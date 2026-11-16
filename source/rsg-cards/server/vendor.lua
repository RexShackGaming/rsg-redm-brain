local RSGCore = exports['rsg-core']:GetCoreObject()
local Inventory = exports['rsg-inventory']

local SHOP_NAME = 'cardcollect'

-- what the vendor can see: card boxes only (Config.Shop.BoxesOnly) or inventory + card boxes
local function scope()
    return Config.Shop.BoxesOnly and 'boxes' or true
end

local function getLocation(src, id)
    return CardsServer.findLocation(src, Config.Shop.Locations, id, Config.Shop.InteractDistance)
end

-- everything the player carries (inventory and card boxes) that the vendor buys, in set order
local function sellableItems(counts)
    local list = {}
    for name, amount in pairs(counts) do
        if amount > 0 then
            local info = Cards.Info[name]
            list[#list + 1] = {
                name = name,
                label = CardsServer.itemLabel(name),
                image = CardsServer.itemImage(name),
                amount = amount,
                price = info.price,
                deck = info.deck == true,
                order = info.order,
            }
        end
    end
    table.sort(list, function(a, b) return a.order < b.order end)
    return list
end

-- sets the player holds every card of (inventory + card boxes)
local function craftableSets(counts)
    local list = {}
    if not Config.Shop.CraftSets then return list end
    for _, set in ipairs(Config.Sets) do
        local times = math.huge
        for number = 1, Config.CardsPerSet do
            times = math.min(times, counts[('card_cigcard_%s_c%d'):format(set.id, number)] or 0)
            if times == 0 then break end
        end
        if times > 0 then
            local deck = ('card_cigcard_%s'):format(set.id)
            list[#list + 1] = {
                id = set.id,
                label = CardsServer.itemLabel(deck),
                image = CardsServer.itemImage(deck),
                times = times,
                cards = Config.CardsPerSet,
            }
        end
    end
    return list
end

-- spare copies: everything beyond the first of each single card (complete sets are never counted)
local function duplicateTotals(counts)
    local count, total = 0, 0
    if not Config.Shop.SellDuplicates then return nil end
    for name, amount in pairs(counts) do
        local info = Cards.Info[name]
        if info and not info.deck and amount > 1 then
            count = count + (amount - 1)
            total = total + info.price * (amount - 1)
        end
    end
    return { count = count, total = CardsServer.round(total) }
end

local function vendorData(src, message, notifyType)
    local counts = CardsServer.countCards(src, scope()) -- read once: inventory and boxes are only scanned one time per update
    return {
        items = sellableItems(counts),
        sets = craftableSets(counts),
        duplicates = duplicateTotals(counts),
        boxesOnly = Config.Shop.BoxesOnly == true,
        message = message,
        type = notifyType,
    }
end

local function pay(Player, total, reason)
    Player.Functions.AddMoney(Config.Shop.Payment, total, reason)
end

RSGCore.Functions.CreateCallback('rsg-cards:server:getVendor', function(source, cb, shopId)
    if not RSGCore.Functions.GetPlayer(source) or not getLocation(source, shopId) then return cb(false) end
    if not CardsServer.throttle(source, 'getVendor', 0.5) then return cb(false) end
    cb(vendorData(source))
end)

RSGCore.Functions.CreateCallback('rsg-cards:server:sell', function(source, cb, shopId, name, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not getLocation(src, shopId) then return cb(false) end
    if not CardsServer.throttle(src, 'sell', 1) then return cb(false) end

    local info = type(name) == 'string' and Cards.Info[name]
    amount = tonumber(amount)
    if not info or not amount or amount < 1 or amount ~= math.floor(amount) then return cb(false) end
    amount = math.floor(amount)

    local owned = CardsServer.countCards(src, scope())[name] or 0
    if amount > owned or not CardsServer.removeCards(src, name, amount, 'rsg-cards:sell', scope()) then
        return cb(vendorData(src, locale('sell_not_enough'), 'error'))
    end

    local total = CardsServer.round(info.price * amount)
    pay(Player, total, 'rsg-cards:sell')
    CardsServer.log(('**Cards sold**\n%s\n%dx %s for $%.2f'):format(CardsServer.playerTag(Player), amount, name, total))

    cb(vendorData(src, locale('sell_success', amount, CardsServer.itemLabel(name), ('%.2f'):format(total)), 'success'))
end)

RSGCore.Functions.CreateCallback('rsg-cards:server:sellAll', function(source, cb, shopId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not getLocation(src, shopId) then return cb(false) end
    if not CardsServer.throttle(src, 'sell', 1) then return cb(false) end

    -- the boxes are saved once at the end, not once per card
    local total, sold, touched = 0, 0, {}
    for name, amount in pairs(CardsServer.countCards(src, scope())) do
        if amount > 0 and CardsServer.removeCards(src, name, amount, 'rsg-cards:sell-all', scope(), touched) then
            total = total + Cards.Info[name].price * amount
            sold = sold + amount
        end
    end
    CardsServer.saveStashes(touched)

    if sold == 0 then
        return cb(vendorData(src, locale('sell_nothing'), 'error'))
    end

    total = CardsServer.round(total)
    pay(Player, total, 'rsg-cards:sell-all')
    CardsServer.log(('**Cards sold (all)**\n%s\n%d items for $%.2f'):format(CardsServer.playerTag(Player), sold, total))

    cb(vendorData(src, locale('sell_all_success', sold, ('%.2f'):format(total)), 'success'))
end)

-- sells every spare copy and keeps one of each single card
RSGCore.Functions.CreateCallback('rsg-cards:server:sellDuplicates', function(source, cb, shopId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Config.Shop.SellDuplicates or not getLocation(src, shopId) then return cb(false) end
    if not CardsServer.throttle(src, 'sell', 1) then return cb(false) end

    local total, sold, touched = 0, 0, {}
    for name, amount in pairs(CardsServer.countCards(src, scope())) do
        local info = Cards.Info[name]
        if info and not info.deck and amount > 1 then
            local extra = amount - 1
            if CardsServer.removeCards(src, name, extra, 'rsg-cards:sell-duplicates', scope(), touched) then
                total = total + info.price * extra
                sold = sold + extra
            end
        end
    end
    CardsServer.saveStashes(touched)

    if sold == 0 then
        return cb(vendorData(src, locale('sell_duplicates_none'), 'error'))
    end

    total = CardsServer.round(total)
    pay(Player, total, 'rsg-cards:sell-duplicates')
    CardsServer.log(('**Duplicates sold**\n%s\n%d cards for $%.2f'):format(CardsServer.playerTag(Player), sold, total))

    cb(vendorData(src, locale('sell_duplicates_success', sold, ('%.2f'):format(total)), 'success'))
end)

---------------------------------------------------------------------
-- MAKE A SET (all 12 cards of a set -> the complete set)
---------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-cards:server:makeSet', function(source, cb, shopId, setId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Config.Shop.CraftSets or not getLocation(src, shopId) then return cb(false) end
    if not CardsServer.throttle(src, 'makeSet', 1) then return cb(false) end

    local deck = type(setId) == 'string' and ('card_cigcard_%s'):format(setId)
    local info = deck and Cards.Info[deck]
    if not info or not info.deck then return cb(false) end

    local cards, counts = {}, CardsServer.countCards(src, scope())
    for number = 1, Config.CardsPerSet do
        cards[number] = ('card_cigcard_%s_c%d'):format(setId, number)
        if (counts[cards[number]] or 0) < 1 then
            return cb(vendorData(src, locale('set_missing'), 'error'))
        end
    end

    if not Inventory:CanAddItem(src, deck, 1) then
        return cb(vendorData(src, locale('inventory_full'), 'error'))
    end

    local removed, touched = {}, {}
    local function refund()
        for _, taken in ipairs(removed) do
            Inventory:AddItem(src, taken, 1, nil, nil, 'rsg-cards:make-set-refund')
        end
        CardsServer.saveStashes(touched)
    end

    for _, name in ipairs(cards) do
        if CardsServer.removeCards(src, name, 1, 'rsg-cards:make-set', scope(), touched) then
            removed[#removed + 1] = name
        else
            -- something changed mid-way: hand back what was already taken
            refund()
            return cb(vendorData(src, locale('set_missing'), 'error'))
        end
    end

    if not Inventory:AddItem(src, deck, 1, nil, nil, 'rsg-cards:make-set') then
        refund() -- the set could not be given: the 12 cards must not be lost
        return cb(vendorData(src, locale('inventory_full'), 'error'))
    end
    CardsServer.saveStashes(touched)
    CardsServer.log(('**Set made**\n%s\n%s'):format(CardsServer.playerTag(Player), deck))
    cb(vendorData(src, locale('set_made', CardsServer.itemLabel(deck)), 'success'))
end)

---------------------------------------------------------------------
-- BUY (rsg-inventory shop)
---------------------------------------------------------------------
CreateThread(function()
    Inventory:CreateShop({
        name = SHOP_NAME,
        label = locale('vendor_title'),
        slots = #Config.Shop.Items,
        items = Config.Shop.Items,
        persistentStock = Config.Shop.PersistStock,
    })
end)

RegisterNetEvent('rsg-cards:server:openShop', function(shopId)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) or not getLocation(src, shopId) then return end
    Inventory:OpenShop(src, SHOP_NAME)
end)
