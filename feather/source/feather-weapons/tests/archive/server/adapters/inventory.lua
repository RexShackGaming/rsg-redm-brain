InventoryAdapter = {}
local provider = nil

local function IsCallable(value)
    return type(value) == "function"
        or (type(value) == "table"
            and type(rawget(value, "__cfx_functionReference")) == "string")
end

local function Unavailable(context, operation)
    return WeaponResult.Error(WeaponErrors.INVENTORY_UNAVAILABLE,
        "Inventory provider does not support " .. operation, nil, context and context.correlationId)
end

function InventoryAdapter.InstallProvider(candidate)
    if type(candidate) ~= "table" or not IsCallable(candidate.GetCapabilities) then
        return WeaponResult.Error(WeaponErrors.INVENTORY_UNAVAILABLE, "Inventory provider is invalid")
    end

    local capabilities = candidate.GetCapabilities()
    local contractVersion = capabilities and tonumber(capabilities.contractVersion) or 0
    if contractVersion < Config.Inventory.requiredContract then
        return WeaponResult.Error(WeaponErrors.INVENTORY_UNAVAILABLE, "Inventory contract is too old", {
            required = Config.Inventory.requiredContract,
            actual = capabilities and capabilities.contractVersion or nil
        })
    end
    if not IsCallable(candidate.GetItemForCharacter)
        or not IsCallable(candidate.GetEquippedForCharacter)
        or not IsCallable(candidate.SetEquippedForCharacter)
        or not IsCallable(candidate.GetEquippedSlotsForCharacter)
        or not IsCallable(candidate.ListWeaponsForCharacter)
        or not IsCallable(candidate.SetEquippedSlotForCharacter)
        or not IsCallable(candidate.MutateWeaponMetadataBatch)
        or not IsCallable(candidate.PromoteOffhandToPrimary)
        or not IsCallable(candidate.CreateWeapon)
        or not IsCallable(candidate.GetInstance)
        or not IsCallable(candidate.GetCharacterInventory)
        or not IsCallable(candidate.DestroyInstance)
        or not IsCallable(candidate.ResolveWeaponDefinitionId)
        or not IsCallable(candidate.Transaction) then
        return WeaponResult.Error(WeaponErrors.INVENTORY_UNAVAILABLE, "Inventory provider is missing required operations")
    end

    provider = candidate
    return WeaponResult.Ok(capabilities)
end

function InventoryAdapter.IsReady()
    return provider ~= nil
end

function InventoryAdapter.GetCapabilities()
    if not provider then return { contractVersion = 0, ready = false, reason = "provider_not_installed" } end
    local capabilities = provider.GetCapabilities()
    capabilities.ready = true
    return capabilities
end

function InventoryAdapter.GetItemForCharacter(context, itemInstanceId)
    if not provider then return Unavailable(context, "GetItemForCharacter") end
    return provider.GetItemForCharacter(context, itemInstanceId)
end

function InventoryAdapter.GetEquippedForCharacter(context)
    if not provider then return Unavailable(context, "GetEquippedForCharacter") end
    return provider.GetEquippedForCharacter(context)
end

function InventoryAdapter.SetEquippedForCharacter(context, itemInstanceId)
    if not provider then return Unavailable(context, "SetEquippedForCharacter") end
    return provider.SetEquippedForCharacter(context, itemInstanceId)
end

function InventoryAdapter.GetEquippedSlotsForCharacter(context)
    if not provider then return Unavailable(context, "GetEquippedSlotsForCharacter") end
    return provider.GetEquippedSlotsForCharacter(context)
end

function InventoryAdapter.ListWeaponsForCharacter(context)
    if not provider then return Unavailable(context, "ListWeaponsForCharacter") end
    return provider.ListWeaponsForCharacter(context)
end

function InventoryAdapter.SetEquippedSlotForCharacter(context, slot, itemInstanceId)
    if not provider then return Unavailable(context, "SetEquippedSlotForCharacter") end
    return provider.SetEquippedSlotForCharacter(context, slot, itemInstanceId)
end

function InventoryAdapter.MutateWeaponMetadataBatch(context, mutations)
    if not provider then return Unavailable(context, "MutateWeaponMetadataBatch") end
    return provider.MutateWeaponMetadataBatch(context, mutations)
end

function InventoryAdapter.PromoteOffhandToPrimary(context)
    if not provider then return Unavailable(context, "PromoteOffhandToPrimary") end
    return provider.PromoteOffhandToPrimary(context)
end

function InventoryAdapter.CreateWeapon(context, definition, metadata)
    if not provider then return Unavailable(context, "CreateWeapon") end
    return provider.CreateWeapon(context, definition, metadata)
end

function InventoryAdapter.GetInstance(context, itemInstanceId)
    if not provider then return Unavailable(context, "GetInstance") end
    return provider.GetInstance(context, itemInstanceId)
end

function InventoryAdapter.GetCharacterInventory(context, characterId)
    if not provider then return Unavailable(context, "GetCharacterInventory") end
    return provider.GetCharacterInventory(context, characterId)
end

function InventoryAdapter.DestroyInstance(context, item)
    if not provider then return Unavailable(context, "DestroyInstance") end
    return provider.DestroyInstance(context, item)
end

function InventoryAdapter.ResolveWeaponDefinitionId(inventoryDefinitionId)
    if not provider then return nil end
    return provider.ResolveWeaponDefinitionId(inventoryDefinitionId)
end

function InventoryAdapter.Transaction(context, callback)
    if not provider then return Unavailable(context, "Transaction") end
    return provider.Transaction(context, callback)
end
