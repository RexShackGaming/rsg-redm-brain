local RSGCore = exports['rsg-core']:GetCoreObject()
local stockFile = 'vendor_stock.json'
local stockData = {}
-- stockData[vendorIndex as string][itemName] = amount (each trapper has its own stock)
local function LoadStock()

-- trophies (Config.Trophies) are bought by every trapper at a flat price
if Config.Trophies and Config.Trophies.Enabled then
    for _, vendor in ipairs(Config.Vendors) do
        local has = false
        for _, it in ipairs(vendor.items) do if it.name == Config.Trophies.Item then has = true break end end
        if not has then
            vendor.items[#vendor.items + 1] = { name = Config.Trophies.Item, label = 'Trophy', sellPrice = Config.Trophies.SellPrice or 10.0, maxStock = 50, canSell = true, stockBasedPrice = false }
        end
    end
end
    local file = LoadResourceFile(GetCurrentResourceName(), stockFile)
    stockData = file and json.decode(file) or {}
    -- migrate the old shared format { item = amount } to per trapper
    local migrated = false
    for k, v in pairs(stockData) do
        if type(v) == 'number' then
            stockData[k] = nil
            for i, vendor in ipairs(Config.Vendors) do
                for _, item in ipairs(vendor.items) do
                    if item.name == k then
                        local key = tostring(i)
                        stockData[key] = stockData[key] or {}
                        stockData[key][k] = v
                    end
                end
            end
            migrated = true
        end
    end
    if migrated or not file then
        SaveResourceFile(GetCurrentResourceName(), stockFile, json.encode(stockData), -1)
    end
end

local function vendorStock(vendorIndex)
    local key = tostring(vendorIndex)
    stockData[key] = stockData[key] or {}
    return stockData[key]
end

local function WriteStock()
    SaveResourceFile(GetCurrentResourceName(), stockFile, json.encode(stockData), -1)
end

-- sales only mark the stock dirty; the file is written at most every 5 seconds and on resource stop
local saveQueued = false
local function SaveStock()
    if saveQueued then return end
    saveQueued = true
    SetTimeout(5000, function()
        saveQueued = false
        WriteStock()
    end)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and saveQueued then WriteStock() end
end)

LoadStock()

-- stock slowly sells on, so stock-based prices recover over time
CreateThread(function()
    local minutes = tonumber(Config.StockDecayMinutes) or 0
    local percent = tonumber(Config.StockDecayPercent) or 0
    if minutes <= 0 or percent <= 0 then return end
    while true do
        Wait(minutes * 60000)
        local changed = false
        for _, stock in pairs(stockData) do
            for name, amount in pairs(stock) do
                local new = math.floor(amount * (1 - percent / 100))
                if new ~= amount then stock[name] = new > 0 and new or nil; changed = true end
            end
        end
        if changed then SaveStock() end
    end
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
local demandShown = {} -- [src] = GetGameTimer() of the last demand notification

-- vendor pays more for items it's short on (same rules as single sells)
local function getSellUnitPrice(itemConfig, src, vendorIndex)
    local price = itemConfig.sellPrice
    if src then
        price = price * (1 + (HuntingXP.GetPerks(src).trapperBonus or 0) / 100)
    end
    price = price * HuntingDemand.Multiplier(itemConfig.name)
    if itemConfig.stockBasedPrice then
        local stockRatio = (vendorStock(vendorIndex)[itemConfig.name] or 0) / (itemConfig.maxStock or 50)
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

-- pelt quality of an inventory stack: 0 plain, 1 good, 2 perfect (set when the item was skinned)
local PELT_RANK = { good = 1, perfect = 2 }

local function peltMultiplier(rank)
    local cfg = Config.PeltQuality
    if not cfg or not cfg.Enabled then return 1.0 end
    if rank == 2 then return cfg.perfect or 1.0 end
    if rank == 1 then return cfg.good or 1.0 end
    return 1.0
end

-- the player's stacks of an item, best quality first
local function stacksOf(src, name)
    local inv = exports['rsg-inventory']:GetInventory(src) or {}
    local out = {}
    for slot, it in pairs(inv) do
        if it.name == name then
            out[#out + 1] = { slot = slot, amount = it.amount, rank = PELT_RANK[it.info and it.info.pelt] or 0, info = it.info }
        end
    end
    table.sort(out, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.slot < b.slot
    end)
    return out
end

local function copyInfo(info)
    local out = {}
    for k, v in pairs(info or {}) do out[k] = v end
    return out
end

-- one pass over the inventory: [item] = { owned, good, perfect }
local function tallyInventory(src)
    local tally = {}
    for _, it in pairs(exports['rsg-inventory']:GetInventory(src) or {}) do
        local t = tally[it.name]
        if not t then t = { owned = 0, good = 0, perfect = 0 }; tally[it.name] = t end
        t.owned = t.owned + it.amount
        local rank = PELT_RANK[it.info and it.info.pelt]
        if rank == 2 then t.perfect = t.perfect + it.amount elseif rank == 1 then t.good = t.good + it.amount end
    end
    return tally
end

local function buildSellData(Player, vendorIndex)
    local vendor = Config.Vendors[vendorIndex]
    local src = Player.PlayerData.source
    local tally = tallyInventory(src)
    local items = {}
    for _, item in ipairs(vendor.items) do
        if item.canSell then
            local shared = RSGCore.Shared.Items[item.name]
            local t = tally[item.name] or { owned = 0, good = 0, perfect = 0 }
            local owned, good, perfect = t.owned, t.good, t.perfect
            items[#items + 1] = {
                name  = item.name,
                label = item.label or (shared and shared.label) or item.name,
                image = (shared and shared.image) or (item.name .. '.png'),
                price = getSellUnitPrice(item, src, vendorIndex),
                owned = owned, good = good, perfect = perfect,
            }
        end
    end
    return items
end

local function handler_getSellData(src, vendorIndex)
    local vendor = type(vendorIndex) == 'number' and Config.Vendors[vendorIndex]
    local Player = RSGCore.Functions.GetPlayer(src)
    if not vendor or not Player then return nil end
    if not isNearVendor(src, vendor) then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('vendor'), description = locale('too_far'), type = 'error' })
        return nil
    end
    -- name the active demand rules, at most once every 5 minutes per player
    local notes = {}
    for _, d in ipairs(HuntingDemand.Active()) do notes[#notes + 1] = ('%s +%s%%'):format(d.label, d.pct) end
    local now = GetGameTimer()
    if #notes > 0 and (not demandShown[src] or now - demandShown[src] > 300000) then
        demandShown[src] = now
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('vendor'), description = locale('demand_note', table.concat(notes, ', ')), type = 'inform', duration = 8000 })
    end
    return {
        title = vendor.blipname or locale('vendor'),
        items = buildSellData(Player, vendorIndex),
        qualityMult = { good = peltMultiplier(1), perfect = peltMultiplier(2) },
    }
end
RSGCore.Functions.CreateCallback('rsg-hunting:server:getSellData', function(src, cb, vendorIndex) cb(handler_getSellData(src, vendorIndex)) end)

local function handler_sellBasket(src, vendorIndex, basket)
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

    -- plan the sale stack by stack, best quality first, and price it with the stock level as it was before this sale
    local plans, rawTotal, totalItems = {}, 0, 0
    for _, name in ipairs(order) do
        local unit = getSellUnitPrice(accepted[name], src, vendorIndex)
        local left = lines[name]
        local plan = {}
        for _, st in ipairs(stacksOf(src, name)) do
            if left <= 0 then break end
            local take = math.min(st.amount, left)
            plan[#plan + 1] = { slot = st.slot, n = take, info = st.info }
            rawTotal = rawTotal + unit * take * peltMultiplier(st.rank)
            left = left - take
        end
        if left > 0 then
            return { ok = false, message = locale('not_enough_items'), items = buildSellData(Player, vendorIndex) }
        end
        plans[name] = plan
        totalItems = totalItems + lines[name]
    end

    -- remove everything; roll back if any removal fails
    local removed = {}
    for _, name in ipairs(order) do
        for _, step in ipairs(plans[name]) do
            if exports['rsg-inventory']:RemoveItem(src, name, step.n, step.slot, 'rsg-hunting-trapper-sale') then
                removed[#removed + 1] = { name = name, n = step.n, info = step.info }
            else
                for _, r in ipairs(removed) do exports['rsg-inventory']:AddItem(src, r.name, r.n, copyInfo(r.info), nil, 'rsg-hunting-sale-rollback') end
                return { ok = false, message = locale('not_enough_items'), items = buildSellData(Player, vendorIndex) }
            end
        end
    end

    -- pay the exact amount, rounded to the cent
    local payout = math.floor(rawTotal * 100 + 0.5) / 100
    Player.Functions.AddMoney('cash', payout, 'vendor-sale')

    local stock = vendorStock(vendorIndex)
    for _, name in ipairs(order) do
        stock[name] = (stock[name] or 0) + lines[name]
    end
    SaveStock()

    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('vendor'), description = locale('basket_sold', totalItems, payout), type = 'success' })

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
    return { ok = true, payout = payout, items = buildSellData(Player, vendorIndex) }
end
RSGCore.Functions.CreateCallback('rsg-hunting:server:sellBasket', function(src, cb, vendorIndex, basket) cb(handler_sellBasket(src, vendorIndex, basket)) end)

-- hunting contract: talk to the trapper (pay a finished one, show progress or get a new one)
RegisterNetEvent('rsg-hunting:server:contract', function(vendorIndex)
    local src = source
    local vendor = type(vendorIndex) == 'number' and Config.Vendors[vendorIndex]
    if not vendor or not isNearVendor(src, vendor) then return end
    if isOnCooldown(src) then return end
    HuntingContracts.Interact(src)
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
    demandShown[source] = nil
end)
