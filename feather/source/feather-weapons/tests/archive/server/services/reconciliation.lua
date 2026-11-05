ReconciliationService = {}
-- A runtime exists before the yielding per-slot bootstrap has finished.
-- Do not publish that partial loadout to a restarting client.
local startupReady = false

function ReconciliationService.MarkStartupReady()
    startupReady = true
end

local function CopyPools(pools)
    if type(pools) ~= 'table' then return nil end
    local snapshot = {}
    for id, total in pairs(pools) do snapshot[id] = total end
    return snapshot
end

local function AmmunitionTotal(item)
    local ammo = item and item.metadata and item.metadata.ammo or nil
    if type(ammo) ~= 'table' then return 0 end
    if type(ammo.pools) == 'table' then
        local total = 0
        for _, amount in pairs(ammo.pools) do
            total = total + math.max(0, math.floor(tonumber(amount) or 0))
        end
        return total
    end
    return math.max(0, math.floor(tonumber(ammo.loaded) or 0))
        + math.max(0, math.floor(tonumber(ammo.reserve) or 0))
end

local function NormalizeFundedOffhand(context, equipped)
    if not equipped.primary or not equipped.offhand then return WeaponResult.Ok(equipped) end
    local primaryResult = InventoryAdapter.GetItemForCharacter(context, equipped.primary)
    if not primaryResult.ok then return primaryResult end
    local offhandResult = InventoryAdapter.GetItemForCharacter(context, equipped.offhand)
    if not offhandResult.ok then return offhandResult end
    local primaryDefinition = DefinitionRegistry.Get('weapon',
        primaryResult.value.metadata and primaryResult.value.metadata.weaponDefinitionId)
    if not primaryDefinition.ok then return primaryDefinition end
    local offhandDefinition = DefinitionRegistry.Get('weapon',
        offhandResult.value.metadata and offhandResult.value.metadata.weaponDefinitionId)
    if not offhandDefinition.ok then return offhandDefinition end
    if primaryDefinition.value.multiTypeAmmunition ~= true
        or offhandDefinition.value.multiTypeAmmunition ~= true
        or AmmunitionTotal(primaryResult.value) > 0
        or AmmunitionTotal(offhandResult.value) == 0 then
        return WeaponResult.Ok(equipped)
    end
    local promoted = InventoryAdapter.PromoteOffhandToPrimary(context)
    if not promoted.ok then return promoted end
    print(('[feather-weapons] promoted funded offhand before restore character=%s item=%s displacedEmptyPrimary=%s')
        :format(tostring(context.characterId), tostring(equipped.offhand), tostring(equipped.primary)))
    equipped.primary, equipped.offhand = equipped.offhand, nil
    return WeaponResult.Ok(equipped)
end

local function ContextForSession(session, correlationId)
    return {
        actorSource = session.source,
        actorCharacterId = session.characterId,
        characterId = session.characterId,
        sessionId = session.sessionId,
        correlationId = correlationId,
        reason = "reconcile",
        resource = "feather-weapons"
    }
end

function ReconciliationService.RehydrateSession(session)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Native cutover is not active')
    end
    local context = ContextForSession(session,
        ("rehydrate:%s:%s"):format(tostring(session.characterId), tostring(GetGameTimer())))
    local equippedResult = InventoryAdapter.GetEquippedSlotsForCharacter(context)
    if not equippedResult.ok then return equippedResult end
    local normalizedEquipped = NormalizeFundedOffhand(context, equippedResult.value or {})
    if not normalizedEquipped.ok then return normalizedEquipped end
    local equipped = normalizedEquipped.value

    local restored = {}
    for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
        local itemInstanceId = equipped[slot]
        if itemInstanceId then
            local restoreResult = EquipService.Restore(
                session.source, session, itemInstanceId, context.correlationId, slot)
            if not restoreResult.ok then
                if restoreResult.error.code ~= WeaponErrors.CONDITION_BROKEN then
                    InventoryAdapter.SetEquippedSlotForCharacter(context, slot, nil)
                end
                print(("[feather-weapons] rejected saved equipped item character=%s slot=%s code=%s")
                    :format(tostring(session.characterId), slot, restoreResult.error.code))
            else
                restored[slot] = restoreResult.value
            end
        end
    end
    local normalized = AmmoService.NormalizeSharedPools(session.source, {
        characterId = session.characterId,
        sessionId = session.sessionId,
        correlationId = context.correlationId
    })
    if not normalized.ok then
        local failure = normalized.error or {}
        print(("[feather-weapons] shared ammunition recovery deferred character=%s code=%s message=%s")
            :format(tostring(session.characterId), tostring(failure.code), tostring(failure.message)))
    end
    return WeaponResult.Ok({ slots = restored, equipped = restored.primary }, context.correlationId)
end

function ReconciliationService.Snapshot(source, sessionId, correlationId)
    local runtime = WeaponRuntime.Get(source)
    if not runtime or runtime.sessionId ~= sessionId then
        return WeaponResult.Error(WeaponErrors.SESSION_EXPIRED, "Character session is no longer active", nil,
            correlationId)
    end
    local equipped = nil
    if runtime.equipped then
        equipped = {
            itemInstanceId = runtime.equipped.itemInstanceId,
            serialNumber = runtime.equipped.serialNumber,
            definitionId = runtime.equipped.definitionId,
            nativeWeaponName = runtime.equipped.nativeWeaponName,
            ammunitionType = runtime.equipped.ammunitionType,
            nativeAmmoName = runtime.equipped.nativeAmmoName,
            ammoPools = CopyPools(runtime.equipped.ammoPools),
            ammo = runtime.equipped.ammo,
            loaded = runtime.equipped.loaded,
            reserve = runtime.equipped.reserve,
            capacity = runtime.equipped.capacity,
            condition = runtime.equipped.condition,
            maintenance = runtime.equipped.maintenance,
            generation = runtime.equipped.generation,
            sessionId = runtime.equipped.sessionId,
            attachments = runtime.equipped.attachments or {}
        }
    end
    local slots = {}
    for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
        local value = runtime.slots and runtime.slots[slot] or nil
        if value then
            slots[slot] = {
                slot = slot,
                itemInstanceId = value.itemInstanceId,
                serialNumber = value.serialNumber,
                definitionId = value.definitionId,
                nativeWeaponName = value.nativeWeaponName,
                ammunitionType = value.ammunitionType,
                nativeAmmoName = value.nativeAmmoName,
                ammoPools = CopyPools(value.ammoPools),
                ammo = value.ammo,
                loaded = value.loaded,
                reserve = value.reserve,
                capacity = value.capacity,
                condition = value.condition,
                maintenance = value.maintenance,
                generation = value.generation,
                sessionId = value.sessionId,
                attachments = value.attachments or {}
            }
        end
    end
    return WeaponResult.Ok({ state = runtime.state, equipped = equipped, slots = slots }, correlationId)
end

function ReconciliationService.InspectMetadata(source)
    local sessionResult = CoreAdapter.ResolveSession(source)
    if not sessionResult.ok then return sessionResult end
    local session = sessionResult.value
    local context = ContextForSession(session,
        ("metadata-inspect:%s:%s"):format(tostring(source), tostring(GetGameTimer())))
    local equippedResult = InventoryAdapter.GetEquippedSlotsForCharacter(context)
    if not equippedResult.ok then return equippedResult end
    local runtime = WeaponRuntime.Get(source)
    local slots = {}
    for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
        local itemInstanceId = equippedResult.value and equippedResult.value[slot] or nil
        if itemInstanceId then
            local itemResult = InventoryAdapter.GetItemForCharacter(context, itemInstanceId)
            if not itemResult.ok then return itemResult end
            local item = itemResult.value
            local definitionId = item.metadata and item.metadata.weaponDefinitionId
            local definitionResult = DefinitionRegistry.Get("weapon", definitionId)
            if not definitionResult.ok then return definitionResult end
            local validation = WeaponMetadata.Validate(
                item.metadata, definitionResult.value, context.correlationId)
            if not validation.ok then return validation end
            local runtimeItem = runtime and runtime.slots and runtime.slots[slot]
            local poolsMatch = true
            if item.metadata.ammo.pools then
                for _, id in ipairs(definitionResult.value.ammunitionTypes) do
                    if not runtimeItem or not runtimeItem.ammoPools
                        or (runtimeItem.ammoPools[id] or 0) ~= (item.metadata.ammo.pools[id] or 0) then
                        poolsMatch = false
                    end
                end
            end
            slots[slot] = {
                slot = slot,
                itemInstanceId = item.id,
                definitionId = definitionId,
                serialNumber = item.metadata.serialNumber,
                condition = item.metadata.condition,
                maintenance = item.metadata.maintenance,
                ammunitionType = item.metadata.ammo.type or definitionResult.value.ammunitionType,
                loaded = item.metadata.ammo.loaded,
                ammoPools = item.metadata.ammo.pools,
                reserve = item.metadata.ammo.reserve,
                attachments = item.metadata.attachments or {},
                runtimeMatches = runtimeItem ~= nil
                    and poolsMatch
                    and tostring(runtimeItem.itemInstanceId) == tostring(item.id)
                    and runtimeItem.ammunitionType == (item.metadata.ammo.type or definitionResult.value.ammunitionType),
                generation = runtimeItem and runtimeItem.generation or nil
            }
        end
    end
    return WeaponResult.Ok({
        equipped = next(slots) ~= nil,
        characterId = session.characterId,
        slots = slots
    }, context.correlationId)
end

function ReconciliationService.Force(source)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Native cutover is not active')
    end
    local sessionResult = CoreAdapter.ResolveSession(source)
    if not sessionResult.ok then return sessionResult end
    local session = sessionResult.value
    local reset = WeaponRuntime.ResetForReconcile(source, session.sessionId,
        ("forced-reconcile-reset:%s:%s"):format(tostring(source), tostring(GetGameTimer())))
    if not reset.ok then return reset end
    local restored = ReconciliationService.RehydrateSession(session)
    if not restored.ok then
        TriggerClientEvent("feather-weapons:client:clear", source)
        return restored
    end
    TriggerClientEvent("feather-weapons:client:forceReconcile", source)
    return ReconciliationService.Snapshot(source, session.sessionId,
        ("forced-reconcile:%s:%s"):format(tostring(source), tostring(GetGameTimer())))
end

function ReconciliationService.BootstrapActiveSessions()
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then return end
    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        if source then
            local sessionResult = CoreAdapter.ResolveSession(source)
            if sessionResult.ok then
                WeaponRuntime.Begin(sessionResult.value)
                ReconciliationService.RehydrateSession(sessionResult.value)
            end
        end
    end
end

RegisterNetEvent("feather-weapons:server:client-ready", function()
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then return end
    local playerSource = source
    local deadline = GetGameTimer() + 15000
    while not startupReady and GetGameTimer() < deadline do
        Wait(50)
    end
    if not startupReady then
        print(("[feather-weapons] client-ready deferred: startup incomplete source=%s")
            :format(tostring(playerSource)))
        return
    end
    local sessionResult = CoreAdapter.ResolveSession(playerSource)
    -- Full joins are restored by feather-character's runtime-ready signal.
    -- During a weapons-resource restart the character is already active, so
    -- this handshake closes the server/client listener registration race.
    if not sessionResult.ok then return end

    local session = sessionResult.value
    local runtime = WeaponRuntime.Get(playerSource)
    if not runtime or runtime.sessionId ~= session.sessionId then
        WeaponRuntime.Begin(session)
        local restored = ReconciliationService.RehydrateSession(session)
        if not restored.ok then return end
    end
    if Config.DevMode then
        print(("[feather-weapons] client-ready restore source=%s session=%s")
            :format(tostring(playerSource), tostring(session.sessionId)))
    end
    TriggerClientEvent("feather-weapons:client:runtime-ready", playerSource)
end)

FeatherCore.RPC.Register("feather-weapons:state:get", function(_, respond, source, context)
    respond(ReconciliationService.Snapshot(source, context.sessionId, context.correlationId))
end, { requireCharacter = true, windowMs = 1000, maxCalls = 4, maxPayloadBytes = 64 })

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        if source then
            TriggerClientEvent("feather-weapons:client:clear", source)
        end
    end
end)
