local RSGCore = exports['rsg-core']:GetCoreObject()

-- player statistics (completed deliveries, distance, earnings, streaks) and the leaderboard
Stats = {}

local cache = {}      -- citizenid -> row
local boardCache = {} -- mode -> { at, rows }
local lastRequest = {}
local BOARD_MODES = { completed = 'completed', distance = 'distance', earned = 'earned' } -- whitelist, also the column names
local BOARD_SIZE = 10

local function ensureDatabase()
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `rsg_deliveries_stats` (
                `citizenid` VARCHAR(50) NOT NULL,
                `name` VARCHAR(100) NOT NULL DEFAULT '',
                `completed` INT UNSIGNED NOT NULL DEFAULT 0,
                `distance` DOUBLE NOT NULL DEFAULT 0,
                `earned` BIGINT UNSIGNED NOT NULL DEFAULT 0,
                `streak` INT UNSIGNED NOT NULL DEFAULT 0,
                `best_streak` INT UNSIGNED NOT NULL DEFAULT 0,
                `last_delivery` INT UNSIGNED NOT NULL DEFAULT 0,
                PRIMARY KEY (`citizenid`),
                INDEX `idx_completed` (`completed`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]])
    end)
    if not ok then
        print(('^1[%s] database setup failed: %s^7'):format(GetCurrentResourceName(), tostring(err)))
        return false
    end
    print(('^2[%s] database tables ready^7'):format(GetCurrentResourceName()))
    return true
end

CreateThread(function()
    if Config.AutoDatabase and not ensureDatabase() then return end
    Stats.ready = true
end)

local function emptyRow()
    return { name = '', completed = 0, distance = 0, earned = 0, streak = 0, best_streak = 0, last_delivery = 0 }
end

---Loads (once) and returns the cached stats row of a character. May yield on the first call.
function Stats.Get(citizenid)
    if cache[citizenid] then return cache[citizenid] end
    local row
    if Stats.ready then
        row = MySQL.single.await('SELECT name, completed, distance, earned, streak, best_streak, last_delivery FROM rsg_deliveries_stats WHERE citizenid = ?', { citizenid })
    end
    cache[citizenid] = row or emptyRow()
    return cache[citizenid]
end

---The streak a delivery completed now would reach, and the bonus % that earns.
---@return integer streak, number bonusPct
function Stats.NextStreak(citizenid, now)
    local row = Stats.Get(citizenid)
    local S = Config.Streak
    local active = row.last_delivery > 0 and (now - row.last_delivery) <= S.Window
    local streak = (active and row.streak or 0) + 1
    local pct = S.Enabled and math.min(S.MaxBonusPct, (streak - 1) * S.BonusPerStep) or 0
    return streak, pct
end

function Stats.Record(citizenid, name, distance, earned, streak, now)
    local row = Stats.Get(citizenid)
    row.name = name
    row.completed = row.completed + 1
    row.distance = row.distance + distance
    row.earned = row.earned + earned
    row.streak = streak
    row.best_streak = math.max(row.best_streak, streak)
    row.last_delivery = now
    boardCache = {}
    if not Stats.ready then return end
    MySQL.insert([[
        INSERT INTO rsg_deliveries_stats (citizenid, name, completed, distance, earned, streak, best_streak, last_delivery)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), completed = VALUES(completed), distance = VALUES(distance),
            earned = VALUES(earned), streak = VALUES(streak), best_streak = VALUES(best_streak), last_delivery = VALUES(last_delivery)
    ]], { citizenid, name, row.completed, row.distance, row.earned, row.streak, row.best_streak, row.last_delivery })
end

local function topRows(mode)
    local cached = boardCache[mode]
    if cached and os.time() - cached.at < 30 then return cached.rows end
    local rows = {}
    if Stats.ready then
        -- the column comes from the BOARD_MODES whitelist, never from the client
        rows = MySQL.query.await(('SELECT name, completed, distance, earned, best_streak FROM rsg_deliveries_stats ORDER BY `%s` DESC LIMIT %d'):format(BOARD_MODES[mode], BOARD_SIZE)) or {}
    end
    boardCache[mode] = { at = os.time(), rows = rows }
    return rows
end

-- read-only: the board plus the caller's own numbers
RSGCore.Functions.CreateCallback('rsg-deliveries:server:getleaderboard', function(src, cb, mode)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end
    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < 500 then return cb(false) end
    lastRequest[src] = now
    if not BOARD_MODES[mode] then mode = 'completed' end

    local me = Stats.Get(Player.PlayerData.citizenid)
    local active = me.last_delivery > 0 and (os.time() - me.last_delivery) <= Config.Streak.Window
    cb({
        mode = mode,
        rows = topRows(mode),
        me = { completed = me.completed, distance = me.distance, earned = me.earned, streak = active and me.streak or 0, best = me.best_streak },
    })
end)

AddEventHandler('playerDropped', function() lastRequest[source] = nil end)
