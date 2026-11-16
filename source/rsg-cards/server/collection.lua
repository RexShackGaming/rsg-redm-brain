local RSGCore = exports['rsg-core']:GetCoreObject()
local Inventory = exports['rsg-inventory']

---------------------------------------------------------------------
-- SET LOOKUPS
---------------------------------------------------------------------
local setById = {}     -- [setId] = Config.Sets entry
local setCards = {}    -- [setId] = { cardItemName, ... } in card order
for _, set in ipairs(Config.Sets) do
    setById[set.id] = set
    local names = {}
    for number = 1, Config.CardsPerSet do
        names[number] = ('card_cigcard_%s_c%d'):format(set.id, number)
    end
    setCards[set.id] = names
end

local boardCache = { at = 0, board = nil, first = nil } -- leaderboard and first collectors, kept for Config.Collection.CacheSeconds

---------------------------------------------------------------------
-- PROFILE (the name shown on the leaderboard)
---------------------------------------------------------------------
function CardsServer.saveProfile(Player)
    if not CardsServer.dbReady() then return end
    local data = Player.PlayerData
    local charinfo = data.charinfo or {}
    local name = ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''):sub(1, 100)
    MySQL.update(
        'INSERT INTO `rsg_cards_profiles` (`citizenid`, `name`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `name` = VALUES(`name`)',
        { data.citizenid, name })
end

local function displayName(name)
    return (name and name ~= '') and name or locale('unknown_collector')
end

---------------------------------------------------------------------
-- SET COMPLETION (bonus, first collector)
---------------------------------------------------------------------
-- pays the bonus and returns the text describing it ('' when there is none)
local function giveBonus(Player, set)
    local bonus = Config.SetBonus
    if not bonus or not bonus.Enabled then return '' end

    local src = Player.PlayerData.source
    local parts = {}

    local money = CardsServer.round((set.deckPrice or 0) * (tonumber(bonus.Multiplier) or 0))
    if money > 0 then
        Player.Functions.AddMoney(bonus.Payment or 'cash', money, 'rsg-cards:set-bonus')
        parts[#parts + 1] = ('$%.2f'):format(money)
    end

    for _, reward in ipairs(bonus.Items or {}) do
        local amount = math.floor(tonumber(reward.amount) or 0)
        if amount > 0 and RSGCore.Shared.Items[reward.name] then
            local given = Inventory:CanAddItem(src, reward.name, amount)
                and Inventory:AddItem(src, reward.name, amount, nil, nil, 'rsg-cards:set-bonus')
            if not given then given = Inventory:ForceDropItem(src, reward.name, amount, nil, 'rsg-cards:set-bonus') end
            if given then parts[#parts + 1] = ('%dx %s'):format(amount, CardsServer.itemLabel(reward.name)) end
        end
    end

    return table.concat(parts, ', ')
end

-- true when this card just completed the set for the character (all cards found for the first time)
local function checkSetComplete(Player, setId)
    local set, names = setById[setId], setCards[setId]
    if not set then return false end
    local citizenid = Player.PlayerData.citizenid

    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM `rsg_cards_collection` WHERE `citizenid` = ? AND `card` IN (' .. ('?,'):rep(#names):sub(1, -2) .. ')',
        { citizenid, table.unpack(names) })
    if (tonumber(count) or 0) < Config.CardsPerSet then return false end

    -- the unique key makes sure this only ever pays once per character and set
    local inserted = MySQL.update.await('INSERT IGNORE INTO `rsg_cards_bonuses` (`citizenid`, `set_id`) VALUES (?, ?)', { citizenid, setId })
    if (tonumber(inserted) or 0) < 1 then return false end

    boardCache.at = 0 -- refresh the leaderboard

    local firstId = MySQL.scalar.await('SELECT `citizenid` FROM `rsg_cards_bonuses` WHERE `set_id` = ? ORDER BY `id` LIMIT 1', { setId })
    local isFirst = firstId == citizenid
    local label = CardsServer.itemLabel('card_cigcard_' .. setId)
    local src = Player.PlayerData.source

    local reward = giveBonus(Player, set)
    if reward ~= '' then
        CardsServer.notify(src, locale('set_bonus', label, reward), 'success')
    else
        CardsServer.notify(src, locale('set_completed', label), 'success')
    end
    CardsServer.log(('**Set completed**\n%s\n%s%s%s'):format(CardsServer.playerTag(Player), label,
        reward ~= '' and (' - bonus ' .. reward) or '', isFirst and ' (first on the server)' or ''))

    if isFirst and Config.Collection.AnnounceFirst then
        local charinfo = Player.PlayerData.charinfo or {}
        TriggerClientEvent('RSGCore:Client:Notify', -1, {
            title = locale('title'),
            description = locale('first_complete', ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''), label),
            type = 'inform',
            duration = 7000,
        })
    end
    return true
end

-- Records that the character found a card and checks whether that completes its set.
-- returns isNew, collected, setComplete
function CardsServer.markFound(Player, card)
    local isNew, collected = CardsServer.recordCard(Player, card)
    local complete = false
    if isNew then
        CardsServer.saveProfile(Player)
        local info = Cards.Info[card]
        local ok, result = pcall(checkSetComplete, Player, info and info.set)
        complete = ok and result == true
        if not ok then print(('^1[rsg-cards] set check failed: %s^7'):format(result)) end
    end
    return isNew, collected, complete
end

-- Characters that had already found every card of a set before this feature existed are recorded
-- as having completed it (no bonus is paid), so the "first collector" titles are correct.
CardsServer.whenReady(function()
    for _, set in ipairs(Config.Sets) do
        MySQL.query.await([[
            INSERT IGNORE INTO `rsg_cards_bonuses` (`citizenid`, `set_id`, `completed_at`)
            SELECT `citizenid`, ?, MAX(`obtained_at`) FROM `rsg_cards_collection`
            WHERE `card` REGEXP ? GROUP BY `citizenid` HAVING COUNT(*) >= ? ORDER BY MAX(`obtained_at`)
        ]], { set.id, '^card_cigcard_' .. set.id .. '_c[0-9]+$', Config.CardsPerSet })
    end
end)

---------------------------------------------------------------------
-- COLLECTION VIEWER AND LEADERBOARD
---------------------------------------------------------------------
-- leaderboard rows and the first collector of every set (cached)
local function loadBoard()
    local ttl = tonumber(Config.Collection.CacheSeconds) or 60
    if boardCache.board and os.time() - boardCache.at < ttl then return boardCache.board, boardCache.first end

    local size = math.max(1, math.floor(tonumber(Config.Collection.LeaderboardSize) or 10))
    local board = MySQL.query.await([[
        SELECT c.`citizenid`, COUNT(*) AS `found`, COALESCE(p.`name`, '') AS `name`,
               (SELECT COUNT(*) FROM `rsg_cards_bonuses` b WHERE b.`citizenid` = c.`citizenid`) AS `sets`
        FROM `rsg_cards_collection` c
        LEFT JOIN `rsg_cards_profiles` p ON p.`citizenid` = c.`citizenid`
        GROUP BY c.`citizenid`, p.`name`
        ORDER BY `found` DESC, MIN(c.`obtained_at`) ASC
        LIMIT ?
    ]], { size }) or {}

    local first = {}
    local rows = MySQL.query.await([[
        SELECT b.`set_id`, b.`citizenid`, COALESCE(p.`name`, '') AS `name`
        FROM `rsg_cards_bonuses` b
        JOIN (SELECT `set_id`, MIN(`id`) AS `id` FROM `rsg_cards_bonuses` GROUP BY `set_id`) f ON f.`id` = b.`id`
        LEFT JOIN `rsg_cards_profiles` p ON p.`citizenid` = b.`citizenid`
    ]]) or {}
    for _, row in ipairs(rows) do first[row.set_id] = row end

    boardCache = { at = os.time(), board = board, first = first }
    return board, first
end

local function collectionData(Player)
    local citizenid = Player.PlayerData.citizenid
    CardsServer.saveProfile(Player)

    local found = {}
    local totalFound = 0
    for _, row in ipairs(MySQL.query.await('SELECT `card` FROM `rsg_cards_collection` WHERE `citizenid` = ?', { citizenid }) or {}) do
        if Cards.Info[row.card] then
            found[row.card] = true
            totalFound = totalFound + 1
        end
    end

    local board, first = loadBoard()

    local sets = {}
    for _, set in ipairs(Config.Sets) do
        local cards, count = {}, 0
        for _, name in ipairs(setCards[set.id]) do
            local has = found[name] == true
            if has then count = count + 1 end
            cards[#cards + 1] = { name = name, label = CardsServer.itemLabel(name), image = CardsServer.itemImage(name), found = has }
        end
        local deck = 'card_cigcard_' .. set.id
        local firstRow = first[set.id]
        sets[#sets + 1] = {
            id = set.id,
            label = CardsServer.itemLabel(deck),
            image = CardsServer.itemImage(deck),
            found = count,
            total = Config.CardsPerSet,
            complete = count >= Config.CardsPerSet,
            first = firstRow and displayName(firstRow.name) or nil,
            firstMe = firstRow ~= nil and firstRow.citizenid == citizenid,
            cards = cards,
        }
    end

    local rows, inTop = {}, false
    for rank, row in ipairs(board) do
        local me = row.citizenid == citizenid
        if me then inTop = true end
        rows[rank] = { rank = rank, name = displayName(row.name), found = tonumber(row.found) or 0, sets = tonumber(row.sets) or 0, me = me }
    end

    local myRank
    if not inTop and totalFound > 0 then
        local ahead = MySQL.scalar.await(
            'SELECT COUNT(*) FROM (SELECT `citizenid` FROM `rsg_cards_collection` GROUP BY `citizenid` HAVING COUNT(*) > ?) t', { totalFound })
        myRank = (tonumber(ahead) or 0) + 1
    end

    return { sets = sets, found = totalFound, total = Cards.Total, board = rows, myRank = myRank }
end

RSGCore.Functions.CreateCallback('rsg-cards:server:getCollection', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not CardsServer.dbReady() then return cb(false) end
    if not CardsServer.throttle(source, 'collection', 1) then return cb(false) end
    local ok, data = pcall(collectionData, Player)
    if not ok then
        print(('^1[rsg-cards] collection failed: %s^7'):format(data))
        return cb(false)
    end
    cb(data)
end)

RSGCore.Commands.Add(Config.Collection.Command, locale('command_collection'), {}, false, function(source)
    TriggerClientEvent('rsg-cards:client:openCollection', source)
end, 'user')
