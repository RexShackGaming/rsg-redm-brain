AmmoService = {}

-- A throwable may be recovered from the world only after this runtime lease
-- has committed an equal number as consumed. Credits are intentionally
-- ephemeral: a resource/session restart discards them instead of allowing an
-- unverifiable ammunition increase.
local throwableRecoveryCredits = {}

local function RecoveryCreditKey(source, rpcContext, equipped)
    return table.concat({
        tostring(source),
        tostring(rpcContext.sessionId),
        tostring(equipped.itemInstanceId),
        tostring(equipped.generation),
        tostring(equipped.ammunitionType)
    }, ':')
end

local function Context(source, rpcContext, reason)
    return {
        actorSource = source,
        actorCharacterId = rpcContext.characterId,
        characterId = rpcContext.characterId,
        sessionId = rpcContext.sessionId,
        correlationId = rpcContext.correlationId,
        activeUseToken = rpcContext.activeUseToken,
        reason = reason,
        resource = 'feather-weapons'
    }
end

local function GetEquipped(source, rpcContext, slot)
    local runtime = WeaponRuntime.Get(source)
    slot = WeaponRuntime.NormalizeSlot(slot)
    local equipped = runtime and slot and runtime.slots and runtime.slots[slot]
    if not runtime or runtime.sessionId ~= rpcContext.sessionId or not equipped then
        return nil, WeaponResult.Error(WeaponErrors.NOT_EQUIPPED, 'No weapon is equipped', nil, rpcContext.correlationId)
    end

    return equipped
end

local function ValidateLease(source, equipped, rpcContext, params)
    params = type(params) == 'table' and params or {}
    if not WeaponRuntime.MatchesLease(source, rpcContext.sessionId, params.itemInstanceId, params.generation, params.slot) then
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            'Weapon runtime lease is stale', {
                expectedGeneration = equipped.generation
            }, rpcContext.correlationId)
    end

    return nil
end

local function Reload(source, rpcContext, requested, slot)
    slot = WeaponRuntime.NormalizeSlot(slot) or 'primary'
    local equipped, failure = GetEquipped(source, rpcContext, slot)
    if not equipped then return failure end

    if requested ~= nil then
        requested = math.floor(tonumber(requested) or -1)
    end

    if requested ~= nil and requested < 1 then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID, 'Ammunition amount must be a positive integer', nil,
            rpcContext.correlationId)
    end

    local definitionResult = DefinitionRegistry.Get('weapon', equipped.definitionId)
    if not definitionResult.ok then return definitionResult end

    local definition = definitionResult.value
    local context = Context(source, rpcContext, 'reload')
    local runtime = WeaponRuntime.Get(source)
    local otherPoolTotal = 0
    for _, candidate in ipairs(WeaponConstants.LoadoutSlots) do
        local other = runtime and runtime.slots and runtime.slots[candidate] or nil
        if candidate ~= slot and other and other.nativeAmmoName == equipped.nativeAmmoName then
            otherPoolTotal = otherPoolTotal + (tonumber(other.ammo) or 0)
        end
    end

    local transactionResult = InventoryAdapter.Transaction(context, function(tx)
        local item = tx:GetItemForUpdate(equipped.itemInstanceId)
        if not item then
            return WeaponResult.Error(WeaponErrors.ITEM_NOT_OWNED, 'Equipped weapon is no longer owned', nil, context.correlationId)
        end

        local metadataResult = WeaponMetadata.Validate(item.metadata, definition, context.correlationId)
        if not metadataResult.ok then return metadataResult end

        if tonumber(item.metadata.condition) < definition.condition.equipMinimum then
            return WeaponResult.Error(WeaponErrors.CONDITION_BROKEN, 'Weapon condition is too low to reload', {
                condition = item.metadata.condition,
                minimum = definition.condition.equipMinimum
            }, context.correlationId)
        end

        local loaded = tonumber(item.metadata.ammo.loaded) or 0
        local reserve = tonumber(item.metadata.ammo.reserve) or 0
        local total = loaded + reserve
        local ammunition = DefinitionRegistry.Get('ammunition', item.metadata.ammo.type or definition.ammunitionType)
        if not ammunition.ok then return ammunition end

        local ammunitionItem = ammunition.value.itemName
        local maxTotal = WeaponValidation.EscrowMaximum(definition, ammunition.value.id)
        local refillAmount = math.max(1, math.floor(tonumber(Config.Escrow and Config.Escrow.refillAmount) or maxTotal))
        -- RedM owns one pool per native ammunition type, even when multiple
        -- equipped weapons use it. The escrow ceiling therefore applies to
        -- the entire compatible pool rather than independently to each slot.
        local needed = maxTotal - total - otherPoolTotal
        local available = tx:GetQuantity(ammunitionItem)
        local moved = math.min(needed, available, requested or refillAmount)
        if moved <= 0 then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, 'No compatible ammunition can enter escrow', nil, context.correlationId)
        end

        if not tx:RemoveQuantity(ammunitionItem, moved) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, 'Ammunition changed during reload', nil, context.correlationId)
        end

        local newTotal = total + moved
        local newLoaded = loaded
        if total == 0 and loaded == 0 then
            -- RedM automatically fills an empty cylinder on the next native
            -- update when a positive pool is granted. Persist that native rule
            -- instead of attempting to hold an unstable 0/positive snapshot.
            newLoaded = math.min(definition.capacity, newTotal)
        end

        local newReserve = newTotal - newLoaded
        item.metadata.ammo.loaded = newLoaded
        item.metadata.ammo.reserve = newReserve
        item.metadata.ammo.chambered = newLoaded > 0
        WeaponMetadata.SaveSelectedAmmunitionPool(item.metadata, definition)

        if not tx:SetMetadata(item.id, item.metadata, item.metadataRevision) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                'Weapon metadata changed during ammunition operation', nil, context.correlationId)
        end
        return {
            total = newTotal,
            loaded = newLoaded,
            reserve = newReserve,
            moved = moved,
            inventoryAmmo = tx:GetQuantity(ammunitionItem),
            nativeAmmoName = equipped.nativeAmmoName
        }
    end)

    if not transactionResult.ok then return transactionResult end

    local value = transactionResult.value
    WeaponRuntime.SetSlotAmmo(source, rpcContext.sessionId, slot,
        value.total, value.loaded, rpcContext.correlationId)
    value.slot = slot

    return WeaponResult.Ok(value, rpcContext.correlationId)
end

-- Select every compatible empty slot. Slots using another ammunition family
-- are independent and must not block or be converted by this item use.
local function SelectAmmunition(source, rpcContext, ammunitionType)
    local runtime = WeaponRuntime.Get(source)
    if not runtime or runtime.sessionId ~= rpcContext.sessionId
        or not runtime.slots or next(runtime.slots) == nil then
        return WeaponResult.Error(WeaponErrors.NOT_EQUIPPED, 'Equip a weapon before using ammunition')
    end

    if runtime.pending then
        return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, 'Finish equipping before changing ammunition')
    end

    local selectedAmmunition = DefinitionRegistry.Get('ammunition', ammunitionType)
    if not selectedAmmunition.ok then return selectedAmmunition end

    local compatibleLongguns = {}
    for _, slot in ipairs(Config.Loadout.longgunSlots or {}) do
        local equipped = runtime.slots[slot]
        if equipped then
            local definition = DefinitionRegistry.Get('weapon', equipped.definitionId)
            if not definition.ok then return definition end
            if WeaponValidation.AcceptsAmmunition(definition.value, ammunitionType) then
                compatibleLongguns[#compatibleLongguns + 1] = slot
            end
        end
    end

    if #compatibleLongguns > 1 then
        return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
            'Unload or unequip one long gun before loading ammunition compatible with both', {
                slots = compatibleLongguns,
                ammunitionType = ammunitionType,
                nativeAmmoName = selectedAmmunition.value.nativeAmmoName
            }, rpcContext.correlationId)
    end

    local mutations, selected, compatible = {}, {}, {}
    local context = Context(source, rpcContext, 'select_ammunition')
    for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
        local equipped = runtime.slots[slot]
        if equipped then
            local definition = DefinitionRegistry.Get('weapon', equipped.definitionId)
            if not definition.ok then return definition end

            if WeaponValidation.AcceptsAmmunition(definition.value, ammunitionType) then
                compatible[#compatible + 1] = slot
            else
                goto continue
            end

            local itemResult = InventoryAdapter.GetItemForCharacter(context, equipped.itemInstanceId)
            if not itemResult.ok then return itemResult end

            local item = itemResult.value
            local valid = WeaponMetadata.Validate(item.metadata, definition.value, context.correlationId)
            if not valid.ok then return valid end

            local currentType = item.metadata.ammo.type or definition.value.ammunitionType
            if currentType ~= ammunitionType then
                if definition.value.multiTypeAmmunition ~= true
                    and (item.metadata.ammo.loaded + item.metadata.ammo.reserve) > 0 then
                    return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                        'Unload the compatible equipped weapon before changing ammunition type')
                end

                if definition.value.multiTypeAmmunition == true then
                    WeaponMetadata.ProjectAmmunitionPool(item.metadata, definition.value, ammunitionType)
                else
                    item.metadata.ammo.type = ammunitionType
                end
                mutations[#mutations + 1] = {
                    itemInstanceId = item.id, expectedRevision = item.metadataRevision, metadata = item.metadata
                }
                selected[#selected + 1] = slot
            end
        end
        ::continue::
    end

    if #compatible == 0 then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            'This ammunition is not compatible with an equipped weapon')
    end

    if #mutations == 0 then return WeaponResult.Ok({ changed = false, compatible = compatible }) end

    local committed = InventoryAdapter.MutateWeaponMetadataBatch(context, mutations)
    if not committed.ok then return committed end

    for _, slot in ipairs(selected) do
        WeaponRuntime.SetSlotAmmunitionType(source, rpcContext.sessionId, slot, ammunitionType)
    end

    return WeaponResult.Ok({ changed = true, compatible = compatible })
end

function AmmoService.NormalizeSharedPools(source, rpcContext)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    local runtime = WeaponRuntime.Get(source)
    if not runtime or runtime.sessionId ~= rpcContext.sessionId or not runtime.slots then
        return WeaponResult.Error(WeaponErrors.SESSION_EXPIRED,
            'Character session is no longer active', nil, rpcContext.correlationId)
    end

    local groups = {}
    for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
        local state = runtime.slots[slot]
        if state and state.nativeAmmoName then
            groups[state.nativeAmmoName] = groups[state.nativeAmmoName] or {}
            groups[state.nativeAmmoName][#groups[state.nativeAmmoName] + 1] = { slot = slot, state = state }
        end
    end

    local context = Context(source, rpcContext, 'normalize_shared_ammo')
    for _, group in pairs(groups) do
        local firstDefinition = DefinitionRegistry.Get('weapon', group[1].state.definitionId)
        if not firstDefinition.ok then return firstDefinition end

        local cap = WeaponValidation.EscrowMaximum(firstDefinition.value, group[1].state.ammunitionType)
        local total = 0
        for _, entry in ipairs(group) do
            total = total + (tonumber(entry.state.ammo) or 0)
        end

        if #group > 1 and total > cap then
            local excess = total - cap
            for index = #group, 1, -1 do
                local entry = group[index]
                if excess > 0 then
                    local normalized = InventoryAdapter.Transaction(context, function(tx)
                    local item = tx:GetItemForUpdate(entry.state.itemInstanceId)
                    if not item then
                        return WeaponResult.Error(WeaponErrors.ITEM_NOT_OWNED,
                            'Equipped weapon is no longer owned', nil, context.correlationId)
                    end
                    local reserve = math.max(0, math.floor(tonumber(item.metadata.ammo.reserve) or 0))
                    local loaded = math.max(0, math.floor(tonumber(item.metadata.ammo.loaded) or 0))
                    local reserveReturned = math.min(excess, reserve)
                    local loadedReturned = math.min(excess - reserveReturned, loaded)
                    local returned = reserveReturned + loadedReturned
                    if returned > 0 then
                        local ammunition = DefinitionRegistry.Get('ammunition',
                            item.metadata.ammo.type or entry.state.ammunitionType)
                        if not ammunition.ok then return ammunition end

                        if not tx:AddQuantity(ammunition.value.itemName, returned) then
                            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                                'Shared ammunition could not return to Inventory', nil, context.correlationId)
                        end

                        item.metadata.ammo.reserve = reserve - reserveReturned
                        item.metadata.ammo.loaded = loaded - loadedReturned
                        item.metadata.ammo.chambered = item.metadata.ammo.loaded > 0
                        if not tx:SetMetadata(item.id, item.metadata, item.metadataRevision) then
                            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                                'Weapon metadata changed during shared ammunition recovery', nil,
                                context.correlationId)
                        end

                        return {
                            slot = entry.slot,
                            total = item.metadata.ammo.loaded + item.metadata.ammo.reserve,
                            loaded = item.metadata.ammo.loaded,
                            returned = returned
                        }
                    end

                    return { slot = entry.slot, returned = 0 }
                    end)

                    if not normalized.ok then return normalized end

                    local change = normalized.value
                    if change.returned > 0 then
                        excess = excess - change.returned
                        WeaponRuntime.SetSlotAmmo(source, rpcContext.sessionId, change.slot,
                            change.total, change.loaded, rpcContext.correlationId)
                    end
                end
            end

            if excess > 0 then
                return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
                    'Shared loaded ammunition exceeds the native pool limit', { excess = excess }, context.correlationId)
            end
        end
    end
    return WeaponResult.Ok(true, rpcContext.correlationId)
end

function AmmoService.Escrow(source, rpcContext, amount, ammunitionType)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    local selection = SelectAmmunition(source, rpcContext, ammunitionType)
    if not selection.ok then return selection end
    local runtime = WeaponRuntime.Get(source)
    local slots = runtime and runtime.slots or nil
    local compatible = type(selection.value) == 'table' and selection.value.compatible or { 'primary' }
    local slot = compatible[1] or 'primary'
    if #compatible > 1 then
        -- Ammunition items are not tied to a hand. Fill the less-stocked
        -- weapon first so repeated uses can provision both escrow pools.
        local function EscrowedAmmo(candidate)
            local state = slots and slots[candidate] or nil
            return state and (tonumber(state.ammo) or 0) or math.huge
        end

        for _, candidate in ipairs(compatible) do
            if EscrowedAmmo(candidate) < EscrowedAmmo(slot) then
                slot = candidate
            end
        end
    end

    local result = Reload(source, rpcContext, amount, slot)
    if type(selection.value) == 'table' and selection.value.changed then
        -- Selection can succeed even if the subsequent refill has no stock.
        -- Always refresh the client to the committed type and renewed leases.
        result.reconcile = true
    end
    return result
end

function AmmoService.LoadSlot(source, rpcContext, params)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    params = type(params) == 'table' and params or {}
    local slot = WeaponRuntime.NormalizeSlot(params.slot)
    local equipped, failure = GetEquipped(source, rpcContext, slot)
    if not equipped then return failure end

    local leaseFailure = ValidateLease(source, equipped, rpcContext, params)
    if leaseFailure then return leaseFailure end

    local ammunitionType = params.ammunitionType
    local ammunition = DefinitionRegistry.Get('ammunition', ammunitionType)
    if not ammunition.ok then return ammunition end

    local definitionResult = DefinitionRegistry.Get('weapon', equipped.definitionId)
    if not definitionResult.ok then return definitionResult end

    local definition = definitionResult.value
    if not WeaponValidation.AcceptsAmmunition(definition, ammunitionType) then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            'This ammunition is not compatible with the selected weapon', { slot = slot },
            rpcContext.correlationId)
    end

    local refillAmount = math.max(1, math.floor(tonumber(Config.Escrow and Config.Escrow.refillAmount) or 50))
    local requested = math.floor(tonumber(params.amount) or refillAmount)
    if requested < 1 then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            'Ammunition amount must be a positive integer', nil, rpcContext.correlationId)
    end

    requested = math.min(requested, refillAmount)

    local runtime = WeaponRuntime.Get(source)
    local otherPoolTotal = 0
    for _, candidate in ipairs(WeaponConstants.LoadoutSlots) do
        local other = runtime and runtime.slots and runtime.slots[candidate] or nil
        if candidate ~= slot and other then
            if other.ammoPools then
                otherPoolTotal = otherPoolTotal + (tonumber(other.ammoPools[ammunitionType]) or 0)
            elseif other.nativeAmmoName == ammunition.value.nativeAmmoName then
                otherPoolTotal = otherPoolTotal + (tonumber(other.ammo) or 0)
            end
        end
    end

    local context = Context(source, rpcContext, 'slot_ammo_load')
    local transactionResult = InventoryAdapter.Transaction(context, function(tx)
        local item = tx:GetItemForUpdate(equipped.itemInstanceId)
        if not item then
            return WeaponResult.Error(WeaponErrors.ITEM_NOT_OWNED,
                'Selected weapon is no longer owned', nil, context.correlationId)
        end
        local metadataResult = WeaponMetadata.Validate(item.metadata, definition, context.correlationId)
        if not metadataResult.ok then return metadataResult end

        local loaded = math.max(0, math.floor(tonumber(item.metadata.ammo.loaded) or 0))
        local reserve = math.max(0, math.floor(tonumber(item.metadata.ammo.reserve) or 0))
        local total = loaded + reserve
        local previousType = item.metadata.ammo.type or definition.ammunitionType
        if definition.multiTypeAmmunition == true then
            WeaponMetadata.EnsureAmmunitionPools(item.metadata, definition)
            total = item.metadata.ammo.pools[ammunitionType] or 0
            loaded = previousType == ammunitionType and loaded or math.min(definition.capacity, total)
        end
        if definition.multiTypeAmmunition ~= true and previousType ~= ammunitionType and total > 0 then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                'Unload this weapon before changing its ammunition type', { slot = slot },
                context.correlationId)
        end

        local maxTotal = WeaponValidation.EscrowMaximum(definition, ammunitionType)
        local needed = maxTotal - total - otherPoolTotal
        local available = tx:GetQuantity(ammunition.value.itemName)
        local moved = math.min(requested, needed, available)
        if moved <= 0 then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                'No compatible ammunition can enter this weapon', {
                    slot = slot, available = available, capacity = math.max(0, needed)
                }, context.correlationId)
        end

        if not tx:RemoveQuantity(ammunition.value.itemName, moved) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                'Ammunition changed during loading', nil, context.correlationId)
        end

        local nextTotal = total + moved
        local nextLoaded = loaded
        if total == 0 then nextLoaded = math.min(definition.capacity, nextTotal) end

        item.metadata.ammo.type = ammunitionType
        item.metadata.ammo.loaded = nextLoaded
        item.metadata.ammo.reserve = nextTotal - nextLoaded
        item.metadata.ammo.chambered = nextLoaded > 0
        WeaponMetadata.SaveSelectedAmmunitionPool(item.metadata, definition)
        if not tx:SetMetadata(item.id, item.metadata, item.metadataRevision) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                'Weapon metadata changed during ammunition loading', nil, context.correlationId)
        end

        return {
            slot = slot,
            itemInstanceId = item.id,
            ammunitionType = ammunitionType,
            nativeAmmoName = ammunition.value.nativeAmmoName,
            total = nextTotal,
            loaded = nextLoaded,
            reserve = nextTotal - nextLoaded,
            moved = moved,
            inventoryAmmo = tx:GetQuantity(ammunition.value.itemName),
            typeChanged = previousType ~= ammunitionType
        }
    end)

    if not transactionResult.ok then return transactionResult end

    local value = transactionResult.value
    if value.typeChanged then
        WeaponRuntime.SetSlotAmmunitionType(source, rpcContext.sessionId, slot, value.ammunitionType)
    end

    WeaponRuntime.SetSlotAmmo(source, rpcContext.sessionId, slot, value.total, value.loaded, rpcContext.correlationId)
    local result = WeaponResult.Ok(value, rpcContext.correlationId)
    result.reconcile = value.typeChanged
    return result
end

function AmmoService.SwitchSlot(source, rpcContext, params)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    params = type(params) == 'table' and params or {}
    local slot = WeaponRuntime.NormalizeSlot(params.slot)
    local equipped, failure = GetEquipped(source, rpcContext, slot)
    if not equipped then return failure end

    local leaseFailure = ValidateLease(source, equipped, rpcContext, params)
    if leaseFailure then return leaseFailure end

    local ammunitionType = params.ammunitionType
    local ammunition = DefinitionRegistry.Get('ammunition', ammunitionType)
    if not ammunition.ok then return ammunition end

    local definitionResult = DefinitionRegistry.Get('weapon', equipped.definitionId)
    if not definitionResult.ok then return definitionResult end

    local definition = definitionResult.value
    if not WeaponValidation.AcceptsAmmunition(definition, ammunitionType) then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            'This ammunition is not compatible with the selected weapon', { slot = slot }, rpcContext.correlationId)
    end

    local refillAmount = math.max(1, math.floor(tonumber(Config.Escrow and Config.Escrow.refillAmount) or 50))
    local requested = math.floor(tonumber(params.amount) or refillAmount)
    if requested < 1 then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            'Ammunition amount must be a positive integer', nil, rpcContext.correlationId)
    end

    requested = math.min(requested, refillAmount)

    local runtime = WeaponRuntime.Get(source)
    local otherPoolTotal = 0
    for _, candidate in ipairs(WeaponConstants.LoadoutSlots) do
        local other = runtime and runtime.slots and runtime.slots[candidate] or nil
        if candidate ~= slot and other and other.nativeAmmoName == ammunition.value.nativeAmmoName then
            otherPoolTotal = otherPoolTotal + (tonumber(other.ammo) or 0)
        end
    end

    local context = Context(source, rpcContext, 'slot_ammo_switch')
    local transactionResult = InventoryAdapter.Transaction(context, function(tx)
        local item = tx:GetItemForUpdate(equipped.itemInstanceId)
        if not item then
            return WeaponResult.Error(WeaponErrors.ITEM_NOT_OWNED,
                'Selected weapon is no longer owned', nil, context.correlationId)
        end

        local metadataResult = WeaponMetadata.Validate(item.metadata, definition, context.correlationId)
        if not metadataResult.ok then return metadataResult end

        local previousType = item.metadata.ammo.type or definition.ammunitionType
        if previousType == ammunitionType then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                'This ammunition type is already loaded', { slot = slot }, context.correlationId)
        end

        if definition.multiTypeAmmunition == true then
            WeaponMetadata.EnsureAmmunitionPools(item.metadata, definition)
            local owned = item.metadata.ammo.pools[ammunitionType] or 0
            if owned < 1 then
                return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                    'Load this ammunition type before selecting it', { slot = slot }, context.correlationId)
            end
            WeaponMetadata.ProjectAmmunitionPool(item.metadata, definition, ammunitionType)
            if not tx:SetMetadata(item.id, item.metadata, item.metadataRevision) then
                return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                    'Weapon metadata changed during ammunition selection', nil, context.correlationId)
            end
            return {
                slot = slot, itemInstanceId = item.id,
                ammunitionType = ammunitionType, nativeAmmoName = ammunition.value.nativeAmmoName,
                total = owned, loaded = item.metadata.ammo.loaded,
                reserve = item.metadata.ammo.reserve, moved = 0, returned = 0,
                inventoryAmmo = tx:GetQuantity(ammunition.value.itemName), typeChanged = true
            }
        end

        local previous = DefinitionRegistry.Get('ammunition', previousType)
        if not previous.ok then return previous end

        local oldLoaded = math.max(0, math.floor(tonumber(item.metadata.ammo.loaded) or 0))
        local oldReserve = math.max(0, math.floor(tonumber(item.metadata.ammo.reserve) or 0))
        local returned = oldLoaded + oldReserve

        local maxTotal = WeaponValidation.EscrowMaximum(definition, ammunitionType)
        local capacity = math.max(0, maxTotal - otherPoolTotal)
        local available = math.max(0, math.floor(tonumber(tx:GetQuantity(ammunition.value.itemName)) or 0))
        local moved = math.min(requested, capacity, available)
        if moved <= 0 then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                'No selected ammunition can enter this weapon', {
                    slot = slot, available = available, capacity = capacity
                }, context.correlationId)
        end

        if not tx:RemoveQuantity(ammunition.value.itemName, moved) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                'Selected ammunition changed during switching', nil, context.correlationId)
        end

        if returned > 0 and not tx:AddQuantity(previous.value.itemName, returned) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                'Inventory cannot accept the ammunition being replaced', nil,
                context.correlationId)
        end

        local loaded = math.min(definition.capacity, moved)
        item.metadata.ammo.type = ammunitionType
        item.metadata.ammo.loaded = loaded
        item.metadata.ammo.reserve = moved - loaded
        item.metadata.ammo.chambered = loaded > 0
        if not tx:SetMetadata(item.id, item.metadata, item.metadataRevision) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                'Weapon metadata changed during ammunition switching', nil, context.correlationId)
        end

        return {
            slot = slot,
            itemInstanceId = item.id,
            ammunitionType = ammunitionType,
            previousAmmunitionType = previousType,
            nativeAmmoName = ammunition.value.nativeAmmoName,
            total = moved,
            loaded = loaded,
            reserve = moved - loaded,
            moved = moved,
            returned = returned,
            inventoryAmmo = tx:GetQuantity(ammunition.value.itemName),
            typeChanged = true
        }
    end)

    if not transactionResult.ok then return transactionResult end

    local value = transactionResult.value
    WeaponRuntime.SetSlotAmmunitionType(source, rpcContext.sessionId, slot, value.ammunitionType)
    WeaponRuntime.SetSlotAmmo(source, rpcContext.sessionId, slot, value.total, value.loaded, rpcContext.correlationId)
    local result = WeaponResult.Ok(value, rpcContext.correlationId)
    result.reconcile = true
    return result
end

function AmmoService.GetInventoryAvailability(source, rpcContext)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    local runtime = WeaponRuntime.Get(source)
    if not runtime or runtime.sessionId ~= rpcContext.sessionId then
        return WeaponResult.Error(WeaponErrors.SESSION_EXPIRED,
            'Character session is no longer active', nil, rpcContext.correlationId)
    end

    local context = Context(source, rpcContext, 'ammunition_menu')
    local transactionResult = InventoryAdapter.Transaction(context, function(tx)
        -- The Inventory adapter scopes quantity reads through an owned weapon
        -- instance so it can resolve the character inventory ID.
        local anchor = nil
        for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
            if runtime.slots and runtime.slots[slot] then
                anchor = runtime.slots[slot]
                break
            end
        end

        if not anchor or not tx:GetItemForUpdate(anchor.itemInstanceId) then
            return WeaponResult.Error(WeaponErrors.ITEM_NOT_OWNED,
                'An equipped weapon is required to inspect ammunition', nil, context.correlationId)
        end

        local quantities = {}
        for id, definition in pairs(WeaponDefinitionCatalog.ammunition or {}) do
            local quantity = math.max(0,
                math.floor(tonumber(tx:GetQuantity(definition.itemName)) or 0))
            if quantity > 0 then quantities[id] = quantity end
        end
        return quantities
    end)

    if not transactionResult.ok then return transactionResult end

    return WeaponResult.Ok({ quantities = transactionResult.value }, rpcContext.correlationId)
end

function AmmoService.Unload(source, rpcContext, requested, requestedSlot, lease)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    local runtime = WeaponRuntime.Get(source)
    local slots = runtime and runtime.slots or nil
    local slot = WeaponRuntime.NormalizeSlot(requestedSlot)
    if not slot then
        local selectedAmmo = -1
        for _, candidate in ipairs(WeaponConstants.LoadoutSlots) do
            local equipped = slots and slots[candidate] or nil
            if equipped then
                local candidateAmmo = tonumber(equipped.ammo) or 0
                if candidateAmmo > selectedAmmo then
                    slot, selectedAmmo = candidate, candidateAmmo
                end
            end
        end
    end

    slot = slot or 'primary'
    local equipped, failure = GetEquipped(source, rpcContext, slot)
    if not equipped then return failure end

    if lease then
        lease.slot = slot
        local leaseFailure = ValidateLease(source, equipped, rpcContext, lease)
        if leaseFailure then return leaseFailure end
    end

    if requested ~= nil then requested = math.floor(tonumber(requested) or -1) end

    if requested ~= nil and requested < 1 then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID, 'Ammunition amount must be a positive integer', nil, rpcContext.correlationId)
    end

    local definitionResult = DefinitionRegistry.Get('weapon', equipped.definitionId)
    if not definitionResult.ok then return definitionResult end

    local definition = definitionResult.value
    local context = Context(source, rpcContext, 'unload')
    local allTypes = lease and lease.allTypes == true
    if allTypes and (definition.multiTypeAmmunition ~= true or requested ~= nil) then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            'Unload-all-types requires a multi-type carrier and no partial amount', nil, rpcContext.correlationId)
    end
    local transactionResult = InventoryAdapter.Transaction(context, function(tx)
        local item = tx:GetItemForUpdate(equipped.itemInstanceId)
        if not item then
            return WeaponResult.Error(WeaponErrors.ITEM_NOT_OWNED, 'Equipped weapon is no longer owned', nil, context.correlationId)
        end

        local metadataResult = WeaponMetadata.Validate(item.metadata, definition, context.correlationId)
        if not metadataResult.ok then return metadataResult end

        if allTypes then
            WeaponMetadata.EnsureAmmunitionPools(item.metadata, definition)
            local returned, moved = {}, 0
            for _, id in ipairs(definition.ammunitionTypes) do
                local amount = item.metadata.ammo.pools[id] or 0
                if amount > 0 then
                    local ammunition = DefinitionRegistry.Get('ammunition', id)
                    if not ammunition.ok then return ammunition end
                    if not tx:AddQuantity(ammunition.value.itemName, amount) then
                        return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                            'Inventory cannot accept all unloaded ammunition', nil, context.correlationId)
                    end
                    returned[id], moved = amount, moved + amount
                end
                item.metadata.ammo.pools[id] = 0
                if item.metadata.ammo.clips then item.metadata.ammo.clips[id] = 0 end
            end
            if moved == 0 then
                return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                    'All ammunition pools are already empty', nil, context.correlationId)
            end
            WeaponMetadata.ProjectAmmunitionPool(item.metadata, definition, item.metadata.ammo.type)
            if not tx:SetMetadata(item.id, item.metadata, item.metadataRevision) then
                return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                    'Weapon metadata changed during ammunition operation', nil, context.correlationId)
            end
            return { total = 0, loaded = 0, reserve = 0, moved = moved,
                returnedPools = returned, nativeAmmoName = equipped.nativeAmmoName }
        end

        local loaded = tonumber(item.metadata.ammo.loaded) or 0
        local reserve = tonumber(item.metadata.ammo.reserve) or 0
        local total = loaded + reserve
        local ammunition = DefinitionRegistry.Get('ammunition', item.metadata.ammo.type or definition.ammunitionType)
        if not ammunition.ok then return ammunition end

        local ammunitionItem = ammunition.value.itemName
        local moved = math.min(total, requested or total)
        if moved <= 0 then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, 'The equipped weapon is already empty', nil,
                context.correlationId)
        end

        if not tx:AddQuantity(ammunitionItem, moved) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                'Inventory cannot accept the unloaded ammunition', nil, context.correlationId)
        end

        local remaining = total - moved
        item.metadata.ammo.loaded = math.min(loaded, remaining)
        item.metadata.ammo.reserve = remaining - item.metadata.ammo.loaded
        item.metadata.ammo.chambered = item.metadata.ammo.loaded > 0
        WeaponMetadata.SaveSelectedAmmunitionPool(item.metadata, definition)
        if not tx:SetMetadata(item.id, item.metadata, item.metadataRevision) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                'Weapon metadata changed during ammunition operation', nil, context.correlationId)
        end

        return {
            total = remaining,
            loaded = item.metadata.ammo.loaded,
            reserve = item.metadata.ammo.reserve,
            moved = moved,
            inventoryAmmo = tx:GetQuantity(ammunitionItem),
            nativeAmmoName = equipped.nativeAmmoName
        }
    end)

    if not transactionResult.ok then return transactionResult end

    if allTypes and equipped.ammoPools then
        for id in pairs(equipped.ammoPools) do equipped.ammoPools[id] = 0 end
    end
    WeaponRuntime.SetSlotAmmo(source, rpcContext.sessionId, slot,
        transactionResult.value.total, transactionResult.value.loaded, rpcContext.correlationId)
    transactionResult.value.slot = slot
    return WeaponResult.Ok(transactionResult.value, rpcContext.correlationId)
end

-- Multi-type checkpoints may consume existing ownership, never mint native
-- pickups. Poison-to-Regular recovery needs a separate exactly-once ledger.
function AmmoService.SyncPools(source, rpcContext, params)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    local slot = WeaponRuntime.NormalizeSlot(params and params.slot)
    local equipped, failure = GetEquipped(source, rpcContext, slot)
    if not equipped then return failure end
    local leaseFailure = ValidateLease(source, equipped, rpcContext, params)
    if leaseFailure then return leaseFailure end
    local definitionResult = DefinitionRegistry.Get('weapon', equipped.definitionId)
    if not definitionResult.ok then return definitionResult end
    local definition = definitionResult.value
    if definition.multiTypeAmmunition ~= true or type(params.pools) ~= 'table'
        or not WeaponValidation.AcceptsAmmunition(definition, params.ammunitionType) then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID, 'Invalid multi-type checkpoint', nil, rpcContext.correlationId)
    end
    for id, total in pairs(params.pools) do
        if not WeaponValidation.AcceptsAmmunition(definition, id) or type(total) ~= 'number'
            or total ~= total or total < 0 or total % 1 ~= 0
            or total > WeaponValidation.EscrowMaximum(definition, id) then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID, 'Invalid ammunition pool', nil, rpcContext.correlationId)
        end
    end
    local reportedLoaded = params.loaded
    if definition.family ~= 'throwing_knife' then
        if type(reportedLoaded) ~= 'number' or reportedLoaded ~= reportedLoaded
            or reportedLoaded % 1 ~= 0 or reportedLoaded < 0
            or reportedLoaded > definition.capacity
            or reportedLoaded > (params.pools[params.ammunitionType] or 0) then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
                'Multi-type firearm checkpoint requires a valid loaded count', nil, rpcContext.correlationId)
        end
    else
        reportedLoaded = nil
    end
    local result = InventoryAdapter.Transaction(Context(source, rpcContext, 'pool_checkpoint'), function(tx)
        local item = tx:GetItemForUpdate(equipped.itemInstanceId)
        if not item then return WeaponResult.Error(WeaponErrors.ITEM_NOT_OWNED, 'Weapon is no longer owned') end
        local valid = WeaponMetadata.Validate(item.metadata, definition, rpcContext.correlationId)
        if not valid.ok then return valid end
        WeaponMetadata.EnsureAmmunitionPools(item.metadata, definition)
        local pools = {}
        for _, id in ipairs(definition.ammunitionTypes) do
            local reported = params.pools[id]
            if reported == nil or reported > (item.metadata.ammo.pools[id] or 0) then
                return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
                    'Checkpoint cannot increase or omit ammunition ownership', nil, rpcContext.correlationId)
            end
            pools[id] = reported
        end
        item.metadata.ammo.pools = pools
        for id, amount in pairs(item.metadata.ammo.clips or {}) do
            item.metadata.ammo.clips[id] = math.min(amount, pools[id] or 0)
        end
        WeaponMetadata.ProjectAmmunitionPool(item.metadata, definition, params.ammunitionType, reportedLoaded)
        if not tx:SetMetadata(item.id, item.metadata, item.metadataRevision) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, 'Weapon metadata changed', nil, rpcContext.correlationId)
        end
        return { pools = pools, ammunitionType = item.metadata.ammo.type,
            total = item.metadata.ammo.loaded + item.metadata.ammo.reserve,
            loaded = item.metadata.ammo.loaded, reserve = item.metadata.ammo.reserve }
    end)
    if not result.ok then return result end
    local pools = {}
    for id, total in pairs(result.value.pools) do pools[id] = total end
    equipped.ammoPools = pools
    equipped.ammunitionType = result.value.ammunitionType
    equipped.nativeAmmoName = DefinitionRegistry.Get('ammunition', equipped.ammunitionType).value.nativeAmmoName
    WeaponRuntime.SetSlotAmmo(source, rpcContext.sessionId, slot, result.value.total, result.value.loaded, rpcContext.correlationId)
    return result
end

-- Commit a shared-pool observation atomically across item leases. A failure in
-- either hand must not consume the first hand while retaining the second.
function AmmoService.SyncPoolBatch(source, rpcContext, params)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    local reports = type(params) == 'table' and params.slots or nil
    if type(reports) ~= 'table' then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID, 'Pool batch requires slot reports')
    end
    local prepared, seen, count = {}, {}, 0
    for slot, report in pairs(reports) do
        if type(report) ~= 'table' or WeaponRuntime.NormalizeSlot(slot) ~= slot then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID, 'Invalid pool batch slot')
        end
        local equipped, failure = GetEquipped(source, rpcContext, slot)
        if not equipped then return failure end
        local lease = { slot = slot, itemInstanceId = report.itemInstanceId, generation = report.generation }
        failure = ValidateLease(source, equipped, rpcContext, lease)
        if failure then return failure end
        if seen[equipped.itemInstanceId] then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID, 'Duplicate item in pool batch')
        end
        seen[equipped.itemInstanceId], count = true, count + 1
        local definition = DefinitionRegistry.Get('weapon', equipped.definitionId)
        if not definition.ok then return definition end
        if definition.value.multiTypeAmmunition ~= true or definition.value.family == 'throwing_knife' then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID, 'Slot is not a multi-type firearm')
        end
        prepared[slot] = { equipped = equipped, definition = definition.value, report = report }
    end
    if count == 0 or count > 4 then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID, 'Pool batch requires one to four firearms')
    end
    local result = InventoryAdapter.Transaction(Context(source, rpcContext, 'pool_batch'), function(tx)
        local values = {}
        for slot, entry in pairs(prepared) do
            local report, definition = entry.report, entry.definition
            local item = tx:GetItemForUpdate(entry.equipped.itemInstanceId)
            if not item then return WeaponResult.Error(WeaponErrors.ITEM_NOT_OWNED, 'Batch item is no longer owned') end
            -- Acquiring an Inventory row may yield. Recheck the live lease
            -- rather than trusting the pre-transaction equipped reference.
            local current, currentFailure = GetEquipped(source, rpcContext, slot)
            if not current then return currentFailure end
            local leaseFailure = ValidateLease(source, current, rpcContext, {
                slot = slot, itemInstanceId = report.itemInstanceId, generation = report.generation
            })
            if leaseFailure then return leaseFailure end
            local valid = WeaponMetadata.Validate(item.metadata, definition, rpcContext.correlationId)
            if not valid.ok then return valid end
            WeaponMetadata.EnsureAmmunitionPools(item.metadata, definition)
            if type(report.pools) ~= 'table' or not WeaponValidation.AcceptsAmmunition(definition, report.ammunitionType) then
                return WeaponResult.Error(WeaponErrors.ITEM_INVALID, 'Invalid batch ammunition selection')
            end
            local pools = {}
            for id, amount in pairs(report.pools) do
                if not WeaponValidation.AcceptsAmmunition(definition, id)
                    or type(amount) ~= 'number' or amount ~= amount or amount < 0 or amount % 1 ~= 0
                    or amount > (item.metadata.ammo.pools[id] or 0) then
                    return WeaponResult.Error(WeaponErrors.ITEM_INVALID, 'Batch cannot increase ammunition ownership')
                end
            end
            for _, id in ipairs(definition.ammunitionTypes) do
                if report.pools[id] == nil then
                    return WeaponResult.Error(WeaponErrors.ITEM_INVALID, 'Batch cannot omit an ammunition pool')
                end
                pools[id] = report.pools[id]
            end
            local loaded = report.loaded
            if type(loaded) ~= 'number' or loaded ~= loaded or loaded < 0 or loaded % 1 ~= 0
                or loaded > definition.capacity or loaded > pools[report.ammunitionType] then
                return WeaponResult.Error(WeaponErrors.ITEM_INVALID, 'Invalid batch loaded count')
            end
            item.metadata.ammo.pools = pools
            for id, amount in pairs(item.metadata.ammo.clips or {}) do
                item.metadata.ammo.clips[id] = math.min(amount, pools[id] or 0)
            end
            WeaponMetadata.ProjectAmmunitionPool(item.metadata, definition, report.ammunitionType, loaded)
            if not tx:SetMetadata(item.id, item.metadata, item.metadataRevision) then
                return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, 'Pool batch metadata changed')
            end
            values[slot] = { pools = pools, ammunitionType = report.ammunitionType,
                total = pools[report.ammunitionType], loaded = loaded,
                reserve = pools[report.ammunitionType] - loaded }
        end
        return { slots = values }
    end)
    if not result.ok then return result end
    for slot, value in pairs(result.value.slots) do
        local equipped = prepared[slot].equipped
        equipped.ammoPools = value.pools
        equipped.ammunitionType = value.ammunitionType
        equipped.nativeAmmoName = DefinitionRegistry.Get('ammunition', value.ammunitionType).value.nativeAmmoName
        WeaponRuntime.SetSlotAmmo(source, rpcContext.sessionId, slot, value.total, value.loaded, rpcContext.correlationId)
    end
    return result
end

function AmmoService.SyncConsumption(source, rpcContext, params)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    local slot = WeaponRuntime.NormalizeSlot(params and params.slot) or 'primary'
    local equipped, failure = GetEquipped(source, rpcContext, slot)
    if not equipped then return failure end

    local leaseFailure = ValidateLease(source, equipped, rpcContext, params)
    if leaseFailure then return leaseFailure end

    local reportedTotal = math.floor(tonumber(params and params.total) or -1)
    local reportedLoaded = math.floor(tonumber(params and params.loaded) or -1)
    local definitionResult = DefinitionRegistry.Get('weapon', equipped.definitionId)
    if not definitionResult.ok then return definitionResult end

    local definition = definitionResult.value
    local recoveryKey = RecoveryCreditKey(source, rpcContext, equipped)
    if definition.multiTypeAmmunition == true then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID, 'Multi-type weapons require a pool checkpoint', nil, rpcContext.correlationId)
    end
    local recoveryCredit = math.max(0, math.floor(tonumber(throwableRecoveryCredits[recoveryKey]) or 0))
    local maxTotal = WeaponValidation.EscrowMaximum(definition, equipped.ammunitionType)

    if reportedTotal < 0 or reportedTotal > maxTotal or reportedLoaded < 0
        or reportedLoaded > definition.capacity or reportedLoaded > reportedTotal then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID, 'Reported ammunition is outside the approved range', nil, rpcContext.correlationId)
    end

    local context = Context(source, rpcContext, 'fire_checkpoint')
    local transactionResult = InventoryAdapter.Transaction(context, function(tx)
        local item = tx:GetItemForUpdate(equipped.itemInstanceId)
        if not item then
            return WeaponResult.Error(WeaponErrors.ITEM_NOT_OWNED, 'Equipped weapon is no longer owned', nil, context.correlationId)
        end

        local current = tonumber(item.metadata.ammo.loaded) or 0
        local currentReserve = tonumber(item.metadata.ammo.reserve) or 0
        local currentTotal = current + currentReserve
        local recovered = math.max(0, reportedTotal - currentTotal)
        if recovered > 0 and (definition.slot ~= 'throwable' or recovered > recoveryCredit) then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
                'Ammunition recovery exceeds the committed throwable recovery credit', {
                    requested = recovered,
                    available = definition.slot == 'throwable' and recoveryCredit or 0
                }, context.correlationId)
        end

        local consumed = math.max(0, currentTotal - reportedTotal)
        item.metadata.ammo.loaded = reportedLoaded
        item.metadata.ammo.reserve = reportedTotal - reportedLoaded
        item.metadata.ammo.chambered = reportedLoaded > 0
        WeaponMetadata.SaveSelectedAmmunitionPool(item.metadata, definition)
        if not tx:SetMetadata(item.id, item.metadata, item.metadataRevision) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                'Weapon metadata changed during ammunition checkpoint', nil, context.correlationId)
        end

        return {
            total = reportedTotal,
            loaded = reportedLoaded,
            reserve = reportedTotal - reportedLoaded,
            consumed = consumed,
            recovered = recovered,
            condition = item.metadata.condition,
            broken = false
        }
    end)

    if not transactionResult.ok then return transactionResult end

    if definition.slot == 'throwable' then
        throwableRecoveryCredits[recoveryKey] = math.max(0,
            recoveryCredit + transactionResult.value.consumed - transactionResult.value.recovered)
    end

    WeaponRuntime.SetSlotAmmo(source, rpcContext.sessionId, slot, reportedTotal, reportedLoaded, rpcContext.correlationId)
    WeaponRuntime.SetSlotCondition(source, rpcContext.sessionId, slot, transactionResult.value.condition, rpcContext.correlationId)
    if transactionResult.value.broken then
        local persistResult = InventoryAdapter.SetEquippedSlotForCharacter(context, slot, nil)
        if not persistResult.ok then return persistResult end

        WeaponRuntime.Unequip(source, rpcContext.sessionId, rpcContext.correlationId, slot)
    end

    return WeaponResult.Ok(transactionResult.value, rpcContext.correlationId)
end

function AmmoService.SyncPair(source, rpcContext, params)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    local runtime = WeaponRuntime.Get(source)
    local slots = runtime and runtime.slots or nil
    params = type(params) == 'table' and params or {}
    local slotNames = type(params.slotNames) == 'table' and params.slotNames or { 'primary', 'offhand' }
    local firstSlot = WeaponRuntime.NormalizeSlot(slotNames[1])
    local secondSlot = WeaponRuntime.NormalizeSlot(slotNames[2])
    if not runtime or runtime.sessionId ~= rpcContext.sessionId
        or not slots or not firstSlot or not secondSlot or firstSlot == secondSlot
        or not slots[firstSlot] or not slots[secondSlot] then
        return WeaponResult.Error(WeaponErrors.NOT_EQUIPPED,
            'Both requested weapon slots must be equipped', nil, rpcContext.correlationId)
    end
    local reports = type(params.slots) == 'table' and params.slots or {}
    local reportedTotal = math.floor(tonumber(params.total) or -1)
    local prepared = {}
    local expectedTotal = 0
    local previousTotal = 0
    local firedTotal = 0
    local sharedAmmoPool = slots[firstSlot].nativeAmmoName == slots[secondSlot].nativeAmmoName
    local context = Context(source, rpcContext, 'pair_checkpoint')

    for _, slot in ipairs(slotNames) do
        local equipped = slots[slot]
        local report = type(reports[slot]) == 'table' and reports[slot] or {}
        if not WeaponRuntime.MatchesLease(source, rpcContext.sessionId,
                report.itemInstanceId, report.generation, slot) then
            return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
                'Weapon runtime lease is stale', { slot = slot,
                    expectedGeneration = equipped.generation }, rpcContext.correlationId)
        end

        local definitionResult = DefinitionRegistry.Get('weapon', equipped.definitionId)
        if not definitionResult.ok then return definitionResult end

        local itemResult = InventoryAdapter.GetItemForCharacter(context, equipped.itemInstanceId)
        if not itemResult.ok then return itemResult end

        local item = itemResult.value
        local metadataResult = WeaponMetadata.Validate(item.metadata, definitionResult.value, context.correlationId)
        if not metadataResult.ok then return metadataResult end

        local oldLoaded = math.floor(tonumber(item.metadata.ammo.loaded) or 0)
        local oldReserve = math.floor(tonumber(item.metadata.ammo.reserve) or 0)
        previousTotal = previousTotal + oldLoaded + oldReserve
        local loaded = math.floor(tonumber(report.loaded) or -1)
        if loaded < 0 or loaded > definitionResult.value.capacity then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
                'Reported loaded ammunition is outside weapon capacity', { slot = slot }, rpcContext.correlationId)
        end

        local fired = math.floor(tonumber(report.consumed) or -1)
        local reloaded = loaded - oldLoaded + fired
        if fired < 0 or reloaded < 0 then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
                'Reported pair ammunition transition is invalid', { slot = slot }, rpcContext.correlationId)
        end

        if reloaded > oldReserve then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
                'Native reload crossed weapon escrow ownership', {
                    slot = slot, requested = reloaded, reserve = oldReserve
                }, rpcContext.correlationId)
        end
        -- Native ammo pools are shared by ammunition hash, but inventory escrow is not.
        -- A shot or reload may only change the weapon instance that reported it.
        local nextReserve = oldReserve - reloaded
        local nextTotal = loaded + nextReserve
        expectedTotal = expectedTotal + nextTotal
        firedTotal = firedTotal + fired
        item.metadata.ammo.loaded = loaded
        item.metadata.ammo.reserve = nextReserve
        item.metadata.ammo.chambered = loaded > 0
        WeaponMetadata.SaveSelectedAmmunitionPool(item.metadata, definitionResult.value)
        prepared[slot] = {
            item = item,
            total = nextTotal,
            loaded = loaded,
            reserve = nextReserve,
            maxTotal = WeaponValidation.EscrowMaximum(
                definitionResult.value, item.metadata.ammo.type or definitionResult.value.ammunitionType),
            fired = fired,
            condition = item.metadata.condition
        }
    end

    if sharedAmmoPool then
        if reportedTotal ~= previousTotal - firedTotal then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
                'Shared ammunition pool consumption is inconsistent', {
                    reported = reportedTotal, previous = previousTotal, fired = firedTotal
                }, rpcContext.correlationId)
        end
    end

    if reportedTotal ~= expectedTotal then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            'Shared native ammunition does not match weapon escrow', {
                reported = reportedTotal, expected = expectedTotal
            }, rpcContext.correlationId)
    end

    local mutations = {}
    for _, slot in ipairs(slotNames) do
        local value = prepared[slot]
        mutations[#mutations + 1] = {
            itemInstanceId = value.item.id,
            expectedRevision = value.item.metadataRevision,
            metadata = value.item.metadata
        }
    end

    local committed = InventoryAdapter.MutateWeaponMetadataBatch(context, mutations)
    if not committed.ok then return committed end

    local responseSlots = {}
    for _, slot in ipairs(slotNames) do
        local value = prepared[slot]
        WeaponRuntime.SetSlotAmmo(source, rpcContext.sessionId, slot,
            value.total, value.loaded, rpcContext.correlationId)
        WeaponRuntime.SetSlotCondition(source, rpcContext.sessionId, slot,
            value.condition, rpcContext.correlationId)
        responseSlots[slot] = {
            total = value.total,
            loaded = value.loaded,
            reserve = value.reserve,
            consumed = value.fired,
            condition = value.condition
        }
    end

    if Config.DevMode then
        print(('[feather-weapons] pair checkpoint total=%d %s=%d/%d consumed=%d condition=%s %s=%d/%d consumed=%d condition=%s')
            :format(reportedTotal,
                firstSlot, responseSlots[firstSlot].loaded, responseSlots[firstSlot].reserve,
                responseSlots[firstSlot].consumed, tostring(responseSlots[firstSlot].condition),
                secondSlot, responseSlots[secondSlot].loaded, responseSlots[secondSlot].reserve,
                responseSlots[secondSlot].consumed, tostring(responseSlots[secondSlot].condition)))
    end

    return WeaponResult.Ok({ total = reportedTotal, slots = responseSlots }, rpcContext.correlationId)
end

FeatherCore.RPC.Register('feather-weapons:ammo:unload', function(params, respond, source, context)
    if params and params.allTypes == true and not params.itemInstanceId then
        respond(WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            'Unload-all-types requires an equipped weapon lease', nil, context.correlationId))
        return
    end
    respond(AmmoService.Unload(source, context, params and params.amount,
        params and params.slot, params and params.itemInstanceId and params or nil))
end, { requireCharacter = true, windowMs = 1000, maxCalls = 4, maxPayloadBytes = 256 })

FeatherCore.RPC.Register('feather-weapons:ammo:loadSlot', function(params, respond, source, context)
    respond(AmmoService.LoadSlot(source, context, params))
end, { requireCharacter = true, windowMs = 1000, maxCalls = 4, maxPayloadBytes = 384 })

FeatherCore.RPC.Register('feather-weapons:ammo:switchSlot', function(params, respond, source, context)
    respond(AmmoService.SwitchSlot(source, context, params))
end, { requireCharacter = true, windowMs = 1000, maxCalls = 4, maxPayloadBytes = 384 })

FeatherCore.RPC.Register('feather-weapons:ammo:availability', function(_, respond, source, context)
    respond(AmmoService.GetInventoryAvailability(source, context))
end, { requireCharacter = true, windowMs = 1000, maxCalls = 4, maxPayloadBytes = 64 })

FeatherCore.RPC.Register('feather-weapons:ammo:sync', function(params, respond, source, context)
    respond(AmmoService.SyncConsumption(source, context, params))
end, { requireCharacter = true, windowMs = 5000, maxCalls = 12, maxPayloadBytes = 256 })

FeatherCore.RPC.Register('feather-weapons:ammo:syncPools', function(params, respond, source, context)
    respond(AmmoService.SyncPools(source, context, params))
end, { requireCharacter = true, windowMs = 5000, maxCalls = 12, maxPayloadBytes = 768 })

FeatherCore.RPC.Register('feather-weapons:ammo:pairSync', function(params, respond, source, context)
    respond(AmmoService.SyncPair(source, context, params))
end, { requireCharacter = true, windowMs = 5000, maxCalls = 12, maxPayloadBytes = 768 })

FeatherCore.RPC.Register('feather-weapons:ammo:syncPoolBatch', function(params, respond, source, context)
    respond(AmmoService.SyncPoolBatch(source, context, params))
end, { requireCharacter = true, windowMs = 5000, maxCalls = 12, maxPayloadBytes = 4096 })
