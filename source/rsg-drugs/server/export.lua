-- Brick export market. State persists in resource KVP (no SQL).
if not Config.Export.Enabled then return end
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local E = Config.Export
local KVP = 'rsg-drugs:market'
local NpcPos = vector3(E.NPC.coords.x, E.NPC.coords.y, E.NPC.coords.z)
local lastSale = {}

local Market = json.decode(GetResourceKvpString(KVP) or 'null') or {}
Market.stock   = tonumber(Market.stock) or 0
Market.demand  = tonumber(Market.demand) or 1.0
Market.history = type(Market.history) == 'table' and Market.history or {}

local function save() SetResourceKvp(KVP, json.encode(Market)) end

-- price of the next brick with `stock` already held
local function priceAt(stock)
    local fill = math.min(1.0, math.max(0.0, stock / E.Saturation))
    local p = E.MinPrice + (E.MaxPrice - E.MinPrice) * (1.0 - fill ^ E.Curve)
    return math.floor(p * Market.demand)
end

local function quote(amount)
    local total = 0
    for i = 0, amount - 1 do total = total + priceAt(Market.stock + i) end
    return total
end

local function pushHistory()
    Market.history[#Market.history + 1] = priceAt(Market.stock)
    while #Market.history > E.History do table.remove(Market.history, 1) end
end
if #Market.history == 0 then pushHistory() end

local function notify(src, desc, ntype)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('export_title'), description = desc, type = ntype or 'inform' })
end

local function canTrade(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - NpcPos) > E.NPC.interactDistance then
        notify(src, locale('too_far'), 'error') return
    end
    if Config.XP.Enabled and DrugsXP.Info(Player).level < E.MinLevel then
        local l = Config.XP.Levels[E.MinLevel]
        notify(src, locale('export_locked', l and l.label or E.MinLevel), 'error') return
    end
    return Player
end

local function payload(src)
    return {
        price   = priceAt(Market.stock),
        stock   = math.floor(Market.stock),
        saturation = E.Saturation,
        demand  = Market.demand,
        history = Market.history,
        maxPrice = E.MaxPrice, minPrice = E.MinPrice,
        maxPerSale = E.MaxPerSale,
        carrying = exports['rsg-inventory']:GetItemCount(src, E.Item) or 0,
        quotes  = (function() local q = {} for i = 1, E.MaxPerSale do q[i] = quote(i) end return q end)(),
    }
end

lib.callback.register('rsg-drugs:server:exportOpen', function(src)
    if not canTrade(src) then return end
    return payload(src)
end)

lib.callback.register('rsg-drugs:server:exportSell', function(src, amount)
    local Player = canTrade(src)
    if not Player then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or amount > E.MaxPerSale then return payload(src) end
    local now = os.time()
    if lastSale[src] and now - lastSale[src] < E.Cooldown then notify(src, locale('export_cooldown'), 'error') return payload(src) end
    if (exports['rsg-inventory']:GetItemCount(src, E.Item) or 0) < amount then notify(src, locale('no_item'), 'error') return payload(src) end
    lastSale[src] = now
    local total = quote(amount)
    if not exports['rsg-inventory']:RemoveItem(src, E.Item, amount, nil, 'rsg-drugs-export') then return payload(src) end
    Player.Functions.AddMoney(E.MoneyType, total, 'rsg-drugs-export')
    Market.stock = Market.stock + amount
    save()
    notify(src, locale('export_sold', amount, total), 'success')
    DrugsLog('export', 'Bricks exported', src, { { 'Bricks', amount }, { 'Payout', ('$%s (%s)'):format(total, E.MoneyType) }, { 'Avg/brick', ('$%d'):format(math.floor(total / amount)) }, { 'Buyer stock', math.floor(Market.stock) }, { 'Demand', ('x%.2f'):format(Market.demand) } })
    DrugsXP.Add(src, (Config.XP.Sell[E.Item] or 0) * amount, 'export')
    local p = payload(src)
    p.sold = amount
    return p
end)

-- market tick: buyer offloads stock, demand drifts
CreateThread(function()
    while true do
        Wait(E.TickMinutes * 60000)
        local drain = E.DrainPerHour * (E.TickMinutes / 60) * (0.7 + math.random() * 0.6)
        Market.stock = math.max(0, Market.stock - drain)
        local step = (math.random() * 2 - 1) * E.DemandStep
        Market.demand = math.max(E.DemandMin, math.min(E.DemandMax, Market.demand + step))
        pushHistory()
        save()
    end
end)

AddEventHandler('playerDropped', function() lastSale[source] = nil end)
