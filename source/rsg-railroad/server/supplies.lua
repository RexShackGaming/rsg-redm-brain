local RSGCore = exports['rsg-core']:GetCoreObject()

local MAX_SUPPLY_QTY = 100 -- per transaction

local function IsSupplyItem(itemName)
    for _, si in ipairs(Config.SupplyItems) do
        if si.item == itemName then return true end
    end
    return false
end

local function ItemLabel(itemName)
    return RSGCore.Shared.Items[itemName] and RSGCore.Shared.Items[itemName].label or itemName
end

local function SanitizeQty(quantity)
    quantity = math.floor(tonumber(quantity) or 0)
    if quantity < 1 or quantity > MAX_SUPPLY_QTY then return nil end
    return quantity
end

---------------------------------------------------------------
-- CALLBACKS (owner / approved drivers only)
---------------------------------------------------------------
lib.callback.register('rsg-railroad:getCompanySupplies', function(source, companyId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not GetCompanyRole(companyId, Player.PlayerData.citizenid) then return {} end
    return DB.GetCompanySupplies(companyId)
end)

---------------------------------------------------------------
-- OWNER: ADD SUPPLIES FROM INVENTORY
---------------------------------------------------------------
RegisterNetEvent('rsg-railroad:addSupply', function(companyId, itemName, quantity)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if GetCompanyRole(companyId, Player.PlayerData.citizenid) ~= 'owner' then
        NotifyPlayer(src, locale('not_owner_of_company'), 'error')
        return
    end

    quantity = SanitizeQty(quantity)
    if not quantity or not IsSupplyItem(itemName) then return end

    if not exports['rsg-inventory']:RemoveItem(src, itemName, quantity, nil, 'railroad-supply-add') then
        NotifyPlayer(src, locale('missing_item_quantity'), 'error')
        return
    end

    DB.AddSupplyItem(companyId, itemName, quantity)
    NotifyPlayer(src, locale('supply_added_notify', quantity, ItemLabel(itemName)), 'success')
end)

---------------------------------------------------------------
-- DRIVER / OWNER: TAKE SUPPLY (free from company stock)
---------------------------------------------------------------
RegisterNetEvent('rsg-railroad:takeSupply', function(companyId, itemName, quantity)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if not GetCompanyRole(companyId, Player.PlayerData.citizenid) then
        NotifyPlayer(src, locale('not_authorized'), 'error')
        return
    end

    quantity = SanitizeQty(quantity)
    if not quantity or not IsSupplyItem(itemName) then return end

    if not exports['rsg-inventory']:CanAddItem(src, itemName, quantity) then
        NotifyPlayer(src, locale('inventory_full'), 'error')
        return
    end

    -- Atomic stock decrement; only hand the item over if it succeeded.
    if (DB.TakeSupplyItem(companyId, itemName, quantity) or 0) < 1 then
        NotifyPlayer(src, locale('not_enough_stock'), 'error')
        return
    end

    exports['rsg-inventory']:AddItem(src, itemName, quantity, nil, nil, 'railroad-supply-take')
    NotifyPlayer(src, locale('supply_taken_notify', quantity, ItemLabel(itemName)), 'success')
end)
