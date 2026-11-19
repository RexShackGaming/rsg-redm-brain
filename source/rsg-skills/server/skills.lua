-- rsg-skills: skill definitions, XP, levels, perks, exports
RSGSkills = RSGSkills or {}
local RSGCore = exports['rsg-core']:GetCoreObject()
local TAG = '[rsg-skills]'

RSGSkills.XP_LIMIT = 2000000000 -- stays well inside INT UNSIGNED
RSGSkills.Defs = {}
RSGSkills.Order = {}
local Defs, Order = RSGSkills.Defs, RSGSkills.Order

------------------------------------------
-- definitions
------------------------------------------
local function rebuildOrder()
    for i = #Order, 1, -1 do Order[i] = nil end
    for key in pairs(Defs) do Order[#Order + 1] = key end
    table.sort(Order, function(a, b)
        local oa, ob = Defs[a].order, Defs[b].order
        if oa ~= ob then return oa < ob end
        return a < b
    end)
end

-- cumulative XP needed for every level of a skill
local function buildThresholds(def)
    local t = { [1] = 0 }
    for lvl = 2, def.maxLevel do
        t[lvl] = math.floor(def.curve.Base * ((lvl - 1) ^ def.curve.Growth))
        if t[lvl] <= t[lvl - 1] then t[lvl] = t[lvl - 1] + 1 end -- always strictly increasing
    end
    def.thresholds = t
end

---@param key string lowercase letters, numbers and underscores
---@param def table see Config.Skills
---@return boolean ok, string? reason
function RSGSkills.RegisterSkill(key, def)
    if type(key) ~= 'string' or #key > 50 or not key:match('^[%l%d_]+$') then return false, 'invalid_key' end
    if type(def) ~= 'table' then def = {} end

    local base = Config.Curve
    local curve = type(def.curve) == 'table' and def.curve or {}
    local d = {
        key = key,
        label = type(def.label) == 'string' and def.label or ('skill_' .. key),
        description = type(def.description) == 'string' and def.description or ('skill_' .. key .. '_desc'),
        order = tonumber(def.order) or 100,
        maxLevel = math.max(1, math.min(100, math.floor(tonumber(def.maxLevel) or base.MaxLevel))),
        curve = {
            Base = tonumber(curve.Base) or base.Base,
            Growth = tonumber(curve.Growth) or base.Growth,
        },
        xpMultiplier = tonumber(def.xpMultiplier) or 1.0,
        repImport = type(def.repImport) == 'string' and def.repImport ~= '' and def.repImport or nil,
        perks = {},
    }
    if d.curve.Base <= 0 then d.curve.Base = base.Base end
    if d.curve.Growth <= 0 then d.curve.Growth = base.Growth end
    if d.xpMultiplier <= 0 then d.xpMultiplier = 1.0 end

    if type(def.perks) == 'table' then
        for perkKey, p in pairs(def.perks) do
            if type(perkKey) == 'string' and type(p) == 'table' and type(p.levels) == 'table' then
                local entries = {}
                for rawLevel, rawValue in pairs(p.levels) do
                    local lvl, val = tonumber(rawLevel), tonumber(rawValue)
                    if lvl and val and lvl >= 1 then
                        entries[#entries + 1] = { level = math.floor(lvl), value = val }
                    end
                end
                table.sort(entries, function(a, b) return a.level < b.level end)
                if #entries > 0 then
                    d.perks[perkKey] = { suffix = type(p.suffix) == 'string' and p.suffix or '', entries = entries }
                end
            end
        end
    end

    buildThresholds(d)
    Defs[key] = d
    rebuildOrder()
    return true
end

for key, def in pairs(Config.Skills or {}) do
    local ok, reason = RSGSkills.RegisterSkill(key, def)
    if not ok then print(('%s ^1skipped skill "%s" in config: %s^7'):format(TAG, tostring(key), tostring(reason))) end
end

------------------------------------------
-- maths helpers
------------------------------------------
local function levelFromXP(def, xp)
    local t = def.thresholds
    for lvl = def.maxLevel, 1, -1 do
        if xp >= t[lvl] then return lvl end
    end
    return 1
end

local function rankLabel(level)
    local ranks = Config.Ranks or {}
    local label, best = ranks[1] and ranks[1].label or '', -1
    for _, r in ipairs(ranks) do
        if r.level <= level and r.level > best then best, label = r.level, r.label end
    end
    return label
end

local function perkValue(def, perkKey, level)
    local p = def.perks[perkKey]
    if not p then return 0 end
    local val = 0
    for _, e in ipairs(p.entries) do
        if e.level <= level then val = e.value else break end
    end
    return val
end

local function sortedPerkKeys(def)
    local keys = {}
    for k in pairs(def.perks) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

------------------------------------------
-- XP boost (temporary server-wide multiplier, kept in memory only)
------------------------------------------
local boost = { mult = 1.0, untilTime = 0 }

local function boostMultiplier()
    if boost.untilTime > os.time() then return boost.mult end
    return 1.0
end

-- mult <= 1 clears the boost
function RSGSkills.SetBoost(mult, minutes)
    mult = tonumber(mult) or 1.0
    minutes = tonumber(minutes) or 0
    if mult <= 1.0 or minutes <= 0 then
        boost.mult, boost.untilTime = 1.0, 0
        return 1.0, 0
    end
    mult = math.min(mult, tonumber(Config.MaxBoostMultiplier) or 5.0)
    minutes = math.min(minutes, tonumber(Config.MaxBoostMinutes) or 1440)
    boost.mult, boost.untilTime = mult, os.time() + math.floor(minutes * 60)
    return boost.mult, math.floor(minutes)
end

function RSGSkills.GetBoost()
    local remaining = boost.untilTime - os.time()
    if remaining > 0 then return boost.mult, remaining end
    return 1.0, 0
end

------------------------------------------
-- client sync (the client keeps a read-only mirror for its own exports)
------------------------------------------
local function syncEntry(c, key)
    local def = Defs[key]
    local xp = c.xp[key] or 0
    local level = levelFromXP(def, xp)
    local perks = {}
    for pk in pairs(def.perks) do perks[pk] = perkValue(def, pk, level) end
    return { xp = xp, level = level, perks = perks }
end

function RSGSkills.SyncClient(src, onlySkill)
    local c = RSGSkills.Load(src)
    if not c then return end
    local payload = {}
    if onlySkill and Defs[onlySkill] then
        payload[onlySkill] = syncEntry(c, onlySkill)
    else
        onlySkill = nil
        for key in pairs(Defs) do payload[key] = syncEntry(c, key) end
    end
    TriggerClientEvent('rsg-skills:client:sync', src, payload, onlySkill ~= nil)
end

------------------------------------------
-- changing XP
------------------------------------------
local function addWeekly(c, skill, gained)
    if not (Config.Weekly and Config.Weekly.Enabled) or gained <= 0 then return end
    local key = ('%s:%d'):format(skill, RSGSkills.WeekNumber())
    c.weekly[key] = (c.weekly[key] or 0) + gained
end

local function notify(src, data)
    TriggerClientEvent('RSGCore:Client:Notify', src, data)
end

-- common tail of every XP change: sync the client, notify, fire the level-up event
local function afterChange(src, c, skill, before, after, gained, silent)
    local def = Defs[skill]
    local oldLevel, newLevel = levelFromXP(def, before), levelFromXP(def, after)
    RSGSkills.SyncClient(src, skill)

    if silent then return end

    if gained > 0 and Config.NotifyXP then
        notify(src, {
            id = 'rsg-skills-xp-' .. skill,
            title = locale('notify_title'),
            description = locale('xp_gained', gained, locale(def.label)),
            type = 'inform',
            duration = 3500,
        })
    end

    if newLevel > oldLevel then
        if Config.NotifyLevelUp then
            notify(src, {
                title = locale('levelup_title'),
                description = locale('levelup_desc', locale(def.label), newLevel, locale(rankLabel(newLevel))),
                type = 'success',
                duration = 9000,
            })
        end
        TriggerEvent('rsg-skills:server:levelUp', src, skill, newLevel, oldLevel)
        TriggerClientEvent('rsg-skills:client:levelUp', src, skill, newLevel)
    end
end

---@param src number
---@param skill string
---@param amount number base XP (multipliers are applied unless opts.raw)
---@param reason? string free text, for your own logging
---@param opts? { raw?: boolean, noWeekly?: boolean }
---@return boolean ok, number|string? xpOrReason, number? level
function RSGSkills.AddXP(src, skill, amount, reason, opts)
    src = tonumber(src)
    local def = Defs[skill]
    if not def then return false, 'unknown_skill' end
    amount = tonumber(amount)
    if not src or not amount or amount ~= amount or amount <= 0 or amount == math.huge then
        return false, 'invalid_amount'
    end

    local c = RSGSkills.Load(src)
    if not c then return false, 'no_player' end

    local raw = type(opts) == 'table' and opts.raw == true
    if raw then
        amount = math.floor(amount)
    else
        amount = amount * def.xpMultiplier * (tonumber(Config.XPMultiplier) or 1.0) * boostMultiplier()
        amount = math.max(1, math.floor(amount + 0.5))
        amount = math.min(amount, math.max(1, math.floor(tonumber(Config.MaxXPPerAward) or 1000)))
    end
    if amount < 1 then return false, 'invalid_amount' end

    local before = c.xp[skill] or 0
    local after = math.min(before + amount, RSGSkills.XP_LIMIT)
    local gained = after - before
    if gained <= 0 then return false, 'xp_limit' end

    c.xp[skill] = after
    c.dirty[skill] = true
    if not (type(opts) == 'table' and opts.noWeekly) then addWeekly(c, skill, gained) end

    afterChange(src, c, skill, before, after, gained, false)
    return true, after, levelFromXP(def, after)
end

-- lowers XP (never below 0). Levels can drop. Not notified.
function RSGSkills.RemoveXP(src, skill, amount)
    src = tonumber(src)
    local def = Defs[skill]
    if not def then return false, 'unknown_skill' end
    amount = tonumber(amount)
    if not src or not amount or amount ~= amount or amount <= 0 or amount == math.huge then
        return false, 'invalid_amount'
    end
    local c = RSGSkills.Load(src)
    if not c then return false, 'no_player' end

    local before = c.xp[skill] or 0
    local after = math.max(0, before - math.floor(amount))
    c.xp[skill] = after
    c.dirty[skill] = true
    afterChange(src, c, skill, before, after, 0, true)
    return true, after, levelFromXP(def, after)
end

-- sets the exact XP. Not notified, does not count toward weekly boards.
function RSGSkills.SetXP(src, skill, xp)
    src = tonumber(src)
    local def = Defs[skill]
    if not def then return false, 'unknown_skill' end
    xp = tonumber(xp)
    if not src or not xp or xp ~= xp then return false, 'invalid_amount' end
    local c = RSGSkills.Load(src)
    if not c then return false, 'no_player' end

    xp = math.max(0, math.min(math.floor(xp), RSGSkills.XP_LIMIT))
    local before = c.xp[skill] or 0
    c.xp[skill] = xp
    c.dirty[skill] = true
    afterChange(src, c, skill, before, xp, 0, true)
    return true, xp, levelFromXP(def, xp)
end

-- sets the level (XP becomes the minimum for that level)
function RSGSkills.SetLevel(src, skill, level)
    local def = Defs[skill]
    if not def then return false, 'unknown_skill' end
    level = tonumber(level)
    if not level or level ~= level then return false, 'invalid_amount' end
    level = math.max(1, math.min(def.maxLevel, math.floor(level)))
    return RSGSkills.SetXP(src, skill, def.thresholds[level])
end

------------------------------------------
-- reading
------------------------------------------
function RSGSkills.GetXP(src, skill)
    if not Defs[skill] then return 0 end
    local c = RSGSkills.Load(src)
    return c and (c.xp[skill] or 0) or 0
end

function RSGSkills.GetLevel(src, skill)
    local def = Defs[skill]
    if not def then return 1, 1 end
    local c = RSGSkills.Load(src)
    return levelFromXP(def, c and (c.xp[skill] or 0) or 0), def.maxLevel
end

function RSGSkills.HasLevel(src, skill, level)
    local lvl = RSGSkills.GetLevel(src, skill)
    return lvl >= (tonumber(level) or 1)
end

function RSGSkills.GetPerk(src, skill, perk)
    local def = Defs[skill]
    if not def or not def.perks[perk] then return 0 end
    return perkValue(def, perk, (RSGSkills.GetLevel(src, skill)))
end

local function progressTable(def, xp)
    local level = levelFromXP(def, xp)
    local floorXP = def.thresholds[level]
    local nextXP = level < def.maxLevel and def.thresholds[level + 1] or nil
    local pct = 100
    if nextXP and nextXP > floorXP then
        pct = math.max(0, math.min(100, math.floor((xp - floorXP) / (nextXP - floorXP) * 100)))
    end
    return { xp = xp, level = level, maxLevel = def.maxLevel, floorXP = floorXP, nextXP = nextXP, pct = pct }
end

function RSGSkills.GetProgress(src, skill)
    local def = Defs[skill]
    if not def then return nil end
    local c = RSGSkills.Load(src)
    return progressTable(def, c and (c.xp[skill] or 0) or 0)
end

function RSGSkills.GetSkills(src)
    local c = RSGSkills.Load(src)
    if not c then return {} end
    local out = {}
    for key in pairs(Defs) do out[key] = syncEntry(c, key) end
    return out
end

function RSGSkills.GetSkillDefinitions()
    local out = {}
    for _, key in ipairs(Order) do
        local def = Defs[key]
        local perks = {}
        for _, pk in ipairs(sortedPerkKeys(def)) do perks[#perks + 1] = pk end
        out[#out + 1] = { key = key, label = def.label, description = def.description, maxLevel = def.maxLevel, perks = perks }
    end
    return out
end

-- works for offline players (reads the database when the player is not loaded)
function RSGSkills.GetLevelByCitizenId(citizenid, skill)
    local def = Defs[skill]
    if not def or type(citizenid) ~= 'string' then return 1 end
    local c = RSGSkills.Cache[citizenid]
    if c then return levelFromXP(def, c.xp[skill] or 0) end
    if not RSGSkills.WaitReady() then return 1 end
    local xp = MySQL.scalar.await('SELECT xp FROM rsg_skills WHERE citizenid = ? AND skill = ?', { citizenid, skill })
    return levelFromXP(def, tonumber(xp) or 0)
end

------------------------------------------
-- data for the NUI panel
------------------------------------------
function RSGSkills.BuildPanel(src)
    local c = RSGSkills.Load(src)
    if not c then return nil end

    local list, totalLevel, totalXP, maxTotal = {}, 0, 0, 0
    for _, key in ipairs(Order) do
        local def = Defs[key]
        local xp = c.xp[key] or 0
        local prog = progressTable(def, xp)

        local perks = {}
        for _, pk in ipairs(sortedPerkKeys(def)) do
            local p = def.perks[pk]
            local nextLevel, nextValue
            for _, e in ipairs(p.entries) do
                if e.level > prog.level then nextLevel, nextValue = e.level, e.value break end
            end
            perks[#perks + 1] = {
                key = pk,
                label = 'perk_' .. pk,
                suffix = p.suffix,
                value = perkValue(def, pk, prog.level),
                nextLevel = nextLevel,
                nextValue = nextValue,
            }
        end

        list[#list + 1] = {
            key = key,
            label = def.label,
            description = def.description,
            rank = rankLabel(prog.level),
            level = prog.level,
            maxLevel = def.maxLevel,
            xp = xp,
            floorXP = prog.floorXP,
            nextXP = prog.nextXP,
            pct = prog.pct,
            perks = perks,
        }
        totalLevel = totalLevel + prog.level
        totalXP = totalXP + xp
        maxTotal = maxTotal + def.maxLevel
    end

    local mult, remaining = RSGSkills.GetBoost()
    return {
        skills = list,
        totalLevel = totalLevel,
        maxTotalLevel = maxTotal,
        totalXP = totalXP,
        boost = remaining > 0 and { mult = mult, minutes = math.ceil(remaining / 60) } or nil,
    }
end

-- used by the leaderboard to turn XP into a level
function RSGSkills.LevelOfXP(skill, xp)
    local def = Defs[skill]
    if not def then return nil end
    return levelFromXP(def, tonumber(xp) or 0), rankLabel(levelFromXP(def, tonumber(xp) or 0))
end

------------------------------------------
-- events and callbacks
------------------------------------------
AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source
    if not src then return end
    CreateThread(function()
        if RSGSkills.Load(src) then RSGSkills.SyncClient(src) end
    end)
end)

-- the panel is read-only; one request per half second per player is plenty
local lastPanel = {}
RSGCore.Functions.CreateCallback('rsg-skills:server:getSkills', function(src, cb)
    local now = GetGameTimer()
    if lastPanel[src] and now - lastPanel[src] < 500 then return cb(nil) end
    lastPanel[src] = now
    local ok, result = pcall(RSGSkills.BuildPanel, src)
    if not ok then print(('%s ^1panel error: %s^7'):format(TAG, tostring(result))) end
    cb(ok and result or nil)
end)

AddEventHandler('playerDropped', function() lastPanel[source] = nil end)

------------------------------------------
-- exports (server only: the client can never award XP)
------------------------------------------
exports('AddXP', function(...) return RSGSkills.AddXP(...) end)
exports('RemoveXP', function(...) return RSGSkills.RemoveXP(...) end)
exports('SetXP', function(...) return RSGSkills.SetXP(...) end)
exports('SetLevel', function(...) return RSGSkills.SetLevel(...) end)
exports('GetXP', function(...) return RSGSkills.GetXP(...) end)
exports('GetLevel', function(...) return RSGSkills.GetLevel(...) end)
exports('HasLevel', function(...) return RSGSkills.HasLevel(...) end)
exports('GetPerk', function(...) return RSGSkills.GetPerk(...) end)
exports('GetProgress', function(...) return RSGSkills.GetProgress(...) end)
exports('GetSkills', function(...) return RSGSkills.GetSkills(...) end)
exports('GetSkillDefinitions', function(...) return RSGSkills.GetSkillDefinitions(...) end)
exports('GetLevelByCitizenId', function(...) return RSGSkills.GetLevelByCitizenId(...) end)
exports('RegisterSkill', function(...) return RSGSkills.RegisterSkill(...) end)
exports('GetBoost', function(...) return RSGSkills.GetBoost(...) end)
