exports('GetHealth', function() return {enabled = Config.medical.enabled, state = 'ready'} end)

local stablePed, stableModel, stableCount = nil, nil, 0
local currentSession, condition, recovery = nil, nil, nil
local lastPrinted
local lethalSamples = 0
local appliedOperation
local unlockAt, requesting = nil, false
-- Keep this gate in the entrypoint: key handling must not depend on an extra
-- client script having been loaded by a cached/deployed manifest.
local function canRequest(unlockTime, now, inFlight, recovering, otherNuiFocused)
    return unlockTime ~= nil and now >= unlockTime and not inFlight and not recovering and not otherNuiFocused
end
local controlResult = exports['feather-toolkit']:ResolveControl(Config.medical.respawnKey)
local respawnControl = type(controlResult) == 'table' and controlResult.ok and controlResult.value or nil
if not respawnControl then print('[feather-medical] invalid respawn key: ' .. tostring(Config.medical.respawnKey)) end
local function hide()
    SendNUIMessage({type = 'medical:hide'})
    unlockAt = nil
end
local function show(record)
    if not record or record.lifeState == 'alive' then hide(); return end
    local remaining = math.max(0, (record.doctorAvailableAt or 0) - (record.serverTime or 0))
    unlockAt = GetGameTimer() + remaining * 1000
    SendNUIMessage({type = 'medical:condition', remaining = remaining, key = Config.medical.respawnKey})
end
local function rpc(name, payload)
    local result, failure = exports['feather-core']:CallRPCAsync(name, payload or {}, nil, 10000)
    return type(result) == 'table' and result or {ok = false,
        code = type(failure) == 'table' and failure.code or 'transport_unavailable'}
end
local function boolean(value) return value == true or value == 1 end
local function dead(ped)
    return boolean(IsEntityDead(ped)) and GetEntityHealth(ped) <= 0
end
local function context()
    if GetResourceState('feather-character') ~= 'started' then return nil end
    return exports['feather-character']:GetMedicalContext()
end
local function matches(expected)
    local now = context()
    return now and now.sessionId == expected.sessionId and now.characterId == expected.characterId
end

CreateThread(function()
    while true do
        if Config.medical.enabled then
            local ok, failure = pcall(function()
                local expected = context()
                if not expected then
                    hide()
                    currentSession, condition, recovery = nil, nil, nil
                    stablePed, stableModel, stableCount = nil, nil, 0
                    lethalSamples = 0
                    return
                end
                if expected.sessionId ~= currentSession then
                    currentSession, condition, recovery = expected.sessionId, nil, nil
                    stablePed, stableModel, stableCount = nil, nil, 0
                    lethalSamples = 0
                end
                local ped = PlayerPedId()
                if ped == 0 or not DoesEntityExist(ped) then stableCount, lethalSamples = 0, 0; return end
                local model = GetEntityModel(ped)
                local function samePed() return PlayerPedId() == ped and DoesEntityExist(ped) and GetEntityModel(ped) == model end
                if ped ~= stablePed or model ~= stableModel then
                    stablePed, stableModel, stableCount = ped, model, 0
                    lethalSamples = 0
                    return
                end
                stableCount = stableCount + 1
                if stableCount < 2 then return end
                -- Obtain persisted state before observing. Unknown/missing state
                -- never manufactures an alive record or grants recovery.
                local result = rpc('medical.condition.get.v1')
                if not result.ok or not matches(expected) or not samePed() then lethalSamples = 0; return end
                condition = result.value
                local pending = rpc('medical.recovery.pending.v1')
                if not pending.ok or not matches(expected) or not samePed() then lethalSamples = 0; return end
                if pending.value.pending then
                    recovery = pending.value
                    if recovery.operationId ~= nil then
                        if dead(ped) or (recovery.kind == 'doctor' and appliedOperation ~= recovery.operationId) then
                            local applied = exports['feather-character']:ApplyMedicalRecovery(recovery)
                            if not applied.ok then return end
                            appliedOperation = recovery.operationId
                            Wait(250)
                        end
                        if not matches(expected) or ped ~= PlayerPedId() or dead(ped) or GetEntityHealth(ped) <= 0 then return end
                        local ack = rpc('medical.recovery.ack.v1', {operationId = recovery.operationId, deliveryToken = recovery.deliveryToken})
                        if ack.ok and matches(expected) then condition, recovery = ack.value, nil end
                    end
                elseif condition.lifeState ~= 'alive' then
                    recovery = nil
                    if not dead(ped) then exports['feather-character']:ApplyMedicalCondition(condition) end
                elseif dead(ped) then
                    lethalSamples = lethalSamples + 1
                    if lethalSamples < 2 then return end
                    local observed = rpc('medical.observation.lethal.v1', {expectedRevision = condition.revision})
                    if observed.ok and matches(expected) then
                        condition = observed.value
                        print('[feather-medical] lethal observation persisted: ' .. condition.lifeState .. ' revision=' .. condition.revision)
                    end
                else
                    lethalSamples = 0
                end
                -- Publish only persisted snapshots; alive recovery is exposed
                -- after the acknowledgment succeeds, never after resurrection alone.
                if matches(expected) then
                    MedicalClientLifecycle.Publish(condition, expected)
                end
                show(condition)
                if condition and lastPrinted ~= condition.lifeState .. ':' .. condition.revision then
                    lastPrinted = condition.lifeState .. ':' .. condition.revision
                    print('[feather-medical] condition=' .. condition.lifeState .. ' revision=' .. condition.revision)
                end
            end)
            if not ok then
                if lastPrinted ~= tostring(failure) then print('[feather-medical] observer unavailable: ' .. tostring(failure)); lastPrinted = tostring(failure) end
            end
        end
        Wait(1500)
    end
end)

RegisterCommand('MedicalStatus', function()
    print('[MedicalStatus] checking; client enabled=' .. tostring(Config.medical.enabled)
        .. ' character=' .. GetResourceState('feather-character') .. ' core=' .. GetResourceState('feather-core'))
    print('[MedicalStatus] input ' .. json.encode({key = Config.medical.respawnKey, control = respawnControl,
        remainingMs = unlockAt and math.max(0, unlockAt - GetGameTimer()), requesting = requesting,
        recovering = recovery ~= nil, nuiFocused = boolean(IsNuiFocused())}))
    local finished = false
    local stage = 'character_context'
    CreateThread(function()
        Wait(12000)
        if not finished then print('[MedicalStatus] still waiting at ' .. stage .. '; send this line and the Medical server startup output') end
    end)
    CreateThread(function()
        local ok, failure = pcall(function()
            local expected = context()
            if not expected then print('[MedicalStatus] no active world character'); return end
            stage = 'medical.condition.get.v1'
            print('[MedicalStatus] current Character context obtained; requesting server snapshot')
            local result = rpc('medical.condition.get.v1')
            stage = 'session_recheck'
            if not matches(expected) then print('[MedicalStatus] session changed'); return end
            print('[MedicalStatus] ' .. json.encode(result))
        end)
        finished = true
        if not ok then print('[MedicalStatus] FAILED at ' .. stage .. ': ' .. tostring(failure)) end
    end)
end, false)

print('[feather-medical] observer loaded; staging enabled=' .. tostring(Config.medical.enabled))

local function requestRespawn()
    local otherFocus = boolean(IsNuiFocused())
    if not Config.medical.enabled or not condition or condition.lifeState == 'alive'
        or not canRequest(unlockAt, GetGameTimer(), requesting, recovery ~= nil, otherFocus) then
        print('[feather-medical] respawn input blocked ' .. json.encode({
            remainingMs = unlockAt and math.max(0, unlockAt - GetGameTimer()),
            requesting = requesting, recovering = recovery ~= nil, nuiFocused = otherFocus}))
        return
    end
    requesting = true
    SendNUIMessage({type = 'medical:requesting'})
    print('[feather-medical] requesting doctor recovery')
    CreateThread(function()
        local ok, result = pcall(function()
            local expected = context()
            if not expected then return {ok = false, code = 'no_character'} end
            return rpc('medical.recovery.doctor.request.v1')
        end)
        requesting = false
        if not ok or not result.ok then
            print('[feather-medical] doctor recovery rejected: ' .. tostring(ok and result.code or result))
            SendNUIMessage({type = 'medical:error', message = 'Recovery unavailable. Please try again.'})
        else
            print('[feather-medical] doctor recovery authorized; awaiting application')
        end
    end)
end

-- Same guarded request as the key, useful for isolating input from transport.
RegisterCommand('MedicalRespawn', requestRespawn, false)

CreateThread(function()
    local lastInputError
    while true do
        if Config.medical.enabled and respawnControl and condition and condition.lifeState ~= 'alive' then
            local ok, failure = pcall(function()
                -- Death can disable gameplay controls. Enable only the configured
                -- recovery action once eligible, without touching other NUI focus.
                if canRequest(unlockAt, GetGameTimer(), requesting, recovery ~= nil, boolean(IsNuiFocused())) then
                    EnableControlAction(0, respawnControl, true)
                end
                if boolean(IsControlJustPressed(0, respawnControl)) or boolean(IsDisabledControlJustPressed(0, respawnControl)) then
                    requestRespawn()
                end
            end)
            if not ok and lastInputError ~= tostring(failure) then
                lastInputError = tostring(failure)
                print('[feather-medical] respawn input failed: ' .. lastInputError)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then hide() end
end)
