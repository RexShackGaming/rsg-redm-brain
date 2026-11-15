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

local function cleanText(v, maxLen, allowEmpty)
    if type(v) ~= 'string' then return nil, 'err_invalid' end
    v = v:gsub('[\0-\8\11\12\14-\31]', ''):gsub('^%s+', ''):gsub('%s+$', '')
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

AddEventHandler('playerDropped', function()
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

local function getScope(src, Player)
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
    return not missing, { items = items, job = job }
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

local function notifyCitizen(citizenid, text, ntype)
    local P = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if P then
        notify(P.PlayerData.source, text, ntype)
        return true
    end
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
        SELECT a.id, p.job, p.grade, p.title FROM townhall_applications a
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
               posted_by_name, UNIX_TIMESTAMP(created_at) AS created,
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
        SELECT id, job, grade, title, questions, status, slots, filled_count, req_items, req_job, req_job_grade, location_id,
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
        "INSERT INTO townhall_applications (posting_id, citizenid, applicant_name, answers, fee) SELECT ?, ?, ?, ?, ? FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM townhall_applications WHERE posting_id = ? AND citizenid = ? AND (status IN ('pending', 'interview') OR (status = 'approved' AND granted <> 1)))",
        { postingId, cid, playerName(Player), json.encode(stored), fee, postingId, cid })
    if not id or id == 0 then
        if fee > 0 then Player.Functions.AddMoney(account, fee, 'townhall-application-fee-refund') end
        cb(fail('err_already_applied')) return
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
    cb({ ok = true, applications = out })
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
    for _, pj in ipairs(exports['rsg-core']:GetPlayerJobs(source) or {}) do
        if not BlockedJobs[pj.job] then
            out[#out + 1] = { job = pj.job, label = pj.jobLabel or pj.job, grade = pj.gradeLabel or tostring(pj.grade or ''), pay = pj.salary or 0 }
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
    rsgLog('Job resigned', 'amber', ('%s resigned from %s'):format(Player.PlayerData.citizenid, job))
    cb(success('ok_resigned'))
end)

---------------------------------------------------------------------------
-- Management: data
---------------------------------------------------------------------------
local function mapApps(rows)
    local out = {}
    for _, r in ipairs(rows) do
        local d = defOf(r.job)
        local g = gradeOf(d, r.grade)
        out[#out + 1] = {
            id = r.id, applicant = r.applicant_name, status = r.status, feedback = r.feedback,
            interviewNote = r.interview_note, reviewedBy = r.reviewed_by_name, created = r.created, title = r.title,
            jobLabel = jobLabel(d, r.job), gradeLabel = g and g.name or tostring(r.grade),
            answers = decode(r.answers) or {},
            online = RSGCore.Functions.GetPlayerByCitizenId(r.citizenid) ~= nil,
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
               p.posted_by_name, p.req_items, p.req_job, p.req_job_grade, UNIX_TIMESTAMP(p.created_at) AS created,
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
        postings[#postings + 1] = {
            id = r.id, title = r.title, status = r.status, jobLabel = jobLabel(d, r.job), expiry = expiryFor(scope, r.job),
            gradeLabel = g and g.name or tostring(r.grade), postedBy = r.posted_by_name,
            slots = r.slots, filledCount = r.filled_count, expiresIn = r.expires_in,
            location = loc and loc.label or '', created = r.created, pending = r.pending,
            description = r.description, requirements = r.requirements, custom = decode(r.questions) or {},
            job = r.job, grade = tonumber(r.grade), locationId = r.location_id,
            reqItems = decode(r.req_items) or {}, reqJob = r.req_job, reqJobGrade = r.req_job_grade,
            stats = { total = r.total, approved = r.approved, rejected = r.rejected, avgMin = r.avg_min and math.floor(tonumber(r.avg_min)) or nil },
        }
    end

    local appSelect = [[
        SELECT a.id, a.citizenid, a.applicant_name, a.answers, a.status, a.feedback, a.interview_note, a.reviewed_by_name,
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

    local locs = {}
    for _, l in pairs(Locations) do locs[#locs + 1] = { id = l.id, label = l.label } end
    table.sort(locs, function(a, b) return a.label < b.label end)
    local items = {}
    for item in pairs(PrereqItems) do items[#items + 1] = { name = item, label = itemLabel(item) } end
    table.sort(items, function(a, b) return a.label < b.label end)

    cb({
        ok = true, admin = scope.admin, allScope = scope.all, jobs = listJobs(scope), postings = postings,
        pending = mapApps(pendingRows), reviewed = mapApps(doneRows), managers = managers, blacklist = blacklist, blacklistEnabled = Config.AllowBlacklist,
        locations = locs, prereqItems = items, allJobs = Config.AllowJobPrerequisites and listAllJobs() or {},
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

    if countOpen(job) >= Config.MaxOpenPostingsPerJob then cb(fail('err_max_postings')) return end

    local id = MySQL.insert.await([[
        INSERT INTO townhall_postings (job, grade, title, description, requirements, questions, slots, expires_at, location_id,
                                       req_items, req_job, req_job_grade, posted_by, posted_by_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, IF(? > 0, DATE_ADD(NOW(), INTERVAL ? DAY), NULL), ?, ?, ?, ?, ?, ?)]],
        { job, tostring(grade), texts.title, texts.desc, texts.reqs, json.encode(texts.custom), slots, days, days, locId,
          json.encode(reqItems), reqJob, reqGrade, Player.PlayerData.citizenid, playerName(Player) })
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
                                           req_items, req_job, req_job_grade, posted_by, posted_by_name)
            SELECT job, grade, title, description, requirements, questions, slots,
                   IF(? > 0, DATE_ADD(NOW(), INTERVAL ? DAY), NULL), location_id, req_items, req_job, req_job_grade, ?, ?
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
    SELECT a.id, a.posting_id, a.citizenid, a.applicant_name, a.status, p.job, p.grade, p.title
    FROM townhall_applications a JOIN townhall_postings p ON p.id = a.posting_id WHERE a.id = ?]]

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
    if not scopeAllows(getScope(src, Player), app.job) then cb(fail('err_no_permission')) return end
    local applicantPlayer = RSGCore.Functions.GetPlayerByCitizenId(app.citizenid)
    if isSelfReview(Player, app, applicantPlayer) then cb(fail('err_self_review')) return end

    local note, nerr, minLen = readFeedback(payload.message)
    if not note then cb(fail(nerr, minLen)) return end
    if note == '' then cb(fail('err_required')) return end

    local n = MySQL.update.await("UPDATE townhall_applications SET status = 'interview', interview_note = ?, reviewed_by = ?, reviewed_by_name = ?, seen = 0, notified = 0 WHERE id = ? AND status = 'pending'",
        { note, Player.PlayerData.citizenid, playerName(Player), appId })
    if n ~= 1 then cb(fail('err_already_reviewed')) return end
    if applicantPlayer then
        notify(applicantPlayer.PlayerData.source, locale('notify_interview', playerName(Player), app.title), 'inform')
        markNotified(appId)
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
        MySQL.update.await("UPDATE townhall_postings SET status = IF(status = 'filled', 'open', status), filled_count = GREATEST(0, filled_count - 1) WHERE id = ?", { postingId })
    end
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

    local app = MySQL.single.await(APP_SELECT, { appId })
    if not app then cb(fail('err_not_found')) return end
    if app.status ~= 'pending' and app.status ~= 'interview' then cb(fail('err_already_reviewed')) return end
    if not scopeAllows(getScope(src, Player), app.job) then cb(fail('err_no_permission')) return end

    local applicantPlayer = RSGCore.Functions.GetPlayerByCitizenId(app.citizenid)
    if isSelfReview(Player, app, applicantPlayer) then cb(fail('err_self_review')) return end

    local feedback, ferr, minLen = readFeedback(payload.feedback)
    if not feedback then cb(fail(ferr, minLen)) return end

    local reviewerCid, reviewerName = Player.PlayerData.citizenid, playerName(Player)

    if decision == 'reject' then
        local n = MySQL.update.await(("UPDATE townhall_applications SET status = 'rejected', feedback = ?, reviewed_by = ?, reviewed_by_name = ?, reviewed_at = NOW(), seen = 0, notified = 0 WHERE id = ? AND status IN %s"):format(ACTIVE),
            { feedback, reviewerCid, reviewerName, appId })
        if n ~= 1 then cb(fail('err_already_reviewed')) return end
        if notifyCitizen(app.citizenid, locale('notify_app_rejected', app.title), 'error') then markNotified(appId) end
        TriggerEvent('rsg-townhall:server:applicationDecided', { id = appId, citizenid = app.citizenid, job = app.job, grade = tonumber(app.grade), decision = 'rejected' })
        rsgLog('Application rejected', 'red', ('%s rejected application #%s (%s)'):format(reviewerCid, appId, app.title))
        cb(success('ok_rejected'))
        return
    end

    -- approve
    local target = applicantPlayer
    if not target and not Config.AllowOfflineApproval then cb(fail('err_applicant_offline')) return end
    if target and exports['rsg-core']:HasPlayerJob(target.PlayerData.source, app.job) then cb(fail('err_applicant_has_job')) return end

    local claimed = MySQL.update.await(("UPDATE townhall_applications SET status = 'approved', granted = ?, feedback = ?, reviewed_by = ?, reviewed_by_name = ?, reviewed_at = NOW(), seen = 0, notified = 0 WHERE id = ? AND status IN %s"):format(ACTIVE),
        { target and 1 or 0, feedback, reviewerCid, reviewerName, appId })
    if claimed ~= 1 then cb(fail('err_already_reviewed')) return end

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
        cb(fail('err_posting_closed'))
        return
    end

    if target then
        local ok, reason = exports['rsg-core']:AddPlayerJob(target.PlayerData.source, app.job, tonumber(app.grade), Config.BypassMaxJobs)
        if not ok then
            revertApproval(appId, app.status, app.posting_id)
            cb(fail(approveErrors[reason] or 'err_generic'))
            return
        end
        if Config.SetActiveJobOnApproval then target.Functions.SetJob(app.job, tonumber(app.grade)) end
        notify(target.PlayerData.source, locale('notify_app_approved', app.title), 'success')
        markNotified(appId)
    end

    local postingStatus = MySQL.scalar.await('SELECT status FROM townhall_postings WHERE id = ?', { app.posting_id })
    if postingStatus == 'filled' then closePending(app.posting_id, app.title) end

    TriggerEvent('rsg-townhall:server:applicationDecided', { id = appId, citizenid = app.citizenid, job = app.job, grade = tonumber(app.grade), decision = 'approved', queued = target == nil })
    rsgLog('Application approved', 'green', ('%s approved application #%s: %s -> %s grade %s%s'):format(
        reviewerCid, appId, app.citizenid, app.job, app.grade, target and '' or ' (queued, applicant offline)'))
    cb(success(target and 'ok_approved' or 'ok_approved_queued'))
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

    local row = MySQL.single.await('SELECT a.id, a.status, p.questions FROM townhall_applications a JOIN townhall_postings p ON p.id = a.posting_id WHERE a.id = ? AND a.citizenid = ?',
        { appId, Player.PlayerData.citizenid })
    if not row then cb(fail('err_not_found')) return end
    if row.status ~= 'pending' and row.status ~= 'interview' then cb(fail('err_already_reviewed')) return end

    local questions = buildQuestions(row)
    if #payload.answers ~= #questions then cb(fail('err_invalid')) return end
    local stored = {}
    for i, q in ipairs(questions) do
        local a, aerr = cleanText(payload.answers[i], q.max, true)
        if not a then cb(fail(aerr)) return end
        if q.required and a == '' then cb(fail('err_answers_required')) return end
        stored[#stored + 1] = { q = q.label, a = a }
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
        if n > 0 then
            notify(src, locale('notify_unseen', n), 'inform')
            MySQL.update.await('UPDATE townhall_applications SET notified = 1 WHERE citizenid = ? AND notified = 0', { cid })
        end
    end)
end)

CreateThread(function()
    if Config.AutoDatabase and not ensureDatabase() then return end
    loadLocations()
    loadManagers()
    syncLocations()
    expireVacancies()
    while true do
        Wait(math.max(1, Config.ExpiryCheckMinutes or 5) * 60000)
        expireVacancies()
    end
end)
