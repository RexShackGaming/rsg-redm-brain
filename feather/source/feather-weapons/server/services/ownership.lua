WeaponOwnershipService = {}
local diagnostics = {
    observed = 0,
    failed = 0,
    leaseViolations = 0,
    byType = {},
    last = nil
}

local function CleanText(value, maximum)
    if value == nil then return nil end
    value = tostring(value)
    if value == "" then return nil end
    return value:sub(1, maximum)
end

function WeaponOwnershipService.EvaluateAdministrativeHold(metadata)
    if type(metadata) ~= "table" or type(metadata.flags) ~= "table" then
        return false, "Weapon administrative state could not be verified."
    end
    if metadata.flags.evidence == true then
        return false, "This weapon is held as evidence and cannot be moved or removed."
    end
    if metadata.flags.disabled == true then
        return false, "This weapon is administratively disabled and cannot be moved or removed."
    end
    return true
end

local function CharacterInventoryId(characterId, correlationId)
    if not characterId then return nil end
    local reader=WeaponNativeOwnershipReader
    local inventory = reader.GetCharacterInventory({
        correlationId = correlationId
    }, characterId)
    return inventory.ok and tonumber(inventory.value.id) or nil
end

local function ActiveCharacterForInventory(inventoryId, correlationId)
    inventoryId = tonumber(inventoryId)
    if not inventoryId then return nil end
    for _, playerId in ipairs(GetPlayers()) do
        local session = CoreAdapter.ResolveSession(tonumber(playerId))
        local characterId = session.ok
            and CoreAdapter.NormalizeCharacterId(session.value.characterId) or nil
        if characterId and CharacterInventoryId(characterId, correlationId) == inventoryId then
            return characterId
        end
    end
    return nil
end

local function ClassifyTransition(payload, actorInventoryId)
    local reason = tostring(payload.reason or "")
    if reason == "ground_drop" then return "drop" end
    if reason == "give" then return "transfer" end
    if reason == "container_recovery" then return "recovery" end

    if actorInventoryId then
        if tonumber(payload.toInventoryId) == actorInventoryId then return "pickup" end
        if tonumber(payload.fromInventoryId) == actorInventoryId then return "deposit" end
    end
    return "inventory_move"
end

local function RecordCommittedFact(fact)
    local persisted = WeaponProvenanceService.Record(fact)
    if not persisted.ok then
        diagnostics.failed = diagnostics.failed + 1
        print(("[feather-weapons] CRITICAL provenance persistence failed item=%s type=%s message=%s"):format(
            tostring(fact.itemInstanceId), tostring(fact.transitionType),
            tostring(persisted.error and persisted.error.message)))
    else
        fact.eventId = persisted.value.eventId
    end
    TriggerEvent("Feather:Weapons:OwnershipTransitionCommitted", fact)
    diagnostics.observed = diagnostics.observed + 1
    diagnostics.byType[fact.transitionType] = (diagnostics.byType[fact.transitionType] or 0) + 1
    diagnostics.last = fact
end

function WeaponOwnershipService.HandleCommittedMove(payload)
    if type(payload) ~= "table" then return nil end
    -- A durable Inventory move is projected through ApplyInventoryMoveDelivery;
    -- this legacy broadcast must not insert a second provenance record.
    if payload.durableMoveOperationId then return nil end
    if tostring(payload.fromInventoryId) == tostring(payload.toInventoryId) then return nil end
    local reader=WeaponNativeOwnershipReader
    if not reader then return nil end
    local definitionId = reader.ResolveWeaponDefinitionId(payload.definitionId)
    if not definitionId then return nil end

    local instance = reader.GetInstance({ correlationId = payload.correlationId }, payload.instanceId)
    if not instance.ok then
        diagnostics.failed = diagnostics.failed + 1
        print(("[feather-weapons] ownership observation failed item=%s code=%s"):format(
            tostring(payload.instanceId), tostring(instance.error and instance.error.code)))
        return instance
    end

    local metadata = instance.value.metadata or {}
    if metadata.weaponDefinitionId ~= definitionId then
        diagnostics.failed = diagnostics.failed + 1
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            "Moved weapon metadata does not match its Inventory definition", {
                itemInstanceId = payload.instanceId,
                expectedDefinitionId = definitionId,
                actualDefinitionId = metadata.weaponDefinitionId
            }, payload.correlationId)
    end

    local actorCharacterId = CoreAdapter.NormalizeCharacterId(payload.actorCharacterId)
    local actorInventoryId = CharacterInventoryId(actorCharacterId, payload.correlationId)
    local fromCharacterId = tonumber(payload.fromInventoryId) == actorInventoryId
        and actorCharacterId or nil
    local toCharacterId = tonumber(payload.toInventoryId) == actorInventoryId
        and actorCharacterId or nil
    if not fromCharacterId then
        fromCharacterId = ActiveCharacterForInventory(payload.fromInventoryId, payload.correlationId)
    end
    if not toCharacterId then
        toCharacterId = ActiveCharacterForInventory(payload.toInventoryId, payload.correlationId)
    end

    local fact = {
        operation = "inventory_move",
        transitionType = ClassifyTransition(payload, actorInventoryId),
        outcome = "committed",
        itemInstanceId = tonumber(payload.instanceId),
        definitionId = definitionId,
        serialNumber = metadata.serialNumber,
        revision = tonumber(payload.revision) or instance.value.metadataRevision,
        observedRevision = instance.value.metadataRevision,
        observedInventoryId = instance.value.inventoryId,
        observationMatchesCommittedRevision = tonumber(payload.revision)==tonumber(instance.value.metadataRevision),
        fromInventoryId = tonumber(payload.fromInventoryId),
        toInventoryId = tonumber(payload.toInventoryId),
        actorSource = tonumber(payload.actorSource),
        actorCharacterId = actorCharacterId,
        fromCharacterId = fromCharacterId,
        toCharacterId = toCharacterId,
        reason = CleanText(payload.reason or "inventory_move", 64),
        resource = CleanText(payload.resource or "feather-inventory", 64),
        correlationId = CleanText(payload.correlationId, 128),
        occurredAt = tonumber(payload.occurredAt) or os.time()
    }

    local nativeBound=false
    if WeaponCharacterAmmoService and type(WeaponCharacterAmmoService.IsNativeItemBound)=='function' then
        nativeBound=WeaponCharacterAmmoService.IsNativeItemBound(tonumber(payload.instanceId))==true
    end
    fact.nativeLeaseViolation=nativeBound
    fact.activeLeaseViolation = nativeBound
    if fact.activeLeaseViolation then
        diagnostics.leaseViolations = diagnostics.leaseViolations + 1
    end
    if nativeBound then
        print(('[feather-weapons] CRITICAL native-owned weapon moved item=%s from=%s to=%s'):format(
            tostring(payload.instanceId),tostring(payload.fromInventoryId),tostring(payload.toInventoryId)))
        -- Diagnostic only: never invoke the legacy reconciler for a native lease.
    end
    RecordCommittedFact(fact)
    if Config.DevMode then
        print(("[feather-weapons] ownership transition item=%s serial=%s definition=%s from=%s/%s to=%s/%s type=%s reason=%s"):format(
            tostring(fact.itemInstanceId), tostring(fact.serialNumber), tostring(fact.definitionId),
            tostring(fact.fromInventoryId), tostring(fact.fromCharacterId),
            tostring(fact.toInventoryId), tostring(fact.toCharacterId),
            tostring(fact.transitionType), tostring(fact.reason)))
    end
    return WeaponResult.Ok(fact, payload.correlationId)
end

function WeaponOwnershipService.GetDiagnostics()
    return {
        observed = diagnostics.observed,
        failed = diagnostics.failed,
        leaseViolations = diagnostics.leaseViolations,
        byType = diagnostics.byType,
        last = diagnostics.last
    }
end

function WeaponOwnershipService.Destroy(context, request, invokingResource)
    context = type(context) == "table" and context or {}
    request = type(request) == "table" and request or {}
    local trusted = (Config.Ownership or {}).trustedResources or {}
    if trusted[invokingResource] ~= true then
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            "Calling resource is not trusted for weapon destruction", nil, context.correlationId)
    end

    local characterId = CoreAdapter.NormalizeCharacterId(request.characterId or context.characterId)
    local itemInstanceId = tonumber(request.itemInstanceId)
    local expectedSerial = CleanText(request.serialNumber, 128)
    if not characterId or not itemInstanceId or itemInstanceId<1 or itemInstanceId%1~=0
        or itemInstanceId==math.huge or not expectedSerial then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            "Character, item instance, and expected serial are required", nil, context.correlationId)
    end

    return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
        'Weapon destruction is not available on the native host; no deletion was requested',
        {reason='native_destruction_not_implemented'},context.correlationId)
end

function WeaponOwnershipService.CheckDestructionContract()
    local trusted = (Config.Ownership or {}).trustedResources or {}
    local authorization = (Config.Ownership or {}).authorization or {}
    local untrusted = WeaponOwnershipService.Destroy({}, {}, "untrusted-smoke-resource")
    local incomplete = WeaponOwnershipService.Destroy({}, {}, "feather-weapons")
    return {
        serviceAvailable = type(WeaponOwnershipService.Destroy) == "function",
        trustedCallerConfigured = trusted["feather-weapons"] == true,
        authorizationConfigured = authorization.enabled ~= true
            or (type(authorization.destroyAction) == "string"
                and authorization.destroyAction ~= ""),
        untrustedRejected = untrusted.ok == false
            and untrusted.error and untrusted.error.code == WeaponErrors.AUTHORIZATION_INVALID,
        incompleteRejected = incomplete.ok == false
            and incomplete.error and incomplete.error.code == WeaponErrors.ITEM_INVALID
    }
end

AddEventHandler("Feather:Inventory:ItemMoved", function(payload)
    WeaponOwnershipService.HandleCommittedMove(payload)
end)
