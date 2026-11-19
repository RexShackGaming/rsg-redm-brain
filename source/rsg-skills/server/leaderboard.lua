-- rsg-skills: leaderboards (all-time and weekly, per skill or overall)
RSGSkills = RSGSkills or {}
local RSGCore = exports['rsg-core']:GetCoreObject()
local TAG = '[rsg-skills]'

local Defs = RSGSkills.Defs
local boards = {} -- ['mode:skill'] = { list, updated, week }

local function weeklyEnabled()
    return Config.Weekly and Config.Weekly.Enabled and true or false
end

-- rebuilds one board from the database (changed skills are saved first so the board is current)
local function build(mode, skill)
    local limit = math.max(1, math.floor(tonumber(Config.Leaderboard.MaxEntries) or 200))
    RSGSkills.Flush(true)

    local rows
    if mode == 'weekly' then
        local week = RSGSkills.WeekNumber()
        if skill == 'all' then
            rows = MySQL.query.await(
                'SELECT citizenid, MAX(name) AS name, SUM(xp) AS total FROM rsg_skills_weekly WHERE week = ? GROUP BY citizenid HAVING SUM(xp) > 0 ORDER BY total DESC LIMIT ?',
                { week, limit })
        else
            rows = MySQL.query.await(
                'SELECT citizenid, name, xp AS total FROM rsg_skills_weekly WHERE week = ? AND skill = ? AND xp > 0 ORDER BY xp DESC LIMIT ?',
                { week, skill, limit })
        end
    else
        if skill == 'all' then
            rows = MySQL.query.await(
                'SELECT citizenid, MAX(name) AS name, SUM(xp) AS total FROM rsg_skills GROUP BY citizenid HAVING SUM(xp) > 0 ORDER BY total DESC LIMIT ?',
                { limit })
        else
            rows = MySQL.query.await(
                'SELECT citizenid, name, xp AS total FROM rsg_skills WHERE skill = ? AND xp > 0 ORDER BY xp DESC LIMIT ?',
                { skill, limit })
        end
    end

    local list = {}
    for i, r in ipairs(rows or {}) do
        local xp = tonumber(r.total) or 0
        local entry = { citizenid = r.citizenid, name = (r.name and r.name ~= '') and r.name or '?', xp = xp }
        -- levels only make sense for a single all-time skill board
        if mode ~= 'weekly' and skill ~= 'all' then
            entry.level = RSGSkills.LevelOfXP(skill, xp)
        end
        list[i] = entry
    end
    return list
end

local lastRequest = {}

local function handler(src, mode, skill)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not RSGSkills.Ready then return nil end

    -- the client controls these two values: only accept known ones
    if mode ~= 'weekly' or not weeklyEnabled() then mode = 'all' end
    if type(skill) ~= 'string' or (skill ~= 'all' and not Defs[skill]) then skill = 'all' end

    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < 500 then return nil end
    lastRequest[src] = now

    local key = mode .. ':' .. skill
    local board = boards[key]
    local week = RSGSkills.WeekNumber()
    local stale = not board
        or os.time() - board.updated >= math.max(10, tonumber(Config.Leaderboard.CacheSeconds) or 60)
        or board.week ~= week
    if stale then
        board = { list = build(mode, skill), updated = os.time(), week = week }
        boards[key] = board
    end

    local cid = Player.PlayerData.citizenid
    local myRank, myXP
    for i, e in ipairs(board.list) do
        if e.citizenid == cid then myRank, myXP = i, e.xp break end
    end
    if not myXP then
        -- not in the loaded rows: show the live all-time value for the skill (weekly shows 0)
        myXP = 0
        if mode ~= 'weekly' then
            local c = RSGSkills.Cache[cid]
            if c then
                if skill == 'all' then
                    for k in pairs(Defs) do myXP = myXP + (c.xp[k] or 0) end
                else
                    myXP = c.xp[skill] or 0
                end
            end
        end
    end

    local top = {}
    for i = 1, math.min(math.max(1, tonumber(Config.Leaderboard.ShowTop) or 10), #board.list) do
        local e = board.list[i]
        top[i] = { rank = i, name = e.name, xp = e.xp, level = e.level, me = e.citizenid == cid }
    end

    return {
        mode = mode,
        skill = skill,
        weeklyEnabled = weeklyEnabled(),
        top = top,
        total = #board.list,
        me = { rank = myRank, xp = myXP },
    }
end

RSGCore.Functions.CreateCallback('rsg-skills:server:getLeaderboard', function(src, cb, mode, skill)
    local ok, result = pcall(handler, src, mode, skill)
    if not ok then print(('%s ^1leaderboard error: %s^7'):format(TAG, tostring(result))) end
    cb(ok and result or nil)
end)

AddEventHandler('playerDropped', function() lastRequest[source] = nil end)
