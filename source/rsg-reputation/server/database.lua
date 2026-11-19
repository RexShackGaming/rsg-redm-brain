-- rsg-reputation: database setup, per-player cache, loading and saving
RSGRep = RSGRep or {}
local RSGCore = exports['rsg-core']:GetCoreObject()
local TAG = '[rsg-reputation]'
local DAY = 86400

------------------------------------------
-- schema (keep identical to install.sql)
------------------------------------------
local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `rsg_reputation` (
        `citizenid` VARCHAR(50) NOT NULL,
        `honor` INT NOT NULL DEFAULT 0,
        `decayed` INT UNSIGNED NOT NULL DEFAULT 0,
        `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_reputation_standing` (
        `citizenid` VARCHAR(50) NOT NULL,
        `region` VARCHAR(50) NOT NULL,
        `standing` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`, `region`)
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

RSGRep.Ready = false

-- blocks (inside a thread) until the database is ready; false if it never becomes ready
function RSGRep.WaitReady()
    local waited = 0
    while not RSGRep.Ready do
        if waited >= 15000 then return false end
        Wait(100)
        waited = waited + 100
    end
    return true
end

------------------------------------------
-- cache: [citizenid] = { src, honor, decayed, dirtyHonor, standing = {region = value}, dirtyStanding = {region = true} }
------------------------------------------
local Cache = {}
local SrcToCid = {}
local loading = {}
RSGRep.Cache = Cache

local function towardZero(value, step)
    if value > 0 then return math.max(0, value - step) end
    if value < 0 then return math.min(0, value + step) end
    return 0
end

-- pulls honor and standing toward 0 for every full day since the last decay. Returns true when something changed.
function RSGRep.ApplyDecay(c)
    local days = (os.time() - c.decayed) // DAY
    if days <= 0 then return false end
    c.decayed = c.decayed + days * DAY
    c.dirtyHonor = true

    local h = Config.Honor.Decay
    if h and h.Enabled and (tonumber(h.PerDay) or 0) > 0 then
        c.honor = towardZero(c.honor, h.PerDay * days)
    end
    local s = Config.Standing.Decay
    if s and s.Enabled and (tonumber(s.PerDay) or 0) > 0 then
        for region, value in pairs(c.standing) do
            local nv = towardZero(value, s.PerDay * days)
            if nv ~= value then
                c.standing[region] = nv
                c.dirtyStanding[region] = true
            end
        end
    end
    return true
end

-- loads (or returns the cached) reputation of an online player. Yields while reading the database.
function RSGRep.Load(src)
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

    if loading[cid] then
        local waited = 0
        while loading[cid] and waited < 10000 do Wait(50) waited = waited + 50 end
        return Cache[cid]
    end

    -- claim the load before yielding so a second caller waits instead of querying again
    loading[cid] = true
    if not RSGRep.WaitReady() then
        loading[cid] = nil
        return nil
    end

    local ok, honorRows, standingRows = pcall(function()
        return MySQL.query.await('SELECT honor, decayed FROM rsg_reputation WHERE citizenid = ?', { cid }),
            MySQL.query.await('SELECT region, standing FROM rsg_reputation_standing WHERE citizenid = ?', { cid })
    end)
    if not ok then
        loading[cid] = nil
        print(('%s ^1could not load reputation of %s: %s^7'):format(TAG, cid, tostring(honorRows)))
        return nil
    end

    local now = os.time()
    local c = { src = src, honor = Config.Honor.Start, decayed = now, dirtyHonor = false, standing = {}, dirtyStanding = {} }
    local row = honorRows and honorRows[1]
    if row then
        c.honor = tonumber(row.honor) or c.honor
        c.decayed = tonumber(row.decayed) or now
        if c.decayed <= 0 then c.decayed = now end
    else
        c.dirtyHonor = true -- first time: create the row
    end
    for _, r in ipairs(standingRows or {}) do
        c.standing[r.region] = tonumber(r.standing) or 0
    end
    RSGRep.ApplyDecay(c)

    Cache[cid] = c
    SrcToCid[src] = cid
    loading[cid] = nil
    return c
end

------------------------------------------
-- saving
------------------------------------------
local UPSERT_HONOR = 'INSERT INTO rsg_reputation (citizenid, honor, decayed) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE honor = VALUES(honor), decayed = VALUES(decayed)'
local UPSERT_STANDING = 'INSERT INTO rsg_reputation_standing (citizenid, region, standing) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE standing = VALUES(standing)'

-- writes changed values to the database. awaitIt = true waits for every query (used on logout and stop)
function RSGRep.Flush(awaitIt, onlyCid)
    if not RSGRep.Ready then return end

    -- snapshot first: the loops below can yield, and new changes may arrive meanwhile
    local jobs = {}
    for cid, c in pairs(Cache) do
        if not onlyCid or onlyCid == cid then
            if c.dirtyHonor then
                jobs[#jobs + 1] = { kind = 'honor', cid = cid, c = c, honor = c.honor, decayed = c.decayed }
                c.dirtyHonor = false
            end
            for region in pairs(c.dirtyStanding) do
                jobs[#jobs + 1] = { kind = 'standing', cid = cid, c = c, region = region, value = c.standing[region] or 0 }
            end
            c.dirtyStanding = {}
        end
    end

    for i = 1, #jobs do
        local j = jobs[i]
        local ok, err = pcall(function()
            local query, params
            if j.kind == 'honor' then
                query, params = UPSERT_HONOR, { j.cid, j.honor, j.decayed }
            else
                query, params = UPSERT_STANDING, { j.cid, j.region, j.value }
            end
            if awaitIt then MySQL.insert.await(query, params) else MySQL.insert(query, params) end
        end)
        if not ok then
            print(('%s ^1save failed for %s: %s^7'):format(TAG, j.cid, tostring(err)))
            if j.kind == 'honor' then j.c.dirtyHonor = true else j.c.dirtyStanding[j.region] = true end
        end
    end
end

local function evict(src)
    local cid = SrcToCid[src]
    SrcToCid[src] = nil
    if not cid then return end
    RSGRep.Flush(true, cid)
    local c = Cache[cid]
    if not c then return end
    -- changes that arrived while the save was running: save them too before forgetting the player
    if c.dirtyHonor or next(c.dirtyStanding) then RSGRep.Flush(true, cid) end
    if c.src == src then Cache[cid] = nil end
end

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src) evict(src) end)
AddEventHandler('playerDropped', function() evict(source) end)

CreateThread(function()
    while true do
        Wait(math.max(15, tonumber(Config.SaveInterval) or 60) * 1000)
        RSGRep.Flush(false)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    RSGRep.Flush(true)
end)

------------------------------------------
-- startup
------------------------------------------
CreateThread(function()
    Wait(1000) -- let every server script finish loading first
    if Config.AutoDatabase and not ensureDatabase() then return end
    RSGRep.Ready = true
    TriggerEvent('rsg-reputation:server:ready')

    -- players already online (resource restarted while the server is running)
    for _, Player in pairs(RSGCore.Functions.GetRSGPlayers()) do
        local src = Player.PlayerData.source
        CreateThread(function()
            if RSGRep.Load(src) then RSGRep.SyncClient(src) end
        end)
    end

    -- online players also decay while they stay connected
    while true do
        Wait(30 * 60 * 1000)
        for _, c in pairs(Cache) do
            if RSGRep.ApplyDecay(c) and c.src then RSGRep.SyncClient(c.src) end
        end
    end
end)
