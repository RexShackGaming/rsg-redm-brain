MedicalGameplay = {}
local G = MedicalGameplay
local delivery = {} -- transient current-session authorization; durable op survives restart

local function err(code) return {ok = false, code = code} end
local function uuid() return DB.value('SELECT UUID()') end
local function current(source, context)
    if not Config.medical.enabled or not G.Ready or not G.Ready() or type(context) ~= 'table' then return false end
    if exports['feather-core']:IsSessionCurrent(source, context.sessionId, context.characterId) ~= true then return false end
    local ready = exports['feather-character']:GetMedicalReadySession(source)
    return type(ready) == 'table' and ready.ok and ready.value.sessionId == context.sessionId
        and ready.value.characterId == context.characterId
end
G.IsCurrent = current

-- Read-only Weapons death preflight. No initialization, recovery or state write.
exports('ReadNativeWeaponCondition',function(source,context)
    if GetInvokingResource()~='feather-weapons' or type(source)~='number' or source<1 or source%1~=0
        or type(context)~='table' or type(context.characterId)~='string' or #context.characterId~=36
        or type(context.sessionId)~='string' or #context.sessionId<1 or #context.sessionId>128 then return err('forbidden') end
    local bound={characterId=context.characterId,sessionId=context.sessionId}
    if not current(source,bound) then return err('stale_session') end
    local called,record=pcall(MedicalRepository.Get,bound.characterId)
    if not called then return err('storage_unavailable') end
    if not record then return err('condition_missing') end
    if not current(source,bound) then return err('stale_session') end
    return {ok=true,value=G.Snapshot(record,bound)}
end)

function G.Snapshot(record, context)
    return {lifeState = record.lifeState, revision = record.revision, episodeId = record.episodeId,
        bleedOutAt = record.bleedOutAt, doctorAvailableAt = record.doctorAvailableAt,
        characterId = record.characterId, sessionId = context and context.sessionId, serverTime = os.time()}
end

function G.Prepare(characterId, source, sessionId)
    if not Config.medical.enabled or not G.Ready or not G.Ready() then return err('medical_unavailable') end
    assert(type(characterId) == 'string' and #characterId == 36, 'Character UUID required')
    local function validActivation()
        return source == nil or exports['feather-core']:IsSessionCurrent(source, sessionId, characterId) == true
    end
    if not validActivation() then return err('stale_session') end
    local record = MedicalRepository.Get(characterId)
    if not record then
        if MedicalRepository.HasHistory(characterId) then return err('condition_missing') end
        -- Explicit first enrollment by Character. A missing row with episode
        -- history must never be silently initialized alive.
        record = MedicalRepository.Initialize(characterId, os.time())
    end
    record = MedicalRepository.Advance(characterId, os.time(), uuid())
    if not Config.medical.persistentDeath then record = MedicalRepository.ResetOnActivation(characterId, os.time(), uuid(), validActivation) end
    if not validActivation() then return err('stale_session') end
    return {ok = true, value = G.Snapshot(record)}
end

function G.Observe(source, context, expectedRevision)
    if not current(source, context) then return err('stale_session') end
    local result = MedicalRepository.ObserveLethal(context.characterId, Config.medical, os.time(), uuid(), uuid(),
        function() return current(source, context) end, expectedRevision)
    if result.ok then result.value = G.Snapshot(result.value, context) end
    return result
end

function G.Pending(source, context)
    if not current(source, context) then return err('stale_session') end
    local operation = MedicalRepository.PendingRecovery(context.characterId)
    if not current(source, context) then return err('stale_session') end
    if not operation then return {ok = true, value = {pending = false}} end
    local key = tonumber(source)
    local existing = delivery[key]
    if not existing or existing.sessionId ~= context.sessionId or existing.characterId ~= context.characterId
        or existing.operationId ~= operation.operation_id then
        existing = {sessionId = context.sessionId, characterId = context.characterId, operationId = operation.operation_id, token = uuid()}
        delivery[key] = existing
    end
    if not current(source, context) then return err('stale_session') end
    return {ok = true, value = {pending = true, operationId = operation.operation_id,
        deliveryToken = existing.token,
        sessionId = context.sessionId, characterId = context.characterId, episodeId = operation.episode_id,
        kind = operation.recovery_kind, destination = operation.destination_snapshot and json.decode(operation.destination_snapshot)}}
end

function G.RequestDoctor(source, context)
    if not current(source, context) then return err('stale_session') end
    local previous = MedicalRepository.PendingRecovery(context.characterId)
    if previous then
        if not current(source, context) then return err('stale_session') end
        return {ok = true, value = {operationId = previous.operation_id, episodeId = previous.episode_id}}
    end
    local destination
    if MedicalHospitals.HasEnabled(Config.hospitals) then
        local ped = GetPlayerPed(tonumber(source))
        if not ped or ped == 0 then return err('position_unavailable') end
        local exists = DoesEntityExist(ped)
        if exists ~= true and exists ~= 1 then return err('position_unavailable') end
        local point, reason = MedicalHospitals.Nearest(Config.hospitals, GetEntityCoords(ped))
        if not point then return err(reason) end
        destination = {ok = true, value = point}
    elseif Config.medical.temporarySpawnEnabled then
        destination = exports['feather-character']:GetMedicalRecoveryDestination(Config.medical.temporarySpawnPoint)
    else
        return err('hospital_unavailable')
    end
    if type(destination) ~= 'table' or not destination.ok then return err('destination_unavailable') end
    return MedicalRepository.BeginRecovery(context.characterId, context.characterId, os.time(), uuid(),
        function() return current(source, context) end, 'doctor', destination.value)
end

function G.Acknowledge(source, context, operationId, deliveryToken)
    local expected = delivery[tonumber(source)]
    if not current(source, context) or not expected or expected.sessionId ~= context.sessionId
        or expected.characterId ~= context.characterId or expected.operationId ~= operationId
        or expected.token ~= deliveryToken then return err('stale_delivery') end
    local result = MedicalRepository.CompleteStaffRecovery(context.characterId, operationId, os.time(), uuid(),
        function() return current(source, context) end)
    if result.ok then result.value = G.Snapshot(result.value, context) end
    return result
end

function G.RequestStaff(actor, target)
    actor, target = tonumber(actor), tonumber(target)
    if not actor or actor < 0 or actor % 1 ~= 0 or not target or target < 1 or target % 1 ~= 0 then return err('invalid_source') end
    local session = exports['feather-core']:GetSessionContext(target)
    if type(session) ~= 'table' or not session.ok or not current(target, session.value) then return err('target_not_ready') end
    local actorSession = actor > 0 and exports['feather-core']:GetSessionContext(actor) or nil
    if actor > 0 and (type(actorSession) ~= 'table' or not actorSession.ok) then return err('actor_not_ready') end
    local function authorized()
        if not current(target, session.value) then return false end
        if actor == 0 then return true end -- console-only command; never a player RPC
        if exports['feather-core']:IsSessionCurrent(actor, actorSession.value.sessionId, actorSession.value.characterId) ~= true then return false end
        local decision = exports['feather-core']:Authorize('booster.revive', {source = actor, subject = {targetSource = target}})
        return type(decision) == 'table' and decision.ok and type(decision.value) == 'table'
            and decision.value.allowed == true and exports['feather-admin']:CanMedicalRevive(actor, target) == true
            and current(target, session.value)
            and exports['feather-core']:IsSessionCurrent(actor, actorSession.value.sessionId, actorSession.value.characterId) == true
    end
    if not authorized() then return err('forbidden') end
    return MedicalRepository.BeginStaffRecovery(session.value.characterId,
        actor == 0 and 'console' or actorSession.value.characterId, os.time(), uuid(), authorized)
end

AddEventHandler('playerDropped', function() delivery[tonumber(source)] = nil end)
AddEventHandler('onResourceStop', function(resource)
    if resource == 'feather-core' then delivery = {} end
end)

exports('PrepareCharacter', function(characterId, source, sessionId)
    if GetInvokingResource() ~= 'feather-character' then return err('forbidden') end
    -- Cfx transport can supply source as a numeric string; Core normalizes it.
    source = tonumber(source)
    if not source or source < 1 or source % 1 ~= 0 or type(sessionId) ~= 'string' then return err('session_required') end
    local ok, result = pcall(G.Prepare, characterId, source, sessionId)
    if not ok then print('[feather-medical] PrepareCharacter failed: ' .. tostring(result)) end
    if ok and not result.ok then print('[feather-medical] PrepareCharacter rejected: ' .. tostring(result.code)) end
    return ok and result or err('storage_unavailable')
end)
exports('RequestStaffRecovery', function(actor, target)
    if GetInvokingResource() ~= 'feather-admin' then return err('forbidden') end
    local ok, result = pcall(G.RequestStaff, actor, target)
    return ok and result or err('storage_unavailable')
end)

RegisterCommand('MedicalRevive', function(source, args)
    if source ~= 0 then return end
    CreateThread(function()
        local target = tonumber(args and args[1])
        if not target or target < 1 or target % 1 ~= 0 then print('[MedicalRevive] usage: MedicalRevive <player server ID>'); return end
        local ok, result = pcall(G.RequestStaff, 0, target)
        print('[MedicalRevive] ' .. (ok and result.ok and ('authorized pending operation=' .. result.value.operationId)
            or ('FAILED ' .. tostring(ok and result.code or result))))
    end)
end, true)
