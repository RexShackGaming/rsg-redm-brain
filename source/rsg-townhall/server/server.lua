local RSGCore = exports['rsg-core']:GetCoreObject()

local Locations = {}      -- [id] = { id, label, x, y, z, h }
local ManagerCache = {}   -- [citizenid] = { ['*'] = true, police = true }
local LastAction = {}

local BlockedJobs, PostableJobs, PrereqItems = {}, {}, {}
for _, j in ipairs(Config.BlockedJobs or {}) do BlockedJobs[j] = true end
for _, j in ipairs(Config.PostableJobs or {}) do PostableJobs[j] = true end
for _, i in ipairs(Config.PrerequisiteItems or {}) do PrereqItems[i] = true end
local HasPostableFilter = next(PostableJobs) ~= nil

-- application states that still need a decision
local ACTIVE = "('pending', 'interview')"
-- SQL: the application's claim is still fresh (see Config.ClaimMinutes)
local CLAIM_FRESH = ("(a.claimed_at IS NOT NULL AND a.claimed_at > DATE_SUB(NOW(), INTERVAL %d MINUTE))"):format(math.max(1, math.floor(tonumber(Config.ClaimMinutes) or 30)))

---------------------------------------------------------------------------
-- Database (tables come from install.sql so both always match)
---------------------------------------------------------------------------
-- Columns added after the first release; added safely to existing tables.
local MIGRATIONS = {
    { 'townhall_postings', 'slots', 'INT NOT NULL DEFAULT 1' },
    { 'townhall_postings', 'filled_count', 'INT NOT NULL DEFAULT 0' },
    { 'townhall_postings', 'expires_at', 'TIMESTAMP NULL DEFAULT NULL' },
    { 'townhall_postings', 'location_id', 'INT NOT NULL DEFAULT 0' },
    { 'townhall_postings', 'req_items', 'TEXT NULL' },
    { 'townhall_postings', 'req_job', "VARCHAR(50) NOT NULL DEFAULT ''" },
    { 'townhall_postings', 'req_job_grade', 'INT NOT NULL DEFAULT 0' },
    { 'townhall_applications', 'interview_note', 'TEXT NULL' },
    { 'townhall_applications', 'granted', 'TINYINT(1) NOT NULL DEFAULT 1' },
    { 'townhall_applications', 'notified', 'TINYINT(1) NOT NULL DEFAULT 1' },
    { 'townhall_postings', 'warned', 'TINYINT(1) NOT NULL DEFAULT 0' },
    { 'townhall_applications', 'fee', 'INT NOT NULL DEFAULT 0' },
    { 'townhall_applications', 'refund', 'INT NOT NULL DEFAULT 0' },
    { 'townhall_postings', 'req_extra', 'TEXT NULL' },
    { 'townhall_postings', 'probation_days', 'INT NOT NULL DEFAULT 0' },
    { 'townhall_applications', 'claimed_by', 'VARCHAR(50) NULL' },
    { 'townhall_applications', 'claimed_by_name', 'VARCHAR(100) NULL' },
    { 'townhall_applications', 'claimed_at', 'TIMESTAMP NULL DEFAULT NULL' },
}

local function ensureDatabase()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'install.sql')
    if not sql then
        print('^1[rsg-townhall] install.sql not found^7')
        return false
    end
    for stmt in sql:gmatch('([^;]+);') do
        if stmt:find('%S') then
            local ok, err = pcall(MySQL.query.await, stmt)
            if not ok then
                print(('^1[rsg-townhall] database error: %s^7'):format(tostring(err)))
                return false
            end
        end
    end
    for _, m in ipairs(MIGRATIONS) do
        local ok, err = pcall(function()
            local exists = MySQL.scalar.await(
                'SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
                { m[1], m[2] })
            if (tonumber(exists) or 0) == 0 then
                MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(m[1], m[2], m[3]))
            end
        end)
        if not ok then
            print(('^1[rsg-townhall] database migration error: %s^7'):format(tostring(err)))
            return false
        end
    end
    print('^2[rsg-townhall] database tables ready^7')
    return true
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function decode(s)
    if type(s) ~= 'string' or s == '' then return nil end
    local ok, res = pcall(json.decode, s)
    return ok and res or nil
end

local function fail(key, ...)
    return { ok = false, err = locale(key or 'err_generic', ...) }
end

local function success(key, ...)
    return { ok = true, msg = key and locale(key, ...) or nil }
end

-- zero-width, bidi-override and soft-hyphen code points: they let a player hide text or make a name
-- read differently in the reviewer's window
local INVISIBLE = { [0x00AD] = true, [0x061C] = true, [0x180E] = true, [0xFEFF] = true }
for cp = 0x200B, 0x200F do INVISIBLE[cp] = true end
for cp = 0x202A, 0x202E do INVISIBLE[cp] = true end
for cp = 0x2060, 0x2064 do INVISIBLE[cp] = true end
for cp = 0x2066, 0x2069 do INVISIBLE[cp] = true end

local function stripInvisible(v)
    if not v:find('[\xC2-\xEF]') then return v end
    local out = {}
    for _, cp in utf8.codes(v) do
        if not INVISIBLE[cp] then out[#out + 1] = utf8.char(cp) end
    end
    return table.concat(out)
end

local function cleanText(v, maxLen, allowEmpty)
    if type(v) ~= 'string' then return nil, 'err_invalid' end
    v = v:gsub('[\0-\8\11\12\14-\31]', '')
    if not utf8.len(v) then return nil, 'err_invalid' end
    v = stripInvisible(v):gsub('^%s+', ''):gsub('%s+$', '')
    local len = utf8.len(v)
    if not len then return nil, 'err_invalid' end
    if len > maxLen then return nil, 'err_too_long' end
    if len == 0 and not allowEmpty then return nil, 'err_required' end
    return v
end

local function throttle(src, key, ms)
    local k = ('%s:%s'):format(src, key)
    local now = GetGameTimer()
    if LastAction[k] and (now - LastAction[k]) < ms then return false end
    LastAction[k] = now
    return true
end

local ScopeCache = {} -- [src] = { at, cid, scope } short-lived, see getScope

AddEventHandler('playerDropped', function()
    ScopeCache[source] = nil
    local prefix = ('%s:'):format(source)
    for k in pairs(LastAction) do
        if k:sub(1, #prefix) == prefix then LastAction[k] = nil end
    end
end)

local function notify(src, description, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('notify_title'),
        description = description,
        type = ntype or 'inform',
        duration = 7000,
    })
end

local function playerName(Player)
    local ci = Player.PlayerData.charinfo or {}
    return ('%s %s'):format(ci.firstname or '?', ci.lastname or '')
end

-- rsg-log + optional Discord webhook (server/sv_config.lua)
local WEBHOOK_COLORS = { green = 3066993, red = 15158332, blue = 3447003, amber = 15844367 }
local function rsgLog(title, color, message)
    TriggerEvent('rsg-log:server:CreateLog', 'townhall', title, color, message)
    if SvConfig and SvConfig.Webhook and SvConfig.Webhook ~= '' then
        PerformHttpRequest(SvConfig.Webhook, function() end, 'POST', json.encode({
            username = SvConfig.Username or 'Town Hall',
            allowed_mentions = { parse = {} }, -- player text must never ping anyone
            embeds = { {
                title = title,
                description = message,
                color = WEBHOOK_COLORS[color] or WEBHOOK_COLORS.blue,
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            } },
        }), { ['Content-Type'] = 'application/json' })
    end
end

-- Nearest clerk within range of the player (id), or nil
local function nearestLocation(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local p = GetEntityCoords(ped)
    local best, bestDist
    for id, l in pairs(Locations) do
        local d = #(p - vector3(l.x, l.y, l.z))
        if d <= Config.ServerDistance and (not bestDist or d < bestDist) then best, bestDist = id, d end
    end
    return best
end

-- Returns Player, nil, locationId  or  nil, localeKey
local function ctx(src, readKey)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil, 'err_generic' end
    -- read callbacks hit the database: stop a modified client from spamming them
    if readKey and not throttle(src, 'r:' .. readKey, 300) then return nil, 'err_slow_down' end
    local locId = nearestLocation(src)
    if not locId then return nil, 'err_too_far' end
    return Player, nil, locId
end

local function itemLabel(item)
    local it = RSGCore.Shared.Items and RSGCore.Shared.Items[item]
    return it and it.label or item
end

---------------------------------------------------------------------------
-- Permissions
---------------------------------------------------------------------------
local function loadManagers()
    ManagerCache = {}
    ScopeCache = {}
    local rows = MySQL.query.await('SELECT citizenid, job FROM townhall_managers') or {}
    for _, r in ipairs(rows) do
        ManagerCache[r.citizenid] = ManagerCache[r.citizenid] or {}
        ManagerCache[r.citizenid][r.job] = true
    end
end

-- Manager entries only count while the player holds Config.ManagerJob (when set)
local function managerActive(src)
    local mj = Config.ManagerJob
    if not mj or mj == '' then return true end
    return exports['rsg-core']:HasPlayerJob(src, mj) and true or false
end

local function buildScope(src, Player)
    local scope = { admin = false, all = false, jobs = {}, any = false, manager = false, managerAll = false, managerJobs = {} }
    if RSGCore.Functions.HasPermission(src, Config.AdminPermission) then
        scope.admin, scope.all, scope.any = true, true, true
        return scope
    end
    local m = ManagerCache[Player.PlayerData.citizenid]
    if m and managerActive(src) then
        for job in pairs(m) do
            if job == '*' then scope.all, scope.managerAll = true, true else scope.jobs[job], scope.managerJobs[job] = true, true end
            scope.any, scope.manager = true, true
        end
    end
    if Config.AllowBossManagement then
        local pj = Player.PlayerData.job
        if pj and pj.isboss and pj.name then
            scope.jobs[pj.name] = true
            scope.any = true
        end
    end
    -- a rank with the society permission may manage vacancies for that job
    if Config.UseSocietyPermission and GetResourceState('rsg-society') == 'started' then
        local perm = Config.SocietyPermission or 'townhall_post'
        for _, pj in ipairs(exports['rsg-core']:GetPlayerJobs(src) or {}) do
            if pj.job and not scope.jobs[pj.job] and not BlockedJobs[pj.job] then
                local ok, has = pcall(function() return exports['rsg-society']:HasPermission(src, pj.job, perm) end)
                if ok and has == true then scope.jobs[pj.job] = true scope.any = true end
            end
        end
    end
    return scope
end

-- permissions are looked up for many players at once (notifications), so keep the result for a moment
local function getScope(src, Player)
    local now, cid = GetGameTimer(), Player.PlayerData.citizenid
    local c = ScopeCache[src]
    if c and c.cid == cid and (now - c.at) < 2000 then return c.scope end
    local scope = buildScope(src, Player)
    ScopeCache[src] = { at = now, cid = cid, scope = scope }
    return scope
end

-- Expiry choices (days) the caller may use; job = the vacancy's job (nil = general)
local function expiryFor(scope, job)
    local cfg = Config.ExpiryOptions
    if type(cfg) ~= 'table' then cfg = { 0 } end
    if cfg[1] ~= nil then return cfg end -- legacy flat list
    local list
    if scope.admin then list = cfg.admin
    elseif job and cfg.jobs and cfg.jobs[job] then list = cfg.jobs[job]
    elseif scope.manager and (job == nil or scope.managerAll or scope.managerJobs[job]) then list = cfg.manager
    else list = cfg.boss end
    if type(list) ~= 'table' or #list == 0 then list = cfg.default end
    if type(list) ~= 'table' or #list == 0 then list = { Config.DefaultExpiryDays or 14 } end
    return list
end

local function expiryAllowed(list, n)
    for _, d in ipairs(list) do if d == n then return true end end
    return false
end

-- default for reopen/repost: Config.DefaultExpiryDays when allowed, else the first timed option
local function defaultExpiry(list)
    if expiryAllowed(list, Config.DefaultExpiryDays) then return Config.DefaultExpiryDays end
    for _, d in ipairs(list) do if d > 0 then return d end end
    return list[1] or 0
end

local function scopeAllows(scope, job)
    return scope.all or scope.jobs[job] == true
end

-- SQL fragment limiting a query to the jobs the caller may manage
local function scopeClause(scope, column)
    if scope.all then return '1 = 1', {} end
    local jobs = {}
    for j in pairs(scope.jobs) do jobs[#jobs + 1] = j end
    if #jobs == 0 then return '1 = 0', {} end
    return ('%s IN (%s)'):format(column, string.rep('?,', #jobs):sub(1, -2)), jobs
end

---------------------------------------------------------------------------
-- Job helpers (job definitions live in the database, served by rsg-core)
---------------------------------------------------------------------------
local function getJobDef(job)
    if type(job) ~= 'string' then return nil end
    return exports['rsg-core']:GetJobDefinition(job)
end

local defCache, defCacheAt = {}, 0
local function defOf(job)
    local now = GetGameTimer()
    if now - defCacheAt > 5000 then defCache, defCacheAt = {}, now end
    local d = defCache[job]
    if d == nil then
        d = getJobDef(job) or false
        defCache[job] = d
    end
    return d or nil
end

local function jobAllowed(job)
    if BlockedJobs[job] then return false end
    if HasPostableFilter and not PostableJobs[job] then return false end
    return true
end

local function gradeOf(def, grade)
    return def and def.grades and def.grades[tostring(grade)] or nil
end

local function jobLabel(def, job) return (def and def.label) or job end

local function listJobs(scope)
    local defs = exports['rsg-core']:GetJobDefinitions() or {}
    local out = {}
    for key, def in pairs(defs) do
        if type(def) == 'table' then
            local name = def.name or key
            if type(name) == 'string' and jobAllowed(name) and scopeAllows(scope, name) then
                local grades = {}
                for gk, g in pairs(def.grades or {}) do
                    local lvl = tonumber(gk)
                    if lvl and not (g.isboss and Config.RestrictBossGrades and not scope.admin) then
                        grades[#grades + 1] = { level = lvl, label = g.name or tostring(lvl), payment = g.payment or 0, isboss = g.isboss and true or false }
                    end
                end
                table.sort(grades, function(a, b) return a.level < b.level end)
                if #grades > 0 then
                    out[#out + 1] = { name = name, label = def.label or name, grades = grades, expiry = expiryFor(scope, name) }
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

-- Every job (name + label), used for the "must already hold job X" prerequisite
local function listAllJobs()
    local defs = exports['rsg-core']:GetJobDefinitions() or {}
    local out = {}
    for key, def in pairs(defs) do
        if type(def) == 'table' then
            local name = def.name or key
            if type(name) == 'string' and not BlockedJobs[name] then
                out[#out + 1] = { name = name, label = def.label or name }
            end
        end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

---------------------------------------------------------------------------
-- Questions + prerequisites
---------------------------------------------------------------------------
local function buildQuestions(row)
    local list = {}
    for _, q in ipairs(Config.Questions or {}) do
        list[#list + 1] = {
            label = locale(q.label), type = q.type or 'textarea',
            required = q.required ~= false, max = q.max or Config.Limits.answer,
        }
    end
    local custom = decode(row.questions)
    if type(custom) == 'table' then
        for _, text in ipairs(custom) do
            if type(text) == 'string' then
                list[#list + 1] = { label = text, type = 'textarea', required = true, max = Config.Limits.answer }
            end
        end
    end
    return list
end

local function skillsOn() return Config.AllowSkillPrerequisites and GetResourceState('rsg-skills') == 'started' end
local function repOn() return Config.AllowReputationPrerequisites and GetResourceState('rsg-reputation') == 'started' end

local function skillDefs()
    if not skillsOn() then return {} end
    local ok, defs = pcall(function() return exports['rsg-skills']:GetSkillDefinitions() end)
    return ok and type(defs) == 'table' and defs or {}
end

local function skillDef(key)
    if type(key) ~= 'string' then return nil end
    for _, d in ipairs(skillDefs()) do if d.key == key then return d end end
end

local function regionList()
    if not repOn() then return {} end
    local ok, regions = pcall(function() return exports['rsg-reputation']:GetRegions() end)
    local out = {}
    if ok and type(regions) == 'table' then
        for key, r in pairs(regions) do out[#out + 1] = { key = key, label = r.label or key, order = r.order or 0 } end
    end
    table.sort(out, function(a, b) return a.order < b.order end)
    return out
end

local function regionLabel(key)
    for _, r in ipairs(regionList()) do if r.key == key then return r.label end end
    return key
end

-- Validates the optional skill / honor / standing requirement a poster typed. Returns table (maybe empty) or nil, errKey
local function readExtra(d)
    local extra = {}
    if type(d) ~= 'table' then return extra end
    if type(d.reqSkill) == 'string' and d.reqSkill ~= '' then
        local def, lvl = skillDef(d.reqSkill), math.tointeger(tonumber(d.reqSkillLevel))
        if not def or not lvl or lvl < 1 or lvl > (tonumber(def.maxLevel) or 1) then return nil, 'err_prereq_invalid' end
        extra.skill = { key = d.reqSkill, level = lvl }
    end
    if d.reqHonor ~= nil and d.reqHonor ~= '' and repOn() then
        local n, r = math.tointeger(tonumber(d.reqHonor)), Config.ReputationLimits.honor
        if not n or n < r[1] or n > r[2] then return nil, 'err_prereq_invalid' end
        extra.honor = n
    end
    if type(d.reqStandingRegion) == 'string' and d.reqStandingRegion ~= '' and repOn() then
        local n, r = math.tointeger(tonumber(d.reqStanding)), Config.ReputationLimits.standing
        if not n or n < r[1] or n > r[2] then return nil, 'err_prereq_invalid' end
        local found = false
        for _, reg in ipairs(regionList()) do if reg.key == d.reqStandingRegion then found = true break end end
        if not found then return nil, 'err_prereq_invalid' end
        extra.standing = { region = d.reqStandingRegion, min = n }
    end
    return extra
end

local function readProbation(v)
    if v == nil then return 0 end
    local n = math.tointeger(tonumber(v))
    if not n then return nil end
    if n == 0 then return 0 end
    for _, d in ipairs(Config.ProbationOptions or {}) do if d == n then return n end end
    return nil
end

-- Returns met (bool), description table for the UI
local function checkPrereq(src, row)
    local items, missing = {}, false
    for _, item in ipairs(decode(row.req_items) or {}) do
        local has = exports['rsg-inventory']:HasItem(src, item, 1) and true or false
        items[#items + 1] = { label = itemLabel(item), met = has }
        if not has then missing = true end
    end
    local job
    if row.req_job and row.req_job ~= '' then
        local held, grade = exports['rsg-core']:HasPlayerJob(src, row.req_job)
        local d = defOf(row.req_job)
        local g = gradeOf(d, row.req_job_grade or 0)
        local ok = held and (tonumber(grade) or 0) >= (row.req_job_grade or 0) or false
        job = { label = jobLabel(d, row.req_job), grade = g and g.name or tostring(row.req_job_grade or 0), met = ok }
        if not ok then missing = true end
    end
    -- rsg-skills / rsg-reputation: a requirement whose resource is stopped counts as met
    local skill, honor, standing
    local extra = decode(row.req_extra)
    if type(extra) == 'table' then
        if type(extra.skill) == 'table' and skillsOn() then
            local ok, has = pcall(function() return exports['rsg-skills']:HasLevel(src, extra.skill.key, extra.skill.level) end)
            local met = ok and has == true
            local def = skillDef(extra.skill.key)
            skill = { label = def and def.label or extra.skill.key, level = extra.skill.level, met = met }
            if not met then missing = true end
        end
        if extra.honor ~= nil and repOn() then
            local ok, has = pcall(function() return exports['rsg-reputation']:HasHonor(src, extra.honor) end)
            local met = ok and has == true
            honor = { min = extra.honor, met = met }
            if not met then missing = true end
        end
        if type(extra.standing) == 'table' and repOn() then
            local ok, has = pcall(function() return exports['rsg-reputation']:HasStanding(src, extra.standing.region, extra.standing.min) end)
            local met = ok and has == true
            standing = { region = regionLabel(extra.standing.region), min = extra.standing.min, met = met }
            if not met then missing = true end
        end
    end
    return not missing, { items = items, job = job, skill = skill, honor = honor, standing = standing }
end

---------------------------------------------------------------------------
-- Notifications to people
---------------------------------------------------------------------------
local function notifyManagers(job, text)
    for _, id in pairs(RSGCore.Functions.GetPlayers()) do
        local P = RSGCore.Functions.GetPlayer(id)
        if P and scopeAllows(getScope(id, P), job) then
            notify(id, text, 'inform')
        end
    end
end

-- rsg-telegram: a letter for someone who is not online (never an error if it is missing)
local function sendTelegram(citizenid, subject, text)
    if not Config.TelegramNotify or GetResourceState('rsg-telegram') ~= 'started' then return false end
    local ok, sent = pcall(function()
        return exports['rsg-telegram']:SendTelegram(citizenid, subject, text, { senderName = Config.TelegramSender or locale('notify_title') })
    end)
    return ok and sent == true
end

-- true = delivered live. withTelegram: an offline citizen gets a telegram instead (returns false then)
local function notifyCitizen(citizenid, text, ntype, withTelegram)
    local P = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if P then
        notify(P.PlayerData.source, text, ntype)
        return true
    end
    if withTelegram then sendTelegram(citizenid, locale('notify_title'), text) end
    return false
end

-- the applicant was told live, so no login reminder is needed for this update
local function markNotified(appId)
    MySQL.update.await('UPDATE townhall_applications SET notified = 1 WHERE id = ?', { appId })
end

-- Pay out application fees owed to this player (vacancy closed before a decision)
local function payRefunds(Player)
    local rows = MySQL.query.await('SELECT id, refund FROM townhall_applications WHERE citizenid = ? AND refund > 0', { Player.PlayerData.citizenid }) or {}
    for _, r in ipairs(rows) do
        -- claim first so a refund can never be paid twice
        if MySQL.update.await('UPDATE townhall_applications SET refund = 0 WHERE id = ? AND refund = ?', { r.id, r.refund }) == 1 then
            Player.Functions.AddMoney(Config.ApplicationFeeAccount or 'cash', r.refund, 'townhall-application-fee-refund')
            notify(Player.PlayerData.source, locale('notify_fee_refunded', r.refund), 'success')
        end
    end
end

-- Probation: the hire keeps the job, but it ends again unless a boss confirms it in time
local function startProbation(cid, name, job, days, appId, source)
    days = math.floor(tonumber(days) or 0)
    if days <= 0 then return end
    MySQL.insert.await("INSERT INTO townhall_probation (citizenid, name, job, application_id, source, ends_at) VALUES (?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? DAY))",
        { cid, name, job, appId, source or 'application', days })
end

-- Close every undecided application of a posting (filled / closed / expired)
local function closePending(postingId, title)
    local rows = MySQL.query.await(("SELECT id, citizenid FROM townhall_applications WHERE posting_id = ? AND status IN %s"):format(ACTIVE), { postingId }) or {}
    if #rows == 0 then return end
    local refund = Config.RefundFeeWhenClosed and ', refund = fee' or ''
    MySQL.update.await(("UPDATE townhall_applications SET status = 'closed', seen = 0, notified = 0, reviewed_at = NOW()%s WHERE posting_id = ? AND status IN %s"):format(refund, ACTIVE), { postingId })
    for _, r in ipairs(rows) do
        if notifyCitizen(r.citizenid, locale('notify_app_closed', title), 'warning') then markNotified(r.id) end
        local P = Config.RefundFeeWhenClosed and RSGCore.Functions.GetPlayerByCitizenId(r.citizenid)
        if P then payRefunds(P) end
    end
end

---------------------------------------------------------------------------
-- Locations (clerks)
---------------------------------------------------------------------------
local function loadLocations()
    Locations = {}
    local rows = MySQL.query.await('SELECT id, label, x, y, z, h FROM townhall_locations') or {}
    for _, r in ipairs(rows) do Locations[r.id] = r end
end

local function syncLocations(target)
    local list = {}
    for _, l in pairs(Locations) do list[#list + 1] = l end
    TriggerClientEvent('rsg-townhall:client:syncLocations', target or -1, list)
end

RSGCore.Functions.CreateCallback('rsg-townhall:server:getLocations', function(source, cb)
    local list = {}
    for _, l in pairs(Locations) do list[#list + 1] = l end
    cb(list)
end)

RSGCore.Commands.Add(Config.Commands.create, locale('cmd_create_help'), { { name = 'name', help = locale('cmd_create_arg') } }, false, function(source, args)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local label = cleanText(table.concat(args, ' '), Config.Limits.label, true)
    if not label or label == '' then label = locale('default_location_label') end
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local id = MySQL.insert.await('INSERT INTO townhall_locations (label, x, y, z, h, created_by) VALUES (?, ?, ?, ?, ?, ?)',
        { label, c.x, c.y, c.z, h, Player.PlayerData.citizenid })
    if not id then return end
    Locations[id] = { id = id, label = label, x = c.x, y = c.y, z = c.z, h = h }
    syncLocations()
    notify(src, locale('notify_location_created', label), 'success')
    rsgLog('Town Hall clerk placed', 'green', ('%s placed clerk #%s (%s)'):format(Player.PlayerData.citizenid, id, label))
end, Config.AdminPermission)

RSGCore.Commands.Add(Config.Commands.remove, locale('cmd_remove_help'), {}, false, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local p = GetEntityCoords(ped)
    local best, bestDist
    for id, l in pairs(Locations) do
        local d = #(p - vector3(l.x, l.y, l.z))
        if d <= 5.0 and (not bestDist or d < bestDist) then best, bestDist = id, d end
    end
    if not best then notify(src, locale('notify_no_location_near'), 'error') return end
    MySQL.update.await('DELETE FROM townhall_locations WHERE id = ?', { best })
    -- vacancies tied to this clerk become available at every clerk
    MySQL.update.await('UPDATE townhall_postings SET location_id = 0 WHERE location_id = ?', { best })
    Locations[best] = nil
    syncLocations()
    notify(src, locale('notify_location_removed'), 'success')
    rsgLog('Town Hall clerk removed', 'red', ('%s removed clerk #%s'):format(Player.PlayerData.citizenid, best))
end, Config.AdminPermission)

---------------------------------------------------------------------------
-- Offline approvals: grant the job when the applicant is online
---------------------------------------------------------------------------
-- granted: 0 = waiting for login, 1 = granted, 2 = skipped/failed, 3 = being processed
local function grantPending(Player)
    local src, cid = Player.PlayerData.source, Player.PlayerData.citizenid
    local rows = MySQL.query.await([[
        SELECT a.id, a.applicant_name, p.job, p.grade, p.title, p.probation_days FROM townhall_applications a
        JOIN townhall_postings p ON p.id = a.posting_id
        WHERE a.citizenid = ? AND a.status = 'approved' AND a.granted = 0]], { cid }) or {}
    for _, r in ipairs(rows) do
        local claimed = MySQL.update.await('UPDATE townhall_applications SET granted = 3 WHERE id = ? AND granted = 0', { r.id })
        if claimed == 1 then
            if exports['rsg-core']:HasPlayerJob(src, r.job) then
                MySQL.update.await('UPDATE townhall_applications SET granted = 2 WHERE id = ?', { r.id })
            else
                local ok, reason = exports['rsg-core']:AddPlayerJob(src, r.job, tonumber(r.grade), Config.BypassMaxJobs)
                if ok then
                    MySQL.update.await('UPDATE townhall_applications SET granted = 1, seen = 0, notified = 1 WHERE id = ?', { r.id })
                    if Config.SetActiveJobOnApproval then Player.Functions.SetJob(r.job, tonumber(r.grade)) end
                    startProbation(cid, r.applicant_name, r.job, r.probation_days, r.id, 'application')
                    notify(src, locale('notify_app_approved', r.title), 'success')
                    rsgLog('Queued job granted', 'green', ('%s received %s grade %s (application #%s)'):format(cid, r.job, r.grade, r.id))
                elseif reason == 'max_jobs' then
                    MySQL.update.await('UPDATE townhall_applications SET granted = 0 WHERE id = ?', { r.id })
                    notify(src, locale('notify_grant_blocked', r.title), 'warning')
                else
                    MySQL.update.await('UPDATE townhall_applications SET granted = 2 WHERE id = ?', { r.id })
                    rsgLog('Queued job failed', 'red', ('application #%s could not be granted (%s)'):format(r.id, tostring(reason)))
                end
            end
        end
    end
end

-- Undecided applications the caller is allowed to review
local function pendingReviewCount(scope)
    if not scope.any then return 0 end
    local clause, params = scopeClause(scope, 'p.job')
    return MySQL.scalar.await(("SELECT COUNT(*) FROM townhall_applications a JOIN townhall_postings p ON p.id = a.posting_id WHERE %s AND a.status IN %s"):format(clause, ACTIVE), params) or 0
end

---------------------------------------------------------------------------
-- Permissions callback
---------------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-townhall:server:getPerms', function(source, cb)
    local Player, err = ctx(source, 'perms')
    if not Player then cb(fail(err)) return end
    local scope = getScope(source, Player)
    grantPending(Player)
    local unseen = MySQL.scalar.await("SELECT COUNT(*) FROM townhall_applications a JOIN townhall_postings p ON p.id = a.posting_id WHERE a.citizenid = ? AND a.seen = 0", { Player.PlayerData.citizenid }) or 0
    -- open invitations also light the "My Applications" badge until they are answered
    unseen = unseen + (MySQL.scalar.await("SELECT COUNT(*) FROM townhall_invites WHERE citizenid = ? AND status = 'pending' AND (expires_at IS NULL OR expires_at > NOW())", { Player.PlayerData.citizenid }) or 0)
    local pendingReview = pendingReviewCount(scope)
    local loc = Locations[nearestLocation(source)]
    cb({
        ok = true, admin = scope.admin, manage = scope.any, unseen = unseen, pending = pendingReview,
        location = loc and loc.label or '',
        maxCustom = Config.MaxCustomQuestions, limits = Config.Limits,
        minFeedback = Config.RequireFeedback and Config.MinFeedbackLength or 0,
        offlineApproval = Config.AllowOfflineApproval, interviews = Config.AllowInterviews,
        messages = Config.AllowMessages, editApps = Config.AllowEditApplication,
        allowResign = Config.AllowResign, maxSlots = Config.MaxSlots,
        expiryOptions = expiryFor(scope), defaultExpiry = defaultExpiry(expiryFor(scope)), maxPrereqItems = Config.MaxPrerequisiteItems,
        invites = Config.AllowInvites, claim = Config.AllowClaim, bulk = Config.AllowBulkReview and math.max(1, Config.MaxBulkReview or 10) or 0,
        probationOptions = Config.ProbationOptions or { 0 }, statsDays = Config.StatsDays or { 30 }, canExport = scope.admin,
    })
end)

---------------------------------------------------------------------------
-- Vacancies + applying
---------------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-townhall:server:getVacancies', function(source, cb)
    local Player, err, locId = ctx(source, 'vac')
    if not Player then cb(fail(err)) return end
    local cid = Player.PlayerData.citizenid

    local rows = MySQL.query.await([[
        SELECT id, job, grade, title, description, requirements, questions, slots, filled_count, req_items, req_job, req_job_grade,
               req_extra, probation_days, posted_by_name, UNIX_TIMESTAMP(created_at) AS created,
               IF(expires_at IS NULL, NULL, GREATEST(0, UNIX_TIMESTAMP(expires_at) - UNIX_TIMESTAMP())) AS expires_in
        FROM townhall_postings
        WHERE status = 'open' AND filled_count < slots AND (expires_at IS NULL OR expires_at > NOW())
          AND (location_id = 0 OR location_id = ?)
        ORDER BY id DESC]], { locId }) or {}

    local mine = MySQL.query.await(
        "SELECT posting_id, status, granted, GREATEST(0, UNIX_TIMESTAMP(reviewed_at) + ? - UNIX_TIMESTAMP()) AS wait FROM townhall_applications WHERE citizenid = ? ORDER BY id DESC",
        { (Config.ReapplyCooldownHours or 0) * 3600, cid }) or {}
    local resigned = MySQL.query.await(
        "SELECT job, MAX(GREATEST(0, UNIX_TIMESTAMP(created_at) + ? - UNIX_TIMESTAMP())) AS wait FROM townhall_resignations WHERE citizenid = ? GROUP BY job",
        { (Config.ResignCooldownHours or 0) * 3600, cid }) or {}

    local pending, wait, resignWait = {}, {}, {}
    for _, a in ipairs(mine) do
        if a.status == 'pending' or a.status == 'interview' or (a.status == 'approved' and a.granted ~= 1) then pending[a.posting_id] = true end
        if a.status == 'rejected' and (a.wait or 0) > 0 and (not wait[a.posting_id] or a.wait > wait[a.posting_id]) then
            wait[a.posting_id] = a.wait
        end
    end
    for _, r in ipairs(resigned) do resignWait[r.job] = tonumber(r.wait) or 0 end

    local blockedAll, blockedJobs = false, {}
    if Config.AllowBlacklist then
        for _, b in ipairs(MySQL.query.await('SELECT job FROM townhall_blacklist WHERE citizenid = ?', { cid }) or {}) do
            if b.job == '*' then blockedAll = true else blockedJobs[b.job] = true end
        end
    end

    local heldJobs = {}
    for _, pj in ipairs(exports['rsg-core']:GetPlayerJobs(source) or {}) do heldJobs[pj.job] = true end

    local out = {}
    for _, r in ipairs(rows) do
        local def = defOf(r.job)
        local g = gradeOf(def, r.grade)
        local met, prereqs = checkPrereq(source, r)
        local w = math.max(wait[r.id] or 0, resignWait[r.job] or 0)
        local state = 'open'
        if heldJobs[r.job] then state = 'holds'
        elseif blockedAll or blockedJobs[r.job] then state = 'blocked'
        elseif pending[r.id] then state = 'applied'
        elseif w > 0 then state = 'cooldown'
        elseif not met then state = 'locked' end
        out[#out + 1] = {
            id = r.id, title = r.title, job = r.job, jobLabel = jobLabel(def, r.job),
            gradeLabel = g and g.name or tostring(r.grade), pay = g and g.payment or 0,
            description = r.description, requirements = r.requirements,
            postedBy = r.posted_by_name, created = r.created,
            openings = r.slots - r.filled_count, slots = r.slots, expiresIn = r.expires_in,
            prereqs = prereqs, questions = buildQuestions(r), state = state, wait = w, fee = Config.ApplicationFee or 0,
            probation = tonumber(r.probation_days) or 0,
        }
    end
    cb({ ok = true, vacancies = out })
end)

RSGCore.Functions.CreateCallback('rsg-townhall:server:apply', function(source, cb, payload)
    local src = source
    local Player, err, locId = ctx(src)
    if not Player then cb(fail(err)) return end
    if type(payload) ~= 'table' then cb(fail('err_invalid')) return end
    if not throttle(src, 'apply', 2000) then cb(fail('err_slow_down')) return end

    local postingId = math.tointeger(tonumber(payload.postingId))
    if not postingId or type(payload.answers) ~= 'table' then cb(fail('err_invalid')) return end
    local cid = Player.PlayerData.citizenid

    local posting = MySQL.single.await([[
        SELECT id, job, grade, title, questions, status, slots, filled_count, req_items, req_job, req_job_grade, req_extra, location_id,
               (expires_at IS NOT NULL AND expires_at <= NOW()) AS expired
        FROM townhall_postings WHERE id = ?]], { postingId })
    if not posting or posting.status ~= 'open' or posting.filled_count >= posting.slots or posting.expired == 1 or posting.expired == true then
        cb(fail('err_posting_closed')) return
    end
    if posting.location_id ~= 0 and posting.location_id ~= locId then cb(fail('err_posting_closed')) return end
    if exports['rsg-core']:HasPlayerJob(src, posting.job) then cb(fail('err_has_job')) return end
    if Config.AllowBlacklist and MySQL.scalar.await("SELECT 1 FROM townhall_blacklist WHERE citizenid = ? AND (job = ? OR job = '*') LIMIT 1", { cid, posting.job }) then
        cb(fail('err_blacklisted')) return
    end

    local activeCount = MySQL.scalar.await(("SELECT COUNT(*) FROM townhall_applications WHERE citizenid = ? AND status IN %s"):format(ACTIVE), { cid }) or 0
    if activeCount >= Config.MaxActiveApplications then cb(fail('err_max_apps')) return end

    local cooldown = MySQL.scalar.await([[
        SELECT GREATEST(
            COALESCE((SELECT MAX(GREATEST(0, UNIX_TIMESTAMP(reviewed_at) + ? - UNIX_TIMESTAMP())) FROM townhall_applications
                      WHERE citizenid = ? AND posting_id = ? AND status = 'rejected'), 0),
            COALESCE((SELECT MAX(GREATEST(0, UNIX_TIMESTAMP(created_at) + ? - UNIX_TIMESTAMP())) FROM townhall_resignations
                      WHERE citizenid = ? AND job = ?), 0))]],
        { (Config.ReapplyCooldownHours or 0) * 3600, cid, postingId, (Config.ResignCooldownHours or 0) * 3600, cid, posting.job })
    if tonumber(cooldown) and tonumber(cooldown) > 0 then cb(fail('err_cooldown')) return end

    if not checkPrereq(src, posting) then cb(fail('err_prereq')) return end

    local questions = buildQuestions(posting)
    if #payload.answers ~= #questions then cb(fail('err_invalid')) return end
    local stored = {}
    for i, q in ipairs(questions) do
        local a, aerr = cleanText(payload.answers[i], q.max, true)
        if not a then cb(fail(aerr)) return end
        if q.required and a == '' then cb(fail('err_answers_required')) return end
        stored[#stored + 1] = { q = q.label, a = a }
    end

    local fee, account = math.floor(tonumber(Config.ApplicationFee) or 0), Config.ApplicationFeeAccount or 'cash'
    if fee > 0 then
        if Player.Functions.GetMoney(account) < fee or not Player.Functions.RemoveMoney(account, fee, 'townhall-application-fee') then
            cb(fail('err_no_fee', fee)) return
        end
    end

    local id = MySQL.insert.await(
        "INSERT INTO townhall_applications (posting_id, citizenid, applicant_name, answers, fee) SELECT ?, ?, ?, ?, ? FROM DUAL WHERE EXISTS (SELECT 1 FROM townhall_postings WHERE id = ? AND status = 'open' AND filled_count < slots AND (expires_at IS NULL OR expires_at > NOW())) AND NOT EXISTS (SELECT 1 FROM townhall_applications WHERE posting_id = ? AND citizenid = ? AND (status IN ('pending', 'interview') OR (status = 'approved' AND granted <> 1)))",
        { postingId, cid, playerName(Player), json.encode(stored), fee, postingId, postingId, cid })
    if not id or id == 0 then
        if fee > 0 then Player.Functions.AddMoney(account, fee, 'townhall-application-fee-refund') end
        -- either a duplicate, or the vacancy filled/closed while the form was being processed
        local stillOpen = MySQL.scalar.await("SELECT 1 FROM townhall_postings WHERE id = ? AND status = 'open' AND filled_count < slots LIMIT 1", { postingId })
        cb(fail(stillOpen and 'err_already_applied' or 'err_posting_closed')) return
    end

    notifyManagers(posting.job, locale('notify_new_application', playerName(Player), posting.title))
    rsgLog('Job application', 'blue', ('%s applied for #%s (%s)'):format(cid, postingId, posting.title))
    cb(success('ok_applied'))
end)

RSGCore.Functions.CreateCallback('rsg-townhall:server:getMyApplications', function(source, cb)
    local Player, err = ctx(source, 'apps')
    if not Player then cb(fail(err)) return end
    local rows = MySQL.query.await([[
        SELECT a.id, a.status, a.feedback, a.interview_note, a.granted, a.seen, a.reviewed_by_name, a.answers,
               UNIX_TIMESTAMP(a.created_at) AS created, UNIX_TIMESTAMP(a.reviewed_at) AS reviewed,
               p.title, p.job, p.grade
        FROM townhall_applications a JOIN townhall_postings p ON p.id = a.posting_id
        WHERE a.citizenid = ? ORDER BY a.id DESC LIMIT 50]], { Player.PlayerData.citizenid }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local def = defOf(r.job)
        local g = gradeOf(def, r.grade)
        out[#out + 1] = {
            id = r.id, status = r.status, feedback = r.feedback, interviewNote = r.interview_note,
            queued = r.status == 'approved' and r.granted == 0, unseen = r.seen == 0,
            reviewedBy = r.reviewed_by_name, created = r.created, reviewed = r.reviewed,
            title = r.title, jobLabel = jobLabel(def, r.job), gradeLabel = g and g.name or tostring(r.grade),
            answers = decode(r.answers) or {},
        }
    end
    local invites = {}
    local irows = MySQL.query.await([[
        SELECT id, job, grade, message, invited_by_name, probation_days,
               IF(expires_at IS NULL, NULL, GREATEST(0, UNIX_TIMESTAMP(expires_at) - UNIX_TIMESTAMP())) AS expires_in
        FROM townhall_invites
        WHERE citizenid = ? AND status = 'pending' AND (expires_at IS NULL OR expires_at > NOW())
        ORDER BY id DESC LIMIT 20]], { Player.PlayerData.citizenid }) or {}
    for _, r in ipairs(irows) do
        local def = defOf(r.job)
        local g = gradeOf(def, r.grade)
        invites[#invites + 1] = {
            id = r.id, jobLabel = jobLabel(def, r.job), gradeLabel = g and g.name or tostring(r.grade), pay = g and g.payment or 0,
            message = r.message or '', invitedBy = r.invited_by_name, probation = tonumber(r.probation_days) or 0, expiresIn = r.expires_in,
        }
    end
    cb({ ok = true, applications = out, invites = invites })
end)

RSGCore.Functions.CreateCallback('rsg-townhall:server:markSeen', function(source, cb)
    local Player = ctx(source)
    if not Player then cb({ ok = false }) return end
    MySQL.update.await('UPDATE townhall_applications SET seen = 1 WHERE citizenid = ? AND seen = 0', { Player.PlayerData.citizenid })
    cb({ ok = true })
end)

RSGCore.Functions.CreateCallback('rsg-townhall:server:withdraw', function(source, cb, payload)
    local Player, err = ctx(source)
    if not Player then cb(fail(err)) return end
    local id = type(payload) == 'table' and math.tointeger(tonumber(payload.applicationId))
    if not id then cb(fail('err_invalid')) return end
    local n = MySQL.update.await(("UPDATE townhall_applications SET status = 'withdrawn' WHERE id = ? AND citizenid = ? AND status IN %s"):format(ACTIVE), { id, Player.PlayerData.citizenid })
    if n ~= 1 then cb(fail('err_not_found')) return end
    cb(success('ok_withdrawn'))
end)

---------------------------------------------------------------------------
-- My jobs + resigning
---------------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-townhall:server:getMyJobs', function(source, cb)
    local Player, err = ctx(source, 'jobs')
    if not Player then cb(fail(err)) return end
    local out = {}
    local onProbation = {}
    for _, p in ipairs(MySQL.query.await("SELECT job, GREATEST(0, UNIX_TIMESTAMP(ends_at) - UNIX_TIMESTAMP()) AS ends_in FROM townhall_probation WHERE citizenid = ? AND status = 'active'", { Player.PlayerData.citizenid }) or {}) do
        onProbation[p.job] = tonumber(p.ends_in) or 0
    end
    for _, pj in ipairs(exports['rsg-core']:GetPlayerJobs(source) or {}) do
        if not BlockedJobs[pj.job] then
            out[#out + 1] = { job = pj.job, label = pj.jobLabel or pj.job, grade = pj.gradeLabel or tostring(pj.grade or ''), pay = pj.salary or 0, probationEnds = onProbation[pj.job] }
        end
    end
    cb({ ok = true, jobs = out, canResign = Config.AllowResign })
end)

RSGCore.Functions.CreateCallback('rsg-townhall:server:resign', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if not Config.AllowResign then cb(fail('err_resign_disabled')) return end
    local job = type(payload) == 'table' and payload.job
    if type(job) ~= 'string' or BlockedJobs[job] then cb(fail('err_invalid')) return end
    if not throttle(src, 'resign', 2000) then cb(fail('err_slow_down')) return end
    if not exports['rsg-core']:HasPlayerJob(src, job) then cb(fail('err_not_holding')) return end
    local ok = exports['rsg-core']:RemovePlayerJob(src, job)
    if not ok then cb(fail('err_generic')) return end
    MySQL.insert.await('INSERT INTO townhall_resignations (citizenid, job) VALUES (?, ?)', { Player.PlayerData.citizenid, job })
    -- nothing left to confirm once the job is gone
    MySQL.update.await("UPDATE townhall_probation SET status = 'ended', decided_at = NOW() WHERE citizenid = ? AND job = ? AND status = 'active'", { Player.PlayerData.citizenid, job })
    rsgLog('Job resigned', 'amber', ('%s resigned from %s'):format(Player.PlayerData.citizenid, job))
    cb(success('ok_resigned'))
end)

---------------------------------------------------------------------------
-- Management: data
---------------------------------------------------------------------------
local function mapApps(rows, viewerCid)
    local out = {}
    local online = {}
    for _, id in pairs(RSGCore.Functions.GetPlayers()) do
        local P = RSGCore.Functions.GetPlayer(id)
        if P then online[P.PlayerData.citizenid] = true end
    end
    for _, r in ipairs(rows) do
        local d = defOf(r.job)
        local g = gradeOf(d, r.grade)
        out[#out + 1] = {
            id = r.id, applicant = r.applicant_name, status = r.status, feedback = r.feedback,
            interviewNote = r.interview_note, reviewedBy = r.reviewed_by_name, created = r.created, title = r.title,
            jobLabel = jobLabel(d, r.job), gradeLabel = g and g.name or tostring(r.grade),
            answers = decode(r.answers) or {},
            online = online[r.citizenid] == true,
            claimedBy = (r.claim_fresh == 1 or r.claim_fresh == true) and r.claimed_by_name or nil,
            claimMine = (r.claim_fresh == 1 or r.claim_fresh == true) and r.claimed_by == viewerCid or false,
        }
    end
    return out
end

RSGCore.Functions.CreateCallback('rsg-townhall:server:getManageData', function(source, cb)
    local src = source
    local Player, err = ctx(src, 'manage')
    if not Player then cb(fail(err)) return end
    local scope = getScope(src, Player)
    if not scope.any then cb(fail('err_no_permission')) return end

    local clause, params = scopeClause(scope, 'p.job')

    local postings = {}
    local prows = MySQL.query.await(([[
        SELECT p.id, p.job, p.grade, p.title, p.description, p.requirements, p.questions, p.status, p.slots, p.filled_count, p.location_id,
               p.posted_by_name, p.req_items, p.req_job, p.req_job_grade, p.req_extra, p.probation_days, UNIX_TIMESTAMP(p.created_at) AS created,
               (SELECT COUNT(*) FROM townhall_applications a WHERE a.posting_id = p.id) AS total,
               (SELECT COUNT(*) FROM townhall_applications a WHERE a.posting_id = p.id AND a.status = 'approved') AS approved,
               (SELECT COUNT(*) FROM townhall_applications a WHERE a.posting_id = p.id AND a.status = 'rejected') AS rejected,
               (SELECT AVG(TIMESTAMPDIFF(MINUTE, a.created_at, a.reviewed_at)) FROM townhall_applications a WHERE a.posting_id = p.id AND a.status IN ('approved', 'rejected') AND a.reviewed_at IS NOT NULL) AS avg_min,
               IF(p.expires_at IS NULL, NULL, GREATEST(0, UNIX_TIMESTAMP(p.expires_at) - UNIX_TIMESTAMP())) AS expires_in,
               (SELECT COUNT(*) FROM townhall_applications a WHERE a.posting_id = p.id AND a.status IN %s) AS pending
        FROM townhall_postings p WHERE %s ORDER BY (p.status = 'open') DESC, p.id DESC LIMIT 200]]):format(ACTIVE, clause), params) or {}
    for _, r in ipairs(prows) do
        local d = defOf(r.job)
        local g = gradeOf(d, r.grade)
        local loc = Locations[r.location_id]
        local rx = decode(r.req_extra) or {}
        postings[#postings + 1] = {
            id = r.id, title = r.title, status = r.status, jobLabel = jobLabel(d, r.job), expiry = expiryFor(scope, r.job),
            gradeLabel = g and g.name or tostring(r.grade), postedBy = r.posted_by_name,
            slots = r.slots, filledCount = r.filled_count, expiresIn = r.expires_in,
            location = loc and loc.label or '', created = r.created, pending = r.pending,
            description = r.description, requirements = r.requirements, custom = decode(r.questions) or {},
            job = r.job, grade = tonumber(r.grade), locationId = r.location_id,
            reqItems = decode(r.req_items) or {}, reqJob = r.req_job, reqJobGrade = r.req_job_grade,
            reqSkill = rx.skill and rx.skill.key or '', reqSkillLevel = rx.skill and rx.skill.level or 1, reqHonor = rx.honor,
            reqStandingRegion = rx.standing and rx.standing.region or '', reqStanding = rx.standing and rx.standing.min or 0,
            probation = tonumber(r.probation_days) or 0,
            stats = { total = r.total, approved = r.approved, rejected = r.rejected, avgMin = r.avg_min and math.floor(tonumber(r.avg_min)) or nil },
        }
    end

    local appSelect = [[
        SELECT a.id, a.citizenid, a.applicant_name, a.answers, a.status, a.feedback, a.interview_note, a.reviewed_by_name,
               a.claimed_by, a.claimed_by_name, ]] .. CLAIM_FRESH .. [[ AS claim_fresh,
               UNIX_TIMESTAMP(a.created_at) AS created, p.title, p.job, p.grade
        FROM townhall_applications a JOIN townhall_postings p ON p.id = a.posting_id
        WHERE %s AND a.status %s ORDER BY %s LIMIT %d]]
    local pendingRows = MySQL.query.await(appSelect:format(clause, 'IN ' .. ACTIVE, 'a.id ASC', 200), params) or {}
    local doneRows = MySQL.query.await(appSelect:format(clause, "IN ('approved', 'rejected')", 'a.reviewed_at DESC', 50), params) or {}

    local managers = {}
    if scope.admin then
        local mrows = MySQL.query.await('SELECT id, citizenid, name, job FROM townhall_managers ORDER BY name ASC') or {}
        for _, m in ipairs(mrows) do
            managers[#managers + 1] = { id = m.id, citizenid = m.citizenid, name = m.name, jobLabel = m.job == '*' and '*' or jobLabel(defOf(m.job), m.job) }
        end
    end

    local blacklist = {}
    if Config.AllowBlacklist then
        local bclause, bparams = scopeClause(scope, 'job')
        for _, b in ipairs(MySQL.query.await(("SELECT id, citizenid, name, job, reason, added_by_name FROM townhall_blacklist WHERE %s ORDER BY id DESC LIMIT 200"):format(bclause), bparams) or {}) do
            blacklist[#blacklist + 1] = { id = b.id, citizenid = b.citizenid, name = b.name, reason = b.reason, addedBy = b.added_by_name,
                jobLabel = b.job == '*' and '*' or jobLabel(defOf(b.job), b.job) }
        end
    end

    local probation = {}
    for _, p in ipairs(MySQL.query.await(("SELECT id, citizenid, name, job, GREATEST(0, UNIX_TIMESTAMP(ends_at) - UNIX_TIMESTAMP()) AS ends_in FROM townhall_probation WHERE status = 'active' AND %s ORDER BY ends_at ASC LIMIT 100"):format(clause), params) or {}) do
        probation[#probation + 1] = { id = p.id, name = p.name, jobLabel = jobLabel(defOf(p.job), p.job), endsIn = tonumber(p.ends_in) or 0 }
    end
    local invites = {}
    if Config.AllowInvites then
        for _, i in ipairs(MySQL.query.await(("SELECT id, name, job, grade, invited_by_name, probation_days, IF(expires_at IS NULL, NULL, GREATEST(0, UNIX_TIMESTAMP(expires_at) - UNIX_TIMESTAMP())) AS expires_in FROM townhall_invites WHERE status = 'pending' AND (expires_at IS NULL OR expires_at > NOW()) AND %s ORDER BY id DESC LIMIT 100"):format(clause), params) or {}) do
            local d = defOf(i.job)
            local g = gradeOf(d, i.grade)
            invites[#invites + 1] = { id = i.id, name = i.name, jobLabel = jobLabel(d, i.job), gradeLabel = g and g.name or tostring(i.grade),
                invitedBy = i.invited_by_name, probation = tonumber(i.probation_days) or 0, expiresIn = i.expires_in }
        end
    end

    local locs = {}
    for _, l in pairs(Locations) do locs[#locs + 1] = { id = l.id, label = l.label } end
    table.sort(locs, function(a, b) return a.label < b.label end)
    local items = {}
    for item in pairs(PrereqItems) do items[#items + 1] = { name = item, label = itemLabel(item) } end
    table.sort(items, function(a, b) return a.label < b.label end)

    cb({
        ok = true, admin = scope.admin, allScope = scope.all, jobs = listJobs(scope), postings = postings,
        pending = mapApps(pendingRows, Player.PlayerData.citizenid), reviewed = mapApps(doneRows, Player.PlayerData.citizenid), managers = managers, blacklist = blacklist, blacklistEnabled = Config.AllowBlacklist,
        locations = locs, prereqItems = items, allJobs = Config.AllowJobPrerequisites and listAllJobs() or {},
        skills = (function()
            local out = {}
            for _, d in ipairs(skillDefs()) do out[#out + 1] = { key = d.key, label = d.label or d.key, maxLevel = tonumber(d.maxLevel) or 1 } end
            return out
        end)(),
        regions = regionList(), honorEnabled = repOn(), limits = Config.ReputationLimits,
        probation = probation, invites = invites,
    })
end)

---------------------------------------------------------------------------
-- Management: vacancies
---------------------------------------------------------------------------
local function readTexts(payload)
    local title, e = cleanText(payload.title, Config.Limits.title)
    if not title then return nil, e end
    local desc, e2 = cleanText(payload.description, Config.Limits.description)
    if not desc then return nil, e2 end
    local reqs, e3 = cleanText(payload.requirements, Config.Limits.requirements)
    if not reqs then return nil, e3 end
    local custom = {}
    if payload.questions ~= nil then
        if type(payload.questions) ~= 'table' or #payload.questions > Config.MaxCustomQuestions then return nil, 'err_invalid' end
        for _, q in ipairs(payload.questions) do
            local text, qe = cleanText(q, Config.Limits.question, true)
            if not text then return nil, qe end
            if text ~= '' then custom[#custom + 1] = text end
        end
    end
    return { title = title, desc = desc, reqs = reqs, custom = custom }
end

local function readSlots(v)
    local n = v == nil and 1 or math.tointeger(tonumber(v))
    if not n or n < 1 or n > Config.MaxSlots then return nil end
    return n
end

local function readExpiry(v, optional, list)
    if v == nil then return optional and false or defaultExpiry(list) end
    local n = math.tointeger(tonumber(v))
    if not n or not expiryAllowed(list, n) then return nil end
    return n
end

local function countOpen(job)
    return MySQL.scalar.await("SELECT COUNT(*) FROM townhall_postings WHERE job = ? AND status = 'open'", { job }) or 0
end

RSGCore.Functions.CreateCallback('rsg-townhall:server:postJob', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if type(payload) ~= 'table' then cb(fail('err_invalid')) return end
    if not throttle(src, 'post', 2000) then cb(fail('err_slow_down')) return end
    local scope = getScope(src, Player)
    if not scope.any then cb(fail('err_no_permission')) return end

    local job = payload.job
    local def = getJobDef(job)
    if not def or not jobAllowed(job) then cb(fail('err_job_invalid')) return end
    if not scopeAllows(scope, job) then cb(fail('err_no_permission')) return end

    local grade = math.tointeger(tonumber(payload.grade))
    local g = grade and gradeOf(def, grade)
    if not g then cb(fail('err_grade_invalid')) return end
    if g.isboss and Config.RestrictBossGrades and not scope.admin then cb(fail('err_no_permission')) return end

    local texts, terr = readTexts(payload)
    if not texts then cb(fail(terr)) return end
    local slots = readSlots(payload.slots)
    local days = readExpiry(payload.expiryDays, false, expiryFor(scope, job))
    if not slots or not days then cb(fail('err_invalid')) return end

    local locId = payload.locationId == nil and 0 or math.tointeger(tonumber(payload.locationId))
    if not locId or (locId ~= 0 and not Locations[locId]) then cb(fail('err_invalid')) return end

    -- prerequisites
    local reqItems = {}
    if payload.reqItems ~= nil then
        if type(payload.reqItems) ~= 'table' or #payload.reqItems > Config.MaxPrerequisiteItems then cb(fail('err_prereq_invalid')) return end
        local seen = {}
        for _, item in ipairs(payload.reqItems) do
            if type(item) ~= 'string' or not PrereqItems[item] then cb(fail('err_prereq_invalid')) return end
            if not seen[item] then seen[item] = true reqItems[#reqItems + 1] = item end
        end
    end
    local reqJob, reqGrade = '', 0
    if Config.AllowJobPrerequisites and type(payload.reqJob) == 'string' and payload.reqJob ~= '' then
        if BlockedJobs[payload.reqJob] or not getJobDef(payload.reqJob) then cb(fail('err_prereq_invalid')) return end
        reqJob = payload.reqJob
        reqGrade = math.tointeger(tonumber(payload.reqJobGrade)) or 0
        if reqGrade < 0 then cb(fail('err_prereq_invalid')) return end
    end

    local extra, xerr = readExtra(payload)
    if not extra then cb(fail(xerr)) return end
    local probation = readProbation(payload.probationDays)
    if not probation then cb(fail('err_invalid')) return end

    if countOpen(job) >= Config.MaxOpenPostingsPerJob then cb(fail('err_max_postings')) return end

    local id = MySQL.insert.await([[
        INSERT INTO townhall_postings (job, grade, title, description, requirements, questions, slots, expires_at, location_id,
                                       req_items, req_job, req_job_grade, req_extra, probation_days, posted_by, posted_by_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, IF(? > 0, DATE_ADD(NOW(), INTERVAL ? DAY), NULL), ?, ?, ?, ?, ?, ?, ?, ?)]],
        { job, tostring(grade), texts.title, texts.desc, texts.reqs, json.encode(texts.custom), slots, days, days, locId,
          json.encode(reqItems), reqJob, reqGrade, json.encode(extra), probation, Player.PlayerData.citizenid, playerName(Player) })
    if not id then cb(fail('err_generic')) return end
    rsgLog('Vacancy posted', 'green', ('%s posted #%s: %s (%s grade %s, %s slot(s))'):format(Player.PlayerData.citizenid, id, texts.title, job, grade, slots))
    cb(success('ok_posted'))
end)

RSGCore.Functions.CreateCallback('rsg-townhall:server:editPosting', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if type(payload) ~= 'table' then cb(fail('err_invalid')) return end
    if not throttle(src, 'post', 1500) then cb(fail('err_slow_down')) return end
    local id = math.tointeger(tonumber(payload.postingId))
    if not id then cb(fail('err_invalid')) return end
    local posting = MySQL.single.await('SELECT id, job, status, filled_count FROM townhall_postings WHERE id = ?', { id })
    if not posting then cb(fail('err_not_found')) return end
    local scope = getScope(src, Player)
    if not scopeAllows(scope, posting.job) then cb(fail('err_no_permission')) return end
    if posting.status ~= 'open' then cb(fail('err_posting_closed')) return end

    local texts, terr = readTexts(payload)
    if not texts then cb(fail(terr)) return end
    local slots = readSlots(payload.slots)
    if not slots or slots <= posting.filled_count then cb(fail('err_invalid')) return end
    local days = readExpiry(payload.expiryDays, true, expiryFor(scope, posting.job))  -- false = leave unchanged
    if days == nil then cb(fail('err_invalid')) return end

    MySQL.update.await("UPDATE townhall_postings SET title = ?, description = ?, requirements = ?, questions = ?, slots = ? WHERE id = ? AND status = 'open'",
        { texts.title, texts.desc, texts.reqs, json.encode(texts.custom), slots, id })
    if days ~= false then
        MySQL.update.await("UPDATE townhall_postings SET warned = 0, expires_at = IF(? > 0, DATE_ADD(NOW(), INTERVAL ? DAY), NULL) WHERE id = ? AND status = 'open'", { days, days, id })
    end
    rsgLog('Vacancy edited', 'blue', ('%s edited #%s'):format(Player.PlayerData.citizenid, id))
    cb(success('ok_edited'))
end)

RSGCore.Functions.CreateCallback('rsg-townhall:server:closePosting', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    local id = type(payload) == 'table' and math.tointeger(tonumber(payload.postingId))
    if not id then cb(fail('err_invalid')) return end
    local posting = MySQL.single.await('SELECT id, job, title, status FROM townhall_postings WHERE id = ?', { id })
    if not posting then cb(fail('err_not_found')) return end
    if not scopeAllows(getScope(src, Player), posting.job) then cb(fail('err_no_permission')) return end
    local n = MySQL.update.await("UPDATE townhall_postings SET status = 'closed', closed_at = NOW() WHERE id = ? AND status = 'open'", { id })
    if n ~= 1 then cb(fail('err_posting_closed')) return end
    closePending(id, posting.title)
    rsgLog('Vacancy closed', 'red', ('%s closed #%s'):format(Player.PlayerData.citizenid, id))
    cb(success('ok_closed'))
end)

-- closed/expired with free seats -> reopened; filled (or full) -> reposted as a new copy
RSGCore.Functions.CreateCallback('rsg-townhall:server:reopenPosting', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if not throttle(src, 'post', 1500) then cb(fail('err_slow_down')) return end
    local id = type(payload) == 'table' and math.tointeger(tonumber(payload.postingId))
    if not id then cb(fail('err_invalid')) return end
    local p = MySQL.single.await('SELECT id, job, grade, status, slots, filled_count FROM townhall_postings WHERE id = ?', { id })
    if not p then cb(fail('err_not_found')) return end
    local scope = getScope(src, Player)
    if not scopeAllows(scope, p.job) then cb(fail('err_no_permission')) return end
    local pg = gradeOf(getJobDef(p.job), p.grade)
    if pg and pg.isboss and Config.RestrictBossGrades and not scope.admin then cb(fail('err_no_permission')) return end
    if p.status == 'open' then cb(fail('err_invalid')) return end
    if not jobAllowed(p.job) or not getJobDef(p.job) then cb(fail('err_job_invalid')) return end
    if countOpen(p.job) >= Config.MaxOpenPostingsPerJob then cb(fail('err_max_postings')) return end

    local days = defaultExpiry(expiryFor(scope, p.job))
    if (p.status == 'closed' or p.status == 'expired') and p.filled_count < p.slots then
        local n = MySQL.update.await("UPDATE townhall_postings SET status = 'open', closed_at = NULL, warned = 0, expires_at = IF(? > 0, DATE_ADD(NOW(), INTERVAL ? DAY), NULL) WHERE id = ? AND status IN ('closed', 'expired')", { days, days, id })
        if n ~= 1 then cb(fail('err_generic')) return end
        rsgLog('Vacancy reopened', 'green', ('%s reopened #%s'):format(Player.PlayerData.citizenid, id))
    else
        local newId = MySQL.insert.await([[
            INSERT INTO townhall_postings (job, grade, title, description, requirements, questions, slots, expires_at, location_id,
                                           req_items, req_job, req_job_grade, req_extra, probation_days, posted_by, posted_by_name)
            SELECT job, grade, title, description, requirements, questions, slots,
                   IF(? > 0, DATE_ADD(NOW(), INTERVAL ? DAY), NULL), location_id, req_items, req_job, req_job_grade, req_extra, probation_days, ?, ?
            FROM townhall_postings WHERE id = ?]], { days, days, Player.PlayerData.citizenid, playerName(Player), id })
        if not newId or newId == 0 then cb(fail('err_generic')) return end
        rsgLog('Vacancy reposted', 'green', ('%s reposted #%s as #%s'):format(Player.PlayerData.citizenid, id, newId))
    end
    cb(success('ok_reopened'))
end)

---------------------------------------------------------------------------
-- Reviewing: interview + decision
---------------------------------------------------------------------------
local function readFeedback(v)
    local minLen = Config.RequireFeedback and Config.MinFeedbackLength or 0
    local text, ferr = cleanText(v, Config.Limits.feedback, minLen == 0)
    if not text then
        if ferr == 'err_required' then return nil, 'err_feedback_required', minLen end
        return nil, ferr
    end
    if minLen > 0 and (utf8.len(text) or 0) < minLen then return nil, 'err_feedback_required', minLen end
    return text
end

-- Reviewers may not decide on their own character or another character on their license
local function isSelfReview(Player, app, applicantPlayer)
    if Config.AllowSelfReview then return false end
    if app.citizenid == Player.PlayerData.citizenid then return true end
    local license = applicantPlayer and applicantPlayer.PlayerData.license
        or MySQL.scalar.await('SELECT license FROM players WHERE citizenid = ?', { app.citizenid })
    return license ~= nil and license == Player.PlayerData.license
end

local APP_SELECT = [[
    SELECT a.id, a.posting_id, a.citizenid, a.applicant_name, a.status, a.claimed_by, a.claimed_by_name, ]] .. CLAIM_FRESH .. [[ AS claim_fresh,
           p.job, p.grade, p.title, p.probation_days
    FROM townhall_applications a JOIN townhall_postings p ON p.id = a.posting_id WHERE a.id = ?]]

-- Someone else's fresh claim blocks a decision (admins may always override). Returns the claimer's name or nil
local function claimedByOther(Player, scope, app)
    if not Config.AllowClaim or scope.admin then return nil end
    if app.claimed_by and app.claimed_by ~= Player.PlayerData.citizenid and (app.claim_fresh == 1 or app.claim_fresh == true) then
        return app.claimed_by_name or '?'
    end
    return nil
end

RSGCore.Functions.CreateCallback('rsg-townhall:server:requestInterview', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if not Config.AllowInterviews then cb(fail('err_interview_disabled')) return end
    if type(payload) ~= 'table' then cb(fail('err_invalid')) return end
    if not throttle(src, 'review', 1000) then cb(fail('err_slow_down')) return end
    local appId = math.tointeger(tonumber(payload.applicationId))
    if not appId then cb(fail('err_invalid')) return end

    local app = MySQL.single.await(APP_SELECT, { appId })
    if not app then cb(fail('err_not_found')) return end
    if app.status ~= 'pending' then cb(fail('err_not_pending')) return end
    local scope = getScope(src, Player)
    if not scopeAllows(scope, app.job) then cb(fail('err_no_permission')) return end
    local applicantPlayer = RSGCore.Functions.GetPlayerByCitizenId(app.citizenid)
    if isSelfReview(Player, app, applicantPlayer) then cb(fail('err_self_review')) return end
    local holder = claimedByOther(Player, scope, app)
    if holder then cb(fail('err_claimed', holder)) return end

    local note, nerr, minLen = readFeedback(payload.message)
    if not note then cb(fail(nerr, minLen)) return end
    if note == '' then cb(fail('err_required')) return end

    local n = MySQL.update.await("UPDATE townhall_applications SET status = 'interview', interview_note = ?, reviewed_by = ?, reviewed_by_name = ?, seen = 0, notified = 0 WHERE id = ? AND status = 'pending'",
        { note, Player.PlayerData.citizenid, playerName(Player), appId })
    if n ~= 1 then cb(fail('err_already_reviewed')) return end
    if applicantPlayer then
        notify(applicantPlayer.PlayerData.source, locale('notify_interview', playerName(Player), app.title), 'inform')
        markNotified(appId)
    else
        sendTelegram(app.citizenid, locale('notify_title'), locale('notify_interview', playerName(Player), app.title))
    end
    rsgLog('Interview requested', 'blue', ('%s requested an interview for application #%s (%s)'):format(Player.PlayerData.citizenid, appId, app.title))
    cb(success('ok_interview'))
end)

local approveErrors = {
    invalid_job = 'err_job_invalid',
    invalid_grade = 'err_grade_invalid',
    player_not_found = 'err_applicant_offline',
    max_jobs = 'err_max_jobs',
}

local function revertApproval(appId, prevStatus, postingId)
    MySQL.update.await("UPDATE townhall_applications SET status = ?, feedback = NULL, reviewed_by = NULL, reviewed_by_name = NULL, reviewed_at = NULL, granted = 1, seen = 1 WHERE id = ? AND status = 'approved'", { prevStatus, appId })
    if postingId then
        MySQL.update.await("UPDATE townhall_postings SET closed_at = IF(status = 'filled', NULL, closed_at), filled_by = IF(status = 'filled', NULL, filled_by), filled_by_name = IF(status = 'filled', NULL, filled_by_name), status = IF(status = 'filled', 'open', status), filled_count = GREATEST(0, filled_count - 1) WHERE id = ?", { postingId })
    end
end

-- One decision on one application. Used by 'review' and 'bulkReview'; returns the { ok, msg | err } table
local function reviewOne(src, Player, appId, decision, rawFeedback)
    local app = MySQL.single.await(APP_SELECT, { appId })
    if not app then return fail('err_not_found') end
    if app.status ~= 'pending' and app.status ~= 'interview' then return fail('err_already_reviewed') end
    local scope = getScope(src, Player)
    if not scopeAllows(scope, app.job) then return fail('err_no_permission') end

    local applicantPlayer = RSGCore.Functions.GetPlayerByCitizenId(app.citizenid)
    if isSelfReview(Player, app, applicantPlayer) then return fail('err_self_review') end
    local holder = claimedByOther(Player, scope, app)
    if holder then return fail('err_claimed', holder) end

    local feedback, ferr, minLen = readFeedback(rawFeedback)
    if not feedback then return fail(ferr, minLen) end

    local reviewerCid, reviewerName = Player.PlayerData.citizenid, playerName(Player)

    if decision == 'reject' then
        local n = MySQL.update.await(("UPDATE townhall_applications SET status = 'rejected', feedback = ?, reviewed_by = ?, reviewed_by_name = ?, reviewed_at = NOW(), seen = 0, notified = 0 WHERE id = ? AND status IN %s"):format(ACTIVE),
            { feedback, reviewerCid, reviewerName, appId })
        if n ~= 1 then return fail('err_already_reviewed') end
        if notifyCitizen(app.citizenid, locale('notify_app_rejected', app.title), 'error', true) then markNotified(appId) end
        TriggerEvent('rsg-townhall:server:applicationDecided', { id = appId, citizenid = app.citizenid, job = app.job, grade = tonumber(app.grade), decision = 'rejected' })
        rsgLog('Application rejected', 'red', ('%s rejected application #%s (%s)'):format(reviewerCid, appId, app.title))
        return success('ok_rejected')
    end

    -- approve
    local target = applicantPlayer
    if not target and not Config.AllowOfflineApproval then return fail('err_applicant_offline') end
    if target and exports['rsg-core']:HasPlayerJob(target.PlayerData.source, app.job) then return fail('err_applicant_has_job') end

    local claimed = MySQL.update.await(("UPDATE townhall_applications SET status = 'approved', granted = ?, feedback = ?, reviewed_by = ?, reviewed_by_name = ?, reviewed_at = NOW(), seen = 0, notified = 0 WHERE id = ? AND status IN %s"):format(ACTIVE),
        { target and 1 or 0, feedback, reviewerCid, reviewerName, appId })
    if claimed ~= 1 then return fail('err_already_reviewed') end

    -- take a seat atomically; the vacancy becomes 'filled' when the last seat goes
    local seat = MySQL.update.await([[
        UPDATE townhall_postings
        SET status = IF(filled_count + 1 >= slots, 'filled', 'open'),
            closed_at = IF(filled_count + 1 >= slots, NOW(), NULL),
            filled_by = ?, filled_by_name = ?, filled_count = filled_count + 1
        WHERE id = ? AND status = 'open' AND filled_count < slots AND (expires_at IS NULL OR expires_at > NOW())]],
        { app.citizenid, app.applicant_name, app.posting_id })
    if seat ~= 1 then
        revertApproval(appId, app.status, nil)
        return fail('err_posting_closed')
    end

    if target then
        local ok, reason = exports['rsg-core']:AddPlayerJob(target.PlayerData.source, app.job, tonumber(app.grade), Config.BypassMaxJobs)
        if not ok then
            revertApproval(appId, app.status, app.posting_id)
            return fail(approveErrors[reason] or 'err_generic')
        end
        if Config.SetActiveJobOnApproval then target.Functions.SetJob(app.job, tonumber(app.grade)) end
        startProbation(app.citizenid, app.applicant_name, app.job, app.probation_days, appId, 'application')
        notify(target.PlayerData.source, locale('notify_app_approved', app.title), 'success')
        markNotified(appId)
    else
        sendTelegram(app.citizenid, locale('notify_title'), locale('notify_app_approved_queued', app.title))
    end

    local postingStatus = MySQL.scalar.await('SELECT status FROM townhall_postings WHERE id = ?', { app.posting_id })
    if postingStatus == 'filled' then closePending(app.posting_id, app.title) end

    TriggerEvent('rsg-townhall:server:applicationDecided', { id = appId, citizenid = app.citizenid, job = app.job, grade = tonumber(app.grade), decision = 'approved', queued = target == nil })
    rsgLog('Application approved', 'green', ('%s approved application #%s: %s -> %s grade %s%s'):format(
        reviewerCid, appId, app.citizenid, app.job, app.grade, target and '' or ' (queued, applicant offline)'))
    return success(target and 'ok_approved' or 'ok_approved_queued')
end

RSGCore.Functions.CreateCallback('rsg-townhall:server:review', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if type(payload) ~= 'table' then cb(fail('err_invalid')) return end
    if not throttle(src, 'review', 1000) then cb(fail('err_slow_down')) return end

    local appId = math.tointeger(tonumber(payload.applicationId))
    local decision = payload.decision
    if not appId or (decision ~= 'approve' and decision ~= 'reject') then cb(fail('err_invalid')) return end
    cb(reviewOne(src, Player, appId, decision, payload.feedback))
end)

-- Several decisions at once (same decision and feedback for each); every application is still checked on its own
RSGCore.Functions.CreateCallback('rsg-townhall:server:bulkReview', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if not Config.AllowBulkReview then cb(fail('err_generic')) return end
    if type(payload) ~= 'table' or type(payload.ids) ~= 'table' then cb(fail('err_invalid')) return end
    local decision = payload.decision
    if decision ~= 'approve' and decision ~= 'reject' then cb(fail('err_invalid')) return end
    if not throttle(src, 'bulk', 3000) then cb(fail('err_slow_down')) return end
    local maxN = math.max(1, Config.MaxBulkReview or 10)
    if #payload.ids < 1 or #payload.ids > maxN then cb(fail('err_invalid')) return end

    local seen, ids = {}, {}
    for _, v in ipairs(payload.ids) do
        local id = math.tointeger(tonumber(v))
        if not id then cb(fail('err_invalid')) return end
        if not seen[id] then seen[id] = true ids[#ids + 1] = id end
    end

    local done, failed, firstErr = 0, 0, nil
    for _, id in ipairs(ids) do
        local r = reviewOne(src, Player, id, decision, payload.feedback)
        if r.ok then done = done + 1 else failed = failed + 1 firstErr = firstErr or r.err end
    end
    if done == 0 then cb({ ok = false, err = firstErr or locale('err_generic') }) return end
    cb({ ok = true, msg = locale('ok_bulk', done, failed) })
end)

-- Claim an application (or give the claim back) so two reviewers do not work on it at once
RSGCore.Functions.CreateCallback('rsg-townhall:server:claimApplication', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if not Config.AllowClaim then cb(fail('err_generic')) return end
    if type(payload) ~= 'table' then cb(fail('err_invalid')) return end
    if not throttle(src, 'claim', 800) then cb(fail('err_slow_down')) return end
    local appId = math.tointeger(tonumber(payload.applicationId))
    if not appId then cb(fail('err_invalid')) return end

    local app = MySQL.single.await(APP_SELECT, { appId })
    if not app then cb(fail('err_not_found')) return end
    if app.status ~= 'pending' and app.status ~= 'interview' then cb(fail('err_already_reviewed')) return end
    local scope = getScope(src, Player)
    if not scopeAllows(scope, app.job) then cb(fail('err_no_permission')) return end
    if isSelfReview(Player, app, RSGCore.Functions.GetPlayerByCitizenId(app.citizenid)) then cb(fail('err_self_review')) return end

    local cid, override = Player.PlayerData.citizenid, scope.admin and 1 or 0
    if payload.release == true then
        MySQL.update.await("UPDATE townhall_applications SET claimed_by = NULL, claimed_by_name = NULL, claimed_at = NULL WHERE id = ? AND (claimed_by = ? OR ?)", { appId, cid, override })
        cb(success('ok_released'))
        return
    end
    local n = MySQL.update.await(("UPDATE townhall_applications AS a SET a.claimed_by = ?, a.claimed_by_name = ?, a.claimed_at = NOW() WHERE a.id = ? AND a.status IN %s AND (a.claimed_by IS NULL OR a.claimed_by = ? OR NOT %s OR ?)"):format(ACTIVE, CLAIM_FRESH),
        { cid, playerName(Player), appId, cid, override })
    if n ~= 1 and not (app.claimed_by == cid) then cb(fail('err_claimed', app.claimed_by_name or '?')) return end
    cb(success('ok_claimed'))
end)

-- Find a character by server id or citizenid: cid, name, onlinePlayer  or  nil, errKey
local function resolvePlayer(input)
    local target
    local asId = math.tointeger(tonumber(input))
    if asId then target = RSGCore.Functions.GetPlayer(asId) end
    if not target then target = RSGCore.Functions.GetPlayerByCitizenId(input) end
    if target then return target.PlayerData.citizenid, playerName(target), target end
    local row = MySQL.single.await('SELECT citizenid, charinfo FROM players WHERE citizenid = ?', { input })
    if not row then return nil, 'err_player_not_found' end
    local ci = decode(row.charinfo) or {}
    return row.citizenid, ('%s %s'):format(ci.firstname or '?', ci.lastname or '')
end

---------------------------------------------------------------------------
-- Manager list (admin only)
---------------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-townhall:server:addManager', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if not getScope(src, Player).admin then cb(fail('err_no_permission')) return end
    if type(payload) ~= 'table' then cb(fail('err_invalid')) return end
    if not throttle(src, 'manager', 1000) then cb(fail('err_slow_down')) return end

    local input, ierr = cleanText(payload.player, 50)
    if not input then cb(fail(ierr)) return end
    local job = payload.job
    if job ~= '*' and not getJobDef(job) then cb(fail('err_job_invalid')) return end

    local cid, name, target = resolvePlayer(input)
    if not cid then cb(fail(name)) return end
    if target and Config.ManagerJob and Config.ManagerJob ~= '' and not exports['rsg-core']:HasPlayerJob(target.PlayerData.source, Config.ManagerJob) then
        cb(fail('err_manager_needs_job', jobLabel(defOf(Config.ManagerJob), Config.ManagerJob)))
        return
    end

    local id = MySQL.insert.await('INSERT IGNORE INTO townhall_managers (citizenid, name, job, added_by) VALUES (?, ?, ?, ?)',
        { cid, name, job, Player.PlayerData.citizenid })
    if not id or id == 0 then cb(fail('err_already_manager')) return end
    loadManagers()
    rsgLog('Manager added', 'green', ('%s added manager %s (%s)'):format(Player.PlayerData.citizenid, cid, job))
    cb(success('ok_manager_added'))
end)

RSGCore.Functions.CreateCallback('rsg-townhall:server:removeManager', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if not getScope(src, Player).admin then cb(fail('err_no_permission')) return end
    local id = type(payload) == 'table' and math.tointeger(tonumber(payload.id))
    if not id then cb(fail('err_invalid')) return end
    local n = MySQL.update.await('DELETE FROM townhall_managers WHERE id = ?', { id })
    if n ~= 1 then cb(fail('err_not_found')) return end
    loadManagers()
    rsgLog('Manager removed', 'red', ('%s removed manager entry #%s'):format(Player.PlayerData.citizenid, id))
    cb(success('ok_manager_removed'))
end)

---------------------------------------------------------------------------
-- Messages between applicant and reviewers
---------------------------------------------------------------------------
-- Returns app, role ('applicant' | 'reviewer')  or  nil, errKey
local function loadAppForMessages(src, Player, payload)
    if not Config.AllowMessages then return nil, 'err_messages_disabled' end
    if type(payload) ~= 'table' then return nil, 'err_invalid' end
    local appId = math.tointeger(tonumber(payload.applicationId))
    if not appId then return nil, 'err_invalid' end
    local app = MySQL.single.await(APP_SELECT, { appId })
    if not app then return nil, 'err_not_found' end
    if app.citizenid == Player.PlayerData.citizenid then return app, 'applicant' end
    if not scopeAllows(getScope(src, Player), app.job) then return nil, 'err_no_permission' end
    return app, 'reviewer'
end

RSGCore.Functions.CreateCallback('rsg-townhall:server:getMessages', function(source, cb, payload)
    local Player, err = ctx(source, 'msgs')
    if not Player then cb(fail(err)) return end
    local app, role = loadAppForMessages(source, Player, payload)
    if not app then cb(fail(role)) return end
    local rows = MySQL.query.await('SELECT sender_cid, sender_name, from_reviewer, body, UNIX_TIMESTAMP(created_at) AS created FROM townhall_messages WHERE application_id = ? ORDER BY id ASC LIMIT ?',
        { app.id, Config.MaxMessages or 30 }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { body = r.body, name = r.sender_name, reviewer = r.from_reviewer == 1, mine = r.sender_cid == Player.PlayerData.citizenid, created = r.created }
    end
    cb({ ok = true, messages = out, canSend = app.status == 'pending' or app.status == 'interview' })
end)

RSGCore.Functions.CreateCallback('rsg-townhall:server:sendMessage', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if not throttle(src, 'msg', 1500) then cb(fail('err_slow_down')) return end
    local app, role = loadAppForMessages(src, Player, payload)
    if not app then cb(fail(role)) return end
    if app.status ~= 'pending' and app.status ~= 'interview' then cb(fail('err_already_reviewed')) return end
    if role == 'reviewer' and isSelfReview(Player, app, RSGCore.Functions.GetPlayerByCitizenId(app.citizenid)) then cb(fail('err_self_review')) return end

    local text, terr = cleanText(payload.message, Config.Limits.message or 300)
    if not text then cb(fail(terr)) return end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM townhall_messages WHERE application_id = ?', { app.id }) or 0
    if count >= (Config.MaxMessages or 30) then cb(fail('err_too_many_messages')) return end

    MySQL.insert.await('INSERT INTO townhall_messages (application_id, sender_cid, sender_name, from_reviewer, body) VALUES (?, ?, ?, ?, ?)',
        { app.id, Player.PlayerData.citizenid, playerName(Player), role == 'reviewer' and 1 or 0, text })
    if role == 'reviewer' then
        MySQL.update.await('UPDATE townhall_applications SET seen = 0, notified = 0 WHERE id = ?', { app.id })
        if notifyCitizen(app.citizenid, locale('notify_reviewer_message', app.title), 'inform') then markNotified(app.id) end
    else
        notifyManagers(app.job, locale('notify_new_message', playerName(Player), app.title))
    end
    cb(success('ok_message_sent'))
end)

---------------------------------------------------------------------------
-- Applicants: edit answers while the application is open
---------------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-townhall:server:editApplication', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if not Config.AllowEditApplication then cb(fail('err_edit_disabled')) return end
    if type(payload) ~= 'table' or type(payload.answers) ~= 'table' then cb(fail('err_invalid')) return end
    if not throttle(src, 'editapp', 2000) then cb(fail('err_slow_down')) return end
    local appId = math.tointeger(tonumber(payload.applicationId))
    if not appId then cb(fail('err_invalid')) return end

    local row = MySQL.single.await('SELECT a.id, a.status, a.answers, p.questions FROM townhall_applications a JOIN townhall_postings p ON p.id = a.posting_id WHERE a.id = ? AND a.citizenid = ?',
        { appId, Player.PlayerData.citizenid })
    if not row then cb(fail('err_not_found')) return end
    if row.status ~= 'pending' and row.status ~= 'interview' then cb(fail('err_already_reviewed')) return end

    -- follow the questions the applicant actually answered (the poster may have edited the vacancy since)
    local current, old = buildQuestions(row), decode(row.answers) or {}
    if #old == 0 or #payload.answers ~= #old then cb(fail('err_invalid')) return end
    local stored = {}
    for i, o in ipairs(old) do
        local q = current[i] and current[i].label == o.q and current[i] or nil
        local a, aerr = cleanText(payload.answers[i], q and q.max or Config.Limits.answer, true)
        if not a then cb(fail(aerr)) return end
        if q and q.required and a == '' then cb(fail('err_answers_required')) return end
        stored[#stored + 1] = { q = o.q, a = a }
    end
    local n = MySQL.update.await(("UPDATE townhall_applications SET answers = ? WHERE id = ? AND status IN %s"):format(ACTIVE), { json.encode(stored), appId })
    if n ~= 1 then cb(fail('err_already_reviewed')) return end
    cb(success('ok_answers_saved'))
end)

---------------------------------------------------------------------------
-- Vacancy templates (per poster)
---------------------------------------------------------------------------
local function cleanTemplate(d)
    if type(d) ~= 'table' then return nil, 'err_invalid' end
    local texts, e = readTexts(d)
    if not texts then return nil, e end
    local out = {
        job = (type(d.job) == 'string' and #d.job <= 50) and d.job or '',
        grade = math.tointeger(tonumber(d.grade)),
        title = texts.title, description = texts.desc, requirements = texts.reqs, questions = texts.custom,
        slots = readSlots(d.slots) or 1,
        expiryDays = math.tointeger(tonumber(d.expiryDays)),
        reqItems = {}, reqJob = '', reqJobGrade = 0,
    }
    if type(d.reqItems) == 'table' then
        for _, item in ipairs(d.reqItems) do
            if #out.reqItems >= Config.MaxPrerequisiteItems then break end
            if type(item) == 'string' and PrereqItems[item] then out.reqItems[#out.reqItems + 1] = item end
        end
    end
    if Config.AllowJobPrerequisites and type(d.reqJob) == 'string' and d.reqJob ~= '' and not BlockedJobs[d.reqJob] and getJobDef(d.reqJob) then
        out.reqJob = d.reqJob
        out.reqJobGrade = math.max(0, math.tointeger(tonumber(d.reqJobGrade)) or 0)
    end
    local extra = readExtra(d)
    if extra then
        out.reqSkill, out.reqSkillLevel = extra.skill and extra.skill.key or '', extra.skill and extra.skill.level or 1
        out.reqHonor = extra.honor
        out.reqStandingRegion, out.reqStanding = extra.standing and extra.standing.region or '', extra.standing and extra.standing.min or 0
    end
    out.probationDays = readProbation(d.probationDays) or 0
    return out
end

RSGCore.Functions.CreateCallback('rsg-townhall:server:getTemplates', function(source, cb)
    local Player, err = ctx(source, 'tpl')
    if not Player then cb(fail(err)) return end
    if not getScope(source, Player).any then cb(fail('err_no_permission')) return end
    local rows = MySQL.query.await('SELECT id, name, data FROM townhall_templates WHERE citizenid = ? ORDER BY name ASC LIMIT 50', { Player.PlayerData.citizenid }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local data = decode(r.data)
        if data then out[#out + 1] = { id = r.id, name = r.name, data = data } end
    end
    cb({ ok = true, templates = out })
end)

RSGCore.Functions.CreateCallback('rsg-townhall:server:saveTemplate', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if not getScope(src, Player).any then cb(fail('err_no_permission')) return end
    if type(payload) ~= 'table' then cb(fail('err_invalid')) return end
    if not throttle(src, 'tpl', 1500) then cb(fail('err_slow_down')) return end
    local name, nerr = cleanText(payload.name, Config.Limits.label)
    if not name then cb(fail(nerr)) return end
    local data, derr = cleanTemplate(payload.data)
    if not data then cb(fail(derr)) return end
    local cid = Player.PlayerData.citizenid
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM townhall_templates WHERE citizenid = ?', { cid }) or 0
    if count >= (Config.MaxTemplates or 10) then cb(fail('err_template_limit', Config.MaxTemplates or 10)) return end
    MySQL.insert.await('INSERT INTO townhall_templates (citizenid, name, data) VALUES (?, ?, ?)', { cid, name, json.encode(data) })
    cb(success('ok_template_saved'))
end)

RSGCore.Functions.CreateCallback('rsg-townhall:server:deleteTemplate', function(source, cb, payload)
    local Player, err = ctx(source)
    if not Player then cb(fail(err)) return end
    local id = type(payload) == 'table' and math.tointeger(tonumber(payload.id))
    if not id then cb(fail('err_invalid')) return end
    local n = MySQL.update.await('DELETE FROM townhall_templates WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
    if n ~= 1 then cb(fail('err_not_found')) return end
    cb(success('ok_template_deleted'))
end)

---------------------------------------------------------------------------
-- Blacklist (a citizen barred from applying for one job, or all jobs)
---------------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-townhall:server:addBlacklist', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if not Config.AllowBlacklist then cb(fail('err_generic')) return end
    local scope = getScope(src, Player)
    if not scope.any then cb(fail('err_no_permission')) return end
    if type(payload) ~= 'table' then cb(fail('err_invalid')) return end
    if not throttle(src, 'blacklist', 1000) then cb(fail('err_slow_down')) return end

    local input, ierr = cleanText(payload.player, 50)
    if not input then cb(fail(ierr)) return end
    local reason, rerr = cleanText(payload.reason, Config.Limits.feedback, true)
    if not reason then cb(fail(rerr)) return end
    local job = payload.job
    if type(job) ~= 'string' or (job ~= '*' and not getJobDef(job)) then cb(fail('err_job_invalid')) return end
    if not scopeAllows(scope, job) then cb(fail('err_no_permission')) return end

    local cid, name = resolvePlayer(input)
    if not cid then cb(fail(name)) return end
    local id = MySQL.insert.await('INSERT IGNORE INTO townhall_blacklist (citizenid, name, job, reason, added_by, added_by_name) VALUES (?, ?, ?, ?, ?, ?)',
        { cid, name, job, reason, Player.PlayerData.citizenid, playerName(Player) })
    if not id or id == 0 then cb(fail('err_already_blacklisted')) return end
    rsgLog('Blacklist added', 'red', ('%s barred %s from %s'):format(Player.PlayerData.citizenid, cid, job))
    cb(success('ok_blacklisted'))
end)

RSGCore.Functions.CreateCallback('rsg-townhall:server:removeBlacklist', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    local id = type(payload) == 'table' and math.tointeger(tonumber(payload.id))
    if not id then cb(fail('err_invalid')) return end
    local row = MySQL.single.await('SELECT id, citizenid, job FROM townhall_blacklist WHERE id = ?', { id })
    if not row then cb(fail('err_not_found')) return end
    if not scopeAllows(getScope(src, Player), row.job) then cb(fail('err_no_permission')) return end
    MySQL.update.await('DELETE FROM townhall_blacklist WHERE id = ?', { id })
    rsgLog('Blacklist removed', 'green', ('%s lifted the bar on %s (%s)'):format(Player.PlayerData.citizenid, row.citizenid, row.job))
    cb(success('ok_unblacklisted'))
end)

---------------------------------------------------------------------------
-- Probation
---------------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-townhall:server:decideProbation', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if type(payload) ~= 'table' then cb(fail('err_invalid')) return end
    local id, decision = math.tointeger(tonumber(payload.id)), payload.decision
    if not id or (decision ~= 'confirm' and decision ~= 'end') then cb(fail('err_invalid')) return end
    if not throttle(src, 'probation', 1000) then cb(fail('err_slow_down')) return end

    local row = MySQL.single.await("SELECT id, citizenid, name, job FROM townhall_probation WHERE id = ? AND status = 'active'", { id })
    if not row then cb(fail('err_not_found')) return end
    if not scopeAllows(getScope(src, Player), row.job) then cb(fail('err_no_permission')) return end
    if isSelfReview(Player, { citizenid = row.citizenid }, RSGCore.Functions.GetPlayerByCitizenId(row.citizenid)) then cb(fail('err_self_review')) return end

    local n = MySQL.update.await("UPDATE townhall_probation SET status = ?, decided_by = ?, decided_at = NOW() WHERE id = ? AND status = 'active'",
        { decision == 'confirm' and 'confirmed' or 'ended', Player.PlayerData.citizenid, id })
    if n ~= 1 then cb(fail('err_not_found')) return end

    local label = jobLabel(defOf(row.job), row.job)
    if decision == 'confirm' then
        notifyCitizen(row.citizenid, locale('notify_probation_confirmed', label), 'success', true)
        rsgLog('Probation confirmed', 'green', ('%s confirmed %s in %s'):format(Player.PlayerData.citizenid, row.citizenid, row.job))
    else
        exports['rsg-core']:RemovePlayerJob(row.citizenid, row.job)
        notifyCitizen(row.citizenid, locale('notify_probation_ended', label), 'warning', true)
        rsgLog('Probation ended early', 'red', ('%s ended the probation of %s in %s'):format(Player.PlayerData.citizenid, row.citizenid, row.job))
    end
    TriggerEvent('rsg-townhall:server:probationDecided', { citizenid = row.citizenid, job = row.job, decision = decision == 'confirm' and 'confirmed' or 'ended' })
    cb(success(decision == 'confirm' and 'ok_probation_confirmed' or 'ok_probation_ended'))
end)

---------------------------------------------------------------------------
-- Invitations (a boss or manager invites a specific citizen)
---------------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-townhall:server:invitePlayer', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if not Config.AllowInvites then cb(fail('err_invites_disabled')) return end
    if type(payload) ~= 'table' then cb(fail('err_invalid')) return end
    if not throttle(src, 'invite', 2000) then cb(fail('err_slow_down')) return end
    local scope = getScope(src, Player)
    if not scope.any then cb(fail('err_no_permission')) return end

    local job = payload.job
    local def = getJobDef(job)
    if not def or not jobAllowed(job) then cb(fail('err_job_invalid')) return end
    if not scopeAllows(scope, job) then cb(fail('err_no_permission')) return end
    local grade = math.tointeger(tonumber(payload.grade))
    local g = grade and gradeOf(def, grade)
    if not g then cb(fail('err_grade_invalid')) return end
    if g.isboss and Config.RestrictBossGrades and not scope.admin then cb(fail('err_no_permission')) return end

    local input, ierr = cleanText(payload.player, 50)
    if not input then cb(fail(ierr)) return end
    local msg, merr = cleanText(payload.message, Config.Limits.message or 300, true)
    if not msg then cb(fail(merr)) return end
    local days = readProbation(payload.probationDays)
    if not days then cb(fail('err_invalid')) return end

    local cid, name, target = resolvePlayer(input)
    if not cid then cb(fail(name)) return end
    if cid == Player.PlayerData.citizenid and not Config.AllowSelfReview then cb(fail('err_self_review')) return end
    if target and exports['rsg-core']:HasPlayerJob(target.PlayerData.source, job) then cb(fail('err_applicant_has_job')) return end
    if Config.AllowBlacklist and MySQL.scalar.await("SELECT 1 FROM townhall_blacklist WHERE citizenid = ? AND (job = ? OR job = '*') LIMIT 1", { cid, job }) then
        cb(fail('err_blacklisted')) return
    end
    if MySQL.scalar.await("SELECT 1 FROM townhall_invites WHERE citizenid = ? AND job = ? AND status = 'pending' AND (expires_at IS NULL OR expires_at > NOW()) LIMIT 1", { cid, job }) then
        cb(fail('err_invite_exists')) return
    end
    local open = MySQL.scalar.await("SELECT COUNT(*) FROM townhall_invites WHERE citizenid = ? AND status = 'pending' AND (expires_at IS NULL OR expires_at > NOW())", { cid }) or 0
    if open >= (Config.MaxPendingInvites or 3) then cb(fail('err_max_invites')) return end

    local expiry = math.max(0, math.floor(tonumber(Config.InviteExpiryDays) or 7))
    local id = MySQL.insert.await([[
        INSERT INTO townhall_invites (citizenid, name, job, grade, message, probation_days, invited_by, invited_by_name, notified, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, IF(? > 0, DATE_ADD(NOW(), INTERVAL ? DAY), NULL))]],
        { cid, name, job, grade, msg, days, Player.PlayerData.citizenid, playerName(Player), target and 1 or 0, expiry, expiry })
    if not id or id == 0 then cb(fail('err_generic')) return end

    local text = locale('notify_invited', playerName(Player), jobLabel(def, job))
    if target then notify(target.PlayerData.source, text, 'inform') else sendTelegram(cid, locale('notify_title'), text) end
    rsgLog('Invitation sent', 'blue', ('%s invited %s to %s grade %s'):format(Player.PlayerData.citizenid, cid, job, grade))
    cb(success('ok_invited'))
end)

RSGCore.Functions.CreateCallback('rsg-townhall:server:cancelInvite', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    local id = type(payload) == 'table' and math.tointeger(tonumber(payload.id))
    if not id then cb(fail('err_invalid')) return end
    local row = MySQL.single.await("SELECT id, citizenid, job FROM townhall_invites WHERE id = ? AND status = 'pending'", { id })
    if not row then cb(fail('err_not_found')) return end
    if not scopeAllows(getScope(src, Player), row.job) then cb(fail('err_no_permission')) return end
    if MySQL.update.await("UPDATE townhall_invites SET status = 'cancelled' WHERE id = ? AND status = 'pending'", { id }) ~= 1 then cb(fail('err_not_found')) return end
    rsgLog('Invitation cancelled', 'amber', ('%s cancelled invitation #%s for %s (%s)'):format(Player.PlayerData.citizenid, id, row.citizenid, row.job))
    cb(success('ok_invite_cancelled'))
end)

RSGCore.Functions.CreateCallback('rsg-townhall:server:answerInvite', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    if type(payload) ~= 'table' then cb(fail('err_invalid')) return end
    local id = math.tointeger(tonumber(payload.id))
    if not id or type(payload.accept) ~= 'boolean' then cb(fail('err_invalid')) return end
    if not throttle(src, 'answerinvite', 1500) then cb(fail('err_slow_down')) return end
    local cid = Player.PlayerData.citizenid

    local inv = MySQL.single.await("SELECT id, job, grade, probation_days, invited_by FROM townhall_invites WHERE id = ? AND citizenid = ? AND status = 'pending' AND (expires_at IS NULL OR expires_at > NOW())", { id, cid })
    if not inv then cb(fail('err_not_found')) return end
    local label = jobLabel(defOf(inv.job), inv.job)

    if not payload.accept then
        if MySQL.update.await("UPDATE townhall_invites SET status = 'declined' WHERE id = ? AND status = 'pending'", { id }) ~= 1 then cb(fail('err_not_found')) return end
        notifyCitizen(inv.invited_by, locale('notify_invite_declined', playerName(Player), label), 'warning', true)
        cb(success('ok_invite_declined'))
        return
    end

    if exports['rsg-core']:HasPlayerJob(src, inv.job) then cb(fail('err_has_job')) return end
    -- the job may have been blocked, or the player barred, since the invitation was sent
    if not getJobDef(inv.job) or not jobAllowed(inv.job) then cb(fail('err_job_invalid')) return end
    if Config.AllowBlacklist and MySQL.scalar.await("SELECT 1 FROM townhall_blacklist WHERE citizenid = ? AND (job = ? OR job = '*') LIMIT 1", { cid, inv.job }) then
        cb(fail('err_blacklisted')) return
    end
    -- claim first so a double click can never grant the job twice
    if MySQL.update.await("UPDATE townhall_invites SET status = 'accepted' WHERE id = ? AND status = 'pending'", { id }) ~= 1 then cb(fail('err_not_found')) return end
    local ok, reason = exports['rsg-core']:AddPlayerJob(src, inv.job, tonumber(inv.grade), Config.BypassMaxJobs)
    if not ok then
        MySQL.update.await("UPDATE townhall_invites SET status = 'pending' WHERE id = ? AND status = 'accepted'", { id })
        cb(fail(approveErrors[reason] or 'err_generic'))
        return
    end
    if Config.SetActiveJobOnApproval then Player.Functions.SetJob(inv.job, tonumber(inv.grade)) end
    startProbation(cid, playerName(Player), inv.job, inv.probation_days, nil, 'invite')
    notifyCitizen(inv.invited_by, locale('notify_invite_accepted', playerName(Player), label), 'success', true)
    TriggerEvent('rsg-townhall:server:applicationDecided', { id = 0, citizenid = cid, job = inv.job, grade = tonumber(inv.grade), decision = 'approved', invite = true })
    rsgLog('Invitation accepted', 'green', ('%s accepted the invitation to %s grade %s'):format(cid, inv.job, inv.grade))
    cb(success('ok_invite_accepted'))
end)

---------------------------------------------------------------------------
-- Statistics (+ CSV export for admins)
---------------------------------------------------------------------------
local function statsWindow(v)
    local n = math.tointeger(tonumber(v))
    for _, d in ipairs(Config.StatsDays or { 30 }) do if d == n then return n end end
    return nil
end

local function buildStats(scope, days)
    local clause, params = scopeClause(scope, 'p.job')
    local args = {}
    for i, v in ipairs(params) do args[i] = v end
    args[#args + 1] = days
    args[#args + 1] = days
    local window = "AND (? = 0 OR p.created_at >= DATE_SUB(NOW(), INTERVAL ? DAY))"

    local byJob = {}
    for _, r in ipairs(MySQL.query.await(([[
        SELECT p.job, COUNT(DISTINCT p.id) AS postings, COUNT(a.id) AS applications,
               COALESCE(SUM(a.status = 'approved'), 0) AS approved, COALESCE(SUM(a.status = 'rejected'), 0) AS rejected,
               AVG(IF(a.status IN ('approved', 'rejected') AND a.reviewed_at IS NOT NULL, TIMESTAMPDIFF(MINUTE, a.created_at, a.reviewed_at), NULL)) AS avg_decision_min
        FROM townhall_postings p LEFT JOIN townhall_applications a ON a.posting_id = p.id
        WHERE %s %s GROUP BY p.job]]):format(clause, window), args) or {}) do
        byJob[r.job] = { postings = tonumber(r.postings) or 0, applications = tonumber(r.applications) or 0, approved = tonumber(r.approved) or 0,
            rejected = tonumber(r.rejected) or 0, avgDecisionMin = r.avg_decision_min and math.floor(tonumber(r.avg_decision_min)) or nil }
    end
    for _, r in ipairs(MySQL.query.await(([[
        SELECT p.job, COALESCE(SUM(p.filled_count), 0) AS hires,
               AVG(IF(p.status = 'filled' AND p.closed_at IS NOT NULL, TIMESTAMPDIFF(MINUTE, p.created_at, p.closed_at), NULL)) AS avg_fill_min
        FROM townhall_postings p WHERE %s %s GROUP BY p.job]]):format(clause, window), args) or {}) do
        local e = byJob[r.job]
        if e then e.hires, e.avgFillMin = tonumber(r.hires) or 0, r.avg_fill_min and math.floor(tonumber(r.avg_fill_min)) or nil end
    end

    local out = {}
    for job, e in pairs(byJob) do
        local decided = e.approved + e.rejected
        e.job, e.label = job, jobLabel(defOf(job), job)
        e.rate = decided > 0 and math.floor(e.approved * 100 / decided + 0.5) or nil
        out[#out + 1] = e
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

RSGCore.Functions.CreateCallback('rsg-townhall:server:getStats', function(source, cb, payload)
    local Player, err = ctx(source, 'stats')
    if not Player then cb(fail(err)) return end
    local scope = getScope(source, Player)
    if not scope.any then cb(fail('err_no_permission')) return end
    local days = statsWindow(type(payload) == 'table' and payload.days or nil)
    if not days then days = (Config.StatsDays or { 30 })[1] end
    cb({ ok = true, days = days, rows = buildStats(scope, days) })
end)

local function csvCell(v)
    v = tostring(v == nil and '' or v)
    if v:find('^[=+%-@\t\r]') then v = "'" .. v end -- a spreadsheet must never read a cell as a formula
    return '"' .. v:gsub('"', '""') .. '"'
end

RSGCore.Functions.CreateCallback('rsg-townhall:server:exportStats', function(source, cb, payload)
    local src = source
    local Player, err = ctx(src)
    if not Player then cb(fail(err)) return end
    local scope = getScope(src, Player)
    if not scope.admin then cb(fail('err_no_permission')) return end
    if not throttle(src, 'export', 5000) then cb(fail('err_slow_down')) return end
    local days = statsWindow(type(payload) == 'table' and payload.days or nil)
    if not days then days = (Config.StatsDays or { 30 })[1] end

    local lines = { 'job,vacancies,applications,approved,rejected,approval_rate_percent,avg_decision_minutes,hires,avg_minutes_to_fill' }
    for _, r in ipairs(buildStats(scope, days)) do
        lines[#lines + 1] = table.concat({ csvCell(r.label), r.postings, r.applications, r.approved, r.rejected, r.rate or '', r.avgDecisionMin or '', r.hires or 0, r.avgFillMin or '' }, ',')
    end
    local file = ('%s/townhall_stats_%s.csv'):format(Config.StatsExportFolder or 'exports', os.date('%Y%m%d_%H%M%S'))
    if not SaveResourceFile(GetCurrentResourceName(), file, table.concat(lines, '\n') .. '\n', -1) then cb(fail('err_export_failed')) return end
    rsgLog('Statistics exported', 'blue', ('%s exported %s'):format(Player.PlayerData.citizenid, file))
    cb({ ok = true, msg = locale('ok_exported', file) })
end)

---------------------------------------------------------------------------
-- Exports for other resources
---------------------------------------------------------------------------
exports('HasPendingApplication', function(citizenid, job)
    if type(citizenid) ~= 'string' then return false end
    local sql = ("SELECT 1 FROM townhall_applications a JOIN townhall_postings p ON p.id = a.posting_id WHERE a.citizenid = ? AND a.status IN %s"):format(ACTIVE)
    local params = { citizenid }
    if type(job) == 'string' then sql, params[2] = sql .. ' AND p.job = ?', job end
    return MySQL.scalar.await(sql .. ' LIMIT 1', params) ~= nil
end)

exports('GetOpenVacancyCount', function(job)
    return type(job) == 'string' and countOpen(job) or 0
end)

exports('IsOnProbation', function(citizenid, job)
    if type(citizenid) ~= 'string' or type(job) ~= 'string' then return false end
    return MySQL.scalar.await("SELECT 1 FROM townhall_probation WHERE citizenid = ? AND job = ? AND status = 'active' LIMIT 1", { citizenid, job }) ~= nil
end)

exports('IsBlacklisted', function(citizenid, job)
    if type(citizenid) ~= 'string' then return false end
    return MySQL.scalar.await("SELECT 1 FROM townhall_blacklist WHERE citizenid = ? AND (job = ? OR job = '*') LIMIT 1", { citizenid, tostring(job) }) ~= nil
end)

---------------------------------------------------------------------------
-- Expiry, login reminder and startup
---------------------------------------------------------------------------
local function expireVacancies()
    local rows = MySQL.query.await("SELECT id, title FROM townhall_postings WHERE status = 'open' AND expires_at IS NOT NULL AND expires_at <= NOW()") or {}
    for _, r in ipairs(rows) do
        local n = MySQL.update.await("UPDATE townhall_postings SET status = 'expired', closed_at = NOW() WHERE id = ? AND status = 'open'", { r.id })
        if n == 1 then
            closePending(r.id, r.title)
            rsgLog('Vacancy expired', 'amber', ('vacancy #%s (%s) expired'):format(r.id, r.title))
        end
    end

    local warnH = tonumber(Config.ExpiryWarnHours) or 0
    if warnH > 0 then
        local soon = MySQL.query.await("SELECT id, title, posted_by FROM townhall_postings WHERE status = 'open' AND warned = 0 AND expires_at IS NOT NULL AND expires_at > NOW() AND expires_at <= DATE_ADD(NOW(), INTERVAL ? HOUR)", { warnH }) or {}
        for _, r in ipairs(soon) do
            -- only marked as warned once the poster actually received it
            if notifyCitizen(r.posted_by, locale('notify_expiring', r.title, warnH), 'warning') then
                MySQL.update.await('UPDATE townhall_postings SET warned = 1 WHERE id = ?', { r.id })
            end
        end
    end
end

local function expireInvites()
    MySQL.update.await("UPDATE townhall_invites SET status = 'expired' WHERE status = 'pending' AND expires_at IS NOT NULL AND expires_at <= NOW()")
end

-- probation that ran out without a boss confirming it: the job is taken away again
local function processProbation()
    local rows = MySQL.query.await("SELECT id, citizenid, job FROM townhall_probation WHERE status = 'active' AND ends_at <= NOW() LIMIT 50") or {}
    for _, r in ipairs(rows) do
        if MySQL.update.await("UPDATE townhall_probation SET status = 'ended', decided_at = NOW() WHERE id = ? AND status = 'active'", { r.id }) == 1 then
            exports['rsg-core']:RemovePlayerJob(r.citizenid, r.job)
            notifyCitizen(r.citizenid, locale('notify_probation_ended', jobLabel(defOf(r.job), r.job)), 'warning', true)
            rsgLog('Probation ended', 'red', ('probation of %s in %s ended without confirmation'):format(r.citizenid, r.job))
            TriggerEvent('rsg-townhall:server:probationDecided', { citizenid = r.citizenid, job = r.job, decision = 'ended', expired = true })
        end
    end
end

local function tick()
    expireVacancies()
    expireInvites()
    processProbation()
end

local function registerSocietyPermission()
    if Config.UseSocietyPermission and GetResourceState('rsg-society') == 'started' then
        pcall(function() exports['rsg-society']:RegisterPermission(Config.SocietyPermission or 'townhall_post', false) end)
    end
end

AddEventHandler('onResourceStart', function(res)
    if res == 'rsg-society' then SetTimeout(1500, registerSocietyPermission) end
end)

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    if not Player or not Player.PlayerData then return end
    local cid, src = Player.PlayerData.citizenid, Player.PlayerData.source
    SetTimeout(10000, function()
        local P = RSGCore.Functions.GetPlayer(src)
        if not P or P.PlayerData.citizenid ~= cid then return end
        grantPending(P)
        payRefunds(P)
        local n = MySQL.scalar.await('SELECT COUNT(*) FROM townhall_applications WHERE citizenid = ? AND seen = 0 AND notified = 0', { cid }) or 0
        local pc = pendingReviewCount(getScope(src, P))
        if pc > 0 then notify(src, locale('notify_pending_reviews', pc), 'inform') end
        local ni = MySQL.scalar.await("SELECT COUNT(*) FROM townhall_invites WHERE citizenid = ? AND status = 'pending' AND notified = 0 AND (expires_at IS NULL OR expires_at > NOW())", { cid }) or 0
        if ni > 0 then
            notify(src, locale('notify_invites_waiting', ni), 'inform')
            MySQL.update.await('UPDATE townhall_invites SET notified = 1 WHERE citizenid = ? AND notified = 0', { cid })
        end
        if n > 0 then
            notify(src, locale('notify_unseen', n), 'inform')
            MySQL.update.await('UPDATE townhall_applications SET notified = 1 WHERE citizenid = ? AND notified = 0', { cid })
        end
    end)
end)

CreateThread(function()
    if Config.AutoDatabase and not ensureDatabase() then return end
    -- a crash mid-grant leaves granted = 3; hand those back to the login queue
    MySQL.update.await('UPDATE townhall_applications SET granted = 0 WHERE granted = 3')
    loadLocations()
    loadManagers()
    syncLocations()
    registerSocietyPermission()
    local function safeTick()
        local ok, e = pcall(tick)
        if not ok then print(('^1[rsg-townhall] periodic check failed: %s^7'):format(tostring(e))) end
    end
    safeTick()
    while true do
        Wait(math.max(1, Config.ExpiryCheckMinutes or 5) * 60000)
        safeTick()
    end
end)
