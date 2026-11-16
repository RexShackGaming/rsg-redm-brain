local RSGCore = exports['rsg-core']:GetCoreObject()
local Inventory = exports['rsg-inventory']

-- Player to player card trading.
-- A trade is one session shared by two players. The server keeps both offers and the "ready" flags;
-- the clients only say "offer N of X", "I'm ready" or "cancel". The cards change hands when both are ready.
local sessions = {} -- [src] = session (both members point at the same table)

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
local function getPlayer(src)
    return RSGCore.Functions.GetPlayer(src)
end

local function playerName(src)
    local Player = getPlayer(src)
    local charinfo = Player and Player.PlayerData.charinfo
    if not charinfo then return '?' end
    return ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')
end

local function partnerOf(session, src)
    return session.a == src and session.b or session.a
end

-- copies the player has to keep (one of each single card when Config.PlayerTrade.DuplicatesOnly)
local function reserve(name)
    local info = Cards.Info[name]
    return (Config.PlayerTrade.DuplicatesOnly and info and not info.deck) and 1 or 0
end

local function available(counts, name)
    return math.max(0, (counts[name] or 0) - reserve(name))
end

local function offerTotal(offer)
    local total = 0
    for _, amount in pairs(offer) do total = total + amount end
    return total
end

local function itemEntry(name, amount)
    return {
        name = name,
        label = CardsServer.itemLabel(name),
        image = CardsServer.itemImage(name),
        amount = amount,
        order = Cards.Info[name].order,
    }
end

local function sortByOrder(list)
    table.sort(list, function(a, b) return a.order < b.order end)
    return list
end

local function offerList(offer)
    local list = {}
    for name, amount in pairs(offer) do list[#list + 1] = itemEntry(name, amount) end
    return sortByOrder(list)
end

-- what the UI of `src` shows
local function buildState(session, src)
    local other = partnerOf(session, src)
    local counts = CardsServer.countCards(src, true) -- inventory and card boxes
    local mine = {}
    for name in pairs(counts) do
        local free = available(counts, name)
        if free > 0 then
            local entry = itemEntry(name, free)
            entry.offered = session.offers[src][name] or 0
            mine[#mine + 1] = entry
        end
    end
    return {
        phase = 'open',
        dupsOnly = Config.PlayerTrade.DuplicatesOnly == true,
        me = { offer = offerList(session.offers[src]), ready = session.ready[src] == true },
        them = { name = playerName(other), offer = offerList(session.offers[other]), ready = session.ready[other] == true },
        mine = sortByOrder(mine),
    }
end

local function push(session)
    for _, id in ipairs({ session.a, session.b }) do
        TriggerClientEvent('rsg-cards:client:tradeState', id, buildState(session, id))
    end
end

-- ends the trade and tells both players why (reason = the suffix of an `ptrade_<reason>` locale key)
local function closeSession(session, reason)
    if sessions[session.a] == session then sessions[session.a] = nil end
    if sessions[session.b] == session then sessions[session.b] = nil end
    for _, id in ipairs({ session.a, session.b }) do
        if getPlayer(id) then TriggerClientEvent('rsg-cards:client:tradeClosed', id, reason) end
    end
end

local function playersClose(a, b, radius)
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    if not pedA or pedA == 0 or not pedB or pedB == 0 then return false end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) <= radius
end

---------------------------------------------------------------------
-- THE EXCHANGE
---------------------------------------------------------------------
local function execute(session)
    if session.executing then return end
    session.executing = true

    local a, b = session.a, session.b
    local playerA, playerB = getPlayer(a), getPlayer(b)
    if not playerA or not playerB then return closeSession(session, 'cancelled') end
    if not playersClose(a, b, Config.PlayerTrade.Distance + 3.0) then return closeSession(session, 'distance') end

    local sides = { { src = a, dst = b }, { src = b, dst = a } }

    -- everything offered is still there and the other player has room for it
    for _, side in ipairs(sides) do
        local counts = CardsServer.countCards(side.src, true)
        for name, amount in pairs(session.offers[side.src]) do
            if amount > available(counts, name) then return closeSession(session, 'changed') end
            if not Inventory:CanAddItem(side.dst, name, amount) then return closeSession(session, 'full') end
        end
    end

    -- take everything out first; if any step fails, everything taken is handed back
    local taken, touched = {}, {}
    for _, side in ipairs(sides) do
        for name, amount in pairs(session.offers[side.src]) do
            if CardsServer.removeCards(side.src, name, amount, 'rsg-cards:ptrade', true, touched) then
                taken[#taken + 1] = { src = side.src, dst = side.dst, name = name, amount = amount }
            else
                for _, entry in ipairs(taken) do
                    Inventory:AddItem(entry.src, entry.name, entry.amount, nil, nil, 'rsg-cards:ptrade-refund')
                end
                CardsServer.saveStashes(touched)
                return closeSession(session, 'changed')
            end
        end
    end
    CardsServer.saveStashes(touched)

    -- hand over; whatever can't be handed over goes back to its owner, so nothing is ever lost
    local log = {}
    for _, entry in ipairs(taken) do
        local given = Inventory:CanAddItem(entry.dst, entry.name, entry.amount)
            and Inventory:AddItem(entry.dst, entry.name, entry.amount, nil, nil, 'rsg-cards:ptrade')
        if given then
            log[#log + 1] = ('%s -> %s: %dx %s'):format(playerName(entry.src), playerName(entry.dst), entry.amount, entry.name)
        else
            Inventory:AddItem(entry.src, entry.name, entry.amount, nil, nil, 'rsg-cards:ptrade-refund')
            entry.failed = true
        end
    end

    CardsServer.log(('**Cards traded between players**\n%s'):format(table.concat(log, '\n')))
    closeSession(session, 'done')

    -- received single cards count as found (collection, set bonus, leaderboard)
    if Config.PlayerTrade.CountAsFound then
        for _, entry in ipairs(taken) do
            local info = Cards.Info[entry.name]
            local receiver = getPlayer(entry.dst)
            if not entry.failed and info and not info.deck and receiver then
                pcall(CardsServer.markFound, receiver, entry.name)
            end
        end
    end
end

---------------------------------------------------------------------
-- REQUESTS
---------------------------------------------------------------------
local function requestTrade(src, targetId)
    if not Config.PlayerTrade.Enabled then return end
    targetId = tonumber(targetId)
    if not targetId or targetId ~= math.floor(targetId) or targetId < 1 or targetId == src then return end
    if not CardsServer.throttle(src, 'ptradeRequest', 3) then return end

    local player, target = getPlayer(src), getPlayer(targetId)
    if not player or not target then return end
    if sessions[src] or sessions[targetId] then
        return CardsServer.notify(src, locale('ptrade_busy'), 'error')
    end
    if not playersClose(src, targetId, Config.PlayerTrade.Distance) then
        return CardsServer.notify(src, locale('ptrade_too_far'), 'error')
    end

    local session = {
        a = src, b = targetId, phase = 'invite',
        offers = { [src] = {}, [targetId] = {} },
        ready = { [src] = false, [targetId] = false },
    }
    sessions[src], sessions[targetId] = session, session

    CardsServer.notify(src, locale('ptrade_sent', playerName(targetId)), 'inform')
    TriggerClientEvent('rsg-cards:client:tradeInvite', targetId, playerName(src))

    SetTimeout((tonumber(Config.PlayerTrade.InviteSeconds) or 30) * 1000, function()
        if sessions[src] == session and session.phase == 'invite' then closeSession(session, 'expired') end
    end)
end

RegisterNetEvent('rsg-cards:server:ptradeRequest', function(targetId)
    requestTrade(source, targetId)
end)

RSGCore.Commands.Add(Config.PlayerTrade.Command, locale('command_cardtrade'),
    { { name = 'id', help = locale('command_cardtrade_id') } }, true, function(source, args)
        requestTrade(source, args[1])
    end, 'user')

-- the invited player accepts or declines
RegisterNetEvent('rsg-cards:server:ptradeRespond', function(accept)
    local src = source
    local session = sessions[src]
    if not session or session.phase ~= 'invite' or session.b ~= src then return end
    if accept ~= true then return closeSession(session, 'declined') end
    if not playersClose(session.a, session.b, Config.PlayerTrade.Distance + 3.0) then
        return closeSession(session, 'distance')
    end
    session.phase = 'open'
    push(session)
end)

---------------------------------------------------------------------
-- THE TRADE WINDOW
---------------------------------------------------------------------
-- "I offer `amount` of `name`" (0 takes it back). Any change makes both players confirm again.
RegisterNetEvent('rsg-cards:server:ptradeOffer', function(name, amount)
    local src = source
    local session = sessions[src]
    if not session or session.phase ~= 'open' or session.executing then return end
    if type(name) ~= 'string' or not Cards.Info[name] then return end
    amount = tonumber(amount)
    if not amount or amount < 0 or amount ~= math.floor(amount) or amount > 100000 then return end
    if not CardsServer.throttle(src, 'ptradeOffer', 0.1) then return end

    local offer = session.offers[src]
    if amount > available(CardsServer.countCards(src, true), name) then
        return push(session) -- the UI was out of date: send the real numbers
    end

    local previous = offer[name]
    offer[name] = amount > 0 and amount or nil
    if offerTotal(offer) > (tonumber(Config.PlayerTrade.MaxPerSide) or 30) then
        offer[name] = previous
        CardsServer.notify(src, locale('ptrade_limit', Config.PlayerTrade.MaxPerSide), 'error')
        return push(session)
    end

    session.ready[session.a], session.ready[session.b] = false, false
    push(session)
end)

RegisterNetEvent('rsg-cards:server:ptradeReady', function(ready)
    local src = source
    local session = sessions[src]
    if not session or session.phase ~= 'open' or session.executing then return end
    if not CardsServer.throttle(src, 'ptradeReady', 0.3) then return end

    session.ready[src] = ready == true
    if session.ready[session.a] and session.ready[session.b] then
        if offerTotal(session.offers[session.a]) + offerTotal(session.offers[session.b]) == 0 then
            session.ready[session.a], session.ready[session.b] = false, false
            return push(session)
        end
        return execute(session)
    end
    push(session)
end)

RegisterNetEvent('rsg-cards:server:ptradeCancel', function()
    local session = sessions[source]
    if session and not session.executing then closeSession(session, 'cancelled') end
end)

---------------------------------------------------------------------
-- CLEANUP
---------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local session = sessions[source]
    if session and not session.executing then closeSession(session, 'cancelled') end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, session in pairs(sessions) do
        if not session.executing then closeSession(session, 'cancelled') end
    end
end)
