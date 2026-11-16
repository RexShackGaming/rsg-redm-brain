local RSGCore = exports['rsg-core']:GetCoreObject()

---------------------------------------------------------------------
-- Constants / state
---------------------------------------------------------------------
local EARN_INTERVAL = 60000            -- server-side earn tick (ms); one tick = PointsPerMinute
local LEADERBOARD_CACHE_MS = 30000     -- leaderboard DB results are shared by everyone for 30s
local MAX_POINTS_VALUE = 2000000000    -- keeps INT columns from overflowing
local HISTORY_PRUNE_MS = 6 * 3600 * 1000
local PERIOD_SECONDS = { day = 86400, week = 604800, month = 2592000 }
local DEFAULT_TIER = { key = 'none', label = 'tier_bronze', minLifetime = 0, discount = 0, earnMultiplier = 1.0 }

local dbReady = false

local COOLDOWN_MS = {
    redeem      = 2000,
    store       = 1500,
    data        = 2000,
    leaderboard = 5000,
    history     = 3000,
    admin       = 1000,
}
local cooldowns = {}
for kind in pairs(COOLDOWN_MS) do cooldowns[kind] = {} end

-- [src] = { citizenid, earned, eligibleAt, lastPos, maxNotified, tierIdx, balance, activityLast }
local sessions = {}

local leaderboardCache = {}
local redeemLocks = {}                  -- [rewardId] = true while stock/limit is being checked
local boost = { multiplier = 1.0, endsAt = 0 }

local ENABLED = Config.Enabled ~= false
if not ENABLED then
    print('^3[rsg-loyalty]^7 Loyalty system is disabled (Config.Enabled = false).')
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function onCooldown(kind, src)
    local now = GetGameTimer()
    local last = cooldowns[kind][src]
    if last and (now - last) < COOLDOWN_MS[kind] then
        return true
    end
    cooldowns[kind][src] = now
    return false
end

local function notify(src, description, nType)
    if src == 0 then
        print(('[rsg-loyalty] %s'):format(description))
        return
    end
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('loyalty_title'),
        description = description,
        type = nType or 'inform',
        duration = Config.UI.NotificationDuration or 5000,
    })
end

local function broadcast(key, ...)
    for src in pairs(sessions) do
        notify(src, locale(key, ...), 'inform')
    end
end

local function active()
    return ENABLED and dbReady
end

-- charname column is VARCHAR(50): cut by characters (not bytes) so UTF-8 names stay valid
local function getCharName(Player)
    local info = Player.PlayerData.charinfo
    local name = ('%s %s'):format(info.firstname, info.lastname)
    local len = utf8.len(name)
    if len and len > 50 then
        name = name:sub(1, utf8.offset(name, 51) - 1)
    end
    return name
end

-- positive whole number no larger than max, or nil
local function sanitizePoints(value, max)
    value = math.tointeger(tonumber(value))
    if not value or value <= 0 or (max and value > max) then return nil end
    return value
end

local function isAdmin(src)
    return src == 0 or RSGCore.Functions.HasPermission(src, 'admin')
end

-- server-side check that the player is standing at a loyalty NPC
local function isNearLoyaltyNpc(src)
    if Config.UI.EnableCommand then return true end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local maxDist = Config.Loyalty.MaxRedeemDistance or 5.0
    for _, loc in ipairs(Config.LoyaltyLocations) do
        if #(pos - loc.npccoords.xyz) <= maxDist then return true end
    end
    return false
end

---------------------------------------------------------------------
-- Tiers and boost
---------------------------------------------------------------------
-- Config.Tiers must be sorted by minLifetime (lowest first)
local function getTier(lifetime)
    local tiers = Config.Tiers
    if type(tiers) ~= 'table' or #tiers == 0 then return 1, DEFAULT_TIER end
    local idx = 1
    for i, t in ipairs(tiers) do
        if lifetime >= t.minLifetime then idx = i end
    end
    return idx, tiers[idx]
end

local function tierIndexByKey(key)
    for i, t in ipairs(Config.Tiers or {}) do
        if t.key == key then return i end
    end
end

local function boostMultiplier()
    if boost.endsAt > 0 and os.time() < boost.endsAt then return boost.multiplier end
    return 1.0
end

local function boostInfo()
    local m = boostMultiplier()
    if m <= 1.0 then return nil end
    return { multiplier = m, remaining = boost.endsAt - os.time() }
end

local function setBoost(multiplier, minutes)
    local cfg = Config.Boost or {}
    multiplier = math.max(1.0, math.min(tonumber(multiplier) or 1.0, cfg.MaxMultiplier or 5.0))
    minutes = math.max(1, math.min(math.tointeger(tonumber(minutes)) or 1, cfg.MaxMinutes or 240))
    boost.multiplier = multiplier
    boost.endsAt = os.time() + minutes * 60
    broadcast('boost_started', multiplier, minutes)
    return multiplier, minutes
end

local function clearBoost()
    local wasActive = boost.endsAt > 0
    boost.multiplier, boost.endsAt = 1.0, 0
    if wasActive then broadcast('boost_ended') end
end

---------------------------------------------------------------------
-- Rewards
---------------------------------------------------------------------
-- cost after the tier discount (always at least 1)
local function finalCost(reward, tier)
    local discount = math.min(100, math.max(0, (tier and tier.discount) or 0))
    return math.max(1, math.ceil(math.floor(reward.points) * (100 - discount) / 100 - 0.0001))
end

-- returns 'tier' / 'job' when the player may not redeem this reward, nil when fine
local function checkRequirements(Player, reward, tierIdx)
    if reward.minTier then
        local need = tierIndexByKey(reward.minTier)
        if need and tierIdx < need then return 'tier' end
    end
    if type(reward.jobs) == 'table' and #reward.jobs > 0 then
        local job = Player.PlayerData.job and Player.PlayerData.job.name
        for _, allowed in ipairs(reward.jobs) do
            if allowed == job then return nil end
        end
        return 'job'
    end
    return nil
end

-- Specials: entries with rotating = true share Config.Rotation.Count slots that
-- change every Period. The pick is seeded by the period number, so it is the
-- same for every player and survives restarts without being stored.
local activeSpecialCache = { slot = nil, set = {} }

local function activeSpecials()
    local rot = Config.Rotation or {}
    local seconds = (rot.Period == 'day') and 86400 or 604800
    local now = os.time()
    local slot = now // seconds
    local endsIn = (slot + 1) * seconds - now

    if activeSpecialCache.slot ~= slot then
        local set, pool = {}, {}
        for i, reward in ipairs(Config.SpecialRewards or {}) do
            if reward.rotating then pool[#pool + 1] = i else set[i] = true end
        end
        local count = math.min(rot.Count or #pool, #pool)
        local seed = slot % 2147483648
        local function rnd(n)
            seed = (seed * 1103515245 + 12345) % 2147483648
            return (seed % n) + 1
        end
        for i = #pool, 2, -1 do
            local j = rnd(i)
            pool[i], pool[j] = pool[j], pool[i]
        end
        for i = 1, count do set[pool[i]] = true end
        activeSpecialCache = { slot = slot, set = set }
    end
    return activeSpecialCache.set, endsIn
end

-- returns reward, kind ('cash' | 'item' | 'custom'), stable id
local function resolveReward(rewardType, index)
    index = math.tointeger(tonumber(index))
    local list = (rewardType == 'cash' and Config.CashRewards)
        or (rewardType == 'item' and Config.ItemRewards)
        or (rewardType == 'special' and Config.SpecialRewards)
    local reward = list and index and list[index]
    if not reward then return nil end
    if rewardType == 'special' and not activeSpecials()[index] then return nil end
    local kind = rewardType == 'special' and (reward.type or 'item') or rewardType
    return reward, kind, reward.id or (rewardType .. '_' .. index)
end

---------------------------------------------------------------------
-- Database
---------------------------------------------------------------------
-- keep identical to installation/rsg_loyalty.sql
local function ensureColumn(tbl, col, definition)
    local exists = MySQL.scalar.await(
        'SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
        { tbl, col }
    )
    if (exists or 0) == 0 then
        MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tbl, col, definition))
    end
end

local function ensureDatabase()
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `rsg_loyalty` (
                `id` INT NOT NULL AUTO_INCREMENT,
                `citizenid` VARCHAR(50) NOT NULL,
                `charname` VARCHAR(50) NOT NULL,
                `loyalty_points` INT NOT NULL DEFAULT 0,
                `lifetime_points` INT NOT NULL DEFAULT 0,
                `daily_streak` INT NOT NULL DEFAULT 0,
                `last_daily` DATE NULL,
                `last_update` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                UNIQUE KEY `citizenid` (`citizenid`),
                KEY `loyalty_points_idx` (`loyalty_points`),
                KEY `lifetime_points_idx` (`lifetime_points`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `rsg_loyalty_history` (
                `id` BIGINT NOT NULL AUTO_INCREMENT,
                `citizenid` VARCHAR(50) NOT NULL,
                `amount` INT NOT NULL,
                `reason` VARCHAR(32) NOT NULL,
                `detail` VARCHAR(100) NULL,
                `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                KEY `citizen_idx` (`citizenid`, `id`),
                KEY `created_idx` (`created`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `rsg_loyalty_redemptions` (
                `id` BIGINT NOT NULL AUTO_INCREMENT,
                `citizenid` VARCHAR(50) NOT NULL,
                `reward_id` VARCHAR(64) NOT NULL,
                `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                KEY `reward_idx` (`reward_id`, `created`),
                KEY `citizen_reward_idx` (`citizenid`, `reward_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
        -- upgrades from 3.0.x
        ensureColumn('rsg_loyalty', 'daily_streak', 'INT NOT NULL DEFAULT 0')
        ensureColumn('rsg_loyalty', 'last_daily', 'DATE NULL')
    end)
    if not ok then
        print(('^1[rsg-loyalty]^7 Failed to create loyalty tables: %s'):format(tostring(err)))
        return false
    end
    print('^2[rsg-loyalty]^7 Database tables are ready.')
    return true
end

local function pruneHistory()
    local days = math.max(1, (Config.History and Config.History.KeepDays) or 30)
    MySQL.query('DELETE FROM `rsg_loyalty_history` WHERE `created` < NOW() - INTERVAL ? DAY', { days })
end

CreateThread(function()
    if not ENABLED then return end
    while GetResourceState('oxmysql') ~= 'started' do Wait(100) end
    if Config.AutoDatabase ~= false and not ensureDatabase() then return end
    dbReady = true
    while true do
        pruneHistory()
        Wait(HISTORY_PRUNE_MS)
    end
end)

-- lets a client that reconnects during a resource restart wait for the tables
local function waitForDatabase()
    local waited = 0
    while not dbReady and waited < 10000 do
        Wait(100)
        waited = waited + 100
    end
    return dbReady
end

local function getLoyalty(citizenid)
    return MySQL.single.await('SELECT loyalty_points, lifetime_points, daily_streak FROM `rsg_loyalty` WHERE citizenid = ?', { citizenid })
end

-- create the row if missing and keep the character name current
local function ensureLoyalty(citizenid, charname)
    MySQL.insert.await(
        'INSERT INTO `rsg_loyalty` (citizenid, charname) VALUES (?, ?) ON DUPLICATE KEY UPDATE charname = ?',
        { citizenid, charname, charname }
    )
    return getLoyalty(citizenid)
end

local function addPoints(citizenid, points)
    local changed = MySQL.update.await(
        'UPDATE `rsg_loyalty` SET loyalty_points = loyalty_points + ?, lifetime_points = lifetime_points + ? WHERE citizenid = ?',
        { points, points, citizenid }
    )
    return (changed or 0) > 0
end

-- give spent points back without inflating lifetime points
local function refundPoints(citizenid, points)
    MySQL.update.await('UPDATE `rsg_loyalty` SET loyalty_points = loyalty_points + ? WHERE citizenid = ?', { points, citizenid })
end

-- atomic: only succeeds if the player has enough points
local function removePoints(citizenid, points)
    local changed = MySQL.update.await(
        'UPDATE `rsg_loyalty` SET loyalty_points = loyalty_points - ? WHERE citizenid = ? AND loyalty_points >= ?',
        { points, citizenid, points }
    )
    return (changed or 0) > 0
end

local function logHistory(citizenid, amount, reason, detail)
    MySQL.insert(
        'INSERT INTO `rsg_loyalty_history` (citizenid, amount, reason, detail) VALUES (?, ?, ?, ?)',
        { citizenid, amount, reason, detail and tostring(detail):sub(1, 100) or nil }
    )
end

-- how often a reward was redeemed (everyone, and this player) inside its period
local function countRedemptions(rewardId, citizenid, period)
    local seconds = PERIOD_SECONDS[period]
    local row
    if seconds then
        row = MySQL.single.await(
            'SELECT COUNT(*) AS total, COALESCE(SUM(citizenid = ?), 0) AS mine FROM `rsg_loyalty_redemptions` WHERE reward_id = ? AND created >= NOW() - INTERVAL ? SECOND',
            { citizenid, rewardId, seconds }
        )
    else
        row = MySQL.single.await(
            'SELECT COUNT(*) AS total, COALESCE(SUM(citizenid = ?), 0) AS mine FROM `rsg_loyalty_redemptions` WHERE reward_id = ?',
            { citizenid, rewardId }
        )
    end
    if not row then return 0, 0 end
    return tonumber(row.total) or 0, tonumber(row.mine) or 0
end

local LEADERBOARD_COLUMNS = { loyalty_points = true, lifetime_points = true }

-- global so server/discord.lua can use it
function GetLoyaltyLeaderboard(column)
    if not LEADERBOARD_COLUMNS[column] then return {} end
    local cached = leaderboardCache[column]
    local now = GetGameTimer()
    if cached and (now - cached.time) < LEADERBOARD_CACHE_MS then
        return cached.rows
    end
    local rows = MySQL.query.await(
        ('SELECT charname, %s FROM `rsg_loyalty` ORDER BY %s DESC LIMIT 10'):format(column, column)
    ) or {}
    leaderboardCache[column] = { time = now, rows = rows }
    return rows
end

---------------------------------------------------------------------
-- Client data
---------------------------------------------------------------------
local function toClient(row)
    local idx, tier = getTier(row.lifetime_points)
    local nextTier = Config.Tiers and Config.Tiers[idx + 1]
    return {
        loyalty_points = row.loyalty_points,
        lifetime_points = row.lifetime_points,
        streak = row.daily_streak or 0,
        tier = {
            key = tier.key,
            label = locale(tier.label),
            min = tier.minLifetime,
            discount = tier.discount or 0,
            earnMultiplier = tier.earnMultiplier or 1.0,
            nextLabel = nextTier and locale(nextTier.label) or nil,
            nextMin = nextTier and nextTier.minLifetime or nil,
        },
        boost = boostInfo(),
    }
end

local function pushLoyalty(src, citizenid)
    local data = getLoyalty(citizenid)
    if not data then return nil end
    local session = sessions[src]
    if session then
        session.tierIdx = getTier(data.lifetime_points)
        session.balance = data.loyalty_points
    end
    TriggerClientEvent('rsg-loyalty:client:updateLoyaltyData', src, toClient(data))
    return data
end

-- per-reward cost, requirement lock and remaining stock/limit for this player
local function buildStoreState(Player, citizenid, data)
    local idx, tier = getTier(data.lifetime_points)

    local function entry(rewardType, i, reward)
        local id = reward.id or (rewardType .. '_' .. i)
        local e = { cost = finalCost(reward, tier) }
        local lock = checkRequirements(Player, reward, idx)
        if lock == 'tier' then
            local need = Config.Tiers[tierIndexByKey(reward.minTier)]
            e.lock = 'tier'
            e.lockLabel = locale('requires_tier', locale(need.label))
        elseif lock == 'job' then
            e.lock = 'job'
            e.lockLabel = locale('requires_job')
        end
        if reward.stock or reward.limit then
            local total, mine = countRedemptions(id, citizenid, reward.period)
            if reward.stock then e.stockLeft = math.max(0, reward.stock - total) end
            if reward.limit then e.mineLeft = math.max(0, reward.limit - mine) end
        end
        return e
    end

    local state = { cash = {}, item = {}, special = {} }
    for i, reward in ipairs(Config.CashRewards) do state.cash[i] = entry('cash', i, reward) end
    for i, reward in ipairs(Config.ItemRewards) do state.item[i] = entry('item', i, reward) end
    local activeSet = activeSpecials()
    for i, reward in ipairs(Config.SpecialRewards or {}) do
        if activeSet[i] then
            local e = entry('special', i, reward)
            e.index = i
            state.special[#state.special + 1] = e
        end
    end
    return state
end

local function sendStore(src, Player)
    local citizenid = Player.PlayerData.citizenid
    local data = pushLoyalty(src, citizenid)
    if not data then return end
    local _, rotationEnds = activeSpecials()
    TriggerClientEvent('rsg-loyalty:client:storeState', src, {
        rewards = buildStoreState(Player, citizenid, data),
        rotationEnds = rotationEnds,
    })
end

local function historyText(row)
    local r, d = row.reason, row.detail
    if r == 'daily' then return locale('history_daily') end
    if r == 'activity' then return locale('history_activity', d or '') end
    if r == 'redeem' then return locale('history_redeem', d or '') end
    if r == 'admin_add' then return locale('history_admin_add') end
    if r == 'admin_remove' then return locale('history_admin_remove') end
    if r == 'export' then return locale('history_export') end
    return tostring(r)
end

---------------------------------------------------------------------
-- Daily login bonus and streak
---------------------------------------------------------------------
local function claimDaily(src, citizenid)
    local cfg = Config.Daily
    if not cfg or not cfg.Enabled then return end

    local row = MySQL.single.await(
        'SELECT daily_streak, DATEDIFF(CURDATE(), last_daily) AS days_since FROM `rsg_loyalty` WHERE citizenid = ?',
        { citizenid }
    )
    if not row then return end
    local daysSince = tonumber(row.days_since)
    if daysSince and daysSince <= 0 then return end -- already claimed today

    local streak = (daysSince == 1) and ((row.daily_streak or 0) + 1) or 1
    local bonus = math.min((cfg.BasePoints or 0) + (streak - 1) * (cfg.PerStreakDay or 0), cfg.MaxPoints or MAX_POINTS_VALUE)
    local milestone = (cfg.Milestones and cfg.Milestones[streak]) or 0
    local total = math.floor(bonus + milestone)

    -- one statement does the guard and the award, so it can never be claimed twice
    local changed = MySQL.update.await(
        'UPDATE `rsg_loyalty` SET loyalty_points = loyalty_points + ?, lifetime_points = lifetime_points + ?, daily_streak = ?, last_daily = CURDATE() WHERE citizenid = ? AND (last_daily IS NULL OR last_daily < CURDATE())',
        { total, total, streak, citizenid }
    )
    if (changed or 0) == 0 then return end

    if total > 0 then
        logHistory(citizenid, total, 'daily', ('day %s'):format(streak))
        notify(src, locale('daily_bonus', total, streak), 'success')
        if milestone > 0 then
            notify(src, locale('daily_milestone', milestone), 'success')
        end
    end
end

---------------------------------------------------------------------
-- Player lifecycle
---------------------------------------------------------------------
RegisterNetEvent('rsg-loyalty:server:playerLoaded', function()
    if not ENABLED then return end
    local src = source
    if onCooldown('data', src) then return end
    if not waitForDatabase() then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    ensureLoyalty(citizenid, getCharName(Player))

    -- only start a new session for a new character; re-triggering this
    -- event must not reset the per-session earning cap or re-run the daily bonus
    local session = sessions[src]
    if not session or session.citizenid ~= citizenid then
        local minPlaytime = (Config.Loyalty.MinPlaytimeBeforeEarning or 0) * 1000
        session = {
            citizenid = citizenid,
            earned = 0,
            eligibleAt = GetGameTimer() + minPlaytime,
            maxNotified = false,
        }
        sessions[src] = session
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then session.lastPos = GetEntityCoords(ped) end
        claimDaily(src, citizenid)
    end

    pushLoyalty(src, citizenid)
end)

local function clearPlayer(src)
    sessions[src] = nil
    for _, list in pairs(cooldowns) do
        list[src] = nil
    end
end

AddEventHandler('playerDropped', function()
    clearPlayer(source)
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    clearPlayer(src)
end)

---------------------------------------------------------------------
-- Data requests
---------------------------------------------------------------------
RegisterNetEvent('rsg-loyalty:server:getStore', function()
    if not active() then return end
    local src = source
    if onCooldown('store', src) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    sendStore(src, Player)
end)

RegisterNetEvent('rsg-loyalty:server:getLeaderboard', function()
    if not active() then return end
    local src = source
    if onCooldown('leaderboard', src) then return end
    if not RSGCore.Functions.GetPlayer(src) then return end

    TriggerClientEvent('rsg-loyalty:client:leaderboardData', src, {
        topCurrent = GetLoyaltyLeaderboard('loyalty_points'),
        topLifetime = GetLoyaltyLeaderboard('lifetime_points'),
    })
end)

RegisterNetEvent('rsg-loyalty:server:getHistory', function()
    if not active() then return end
    local src = source
    if onCooldown('history', src) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local limit = math.min((Config.History and Config.History.Rows) or 20, 50)
    local rows = MySQL.query.await(
        'SELECT amount, reason, detail, UNIX_TIMESTAMP(created) AS ts FROM `rsg_loyalty_history` WHERE citizenid = ? ORDER BY id DESC LIMIT ?',
        { Player.PlayerData.citizenid, limit }
    ) or {}

    local out = {}
    for i, row in ipairs(rows) do
        out[i] = { text = historyText(row), amount = row.amount, ts = tonumber(row.ts) }
    end
    TriggerClientEvent('rsg-loyalty:client:historyData', src, out)
end)

---------------------------------------------------------------------
-- Earning (fully server-side: no client event, nothing to spoof)
---------------------------------------------------------------------
-- tell the player when this tick made a reward affordable
local function notifyAffordable(src, Player, oldBalance, newBalance, tierIdx)
    if not (Config.Notify and Config.Notify.AffordableReward) then return end
    local tier = (Config.Tiers and Config.Tiers[tierIdx]) or DEFAULT_TIER
    local best, bestCost

    local function consider(reward)
        if checkRequirements(Player, reward, tierIdx) then return end
        local cost = finalCost(reward, tier)
        if cost > oldBalance and cost <= newBalance and (not bestCost or cost > bestCost) then
            best, bestCost = reward, cost
        end
    end

    for _, reward in ipairs(Config.CashRewards) do consider(reward) end
    for _, reward in ipairs(Config.ItemRewards) do consider(reward) end
    local activeSet = activeSpecials()
    for i, reward in ipairs(Config.SpecialRewards or {}) do
        if activeSet[i] then consider(reward) end
    end

    if best then
        notify(src, locale('can_afford', locale(best.label)), 'success')
    end
end

local function earnTick(src, session)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.citizenid ~= session.citizenid then return end
    if GetGameTimer() < session.eligibleAt then return end

    -- anti-AFK: position is read on the server
    if Config.Loyalty.RequireMovement then
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return end
        local pos = GetEntityCoords(ped)
        local last = session.lastPos
        session.lastPos = pos
        if not last or #(pos - last) < (Config.Loyalty.MinMoveDistance or 5.0) then return end
    end

    local base = math.floor(Config.Loyalty.PointsPerMinute or 1)
    if base <= 0 then return end
    local tier = (Config.Tiers and Config.Tiers[session.tierIdx or 1]) or DEFAULT_TIER
    local points = math.max(1, math.floor(base * (tier.earnMultiplier or 1.0) * boostMultiplier() + 0.5))

    local remaining = (Config.Loyalty.MaxPointsPerSession or math.huge) - session.earned
    points = math.min(points, remaining)
    if points <= 0 then
        if not session.maxNotified then
            session.maxNotified = true
            notify(src, locale('session_max'), 'inform')
        end
        return
    end

    local citizenid = session.citizenid
    local oldBalance = session.balance
    if not addPoints(citizenid, points) then return end
    session.earned = session.earned + points

    LogPointsEarned(citizenid, getCharName(Player), points)
    local data = pushLoyalty(src, citizenid)
    if data and oldBalance then
        notifyAffordable(src, Player, oldBalance, data.loyalty_points, session.tierIdx or 1)
    end
end

CreateThread(function()
    while true do
        Wait(EARN_INTERVAL)
        if boost.endsAt > 0 and os.time() >= boost.endsAt then
            clearBoost()
        end
        if active() and Config.Loyalty.EnableEarning ~= false then
            -- snapshot the ids: sessions can change while a tick waits on the database
            local ids = {}
            for src in pairs(sessions) do ids[#ids + 1] = src end
            for _, src in ipairs(ids) do
                local session = sessions[src]
                if session then earnTick(src, session) end
            end
        end
    end
end)

---------------------------------------------------------------------
-- Redemption
---------------------------------------------------------------------
-- Takes the points and, for rewards with a stock or per-player limit, records the
-- redemption. A lock per reward keeps two players from taking the last one.
-- Returns true, insertId  or  false, localeKey
local function reserveRedemption(id, citizenid, reward, cost)
    if not (reward.stock or reward.limit) then
        if not removePoints(citizenid, cost) then return false, 'insufficient_points' end
        return true, nil
    end

    if redeemLocks[id] then return false, 'reward_busy' end
    redeemLocks[id] = true
    local ok, success, extra = pcall(function()
        local total, mine = countRedemptions(id, citizenid, reward.period)
        if reward.stock and total >= reward.stock then return false, 'sold_out_notify' end
        if reward.limit and mine >= reward.limit then return false, 'limit_reached_notify' end
        if not removePoints(citizenid, cost) then return false, 'insufficient_points' end
        local insertId = MySQL.insert.await(
            'INSERT INTO `rsg_loyalty_redemptions` (citizenid, reward_id) VALUES (?, ?)',
            { citizenid, id }
        )
        if not insertId then
            refundPoints(citizenid, cost)
            return false, 'error_processing'
        end
        return true, insertId
    end)
    redeemLocks[id] = nil

    if not ok then
        print(('^1[rsg-loyalty]^7 Redemption error for "%s": %s'):format(id, tostring(success)))
        return false, 'error_processing'
    end
    return success, extra
end

local function giveReward(src, Player, kind, reward)
    if kind == 'cash' then
        return Player.Functions.AddMoney('cash', reward.amount, 'loyalty-redeem')
    elseif kind == 'item' then
        local given = exports['rsg-inventory']:AddItem(src, reward.item, reward.amount, nil, nil, 'loyalty-redeem')
        if given then
            TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[reward.item], 'add', reward.amount)
        end
        return given
    end

    -- custom: call a server export in another resource. It counts as given unless
    -- the call errors or the export returns exactly false.
    local ex = reward.export
    local module = exports[ex.resource]
    local ok, result = pcall(function()
        return module[ex.func](module, src, table.unpack(reward.args or {}))
    end)
    if not ok then
        print(('^1[rsg-loyalty]^7 Custom reward export %s:%s failed: %s'):format(ex.resource, ex.func, tostring(result)))
        return false
    end
    return result ~= false
end

RegisterNetEvent('rsg-loyalty:server:redeem', function(rewardType, rewardIndex)
    if not active() then return end
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if onCooldown('redeem', src) then
        return notify(src, locale('redeem_cooldown'), 'error')
    end

    if not isNearLoyaltyNpc(src) then
        return notify(src, locale('too_far_from_store'), 'error')
    end

    local reward, kind, id = resolveReward(rewardType, rewardIndex)
    if not reward then
        return notify(src, locale('invalid_reward'), 'error')
    end

    if kind == 'item' and not RSGCore.Shared.Items[reward.item] then
        print(('^1[rsg-loyalty]^7 Config error: item reward "%s" does not exist in shared items'):format(tostring(reward.item)))
        return notify(src, locale('invalid_reward'), 'error')
    end
    if kind == 'custom' then
        local ex = reward.export
        if type(ex) ~= 'table' or type(ex.resource) ~= 'string' or type(ex.func) ~= 'string'
            or GetResourceState(ex.resource) ~= 'started' then
            print(('^1[rsg-loyalty]^7 Config error: custom reward "%s" has no started export target'):format(id))
            return notify(src, locale('error_processing'), 'error')
        end
    end

    local citizenid = Player.PlayerData.citizenid
    local data = getLoyalty(citizenid)
    if not data then
        return notify(src, locale('no_loyalty_data'), 'error')
    end
    local tierIdx, tier = getTier(data.lifetime_points)

    local lock = checkRequirements(Player, reward, tierIdx)
    if lock == 'tier' then
        return notify(src, locale('tier_too_low'), 'error')
    elseif lock == 'job' then
        return notify(src, locale('job_restricted'), 'error')
    end

    if kind == 'item' and not exports['rsg-inventory']:CanAddItem(src, reward.item, reward.amount) then
        return notify(src, locale('pocket_full'), 'error')
    end

    local cost = finalCost(reward, tier)
    local charname = getCharName(Player)
    local label = locale(reward.label)

    local reserved, extra = reserveRedemption(id, citizenid, reward, cost)
    if not reserved then
        return notify(src, locale(extra), 'error')
    end

    local given = giveReward(src, Player, kind, reward)
    if not given then
        refundPoints(citizenid, cost)
        if extra then
            MySQL.update('DELETE FROM `rsg_loyalty_redemptions` WHERE id = ?', { extra })
        end
        LogRedemptionFailed(citizenid, charname, kind == 'cash' and 'cash' or 'item', label, locale('error_processing'))
        notify(src, locale('error_processing'), 'error')
        return sendStore(src, Player)
    end

    local amount = reward.amount or 1
    LogRedemptionSuccess(citizenid, charname, kind == 'cash' and 'cash' or 'item', label, amount, cost)
    logHistory(citizenid, -cost, 'redeem', label)

    local message = kind == 'cash'
        and locale('cash_redeemed', label, amount)
        or locale('item_redeemed', label, amount)
    notify(src, message, 'success')
    sendStore(src, Player)
end)

---------------------------------------------------------------------
-- Admin
---------------------------------------------------------------------
-- mode: 'add' | 'remove'
local function adminAdjust(src, targetId, points, mode)
    if not active() then
        return notify(src, locale('loyalty_disabled'), 'error')
    end
    if not isAdmin(src) then
        return notify(src, locale('no_permission'), 'error')
    end
    if src ~= 0 and onCooldown('admin', src) then
        return notify(src, locale('admin_cooldown'), 'error')
    end

    targetId = tonumber(targetId)
    points = sanitizePoints(points, Config.Loyalty.MaxAdminAwardPoints or 10000)
    if not targetId or not points then
        return notify(src, locale('invalid_player_or_points', Config.Loyalty.MaxAdminAwardPoints or 10000), 'error')
    end

    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target then
        return notify(src, locale('player_not_found'), 'error')
    end

    local citizenid = Target.PlayerData.citizenid
    local targetName = getCharName(Target)
    local Admin = src ~= 0 and RSGCore.Functions.GetPlayer(src)
    local adminName = Admin and getCharName(Admin) or locale('console')

    if mode == 'add' then
        if not addPoints(citizenid, points) then
            return notify(src, locale('award_fail'), 'error')
        end
        logHistory(citizenid, points, 'admin_add', adminName)
        notify(src, locale('award_success', points, targetName), 'success')
        notify(targetId, locale('award_notification', points), 'success')
        LogAdminPointAward(adminName, targetName, points)
    else
        if not removePoints(citizenid, points) then
            return notify(src, locale('remove_fail'), 'error')
        end
        logHistory(citizenid, -points, 'admin_remove', adminName)
        notify(src, locale('remove_success', points, targetName), 'success')
        notify(targetId, locale('remove_notification', points), 'inform')
        LogAdminPointRemoval(adminName, targetName, points)
    end

    pushLoyalty(targetId, citizenid)
end

RegisterCommand('awardloyalty', function(source, args)
    if not args[1] or not args[2] then
        return notify(source, locale('usage_awardloyalty'), 'inform')
    end
    adminAdjust(source, args[1], args[2], 'add')
end, false)

RegisterCommand('removeloyalty', function(source, args)
    if not args[1] or not args[2] then
        return notify(source, locale('usage_removeloyalty'), 'inform')
    end
    adminAdjust(source, args[1], args[2], 'remove')
end, false)

-- for external admin menus; same permission/validation as the commands
RegisterNetEvent('rsg-loyalty:server:adminAwardPoints', function(targetId, points)
    local src = source
    if not isAdmin(src) then return end
    adminAdjust(src, targetId, points, 'add')
end)

RegisterCommand('checkloyalty', function(source, args)
    if not isAdmin(source) then
        return notify(source, locale('no_permission'), 'error')
    end
    if not active() then
        return notify(source, locale('loyalty_disabled'), 'error')
    end

    local targetId = tonumber(args[1])
    if not targetId then
        return notify(source, locale('usage_checkloyalty'), 'inform')
    end

    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target then
        return notify(source, locale('player_not_found'), 'error')
    end

    local data = getLoyalty(Target.PlayerData.citizenid)
    if not data then
        return notify(source, locale('no_loyalty_data'), 'error')
    end

    notify(source, locale('check_loyalty_result', getCharName(Target), data.loyalty_points, data.lifetime_points), 'inform')
end, false)

-- /loyaltyboost [multiplier] [minutes]   or   /loyaltyboost off
RegisterCommand('loyaltyboost', function(source, args)
    if not isAdmin(source) then
        return notify(source, locale('no_permission'), 'error')
    end
    if not active() then
        return notify(source, locale('loyalty_disabled'), 'error')
    end

    if args[1] == 'off' then
        clearBoost()
        return notify(source, locale('boost_cleared'), 'success')
    end

    local multiplier, minutes = tonumber(args[1]), math.tointeger(tonumber(args[2]))
    if not multiplier or not minutes or multiplier <= 1.0 or minutes < 1 then
        return notify(source, locale('usage_loyaltyboost'), 'inform')
    end

    local m, mins = setBoost(multiplier, minutes)
    notify(source, locale('boost_set', m, mins), 'success')
end, false)

RegisterCommand('postleaderboard', function(source)
    if not isAdmin(source) then
        return notify(source, locale('no_permission'), 'error')
    end
    if not active() then
        return notify(source, locale('loyalty_disabled'), 'error')
    end
    if not IsWebhookConfigured() then
        return notify(source, locale('postleaderboard_no_webhook'), 'error')
    end
    SendLeaderboardWebhook()
    notify(source, locale('postleaderboard_success'), 'success')
end, false)

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
-- returns allowed, invokingResource (call before anything that yields)
local function isExportAllowed()
    if not active() then return false end
    local resource = GetInvokingResource()
    if Config.Exports.AllowAllResources then return true, resource end
    if not resource then return false end
    for _, allowed in ipairs(Config.Exports.AllowedResources) do
        if resource == allowed then return true, resource end
    end
    return false
end

exports('getLoyaltyPoints', function(citizenid)
    local data = getLoyalty(citizenid)
    return data and data.loyalty_points or 0
end)

exports('getLifetimeLoyaltyPoints', function(citizenid)
    local data = getLoyalty(citizenid)
    return data and data.lifetime_points or 0
end)

-- { index, key, discount, earnMultiplier } for a character
exports('getLoyaltyTier', function(citizenid)
    local data = getLoyalty(citizenid)
    local idx, tier = getTier(data and data.lifetime_points or 0)
    return { index = idx, key = tier.key, discount = tier.discount or 0, earnMultiplier = tier.earnMultiplier or 1.0 }
end)

exports('addLoyaltyPoints', function(citizenid, points)
    local allowed, resource = isExportAllowed()
    points = sanitizePoints(points, MAX_POINTS_VALUE)
    if not allowed or not points or type(citizenid) ~= 'string' then return false end
    if not addPoints(citizenid, points) then return false end
    logHistory(citizenid, points, 'export', resource)
    return true
end)

exports('removeLoyaltyPoints', function(citizenid, points)
    local allowed, resource = isExportAllowed()
    points = sanitizePoints(points, MAX_POINTS_VALUE)
    if not allowed or not points or type(citizenid) ~= 'string' then return false end
    if not removePoints(citizenid, points) then return false end
    logHistory(citizenid, -points, 'export', resource)
    return true
end)

-- Award the points configured for an activity in Config.Activities (per-activity
-- cooldown and daily cap, tier multiplier and boost apply). Returns ok, points.
exports('awardActivity', function(src, activity)
    local allowed = isExportAllowed()
    if not allowed then return false end

    src = tonumber(src)
    local cfg = type(activity) == 'string' and Config.Activities and Config.Activities[activity]
    local session = src and sessions[src]
    local Player = src and RSGCore.Functions.GetPlayer(src)
    if not cfg or not session or not Player or session.citizenid ~= Player.PlayerData.citizenid then
        return false
    end
    if (cfg.points or 0) <= 0 then return false end

    local now = GetGameTimer()
    session.activityLast = session.activityLast or {}
    local last = session.activityLast[activity]
    if last and (now - last) < (cfg.cooldown or 0) * 1000 then return false end
    session.activityLast[activity] = now

    local tier = (Config.Tiers and Config.Tiers[session.tierIdx or 1]) or DEFAULT_TIER
    local points = math.max(1, math.floor(cfg.points * (tier.earnMultiplier or 1.0) * boostMultiplier() + 0.5))

    local citizenid = session.citizenid
    if cfg.dailyCap then
        local today = MySQL.scalar.await(
            "SELECT COALESCE(SUM(amount), 0) FROM `rsg_loyalty_history` WHERE citizenid = ? AND reason = 'activity' AND detail = ? AND created >= CURDATE()",
            { citizenid, activity }
        ) or 0
        points = math.min(points, cfg.dailyCap - today)
        if points <= 0 then return false end
    end

    if not addPoints(citizenid, points) then return false end
    logHistory(citizenid, points, 'activity', activity)
    notify(src, locale('activity_points', points), 'success')
    pushLoyalty(src, citizenid)
    return true, points
end)

-- start or clear a global earning boost from another resource (e.g. an admin menu)
exports('setLoyaltyBoost', function(multiplier, minutes)
    if not isExportAllowed() then return false end
    multiplier = tonumber(multiplier)
    if not multiplier or multiplier <= 1.0 then
        clearBoost()
        return true
    end
    setBoost(multiplier, minutes)
    return true
end)
