RepairService = {}
local pendingSelections = {}

local function Context(source, rpcContext)
    return {
        actorSource = source,
        actorCharacterId = rpcContext.characterId,
        characterId = rpcContext.characterId,
        sessionId = rpcContext.sessionId,
        correlationId = rpcContext.correlationId,
        activeUseToken = rpcContext.activeUseToken,
        reason = "repair",
        resource = "feather-weapons"
    }
end

function RepairService.Repair(source, rpcContext, request, allowOwned)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    request = type(request) == "table" and request or {}
    local slot = WeaponRuntime.NormalizeSlot(request.slot)
    local itemInstanceId = request.itemInstanceId
    local generation = tonumber(request.generation)
    if not slot then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID, "Weapon equipment slot is invalid", nil,
            rpcContext.correlationId)
    end
    local idType = type(itemInstanceId)
    if (idType ~= "string" and idType ~= "number")
        or (idType == "string" and (itemInstanceId == "" or #itemInstanceId > 128))
        or (idType == "number" and (itemInstanceId < 1 or itemInstanceId % 1 ~= 0)) then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID, "Item instance ID is invalid", nil,
            rpcContext.correlationId)
    end
    local hasRuntimeLease = generation and WeaponRuntime.MatchesLease(
        source, rpcContext.sessionId, itemInstanceId, generation, slot)
    if not hasRuntimeLease and not allowOwned then
        local equippedResult = InventoryAdapter.GetEquippedSlotsForCharacter(Context(source, rpcContext))
        if not equippedResult.ok
            or tostring(equippedResult.value and equippedResult.value[slot] or '')
                ~= tostring(itemInstanceId) then
            return WeaponResult.Error(WeaponErrors.SESSION_EXPIRED,
                "The equipped weapon assignment is no longer current",
                { slot = slot }, rpcContext.correlationId)
        end
    end

    local context = Context(source, rpcContext)
    local transactionResult = InventoryAdapter.Transaction(context, function(tx)
        local item = tx:GetItemForUpdate(itemInstanceId)
        if not item then
            return WeaponResult.Error(WeaponErrors.ITEM_NOT_OWNED, "Weapon item is not owned by this character", nil,
                context.correlationId)
        end
        if type(item.metadata) ~= "table" then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID, "Weapon item metadata is invalid", nil,
                context.correlationId)
        end

        local metadata = item.metadata
        local definitionResult = DefinitionRegistry.Get("weapon", metadata.weaponDefinitionId)
        if not definitionResult or not definitionResult.ok then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID, "Weapon item metadata is invalid", nil,
                context.correlationId)
        end
        local definition = definitionResult.value
        if item.itemName ~= definition.itemName then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID, "Item definition does not match weapon metadata", nil,
                context.correlationId)
        end
        local metadataResult = WeaponMetadata.Validate(metadata, definition, context.correlationId)
        if not metadataResult.ok then return metadataResult end

        local current = tonumber(metadata.condition) or definition.condition.minimum
        if current >= definition.condition.maximum then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, "Weapon condition is already full", {
                condition = current
            }, context.correlationId)
        end

        local repair = definition.condition.repair
        if tx:GetQuantity(repair.itemDefinitionId) < repair.quantity then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, "Required repair material is unavailable", {
                itemDefinitionId = repair.itemDefinitionId,
                required = repair.quantity
            }, context.correlationId)
        end
        if not tx:RemoveQuantity(repair.itemDefinitionId, repair.quantity) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, "Repair material changed during repair", nil,
                context.correlationId)
        end

        metadata.maintenance = type(metadata.maintenance) == "table" and metadata.maintenance or {}
        local permanent = math.max(0.0, math.min(1.0,
            tonumber(metadata.maintenance.permanentDegradation) or 0.0))
        metadata.maintenance.permanentDegradation = permanent
        metadata.maintenance.degradation = permanent
        metadata.maintenance.damage = permanent
        metadata.maintenance.dirt = 0.0
        metadata.maintenance.soot = 0.0
        metadata.condition = math.floor((1.0 - permanent) * definition.condition.maximum + 0.5)
        if not tx:SetMetadata(item.id, metadata, item.metadataRevision) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, "Weapon metadata changed during repair", nil,
                context.correlationId)
        end
        return {
            slot = slot,
            generation = generation,
            itemInstanceId = item.id,
            previousCondition = current,
            condition = metadata.condition,
            maintenance = metadata.maintenance,
            restored = metadata.condition - current,
            material = repair.itemDefinitionId,
            materialConsumed = repair.quantity,
            materialRemaining = tx:GetQuantity(repair.itemDefinitionId),
            broken = metadata.condition < definition.condition.equipMinimum
        }
    end)
    if not transactionResult.ok then return transactionResult end

    if WeaponRuntime.MatchesLease(source, rpcContext.sessionId, itemInstanceId, generation, slot) then
        WeaponRuntime.SetSlotMaintenance(source, rpcContext.sessionId, slot,
            transactionResult.value.maintenance, transactionResult.value.condition,
            rpcContext.correlationId)
    end
    if not hasRuntimeLease and not allowOwned and transactionResult.value.broken == false then
        local itemResult = InventoryAdapter.GetItemForCharacter(context, itemInstanceId)
        if itemResult.ok then
            local definitionResult = DefinitionRegistry.Get(
                "weapon", itemResult.value.metadata.weaponDefinitionId)
            if definitionResult.ok then
                local restored = WeaponRuntime.RestoreEquipped(source, rpcContext.sessionId,
                    itemResult.value, definitionResult.value, rpcContext.correlationId, slot)
                transactionResult.value.reconcile = restored.ok == true
            end
        end
    end
    return WeaponResult.Ok(transactionResult.value, rpcContext.correlationId)
end

function RepairService.BeginSelection(source, rpcContext, done)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    if pendingSelections[source] then
        return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
            "A repair selection is already pending", nil, rpcContext.correlationId)
    end
    local runtime = WeaponRuntime.Get(source)
    if not runtime or runtime.sessionId ~= rpcContext.sessionId then
        return WeaponResult.Error(WeaponErrors.NOT_EQUIPPED,
            "An equipped weapon is required for repair selection", nil,
            rpcContext.correlationId)
    end
    local context = Context(source, rpcContext)
    local equippedResult = InventoryAdapter.GetEquippedSlotsForCharacter(context)
    if not equippedResult.ok then return equippedResult end
    local pending = {
        context = rpcContext,
        done = done,
        selections = {}
    }
    local choices = {}
    local listed = InventoryAdapter.ListWeaponsForCharacter(context)
    if not listed.ok then return listed end
    local itemsById = {}
    for _, item in ipairs(listed.value or {}) do itemsById[tostring(item.id)] = item end
    local seen = {}
    for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
        local itemInstanceId = equippedResult.value and equippedResult.value[slot] or nil
        if itemInstanceId then
            local item = itemsById[tostring(itemInstanceId)]
            local definitionResult = item and type(item.metadata) == "table"
                and DefinitionRegistry.Get("weapon", item.metadata.weaponDefinitionId) or nil
            local definition = definitionResult and definitionResult.ok and definitionResult.value or nil
            local condition = item and item.metadata and tonumber(item.metadata.condition) or 0
            if definition and condition < definition.condition.maximum then
                local equipped = runtime.slots and runtime.slots[slot] or nil
                local key = "slot:" .. slot
                pending.selections[key] = {
                    slot = slot,
                    itemInstanceId = itemInstanceId,
                    generation = equipped and tostring(equipped.itemInstanceId) == tostring(itemInstanceId)
                        and equipped.generation or nil
                }
                choices[#choices + 1] = {
                    key = key,
                    location = slot,
                    definitionId = definition.id,
                    condition = condition
                }
            end
            seen[tostring(itemInstanceId)] = true
        end
    end
    for _, item in ipairs(listed.value or {}) do
        if not seen[tostring(item.id)] then
            local definitionId = item.metadata and item.metadata.weaponDefinitionId or "Weapon"
            local definition = WeaponDefinitionCatalog.weapons[definitionId]
            local condition = item.metadata and tonumber(item.metadata.condition) or 0
            if definition and condition < definition.condition.maximum then
                local slot = definition.slot == "longgun" and "shoulder" or "primary"
                local key = "item:" .. tostring(item.id)
                pending.selections[key] = {
                    slot = slot,
                    itemInstanceId = item.id,
                    inventoryOnly = true
                }
                choices[#choices + 1] = {
                    key = key,
                    location = "Inventory",
                    definitionId = definitionId,
                    condition = condition
                }
            end
        end
    end
    if next(pending.selections) == nil then
        return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
            "No owned weapon currently needs repair", nil,
            rpcContext.correlationId)
    end
    pendingSelections[source] = pending
    TriggerClientEvent("feather-weapons:client:repairSlotRequested", source, choices)
    SetTimeout(15000, function()
        if pendingSelections[source] ~= pending then return end
        pendingSelections[source] = nil
        TriggerClientEvent("feather-weapons:client:inventoryRepairResult", source,
            WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                "Repair selection timed out", nil, rpcContext.correlationId))
        if pending.done then pending.done() end
    end)
    return WeaponResult.Ok({ pending = true }, rpcContext.correlationId)
end

function RepairService.Select(source, rpcContext, request)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    local pending = pendingSelections[source]
    if not pending or pending.context.sessionId ~= rpcContext.sessionId then
        return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
            "No repair selection is pending", nil, rpcContext.correlationId)
    end
    local key = type(request) == "table" and request.key or nil
    local selected = type(key) == "string" and pending.selections[key] or nil
    if not selected then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            "Weapon equipment slot is invalid", nil, rpcContext.correlationId)
    end
    pendingSelections[source] = nil
    local result = RepairService.Repair(source, pending.context, {
        slot = selected.slot,
        itemInstanceId = selected.itemInstanceId,
        generation = selected.generation
    }, selected.inventoryOnly == true)
    if pending.done then pending.done() end
    return result
end

FeatherCore.RPC.Register("feather-weapons:repair", function(params, respond, source, context)
    respond(RepairService.Repair(source, context, params))
end, { requireCharacter = true, windowMs = 2000, maxCalls = 3, maxPayloadBytes = 256 })

FeatherCore.RPC.Register("feather-weapons:repair:select", function(params, respond, source, context)
    respond(RepairService.Select(source, context, params))
end, { requireCharacter = true, windowMs = 2000, maxCalls = 3, maxPayloadBytes = 128 })
