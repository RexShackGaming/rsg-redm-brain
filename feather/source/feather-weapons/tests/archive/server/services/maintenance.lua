MaintenanceService = {}

local fields = { "degradation", "permanentDegradation", "damage", "dirt", "soot" }

local function Unit(value)
    value = tonumber(value)
    if not value or value < 0.0 or value > 1.0 then return nil end
    return value
end

function MaintenanceService.Sync(source, rpcContext, params)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    params = type(params) == "table" and params or {}
    local slot = WeaponRuntime.NormalizeSlot(params.slot)
    local runtime = WeaponRuntime.Get(source)
    local equipped = runtime and slot and runtime.sessionId == rpcContext.sessionId
        and runtime.slots and runtime.slots[slot] or nil
    if not equipped then
        return WeaponResult.Error(WeaponErrors.NOT_EQUIPPED,
            "No weapon is equipped in that slot", nil, rpcContext.correlationId)
    end
    if not WeaponRuntime.MatchesLease(source, rpcContext.sessionId,
        params.itemInstanceId, params.generation, slot) then
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            "Weapon runtime lease is stale", nil, rpcContext.correlationId)
    end

    local report = type(params.maintenance) == "table" and params.maintenance or {}
    for _, field in ipairs(fields) do
        if Unit(report[field]) == nil then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
                "Native maintenance state is invalid", { field = field }, rpcContext.correlationId)
        end
    end

    local context = {
        actorSource = source,
        actorCharacterId = rpcContext.characterId,
        characterId = rpcContext.characterId,
        sessionId = rpcContext.sessionId,
        correlationId = rpcContext.correlationId,
        reason = "maintenance_checkpoint",
        resource = "feather-weapons"
    }
    local transaction = InventoryAdapter.Transaction(context, function(tx)
        local item = tx:GetItemForUpdate(equipped.itemInstanceId)
        if not item then
            return WeaponResult.Error(WeaponErrors.ITEM_NOT_OWNED,
                "Equipped weapon is no longer owned", nil, context.correlationId)
        end
        local definitionResult = DefinitionRegistry.Get("weapon", equipped.definitionId)
        if not definitionResult.ok then return definitionResult end
        local validation = WeaponMetadata.Validate(item.metadata, definitionResult.value, context.correlationId)
        if not validation.ok then return validation end

        local saved = item.metadata.maintenance
        local nextValue = {}
        -- Native wear may only worsen through this client checkpoint. Cleaning is
        -- a separate server-authorized transaction and is the only decrease path.
        for _, field in ipairs(fields) do
            nextValue[field] = math.max(Unit(saved[field]) or 0.0, Unit(report[field]))
        end
        nextValue.degradation = math.max(nextValue.degradation, nextValue.permanentDegradation)
        nextValue.damage = math.max(nextValue.damage, nextValue.permanentDegradation)
        item.metadata.maintenance = nextValue
        item.metadata.condition = math.floor((1.0 - math.max(
            nextValue.degradation, nextValue.damage))
            * definitionResult.value.condition.maximum + 0.5)
        if not tx:SetMetadata(item.id, item.metadata, item.metadataRevision) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                "Weapon metadata changed during maintenance checkpoint", nil, context.correlationId)
        end
        return { slot = slot, itemInstanceId = item.id,
            maintenance = nextValue, condition = item.metadata.condition }
    end)
    if not transaction.ok then return transaction end
    WeaponRuntime.SetSlotMaintenance(source, rpcContext.sessionId, slot,
        transaction.value.maintenance, transaction.value.condition, rpcContext.correlationId)
    return WeaponResult.Ok(transaction.value, rpcContext.correlationId)
end

FeatherCore.RPC.Register("feather-weapons:maintenance:sync", function(params, respond, source, context)
    respond(MaintenanceService.Sync(source, context, params))
end, { requireCharacter = true, windowMs = 10000, maxCalls = 12, maxPayloadBytes = 768 })
