local RSGCore = exports['rsg-core']:GetCoreObject()
------------------------------------------
-- hunting xp, levels and perks
-- xp is stored as player rep (Player.Functions.AddRep) -> metadata.rep[RepName]
------------------------------------------
HuntingXP = {}

local Cfg = Config.HuntingXP

-- level data for a given xp total
function HuntingXP.GetLevelData(xp)
    xp = tonumber(xp) or 0
    local current, nextLvl = Cfg.Levels[1], nil
    for i, lvl in ipairs(Cfg.Levels) do
        if xp >= lvl.xp then
            current = lvl
            nextLvl = Cfg.Levels[i + 1]
        end
    end
    return current, nextLvl
end

function HuntingXP.GetXP(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return 0 end
    return Player.Functions.GetRep(Cfg.RepName) or 0
end

-- perks of the player's current level (empty table when xp is off)
function HuntingXP.GetPerks(src)
    if not Cfg or not Cfg.Enabled then return {} end
    local lvl = HuntingXP.GetLevelData(HuntingXP.GetXP(src))
    return lvl.perks or {}
end

-- xp value of an animal model
function HuntingXP.GetAnimalXP(model)
    if not Cfg or not Cfg.Enabled then return 0 end
    return Cfg.Animals[model] or Cfg.DefaultXP or 0
end

-- weeks start Monday 00:00 UTC (1970-01-05 was a Monday)
local function weekNumber(t)
    return ((t or os.time()) - 345600) // 604800
end
HuntingXP.WeekNumber = weekNumber

-- weekly tables are created automatically on start; weekly features stay off until they exist
local weeklyReady = false

local function weeklyEnabled()
    return weeklyReady and Cfg and Cfg.Enabled and Cfg.Weekly and Cfg.Weekly.Enabled
end

CreateThread(function()
    if not (Cfg and Cfg.Enabled and Cfg.Weekly and Cfg.Weekly.Enabled) then return end
    local ok, err = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `hunting_weekly` (
            `citizenid` VARCHAR(50) NOT NULL,
            `week` INT NOT NULL,
            `name` VARCHAR(100) NOT NULL DEFAULT '',
            `xp` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`citizenid`, `week`),
            KEY `week_xp` (`week`, `xp`)
        )]])
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `hunting_weekly_rewards` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `week` INT NOT NULL,
            `rank` INT NOT NULL,
            `cash` DECIMAL(10,2) NOT NULL DEFAULT 0,
            `claimed` TINYINT(1) NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            UNIQUE KEY `cid_week` (`citizenid`, `week`)
        )]])
    end)
    if ok then
        weeklyReady = true
    else
        print(('[rsg-hunting] ^1could not create weekly tables, weekly leaderboard disabled: %s^7'):format(tostring(err)))
    end
end)

local function addWeeklyXP(Player, amount)
    if not weeklyEnabled() then return end
    local ci = Player.PlayerData.charinfo or {}
    local name = ('%s %s'):format(ci.firstname or '?', ci.lastname or '')
    MySQL.insert('INSERT INTO hunting_weekly (citizenid, week, name, xp) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE xp = xp + VALUES(xp), name = VALUES(name)',
        { Player.PlayerData.citizenid, weekNumber(), name, amount })
end

function HuntingXP.Award(src, amount)
    amount = math.floor(tonumber(amount) or 0)
    if not Cfg or not Cfg.Enabled or amount <= 0 then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local before = Player.Functions.GetRep(Cfg.RepName) or 0
    Player.Functions.AddRep(Cfg.RepName, amount)
    local after = before + amount
    addWeeklyXP(Player, amount)

    if Cfg.Notify then
        TriggerClientEvent('RSGCore:Client:Notify', src, {
            title = locale('hunting_xp_title'),
            description = locale('hunting_xp_gained', amount, after),
            type = 'success',
            duration = 5000
        })
    end

    local oldLvl = HuntingXP.GetLevelData(before)
    local newLvl = HuntingXP.GetLevelData(after)
    if newLvl.level > oldLvl.level then
        HuntingWebhook.Send('levelup', {
            title = locale('wh_levelup_title', newLvl.level),
            description = locale('wh_levelup_desc', newLvl.label, after),
            src = src,
            fields = {
                { name = locale('wh_trapper_bonus'), value = ('+%s%%'):format(newLvl.perks.trapperBonus or 0) },
                { name = locale('wh_butcher_bonus'), value = ('+%s%%'):format(newLvl.perks.butcherBonus or 0) },
                { name = locale('hunting_board_extraskin'), value = ('%s%%'):format(newLvl.perks.extraSkinChance or 0) },
            }
        })
        TriggerClientEvent('RSGCore:Client:Notify', src, {
            title = locale('hunting_levelup_title'),
            description = locale('hunting_levelup_desc', newLvl.level, newLvl.label),
            type = 'success',
            duration = 10000
        })
    end
end

exports('AwardHuntingXP', HuntingXP.Award)
exports('GetHuntingXP', HuntingXP.GetXP)
exports('GetHuntingLevel', function(src)
    local lvl = HuntingXP.GetLevelData(HuntingXP.GetXP(src))
    return lvl.level, lvl.label
end)

------------------------------------------
-- leaderboard (database, cached; online players use live values)
------------------------------------------
local Board = { list = {}, updated = 0 }
local REP_PATH = '$.rep.' .. tostring(Cfg.RepName):gsub('[^%w_]', '')

local function charName(charinfo)
    local ok, ci = pcall(json.decode, charinfo or '{}')
    if ok and type(ci) == 'table' and ci.firstname then
        return ('%s %s'):format(ci.firstname, ci.lastname or '')
    end
    return locale('hunting_unknown')
end

local function refreshBoard()
    local rows = MySQL.query.await(
        'SELECT citizenid, charinfo, CAST(JSON_UNQUOTE(JSON_EXTRACT(metadata, ?)) AS UNSIGNED) AS xp FROM players WHERE JSON_EXTRACT(metadata, ?) IS NOT NULL ORDER BY xp DESC LIMIT ?',
        { REP_PATH, REP_PATH, Cfg.Leaderboard.MaxEntries }
    ) or {}

    local byCid = {}
    for _, r in ipairs(rows) do
        byCid[r.citizenid] = { citizenid = r.citizenid, name = charName(r.charinfo), xp = tonumber(r.xp) or 0 }
    end
    -- online players may have unsaved xp
    for _, P in pairs(RSGCore.Functions.GetRSGPlayers()) do
        local xp = P.Functions.GetRep(Cfg.RepName) or 0
        if xp > 0 then
            local ci = P.PlayerData.charinfo or {}
            byCid[P.PlayerData.citizenid] = {
                citizenid = P.PlayerData.citizenid,
                name = ('%s %s'):format(ci.firstname or '?', ci.lastname or ''),
                xp = xp
            }
        end
    end

    local list = {}
    for _, e in pairs(byCid) do
        local lvl = HuntingXP.GetLevelData(e.xp)
        e.level, e.label = lvl.level, lvl.label
        list[#list + 1] = e
    end
    table.sort(list, function(a, b) return a.xp > b.xp end)
    Board.list, Board.updated = list, os.time()
end

------------------------------------------
-- weekly board (cached like the all-time board)
------------------------------------------
local Weekly = { list = {}, updated = 0, week = -1 }

local function refreshWeekly()
    local week = weekNumber()
    local rows = MySQL.query.await('SELECT citizenid, name, xp FROM hunting_weekly WHERE week = ? AND xp > 0 ORDER BY xp DESC LIMIT ?',
        { week, Cfg.Leaderboard.MaxEntries }) or {}
    local list = {}
    for i, r in ipairs(rows) do
        list[i] = { citizenid = r.citizenid, name = r.name, xp = tonumber(r.xp) or 0 }
    end
    Weekly.list, Weekly.updated, Weekly.week = list, os.time(), week
end

------------------------------------------
-- weekly rewards: when a new week starts, the top hunters of the
-- last week get a cash reward to collect from any trapper
------------------------------------------
local function payWeek(week)
    local rewards = Cfg.Weekly.Rewards or {}
    if #rewards == 0 then return end
    local rows = MySQL.query.await('SELECT citizenid, name, xp FROM hunting_weekly WHERE week = ? AND xp > 0 ORDER BY xp DESC LIMIT ?', { week, #rewards }) or {}
    for i, r in ipairs(rows) do
        MySQL.insert.await('INSERT IGNORE INTO hunting_weekly_rewards (citizenid, week, `rank`, cash) VALUES (?, ?, ?, ?)', { r.citizenid, week, i, rewards[i] })
        HuntingWebhook.Send('levelup', {
            title = locale('wh_weekly_title', i),
            description = locale('wh_weekly_desc', r.name, r.xp, ('%.2f'):format(rewards[i])),
            src = 0,
        })
    end
    -- keep the table small
    MySQL.update('DELETE FROM hunting_weekly WHERE week < ?', { week - (Cfg.Weekly.KeepWeeks or 4) })
end

CreateThread(function()
    if not weeklyEnabled() then return end
    Wait(5000)
    while true do
        local current = weekNumber()
        local last = GetResourceKvpInt('rsg-hunting:lastPaidWeek')
        if last == 0 then
            SetResourceKvpInt('rsg-hunting:lastPaidWeek', current - 1) -- first run: nothing to pay yet
        elseif last < current - 1 then
            payWeek(current - 1)
            SetResourceKvpInt('rsg-hunting:lastPaidWeek', current - 1)
        end
        Wait(60000)
    end
end)

local claiming = {}
local function handler_claimWeekly(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not weeklyEnabled() or claiming[src] then return { ok = false } end
    claiming[src] = true
    local cid = Player.PlayerData.citizenid
    local rows = MySQL.query.await('SELECT id, `rank`, cash FROM hunting_weekly_rewards WHERE citizenid = ? AND claimed = 0', { cid }) or {}
    local total, count = 0, 0
    for _, r in ipairs(rows) do
        -- only pay a row this request actually flipped (no double claims)
        local changed = MySQL.update.await('UPDATE hunting_weekly_rewards SET claimed = 1 WHERE id = ? AND claimed = 0', { r.id })
        if changed == 1 then
            total = total + (tonumber(r.cash) or 0)
            count = count + 1
        end
    end
    if total > 0 then
        Player.Functions.AddMoney('cash', total, 'rsg-hunting-weekly-reward')
        HuntingWebhook.Send('trapper', {
            title = locale('wh_weekly_claim_title'),
            description = locale('wh_weekly_claim_desc', ('%.2f'):format(total), count),
            src = src,
        })
    end
    claiming[src] = nil
    return { ok = total > 0, cash = total }
end
RSGCore.Functions.CreateCallback('rsg-hunting:server:claimWeekly', function(src, cb)
    local ok, result = pcall(handler_claimWeekly, src)
    if not ok then claiming[src] = nil; print(('[rsg-hunting] weekly claim error: %s'):format(tostring(result))) end
    cb(ok and result or { ok = false })
end)

local lastRequest = {}
local function handler_getLeaderboard(src, mode)
    if not Cfg or not Cfg.Enabled then return nil end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end

    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < 1000 then return nil end
    lastRequest[src] = now

    local weekly = mode == 'weekly' and weeklyEnabled()
    local source_
    if weekly then
        if os.time() - Weekly.updated >= Cfg.Leaderboard.CacheSeconds or Weekly.week ~= weekNumber() then refreshWeekly() end
        source_ = Weekly.list
    else
        if os.time() - Board.updated >= Cfg.Leaderboard.CacheSeconds then refreshBoard() end
        source_ = Board.list
    end

    local myCid = Player.PlayerData.citizenid
    local myXP = Player.Functions.GetRep(Cfg.RepName) or 0
    local myRank, myWeekXP
    for i, e in ipairs(source_) do
        if e.citizenid == myCid then myRank, myWeekXP = i, e.xp break end
    end

    local top = {}
    for i = 1, math.min(Cfg.Leaderboard.ShowTop, #source_) do
        local e = source_[i]
        local lvl = e.level and e or HuntingXP.GetLevelData(e.xp)
        top[i] = { rank = i, name = e.name, xp = e.xp, level = lvl.level, label = lvl.label, me = e.citizenid == myCid }
        if weekly then top[i].level, top[i].label = nil, nil end
    end

    local lvl, nextLvl = HuntingXP.GetLevelData(myXP)
    local unclaimed = 0
    if weeklyEnabled() then
        unclaimed = MySQL.scalar.await('SELECT COALESCE(SUM(cash), 0) FROM hunting_weekly_rewards WHERE citizenid = ? AND claimed = 0', { myCid }) or 0
    end
    return {
        mode = weekly and 'weekly' or 'all',
        weeklyEnabled = weeklyEnabled() and true or false,
        top = top,
        total = #source_,
        bounties = HuntingBounty.List(),
        rewards = weeklyEnabled() and Cfg.Weekly.Rewards or {},
        unclaimed = tonumber(unclaimed) or 0,
        me = {
            rank = myRank,
            xp = myXP,
            weekXP = myWeekXP or 0,
            level = lvl.level,
            label = lvl.label,
            levelXP = lvl.xp,
            nextXP = nextLvl and nextLvl.xp or nil,
            perks = lvl.perks or {},
        }
    }
end
RSGCore.Functions.CreateCallback('rsg-hunting:server:getLeaderboard', function(src, cb, mode)
    local ok, result = pcall(handler_getLeaderboard, src, mode)
    if not ok then print(('[rsg-hunting] leaderboard error: %s'):format(tostring(result))) end
    cb(ok and result or nil)
end)

AddEventHandler('playerDropped', function()
    lastRequest[source] = nil
    claiming[source] = nil
end)
