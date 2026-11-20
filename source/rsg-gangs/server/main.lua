local RSGCore = exports['rsg-core']:GetCoreObject()

---------------------------------------------------------------------
-- Shared internal API. The other server files (loaded after this one)
-- register their own functions on this table and call the helpers below.
---------------------------------------------------------------------
RSGGangs = {}

-- Gangs[name] = { name, label, color, bank, owner, stashTier, stashId, wagon = {x,y,z,heading}|nil,
--                 members = { [citizenid] = { rank, source|nil, name } },
--                 equipment = { [itemId] = { { id, x, y, z, heading }, ... } } }
local Gangs = {}
local memberIndex = {} -- [citizenid] = gangName (O(1) lookup instead of scanning every gang)

RSGGangs.Gangs = Gangs
RSGGangs.Loaded = false

local pendingGangNames = {}
local pendingMembershipChange = {}
local pendingInvites = {} -- [citizenid] = { gangName, invitedBy, inviterSrc, expires }

---------------------------------------------------------------------
-- Generic helpers
---------------------------------------------------------------------
local function isFinite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

local function generateUUID()
    return (('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'):gsub('[xy]', function(c)
        local v = (c == 'x') and math.random(0, 15) or math.random(8, 11)
        return ('%x'):format(v)
    end))
end

local function trim(s)
    return (s:match('^%s*(.-)%s*$'))
end

local function charName(Player)
    local info = Player.PlayerData.charinfo or {}
    return trim(((info.firstname or '') .. ' ' .. (info.lastname or '')))
end

local function notify(src, message, nType)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('notify_title'),
        description = message,
        type = nType or 'inform',
        duration = Config.Notify and Config.Notify.duration or 5000,
    })
end

-- Per-source rate limit. Returns true when the caller must stop (called again too soon).
local cooldowns = {}
local function onCooldown(src, key, ms)
    local now = GetGameTimer()
    local bucket = cooldowns[src]
    if not bucket then
        bucket = {}
        cooldowns[src] = bucket
    end
    if bucket[key] and (now - bucket[key]) < ms then return true end
    bucket[key] = now
    return false
end

-- Short-lived server-issued permissions. The server grants a source the right to report
-- one specific thing (e.g. "you may register the wagon you just spawned for gang X");
-- the matching net event must consume the grant, so a client cannot invent reports.
local grants = {}
local function grant(src, key, ttlSeconds)
    grants[src] = grants[src] or {}
    grants[src][key] = os.time() + (ttlSeconds or 60)
end

local function hasGrant(src, key)
    local g = grants[src]
    return g ~= nil and g[key] ~= nil and g[key] >= os.time()
end

local function consumeGrant(src, key)
    local ok = hasGrant(src, key)
    if grants[src] then grants[src][key] = nil end
    return ok
end

local function validCoords(c)
    local t = type(c)
    if t ~= 'table' and t ~= 'vector3' then return false end
    return isFinite(c.x) and isFinite(c.y) and isFinite(c.z)
end

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function isNear(src, coords, distance)
    local pc = playerCoords(src)
    if not pc or not validCoords(coords) then return false end
    return #(pc - vector3(coords.x, coords.y, coords.z)) <= distance
end

-- Snapshot of every fully-loaded player and where they are. Built once per streaming tick.
local function playerPositions()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and RSGCore.Functions.GetPlayer(src) then
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 then
                list[#list + 1] = { src = src, coords = GetEntityCoords(ped) }
            end
        end
    end
    return list
end

-- Closest player in `positions` within `radius` of `coords`, or nil.
local function nearestPlayer(positions, coords, radius)
    local best, bestDist = nil, radius
    for i = 1, #positions do
        local d = #(positions[i].coords - coords)
        if d <= bestDist then
            best, bestDist = positions[i].src, d
        end
    end
    return best
end

local function logEvent(title, message)
    if not Config.Logging or not Config.Logging.enabled then return end
    TriggerEvent('rsg-log:server:CreateLog', Config.Logging.channel or 'default', title, 'blue', message)
end

-- Activity log (shown to higher ranks in the UI). `...` are plain text arguments for the locale line.
local function addLog(gang, citizenid, action, ...)
    if not Config.ActivityLog or not Config.ActivityLog.enabled or not gang then return end
    local parts = {}
    for _, v in ipairs({ ... }) do parts[#parts + 1] = tostring(v):gsub('|', '/') end
    local member = citizenid and gang.members[citizenid] or nil
    if RSGGangs.Webhook then RSGGangs.Webhook(gang, member and member.name or nil, action, parts) end
    pcall(MySQL.insert, 'INSERT INTO rsg_gang_logs (gang_name, citizenid, actor, action, detail) VALUES (?, ?, ?, ?, ?)', {
        gang.name, citizenid, member and member.name or nil, action, table.concat(parts, '|'):sub(1, 200),
    })
end

---------------------------------------------------------------------
-- Database
---------------------------------------------------------------------
-- Keep these statements identical to installation/rsg-gangs.sql.
local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `rsg_gangs` (
        `name` varchar(50) NOT NULL,
        `label` varchar(50) NOT NULL,
        `color` varchar(10) NOT NULL DEFAULT '#e63946',
        `bank` int(11) NOT NULL DEFAULT 0,
        `owner` varchar(50) NOT NULL,
        `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `wagon_x` float DEFAULT NULL,
        `wagon_y` float DEFAULT NULL,
        `wagon_z` float DEFAULT NULL,
        `wagon_heading` float DEFAULT NULL,
        `stash_tier` varchar(20) NOT NULL DEFAULT 'small',
        `stash_id` varchar(36) DEFAULT NULL,
        `upkeep_due` int(11) DEFAULT NULL,
        `upkeep_missed` int(11) NOT NULL DEFAULT 0,
        `tag` varchar(8) DEFAULT NULL,
        PRIMARY KEY (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_gang_members` (
        `citizenid` varchar(50) NOT NULL,
        `gang_name` varchar(50) NOT NULL,
        `rank` varchar(50) NOT NULL DEFAULT 'recruit',
        `name` varchar(100) DEFAULT NULL,
        `joined_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`),
        KEY `gang_name` (`gang_name`),
        CONSTRAINT `fk_gang_member_gang` FOREIGN KEY (`gang_name`) REFERENCES `rsg_gangs` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_gang_equipment` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `gang_name` varchar(50) NOT NULL,
        `item_id` varchar(50) NOT NULL,
        `x` float NOT NULL,
        `y` float NOT NULL,
        `z` float NOT NULL,
        `heading` float NOT NULL DEFAULT 0,
        `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `gang_item` (`gang_name`, `item_id`),
        CONSTRAINT `fk_gang_equipment_gang` FOREIGN KEY (`gang_name`) REFERENCES `rsg_gangs` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_gang_logs` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `gang_name` varchar(50) NOT NULL,
        `citizenid` varchar(50) DEFAULT NULL,
        `actor` varchar(100) DEFAULT NULL,
        `action` varchar(40) NOT NULL,
        `detail` varchar(200) DEFAULT NULL,
        `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `gang_id` (`gang_name`, `id`),
        CONSTRAINT `fk_gang_log_gang` FOREIGN KEY (`gang_name`) REFERENCES `rsg_gangs` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_gang_bounties` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `gang_name` varchar(50) NOT NULL,
        `reward` int(11) NOT NULL,
        `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `gang_name` (`gang_name`),
        CONSTRAINT `fk_gang_bounty_gang` FOREIGN KEY (`gang_name`) REFERENCES `rsg_gangs` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_gang_rivals` (
        `gang_name` varchar(50) NOT NULL,
        `rival_name` varchar(50) NOT NULL,
        `kills` int(11) NOT NULL DEFAULT 0,
        PRIMARY KEY (`gang_name`, `rival_name`),
        CONSTRAINT `fk_gang_rival_gang` FOREIGN KEY (`gang_name`) REFERENCES `rsg_gangs` (`name`) ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT `fk_gang_rival_other` FOREIGN KEY (`rival_name`) REFERENCES `rsg_gangs` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_gang_territories` (
        `territory_id` varchar(50) NOT NULL,
        `gang_name` varchar(50) NOT NULL,
        `claimed_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`territory_id`),
        KEY `gang_name` (`gang_name`),
        CONSTRAINT `fk_gang_territory_gang` FOREIGN KEY (`gang_name`) REFERENCES `rsg_gangs` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

-- Columns added after 2.0.x: { table, column, definition }. Added only when missing.
local COLUMN_UPGRADES = {
    { 'rsg_gang_members', 'name', 'varchar(100) DEFAULT NULL AFTER `rank`' },
    { 'rsg_gangs', 'upkeep_due', 'int(11) DEFAULT NULL' },
    { 'rsg_gangs', 'upkeep_missed', 'int(11) NOT NULL DEFAULT 0' },
    { 'rsg_gangs', 'tag', 'varchar(8) DEFAULT NULL' },
}

local function ensureDatabase()
    local ok, err = pcall(function()
        for _, query in ipairs(SCHEMA) do
            MySQL.query.await(query)
        end

        for _, upgrade in ipairs(COLUMN_UPGRADES) do
            local exists = MySQL.scalar.await([[
                SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
            ]], { upgrade[1], upgrade[2] })
            if (tonumber(exists) or 0) == 0 then
                MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(upgrade[1], upgrade[2], upgrade[3]))
            end
        end
    end)

    if not ok then
        print(('^1[rsg-gangs] database setup failed: %s^7'):format(tostring(err)))
        return false
    end
    print('^2[rsg-gangs] database tables ready^7')
    return true
end

-- Runs a write statement. Returns true when it executed without an error.
local function dbOk(query, params)
    local ok, res = pcall(MySQL.update.await, query, params)
    if not ok then
        print(('^1[rsg-gangs] database error: %s^7'):format(tostring(res)))
        return false
    end
    return res ~= nil
end

local function dbTransaction(queries)
    local ok, res = pcall(MySQL.transaction.await, queries)
    if not ok then
        print(('^1[rsg-gangs] database transaction error: %s^7'):format(tostring(res)))
        return false
    end
    return res == true
end

---------------------------------------------------------------------
-- Ranks
---------------------------------------------------------------------
local rankByName, rankByWeight, permissionSets, rankPayload = {}, {}, {}, {}

for _, rank in ipairs(Config.Ranks) do
    rankByName[rank.name] = rank
    rankByWeight[rank.weight] = rank
    local set = {}
    for _, perm in ipairs(rank.permissions or {}) do set[perm] = true end
    permissionSets[rank.name] = set
    rankPayload[#rankPayload + 1] = { name = rank.name, label = rank.label, weight = rank.weight, isLeader = rank.isLeader == true }
end

local function getRankData(rankName)
    return rankByName[rankName]
end

local function hasPermission(rankName, permission)
    local set = permissionSets[rankName]
    return set ~= nil and set[permission] == true
end

local function rankWeight(rankName)
    local rank = rankByName[rankName]
    return rank and rank.weight or -1
end

local function canViewLog(rankName)
    local cfg = Config.ActivityLog
    return cfg ~= nil and cfg.enabled == true and rankWeight(rankName) >= (cfg.minWeight or 0)
end

local function permissionList(rankName)
    local rank = rankByName[rankName]
    return rank and rank.permissions or {}
end

---------------------------------------------------------------------
-- Config sanity check (prints warnings, never stops the resource)
---------------------------------------------------------------------
local function validateConfig()
    local function warn(msg) print(('^3[rsg-gangs] config: %s^7'):format(msg)) end

    local seenName, seenWeight, hasLeader = {}, {}, false
    for _, rank in ipairs(Config.Ranks) do
        if seenName[rank.name] then warn(('duplicate rank name "%s"'):format(rank.name)) end
        if seenWeight[rank.weight] then warn(('duplicate rank weight %s'):format(rank.weight)) end
        seenName[rank.name], seenWeight[rank.weight] = true, true
        if rank.isLeader then hasLeader = true end
    end
    if not hasLeader then warn('no rank has isLeader = true') end
    if not rankByName[Config.DefaultLeaderRank] then warn('Config.DefaultLeaderRank is not a defined rank') end
    if not rankByName[Config.DefaultJoinRank] then warn('Config.DefaultJoinRank is not a defined rank') end
    for weight = 0, #Config.Ranks - 1 do
        if not rankByWeight[weight] then warn('rank weights must be consecutive starting at 0 (promote/demote step by one)') break end
    end

    local equipmentIds = {}
    for _, cfg in ipairs(Config.GangEquipment) do
        if equipmentIds[cfg.id] then warn(('duplicate equipment id "%s"'):format(cfg.id)) end
        equipmentIds[cfg.id] = true
    end

    local items = RSGCore.Shared.Items or {}
    local function checkItem(name, where)
        if not items[name] then warn(('%s uses item "%s" which does not exist in your items list'):format(where, tostring(name))) end
    end

    if Config.Crafting and Config.Crafting.enabled then
        for _, station in ipairs(Config.Crafting.stations or {}) do
            if not equipmentIds[station.equipmentId] then
                warn(('crafting station "%s" points at unknown equipmentId "%s"'):format(station.id, tostring(station.equipmentId)))
            end
            for _, recipe in ipairs(station.recipes or {}) do
                checkItem(recipe.output.item, ('recipe "%s" output'):format(recipe.id))
                for _, ing in ipairs(recipe.ingredients or {}) do
                    checkItem(ing.item, ('recipe "%s" ingredient'):format(recipe.id))
                end
            end
        end
    end

    if Config.GangStash and Config.GangStash.enabled and not equipmentIds[Config.GangStash.equipmentId] then
        warn(('Config.GangStash.equipmentId "%s" is not a Config.GangEquipment id'):format(tostring(Config.GangStash.equipmentId)))
    end
end

---------------------------------------------------------------------
-- Gang / member bookkeeping (memory side)
---------------------------------------------------------------------
local function findGangByMember(citizenid)
    local name = memberIndex[citizenid]
    return name and Gangs[name] or nil
end

local function addMember(gang, citizenid, rank, src, name)
    gang.members[citizenid] = { rank = rank, source = src, name = name }
    memberIndex[citizenid] = gang.name
end

local function removeMember(gang, citizenid)
    gang.members[citizenid] = nil
    if memberIndex[citizenid] == gang.name then memberIndex[citizenid] = nil end
end

local function memberCount(gang)
    local n = 0
    for _ in pairs(gang.members) do n = n + 1 end
    return n
end

local function getPlayerCitizenId(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and Player.PlayerData.citizenid or nil
end

local function sanitizeGangName(input)
    if type(input) ~= 'string' then return nil end
    input = input:lower():gsub('%s+', '_'):gsub('[^%w_]', '')
    return input
end

-- Cleans player-supplied text for display: no control characters or markup, collapsed spaces.
-- Returns nil when the result is outside the allowed length.
local function cleanLabel(input)
    if type(input) ~= 'string' then return nil end
    input = input:gsub('[%c<>"\\]', ''):gsub('%s+', ' ')
    input = trim(input)
    local len = utf8.len(input) or #input
    if len < Config.MinNameLength or len > Config.MaxNameLength then return nil end
    return input
end

-- Whole, positive, finite number within the bank limits; otherwise nil.
local function parseAmount(value)
    local n = tonumber(value)
    if not isFinite(n) or n <= 0 or n ~= math.floor(n) or n > Config.MaxBankBalance then return nil end
    return n
end

local function stashTierIndex(tierId)
    local tiers = Config.GangStash and Config.GangStash.tiers
    if not tiers then return nil end
    for i, tier in ipairs(tiers) do
        if tier.id == tierId then return i end
    end
    return nil
end

---------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------
local function loadGangs()
    for key in pairs(Gangs) do Gangs[key] = nil end
    for key in pairs(memberIndex) do memberIndex[key] = nil end

    local gangRows = MySQL.query.await('SELECT * FROM rsg_gangs', {}) or {}
    for _, row in ipairs(gangRows) do
        local stashId = row.stash_id
        if not stashId or stashId == '' then
            stashId = generateUUID()
            dbOk('UPDATE rsg_gangs SET stash_id = ? WHERE name = ?', { stashId, row.name })
        end

        Gangs[row.name] = {
            name = row.name,
            label = row.label,
            color = row.color,
            bank = row.bank,
            owner = row.owner,
            members = {},
            equipment = {},
            wagon = row.wagon_x and {
                x = row.wagon_x, y = row.wagon_y, z = row.wagon_z, heading = row.wagon_heading or 0.0,
            } or nil,
            stashTier = row.stash_tier or 'small',
            stashId = stashId,
            upkeepDue = row.upkeep_due,
            upkeepMissed = row.upkeep_missed or 0,
            tag = row.tag,
        }
    end

    local missingNames = {}
    local memberRows = MySQL.query.await('SELECT * FROM rsg_gang_members', {}) or {}
    for _, row in ipairs(memberRows) do
        local gang = Gangs[row.gang_name]
        if gang then
            addMember(gang, row.citizenid, row.rank, nil, row.name)
            if not row.name or row.name == '' then missingNames[#missingNames + 1] = row.citizenid end
        end
    end

    -- Members saved before 2.1.0 have no stored name yet: look them up once from the players table.
    if #missingNames > 0 then
        local ok, rows = pcall(MySQL.query.await, 'SELECT citizenid, charinfo FROM players WHERE citizenid IN (?)', { missingNames })
        if ok and rows then
            for _, row in ipairs(rows) do
                local info = type(row.charinfo) == 'string' and json.decode(row.charinfo) or row.charinfo
                local gang = findGangByMember(row.citizenid)
                if gang and type(info) == 'table' and info.firstname then
                    local name = trim(info.firstname .. ' ' .. (info.lastname or ''))
                    gang.members[row.citizenid].name = name
                    dbOk('UPDATE rsg_gang_members SET name = ? WHERE citizenid = ?', { name, row.citizenid })
                end
            end
        end
    end

    local equipmentRows = MySQL.query.await('SELECT * FROM rsg_gang_equipment', {}) or {}
    for _, row in ipairs(equipmentRows) do
        local gang = Gangs[row.gang_name]
        if gang then
            gang.equipment[row.item_id] = gang.equipment[row.item_id] or {}
            table.insert(gang.equipment[row.item_id], { id = row.id, x = row.x, y = row.y, z = row.z, heading = row.heading })
        end
    end

    RSGGangs.Loaded = true
end

CreateThread(function()
    validateConfig()
    if Config.AutoDatabase and not ensureDatabase() then return end

    local ok, err = pcall(loadGangs)
    if not ok then
        print(('^1[rsg-gangs] failed to load gangs: %s^7'):format(tostring(err)))
        print('^1[rsg-gangs] Are the database tables installed? (Config.AutoDatabase or installation/rsg-gangs.sql)^7')
    end
end)

---------------------------------------------------------------------
-- State sent to the NUI
---------------------------------------------------------------------
local function refreshMemberOnlineData(gang)
    for citizenid, member in pairs(gang.members) do
        local Player = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
        if Player then
            member.source = Player.PlayerData.source
            local name = charName(Player)
            if name ~= '' and name ~= member.name then
                member.name = name
                pcall(MySQL.update, 'UPDATE rsg_gang_members SET name = ? WHERE citizenid = ?', { name, citizenid })
            end
        else
            member.source = nil
        end
    end
end

local function buildGangPayload(gang)
    refreshMemberOnlineData(gang)

    local members = {}
    for citizenid, data in pairs(gang.members) do
        local rank = getRankData(data.rank)
        members[#members + 1] = {
            citizenid = citizenid,
            name = data.name or citizenid,
            rank = data.rank,
            rankLabel = rank and rank.label or data.rank,
            weight = rankWeight(data.rank),
            online = data.source ~= nil,
        }
    end
    table.sort(members, function(a, b)
        if a.weight ~= b.weight then return a.weight > b.weight end
        return a.name < b.name
    end)

    local equipment = {}
    for _, cfg in ipairs(Config.GangEquipment) do
        local list = gang.equipment[cfg.id]
        local count = list and #list or 0
        equipment[#equipment + 1] = {
            id = cfg.id,
            label = cfg.label,
            deployedCount = count,
            maxDeployed = cfg.maxDeployed or 1,
            deployed = count > 0,
        }
    end

    local stashTiers = {}
    if Config.GangStash and Config.GangStash.tiers then
        local currentIndex = stashTierIndex(gang.stashTier) or 1
        for i, tier in ipairs(Config.GangStash.tiers) do
            stashTiers[#stashTiers + 1] = {
                id = tier.id,
                label = tier.label,
                slots = tier.slots,
                maxWeight = tier.maxWeight,
                upgradeCost = tier.upgradeCost,
                isCurrent = i == currentIndex,
                isPurchased = i <= currentIndex,
                isNext = i == currentIndex + 1,
                canAfford = gang.bank >= (tier.upgradeCost or 0),
            }
        end
    end

    return {
        name = gang.name,
        label = gang.label,
        color = gang.color,
        bank = gang.bank,
        maxMembers = Config.MaxMembers,
        hasWagon = gang.wagon ~= nil,
        members = members,
        ranks = rankPayload,
        equipment = equipment,
        stashTiers = stashTiers,
        territories = RSGGangs.TerritoryPayload and RSGGangs.TerritoryPayload(gang) or nil,
        upkeep = RSGGangs.UpkeepPayload and RSGGangs.UpkeepPayload(gang) or nil,
        bounties = RSGGangs.BountyPayload and RSGGangs.BountyPayload(gang) or nil,
        honor = gang.honorAvg,
        tag = gang.tag,
        rivals = RSGGangs.RivalPayload and RSGGangs.RivalPayload(gang) or nil,
    }
end

local function buildState(citizenid, gang)
    local member = gang and gang.members[citizenid]
    return {
        citizenid = citizenid,
        inGang = gang ~= nil,
        gang = gang and buildGangPayload(gang) or nil,
        myRank = member and member.rank or nil,
        myPermissions = member and permissionList(member.rank) or {},
        canViewLog = member and canViewLog(member.rank) or false,
        tagsEnabled = Config.Tags and Config.Tags.enabled or false,
        leaderboardEnabled = Config.Leaderboard and Config.Leaderboard.enabled or false,
        createCost = Config.CreateGangCost,
        minNameLength = Config.MinNameLength,
        maxNameLength = Config.MaxNameLength,
        maxBank = Config.MaxBankBalance,
        colors = Config.GangColors,
    }
end

local function broadcastGangUpdate(gang)
    if not gang then return end
    local payload = buildGangPayload(gang)
    for citizenid, member in pairs(gang.members) do
        if member.source then
            TriggerClientEvent('rsg-gangs:client:setState', member.source, {
                citizenid = citizenid,
                inGang = true,
                gang = payload,
                myRank = member.rank,
                myPermissions = permissionList(member.rank),
                canViewLog = canViewLog(member.rank),
                tagsEnabled = Config.Tags and Config.Tags.enabled or false,
                leaderboardEnabled = Config.Leaderboard and Config.Leaderboard.enabled or false,
                createCost = Config.CreateGangCost,
                minNameLength = Config.MinNameLength,
                maxNameLength = Config.MaxNameLength,
                maxBank = Config.MaxBankBalance,
                colors = Config.GangColors,
            })
        end
    end
end

-- Bank changes go through here: memory is updated first (no yield, so concurrent callers see the
-- new balance) and the database uses a delta so two overlapping updates can never overwrite each other.
local function adjustBank(gang, delta)
    if delta < 0 and gang.bank + delta < 0 then return false end
    if delta > 0 and gang.bank + delta > Config.MaxBankBalance then return false end

    gang.bank = gang.bank + delta
    if not dbOk('UPDATE rsg_gangs SET bank = bank + ? WHERE name = ?', { delta, gang.name }) then
        gang.bank = gang.bank - delta
        return false
    end
    return true
end

---------------------------------------------------------------------
-- Creating and destroying gangs
---------------------------------------------------------------------
-- Creates a gang row (and, when `leader` is given, its first member) in one transaction.
local function createGangRecord(gangName, label, color, owner, leader)
    local stashId = generateUUID()
    local leaderName = leader and charName(leader) or nil

    local queries = {
        { query = 'INSERT INTO rsg_gangs (name, label, color, bank, owner, stash_id) VALUES (?, ?, ?, 0, ?, ?)',
          values = { gangName, label, color, owner, stashId } },
    }
    if leader then
        queries[#queries + 1] = {
            query = 'INSERT INTO rsg_gang_members (citizenid, gang_name, rank, name) VALUES (?, ?, ?, ?)',
            values = { leader.PlayerData.citizenid, gangName, Config.DefaultLeaderRank, leaderName },
        }
    end
    if not dbTransaction(queries) then return nil end

    local gang = {
        name = gangName, label = label, color = color, bank = 0, owner = owner,
        members = {}, equipment = {}, stashTier = 'small', stashId = stashId,
    }
    Gangs[gangName] = gang
    if leader then
        addMember(gang, leader.PlayerData.citizenid, Config.DefaultLeaderRank, leader.PlayerData.source, leaderName)
    end
    return gang
end

-- Removes a gang everywhere: database (members/equipment cascade), the world entities, memory and invites.
local function destroyGang(gang, notifyKey, notifyType)
    if not dbOk('DELETE FROM rsg_gangs WHERE name = ?', { gang.name }) then return false end

    for citizenid, member in pairs(gang.members) do
        if member.source then
            if notifyKey then notify(member.source, locale(notifyKey), notifyType or 'inform') end
            TriggerClientEvent('rsg-gangs:client:setState', member.source, { inGang = false })
        end
        if memberIndex[citizenid] == gang.name then memberIndex[citizenid] = nil end
    end

    if RSGGangs.DeleteGangWagon then RSGGangs.DeleteGangWagon(gang.name) end
    if RSGGangs.DeleteAllGangEquipment then RSGGangs.DeleteAllGangEquipment(gang.name) end
    if RSGGangs.OnGangDestroyed then RSGGangs.OnGangDestroyed(gang) end

    for citizenid, invite in pairs(pendingInvites) do
        if invite.gangName == gang.name then pendingInvites[citizenid] = nil end
    end

    Gangs[gang.name] = nil
    return true
end

-- Adds an online player to a gang (database + memory). Returns true on success.
local function insertMember(gang, Player, rank)
    local citizenid = Player.PlayerData.citizenid
    if findGangByMember(citizenid) or pendingMembershipChange[citizenid] then return false end

    pendingMembershipChange[citizenid] = true
    local name = charName(Player)
    local ok, res = pcall(MySQL.insert.await,
        'INSERT INTO rsg_gang_members (citizenid, gang_name, rank, name) VALUES (?, ?, ?, ?)',
        { citizenid, gang.name, rank, name })
    pendingMembershipChange[citizenid] = nil

    if not ok or res == nil then return false end
    addMember(gang, citizenid, rank, Player.PlayerData.source, name)
    pendingInvites[citizenid] = nil
    return true
end

---------------------------------------------------------------------
-- Internal API for the other server files
---------------------------------------------------------------------
RSGGangs.GetRankData = getRankData
RSGGangs.HasPermission = hasPermission
RSGGangs.RankWeight = rankWeight
RSGGangs.Notify = notify
RSGGangs.FindGangByMember = findGangByMember
RSGGangs.GetPlayerCitizenId = getPlayerCitizenId
RSGGangs.SanitizeGangName = sanitizeGangName
RSGGangs.CleanLabel = cleanLabel
RSGGangs.BroadcastGangUpdate = broadcastGangUpdate
RSGGangs.AdjustBank = adjustBank
RSGGangs.CreateGangRecord = createGangRecord
RSGGangs.DestroyGang = destroyGang
RSGGangs.InsertMember = insertMember
RSGGangs.StashTierIndex = stashTierIndex
RSGGangs.CharName = charName
RSGGangs.OnCooldown = onCooldown
RSGGangs.Grant = grant
RSGGangs.ConsumeGrant = consumeGrant
RSGGangs.IsFinite = isFinite
RSGGangs.ValidCoords = validCoords
RSGGangs.PlayerCoords = playerCoords
RSGGangs.IsNear = isNear
RSGGangs.PlayerPositions = playerPositions
RSGGangs.NearestPlayer = nearestPlayer
RSGGangs.Log = logEvent
RSGGangs.AddLog = addLog
RSGGangs.DbOk = dbOk

---------------------------------------------------------------------
-- Exports for other resources
---------------------------------------------------------------------
exports('GetPlayerGang', function(citizenid)
    local gang = findGangByMember(citizenid)
    if not gang then return nil end
    return {
        name = gang.name,
        label = gang.label,
        color = gang.color,
        rank = gang.members[citizenid].rank,
    }
end)

exports('GetGangData', function(gangName)
    local gang = Gangs[gangName]
    if not gang then return nil end
    return buildGangPayload(gang)
end)

exports('IsGangLeader', function(citizenid)
    local gang = findGangByMember(citizenid)
    if not gang then return false end
    local rank = getRankData(gang.members[citizenid].rank)
    return rank ~= nil and rank.isLeader == true
end)

exports('HasGangPermission', function(citizenid, permission)
    local gang = findGangByMember(citizenid)
    if not gang then return false end
    return hasPermission(gang.members[citizenid].rank, permission)
end)

exports('GetGangMembers', function(gangName)
    local gang = Gangs[gangName]
    if not gang then return nil end
    return buildGangPayload(gang).members
end)

exports('GetGangBank', function(gangName)
    local gang = Gangs[gangName]
    return gang and gang.bank or nil
end)

-- For other scripts (heist payouts, gang shops...). Returns true on success.
exports('AddGangBank', function(gangName, amount, reason)
    local gang = Gangs[gangName]
    amount = parseAmount(amount)
    if not gang or not amount then return false end
    if not adjustBank(gang, amount) then return false end
    logEvent('Gang bank +', ('%s +$%s (%s)'):format(gang.name, amount, tostring(reason or 'export')))
    broadcastGangUpdate(gang)
    return true
end)

exports('RemoveGangBank', function(gangName, amount, reason)
    local gang = Gangs[gangName]
    amount = parseAmount(amount)
    if not gang or not amount then return false end
    if not adjustBank(gang, -amount) then return false end
    logEvent('Gang bank -', ('%s -$%s (%s)'):format(gang.name, amount, tostring(reason or 'export')))
    broadcastGangUpdate(gang)
    return true
end)

---------------------------------------------------------------------
-- NUI: fetch state
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:requestState', function()
    local src = source
    if onCooldown(src, 'state', 500) then return end
    local citizenid = getPlayerCitizenId(src)
    if not citizenid then return end

    TriggerClientEvent('rsg-gangs:client:setState', src, buildState(citizenid, findGangByMember(citizenid)))
end)

---------------------------------------------------------------------
-- Create gang
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:createGang', function(label)
    local src = source
    if onCooldown(src, 'create', 3000) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    if findGangByMember(citizenid) or pendingMembershipChange[citizenid] then
        notify(src, locale('error_already_gang'), 'error')
        return
    end

    label = cleanLabel(label)
    local gangName = label and sanitizeGangName(label)
    if not label or not gangName or #gangName < Config.MinNameLength then
        notify(src, locale('error_invalid_name', Config.MinNameLength, Config.MaxNameLength), 'error')
        return
    end

    if Gangs[gangName] or pendingGangNames[gangName] then
        notify(src, locale('error_gang_exists'), 'error')
        return
    end

    local cost = Config.CreateGangCost
    if cost > 0 and Player.Functions.GetMoney('cash') < cost then
        notify(src, locale('error_not_enough_money'), 'error')
        return
    end

    pendingGangNames[gangName] = true
    pendingMembershipChange[citizenid] = true

    if cost > 0 and Player.Functions.RemoveMoney('cash', cost, 'gang-creation') == false then
        pendingGangNames[gangName] = nil
        pendingMembershipChange[citizenid] = nil
        notify(src, locale('error_not_enough_money'), 'error')
        return
    end

    -- The creating player is added by createGangRecord itself, so release the membership lock first.
    pendingMembershipChange[citizenid] = nil
    local gang = createGangRecord(gangName, label, Config.GangColors[math.random(#Config.GangColors)], citizenid, Player)
    pendingGangNames[gangName] = nil

    if not gang then
        if cost > 0 then Player.Functions.AddMoney('cash', cost, 'gang-creation-refund') end
        notify(src, locale('error_generic'), 'error')
        return
    end

    notify(src, locale('success_gang_created', label), 'success')
    logEvent('Gang created', ('%s (%s) founded by %s'):format(label, gangName, citizenid))
    addLog(gang, citizenid, 'created')
    broadcastGangUpdate(gang)

    if Config.GangVehicle.enabled then
        grant(src, 'spot:' .. gangName, 90)
        grant(src, 'wagon:' .. gangName, 150)
        TriggerClientEvent('rsg-gangs:client:findGangVehicleSpot', src, gangName)

        if Config.GangVehicle.useTargetMenu then
            TriggerClientEvent('rsg-gangs:client:closeMenu', src)
        end
    end
end)

---------------------------------------------------------------------
-- Disband
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:disbandGang', function()
    local src = source
    if onCooldown(src, 'disband', 2000) then return end
    local citizenid = getPlayerCitizenId(src)
    if not citizenid then return end
    local gang = findGangByMember(citizenid)
    if not gang then notify(src, locale('error_no_gang'), 'error') return end

    if not hasPermission(gang.members[citizenid].rank, 'disband') then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    local name, label = gang.name, gang.label
    if not destroyGang(gang, 'success_gang_disbanded', 'inform') then
        notify(src, locale('error_generic'), 'error')
        return
    end
    logEvent('Gang disbanded', ('%s (%s) disbanded by %s'):format(label, name, citizenid))
end)

---------------------------------------------------------------------
-- Invite / accept / decline
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:invitePlayer', function(targetId)
    local src = source
    if onCooldown(src, 'invite', 2000) then return end
    local citizenid = getPlayerCitizenId(src)
    if not citizenid then return end
    local gang = findGangByMember(citizenid)
    if not gang then notify(src, locale('error_no_gang'), 'error') return end

    if not hasPermission(gang.members[citizenid].rank, 'invite') then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    if Config.MaxMembers > 0 and memberCount(gang) >= Config.MaxMembers then
        notify(src, locale('error_max_members'), 'error')
        return
    end

    local targetSrc = tonumber(targetId)
    local TargetPlayer = isFinite(targetSrc) and RSGCore.Functions.GetPlayer(targetSrc)
    if not TargetPlayer then
        notify(src, locale('error_player_not_found'), 'error')
        return
    end

    local targetCitizenId = TargetPlayer.PlayerData.citizenid
    if findGangByMember(targetCitizenId) then
        notify(src, locale('error_player_already_gang'), 'error')
        return
    end

    pendingInvites[targetCitizenId] = {
        gangName = gang.name,
        invitedBy = citizenid,
        inviterSrc = src,
        expires = os.time() + Config.InviteExpireSeconds,
    }

    notify(src, locale('success_invite_sent', charName(TargetPlayer)), 'success')
    notify(targetSrc, locale('success_invite_received', gang.label), 'inform')
end)

local function takeInvite(src, Player)
    local citizenid = Player.PlayerData.citizenid
    local invite = pendingInvites[citizenid]
    if not invite then
        notify(src, locale('error_no_invite'), 'error')
        return nil
    end
    pendingInvites[citizenid] = nil

    if invite.expires < os.time() then
        notify(src, locale('error_invite_expired'), 'error')
        return nil
    end
    return invite
end

RegisterNetEvent('rsg-gangs:server:acceptInvite', function()
    local src = source
    if onCooldown(src, 'accept', 2000) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    if findGangByMember(citizenid) or pendingMembershipChange[citizenid] then
        notify(src, locale('error_already_gang'), 'error')
        pendingInvites[citizenid] = nil
        return
    end

    local invite = takeInvite(src, Player)
    if not invite then return end

    local gang = Gangs[invite.gangName]
    if not gang then
        notify(src, locale('error_invite_expired'), 'error')
        return
    end

    if Config.MaxMembers > 0 and memberCount(gang) >= Config.MaxMembers then
        notify(src, locale('error_max_members'), 'error')
        return
    end

    if not insertMember(gang, Player, Config.DefaultJoinRank) then
        notify(src, locale('error_generic'), 'error')
        return
    end

    notify(src, locale('success_joined_gang', gang.label), 'success')
    addLog(gang, citizenid, 'joined')
    if invite.inviterSrc and GetPlayerName(invite.inviterSrc) then
        notify(invite.inviterSrc, locale('success_invite_accepted', charName(Player)), 'success')
    end
    broadcastGangUpdate(gang)
end)

RegisterNetEvent('rsg-gangs:server:declineInvite', function()
    local src = source
    if onCooldown(src, 'decline', 2000) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local invite = takeInvite(src, Player)
    if not invite then return end

    notify(src, locale('success_invite_declined'), 'inform')
    if invite.inviterSrc and GetPlayerName(invite.inviterSrc) then
        notify(invite.inviterSrc, locale('notify_invite_declined', charName(Player)), 'inform')
    end
end)

---------------------------------------------------------------------
-- Kick / leave
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:kickMember', function(targetCitizenId)
    local src = source
    if onCooldown(src, 'kick', 1000) then return end
    local citizenid = getPlayerCitizenId(src)
    if not citizenid then return end
    local gang = findGangByMember(citizenid)
    if not gang then notify(src, locale('error_no_gang'), 'error') return end

    if not hasPermission(gang.members[citizenid].rank, 'kick') then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    if type(targetCitizenId) ~= 'string' then return end
    if targetCitizenId == citizenid then
        notify(src, locale('error_cannot_kick_self'), 'error')
        return
    end

    local target = gang.members[targetCitizenId]
    if not target then
        notify(src, locale('error_target_not_in_gang'), 'error')
        return
    end

    if rankWeight(target.rank) >= rankWeight(gang.members[citizenid].rank) then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    if not dbOk('DELETE FROM rsg_gang_members WHERE citizenid = ?', { targetCitizenId }) then
        notify(src, locale('error_generic'), 'error')
        return
    end
    removeMember(gang, targetCitizenId)

    notify(src, locale('success_kicked_member', target.name or targetCitizenId), 'success')
    if target.source then
        notify(target.source, locale('success_kicked'), 'inform')
        TriggerClientEvent('rsg-gangs:client:setState', target.source, { inGang = false })
    end
    logEvent('Gang kick', ('%s kicked %s from %s'):format(citizenid, targetCitizenId, gang.name))
    addLog(gang, citizenid, 'kick', target.name or targetCitizenId)
    broadcastGangUpdate(gang)
end)

RegisterNetEvent('rsg-gangs:server:leaveGang', function()
    local src = source
    if onCooldown(src, 'leave', 2000) then return end
    local citizenid = getPlayerCitizenId(src)
    if not citizenid then return end
    local gang = findGangByMember(citizenid)
    if not gang then notify(src, locale('error_no_gang'), 'error') return end

    local myRank = getRankData(gang.members[citizenid].rank)
    local others = memberCount(gang) - 1

    if myRank and myRank.isLeader and others > 0 then
        notify(src, locale('error_leader_cannot_leave'), 'error')
        return
    end

    -- Last member out: the gang is removed completely (wagon, camp equipment, rows).
    if others == 0 then
        if not destroyGang(gang) then
            notify(src, locale('error_generic'), 'error')
            return
        end
        notify(src, locale('success_left_gang'), 'success')
        TriggerClientEvent('rsg-gangs:client:setState', src, { inGang = false })
        logEvent('Gang disbanded', ('%s (%s) removed: last member left'):format(gang.label, gang.name))
        return
    end

    if not dbOk('DELETE FROM rsg_gang_members WHERE citizenid = ?', { citizenid }) then
        notify(src, locale('error_generic'), 'error')
        return
    end
    local leaverName = gang.members[citizenid] and gang.members[citizenid].name or citizenid
    removeMember(gang, citizenid)
    addLog(gang, nil, 'left', leaverName)

    notify(src, locale('success_left_gang'), 'success')
    TriggerClientEvent('rsg-gangs:client:setState', src, { inGang = false })
    broadcastGangUpdate(gang)
end)

---------------------------------------------------------------------
-- Promote / demote / transfer leadership
---------------------------------------------------------------------
local function changeRank(src, targetCitizenId, direction)
    if onCooldown(src, 'rank', 750) then return end
    local citizenid = getPlayerCitizenId(src)
    if not citizenid then return end
    local gang = findGangByMember(citizenid)
    if not gang then notify(src, locale('error_no_gang'), 'error') return end

    local permission = direction == 1 and 'promote' or 'demote'
    if not hasPermission(gang.members[citizenid].rank, permission) then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    if type(targetCitizenId) ~= 'string' or targetCitizenId == citizenid then return end
    local target = gang.members[targetCitizenId]
    if not target then
        notify(src, locale('error_target_not_in_gang'), 'error')
        return
    end

    local myWeight = rankWeight(gang.members[citizenid].rank)
    local targetWeight = rankWeight(target.rank)

    if targetWeight >= myWeight then
        notify(src, locale('error_rank_too_high'), 'error')
        return
    end

    local targetRank = getRankData(target.rank)
    if direction == -1 and targetRank and targetRank.isLeader then
        notify(src, locale('error_cannot_demote_leader'), 'error')
        return
    end

    local newRank = rankByWeight[targetWeight + direction]
    if not newRank then
        notify(src, locale('error_rank_limit'), 'error')
        return
    end
    if newRank.weight >= myWeight then
        notify(src, locale('error_rank_too_high'), 'error')
        return
    end

    if not dbOk('UPDATE rsg_gang_members SET rank = ? WHERE citizenid = ?', { newRank.name, targetCitizenId }) then
        notify(src, locale('error_generic'), 'error')
        return
    end
    target.rank = newRank.name

    addLog(gang, citizenid, direction == 1 and 'promote' or 'demote', target.name or targetCitizenId, newRank.label)
    local key = direction == 1 and 'success_promoted' or 'success_demoted'
    notify(src, locale(key, target.name or targetCitizenId, newRank.label), 'success')
    if target.source then
        notify(target.source, locale(key, target.name or targetCitizenId, newRank.label), 'inform')
    end
    broadcastGangUpdate(gang)
end

RegisterNetEvent('rsg-gangs:server:promoteMember', function(targetCitizenId)
    changeRank(source, targetCitizenId, 1)
end)

RegisterNetEvent('rsg-gangs:server:demoteMember', function(targetCitizenId)
    changeRank(source, targetCitizenId, -1)
end)

RegisterNetEvent('rsg-gangs:server:transferLeadership', function(targetCitizenId)
    local src = source
    if onCooldown(src, 'transfer', 2000) then return end
    local citizenid = getPlayerCitizenId(src)
    if not citizenid then return end
    local gang = findGangByMember(citizenid)
    if not gang then notify(src, locale('error_no_gang'), 'error') return end

    local me = gang.members[citizenid]
    local myRank = getRankData(me.rank)
    if not myRank or not myRank.isLeader then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    if type(targetCitizenId) ~= 'string' or targetCitizenId == citizenid then return end
    local target = gang.members[targetCitizenId]
    if not target then
        notify(src, locale('error_target_not_in_gang'), 'error')
        return
    end

    local leaderRank = getRankData(Config.DefaultLeaderRank) or myRank
    local stepDown = rankByWeight[leaderRank.weight - 1]
    if not stepDown then
        notify(src, locale('error_rank_limit'), 'error')
        return
    end

    local ok = dbTransaction({
        { query = 'UPDATE rsg_gang_members SET rank = ? WHERE citizenid = ?', values = { leaderRank.name, targetCitizenId } },
        { query = 'UPDATE rsg_gang_members SET rank = ? WHERE citizenid = ?', values = { stepDown.name, citizenid } },
        { query = 'UPDATE rsg_gangs SET owner = ? WHERE name = ?', values = { targetCitizenId, gang.name } },
    })
    if not ok then
        notify(src, locale('error_generic'), 'error')
        return
    end

    target.rank = leaderRank.name
    me.rank = stepDown.name
    gang.owner = targetCitizenId

    notify(src, locale('success_leadership_transferred', target.name or targetCitizenId), 'success')
    if target.source then notify(target.source, locale('notify_now_leader', gang.label), 'inform') end
    logEvent('Gang leadership', ('%s handed %s to %s'):format(citizenid, gang.name, targetCitizenId))
    addLog(gang, citizenid, 'transfer', target.name or targetCitizenId)
    broadcastGangUpdate(gang)
end)

---------------------------------------------------------------------
-- Bank
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:depositMoney', function(amount)
    local src = source
    if onCooldown(src, 'bank', 1000) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local gang = findGangByMember(citizenid)
    if not gang then notify(src, locale('error_no_gang'), 'error') return end

    if not hasPermission(gang.members[citizenid].rank, 'deposit') then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    amount = parseAmount(amount)
    if not amount then
        notify(src, locale('error_invalid_amount'), 'error')
        return
    end

    if gang.bank + amount > Config.MaxBankBalance then
        notify(src, locale('error_bank_full'), 'error')
        return
    end

    if Player.Functions.GetMoney('cash') < amount then
        notify(src, locale('error_not_enough_money'), 'error')
        return
    end

    if Player.Functions.RemoveMoney('cash', amount, 'gang-deposit') == false then
        notify(src, locale('error_not_enough_money'), 'error')
        return
    end

    if not adjustBank(gang, amount) then
        Player.Functions.AddMoney('cash', amount, 'gang-deposit-refund')
        notify(src, locale('error_generic'), 'error')
        return
    end

    logEvent('Gang deposit', ('%s deposited $%s into %s'):format(citizenid, amount, gang.name))
    addLog(gang, citizenid, 'deposit', amount)
    notify(src, locale('success_deposit', amount), 'success')
    broadcastGangUpdate(gang)
end)

RegisterNetEvent('rsg-gangs:server:withdrawMoney', function(amount)
    local src = source
    if onCooldown(src, 'bank', 1000) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local gang = findGangByMember(citizenid)
    if not gang then notify(src, locale('error_no_gang'), 'error') return end

    if not hasPermission(gang.members[citizenid].rank, 'withdraw') then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    amount = parseAmount(amount)
    if not amount then
        notify(src, locale('error_invalid_amount'), 'error')
        return
    end

    if gang.bank < amount then
        notify(src, locale('error_insufficient_gang_funds'), 'error')
        return
    end

    if not adjustBank(gang, -amount) then
        notify(src, locale('error_generic'), 'error')
        return
    end

    if Player.Functions.AddMoney('cash', amount, 'gang-withdraw') == false then
        adjustBank(gang, amount)
        notify(src, locale('error_generic'), 'error')
        return
    end

    logEvent('Gang withdrawal', ('%s withdrew $%s from %s'):format(citizenid, amount, gang.name))
    addLog(gang, citizenid, 'withdraw', amount)
    notify(src, locale('success_withdraw', amount), 'success')
    broadcastGangUpdate(gang)
end)

---------------------------------------------------------------------
-- Rename / colour
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:renameGang', function(newLabel)
    local src = source
    if onCooldown(src, 'rename', 2000) then return end
    local citizenid = getPlayerCitizenId(src)
    if not citizenid then return end
    local gang = findGangByMember(citizenid)
    if not gang then notify(src, locale('error_no_gang'), 'error') return end

    if not hasPermission(gang.members[citizenid].rank, 'rename') then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    newLabel = cleanLabel(newLabel)
    if not newLabel then
        notify(src, locale('error_invalid_name', Config.MinNameLength, Config.MaxNameLength), 'error')
        return
    end

    if not dbOk('UPDATE rsg_gangs SET label = ? WHERE name = ?', { newLabel, gang.name }) then
        notify(src, locale('error_generic'), 'error')
        return
    end
    gang.label = newLabel
    addLog(gang, citizenid, 'rename', newLabel)

    notify(src, locale('success_renamed', newLabel), 'success')
    broadcastGangUpdate(gang)
end)

RegisterNetEvent('rsg-gangs:server:setColor', function(color)
    local src = source
    if onCooldown(src, 'color', 750) then return end
    local citizenid = getPlayerCitizenId(src)
    if not citizenid then return end
    local gang = findGangByMember(citizenid)
    if not gang then notify(src, locale('error_no_gang'), 'error') return end

    if not hasPermission(gang.members[citizenid].rank, 'setcolor') then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    local valid = false
    for _, c in ipairs(Config.GangColors) do
        if c == color then valid = true break end
    end
    if not valid then return end

    if not dbOk('UPDATE rsg_gangs SET color = ? WHERE name = ?', { color, gang.name }) then
        notify(src, locale('error_generic'), 'error')
        return
    end
    gang.color = color
    addLog(gang, citizenid, 'color')

    notify(src, locale('success_color_set'), 'success')
    broadcastGangUpdate(gang)
end)

---------------------------------------------------------------------
-- Online / offline tracking, so the member list's status dots stay current
---------------------------------------------------------------------
local function refreshGangLater(gang)
    SetTimeout(1500, function()
        if Gangs[gang.name] then broadcastGangUpdate(gang) end
    end)
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    if not Player or not Player.PlayerData then return end
    local gang = findGangByMember(Player.PlayerData.citizenid)
    if gang then refreshGangLater(gang) end
end)

local function memberWentOffline(src)
    cooldowns[src] = nil
    grants[src] = nil
    for _, gang in pairs(Gangs) do
        for _, member in pairs(gang.members) do
            if member.source == src then
                member.source = nil
                refreshGangLater(gang)
                return
            end
        end
    end
end

AddEventHandler('playerDropped', function()
    memberWentOffline(source)
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    if type(src) == 'number' then memberWentOffline(src) end
end)

-- Expired invites would otherwise sit in memory forever.
CreateThread(function()
    while true do
        Wait(60 * 1000)
        local now = os.time()
        for citizenid, invite in pairs(pendingInvites) do
            if invite.expires < now then pendingInvites[citizenid] = nil end
        end
    end
end)
