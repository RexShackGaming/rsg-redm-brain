local RSGCore = exports['rsg-core']:GetCoreObject()

local Requests = {}   -- [target src] = { from = src, expires = ms }
local Sessions = {}   -- [src] = session (both players point at the same table)
local Cooldown = {}   -- [src] = { [action] = ms }
local Declined = {}   -- [citizenid .. ':' .. citizenid] = ms until that requester may ask that player again

local CashItems = { dollar = true, cent = true, blood_dollar = true, blood_cent = true }

local function Notify(src, key, kind, ...)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('title'), description = locale(key, ...), type = kind or 'error', duration = 5000,
    })
end

local function Throttle(src, action, ms)
    local now = GetGameTimer()
    Cooldown[src] = Cooldown[src] or {}
    if Cooldown[src][action] and now - Cooldown[src][action] < ms then return true end
    Cooldown[src][action] = now
    return false
end

local function CharName(Player)
    local ci = Player.PlayerData.charinfo or {}
    return ((ci.firstname or '') .. ' ' .. (ci.lastname or ''))
end

local function Available(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local meta = Player.PlayerData.metadata or {}
    if meta.isdead or meta.inlaststand or meta.ishandcuffed then return nil end
    return Player
end

local function InRange(a, b, max)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return false end
    if GetPlayerRoutingBucket(a) ~= GetPlayerRoutingBucket(b) then return false end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= max
end

local function Same(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function Copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Copy(v) end
    return out
end

local function Tradable(item)
    return not (CashItems[item.name] or Config.BlacklistItems[item.name] or Config.BlacklistTypes[item.type or ''])
end

-- the player's items keyed by numeric slot
local function ItemsBySlot(Player)
    local out = {}
    for key, it in pairs(Player.PlayerData.items or {}) do
        local slot = it and math.tointeger(tonumber(it.slot) or tonumber(key))
        if slot and it.name then out[slot] = it end
    end
    return out
end

local function CashCents(Player)
    return math.floor((tonumber(Player.PlayerData.money.cash) or 0) * 100 + 0.5)
end

-- only what the other player needs to see; the rest of the item metadata stays on the server
local function View(slot, item, amount)
    local info = item.info or {}
    return {
        slot = slot, name = item.name, amount = amount,
        label = item.label or item.name, image = item.image,
        quality = tonumber(info.quality),
        serie = info.serie and tostring(info.serie) or nil,
    }
end

local function OfferView(offer)
    local list = {}
    for slot, o in pairs(offer.items) do list[#list + 1] = View(slot, o, o.amount) end
    table.sort(list, function(x, y) return x.slot < y.slot end)
    return { items = list, cents = offer.cents }
end

local function Other(s, src)
    return src == s.ids[1] and s.ids[2] or s.ids[1]
end

-- changes whenever anything shown in a player's own item list or cash changes
local function Signature(Player)
    local parts = {}
    for slot, it in pairs(ItemsBySlot(Player)) do
        parts[#parts + 1] = ('%d:%s:%d:%s'):format(slot, it.name, it.amount, tostring(it.info and it.info.quality))
    end
    table.sort(parts)
    parts[#parts + 1] = tostring(CashCents(Player))
    return table.concat(parts, '|')
end

-- players = { [src] = Player }, fetched once per update because every GetPlayer call copies the player
local function Fetch(s)
    return { [s.ids[1]] = Available(s.ids[1]), [s.ids[2]] = Available(s.ids[2]) }
end

local function StateFor(s, src, Player)
    local other = Other(s, src)
    local inventory = {}
    if Player then
        for slot, it in pairs(ItemsBySlot(Player)) do
            if Tradable(it) then inventory[#inventory + 1] = View(slot, it, it.amount) end
        end
        table.sort(inventory, function(x, y) return x.slot < y.slot end)
        s.seen[src] = Signature(Player)
    end
    local lock = 0
    if s.lockedAt then lock = math.max(0, Config.LockSeconds * 1000 - (GetGameTimer() - s.lockedAt)) end
    return {
        rev = s.rev,
        name = s.names[other], id = other,
        inventory = inventory,
        cash = Player and CashCents(Player) or 0,
        mine = OfferView(s.offers[src]), theirs = OfferView(s.offers[other]),
        ready = { mine = s.ready[src] == true, theirs = s.ready[other] == true },
        confirmed = { mine = s.confirmed[src] == true, theirs = s.confirmed[other] == true },
        lockMs = lock,
    }
end

local function Push(s, players)
    if s.closed then return end
    players = players or Fetch(s)
    for _, src in ipairs(s.ids) do
        TriggerClientEvent('rsg-playertrade:client:update', src, StateFor(s, src, players[src]))
    end
end

-- any change to either offer withdraws both players' approval
local function Changed(s)
    s.rev = s.rev + 1
    s.ready, s.confirmed, s.lockedAt = {}, {}, nil
end

-- cancelledBy: that player is told they cancelled, the other that their partner did
local function EndSession(s, key, kind, cancelledBy)
    if s.closed then return end
    s.closed = true
    for _, src in ipairs(s.ids) do
        if Sessions[src] == s then Sessions[src] = nil end
        TriggerClientEvent('rsg-playertrade:client:close', src)
        if cancelledBy then
            Notify(src, src == cancelledBy and 'cancelled' or 'partner_cancelled', 'inform')
        elseif key then
            Notify(src, key, kind)
        end
    end
end

-- drops offered stacks that have since moved or changed (used, given away, decayed...)
local function Revalidate(s, players)
    local changed = false
    for _, src in ipairs(s.ids) do
        local Player = players[src]
        local items = Player and ItemsBySlot(Player) or {}
        for slot, o in pairs(s.offers[src].items) do
            local it = items[slot]
            if not it or it.name ~= o.name or it.amount < o.amount or not Same(it.info or {}, o.info) then
                s.offers[src].items[slot] = nil
                changed = true
            end
        end
        if Player and s.offers[src].cents > CashCents(Player) then
            s.offers[src].cents = 0
            changed = true
        end
    end
    if changed then Changed(s) end
    return changed
end

--------------------------------------------------------------------------------
-- Requests
--------------------------------------------------------------------------------
local function AcceptRequest(src)
    local req = Requests[src]
    if not req or req.expires <= GetGameTimer() then
        Requests[src] = nil
        return Notify(src, 'no_request')
    end
    local from = req.from
    Requests[src] = nil
    local me, them = Available(src), Available(from)
    if not me then return Notify(src, 'cannot_trade') end
    if not them then return Notify(src, 'no_player') end
    if Sessions[src] then return Notify(src, 'you_busy') end
    if Sessions[from] then return Notify(src, 'target_busy') end
    if not InRange(src, from, Config.Distance) then return Notify(src, 'too_far') end

    local s = {
        ids = { from, src }, rev = 1, started = GetGameTimer(),
        names = { [from] = CharName(them), [src] = CharName(me) },
        cids = { [from] = them.PlayerData.citizenid, [src] = me.PlayerData.citizenid },
        offers = { [from] = { items = {}, cents = 0 }, [src] = { items = {}, cents = 0 } },
        ready = {}, confirmed = {}, seen = {},
    }
    Sessions[from], Sessions[src] = s, s
    Requests[from] = nil
    local players = { [from] = them, [src] = me }
    for _, id in ipairs(s.ids) do
        exports['rsg-inventory']:CloseInventory(id)
        TriggerClientEvent('rsg-playertrade:client:open', id, StateFor(s, id, players[id]))
    end
end

local function PairKey(from, to)
    return from.PlayerData.citizenid .. ':' .. to.PlayerData.citizenid
end

local function SendRequest(src, target)
    target = math.tointeger(tonumber(target))
    if not target or target == src then return Notify(src, 'no_player') end
    if Sessions[src] then return Notify(src, 'you_busy') end
    local me = Available(src)
    if not me then return Notify(src, 'cannot_trade') end
    -- one message for offline, unavailable and out of range, so /trade can't be used to probe server ids
    local them = Available(target)
    if not them or not InRange(src, target, Config.Distance) then return Notify(src, 'no_player') end

    -- asking someone who has already asked you accepts their request
    local mine = Requests[src]
    if mine and mine.from == target and mine.expires > GetGameTimer() then return AcceptRequest(src) end

    if Sessions[target] then return Notify(src, 'target_busy') end
    local pending = Requests[target]
    if pending and pending.from ~= src and pending.expires > GetGameTimer() then return Notify(src, 'target_busy') end
    if Throttle(src, 'request', Config.RequestCooldown * 1000) then return Notify(src, 'wait') end

    local blocked = Declined[PairKey(me, them)]
    if blocked and blocked > GetGameTimer() then return Notify(src, 'wait') end

    Requests[target] = { from = src, expires = GetGameTimer() + Config.RequestTimeout * 1000 }
    Notify(src, 'request_sent', 'inform')
    Notify(target, 'request_received', 'inform', CharName(me), src,
        tostring(Config.AcceptCommand or '-'), tostring(Config.DeclineCommand or '-'))
end

local function DeclineRequest(src)
    local req = Requests[src]
    if not req then return Notify(src, 'no_request') end
    Requests[src] = nil
    local from, me = RSGCore.Functions.GetPlayer(req.from), RSGCore.Functions.GetPlayer(src)
    if from and me then Declined[PairKey(from, me)] = GetGameTimer() + Config.DeclineCooldown * 1000 end
    Notify(src, 'request_declined_self', 'inform')
    Notify(req.from, 'request_declined', 'inform')
end

RegisterNetEvent('rsg-playertrade:server:request', function(target)
    local src = source
    if Throttle(src, 'ask', 1000) then return end
    SendRequest(src, target)
end)

if Config.Command then
    RegisterCommand(Config.Command, function(src, args)
        if src > 0 and not Throttle(src, 'ask', 1000) then SendRequest(src, args[1]) end
    end, false)
end
if Config.AcceptCommand then
    RegisterCommand(Config.AcceptCommand, function(src)
        if src > 0 and not Throttle(src, 'accept', 1000) then AcceptRequest(src) end
    end, false)
end
if Config.DeclineCommand then
    RegisterCommand(Config.DeclineCommand, function(src)
        if src > 0 and not Throttle(src, 'decline', 1000) then DeclineRequest(src) end
    end, false)
end

--------------------------------------------------------------------------------
-- Offers
--------------------------------------------------------------------------------
-- amount 0 removes the slot from the offer; otherwise it sets the offered quantity
RegisterNetEvent('rsg-playertrade:server:setItem', function(slot, amount, name)
    local src = source
    local s = Sessions[src]
    slot, amount = math.tointeger(tonumber(slot)), math.tointeger(tonumber(amount))
    if not s or not slot or not amount or amount < 0 then return end
    if Throttle(src, 'offer', 100) then return end
    local Player = Available(src)
    if not Player then return end

    local offer = s.offers[src]
    if amount == 0 then
        if not offer.items[slot] then return end
        offer.items[slot] = nil
    else
        local it = ItemsBySlot(Player)[slot]
        if not it or it.name ~= name or amount > it.amount or not Tradable(it) then
            Notify(src, 'invalid_item')
            return Push(s)
        end
        local current = offer.items[slot]
        if current and current.amount == amount and current.name == it.name and Same(current.info, it.info or {}) then return end
        if not current then
            local count = 0
            for _ in pairs(offer.items) do count = count + 1 end
            if count >= Config.MaxOfferSlots then
                Notify(src, 'offer_full')
                return Push(s)
            end
        end
        offer.items[slot] = { name = it.name, label = it.label, image = it.image, amount = amount, info = Copy(it.info or {}) }
    end
    Changed(s)
    Push(s)
end)

RegisterNetEvent('rsg-playertrade:server:setCash', function(dollars)
    local src = source
    local s = Sessions[src]
    dollars = tonumber(dollars)
    if not s or not Config.AllowCash then return end
    if Throttle(src, 'cash', 250) then return end
    local Player = Available(src)
    if not Player then return end
    -- these comparisons also reject NaN and infinity
    if not dollars or not (dollars >= 0 and dollars <= Config.MaxCash) then
        Notify(src, 'invalid_amount')
        return Push(s)
    end
    local cents = math.floor(dollars * 100 + 0.5)
    if cents > CashCents(Player) then
        Notify(src, 'not_enough_cash')
        return Push(s)
    end
    if cents == s.offers[src].cents then return Push(s) end
    s.offers[src].cents = cents
    Changed(s)
    Push(s)
end)

--------------------------------------------------------------------------------
-- Ready, confirm, complete
--------------------------------------------------------------------------------
-- `rev` is the version of the offers the player was looking at: a click made against an older one is ignored
RegisterNetEvent('rsg-playertrade:server:ready', function(rev, state)
    local src = source
    local s = Sessions[src]
    if not s or rev ~= s.rev then return end -- the update with the newer revision is already on its way

    if state ~= true then -- taking approval back is never throttled
        if not s.ready[src] then return end
        s.ready[src], s.confirmed, s.lockedAt = nil, {}, nil
        return Push(s)
    end

    if s.ready[src] or Throttle(src, 'ready', 250) then return end
    local players = Fetch(s)
    if Revalidate(s, players) then return Push(s, players) end
    local mine, theirs = s.offers[src], s.offers[Other(s, src)]
    if not next(mine.items) and mine.cents == 0 and not next(theirs.items) and theirs.cents == 0 then
        return Notify(src, 'empty_trade')
    end
    s.ready[src] = true
    if s.ready[s.ids[1]] and s.ready[s.ids[2]] then s.lockedAt = GetGameTimer() end
    Push(s, players)
end)

local failKeys = {
    offer_changed = 'failed_changed', no_cash = 'failed_cash', cash_unavailable = 'failed_cash', no_room = 'failed_room',
}

local function ExportOffer(offer)
    local items = {}
    for slot, o in pairs(offer.items) do
        items[#items + 1] = { slot = slot, name = o.name, amount = o.amount, info = o.info }
    end
    table.sort(items, function(x, y) return x.slot < y.slot end)
    return { items = items, cents = offer.cents }
end

local function Describe(offer)
    local parts = {}
    for _, o in ipairs(offer.items) do
        local serie = o.info.serie and (' (%s)'):format(o.info.serie) or ''
        parts[#parts + 1] = ('%dx %s%s'):format(o.amount, o.name, serie)
    end
    if offer.cents > 0 then parts[#parts + 1] = ('$%.2f'):format(offer.cents / 100) end
    return #parts > 0 and table.concat(parts, ', ') or 'nothing'
end

local function Complete(s)
    local a, b = s.ids[1], s.ids[2]
    for _, id in ipairs(s.ids) do
        local Player = Available(id)
        -- same character as when the trade started
        if not Player or Player.PlayerData.citizenid ~= s.cids[id] then return EndSession(s, 'cancelled', 'error') end
    end
    if not InRange(a, b, Config.CancelDistance) then return EndSession(s, 'too_far', 'error') end

    local offerA, offerB = ExportOffer(s.offers[a]), ExportOffer(s.offers[b])
    local called, ok, reason = pcall(function()
        return exports['rsg-inventory']:TradeItems(a, b, offerA, offerB)
    end)
    if not called then
        -- an error can't tell us how far the swap got, so don't claim nothing moved
        print(('^1[rsg-playertrade] TradeItems errored between %s and %s (is rsg-inventory 3.6.0 or newer running?): %s^7'):format(
            s.cids[a], s.cids[b], tostring(ok)))
        return EndSession(s, 'failed_error', 'error')
    end
    if not ok then
        -- nothing moved: keep the window open so the players can fix the offer
        local players = Fetch(s)
        if not Revalidate(s, players) then Changed(s) end
        for _, id in ipairs(s.ids) do Notify(id, failKeys[reason] or 'failed_generic') end
        return Push(s, players)
    end

    EndSession(s, 'completed', 'success')
    TriggerEvent('rsg-log:server:CreateLog', 'playerinventory', 'Player trade', 'green',
        ('**%s** (%s) gave: %s\n**%s** (%s) gave: %s'):format(
            s.names[a], s.cids[a], Describe(offerA), s.names[b], s.cids[b], Describe(offerB)))
    -- for other server scripts (tax, reputation, audit)
    TriggerEvent('rsg-playertrade:server:completed', {
        { source = a, citizenid = s.cids[a], offer = offerA },
        { source = b, citizenid = s.cids[b], offer = offerB },
    })
end

RegisterNetEvent('rsg-playertrade:server:confirm', function(rev)
    local src = source
    local s = Sessions[src]
    if not s or rev ~= s.rev or s.confirmed[src] then return end
    if not s.lockedAt or GetGameTimer() - s.lockedAt < Config.LockSeconds * 1000 then return end
    if Throttle(src, 'confirm', 250) then return end
    local players = Fetch(s)
    if Revalidate(s, players) then return Push(s, players) end

    s.confirmed[src] = true
    if s.confirmed[Other(s, src)] then return Complete(s) end
    Push(s, players)
end)

RegisterNetEvent('rsg-playertrade:server:cancel', function()
    local src = source
    if Sessions[src] then EndSession(Sessions[src], nil, nil, src) end
end)

--------------------------------------------------------------------------------
-- Watchdog and lifecycle
--------------------------------------------------------------------------------
-- each session once (Sessions holds it under both players); a copy, so sessions can end while looping
local function LiveSessions()
    local live = {}
    for _, s in pairs(Sessions) do live[s] = true end
    return live
end

local function Watch(s, now)
    local players = Fetch(s)
    local a, b = s.ids[1], s.ids[2]
    if not players[a] or not players[b] then return EndSession(s, 'cancelled', 'error') end
    if not InRange(a, b, Config.CancelDistance) then return EndSession(s, 'too_far', 'error') end
    if now - s.started > Config.TradeTimeout * 1000 then return EndSession(s, 'timed_out', 'error') end
    if Revalidate(s, players) or s.seen[a] ~= Signature(players[a]) or s.seen[b] ~= Signature(players[b]) then
        Push(s, players)
    end
end

CreateThread(function()
    while true do
        Wait(500)
        local now = GetGameTimer()
        for s in pairs(LiveSessions()) do Watch(s, now) end
        for target, req in pairs(Requests) do
            if req.expires <= now then
                Requests[target] = nil
                Notify(req.from, 'request_expired', 'inform')
                Notify(target, 'request_expired', 'inform')
            end
        end
        for key, expires in pairs(Declined) do
            if expires <= now then Declined[key] = nil end
        end
    end
end)

local function Forget(src)
    if Sessions[src] then EndSession(Sessions[src], nil, nil, src) end
    Requests[src] = nil
    for target, req in pairs(Requests) do
        if req.from == src then Requests[target] = nil end
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    Forget(src)
    Cooldown[src] = nil
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', Forget)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for s in pairs(LiveSessions()) do EndSession(s) end
end)

exports('IsTrading', function(src) return Sessions[tonumber(src) or -1] ~= nil end)
