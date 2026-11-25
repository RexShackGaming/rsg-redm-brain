-- Corner selling. /corner starts a session at the player's spot; NPCs walk up one at a time (the client picks
-- them) and the server runs the haggle. Everything that matters is decided here: which item and how many the
-- buyer wants, their hidden price limit and patience, every counter-offer, the payout, XP, heat and reputation.
-- The client only sends a netId when a buyer arrives and the price the player typed.
local RSGCore = exports['rsg-core']:GetCoreObject()

local Callback = DrugsCallback -- server/utils.lua

local C = Config.Corner
local H = C.Haggle

local Sessions = {}  -- [src] = { pos, since, sold, earned }
local Deals    = {}  -- [src] = deal (one open haggle per player)
local DealPeds = {}  -- [netId] = src (a buyer can only be haggled with by one player)
local lastDeal = {}  -- [src] = os.time() of the last haggle that started
local pressure = {}  -- [item] = sell pressure that lowers the street price (Config.Corner.Demand)
local hourly   = {}  -- [src] = { since, n } haggles opened this hour (H.MaxDealsPerHour)

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('corner_title'), description = desc, type = ntype or 'inform', duration = 5000 })
end

local function rnd(a, b) return a + math.random() * (b - a) end
local function round2(n) return math.floor(n * 100 + 0.5) / 100 end
local function pick(prefix, count) return ('%s_%d'):format(prefix, math.random(count)) end

local function itemLabel(name)
    local it = RSGCore.Shared.Items[name]
    return it and it.label or name
end

-- price multiplier from the market's sell pressure (1.0 = normal)
local function demandMult(item)
    local D = C.Demand
    if not D or not D.Enabled then return 1.0 end
    return 1.0 - D.MaxDrop * math.min(1.0, (pressure[item] or 0) / math.max(1, D.Capacity))
end

CreateThread(function()
    while true do
        Wait(60000)
        local D = C.Demand
        if D and D.Enabled then
            for item, p in pairs(pressure) do
                p = p - D.Recover
                pressure[item] = p > 0 and p or nil
            end
        end
    end
end)

-- corner rank from lifetime units sold (character metadata 'cornerrep'). Returns bonus %, level index, label key
local function rankOf(Player)
    local R = C.Rank
    if not R or not R.Enabled then return 0, 1, nil end
    local m = Player.PlayerData.metadata.cornerrep
    local sold = type(m) == 'table' and tonumber(m.sold) or 0
    local lvl = 1
    for i, l in ipairs(R.Levels) do if sold >= l.sold then lvl = i end end
    return R.Levels[lvl].bonus, lvl, R.Levels[lvl].label
end

local function addRankSold(Player, src, n)
    local R = C.Rank
    if not R or not R.Enabled then return end
    local _, before = rankOf(Player)
    local m = Player.PlayerData.metadata.cornerrep
    m = type(m) == 'table' and m or { sold = 0 }
    m.sold = (tonumber(m.sold) or 0) + n
    Player.Functions.SetMetaData('cornerrep', m)
    local bonus, after, label = rankOf(Player)
    if after > before then notify(src, locale('corner_rank_up', locale(label), bonus), 'success') end
end

-- the buyer type of a new haggle (undercover only while enough law is online)
local function pickBuyer(stingMult)
    local total, pool = 0, {}
    for name, b in pairs(C.Buyers) do
        local ok = name ~= 'undercover' or (C.Sting.Enabled and DrugsLawCount() >= (C.Sting.MinLaw or 1))
        local w = b.weight * (name == 'undercover' and stingMult or 1.0)
        if ok and w > 0 then total = total + w pool[#pool + 1] = { name = name, w = w } end
    end
    table.sort(pool, function(a, b) return a.name < b.name end) -- stable order
    local r = math.random() * total
    for _, e in ipairs(pool) do
        r = r - e.w
        if r <= 0 then return e.name end
    end
    return 'regular'
end

-- town modifiers (Config.Corner.Towns) for a rsg-economy region id
local NO_TOWN = { price = 1.0, ceiling = 1.0, heat = 1.0, sting = 1.0 }
local function townOf(region)
    local T = C.Towns
    if not T or not T.Enabled then return NO_TOWN end
    local t = region ~= nil and T.List[tostring(region):lower()] or nil
    local d = T.Default or NO_TOWN
    return {
        price = (t and t.price) or d.price or 1.0, ceiling = (t and t.ceiling) or d.ceiling or 1.0,
        heat = (t and t.heat) or d.heat or 1.0, sting = (t and t.sting) or d.sting or 1.0,
    }
end

-- regulars (Config.Corner.Regulars), stored on the character as metadata 'cornerregulars'
local R = C.Regulars
local function regList(Player)
    local m = Player.PlayerData.metadata.cornerregulars
    return type(m) == 'table' and m or {}
end
local function regLevel(r) return math.min(R.MaxLevel, 1 + math.floor((r.loyalty or 1) / R.PerLevel)) end

-- change one regular (fn gets it and may change it). Returns the regular, and true when they left.
local function regUpdate(Player, id, fn)
    local list = regList(Player)
    for i, r in ipairs(list) do
        if r.id == id then
            fn(r)
            local gone = (r.loyalty or 0) <= 0
            if gone then table.remove(list, i) end
            Player.Functions.SetMetaData('cornerregulars', list)
            return r, gone
        end
    end
end

-- one of the player's regulars who is free to come back now (not guaranteed: R.Return %)
local function pickRegular(Player)
    if not R or not R.Enabled or math.random(100) > R.Return then return nil end
    local now, free = os.time(), {}
    for _, r in ipairs(regList(Player)) do
        if now >= (r.back or 0) then free[#free + 1] = r end
    end
    return #free > 0 and free[math.random(#free)] or nil
end

-- a fair sale to a stranger may win a new regular; a sale to a regular adds loyalty
local function regAfterSale(Player, src, deal, price)
    if not R or not R.Enabled then return end
    if deal.regularId then
        local before = deal.regularLvl
        local r = regUpdate(Player, deal.regularId, function(x) x.loyalty = (x.loyalty or 1) + 1 end)
        if r and regLevel(r) > before then notify(src, locale('corner_regular_up', r.name, regLevel(r)), 'success') end
        return
    end
    if deal.sting or price > deal.street * R.FairMult or math.random(100) > R.Recruit then return end
    local list = regList(Player)
    if #list >= R.Max then return end
    local used, maxId = {}, 0
    for _, r in ipairs(list) do used[r.name] = true; if r.id > maxId then maxId = r.id end end
    local pool = {}
    for _, n in ipairs(R.Names) do if not used[n] then pool[#pool + 1] = n end end
    if #pool == 0 then return end
    local r = { id = maxId + 1, name = pool[math.random(#pool)], loyalty = 1, back = os.time() + R.CooldownMinutes * 60 }
    list[#list + 1] = r
    Player.Functions.SetMetaData('cornerregulars', list)
    notify(src, locale('corner_regular_new', r.name), 'success')
end

local function isLaw(Player)
    local job = Player.PlayerData.job
    if not job or job.onduty == false then return false end
    return (Config.Heat.LawJobTypes[job.type] or Config.Heat.LawJobs[job.name]) and true or false
end

local function isJailed(Player)
    return (tonumber(Player.PlayerData.metadata.injail) or 0) > 0
end

-- the stacks that would be sold: best potency first, with the price multiplier of each unit taken (qty units)
local function unitsOf(src, name, qty)
    local stacks = exports['rsg-inventory']:GetItemsByName(src, name) or {}
    table.sort(stacks, function(a, b) return DrugsItemPotency(a) > DrugsItemPotency(b) end)
    local take, n, multSum, potSum = {}, 0, 0.0, 0.0
    for _, st in ipairs(stacks) do
        local k = math.min(qty - n, st.amount or 0)
        if k > 0 then
            take[#take + 1] = { slot = st.slot, amount = k }
            multSum = multSum + DrugsPotencyMult(DrugsItemPotency(st)) * k
            potSum = potSum + DrugsItemPotency(st) * k
            n = n + k
        end
        if n >= qty then break end
    end
    if n < 1 then return nil end
    return take, n, multSum / n, potSum / n
end

local function countOf(src, name)
    return exports['rsg-inventory']:GetItemCount(src, name) or 0
end

-- items from Config.Corner.Items the player still holds
local function sellable(src)
    local list = {}
    for name in pairs(C.Items) do
        if countOf(src, name) >= 1 then list[#list + 1] = name end
    end
    table.sort(list)
    return list
end

local function endDeal(src)
    local d = Deals[src]
    if not d then return end
    if d.netId then DealPeds[d.netId] = nil end
    Deals[src] = nil
end

local function stopCorner(src, reason)
    local s = Sessions[src]
    if not s then return end
    Sessions[src] = nil
    endDeal(src)
    TriggerClientEvent('rsg-drugs:client:cornerState', src, false)
    if reason == 'silent' then return end
    local key = reason == 'spot' and 'corner_left_spot' or reason == 'out' and 'corner_out' or nil
    if key then notify(src, locale(key), 'inform') end
    notify(src, locale('corner_stopped', s.sold, ('%.2f'):format(s.earned)), 'inform')
    if s.sold > 0 then DrugsLog('sales', 'Corner selling ended', src, { { 'Items sold', s.sold }, { 'Earned', ('$%.2f (%s)'):format(s.earned, C.MoneyType) }, { 'Minutes', math.floor((os.time() - s.since) / 60) } }) end
end

---------------------------------------------------------------------
-- starting and stopping (/corner)
---------------------------------------------------------------------
local function startCorner(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.metadata.isdead or isJailed(Player) or DrugsInRehab(src) then return notify(src, locale('corner_blocked'), 'error') end
    if C.BlockLaw and isLaw(Player) then return notify(src, locale('corner_law'), 'error') end
    if #sellable(src) == 0 then return notify(src, locale('corner_no_items'), 'error') end
    Sessions[src] = { pos = GetEntityCoords(GetPlayerPed(src)), since = os.time(), sold = 0, earned = 0 }
    TriggerClientEvent('rsg-drugs:client:cornerState', src, true, Sessions[src].pos)
    notify(src, locale('corner_started', math.floor(C.Spot.LeaveRadius)), 'success')
end

RSGCore.Commands.Add(C.Command, locale('cmd_corner'), {}, false, function(source)
    if Sessions[source] then stopCorner(source) else startCorner(source) end
end, 'user')

-- the client stops a session when you die, leave the spot, etc. Stopping your own session is always harmless.
RegisterNetEvent('rsg-drugs:server:cornerStop', function(reason)
    local src = source
    stopCorner(src, reason == 'spot' and 'spot' or nil)
end)

exports('IsCornerSelling', function(src) return Sessions[src] ~= nil end)
exports('StopCorner', function(src) stopCorner(src) end)

---------------------------------------------------------------------
-- the haggle
---------------------------------------------------------------------
-- what the panel is allowed to see. The buyer's limit and patience-per-round logic stay on the server.
-- Street market average (see Config.Corner.Market). Recent sales per item as { price per unit, qty }, persisted
-- in rsg_drugs_state so it survives restarts.
local MKT_KEY = 'corner_market'
local Mkt, mktDirty = {}, false

local function regionKey(region)
    if type(region) == 'string' or type(region) == 'number' then return tostring(region) end
end

-- average for the player's town when it has enough sales, else the whole server. Third result: town average?
local function mktAverage(item, region)
    local M = C.Market
    local list, town = Mkt[item], false
    local rk = region and regionKey(region)
    if rk and M and Mkt[item .. '@' .. rk] and #Mkt[item .. '@' .. rk] >= (M.MinSales or 1) then
        list, town = Mkt[item .. '@' .. rk], true
    end
    if not M or not M.Enabled or not list or #list < (M.MinSales or 1) then return nil end
    -- trimmed mean: with 10+ sales the cheapest and dearest 10% are ignored, so a few joke prices ($0.01 or $9999)
    -- from one player can't drag the average the whole server sees
    local sorted = {}
    for i, e in ipairs(list) do sorted[i] = e end
    table.sort(sorted, function(a, b) return a[1] < b[1] end)
    local cut = #sorted >= 10 and math.floor(#sorted * 0.1) or 0
    local sum, n = 0, 0
    for i = 1 + cut, #sorted - cut do sum, n = sum + sorted[i][1] * sorted[i][2], n + sorted[i][2] end
    if n < 1 then return nil end
    return round2(sum / n), #list, town
end

local function mktRecord(item, price, qty, region)
    local M = C.Market
    if not M or not M.Enabled then return end
    local keys = { item }
    local rk = region and regionKey(region)
    if rk then keys[2] = item .. '@' .. rk end
    for _, k in ipairs(keys) do
        local list = Mkt[k]
        if not list then list = {} Mkt[k] = list end
        list[#list + 1] = { round2(price), qty }
        while #list > (M.Window or 40) do table.remove(list, 1) end
    end
    mktDirty = true
end

local function mktSave()
    if not mktDirty then return end
    mktDirty = false
    MySQL.prepare('INSERT INTO rsg_drugs_state (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)', { MKT_KEY, json.encode(Mkt) })
end

CreateThread(function()
    if not DrugsEnsureDatabase() then return end
    local raw = MySQL.scalar.await('SELECT `value` FROM rsg_drugs_state WHERE `key` = ?', { MKT_KEY })
    local data = raw and json.decode(raw)
    if type(data) == 'table' then Mkt = data end
    while true do Wait(60000) mktSave() end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then mktSave() end
end)

local function payload(deal, line)
    local avg, avgN, town = mktAverage(deal.item, deal.region)
    local P = {
        item = deal.item, label = deal.label, qty = deal.qty,
        potency = Config.Quality.Enabled and math.floor(deal.potency + 0.5) or nil,
        street = H.ShowStreetPrice and deal.street or nil,
        avg = avg, avgN = avgN, avgTown = town or nil,
        buyer = (not deal.sting) and deal.buyer ~= 'regular' and deal.buyer or nil,
        regular = deal.regularName and { name = deal.regularName, lvl = deal.regularLvl } or nil,
        rankLabel = deal.rankLabel, rankBonus = deal.rankBonus, demand = deal.demand,
        minPrice = 0.01, maxPrice = H.ShowStreetPrice and deal.maxAsk or nil, step = H.Step,
        patience = deal.patience, maxPatience = deal.maxPatience,
        offer = deal.shown and deal.offer or nil,
        line = line, history = deal.history,
    }
    return P
end

-- the buyer's answer to an asking price. Returns 'accept' | 'counter' | 'walk' and the line to show.
local function respond(deal, ask)
    deal.rounds = deal.rounds + 1
    -- at or below what they would already pay
    if ask <= deal.offer + 0.0001 then return 'accept' end
    local line
    if ask <= deal.ceiling + 0.0001 then
        -- inside their limit: they meet you part of the way
        local newOffer = deal.offer + (ask - deal.offer) * rnd(H.ConcedeMin, H.ConcedeMax)
        if newOffer >= ask * (1 - H.CloseEnough) then return 'accept' end
        deal.offer = round2(newOffer)
        deal.patience = deal.patience - 1
        line = pick('corner_say_counter', 2)
    else
        -- over their limit: they dig in and lose patience
        deal.offer = round2(deal.offer + (deal.ceiling - deal.offer) * rnd(H.StubbornMin, H.StubbornMax))
        if ask > deal.ceiling * H.InsultMult then
            deal.patience = deal.patience - H.InsultPatience
            deal.insulted = true
            line = 'corner_say_insult_1'
        else
            deal.patience = deal.patience - 1
            line = pick('corner_say_toohigh', 2)
        end
    end
    deal.shown = true
    deal.history[#deal.history + 1] = { ask = ask, offer = deal.offer }
    if deal.patience <= 0 then return 'walk' end
    return 'counter', line
end

-- the deal is agreed at `price` per unit: take the goods, pay, and apply XP, heat, reputation and the market
local function completeDeal(src, deal, price)
    local Player = RSGCore.Functions.GetPlayer(src)
    local s = Sessions[src]
    if not Player or not s then endDeal(src) return { done = 'lost' } end
    local cfg = C.Items[deal.item]
    local take, _, _, dealPotency = unitsOf(src, deal.item, deal.qty)
    if not take then endDeal(src) notify(src, locale('no_item'), 'error') return { done = 'lost' } end
    local removed = 0
    for _, t in ipairs(take) do
        if exports['rsg-inventory']:RemoveItem(src, deal.item, t.amount, t.slot, deal.sting and 'rsg-drugs-corner-seized' or 'rsg-drugs-corner') then removed = removed + t.amount else break end
    end
    if removed < 1 then endDeal(src) return { done = 'lost' } end

    if deal.sting then -- an undercover officer: the goods are seized, nobody is paid
        endDeal(src)
        DrugsHeat.Add(Player.PlayerData.citizenid, C.Sting.Heat or 0)
        DrugsRep.Apply(src, 'refused')
        DrugsNpc.Refused(deal.netId)
        DrugsAlertLaw(src, true)
        notify(src, locale('corner_bust', removed, deal.label), 'error')
        DrugsLog('sales', 'Corner sting - goods seized', src, { { 'Item', ('%dx %s'):format(removed, deal.item) }, { 'Would have paid', ('$%.2f each'):format(price) } })
        if #sellable(src) == 0 then SetTimeout(4000, function() if Sessions[src] then stopCorner(src, 'out') end end) end
        return { done = 'law', line = 'corner_say_bust_1' }
    end

    local total = round2(price * removed) -- paid for exactly what left the inventory
    Player.Functions.AddMoney(C.MoneyType, total, 'rsg-drugs-corner')
    s.sold, s.earned = s.sold + removed, s.earned + total
    mktRecord(deal.item, price, removed, deal.region)
    if C.Demand and C.Demand.Enabled then pressure[deal.item] = (pressure[deal.item] or 0) + removed end
    addRankSold(Player, src, removed)
    regAfterSale(Player, src, deal, price)
    DrugsBoard.Record(Player, removed, total, dealPotency)

    local ent, netId = deal.ent, deal.netId
    local hooked = false
    if ent and DoesEntityExist(ent) then hooked = DrugsNpc.Sold(Player, ent, netId, cfg.addicts) end
    notify(src, locale('corner_sold', removed, deal.label, ('%.2f'):format(total)), 'success')
    DrugsLog('sales', 'Corner sale', src, {
        { 'Item', ('%dx %s'):format(removed, deal.item) }, { 'Price', ('$%.2f each (street $%.2f)'):format(price, deal.street) },
        { 'Paid', ('$%.2f (%s)'):format(total, C.MoneyType) }, { 'Rounds', deal.rounds }, { 'Buyer', hooked and 'Addict' or 'Ambient NPC' },
    })
    DrugsXP.Add(src, (Config.XP.Sell[deal.item] or 0) * removed, 'sell')
    DrugsEcon.Record(src, deal.item, removed)
    DrugsHeat.Add(Player.PlayerData.citizenid, Config.Heat.PerSale * removed * (deal.townHeat or 1.0))
    DrugsRep.Apply(src, 'sale')

    endDeal(src)
    local out = { done = 'sold', price = price, total = total, qty = removed, hooked = hooked, line = pick('corner_say_accept', 2) }
    -- nothing left to sell: the session ends after the handover
    if #sellable(src) == 0 then SetTimeout(4000, function() if Sessions[src] then stopCorner(src, 'out') end end) end
    return out
end

-- the buyer gave up. An insulted buyer may report the player.
local function walkOff(src, deal)
    local Player = RSGCore.Functions.GetPlayer(src)
    endDeal(src)
    if deal.regularId and deal.insulted and Player then -- you insulted a regular: loyalty drops, maybe for good
        local r, gone = regUpdate(Player, deal.regularId, function(x) x.loyalty = (x.loyalty or 1) - 2 end)
        if r and gone then notify(src, locale('corner_regular_lost', r.name), 'error') end
    end
    if deal.insulted and Player and math.random(100) <= H.CallLawChance then
        DrugsNpc.Refused(deal.netId)
        DrugsHeat.Add(Player.PlayerData.citizenid, Config.Heat.PerRefusal * (deal.townHeat or 1.0))
        DrugsRep.Apply(src, 'refused')
        DrugsLog('sales', 'Corner buyer insulted - law alerted', src, { { 'Item', deal.item }, { 'Asked', ('$%.2f each (their limit $%.2f)'):format(deal.lastAsk or 0, deal.ceiling) } })
        notify(src, locale('corner_reported'), 'error')
        DrugsAlertLaw(src)
        return { done = 'law', line = 'corner_say_law_1' }
    end
    return { done = 'walk', line = 'corner_say_walk_1' }
end

-- still a valid haggle? Returns the deal, or nil after closing it.
local function liveDeal(src)
    local deal, s = Deals[src], Sessions[src]
    if not deal or not s then return nil end
    local ped = GetPlayerPed(src)
    local pos = GetEntityCoords(ped)
    if #(pos - s.pos) > C.Spot.LeaveRadius + 5.0 then stopCorner(src, 'spot') return nil end
    if not deal.ent or not DoesEntityExist(deal.ent) or #(GetEntityCoords(deal.ent) - pos) > 8.0 then endDeal(src) return nil end
    if countOf(src, deal.item) < deal.qty then endDeal(src) notify(src, locale('no_item'), 'error') return nil end
    return deal
end

-- a buyer arrived. Returns { ok = true, data = payload } or { ok = false, reason }.
Callback('rsg-drugs:server:cornerApproach', function(src, netId)
    local s = Sessions[src]
    local Player = RSGCore.Functions.GetPlayer(src)
    if not s or not Player or Deals[src] then return { ok = false, reason = 'busy' } end
    local now = os.time()
    if lastDeal[src] and now - lastDeal[src] < H.MinInterval then return { ok = false, reason = 'rate' } end
    if (H.MaxDealsPerHour or 0) > 0 then
        local hr = hourly[src]
        if not hr or now - hr.since >= 3600 then hr = { since = now, n = 0 } hourly[src] = hr end
        if hr.n >= H.MaxDealsPerHour then return { ok = false, reason = 'rate' } end
    end
    if #(GetEntityCoords(GetPlayerPed(src)) - s.pos) > C.Spot.LeaveRadius + 5.0 then stopCorner(src, 'spot') return { ok = false, reason = 'spot' } end
    if Player.PlayerData.metadata.isdead or DrugsInRehab(src) then return { ok = false, reason = 'blocked' } end

    local ent; ent, netId = DrugsNpc.FromNet(src, netId, 8.0)
    if not ent or DealPeds[netId] then return { ok = false, reason = 'npc' } end
    if DrugsNpc.Status(netId) ~= 'ok' then return { ok = false, reason = 'npc' } end
    -- a town that has turned against you: most people want nothing to do with you
    if DrugsRep.Hostile(src) and math.random() > (Config.Reputation.HostileBuyMult or 0.5) then return { ok = false, reason = 'hostile' } end

    local items = sellable(src)
    if #items == 0 then stopCorner(src, 'out') return { ok = false, reason = 'out' } end
    local name = items[math.random(#items)]
    local cfg = C.Items[name]
    local region = DrugsEcon.Region(src)
    local town = townOf(region)
    if C.Approach.Debug then print(('[rsg-drugs] corner region: %s'):format(tostring(region))) end
    local reg = pickRegular(Player) -- a regular is never undercover
    local buyer = reg and 'regular' or pickBuyer(town.sting)
    local B = C.Buyers[buyer] or C.Buyers.regular
    local sting = buyer == 'undercover'
    local regLvl = reg and regLevel(reg) or 0
    local maxQty = math.max(1, math.floor((cfg.maxQty or 1) * (B.qty or 1.0) * (1 + regLvl * ((R and R.QtyBonus) or 0)) + 0.5))
    local qty = math.random(1, math.max(1, math.min(countOf(src, name), maxQty)))
    local take, n, mult, potency = unitsOf(src, name, qty)
    if not take then return { ok = false, reason = 'out' } end

    -- street price: base price with the potency of what will be sold, the rsg-skills sell perk and the town's market
    -- ...then your corner rank and the market's demand
    local rankBonus, _, rankLabel = rankOf(Player)
    local dMult = demandMult(name)
    local street = round2(math.max(0.05, cfg.price * mult * (1 + DrugsSkills.Perk(src, 'sell_bonus') / 100) * DrugsEcon.Multiplier(src, name)
        * (1 + rankBonus / 100) * dMult * town.price))
    local S = C.Sting
    local ceiling = street * (sting and rnd(S.CeilingMin, S.CeilingMax)
        or rnd(H.CeilingMin, H.CeilingMax) * (B.ceiling or 1.0) * town.ceiling * (1 + regLvl * ((R and R.CeilingBonus) or 0) / 100))
    local patience = math.max(2, math.random(H.PatienceMin, H.PatienceMax) + (B.patience or 0) + (reg and 1 or 0))
    local deal = {
        item = name, label = itemLabel(name), qty = n, potency = potency, buyer = buyer, sting = sting,
        region = region, townHeat = town.heat, rankLabel = rankLabel, rankBonus = rankBonus > 0 and rankBonus or nil,
        demand = dMult < 0.995 and math.floor((dMult - 1) * 100 + 0.5) or nil,
        street = street, ceiling = ceiling,
        offer = round2(ceiling * (sting and rnd(S.OpenMin, S.OpenMax) or rnd(H.OpeningMin, H.OpeningMax))),
        maxAsk = round2(street * H.MaxAskMult),
        patience = patience, maxPatience = patience, rounds = 0, shown = sting, insulted = false,
        history = {}, ent = ent, netId = netId, lastOffer = 0, expires = now + H.DealSeconds,
    }
    if reg then
        deal.regularId, deal.regularName, deal.regularLvl = reg.id, reg.name, regLvl
        regUpdate(Player, reg.id, function(x) x.back = now + R.CooldownMinutes * 60 end) -- not back again too soon
    end
    Deals[src], DealPeds[netId], lastDeal[src] = deal, src, now
    if hourly[src] then hourly[src].n = hourly[src].n + 1 end
    return { ok = true, data = payload(deal, sting and pick('corner_say_greet_sting', 2) or pick('corner_say_greet', 2)) }
end)

-- the player named a price
Callback('rsg-drugs:server:cornerOffer', function(src, price)
    local deal = liveDeal(src)
    if not deal then return { done = 'lost' } end
    local t = GetGameTimer()
    if t - deal.lastOffer < H.OfferCooldown * 1000 then return payload(deal) end
    deal.lastOffer = t
    price = tonumber(price)
    if not price or price ~= price or price == math.huge or price == -math.huge then return payload(deal) end
    price = round2(math.max(0.01, math.min(price, deal.maxAsk)))
    deal.lastAsk = price

    local result, line = respond(deal, price)
    if result == 'accept' then return completeDeal(src, deal, price) end
    if result == 'walk' then return walkOff(src, deal) end
    return payload(deal, line)
end)

-- the player takes the buyer's last counter-offer
Callback('rsg-drugs:server:cornerAccept', function(src)
    local deal = liveDeal(src)
    if not deal then return { done = 'lost' } end
    if not deal.shown then return payload(deal) end -- they haven't named a price yet
    return completeDeal(src, deal, deal.offer)
end)

RegisterNetEvent('rsg-drugs:server:cornerWalk', function()
    endDeal(source)
end)

---------------------------------------------------------------------
-- housekeeping
---------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for src, deal in pairs(Deals) do
            if now > deal.expires then
                endDeal(src)
                TriggerClientEvent('rsg-drugs:client:cornerDealEnd', src)
            end
        end
        for src, s in pairs(Sessions) do
            local Player = RSGCore.Functions.GetPlayer(src)
            if not Player then
                stopCorner(src, 'silent')
            elseif Player.PlayerData.metadata.isdead then
                stopCorner(src)
            elseif #(GetEntityCoords(GetPlayerPed(src)) - s.pos) > C.Spot.LeaveRadius + 5.0 then
                stopCorner(src, 'spot')
            end
        end
    end
end)

local function cleanup(src)
    stopCorner(src, 'silent')
    lastDeal[src], hourly[src] = nil, nil
end
AddEventHandler('playerDropped', function() cleanup(source) end)
AddEventHandler('RSGCore:Server:OnPlayerUnload', cleanup)
