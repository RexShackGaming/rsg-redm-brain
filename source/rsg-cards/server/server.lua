local RSGCore = exports['rsg-core']:GetCoreObject()
local Inventory = exports['rsg-inventory']

-- Helpers shared with the other server files
CardsServer = {}

local dbReady = false
local throttles = {}    -- [src] = { [key] = GetGameTimer() }
local pendingPacks = {} -- [src] = { cards = { itemName, ... }, revealed = { [index] = true }, left = number }
local pickups = {}      -- [citizenid] = { [itemName] = os.time() of the last pickup }
local pickupOwner = {} -- [src] = citizenid whose pickups are cached (the player may already be gone when they drop)

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
function CardsServer.notify(src, description, notifyType)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('title'),
        description = description,
        type = notifyType or 'inform',
        duration = 5000,
    })
end

function CardsServer.log(message)
    TriggerEvent('rsg-log:server:CreateLog', Config.Webhook.Name, Config.Webhook.Title, Config.Webhook.Colour, message, false)
end

function CardsServer.playerTag(Player)
    local data = Player.PlayerData
    return ('%s %s (%s)'):format(data.charinfo.firstname, data.charinfo.lastname, data.citizenid)
end

function CardsServer.isNear(src, coords, radius)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - vector3(coords.x, coords.y, coords.z)) <= radius
end

-- returns true when the action is allowed (at most once every `seconds` per player)
function CardsServer.throttle(src, key, seconds)
    local now = GetGameTimer()
    throttles[src] = throttles[src] or {}
    local last = throttles[src][key]
    if last and now - last < seconds * 1000 then return false end
    throttles[src][key] = now
    return true
end

function CardsServer.itemLabel(name)
    local item = RSGCore.Shared.Items[name]
    return item and item.label or name
end

function CardsServer.itemImage(name)
    local item = RSGCore.Shared.Items[name]
    return item and item.image or (name .. '.png')
end

function CardsServer.round(value)
    return math.floor(value * 100 + 0.5) / 100
end

-- stash ids ('box_<serial>') of every card storage box the player carries
function CardsServer.getBoxIds(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    local ids, seen = {}, {}
    if not Player then return ids end
    for _, item in pairs(Player.PlayerData.items or {}) do
        if item and item.name == Config.Items.Box and type(item.info) == 'table' then
            local serial = item.info.serie
            if type(serial) == 'string' and serial:match('^%w+$') and not seen[serial] then
                seen[serial] = true
                ids[#ids + 1] = 'box_' .. serial
            end
        end
    end
    return ids
end

-- items of a box stash, or nil when rsg-inventory can't give them
local function getStashItems(stashId)
    local ok, stash = pcall(function() return Inventory:GetInventory(stashId) end)
    if ok and type(stash) == 'table' and type(stash.items) == 'table' then return stash.items end
    return nil
end

-- { [itemName] = amount } of every card / set the player carries.
-- scope: nil/false = inventory only, true = inventory + card boxes, 'boxes' = card boxes only
function CardsServer.countCards(src, scope)
    local Player = RSGCore.Functions.GetPlayer(src)
    local counts = {}
    if not Player then return counts end
    if scope ~= 'boxes' then
        for _, item in pairs(Player.PlayerData.items or {}) do
            if item and Cards.Info[item.name] then
                counts[item.name] = (counts[item.name] or 0) + (tonumber(item.amount) or 0)
            end
        end
    end
    if scope then
        for _, stashId in ipairs(CardsServer.getBoxIds(src)) do
            for _, item in pairs(getStashItems(stashId) or {}) do
                if type(item) == 'table' and Cards.Info[item.name] then
                    counts[item.name] = (counts[item.name] or 0) + (tonumber(item.amount) or 0)
                end
            end
        end
    end
    return counts
end

-- Removes `amount` of a card / set, taking from the inventory first and then from the player's
-- card boxes (scope 'boxes' = card boxes only). All or nothing: if anything fails, what was
-- already taken is handed back.
function CardsServer.removeCards(src, name, amount, reason, scope)
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or not Cards.Info[name] then return false end

    local inInventory = scope == 'boxes' and 0 or (CardsServer.countCards(src)[name] or 0)
    local left, taken, touched = amount, {}, {}

    local fromInventory = math.min(inInventory, left)
    if fromInventory > 0 then
        if not Inventory:RemoveItem(src, name, fromInventory, nil, reason) then return false end
        taken[#taken + 1] = { target = src, amount = fromInventory }
        left = left - fromInventory
    end

    if left > 0 then
        for _, stashId in ipairs(CardsServer.getBoxIds(src)) do
            if left < 1 then break end
            local have = 0
            for _, item in pairs(getStashItems(stashId) or {}) do
                if type(item) == 'table' and item.name == name then have = have + (tonumber(item.amount) or 0) end
            end
            local count = math.min(have, left)
            if count > 0 then
                if not Inventory:RemoveItem(stashId, name, count, nil, reason) then break end
                taken[#taken + 1] = { target = stashId, amount = count }
                touched[stashId] = true
                left = left - count
            end
        end
    end

    if left > 0 then
        for _, entry in ipairs(taken) do
            Inventory:AddItem(entry.target, name, entry.amount, nil, nil, (reason or 'rsg-cards') .. '-refund')
        end
        return false
    end

    for stashId in pairs(touched) do Inventory:SaveStash(stashId) end
    return true
end

local function debugPrint(...)
    if Config.Debug then print('[rsg-cards]', ...) end
end

---------------------------------------------------------------------
-- DATABASE
---------------------------------------------------------------------
local function tableExists(name)
    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name })
    return (tonumber(count) or 0) > 0
end

-- Keep these statements identical to install.sql
local function ensureDatabase()
    local ok, err = pcall(function()
        -- boxes created before the resource was renamed to rsg-cards
        if tableExists('hdrp_boxes') and not tableExists('rsg_cards_boxes') then
            MySQL.query.await('RENAME TABLE `hdrp_boxes` TO `rsg_cards_boxes`')
        end

        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `rsg_cards_boxes` (
                `serial`  VARCHAR(20) NOT NULL,
                `creator` VARCHAR(50) NOT NULL,
                `owner`   VARCHAR(50) NOT NULL,
                PRIMARY KEY (`serial`),
                INDEX `idx_creator` (`creator`),
                INDEX `idx_owner` (`owner`)
            )
        ]])

        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `rsg_cards_collection` (
                `citizenid`   VARCHAR(50) NOT NULL,
                `card`        VARCHAR(50) NOT NULL,
                `obtained_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`citizenid`, `card`)
            )
        ]])

        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `rsg_cards_pickups` (
                `citizenid` VARCHAR(50) NOT NULL,
                `card`      VARCHAR(50) NOT NULL,
                `picked_at` INT UNSIGNED NOT NULL,
                PRIMARY KEY (`citizenid`, `card`)
            )
        ]])
    end)

    if not ok then
        print(('^1[rsg-cards] database setup failed: %s^7'):format(err))
        return false
    end
    print('^2[rsg-cards] database tables ready^7')
    return true
end

local function checkItems()
    local missing = {}
    local names = { Config.Items.Pack, Config.Items.Box }
    for name in pairs(Cards.Info) do names[#names + 1] = name end
    for _, name in ipairs(names) do
        if not RSGCore.Shared.Items[name] then missing[#missing + 1] = name end
    end
    if #missing > 0 then
        table.sort(missing)
        print(('^1[rsg-cards] %d item(s) missing from rsg-core shared items (see installation/shared_items.lua): %s%s^7')
            :format(#missing, table.concat(missing, ', ', 1, math.min(#missing, 5)), #missing > 5 and ', ...' or ''))
    end
end

CreateThread(function()
    math.randomseed(os.time())
    checkItems()
    if Config.AutoDatabase and not ensureDatabase() then return end
    dbReady = true
end)

---------------------------------------------------------------------
-- COLLECTION (which cards a character has ever found)
---------------------------------------------------------------------
-- returns isNew, collected
local function recordCard(Player, card)
    if not dbReady then return false, nil end
    local citizenid = Player.PlayerData.citizenid
    local ok, isNew, collected = pcall(function()
        local added = MySQL.update.await(
            'INSERT IGNORE INTO `rsg_cards_collection` (`citizenid`, `card`) VALUES (?, ?)', { citizenid, card })
        if (tonumber(added) or 0) < 1 then return false, nil end
        local count = MySQL.scalar.await(
            'SELECT COUNT(*) FROM `rsg_cards_collection` WHERE `citizenid` = ?', { citizenid })
        return true, tonumber(count) or 0
    end)
    if not ok then
        debugPrint('collection update failed:', isNew)
        return false, nil
    end
    return isNew, collected
end

-- Gives one card (or complete set) and returns the data the UI needs to show it, or false.
local function grantCard(src, card, reason)
    local Player = RSGCore.Functions.GetPlayer(src)
    local info = Cards.Info[card]
    if not Player or not info then return false end

    local added = Inventory:CanAddItem(src, card, 1) and Inventory:AddItem(src, card, 1, nil, nil, reason)
    if not added then
        -- no room: drop it at the player's feet rather than losing it
        local ok, result = pcall(function() return Inventory:ForceDropItem(src, card, 1, nil, reason) end)
        local dropped = ok and result ~= false
        CardsServer.notify(src, locale(dropped and 'inventory_full_dropped' or 'inventory_full'), 'error')
        if not dropped then return false end
    end

    local isNew, collected = false, nil
    if not info.deck then
        isNew, collected = recordCard(Player, card)
        if isNew and collected and collected >= Cards.Total then
            CardsServer.notify(src, locale('collection_complete'), 'success')
            CardsServer.log(('**Collection complete**\n%s has found all %d cards'):format(CardsServer.playerTag(Player), Cards.Total))
        end
    end

    return {
        item = card,
        label = CardsServer.itemLabel(card),
        image = CardsServer.itemImage(card),
        tier = info.tier,
        deck = info.deck == true,
        isNew = isNew,
        collected = collected,
        total = Cards.Total,
    }
end

---------------------------------------------------------------------
-- CARD PACKS
---------------------------------------------------------------------
local totalWeight = 0
for _, chance in ipairs(Config.Pack.Chances) do
    totalWeight = totalWeight + math.max(0, math.floor(chance.weight))
end

local function rollCard()
    if totalWeight > 0 then
        local roll = math.random(totalWeight)
        for _, chance in ipairs(Config.Pack.Chances) do
            roll = roll - math.max(0, math.floor(chance.weight))
            if roll <= 0 then
                local pool = chance.tier == 'deck' and Cards.Decks or Cards.ByTier[chance.tier]
                if pool and #pool > 0 then return pool[math.random(#pool)] end
                break
            end
        end
    end
    return Cards.List[math.random(#Cards.List)]
end

-- Gives every card the player has not turned over yet (UI closed early, disconnect, restart)
local function finishPack(src)
    local pack = pendingPacks[src]
    if not pack then return end
    pendingPacks[src] = nil
    for index, card in ipairs(pack.cards) do
        if not pack.revealed[index] then
            grantCard(src, card, 'rsg-cards:pack')
        end
    end
end

RSGCore.Functions.CreateUseableItem(Config.Items.Pack, function(source, item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if not CardsServer.throttle(src, 'pack', 2) then return end

    finishPack(src) -- a previous pack that was never closed

    if not Inventory:RemoveItem(src, Config.Items.Pack, 1, item and item.slot, 'rsg-cards:open-pack') then
        return CardsServer.notify(src, locale('no_pack'), 'error')
    end

    local cards = {}
    for i = 1, Config.Pack.Cards do cards[i] = rollCard() end
    pendingPacks[src] = { cards = cards, revealed = {}, left = #cards }

    debugPrint(('%s opened a pack: %s'):format(Player.PlayerData.citizenid, table.concat(cards, ', ')))
    CardsServer.log(('**Pack opened**\n%s\n%s'):format(CardsServer.playerTag(Player), table.concat(cards, ', ')))
    TriggerClientEvent('rsg-cards:client:openPack', src, #cards)
end)

-- The player turned over card `index` of the open pack
RSGCore.Functions.CreateCallback('rsg-cards:server:flipCard', function(source, cb, index)
    local pack = pendingPacks[source]
    index = tonumber(index)
    if not pack or not index or not pack.cards[index] or pack.revealed[index] then return cb(false) end

    pack.revealed[index] = true
    pack.left = pack.left - 1
    local card = pack.cards[index]
    if pack.left <= 0 then pendingPacks[source] = nil end

    cb(grantCard(source, card, 'rsg-cards:pack'))
end)

RegisterNetEvent('rsg-cards:server:closePack', function()
    finishPack(source)
end)

---------------------------------------------------------------------
-- CARDS IN THE WORLD
---------------------------------------------------------------------
local function loadPickups(citizenid)
    if pickups[citizenid] then return pickups[citizenid] end
    local list = {}
    if dbReady then
        local ok, rows = pcall(MySQL.query.await,
            'SELECT `card`, `picked_at` FROM `rsg_cards_pickups` WHERE `citizenid` = ?', { citizenid })
        if ok and rows then
            for _, row in ipairs(rows) do list[row.card] = tonumber(row.picked_at) end
        end
    end
    pickups[citizenid] = list
    return list
end

-- { [itemName] = seconds left } for every card the player still has on cooldown
RSGCore.Functions.CreateCallback('rsg-cards:server:getPickups', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end

    local citizenid = Player.PlayerData.citizenid
    pickupOwner[source] = citizenid
    local now, cooldown, remaining = os.time(), Config.Card.Cooldown * 60, {}
    for card, pickedAt in pairs(loadPickups(citizenid)) do
        local left = cooldown - (now - pickedAt)
        if left > 0 then remaining[card] = left end
    end
    cb(remaining)
end)

RSGCore.Functions.CreateCallback('rsg-cards:server:pickupCard', function(source, cb, index)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local point = Config.CardPoints[tonumber(index) or 0]
    if not Player or not point or not Cards.Info[point.item] then return cb(false) end
    if not CardsServer.throttle(src, 'pickup', 2) then return cb(false) end
    if not CardsServer.isNear(src, point.coords, Config.Card.PickupDistance + 3.0) then return cb(false) end

    local citizenid = Player.PlayerData.citizenid
    pickupOwner[src] = citizenid
    local list = loadPickups(citizenid)
    local now, cooldown = os.time(), Config.Card.Cooldown * 60
    local left = list[point.item] and (cooldown - (now - list[point.item])) or 0
    if left > 0 then
        CardsServer.notify(src, locale('pickup_cooldown', math.ceil(left / 60)), 'error')
        return cb({ cooldown = left })
    end

    if not Inventory:CanAddItem(src, point.item, 1) then
        CardsServer.notify(src, locale('inventory_full'), 'error')
        return cb(false)
    end

    -- set the cooldown before giving the card so a second request can't slip through
    list[point.item] = now
    local result = grantCard(src, point.item, 'rsg-cards:pickup')
    if not result then
        list[point.item] = nil
        return cb(false)
    end

    if dbReady then
        MySQL.query(
            'INSERT INTO `rsg_cards_pickups` (`citizenid`, `card`, `picked_at`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `picked_at` = VALUES(`picked_at`)',
            { citizenid, point.item, now })
    end

    result.cooldown = cooldown
    cb(result)
end)

---------------------------------------------------------------------
-- INSPECT A CARD (use it from the inventory)
---------------------------------------------------------------------
for _, card in ipairs(Cards.List) do
    RSGCore.Functions.CreateUseableItem(card, function(source)
        if not RSGCore.Functions.GetPlayer(source) then return end
        TriggerClientEvent('rsg-cards:client:inspectCard', source, card)
    end)
end

---------------------------------------------------------------------
-- CARD STORAGE BOX
---------------------------------------------------------------------
local function generateSerial()
    return (RSGCore.Shared.RandomInt(4) .. RSGCore.Shared.RandomStr(3) .. RSGCore.Shared.RandomInt(3) .. RSGCore.Shared.RandomStr(3)):upper()
end

local function createUniqueSerial()
    for _ = 1, 10 do
        local serial = generateSerial()
        local exists = MySQL.scalar.await('SELECT 1 FROM `rsg_cards_boxes` WHERE `serial` = ? LIMIT 1', { serial })
        if not exists then return serial end
    end
end

local openBoxes = {} -- [src] = serial of the box the player has open beside their inventory

local allowedCategories = {}
for _, category in ipairs(Config.Storage.AllowedCategories or {}) do allowedCategories[category] = true end

local function canStore(name)
    if Cards.Info[name] or name == Config.Items.Pack then return true end
    local item = RSGCore.Shared.Items[name]
    return item ~= nil and item.category ~= nil and allowedCategories[item.category] == true
end

-- Hands anything that isn't a card, set or pack back to the player (or drops it at their feet).
local function sweepBox(src, serial)
    local stashId = 'box_' .. serial
    local ok, stash = pcall(function() return Inventory:GetInventory(stashId) end)
    if not ok or type(stash) ~= 'table' or type(stash.items) ~= 'table' then return end

    local rejected = {}
    for _, item in pairs(stash.items) do
        if type(item) == 'table' and item.name and not canStore(item.name) then rejected[#rejected + 1] = item end
    end
    if #rejected == 0 then return end

    for _, item in ipairs(rejected) do
        local amount = tonumber(item.amount) or 1
        if Inventory:RemoveItem(stashId, item.name, amount, item.slot, 'rsg-cards:box-reject') then
            local returned = RSGCore.Functions.GetPlayer(src) ~= nil
                and Inventory:CanAddItem(src, item.name, amount)
                and Inventory:AddItem(src, item.name, amount, item.info, nil, 'rsg-cards:box-reject')
            if not returned and not Inventory:ForceDropItem(src, item.name, amount, item.info, 'rsg-cards:box-reject') then
                -- could not return or drop it: put it back rather than lose it
                Inventory:AddItem(stashId, item.name, amount, item.info, nil, 'rsg-cards:box-reject')
            end
        end
    end
    Inventory:SaveStash(stashId)
    CardsServer.notify(src, locale('box_cards_only'), 'error')
end

local function closeBox(src)
    local serial = openBoxes[src]
    if not serial then return end
    openBoxes[src] = nil
    sweepBox(src, serial)
end

local BUNDLE_ACTION = 'bundle_sets' -- id of the button rsg-inventory shows at the top of the box

local function openBox(src, serial)
    if not RSGCore.Functions.GetPlayer(src) then return end
    sweepBox(src, serial) -- clears out anything stored before the card-only rule
    local opened = Inventory:OpenInventory(src, 'box_' .. serial, {
        label = locale('box_label', serial),
        maxweight = Config.Storage.MaxWeight,
        slots = Config.Storage.MaxSlots,
        -- false removes the button from a box that was opened before the option was turned off
        actions = Config.Storage.BundleSets and { { id = BUNDLE_ACTION, label = locale('bundle_sets') } } or false,
    })
    if opened then
        openBoxes[src] = serial
        TriggerClientEvent('rsg-cards:client:boxOpened', src)
    end
end

RSGCore.Functions.CreateUseableItem(Config.Items.Box, function(source, item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not item or not item.slot then return end
    if not CardsServer.throttle(src, 'box', 1) then return end
    if not dbReady then return CardsServer.notify(src, locale('box_error'), 'error') end

    -- rsg-inventory closes the inventory right after a `shouldClose` item is used,
    -- so anything we open has to wait until that has happened
    local shared = RSGCore.Shared.Items[Config.Items.Box]
    local delay = shared and shared.shouldClose and (Config.Storage.OpenDelay or 300) or 0

    local citizenid = Player.PlayerData.citizenid
    local info = type(item.info) == 'table' and item.info or {}
    local serial = info.serie

    -- using the box that is already open closes just the box and leaves the inventory open
    if openBoxes[src] and openBoxes[src] == serial then
        closeBox(src)
        return SetTimeout(delay, function()
            if RSGCore.Functions.GetPlayer(src) then Inventory:OpenInventory(src) end
        end)
    end
    closeBox(src) -- a different box was open

    if type(serial) ~= 'string' or not serial:match('^%w+$') then
        -- first use: give the box its own serial number (this is what its contents are stored under)
        local ok, newSerial = pcall(function()
            local generated = createUniqueSerial()
            if not generated then return nil end
            MySQL.insert.await('INSERT INTO `rsg_cards_boxes` (`serial`, `creator`, `owner`) VALUES (?, ?, ?)',
                { generated, citizenid, citizenid })
            return generated
        end)
        if not ok or not newSerial then return CardsServer.notify(src, locale('box_error'), 'error') end

        serial = newSerial
        info.serie = serial
        Inventory:SetItemInfo(src, item.slot, info)
        CardsServer.notify(src, locale('box_registered', serial), 'success')
        CardsServer.log(('**Box created**\n%s\nSerial: %s'):format(CardsServer.playerTag(Player), serial))
    else
        MySQL.update('UPDATE `rsg_cards_boxes` SET `owner` = ? WHERE `serial` = ?', { citizenid, serial })
    end

    SetTimeout(delay, function() openBox(src, serial) end)
end)

-- Turns every complete run of cards inside the box into the complete-set item (kept in the box).
local function bundleSets(src, serial)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local stashId = 'box_' .. serial
    local ok, stash = pcall(function() return Inventory:GetInventory(stashId) end)
    if not ok or type(stash) ~= 'table' or type(stash.items) ~= 'table' then return end

    local counts = {}
    for _, item in pairs(stash.items) do
        local info = type(item) == 'table' and item.name and Cards.Info[item.name]
        if info and not info.deck then
            counts[item.name] = (counts[item.name] or 0) + (tonumber(item.amount) or 0)
        end
    end

    local total, made = 0, {}
    for _, set in ipairs(Config.Sets) do
        -- how many complete sets these cards make = the lowest count of any one card
        local cards, times = {}, nil
        for number = 1, Config.CardsPerSet do
            cards[number] = ('card_cigcard_%s_c%d'):format(set.id, number)
            local have = counts[cards[number]] or 0
            times = times and math.min(times, have) or have
        end

        local deck = ('card_cigcard_%s'):format(set.id)
        if times and times > 0 and Cards.Info[deck] then
            local removed, complete = {}, true
            for _, name in ipairs(cards) do
                if Inventory:RemoveItem(stashId, name, times, nil, 'rsg-cards:bundle-set') then
                    removed[#removed + 1] = name
                else
                    complete = false
                    break
                end
            end

            -- the set goes into the box; if that somehow fails, to the player, then to their feet
            local stored = complete and (
                Inventory:AddItem(stashId, deck, times, nil, nil, 'rsg-cards:bundle-set')
                or (Inventory:CanAddItem(src, deck, times) and Inventory:AddItem(src, deck, times, nil, nil, 'rsg-cards:bundle-set'))
                or Inventory:ForceDropItem(src, deck, times, nil, 'rsg-cards:bundle-set'))

            if stored then
                total = total + times
                made[#made + 1] = ('%dx %s'):format(times, deck)
            else
                -- nothing was made: put back the cards that were already taken
                for _, name in ipairs(removed) do
                    Inventory:AddItem(stashId, name, times, nil, nil, 'rsg-cards:bundle-refund')
                end
            end
        end
    end

    if total < 1 then
        return CardsServer.notify(src, locale('bundle_none', Config.CardsPerSet), 'error')
    end
    Inventory:SaveStash(stashId)
    CardsServer.notify(src, locale('bundle_done', total), 'success')
    CardsServer.log(('**Sets bundled**\n%s\nBox: %s\n%s'):format(CardsServer.playerTag(Player), serial, table.concat(made, ', ')))
end

-- "Bundle Sets" button on the box (local event from rsg-inventory, which only sends it for a
-- button registered on the stash the player has open)
AddEventHandler('rsg-inventory:stashAction', function(src, stashId, actionId)
    if actionId ~= BUNDLE_ACTION or not Config.Storage.BundleSets then return end
    src = tonumber(src)
    local serial = src and openBoxes[src]
    if not serial or stashId ~= 'box_' .. serial then return end
    if not CardsServer.throttle(src, 'bundle', 2) then return end
    bundleSets(src, serial)
end)

-- rsg-inventory has no item filter for stashes, so check the box after every move into it
-- (a swap out of the box also puts the player's item in, so both directions count)
RegisterNetEvent('rsg-inventory:server:move', function(data)
    local src = source
    local serial = openBoxes[src]
    if not serial or type(data) ~= 'table' then return end
    local stashId = 'box_' .. serial
    if data.to ~= stashId and data.from ~= stashId then return end
    SetTimeout(150, function()
        if openBoxes[src] == serial then sweepBox(src, serial) end
    end)
end)

-- sent by the client when the inventory has been closed
RegisterNetEvent('rsg-cards:server:boxClosed', function()
    closeBox(source)
end)

---------------------------------------------------------------------
-- CLEANUP
---------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    closeBox(src)
    if pickupOwner[src] then pickups[pickupOwner[src]] = nil end
    pickupOwner[src] = nil
    if Player then
        finishPack(src)
    elseif pendingPacks[src] then
        print(('^3[rsg-cards] player %s left with unopened pack cards: %s^7'):format(src, table.concat(pendingPacks[src].cards, ', ')))
        pendingPacks[src] = nil
    end
    throttles[src] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for src in pairs(pendingPacks) do finishPack(src) end
    for src in pairs(openBoxes) do closeBox(src) end
end)
