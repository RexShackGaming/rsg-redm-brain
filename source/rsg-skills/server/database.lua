-- rsg-skills: database setup, cache, loading and saving
RSGSkills = RSGSkills or {}
local RSGCore = exports['rsg-core']:GetCoreObject()

local TAG = '[rsg-skills]'

------------------------------------------
-- schema (keep identical to install.sql)
------------------------------------------
local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `rsg_skills` (
        `citizenid` VARCHAR(50) NOT NULL,
        `skill` VARCHAR(50) NOT NULL,
        `xp` INT UNSIGNED NOT NULL DEFAULT 0,
        `name` VARCHAR(100) NOT NULL DEFAULT '',
        `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`, `skill`),
        KEY `skill_xp` (`skill`, `xp`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_skills_weekly` (
        `citizenid` VARCHAR(50) NOT NULL,
        `skill` VARCHAR(50) NOT NULL,
        `week` INT NOT NULL,
        `xp` INT UNSIGNED NOT NULL DEFAULT 0,
        `name` VARCHAR(100) NOT NULL DEFAULT '',
        PRIMARY KEY (`citizenid`, `skill`, `week`),
        KEY `week_skill_xp` (`week`, `skill`, `xp`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local function ensureDatabase()
    local ok, err = pcall(function()
        for i = 1, #SCHEMA do
            MySQL.query.await(SCHEMA[i])
        end
    end)
    if not ok then
        print(('%s ^1could not create database tables: %s^7'):format(TAG, tostring(err)))
        return false
    end
    print(('%s ^2database tables ready^7'):format(TAG))
    return true
end

------------------------------------------
-- startup state
------------------------------------------
RSGSkills.Ready = false

-- blocks (inside a thread) until the database is ready; false if it never becomes ready
function RSGSkills.WaitReady()
    local waited = 0
    while not RSGSkills.Ready do
        if waited >= 15000 then return false end
        Wait(100)
        waited = waited + 100
    end
    return true
end

------------------------------------------
-- cache: [citizenid] = { src, name, xp = {skill = xp}, dirty = {skill = true}, weekly = {'skill:week' = delta} }
------------------------------------------
local Cache = {}
local SrcToCid = {}
local loading = {}
RSGSkills.Cache = Cache

-- weeks start Monday 00:00 UTC (1970-01-05 was a Monday)
function RSGSkills.WeekNumber(t)
    return ((t or os.time()) - 345600) // 604800
end

local function fullName(Player)
    local ci = Player.PlayerData.charinfo or {}
    return ('%s %s'):format(ci.firstname or '?', ci.lastname or ''):sub(1, 100)
end

-- loads (or returns the cached) skill data of an online player. Yields while reading the database.
function RSGSkills.Load(src)
    src = tonumber(src)
    if not src then return nil end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local cid = Player.PlayerData.citizenid
    if not cid then return nil end

    local cached = Cache[cid]
    if cached then
        cached.src = src
        SrcToCid[src] = cid
        return cached
    end

    -- another call is already reading this player: wait for it
    if loading[cid] then
        local waited = 0
        while loading[cid] and waited < 10000 do Wait(50) waited = waited + 50 end
        return Cache[cid]
    end

    -- claim the load before yielding so a second caller waits instead of querying again
    loading[cid] = true
    if not RSGSkills.WaitReady() then
        loading[cid] = nil
        return nil
    end

    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT skill, xp FROM rsg_skills WHERE citizenid = ?', { cid })
    end)
    if not ok then
        loading[cid] = nil
        print(('%s ^1could not load skills of %s: %s^7'):format(TAG, cid, tostring(rows)))
        return nil
    end

    local c = { src = src, name = fullName(Player), xp = {}, dirty = {}, weekly = {} }
    for _, r in ipairs(rows or {}) do
        c.xp[r.skill] = tonumber(r.xp) or 0
    end

    -- seed a skill from the player's existing rep value the first time they have no row for it
    for key, def in pairs(RSGSkills.Defs) do
        if def.repImport and c.xp[key] == nil then
            local rep = Player.Functions.GetRep(def.repImport)
            rep = tonumber(rep)
            if rep and rep > 0 then
                c.xp[key] = math.min(math.floor(rep), RSGSkills.XP_LIMIT)
                c.dirty[key] = true
            end
        end
    end

    Cache[cid] = c
    SrcToCid[src] = cid
    loading[cid] = nil
    return c
end

------------------------------------------
-- saving
------------------------------------------
local UPSERT = 'INSERT INTO rsg_skills (citizenid, skill, xp, name) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE xp = VALUES(xp), name = VALUES(name)'
local UPSERT_WEEKLY = 'INSERT INTO rsg_skills_weekly (citizenid, skill, week, xp, name) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE xp = xp + VALUES(xp), name = VALUES(name)'

-- writes changed skills to the database. awaitIt = true waits for every query (used before reading boards and on stop)
function RSGSkills.Flush(awaitIt, onlyCid)
    if not RSGSkills.Ready then return end

    -- snapshot first: the loops below can yield, and new XP may arrive meanwhile
    local jobs = {}
    for cid, c in pairs(Cache) do
        if not onlyCid or onlyCid == cid then
            for skill in pairs(c.dirty) do
                jobs[#jobs + 1] = { kind = 'xp', cid = cid, c = c, skill = skill, xp = c.xp[skill] or 0 }
            end
            c.dirty = {}
            for key, delta in pairs(c.weekly) do
                local skill, week = key:match('^(.-):(%d+)$')
                jobs[#jobs + 1] = { kind = 'weekly', cid = cid, c = c, key = key, skill = skill, week = tonumber(week), xp = delta }
            end
            c.weekly = {}
        end
    end

    for i = 1, #jobs do
        local j = jobs[i]
        local ok, err = pcall(function()
            if j.kind == 'xp' then
                if awaitIt then
                    MySQL.insert.await(UPSERT, { j.cid, j.skill, j.xp, j.c.name })
                else
                    MySQL.insert(UPSERT, { j.cid, j.skill, j.xp, j.c.name })
                end
            else
                if awaitIt then
                    MySQL.insert.await(UPSERT_WEEKLY, { j.cid, j.skill, j.week, j.xp, j.c.name })
                else
                    MySQL.insert(UPSERT_WEEKLY, { j.cid, j.skill, j.week, j.xp, j.c.name })
                end
            end
        end)
        if not ok then
            -- put it back so the next save retries
            print(('%s ^1save failed for %s (%s): %s^7'):format(TAG, j.cid, j.skill or '?', tostring(err)))
            if j.kind == 'xp' then
                j.c.dirty[j.skill] = true
            else
                j.c.weekly[j.key] = (j.c.weekly[j.key] or 0) + j.xp
            end
        end
    end
end

-- saves and forgets a player (logout / disconnect)
local function evict(src)
    local cid = SrcToCid[src]
    SrcToCid[src] = nil
    if not cid then return end
    RSGSkills.Flush(true, cid)
    local c = Cache[cid]
    if not c then return end
    -- XP that arrived while the save was running: save it too before forgetting the player
    if next(c.dirty) or next(c.weekly) then RSGSkills.Flush(true, cid) end
    -- keep the cache entry if the player came back (character switch) while we were saving
    if c.src == src then Cache[cid] = nil end
end

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src) evict(src) end)
AddEventHandler('playerDropped', function() evict(source) end)

CreateThread(function()
    while true do
        Wait(math.max(15, tonumber(Config.SaveInterval) or 60) * 1000)
        RSGSkills.Flush(false)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    RSGSkills.Flush(true)
end)

-- weekly rows older than KeepWeeks are removed
local function pruneWeekly()
    if not (Config.Weekly and Config.Weekly.Enabled) then return end
    local keep = math.max(1, tonumber(Config.Weekly.KeepWeeks) or 4)
    pcall(function()
        MySQL.update.await('DELETE FROM rsg_skills_weekly WHERE week < ?', { RSGSkills.WeekNumber() - keep })
    end)
end

------------------------------------------
-- startup
------------------------------------------
CreateThread(function()
    Wait(1000) -- let every server script finish loading first
    if Config.AutoDatabase and not ensureDatabase() then return end
    RSGSkills.Ready = true
    pruneWeekly()
    TriggerEvent('rsg-skills:server:ready')

    -- players already online (resource restarted while the server is running)
    for _, Player in pairs(RSGCore.Functions.GetRSGPlayers()) do
        local src = Player.PlayerData.source
        CreateThread(function()
            if RSGSkills.Load(src) then RSGSkills.SyncClient(src) end
        end)
    end

    while true do
        Wait(6 * 60 * 60 * 1000)
        pruneWeekly()
    end
end)
