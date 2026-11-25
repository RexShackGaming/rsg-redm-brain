-- Brick export market. State persists in MySQL (rsg_drugs_state), not resource KVP, so no server "db" folder is created.
if not Config.Export.Enabled then return end
local RSGCore = exports['rsg-core']:GetCoreObject()

local Callback = DrugsCallback -- server/utils.lua

local E = Config.Export
local STATE_KEY = 'market'
local NpcPos = vector3(E.NPC.coords.x, E.NPC.coords.y, E.NPC.coords.z)
local lastSale = {}

-- defaults until the saved market has been loaded from the database (see MySQL.ready below)
local Market = { stock = 0, demand = 1.0, history = {} }
local marketLoaded = false

local function save()
    if not marketLoaded then return end -- never overwrite the saved market with defaults
    MySQL.prepare('INSERT INTO rsg_drugs_state (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)', { STATE_KEY, json.encode(Market) })
end

-- price of the next brick with `stock` already held
local function priceAt(stock)
    local fill = math.min(1.0, math.max(0.0, stock / E.Saturation))
    local p = E.MinPrice + (E.MaxPrice - E.MinPrice) * (1.0 - fill ^ E.Curve)
    return math.floor(p * Market.demand)
end

-- mults[i] = price multiplier of the i-th brick sold (potency and sell perk); missing entries count as 1
local function quote(amount, mults)
    local total = 0
    for i = 0, amount - 1 do total = total + priceAt(Market.stock + i) * (mults and mults[i + 1] or 1) end
    return math.floor(total)
end

-- the player's bricks, highest potency first, plus the price multiplier of each of the first `limit` bricks
local function brickStacks(src, limit)
    local bonus = 1 + DrugsSkills.Perk(src, 'sell_bonus') / 100
    local stacks = exports['rsg-inventory']:GetItemsByName(src, E.Item) or {}
    table.sort(stacks, function(a, b) return DrugsItemPotency(a) > DrugsItemPotency(b) end)
    local mults, n = {}, 0
    for _, st in ipairs(stacks) do
        local m = DrugsPotencyMult(DrugsItemPotency(st)) * bonus
        for _ = 1, (st.amount or 0) do
            if n >= limit then break end
            n = n + 1
            mults[n] = m
        end
        if n >= limit then break end
    end
    return stacks, mults
end

local function pushHistory()
    Market.history[#Market.history + 1] = priceAt(Market.stock)
    while #Market.history > E.History do table.remove(Market.history, 1) end
end

MySQL.ready(function()
    if not DrugsEnsureDatabase() then return end -- server/utils.lua (also honours Config.AutoDatabase)
    local raw = MySQL.scalar.await('SELECT `value` FROM rsg_drugs_state WHERE `key` = ?', { STATE_KEY })
    local ok, saved = pcall(json.decode, raw or 'null')
    if ok and type(saved) == 'table' then
        Market.stock   = tonumber(saved.stock) or 0
        Market.demand  = tonumber(saved.demand) or 1.0
        Market.history = type(saved.history) == 'table' and saved.history or {}
    end
    if #Market.history == 0 then pushHistory() end
    marketLoaded = true
    save()
end)

local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('export_title'), description = desc, type = ntype or 'inform' })
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
        quotes  = (function()
            local _, mults = brickStacks(src, E.MaxPerSale)
            local q = {}
            for i = 1, E.MaxPerSale do q[i] = quote(i, mults) end
            return q
        end)(),
    }
end

Callback('rsg-drugs:server:exportOpen', function(src)
    if not canTrade(src) then return end
    return payload(src)
end)

Callback('rsg-drugs:server:exportSell', function(src, amount)
    local Player = canTrade(src)
    if not Player then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or amount > E.MaxPerSale then return payload(src) end
    local now = os.time()
    if lastSale[src] and now - lastSale[src] < E.Cooldown then notify(src, locale('export_cooldown'), 'error') return payload(src) end
    if (exports['rsg-inventory']:GetItemCount(src, E.Item) or 0) < amount then notify(src, locale('no_item'), 'error') return payload(src) end
    lastSale[src] = now
    local stacks, mults = brickStacks(src, amount)
    -- take the best bricks first and pay for exactly what left the inventory
    local left = amount
    for _, st in ipairs(stacks) do
        if left <= 0 then break end
        local take = math.min(left, st.amount or 0)
        if take > 0 then
            if not exports['rsg-inventory']:RemoveItem(src, E.Item, take, st.slot, 'rsg-drugs-export') then break end
            left = left - take
        end
    end
    amount = amount - left
    if amount < 1 then return payload(src) end
    local total = quote(amount, mults)
    Player.Functions.AddMoney(E.MoneyType, total, 'rsg-drugs-export')
    Market.stock = Market.stock + amount
    save()
    DrugsBoard.Record(Player, amount, total, nil)
    notify(src, locale('export_sold', amount, total), 'success')
    DrugsLog('export', 'Bricks exported', src, { { 'Bricks', amount }, { 'Payout', ('$%s (%s)'):format(total, E.MoneyType) }, { 'Avg/brick', ('$%d'):format(math.floor(total / amount)) }, { 'Buyer stock', math.floor(Market.stock) }, { 'Demand', ('x%.2f'):format(Market.demand) } })
    DrugsXP.Add(src, (Config.XP.Sell[E.Item] or 0) * amount, 'export')
    DrugsHeat.Add(Player.PlayerData.citizenid, amount * Config.Heat.PerExportBrick)
    DrugsRep.Apply(src, 'export')
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
