local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

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

function HuntingXP.Award(src, amount)
    amount = math.floor(tonumber(amount) or 0)
    if not Cfg or not Cfg.Enabled or amount <= 0 then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local before = Player.Functions.GetRep(Cfg.RepName) or 0
    Player.Functions.AddRep(Cfg.RepName, amount)
    local after = before + amount

    if Cfg.Notify then
        TriggerClientEvent('ox_lib:notify', src, {
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
        TriggerClientEvent('ox_lib:notify', src, {
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

local lastRequest = {}
lib.callback.register('rsg-hunting:server:getLeaderboard', function(src)
    if not Cfg or not Cfg.Enabled then return nil end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end

    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < 2000 then return nil end
    lastRequest[src] = now

    if os.time() - Board.updated >= Cfg.Leaderboard.CacheSeconds then
        refreshBoard()
    end

    local myCid = Player.PlayerData.citizenid
    local myXP = Player.Functions.GetRep(Cfg.RepName) or 0
    local myRank
    for i, e in ipairs(Board.list) do
        if e.citizenid == myCid then myRank = i break end
    end

    local top = {}
    for i = 1, math.min(Cfg.Leaderboard.ShowTop, #Board.list) do
        local e = Board.list[i]
        top[i] = { rank = i, name = e.name, xp = e.xp, level = e.level, label = e.label, me = e.citizenid == myCid }
    end

    local lvl, nextLvl = HuntingXP.GetLevelData(myXP)
    return {
        top = top,
        total = #Board.list,
        me = {
            rank = myRank,
            xp = myXP,
            level = lvl.level,
            label = lvl.label,
            levelXP = lvl.xp,
            nextXP = nextLvl and nextLvl.xp or nil,
            perks = lvl.perks or {},
        }
    }
end)

AddEventHandler('playerDropped', function()
    lastRequest[source] = nil
end)
