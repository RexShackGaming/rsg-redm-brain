local FeatherInventoryProvider = {}
-- Kept as a table so every adapter call has one stable API shape. Failed
-- installation attempts clear the cached surface before returning.
---@type table
local Inventory = {}
local DefinitionIds = {}
local WeaponDefinitionsByInventoryId = {}
local MissingDefinitions = {}
local DuplicateDefinitions = {}

-- Capabilities as reported by feather-inventory, validated once at install
-- time and cached. This is the REAL contract version -- it is deliberately
-- not Config.Inventory.requiredContract, which is what we demand rather than
-- what the provider offers. Reporting our own requirement back to ourselves
-- is how the previous version of this gate came to compare 1 < 1 and could
-- never fail.
local InventoryCapabilities = nil

local function IsCallable(value)
    return type(value) == "function"
        or (type(value) == "table"
            and type(rawget(value, "__cfx_functionReference")) == "string")
end

local function Failure(context, message, details)
    return WeaponResult.Error(WeaponErrors.INVENTORY_UNAVAILABLE, message, details, context and context.correlationId)
end

local function NormalizeItem(item)
    if type(item) ~= "table" then return nil end
    return {
        id = item.id,
        inventoryId = item.inventoryId,
        itemName = item.definition and item.definition.name or nil,
        metadata = item.metadata,
        metadataRevision = item.revision,
        definitionId = item.definition and item.definition.id or nil
    }
end

-- Returns a WeaponResult so a failure can stop installation instead of
-- leaving the index silently empty. An empty index is indistinguishable from
-- "this server has no weapons configured", which is exactly the wrong thing
-- to report when the real answer is "inventory did not answer".
local function BuildDefinitionIndex()
    DefinitionIds = {}
    WeaponDefinitionsByInventoryId = {}
    DuplicateDefinitions = {}
    local definitionsByName = {}

    local listed = Inventory.Items.GetDefinitions()
    if type(listed) ~= "table" or listed.ok ~= true then
        local failure = type(listed) == "table" and listed.error or nil
        return Failure(nil, "Inventory item definitions are unavailable", {
            code = failure and failure.code,
            reason = failure and failure.message
        })
    end

    local definitions = listed.value
    for _, definition in pairs(definitions or {}) do
        local name, id = definition.name, tonumber(definition.id)
        if name and id then
            definitionsByName[name] = definitionsByName[name] or definition
            local current = DefinitionIds[name]
            if current then
                DuplicateDefinitions[name] = DuplicateDefinitions[name] or { current }
                DuplicateDefinitions[name][#DuplicateDefinitions[name] + 1] = id
            end
            if not current or id < current then DefinitionIds[name] = id end
        end
    end

    for name, ids in pairs(DuplicateDefinitions) do
        table.sort(ids)
        print(("[feather-weapons] duplicate inventory definition name=%s ids=%s canonical=%s"):format(
            tostring(name), table.concat(ids, ","), tostring(DefinitionIds[name])))
    end

    MissingDefinitions = {}
    local required = {
        gun_oil = true
    }
    for itemName in pairs(WeaponDefinitionCatalog.ammunition or {}) do
        required[itemName] = true
    end
    for _, attachment in pairs(WeaponDefinitionCatalog.attachments or {}) do
        required[attachment.itemName] = true
    end
    for _, definition in pairs(WeaponDefinitionCatalog.weapons or {}) do
        required[definition.itemName] = true
    end
    for name in pairs(required) do
        if not DefinitionIds[name] then MissingDefinitions[#MissingDefinitions + 1] = name end
    end
    table.sort(MissingDefinitions)

    if #MissingDefinitions > 0 then
        return Failure(nil, "Required Inventory item definitions are missing", {
            missing = MissingDefinitions
        })
    end
    if next(DuplicateDefinitions) ~= nil then
        return Failure(nil, "Duplicate Inventory item definitions are not supported", {
            duplicates = DuplicateDefinitions
        })
    end

    local expected = {
        gun_oil = { instanceMode = "stack", usable = true, type = "item_item" }
    }
    for itemName in pairs(WeaponDefinitionCatalog.ammunition or {}) do
        expected[itemName] = { instanceMode = "stack", usable = true, type = "item_ammo" }
    end
    for _, attachment in pairs(WeaponDefinitionCatalog.attachments or {}) do
        expected[attachment.itemName] = { instanceMode = "stack", usable = false, type = "item_item" }
    end
    for _, definition in pairs(WeaponDefinitionCatalog.weapons or {}) do
        expected[definition.itemName] = { instanceMode = "unique", usable = true, type = "item_weapon" }
    end
    local mismatches = {}
    for name, rules in pairs(expected) do
        local definition = definitionsByName[name]
        local usable = definition.usable == true or tonumber(definition.usable) == 1
        local actualMode = definition.instanceMode or definition.instance_mode
        if actualMode ~= rules.instanceMode or usable ~= rules.usable or definition.type ~= rules.type then
            mismatches[#mismatches + 1] = {
                name = name,
                expected = rules,
                actual = { instanceMode = actualMode, usable = usable, type = definition.type }
            }
        end
    end
    if #mismatches > 0 then
        return Failure(nil, "Inventory item definitions do not match the Weapons contract", {
            mismatches = mismatches
        })
    end

    for definitionId, definition in pairs(WeaponDefinitionCatalog.weapons or {}) do
        local inventoryDefinitionId = DefinitionIds[definition.itemName]
        if inventoryDefinitionId then
            WeaponDefinitionsByInventoryId[inventoryDefinitionId] = definitionId
        end
    end

    return WeaponResult.Ok(true)
end

function FeatherInventoryProvider.GetCapabilities()
    -- Read from the validated cache, not by re-querying: the provider is not
    -- installed until the contract has been checked, so there is no state in
    -- which this should be asking again and reaching a different answer.
    local capabilities = InventoryCapabilities or {}
    return {
        -- The provider's OWN reported contract version. Reporting
        -- Config.Inventory.requiredContract here is what made the gate in
        -- InventoryAdapter.InstallProvider compare a value against itself.
        contractVersion = tonumber(capabilities.contractVersion) or 0,
        provider = "feather-inventory",
        inventoryVersion = capabilities.version,
        features = capabilities.features,
        characterIdentity = capabilities.characterIdentity,
        uniqueItems = capabilities.features and capabilities.features.instanceMode == true,
        equippedState = capabilities.features and capabilities.features.equippedState == true,
        reconnectPersistence = true,
        resourceRestartPersistence = true,
        transactions = capabilities.features and capabilities.features.transactions == true,
        atomicCreation = capabilities.features and capabilities.features.atomicCreation == true,
        missingDefinitions = MissingDefinitions,
        duplicateDefinitions = DuplicateDefinitions
    }
end

function FeatherInventoryProvider.GetItemForCharacter(context, itemInstanceId)
    local result = Inventory.GetItemForCharacter(context.characterId, itemInstanceId)
    if not result.ok then return result end
    return WeaponResult.Ok(NormalizeItem(result.value), context.correlationId)
end

function FeatherInventoryProvider.GetInstance(context, itemInstanceId)
    local result = Inventory.Instances.GetInstance(itemInstanceId)
    if not result.ok then return result end
    return WeaponResult.Ok(NormalizeItem(result.value), context and context.correlationId)
end

function FeatherInventoryProvider.GetCharacterInventory(context, characterId)
    local result = Inventory.GetCharacterInventory(characterId)
    if not result.ok then return result end
    return WeaponResult.Ok(result.value, context and context.correlationId)
end

function FeatherInventoryProvider.DestroyInstance(context, item)
    local result = Inventory.DestroyInstances(context, {
        inventoryId = item.inventoryId,
        expectedLocation = "character",
        instanceIds = { item.id }
    })
    if not result.ok then return result end
    return WeaponResult.Ok(result.value, context and context.correlationId)
end

function FeatherInventoryProvider.ResolveWeaponDefinitionId(inventoryDefinitionId)
    return WeaponDefinitionsByInventoryId[tonumber(inventoryDefinitionId)]
end

function FeatherInventoryProvider.GetEquippedForCharacter(context)
    local result = Inventory.GetEquippedForCharacter(context.characterId, Config.Inventory.equipmentSlot)
    if not result.ok then return result end
    return WeaponResult.Ok(result.value, context.correlationId)
end

function FeatherInventoryProvider.SetEquippedForCharacter(context, itemInstanceId)
    local result = Inventory.SetEquippedForCharacter(context.characterId, Config.Inventory.equipmentSlot, itemInstanceId)
    if not result.ok then return result end
    return WeaponResult.Ok(itemInstanceId, context.correlationId)
end

function FeatherInventoryProvider.GetEquippedSlotsForCharacter(context)
    local result = Inventory.GetEquippedForCharacter(context.characterId)
    if not result.ok then return result end
    local configured = Config.Inventory.equipmentSlots or {}
    return WeaponResult.Ok({
        utility_senary = result.value and result.value[configured.utility_senary or "weapon_utility_senary"] or nil,
        utility_septenary = result.value and result.value[configured.utility_septenary or "weapon_utility_septenary"] or nil,
        utility_octonary = result.value and result.value[configured.utility_octonary or "weapon_utility_octonary"] or nil,
        utility_quinary = result.value and result.value[configured.utility_quinary or "weapon_utility_quinary"] or nil,
        utility_quaternary = result.value and result.value[configured.utility_quaternary or "weapon_utility_quaternary"] or nil,
        utility_tertiary = result.value and result.value[configured.utility_tertiary or "weapon_utility_tertiary"] or nil,
        utility_secondary = result.value and result.value[configured.utility_secondary or "weapon_utility_secondary"] or nil,
        utility = result.value and result.value[configured.utility or "weapon_utility"] or nil,
        primary = result.value and result.value[configured.primary or Config.Inventory.equipmentSlot] or nil,
        offhand = result.value and result.value[configured.offhand or "weapon_offhand"] or nil,
        shoulder = result.value and result.value[configured.shoulder or "weapon_shoulder"] or nil,
        back = result.value and result.value[configured.back or "weapon_back"] or nil,
        melee = result.value and result.value[configured.melee or "weapon_melee"] or nil,
        melee_secondary = result.value
            and result.value[configured.melee_secondary or "weapon_melee_secondary"] or nil,
        melee_tertiary = result.value
            and result.value[configured.melee_tertiary or "weapon_melee_tertiary"] or nil,
        melee_quinary = result.value and result.value[configured.melee_quinary or "weapon_melee_quinary"] or nil,
        melee_quaternary = result.value
            and result.value[configured.melee_quaternary or "weapon_melee_quaternary"] or nil,
        throwable = result.value
            and result.value[configured.throwable or "weapon_throwable"] or nil,
        throwable_secondary = result.value
            and result.value[configured.throwable_secondary or "weapon_throwable_secondary"] or nil,
        throwable_tertiary = result.value
            and result.value[configured.throwable_tertiary or "weapon_throwable_tertiary"] or nil,
        throwable_quaternary = result.value
            and result.value[configured.throwable_quaternary or "weapon_throwable_quaternary"] or nil,
        throwable_quinary = result.value
            and result.value[configured.throwable_quinary or "weapon_throwable_quinary"] or nil,
        throwable_senary = result.value
            and result.value[configured.throwable_senary or "weapon_throwable_senary"] or nil,
        throwable_septenary = result.value
            and result.value[configured.throwable_septenary or "weapon_throwable_septenary"] or nil,
        throwable_octonary = result.value
            and result.value[configured.throwable_octonary or "weapon_throwable_octonary"] or nil,
        throwable_nonary = result.value
            and result.value[configured.throwable_nonary or "weapon_throwable_nonary"] or nil,
        throwable_denary = result.value
            and result.value[configured.throwable_denary or "weapon_throwable_denary"] or nil
    }, context.correlationId)
end

function FeatherInventoryProvider.ListWeaponsForCharacter(context)
    local inventoryResult = Inventory.GetCharacterInventory(context.characterId)
    if not inventoryResult.ok then return inventoryResult end
    local itemsResult = Inventory.Inventory.GetInventoryItems(inventoryResult.value.id)
    if not itemsResult.ok then return itemsResult end
    local weapons = {}
    for _, raw in ipairs(itemsResult.value or {}) do
        local item = NormalizeItem(raw)
        local definitionId = item and type(item.metadata) == "table"
            and item.metadata.weaponDefinitionId or nil
        if definitionId and WeaponDefinitionCatalog.weapons[definitionId] then
            weapons[#weapons + 1] = item
        end
    end
    return WeaponResult.Ok(weapons, context.correlationId)
end

function FeatherInventoryProvider.SetEquippedSlotForCharacter(context, slot, itemInstanceId)
    local configured = Config.Inventory.equipmentSlots or {}
    local inventorySlot = configured[slot]
    if not inventorySlot then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID, "Weapon equipment slot is invalid", {
            slot = slot
        }, context.correlationId)
    end
    local result = Inventory.SetEquippedForCharacter(context.characterId, inventorySlot, itemInstanceId)
    if not result.ok then return result end
    return WeaponResult.Ok({ slot = slot, itemInstanceId = itemInstanceId }, context.correlationId)
end

function FeatherInventoryProvider.PromoteOffhandToPrimary(context)
    local configured = Config.Inventory.equipmentSlots or {}
    local result = Inventory.PromoteEquippedSlot(context.characterId,
        configured.offhand or "weapon_offhand",
        configured.primary or Config.Inventory.equipmentSlot)
    if not result.ok then return result end
    return WeaponResult.Ok({ itemInstanceId = result.value.instanceId,
        fromSlot = "offhand", toSlot = "primary" }, context.correlationId)
end

function FeatherInventoryProvider.CreateWeapon(context, definition, metadata)
    local definitionId = DefinitionIds[definition.itemName]
    if not definitionId then
        return Failure(context, "Weapon inventory definition is missing", { itemName = definition.itemName })
    end
    local result = Inventory.CreateInstance(context, {
        characterId = context.characterId,
        definitionId = definitionId,
        metadata = metadata
    })
    if not result.ok then return result end
    return WeaponResult.Ok(result.value, context.correlationId)
end

function FeatherInventoryProvider.Transaction(context, callback)
    local currentItem = nil
    local quantities = {}
    local quantityInstanceIds = {}
    local removals = {}
    local additions = {}
    local nextMetadata = nil
    local expectedRevision = nil
    local metadataUpdates = {}
    local metadataUpdateCount = 0
    local tx = {}

    function tx:GetItemForUpdate(itemInstanceId)
        local result = Inventory.GetItemForCharacter(context.characterId, itemInstanceId)
        if not result.ok then return nil end
        currentItem = NormalizeItem(result.value)
        return currentItem
    end

    function tx:GetQuantity(definitionName)
        if not currentItem then return 0 end
        if quantities[definitionName] == nil then
            local found = Inventory.Instances.FindInstances(currentItem.inventoryId, definitionName)
            quantityInstanceIds[definitionName] = found.ok and found.value or {}
            quantities[definitionName] = #quantityInstanceIds[definitionName]
        end
        return quantities[definitionName]
    end

    function tx:RemoveQuantity(definitionName, quantity)
        local catalogDefinitionId = DefinitionIds[definitionName]
        local wanted = math.floor(tonumber(quantity) or 0)
        local available = self:GetQuantity(definitionName)
        local item = currentItem
        if not item then return false end
        local ids = quantityInstanceIds[definitionName] or {}
        local first = ids[1] and Inventory.Instances.GetInstance(ids[1]) or nil
        local firstValue = first and first.ok and first.value or nil
        local definitionId = firstValue and firstValue.definition and tonumber(firstValue.definition.id)
            or catalogDefinitionId
        if Config.DevMode then
            print(("[feather-weapons] inventory removal planned inventory=%s actualInventory=%s item=%s definition=%s catalogDefinition=%s available=%s requested=%s firstInstance=%s")
                :format(
                    tostring(item.inventoryId), tostring(firstValue and firstValue.inventoryId),
                    tostring(definitionName), tostring(definitionId), tostring(catalogDefinitionId),
                    tostring(available), tostring(wanted), tostring(ids[1])))
        end
        if not definitionId or wanted < 1 or available < wanted then return false end
        local selected = {}
        for index = 1, wanted do
            local id = table.remove(ids, 1)
            local instance = id and Inventory.Instances.GetInstance(id) or nil
            local value = instance and instance.ok and instance.value or nil
            if not value or tostring(value.inventoryId) ~= tostring(item.inventoryId)
                or not value.definition or tonumber(value.definition.id) ~= tonumber(definitionId) then
                return false
            end
            selected[index] = id
        end
        quantities[definitionName] = #ids
        removals[definitionId] = removals[definitionId] or { quantity = 0, instanceIds = {} }
        removals[definitionId].quantity = removals[definitionId].quantity + wanted
        for _, id in ipairs(selected) do
            removals[definitionId].instanceIds[#removals[definitionId].instanceIds + 1] = id
        end
        return true
    end

    function tx:AddQuantity(definitionName, quantity, metadata)
        local definitionId = DefinitionIds[definitionName]
        local wanted = math.floor(tonumber(quantity) or 0)
        if not definitionId or wanted < 1 then return false end
        local available = self:GetQuantity(definitionName)
        quantities[definitionName] = available + wanted
        additions[definitionId] = additions[definitionId] or { quantity = 0, metadata = metadata }
        additions[definitionId].quantity = additions[definitionId].quantity + wanted
        return true
    end

    function tx:SetMetadata(itemInstanceId, metadata, revision)
        if not currentItem or tostring(currentItem.id) ~= tostring(itemInstanceId)
            or tonumber(currentItem.metadataRevision) ~= tonumber(revision) then
            return false
        end
        nextMetadata = metadata
        expectedRevision = revision
        local key = tostring(itemInstanceId)
        if not metadataUpdates[key] then metadataUpdateCount = metadataUpdateCount + 1 end
        metadataUpdates[key] = { itemInstanceId = itemInstanceId,
            expectedRevision = revision, metadata = metadata }
        return true
    end

    local ok, outcome = pcall(callback, tx)
    if not ok then
        return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, "Weapons inventory calculation failed", {
            reason = tostring(outcome)
        }, context.correlationId)
    end
    if type(outcome) == "table" and outcome.ok == false then return outcome end

    if nextMetadata ~= nil or next(removals) ~= nil or next(additions) ~= nil then
        if not currentItem then
            return WeaponResult.Error(WeaponErrors.ITEM_NOT_OWNED, "Weapon item is unavailable", nil,
                context.correlationId)
        end
        local removalList = {}
        for definitionId, removal in pairs(removals) do
            removalList[#removalList + 1] = {
                definitionId = definitionId,
                quantity = removal.quantity,
                instanceIds = removal.instanceIds
            }
        end
        local additionList = {}
        for definitionId, addition in pairs(additions) do
            additionList[#additionList + 1] = {
                definitionId = definitionId,
                quantity = addition.quantity,
                metadata = addition.metadata
            }
        end
        local committed
        if metadataUpdateCount > 1 then
            if next(removals) ~= nil or next(additions) ~= nil then
                return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                    'Multi-item metadata batches cannot include quantity changes', nil, context.correlationId)
            end
            local mutations = {}
            for _, mutation in pairs(metadataUpdates) do mutations[#mutations + 1] = mutation end
            table.sort(mutations, function(left, right)
                return tonumber(left.itemInstanceId) < tonumber(right.itemInstanceId)
            end)
            committed = Inventory.MutateItems(context, { items = mutations })
        else
        committed = Inventory.MutateItem(context, {
            itemInstanceId = currentItem.id,
            expectedRevision = expectedRevision or currentItem.metadataRevision,
            metadata = nextMetadata,
            removals = removalList,
            additions = additionList
        })
        end
        if not committed.ok then
            if Config.DevMode then
                local failure = committed.error or {}
                print(("[feather-weapons] inventory mutation failed inventory=%s code=%s message=%s details=%s"):format(
                    tostring(currentItem.inventoryId), tostring(failure.code), tostring(failure.message),
                    json.encode(failure.details or {})))
            end
            return committed
        end
    end

    return WeaponResult.Ok(outcome, context.correlationId)
end

function FeatherInventoryProvider.MutateWeaponMetadataBatch(context, mutations)
    local result = Inventory.MutateItems(context, { items = mutations })
    if not result.ok then return result end
    return WeaponResult.Ok(result.value, context.correlationId)
end

local function RegisterUsableWeapons()
    local listed = DefinitionRegistry.List("weapon")
    if not listed.ok then return listed end
    for _, definition in ipairs(listed.value) do
        if DefinitionIds[definition.itemName] then
            local registered = Inventory.Items.RegisterUsableItem(definition.itemName, function(item, source, done)
                if Config.DevMode then
                    print(("[feather-weapons] inventory use item=%s source=%s")
                        :format(tostring(item.id), tostring(source)))
                end
                TriggerClientEvent("feather-weapons:client:useInventoryWeapon", source, item.id)
                if done then done() end
            end, GetCurrentResourceName())
            if type(registered) == "table" and registered.ok ~= true then
                return Failure(nil, "Weapon usable-item registration failed", {
                    itemName = definition.itemName,
                    code = registered.error and registered.error.code,
                    reason = registered.error and registered.error.message
                })
            end
        end
    end
    return WeaponResult.Ok(true)
end

local function RegisterUsableAmmunition()
    local listed = DefinitionRegistry.List("ammunition")
    if not listed.ok then return listed end
    for _, definition in ipairs(listed.value) do
        if DefinitionIds[definition.itemName] then
            local registered = Inventory.Items.RegisterUsableItem(definition.itemName,
                function(_, source, done, useContext)
                    local runtime = WeaponRuntime.Get(source)
                    local result
                    local compatible = false
                    for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
                        local equipped = runtime and runtime.slots and runtime.slots[slot] or nil
                        local weapon = equipped and DefinitionRegistry.Get("weapon", equipped.definitionId) or nil
                        if weapon and weapon.ok
                            and WeaponValidation.AcceptsAmmunition(weapon.value, definition.id) then
                            compatible = true
                            break
                        end
                    end
                    if not runtime or not runtime.slots or next(runtime.slots) == nil then
                        result = WeaponResult.Error(WeaponErrors.NOT_EQUIPPED,
                            "Equip a compatible weapon before using ammunition")
                    elseif not compatible then
                        result = WeaponResult.Error(WeaponErrors.ITEM_INVALID,
                            "This ammunition is not compatible with the equipped weapon")
                    else
                        result = AmmoService.Escrow(source, {
                            characterId = runtime.characterId,
                            sessionId = runtime.sessionId,
                            correlationId = ("inventory-ammo:%s:%s"):format(tostring(source), tostring(GetGameTimer())),
                            activeUseToken = type(useContext) == "table" and useContext.activeUseToken or nil
                        }, nil, definition.id)
                    end
                    TriggerClientEvent("feather-weapons:client:inventoryAmmoResult", source, result)
                    if done then done() end
                end, GetCurrentResourceName())
            if type(registered) == "table" and registered.ok ~= true then
                return Failure(nil, "Ammunition usable-item registration failed", {
                    itemName = definition.itemName,
                    code = registered.error and registered.error.code,
                    reason = registered.error and registered.error.message
                })
            end
        end
    end
    return WeaponResult.Ok(true)
end

local function RegisterUsableRepairItems()
    local listed = DefinitionRegistry.List("weapon")
    if not listed.ok then return listed end
    local registered = {}
    for _, definition in ipairs(listed.value) do
        local repair = definition.condition and definition.condition.repair
        local itemName = repair and repair.itemDefinitionId
        if itemName and DefinitionIds[itemName] and not registered[itemName] then
            registered[itemName] = true
            local registrationResult = Inventory.Items.RegisterUsableItem(itemName, function(item, source, done, useContext)
                if Config.DevMode then
                    print(("[feather-weapons] inventory repair use item=%s source=%s")
                        :format(tostring(item.id), tostring(source)))
                end
                local runtime = WeaponRuntime.Get(source)
                local result
                if not runtime then
                    result = WeaponResult.Error(WeaponErrors.NOT_EQUIPPED, "Equip a weapon before using gun oil")
                else
                    local rpcContext = {
                        characterId = runtime.characterId,
                        sessionId = runtime.sessionId,
                        correlationId = ("inventory-repair:%s:%s"):format(tostring(source), tostring(GetGameTimer())),
                        activeUseToken = type(useContext) == "table" and useContext.activeUseToken or nil
                    }
                    result = RepairService.BeginSelection(source, rpcContext, done)
                    if result.ok then return end
                end
                TriggerClientEvent("feather-weapons:client:inventoryRepairResult", source, result)
                if done then done() end
            end, GetCurrentResourceName())
            if type(registrationResult) == "table" and registrationResult.ok ~= true then
                return Failure(nil, "Repair usable-item registration failed", {
                    itemName = itemName,
                    code = registrationResult.error and registrationResult.error.code,
                    reason = registrationResult.error and registrationResult.error.message
                })
            end
        end
    end
    return WeaponResult.Ok(true)
end

local function RegisterGuards()
    -- Contract 2: IsInstanceEquipped answers with an envelope, where `ok`
    -- says whether the question could be answered and `value` is the answer.
    --
    -- Both branches must be handled separately and the guard must FAIL
    -- CLOSED. A failure envelope is a table and therefore truthy, so testing
    -- the envelope itself would veto every move on a database error -- and
    -- treating an unanswerable question as "not equipped" would let an
    -- equipped weapon leave the inventory while the game still holds it.
    local function WeaponGuard(instance)
        if WeaponCharacterAmmoService and WeaponCharacterAmmoService.IsNativeItemBound(instance.id) then
            return false, "Native loadout still owns this item; complete its release first."
        end
        local equipped = Inventory.Equipment.IsInstanceEquipped(instance.id)
        if not equipped.ok then
            return false, "Unable to verify equipped state."
        end
        if equipped.value then
            return false, "Unequip this item before moving or removing it."
        end
        local definition = instance.definition or {}
        if WeaponDefinitionsByInventoryId[tonumber(definition.id)] then
            return WeaponOwnershipService.EvaluateAdministrativeHold(instance.metadata)
        end
        return true
    end

    local move = Inventory.Guards.RegisterMoveGuard("feather-weapons", WeaponGuard)
    if type(move) ~= "table" or move.ok ~= true then
        return Failure(nil, "Move guard registration failed",
            { reason = type(move) == "table" and move.error and move.error.message or nil })
    end

    local destroy = Inventory.Guards.RegisterDestroyGuard("feather-weapons", WeaponGuard)
    if type(destroy) ~= "table" or destroy.ok ~= true then
        return Failure(nil, "Destroy guard registration failed",
            { reason = type(destroy) == "table" and destroy.error and destroy.error.message or nil })
    end

    if not IsCallable(Inventory.Guards.RegisterInstanceChangeGuard) then
        return Failure(nil, 'Inventory item-lifetime guard API is unavailable')
    end
    local change=Inventory.Guards.RegisterInstanceChangeGuard('feather-weapons',
        WeaponCharacterAmmoLoadoutLease.Guard(function(id)
            return WeaponCharacterAmmoService and WeaponCharacterAmmoService.IsNativeItemBound(id)==true
        end))
    if type(change)~='table' or change.ok~=true then return Failure(nil,'Item-lifetime guard registration failed') end
    return WeaponResult.Ok(true)
end

function InstallFeatherInventoryProvider()
    if GetResourceState("feather-inventory") ~= "started" then
        return Failure(nil, "feather-inventory is not started")
    end

    local ok, api = pcall(function() return exports["feather-inventory"].initiate() end)
    if not ok or type(api) ~= "table" then
        return Failure(nil, "feather-inventory API is unavailable", { reason = tostring(api) })
    end

    local required = { "Items", "Instances", "Equipment", "Guards", "Transaction", "MutateItem", "MutateItems", "CreateInstance",
        "PromoteEquippedSlot",
        "GetCapabilities", "DestroyInstances",
        "GetItemForCharacter", "GetEquippedForCharacter", "SetEquippedForCharacter",
        "GetCharacterInventory" }
    for _, name in ipairs(required) do
        if api[name] == nil then
            return Failure(nil, "feather-inventory is missing a required API", { operation = name })
        end
    end
    if type(api.Inventory) ~= "table" or not IsCallable(api.Inventory.GetInventoryItems)
        or not IsCallable(api.GetCharacterInventory)
        or not IsCallable(api.DestroyInstances) then
        return Failure(nil, "feather-inventory is missing weapon listing or destruction APIs")
    end

    Inventory = api

    if not IsCallable(api.Guards.RegisterInstanceChangeGuard) then
        Inventory = {}
        return Failure(nil, 'feather-inventory is missing item-lifetime guards')
    end

    -- The contract check happens FIRST -- before definitions, usable
    -- callbacks or guards are registered against an API we have not yet
    -- confirmed we can speak to.
    --
    -- A key-existence check cannot detect a changed return shape: every
    -- export contract 2 reshaped is still present under the same name, so
    -- the loop above passes cleanly against a provider that will then
    -- misanswer every call. This is the only gate that catches that, and it
    -- must read the version the PROVIDER reports rather than the one we
    -- require -- comparing our requirement against itself is a check that
    -- can never fail.
    local reported = api.GetCapabilities()
    if type(reported) ~= "table" or reported.ok ~= true or type(reported.value) ~= "table" then
        Inventory = {}
        return Failure(nil, "feather-inventory capabilities are unavailable", {
            reason = type(reported) == "table" and reported.error and reported.error.message or nil
        })
    end

    local contractVersion = tonumber(reported.value.contractVersion) or 0
    if contractVersion < Config.Inventory.requiredContract then
        Inventory = {}
        return Failure(nil, "feather-inventory contract is too old", {
            required = Config.Inventory.requiredContract,
            actual = contractVersion,
            inventoryVersion = reported.value.version
        })
    end

    local characterIdentity = reported.value.characterIdentity
    if type(characterIdentity) ~= "table" or characterIdentity.uuid ~= true then
        Inventory = {}
        return Failure(nil, "feather-inventory does not support canonical character IDs")
    end
    local expectedMode = "uuid"
    if characterIdentity.mode ~= expectedMode then
        Inventory = {}
        return Failure(nil, "feather-inventory character identity mode does not match weapons", {
            expected = expectedMode,
            actual = characterIdentity.mode
        })
    end

    InventoryCapabilities = reported.value

    -- Each of these can fail, and none of them may be degraded to an empty
    -- result: reporting ready with no definitions, no usable callbacks or no
    -- guards is worse than refusing to install, because an unguarded
    -- inventory will happily move an equipped weapon.
    local indexed = BuildDefinitionIndex()
    if not indexed.ok then
        Inventory, InventoryCapabilities = {}, nil
        return indexed
    end

    local weapons = RegisterUsableWeapons()
    if type(weapons) == "table" and weapons.ok ~= true then
        Inventory, InventoryCapabilities = {}, nil
        return weapons
    end

    local ammunition = RegisterUsableAmmunition()
    if type(ammunition) == "table" and ammunition.ok ~= true then
        Inventory, InventoryCapabilities = {}, nil
        return ammunition
    end

    local repairs = RegisterUsableRepairItems()
    if type(repairs) == "table" and repairs.ok ~= true then
        Inventory, InventoryCapabilities = {}, nil
        return repairs
    end

    local guards = RegisterGuards()
    if type(guards) == "table" and guards.ok ~= true then
        Inventory, InventoryCapabilities = {}, nil
        return guards
    end

    return InventoryAdapter.InstallProvider(FeatherInventoryProvider)
end
