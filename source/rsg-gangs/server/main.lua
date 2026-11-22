local RSGCore = exports['rsg-core']:GetCoreObject()

---------------------------------------------------------------------
-- Shared internal API. The other server files (loaded after this one)
-- register their own functions on this table and call the helpers below.
---------------------------------------------------------------------
RSGGangs = {}

-- Gangs[name] = { name, members = { [citizenid] = { rank = "<level>", level, source|nil, name } },
--                 wagon = {x,y,z,heading}|nil, stashTier, stashId, upkeepDue, upkeepMissed,
--                 equipment = { [itemId] = { { id, x, y, z, heading }, ... } } }
-- label, color, tag, owner and bank are read from rsg-society whenever they are accessed (see gangMeta).
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
        `target_type` varchar(10) NOT NULL DEFAULT 'player',
        `target_id` varchar(50) DEFAULT NULL,
        `target_name` varchar(100) DEFAULT NULL,
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
    [[CREATE TABLE IF NOT EXISTS `rsg_gang_state` (
        `key` varchar(50) NOT NULL,
        `value` varchar(100) NOT NULL,
        PRIMARY KEY (`key`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

-- Columns added after 2.0.x: { table, column, definition }. Added only when missing.
local COLUMN_UPGRADES = {
    { 'rsg_gang_members', 'name', 'varchar(100) DEFAULT NULL AFTER `rank`' },
    { 'rsg_gangs', 'upkeep_due', 'int(11) DEFAULT NULL' },
    { 'rsg_gangs', 'upkeep_missed', 'int(11) NOT NULL DEFAULT 0' },
    { 'rsg_gangs', 'tag', 'varchar(8) DEFAULT NULL' },
    { 'rsg_gang_bounties', 'target_type', "varchar(10) NOT NULL DEFAULT 'player'" },
    { 'rsg_gang_bounties', 'target_id', 'varchar(50) DEFAULT NULL' },
    { 'rsg_gang_bounties', 'target_name', 'varchar(100) DEFAULT NULL' },
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
-- Ranks and permissions (owned by rsg-society)
---------------------------------------------------------------------
-- Every gang's ranks live in rsg-society as levels 0..n. A member's `rank` here is that level as a
-- string, which is also the rank `name` the NUI works with; its label is the rank name set in rsg-society.
-- rsg-gangs permission names -> rsg-society permission names.
local PERMISSION_MAP = {
    invite = 'hire', kick = 'fire', promote = 'promote', demote = 'promote',
    deposit = 'deposit', withdraw = 'withdraw', upgrade = 'upgrade', bounty = 'bounty',
    disband = 'disband', rename = 'settings', setcolor = 'settings', equipment = 'equipment',
}
local PERMISSION_ORDER = {
    'invite', 'kick', 'promote', 'demote', 'deposit', 'withdraw', 'upgrade', 'bounty', 'disband', 'rename', 'setcolor', 'equipment',
}

local rankCache = {} -- [gangName] = { t, list = { { level, name, boss } ... } }

local function ranksOf(gangName)
    local cached = rankCache[gangName]
    local now = GetGameTimer()
    if cached and now - cached.t < 3000 then return cached.list end
    local ok, list = pcall(function() return exports['rsg-society']:GetRanks(gangName) end)
    if ok and type(list) == 'table' then
        rankCache[gangName] = { t = now, list = list }
        return list
    end
    return cached and cached.list or {}
end

local function rankInfo(gangName, level)
    level = tonumber(level)
    for _, rank in ipairs(ranksOf(gangName)) do
        if rank.level == level then return rank end
    end
    return nil
end

-- Level of a member inside their gang (-1 when they are not a member)
local function rankWeight(gang, citizenid)
    local member = gang and gang.members[citizenid]
    return member and member.level or -1
end

local function isBossRank(gang, citizenid)
    local member = gang and gang.members[citizenid]
    local info = member and rankInfo(gang.name, member.level)
    return info ~= nil and info.boss == true
end

local function hasPermission(gang, citizenid, permission)
    if not gang or not gang.members[citizenid] then return false end
    local mapped = PERMISSION_MAP[permission] or permission
    local ok, res = pcall(function() return exports['rsg-society']:HasPermission(citizenid, gang.name, mapped) end)
    return ok and res == true
end

local function canViewLog(gang, citizenid)
    local cfg = Config.ActivityLog
    return cfg ~= nil and cfg.enabled == true and rankWeight(gang, citizenid) >= (cfg.minWeight or 0)
end

local function permissionList(gang, citizenid)
    local out = {}
    for _, perm in ipairs(PERMISSION_ORDER) do
        if hasPermission(gang, citizenid, perm) then out[#out + 1] = perm end
    end
    return out
end

-- Highest rank level, and the level just below it (leadership transfers use these)
local function topLevels(gangName)
    local top, below = nil, nil
    for _, rank in ipairs(ranksOf(gangName)) do
        if rank.boss and (not top or rank.level > top) then top = rank.level end
    end
    for _, rank in ipairs(ranksOf(gangName)) do
        if top and rank.level < top and (not below or rank.level > below) then below = rank.level end
    end
    return top, below
end

-- Turns a rank typed by an admin (a level number or a rank name) into a level for one gang
local function resolveLevel(gangName, value)
    if value == nil then return 0 end
    local number = tonumber(value)
    if number then
        number = math.floor(number)
        return rankInfo(gangName, number) and number or nil
    end
    local wanted = tostring(value):lower()
    for _, rank in ipairs(ranksOf(gangName)) do
        if tostring(rank.name):lower() == wanted then return rank.level end
    end
    return nil
end

---------------------------------------------------------------------
-- Config sanity check (prints warnings, never stops the resource)
---------------------------------------------------------------------
local function validateConfig()
    local function warn(msg) print(('^3[rsg-gangs] config: %s^7'):format(msg)) end

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
-- Loading (gang identity, members, ranks and bank come from rsg-society)
---------------------------------------------------------------------
-- label, colour, tag, owner and bank are never stored on the gang table: they are read from
-- rsg-society on demand (with a short cache), so a change made in its menu shows up here at once.
local liveCache = {} -- [gangName] = { t, info }
local LIVE_FIELDS = { label = true, color = true, tag = true, owner = true, bank = true }

local function societyInfo(gangName)
    local cached = liveCache[gangName]
    local now = GetGameTimer()
    if cached and now - cached.t < 1500 then return cached.info end
    local ok, info = pcall(function() return exports['rsg-society']:GetSociety(gangName) end)
    if ok and type(info) == 'table' then
        liveCache[gangName] = { t = now, info = info }
        return info
    end
    return cached and cached.info or nil
end

local function forgetLive(gangName)
    liveCache[gangName] = nil
    rankCache[gangName] = nil
end

local gangMeta = {
    __index = function(gang, key)
        if not LIVE_FIELDS[key] then return nil end
        local info = societyInfo(rawget(gang, 'name'))
        if not info then return key == 'bank' and 0 or nil end
        if key == 'bank' then return info.balance or 0 end
        return info[key]
    end,
    __newindex = function(gang, key, value)
        if LIVE_FIELDS[key] then return end -- owned by rsg-society, change it there
        rawset(gang, key, value)
    end,
}

-- Creates / refreshes the row that anchors this gang's own data (wagon, equipment, turf, bounties...).
local function ensureGangRow(name, info)
    local color = info.color
    if type(color) ~= 'string' or not color:match('^#%x%x%x%x%x%x$') then color = '#e63946' end
    local label = tostring(info.label or name):sub(1, 50)
    local owner = type(info.owner) == 'string' and info.owner ~= '' and info.owner or 'SYSTEM'
    return dbOk([[
        INSERT INTO rsg_gangs (name, label, color, owner, stash_id) VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), color = VALUES(color), owner = VALUES(owner)
    ]], { name, label, color, owner, generateUUID() })
end

-- Reads the members of one gang from rsg-society into memory
local function syncMembers(gang)
    for citizenid in pairs(gang.members) do
        if memberIndex[citizenid] == gang.name then memberIndex[citizenid] = nil end
    end
    gang.members = {}

    local ok, list = pcall(function() return exports['rsg-society']:GetMembers(gang.name) end)
    if not ok or type(list) ~= 'table' then return end
    for _, row in ipairs(list) do
        local member = { rank = tostring(row.level), level = row.level, source = nil, name = row.name }
        gang.members[row.citizenid] = member
        memberIndex[row.citizenid] = gang.name
    end
end

local loadingGang = {}

-- Builds the in-memory gang for one rsg-society gang (and its anchor row). Returns the gang or nil.
local function loadGang(name)
    if Gangs[name] then return Gangs[name] end
    while loadingGang[name] do Wait(50) end
    if Gangs[name] then return Gangs[name] end
    loadingGang[name] = true

    local gang
    local ok, err = pcall(function()
        forgetLive(name)
        local info = societyInfo(name)
        if not info or info.type ~= 'gang' then return end
        ensureGangRow(name, info)

        local row = MySQL.single.await('SELECT * FROM rsg_gangs WHERE name = ?', { name })
        if not row then return end
        local stashId = row.stash_id
        if not stashId or stashId == '' then
            stashId = generateUUID()
            dbOk('UPDATE rsg_gangs SET stash_id = ? WHERE name = ?', { stashId, name })
        end

        gang = setmetatable({
            name = name,
            members = {},
            equipment = {},
            wagon = row.wagon_x and {
                x = row.wagon_x, y = row.wagon_y, z = row.wagon_z, heading = row.wagon_heading or 0.0,
            } or nil,
            stashTier = row.stash_tier or 'small',
            stashId = stashId,
            upkeepDue = row.upkeep_due,
            upkeepMissed = row.upkeep_missed or 0,
        }, gangMeta)

        local equipmentRows = MySQL.query.await('SELECT * FROM rsg_gang_equipment WHERE gang_name = ?', { name }) or {}
        for _, eq in ipairs(equipmentRows) do
            gang.equipment[eq.item_id] = gang.equipment[eq.item_id] or {}
            table.insert(gang.equipment[eq.item_id], { id = eq.id, x = eq.x, y = eq.y, z = eq.z, heading = eq.heading })
        end
        syncMembers(gang)
        Gangs[name] = gang
    end)
    loadingGang[name] = nil
    if not ok then print(('^1[rsg-gangs] could not load gang "%s": %s^7'):format(name, tostring(err))) return nil end
    return gang
end

local function loadGangs()
    for key in pairs(Gangs) do Gangs[key] = nil end
    for key in pairs(memberIndex) do memberIndex[key] = nil end
    liveCache, rankCache = {}, {}

    local names = exports['rsg-society']:GetSocieties('gang') or {}
    local known = {}
    for _, name in ipairs(names) do
        known[name] = true
        loadGang(name)
    end

    -- rows from before the move to rsg-society that no society owns: keep them, but they stay inactive
    for _, row in ipairs(MySQL.query.await('SELECT name FROM rsg_gangs', {}) or {}) do
        if not known[row.name] then
            print(('^3[rsg-gangs] gang "%s" has no rsg-society account and is inactive. Start rsg-society with Config.Migration.ImportRsgGangs on (or run its migration command) to bring it over.^7'):format(row.name))
        end
    end

    RSGGangs.Loaded = true
end

local function societyReady()
    if GetResourceState('rsg-society') ~= 'started' then return false end
    local ok, ready = pcall(function() return exports['rsg-society']:IsReady() end)
    return ok and ready == true
end

local function startUp()
    local ok, err = pcall(loadGangs)
    if not ok then
        print(('^1[rsg-gangs] failed to load gangs: %s^7'):format(tostring(err)))
        print('^1[rsg-gangs] Are the database tables installed? (Config.AutoDatabase or installation/rsg-gangs.sql)^7')
    end
end

CreateThread(function()
    validateConfig()
    if Config.AutoDatabase and not ensureDatabase() then return end

    local waited = 0
    while not societyReady() do
        Wait(500)
        waited = waited + 500
        if waited == 30000 then
            print('^3[rsg-gangs] still waiting for rsg-society. Is it installed and started before rsg-gangs?^7')
        end
    end
    startUp()
end)

-- rsg-society was restarted: read everything again
AddEventHandler('rsg-society:server:ready', function()
    if RSGGangs.Loaded then startUp() end
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
            if name ~= '' and (not member.name or member.name == '') then member.name = name end
        else
            member.source = nil
        end
    end
end

local function buildGangPayload(gang)
    refreshMemberOnlineData(gang)

    local ranks = {}
    local labelOf = {}
    for _, rank in ipairs(ranksOf(gang.name)) do
        ranks[#ranks + 1] = { name = tostring(rank.level), label = rank.name, weight = rank.level, isLeader = rank.boss == true }
        labelOf[rank.level] = rank.name
    end

    local members = {}
    for citizenid, data in pairs(gang.members) do
        members[#members + 1] = {
            citizenid = citizenid,
            name = data.name or citizenid,
            rank = tostring(data.level),
            rankLabel = labelOf[data.level] or tostring(data.level),
            weight = data.level,
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
        ranks = ranks,
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

-- `payload` lets broadcastGangUpdate build the (expensive) gang payload once for every member.
local function buildState(citizenid, gang, payload)
    local member = gang and gang.members[citizenid]
    return {
        citizenid = citizenid,
        inGang = gang ~= nil,
        gang = gang and (payload or buildGangPayload(gang)) or nil,
        myRank = member and tostring(member.level) or nil,
        myPermissions = member and permissionList(gang, citizenid) or {},
        canViewLog = member and canViewLog(gang, citizenid) or false,
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
            TriggerClientEvent('rsg-gangs:client:setState', member.source, buildState(citizenid, gang, payload))
        end
    end
end

---------------------------------------------------------------------
-- Creating and destroying gangs, bank changes (all through rsg-society)
---------------------------------------------------------------------
-- Bank changes go to rsg-society, which keeps the balance and the ledger. `delta` is in dollars.
local function adjustBank(gang, delta)
    if type(delta) ~= 'number' or delta ~= delta then return false end
    if delta == 0 then return true end
    if delta > 0 and (gang.bank or 0) + delta > Config.MaxBankBalance then return false end

    local ok, res = pcall(function()
        if delta > 0 then return exports['rsg-society']:AddMoney(gang.name, delta, 'rsg-gangs') end
        return exports['rsg-society']:RemoveMoney(gang.name, -delta, 'rsg-gangs')
    end)
    liveCache[gang.name] = nil
    return ok and res ~= nil and res ~= false
end

-- Maps an rsg-society failure key to a message the player can read
local function notifyFail(src, reason)
    if reason == 'sv_err_gang_taken' then return notify(src, locale('error_gang_exists'), 'error') end
    if reason == 'sv_err_gang_name' then
        return notify(src, locale('error_invalid_name', Config.MinNameLength, Config.MaxNameLength), 'error')
    end
    notify(src, locale('error_generic'), 'error')
end

-- Creates the gang in rsg-society (founder becomes its top rank) and loads it here.
-- Returns the gang, or nil and the rsg-society reason key.
local function createGangRecord(label, color, ownerCid)
    local called, created, nameOrReason = pcall(function() return exports['rsg-society']:CreateGang(label, ownerCid) end)
    if not called or not created then return nil, called and nameOrReason or 'sv_err_unknown' end

    local gang = loadGang(nameOrReason)
    if not gang then return nil, 'sv_err_unknown' end
    if type(color) == 'string' then
        pcall(function() exports['rsg-society']:SetGangInfo(gang.name, { color = color }) end)
        forgetLive(gang.name)
    end
    return gang
end

local disbandNotice = {} -- [gangName] = { key, type } for the notice members get when the gang goes

-- Clears everything rsg-gangs owns for a gang that rsg-society has removed (safe to call twice)
local function cleanupGang(gang, memberIds)
    if rawget(gang, 'destroyed') then return end
    rawset(gang, 'destroyed', true)

    local notice = disbandNotice[gang.name]
    disbandNotice[gang.name] = nil
    local key = 'success_gang_disbanded'
    local nType = 'inform'
    if notice then key, nType = notice.key, notice.type or 'inform' end

    local ids = {}
    for citizenid in pairs(gang.members) do ids[citizenid] = true end
    for _, citizenid in ipairs(memberIds or {}) do ids[citizenid] = true end
    for citizenid in pairs(ids) do
        local Player = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
        if Player then
            local target = Player.PlayerData.source
            if key then notify(target, locale(key), nType) end
            TriggerClientEvent('rsg-gangs:client:setState', target, { inGang = false })
        end
        if memberIndex[citizenid] == gang.name then memberIndex[citizenid] = nil end
    end

    if RSGGangs.DeleteGangWagon then RSGGangs.DeleteGangWagon(gang.name) end
    if RSGGangs.DeleteAllGangEquipment then RSGGangs.DeleteAllGangEquipment(gang.name) end
    if RSGGangs.OnGangDestroyed then RSGGangs.OnGangDestroyed(gang) end

    for citizenid, invite in pairs(pendingInvites) do
        if invite.gangName == gang.name then pendingInvites[citizenid] = nil end
    end

    dbOk('DELETE FROM rsg_gangs WHERE name = ?', { gang.name }) -- equipment, turf, bounties, logs cascade
    Gangs[gang.name] = nil
    forgetLive(gang.name)
end

-- Disbands the gang in rsg-society, then removes the world entities and rows here.
-- Returns true and the balance (dollars) that was in the gang account; the caller decides who gets it.
local function destroyGang(gang, notifyKey, notifyType)
    local memberIds = {}
    for citizenid in pairs(gang.members) do memberIds[#memberIds + 1] = citizenid end

    disbandNotice[gang.name] = { key = notifyKey or false, type = notifyType }
    local ok, done, balance = pcall(function() return exports['rsg-society']:DisbandGang(gang.name) end)
    if not ok or not done then
        disbandNotice[gang.name] = nil
        return false
    end
    cleanupGang(gang, memberIds)
    return true, tonumber(balance) or 0
end

-- Adds an online player to a gang at a rank level. Returns true on success.
local function insertMember(gang, Player, level)
    local citizenid = Player.PlayerData.citizenid
    if findGangByMember(citizenid) or pendingMembershipChange[citizenid] then return false end

    pendingMembershipChange[citizenid] = true
    local ok, res = pcall(function() return exports['rsg-society']:AddMember(gang.name, citizenid, level or 0) end)
    pendingMembershipChange[citizenid] = nil

    if not ok or not res then return false end
    pendingInvites[citizenid] = nil
    syncMembers(gang)
    return true
end

-- Removes a member through rsg-society and updates memory. Returns true on success.
local function removeMemberViaSociety(gang, citizenid)
    local ok, res = pcall(function() return exports['rsg-society']:RemoveMember(gang.name, citizenid) end)
    if not ok or not res then return false end
    removeMember(gang, citizenid)
    return true
end

---------------------------------------------------------------------
-- Internal API for the other server files
---------------------------------------------------------------------
RSGGangs.RankInfo = rankInfo
RSGGangs.Ranks = ranksOf
RSGGangs.ResolveLevel = resolveLevel
RSGGangs.TopLevels = topLevels
RSGGangs.IsBossRank = isBossRank
RSGGangs.LoadGang = loadGang
RSGGangs.SyncMembers = syncMembers
RSGGangs.ForgetLive = forgetLive
RSGGangs.NotifyFail = notifyFail
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
RSGGangs.DbTransaction = dbTransaction
RSGGangs.RemoveMember = removeMemberViaSociety
RSGGangs.MemberCount = memberCount

---------------------------------------------------------------------
-- Exports for other resources
---------------------------------------------------------------------
exports('GetPlayerGang', function(citizenid)
    local gang = findGangByMember(citizenid)
    if not gang then return nil end
    local member = gang.members[citizenid]
    local info = rankInfo(gang.name, member.level)
    return {
        name = gang.name,
        label = gang.label,
        color = gang.color,
        rank = info and info.name or tostring(member.level),
        level = member.level,
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
    return isBossRank(gang, citizenid)
end)

exports('HasGangPermission', function(citizenid, permission)
    local gang = findGangByMember(citizenid)
    if not gang then return false end
    return hasPermission(gang, citizenid, permission)
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
    if not label then
        notify(src, locale('error_invalid_name', Config.MinNameLength, Config.MaxNameLength), 'error')
        return
    end

    local cost = Config.CreateGangCost
    if cost > 0 and Player.Functions.GetMoney('cash') < cost then
        notify(src, locale('error_not_enough_money'), 'error')
        return
    end

    pendingMembershipChange[citizenid] = true
    if cost > 0 and Player.Functions.RemoveMoney('cash', cost, 'gang-creation') == false then
        pendingMembershipChange[citizenid] = nil
        notify(src, locale('error_not_enough_money'), 'error')
        return
    end

    local color = Config.GangColors[math.random(#Config.GangColors)]
    local gang, reason = createGangRecord(label, color, citizenid)
    pendingMembershipChange[citizenid] = nil

    if not gang then
        if cost > 0 then Player.Functions.AddMoney('cash', cost, 'gang-creation-refund') end
        notifyFail(src, reason)
        return
    end

    notify(src, locale('success_gang_created', gang.label or label), 'success')
    logEvent('Gang created', ('%s (%s) founded by %s'):format(gang.label or label, gang.name, citizenid))
    addLog(gang, citizenid, 'created')
    broadcastGangUpdate(gang)

    if Config.GangVehicle.enabled then
        grant(src, 'spot:' .. gang.name, 90)
        grant(src, 'wagon:' .. gang.name, 150)
        TriggerClientEvent('rsg-gangs:client:findGangVehicleSpot', src, gang.name)

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
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local gang = findGangByMember(citizenid)
    if not gang then notify(src, locale('error_no_gang'), 'error') return end

    if not hasPermission(gang, citizenid, 'disband') then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    local name, label = gang.name, gang.label
    local ok, balance = destroyGang(gang, 'success_gang_disbanded', 'inform')
    if not ok then
        notify(src, locale('error_generic'), 'error')
        return
    end
    -- what was left in the gang account goes to whoever disbanded it, like rsg-society's own menu does
    if balance > 0 then Player.Functions.AddMoney('cash', balance, 'gang-disband') end
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

    if not hasPermission(gang, citizenid, 'invite') then
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

    if not insertMember(gang, Player, 0) then -- level 0 = lowest rank
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

    if not hasPermission(gang, citizenid, 'kick') then
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

    if rankWeight(gang, targetCitizenId) >= rankWeight(gang, citizenid) then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    local targetName, targetSource = target.name or targetCitizenId, target.source
    if not removeMemberViaSociety(gang, targetCitizenId) then
        notify(src, locale('error_generic'), 'error')
        return
    end

    notify(src, locale('success_kicked_member', targetName), 'success')
    if targetSource then
        notify(targetSource, locale('success_kicked'), 'inform')
        TriggerClientEvent('rsg-gangs:client:setState', targetSource, { inGang = false })
    end
    logEvent('Gang kick', ('%s kicked %s from %s'):format(citizenid, targetCitizenId, gang.name))
    addLog(gang, citizenid, 'kick', targetName)
    broadcastGangUpdate(gang)
end)

RegisterNetEvent('rsg-gangs:server:leaveGang', function()
    local src = source
    if onCooldown(src, 'leave', 2000) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local gang = findGangByMember(citizenid)
    if not gang then notify(src, locale('error_no_gang'), 'error') return end

    local others = memberCount(gang) - 1

    if isBossRank(gang, citizenid) and others > 0 then
        notify(src, locale('error_leader_cannot_leave'), 'error')
        return
    end

    -- Last member out: the gang is removed completely (wagon, camp equipment, rows).
    if others == 0 then
        local label, name = gang.label, gang.name
        local ok, balance = destroyGang(gang)
        if not ok then
            notify(src, locale('error_generic'), 'error')
            return
        end
        if balance > 0 then Player.Functions.AddMoney('cash', balance, 'gang-disband') end
        notify(src, locale('success_left_gang'), 'success')
        TriggerClientEvent('rsg-gangs:client:setState', src, { inGang = false })
        logEvent('Gang disbanded', ('%s (%s) removed: last member left'):format(label, name))
        return
    end

    local leaverName = gang.members[citizenid] and gang.members[citizenid].name or citizenid
    if not removeMemberViaSociety(gang, citizenid) then
        notify(src, locale('error_generic'), 'error')
        return
    end
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

    if not hasPermission(gang, citizenid, direction == 1 and 'promote' or 'demote') then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    if type(targetCitizenId) ~= 'string' or targetCitizenId == citizenid then return end
    local target = gang.members[targetCitizenId]
    if not target then
        notify(src, locale('error_target_not_in_gang'), 'error')
        return
    end

    local myWeight = rankWeight(gang, citizenid)
    local targetWeight = rankWeight(gang, targetCitizenId)

    if targetWeight >= myWeight then
        notify(src, locale('error_rank_too_high'), 'error')
        return
    end

    local targetInfo = rankInfo(gang.name, targetWeight)
    if direction == -1 and targetInfo and targetInfo.boss then
        notify(src, locale('error_cannot_demote_leader'), 'error')
        return
    end

    local newInfo = rankInfo(gang.name, targetWeight + direction)
    if not newInfo then
        notify(src, locale('error_rank_limit'), 'error')
        return
    end
    if newInfo.level >= myWeight then
        notify(src, locale('error_rank_too_high'), 'error')
        return
    end

    local ok, res = pcall(function() return exports['rsg-society']:SetMemberLevel(gang.name, targetCitizenId, newInfo.level) end)
    if not ok or not res then
        notify(src, locale('error_generic'), 'error')
        return
    end
    syncMembers(gang)

    local targetName = target.name or targetCitizenId
    addLog(gang, citizenid, direction == 1 and 'promote' or 'demote', targetName, newInfo.name)
    local key = direction == 1 and 'success_promoted' or 'success_demoted'
    notify(src, locale(key, targetName, newInfo.name), 'success')
    if target.source then
        notify(target.source, locale(key, targetName, newInfo.name), 'inform')
    end
    broadcastGangUpdate(gang)
end

RegisterNetEvent('rsg-gangs:server:promoteMember', function(targetCitizenId)
    changeRank(source, targetCitizenId, 1)
end)

RegisterNetEvent('rsg-gangs:server:demoteMember', function(targetCitizenId)
    changeRank(source, targetCitizenId, -1)
end)

-- Makes `targetCitizenId` the boss rank and steps `fromCitizenId` (when given) one rank down.
-- Shared by the player menu and the admin panel. Returns true on success.
local function handOverLeadership(gang, targetCitizenId, fromCitizenId)
    local top, below = topLevels(gang.name)
    if not top or not below then return false, 'error_rank_limit' end

    local ok, res = pcall(function() return exports['rsg-society']:SetMemberLevel(gang.name, targetCitizenId, top) end)
    if not ok or not res then return false, 'error_generic' end
    if fromCitizenId and fromCitizenId ~= targetCitizenId then
        pcall(function() exports['rsg-society']:SetMemberLevel(gang.name, fromCitizenId, below) end)
    end
    pcall(function() exports['rsg-society']:SetGangOwner(gang.name, targetCitizenId) end)
    forgetLive(gang.name)
    syncMembers(gang)
    return true
end
RSGGangs.HandOverLeadership = handOverLeadership

RegisterNetEvent('rsg-gangs:server:transferLeadership', function(targetCitizenId)
    local src = source
    if onCooldown(src, 'transfer', 2000) then return end
    local citizenid = getPlayerCitizenId(src)
    if not citizenid then return end
    local gang = findGangByMember(citizenid)
    if not gang then notify(src, locale('error_no_gang'), 'error') return end

    if not isBossRank(gang, citizenid) then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    if type(targetCitizenId) ~= 'string' or targetCitizenId == citizenid then return end
    local target = gang.members[targetCitizenId]
    if not target then
        notify(src, locale('error_target_not_in_gang'), 'error')
        return
    end

    local targetName, targetSource = target.name or targetCitizenId, target.source
    local ok, errKey = handOverLeadership(gang, targetCitizenId, citizenid)
    if not ok then
        notify(src, locale(errKey), 'error')
        return
    end

    notify(src, locale('success_leadership_transferred', targetName), 'success')
    if targetSource then notify(targetSource, locale('notify_now_leader', gang.label), 'inform') end
    logEvent('Gang leadership', ('%s handed %s to %s'):format(citizenid, gang.name, targetCitizenId))
    addLog(gang, citizenid, 'transfer', targetName)
    broadcastGangUpdate(gang)
end)

---------------------------------------------------------------------
-- Bank (the account lives in rsg-society)
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:depositMoney', function(amount)
    local src = source
    if onCooldown(src, 'bank', 1000) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local gang = findGangByMember(citizenid)
    if not gang then notify(src, locale('error_no_gang'), 'error') return end

    if not hasPermission(gang, citizenid, 'deposit') then
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

    if not hasPermission(gang, citizenid, 'withdraw') then
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
-- Rename / colour (stored in rsg-society)
---------------------------------------------------------------------
-- Changes label, colour and/or tag through rsg-society. Returns true, or false and the failure key.
local function setGangInfo(gang, data)
    local ok, res, reason = pcall(function() return exports['rsg-society']:SetGangInfo(gang.name, data) end)
    forgetLive(gang.name)
    if not ok then return false, 'sv_err_unknown' end
    if not res then return false, reason end
    return true
end
RSGGangs.SetGangInfo = setGangInfo

RegisterNetEvent('rsg-gangs:server:renameGang', function(newLabel)
    local src = source
    if onCooldown(src, 'rename', 2000) then return end
    local citizenid = getPlayerCitizenId(src)
    if not citizenid then return end
    local gang = findGangByMember(citizenid)
    if not gang then notify(src, locale('error_no_gang'), 'error') return end

    if not hasPermission(gang, citizenid, 'rename') then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    newLabel = cleanLabel(newLabel)
    if not newLabel then
        notify(src, locale('error_invalid_name', Config.MinNameLength, Config.MaxNameLength), 'error')
        return
    end

    local ok, reason = setGangInfo(gang, { label = newLabel })
    if not ok then notifyFail(src, reason) return end
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

    if not hasPermission(gang, citizenid, 'setcolor') then
        notify(src, locale('error_no_permission'), 'error')
        return
    end

    local valid = false
    for _, c in ipairs(Config.GangColors) do
        if c == color then valid = true break end
    end
    if not valid then return end

    local ok, reason = setGangInfo(gang, { color = color })
    if not ok then notifyFail(src, reason) return end
    addLog(gang, citizenid, 'color')

    notify(src, locale('success_color_set'), 'success')
    broadcastGangUpdate(gang)
end)

---------------------------------------------------------------------
-- Changes made in rsg-society's own menu reach this resource through its events
---------------------------------------------------------------------
local broadcastPending = {}
local function scheduleBroadcast(name)
    if broadcastPending[name] then return end
    broadcastPending[name] = true
    SetTimeout(300, function()
        broadcastPending[name] = nil
        local gang = Gangs[name]
        if gang and not rawget(gang, 'destroyed') then broadcastGangUpdate(gang) end
    end)
end

AddEventHandler('rsg-society:server:memberJoined', function(name)
    local gang = Gangs[name]
    if not gang then return end
    syncMembers(gang)
    scheduleBroadcast(name)
end)

AddEventHandler('rsg-society:server:memberLeft', function(name, citizenid)
    local gang = Gangs[name]
    if not gang then return end
    syncMembers(gang)
    scheduleBroadcast(name)
    local Player = type(citizenid) == 'string' and RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if Player and not findGangByMember(citizenid) then
        TriggerClientEvent('rsg-gangs:client:setState', Player.PlayerData.source, { inGang = false })
    end
end)

AddEventHandler('rsg-society:server:rankChanged', function(name)
    local gang = Gangs[name]
    if not gang then return end
    forgetLive(name)
    syncMembers(gang)
    scheduleBroadcast(name)
end)

AddEventHandler('rsg-society:server:gangCreated', function(name)
    CreateThread(function()
        local gang = loadGang(name)
        if gang then scheduleBroadcast(name) end
    end)
end)

AddEventHandler('rsg-society:server:gangDisbanded', function(name, memberIds)
    local gang = Gangs[name]
    if not gang then return end
    CreateThread(function() cleanupGang(gang, memberIds) end)
end)

AddEventHandler('rsg-society:server:gangUpdated', function(name)
    local gang = Gangs[name]
    if not gang then return end
    forgetLive(name)
    local info = societyInfo(name)
    if info then ensureGangRow(name, info) end
    syncMembers(gang)
    scheduleBroadcast(name)
    if RSGGangs.PushTerritories then RSGGangs.PushTerritories() end
end)

AddEventHandler('rsg-society:server:balanceChanged', function(name)
    if not Gangs[name] then return end
    liveCache[name] = nil
    scheduleBroadcast(name)
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
