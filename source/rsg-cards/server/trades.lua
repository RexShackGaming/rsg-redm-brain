local RSGCore = exports['rsg-core']:GetCoreObject()
local Inventory = exports['rsg-inventory']

local offers = {}   -- [locationId] = { { id, set, reward, amount, cards = { itemName, ... } }, ... }
local lastSets = {} -- [locationId] = { [setId] = true } sets offered in the previous rotation
local traded = {}    -- [citizenid] = { [locationId|offerId] = true } offers a player already completed this rotation
local rotation = 0
local nextRefresh = 0

local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

local function rotateOffers()
    rotation = rotation + 1
    traded = {}
    nextRefresh = os.time() + Config.Trades.Refresh * 60

    local minCards = math.max(1, math.min(Config.Trades.MinCards, Config.CardsPerSet))
    local maxCards = math.max(minCards, math.min(Config.Trades.MaxCards, Config.CardsPerSet))

    for _, location in ipairs(Config.Trades.Locations) do
        -- prefer sets this collector did not ask for last time
        local previous, pool = lastSets[location.id] or {}, {}
        for _, set in ipairs(Config.Sets) do
            if not previous[set.id] then pool[#pool + 1] = set.id end
        end
        if #pool < Config.Trades.MaxActive then
            pool = {}
            for _, set in ipairs(Config.Sets) do pool[#pool + 1] = set.id end
        end
        shuffle(pool)

        local list, used = {}, {}
        for i = 1, math.min(Config.Trades.MaxActive, #pool) do
            local setId = pool[i]
            local numbers = {}
            for n = 1, Config.CardsPerSet do numbers[n] = n end
            shuffle(numbers)

            local cards = {}
            for n = 1, math.random(minCards, maxCards) do
                cards[n] = ('card_cigcard_%s_c%d'):format(setId, numbers[n])
            end
            table.sort(cards, function(a, b) return Cards.Info[a].order < Cards.Info[b].order end)

            list[i] = {
                id = ('%d:%d'):format(rotation, i),
                set = setId,
                reward = ('card_cigcard_%s'):format(setId),
                amount = Config.Trades.RewardAmount,
                cards = cards,
            }
            used[setId] = true
        end

        offers[location.id] = list
        lastSets[location.id] = used
    end

    if Config.Debug then print('[rsg-cards] collector offers refreshed') end
end

CreateThread(function()
    Wait(1000) -- let server.lua seed the random generator first
    while true do
        if os.time() >= nextRefresh then rotateOffers() end
        Wait(30000)
    end
end)

local function getLocation(src, id)
    for _, location in ipairs(Config.Trades.Locations) do
        if location.id == id then
            return CardsServer.isNear(src, location.coords, Config.Trades.InteractDistance) and location or nil
        end
    end
end

local function tradeKey(locationId, offerId)
    return locationId .. '|' .. offerId
end

local function hasTraded(citizenid, locationId, offerId)
    return Config.Trades.OncePerPlayer and traded[citizenid] ~= nil and traded[citizenid][tradeKey(locationId, offerId)] == true
end

-- offers of one collector, with how many of each card the player carries
local function buildOffers(src, locationId)
    local counts = CardsServer.countCards(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    local citizenid = Player and Player.PlayerData.citizenid
    local list = {}
    for _, offer in ipairs(offers[locationId] or {}) do
        local cards, have = {}, 0
        for i, name in ipairs(offer.cards) do
            local owned = (counts[name] or 0) > 0
            if owned then have = have + 1 end
            cards[i] = {
                name = name,
                label = CardsServer.itemLabel(name),
                image = CardsServer.itemImage(name),
                owned = owned,
            }
        end
        list[#list + 1] = {
            id = offer.id,
            label = CardsServer.itemLabel(offer.reward),
            image = CardsServer.itemImage(offer.reward),
            amount = offer.amount,
            cards = cards,
            have = have,
            need = #cards,
            done = citizenid ~= nil and hasTraded(citizenid, locationId, offer.id),
        }
    end
    return { offers = list, refresh = math.max(0, nextRefresh - os.time()) }
end

RSGCore.Functions.CreateCallback('rsg-cards:server:getTrades', function(source, cb, locationId)
    if not RSGCore.Functions.GetPlayer(source) or not getLocation(source, locationId) then return cb(false) end
    if not CardsServer.throttle(source, 'getTrades', 0.5) then return cb(false) end
    cb(buildOffers(source, locationId))
end)

RSGCore.Functions.CreateCallback('rsg-cards:server:trade', function(source, cb, locationId, offerId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not getLocation(src, locationId) then return cb(false) end
    if not CardsServer.throttle(src, 'trade', 1) then return cb(false) end

    local offer
    for _, candidate in ipairs(offers[locationId] or {}) do
        if candidate.id == offerId then offer = candidate break end
    end

    local function reply(message, notifyType)
        local data = buildOffers(src, locationId)
        data.message, data.type = message, notifyType
        cb(data)
    end

    if not offer then return reply(locale('trade_expired'), 'error') end

    local citizenid = Player.PlayerData.citizenid
    if hasTraded(citizenid, locationId, offer.id) then return reply(locale('trade_done'), 'error') end

    local counts = CardsServer.countCards(src)
    for _, name in ipairs(offer.cards) do
        if (counts[name] or 0) < 1 then return reply(locale('trade_missing'), 'error') end
    end

    if not Inventory:CanAddItem(src, offer.reward, offer.amount) then
        return reply(locale('inventory_full'), 'error')
    end

    local removed = {}
    for _, name in ipairs(offer.cards) do
        if Inventory:RemoveItem(src, name, 1, nil, 'rsg-cards:trade') then
            removed[#removed + 1] = name
        else
            -- something changed mid-trade: hand back what was already taken
            for _, taken in ipairs(removed) do
                Inventory:AddItem(src, taken, 1, nil, nil, 'rsg-cards:trade-refund')
            end
            return reply(locale('trade_missing'), 'error')
        end
    end

    if not Inventory:AddItem(src, offer.reward, offer.amount, nil, nil, 'rsg-cards:trade') then
        -- could not hand over the reward: give the cards back
        for _, name in ipairs(removed) do
            Inventory:AddItem(src, name, 1, nil, nil, 'rsg-cards:trade-refund')
        end
        return reply(locale('inventory_full'), 'error')
    end

    if Config.Trades.OncePerPlayer then
        traded[citizenid] = traded[citizenid] or {}
        traded[citizenid][tradeKey(locationId, offer.id)] = true
    end
    CardsServer.log(('**Cards traded**\n%s\n%d cards for %dx %s'):format(
        CardsServer.playerTag(Player), #offer.cards, offer.amount, offer.reward))

    reply(locale('trade_success', offer.amount, CardsServer.itemLabel(offer.reward)), 'success')
end)

RSGCore.Commands.Add('refreshcardtrades', locale('command_refresh'), {}, false, function(source)
    rotateOffers()
    if source and source > 0 then
        CardsServer.notify(source, locale('trades_refreshed'), 'success')
    end
end, 'admin')
