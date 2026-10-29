local RSGCore = exports['rsg-core']:GetCoreObject()
local stockFile = 'vendor_stock.json'
local stockData = {}
lib.locale()

local function LoadStock()
    local file = LoadResourceFile(GetCurrentResourceName(), stockFile)
    if file then
        stockData = json.decode(file) or {}
    else
        stockData = {}
        SaveResourceFile(GetCurrentResourceName(), stockFile, json.encode(stockData), -1)
    end
end

local function SaveStock()
    SaveResourceFile(GetCurrentResourceName(), stockFile, json.encode(stockData), -1)
end

CreateThread(function()
    Wait(1000)
    LoadStock()
end)

--------------------------------------
-- anti-spam: throttle selling so a macro can't fire the events faster
-- than the UI could ever produce them
--------------------------------------
local PlayerCooldowns = {}
local TRADE_COOLDOWN = 500 -- ms
local MAX_TRADE_AMOUNT = 500

local function isOnCooldown(src)
    local now = GetGameTimer()
    local last = PlayerCooldowns[src]
    if last and (now - last) < TRADE_COOLDOWN then
        return true
    end
    PlayerCooldowns[src] = now
    return false
end

-- amount must be a whole, positive number within sane bounds
local function isValidAmount(amount)
    return type(amount) == 'number'
        and amount > 0
        and amount <= MAX_TRADE_AMOUNT
        and amount % 1 == 0
end

--------------------------------------
-- trapper sell UI: data + basket checkout
--------------------------------------
local SELL_DISTANCE = 6.0

-- vendor pays more for items it's short on (same rules as single sells)
local function getSellUnitPrice(itemConfig, src)
    local price = itemConfig.sellPrice
    if src then
        price = price * (1 + (HuntingXP.GetPerks(src).trapperBonus or 0) / 100)
    end
    if itemConfig.stockBasedPrice then
        local stockRatio = (stockData[itemConfig.name] or 0) / (itemConfig.maxStock or 50)
        if stockRatio < 0.25 then
            price = price * 1.5
        elseif stockRatio < 0.5 then
            price = price * 1.25
        end
    end
    return price
end

local function isNearVendor(src, vendor)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = vendor.coords
    return #(GetEntityCoords(ped) - vector3(c.x, c.y, c.z)) <= SELL_DISTANCE
end

local function buildSellData(Player, vendor)
    local items = {}
    for _, item in ipairs(vendor.items) do
        if item.canSell then
            local shared = RSGCore.Shared.Items[item.name]
            local owned = Player.Functions.GetItemByName(item.name)
            items[#items + 1] = {
                name  = item.name,
                label = item.label or (shared and shared.label) or item.name,
                image = (shared and shared.image) or (item.name .. '.png'),
                price = getSellUnitPrice(item, Player.PlayerData.source),
                owned = owned and owned.amount or 0,
            }
        end
    end
    return items
end

lib.callback.register('rsg-hunting:server:getSellData', function(src, vendorIndex)
    local vendor = type(vendorIndex) == 'number' and Config.Vendors[vendorIndex]
    local Player = RSGCore.Functions.GetPlayer(src)
    if not vendor or not Player then return nil end
    if not isNearVendor(src, vendor) then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('vendor'), description = locale('too_far'), type = 'error' })
        return nil
    end
    return { title = vendor.blipname or locale('vendor'), items = buildSellData(Player, vendor) }
end)

lib.callback.register('rsg-hunting:server:sellBasket', function(src, vendorIndex, basket)
    local vendor = type(vendorIndex) == 'number' and Config.Vendors[vendorIndex]
    local Player = RSGCore.Functions.GetPlayer(src)
    if not vendor or not Player or type(basket) ~= 'table' then return { ok = false } end
    if isOnCooldown(src) then return { ok = false } end
    if not isNearVendor(src, vendor) then
        return { ok = false, message = locale('too_far') }
    end

    -- only items this specific vendor accepts
    local accepted = {}
    for _, item in ipairs(vendor.items) do
        if item.canSell then accepted[item.name] = item end
    end

    -- merge + validate every line before touching the inventory
    local lines, order, count = {}, {}, 0
    for _, entry in pairs(basket) do
        count = count + 1
        if count > 200 or type(entry) ~= 'table' then return { ok = false } end
        local name, amount = entry.name, tonumber(entry.amount)
        if type(name) ~= 'string' or not accepted[name] or not isValidAmount(amount) then
            return { ok = false }
        end
        if not lines[name] then order[#order + 1] = name end
        lines[name] = (lines[name] or 0) + amount
    end
    if #order == 0 then return { ok = false, message = locale('basket_empty') } end

    for _, name in ipairs(order) do
        local owned = Player.Functions.GetItemByName(name)
        if not owned or owned.amount < lines[name] then
            return { ok = false, message = locale('not_enough_items'), items = buildSellData(Player, vendor) }
        end
    end

    -- price with the stock level as it was before this sale
    local rawTotal, totalItems = 0, 0
    for _, name in ipairs(order) do
        rawTotal = rawTotal + getSellUnitPrice(accepted[name], src) * lines[name]
        totalItems = totalItems + lines[name]
    end

    -- remove everything; roll back if any removal fails
    local removed = {}
    for _, name in ipairs(order) do
        if exports['rsg-inventory']:RemoveItem(src, name, lines[name], nil, 'rsg-hunting-trapper-sale') then
            removed[#removed + 1] = name
        else
            for _, r in ipairs(removed) do exports['rsg-inventory']:AddItem(src, r, lines[r], nil, nil, 'rsg-hunting-sale-rollback') end
            return { ok = false, message = locale('not_enough_items'), items = buildSellData(Player, vendor) }
        end
    end

    -- pay the exact amount, rounded to the cent
    local payout = math.floor(rawTotal * 100 + 0.5) / 100
    Player.Functions.AddMoney('cash', payout, 'vendor-sale')

    for _, name in ipairs(order) do
        stockData[name] = (stockData[name] or 0) + lines[name]
    end
    SaveStock()

    TriggerClientEvent('ox_lib:notify', src, { title = locale('vendor'), description = locale('basket_sold', totalItems, payout), type = 'success' })

    local soldText = {}
    for _, name in ipairs(order) do
        local shared = RSGCore.Shared.Items[name]
        soldText[#soldText + 1] = ('%sx %s'):format(lines[name], (shared and shared.label) or name)
    end
    HuntingWebhook.Sale('trapper', src, locale('wh_trapper_title', totalItems, vendor.blipname or locale('vendor')), {
        { name = locale('wh_trapper'), value = vendor.blipname or ('#' .. vendorIndex) },
        { name = locale('wh_payout'), value = ('$%.2f'):format(payout) },
        { name = locale('wh_trapper_perk'), value = ('+%s%%'):format(HuntingXP.GetPerks(src).trapperBonus or 0) },
        { name = locale('wh_items'), value = table.concat(soldText, '\n'), inline = false },
    }, payout)
    return { ok = true, payout = payout, items = buildSellData(Player, vendor) }
end)

RegisterCommand('resetvendorstock', function(src)
    if src ~= 0 then return end

    stockData = {}
    SaveStock()
    print('[rsg-hunting] Vendor stock reset')
    HuntingWebhook.Send('admin', { title = locale('wh_stock_reset_title'), description = locale('wh_stock_reset_desc'), src = 0 })
end, false)

--------------------------------------
-- cleanup on player disconnect
--------------------------------------
AddEventHandler('playerDropped', function()
    PlayerCooldowns[source] = nil
end)
