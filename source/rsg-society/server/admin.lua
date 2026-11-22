-- Admin panel (/societyadmin): everything an admin can see and change about every society, in one NUI.
-- Every callback re-checks Config.AdminPermission on the server; the NUI only asks, the server decides.
local RSGCore = Soc.Core
local ADMIN = Config.AdminPermission
local Cfg = Config.Admin or {}

local Tabs, Actions = {}, {}

-- A handler that errors must still answer, otherwise the panel waits for the full timeout.
local function registerCallback(name, fn)
    RSGCore.Functions.CreateCallback(name, function(source, cb, ...)
        local ok, res = pcall(fn, source, ...)
        if not ok then
            print(('^1[rsg-society] callback %s failed: %s^7'):format(name, tostring(res)))
            res = { ok = false, msg = locale('sv_err_unknown') }
        end
        cb(res)
    end)
end

local function reply(ok, key, ...)
    return { ok = ok, msg = locale(key, ...) }
end

local function decode(text)
    if type(text) ~= 'string' or text == '' then return nil end
    local ok, value = pcall(json.decode, text)
    return ok and value or nil
end

local function trim(s)
    return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

-----------------------------------------------------------------------
-- Guard: is this player an admin?
-----------------------------------------------------------------------
local function guard(src)
    if Cfg.Enabled == false then return nil, 'sv_adm_denied' end
    if not Soc.Ready then return nil, 'sv_err_not_ready' end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil, 'sv_err_player' end
    if not RSGCore.Functions.HasPermission(src, ADMIN) then return nil, 'sv_adm_denied' end
    local who = Soc.PlayerName(Player)
    return { src = src, Player = Player, cid = Player.PlayerData.citizenid, who = who, actor = who .. ' [admin]' }
end

local function audit(ctx, name, action, detail, targetCid, targetName)
    Soc.Audit(name, ctx.cid, ctx.actor, action, detail, targetCid, targetName)
end

-----------------------------------------------------------------------
-- Lookups
-----------------------------------------------------------------------
--- name of a character (online or offline) and the Player when online
local function charName(cid)
    local P = RSGCore.Functions.GetPlayerByCitizenId(cid)
    if P then return Soc.PlayerName(P), P end
    local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { cid })
    if not row then return nil end
    return Soc.FullName(decode(row.charinfo)), nil
end

--- accepts a server id or a citizen id; returns citizenid, name, Player
local function resolveTarget(value)
    if type(value) == 'number' then value = tostring(math.floor(value)) end
    value = trim(value)
    if value == '' or #value > 50 then return nil end
    if value:match('^%d+$') and #value <= 5 then
        local P = RSGCore.Functions.GetPlayer(tonumber(value))
        if P then return P.PlayerData.citizenid, Soc.PlayerName(P), P end
        return nil
    end
    if not value:match('^[%w_%-]+$') then return nil end
    local name, P = charName(value)
    if not name then return nil end
    return value, name, P
end

local function societyOf(data)
    local name = type(data.name) == 'string' and data.name or nil
    local s = name and Soc.S[name]
    if not s then return nil end
    return name, s
end

local function memberCount(name, s)
    if s.type == 'gang' then return Soc.GangMemberCount(name) end
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM player_jobs WHERE job = ?', { name })) or 0
end

local function deskCount(name)
    local n = 0
    for _, loc in pairs(Soc.Locations) do
        if loc.society == name then n = n + 1 end
    end
    return n
end

local function beforeId(arg)
    return math.max(0, math.floor(tonumber(arg.before) or 0))
end

-----------------------------------------------------------------------
-- Tabs (reads)
-----------------------------------------------------------------------
function Tabs.dashboard()
    local jobs, gangs, funds, top = 0, 0, 0, {}
    for name, s in pairs(Soc.S) do
        if s.type == 'gang' then gangs = gangs + 1 else jobs = jobs + 1 end
        funds = funds + s.balance
        top[#top + 1] = { name = name, label = Soc.Label(name), type = s.type, balance = s.balance / 100 }
    end
    table.sort(top, function(a, b) return a.balance > b.balance end)
    while #top > 5 do top[#top] = nil end

    local fines = MySQL.single.await("SELECT COUNT(*) AS c, COALESCE(SUM(amount_cents - paid_cents), 0) AS owed FROM rsg_society_fines WHERE status = 'unpaid'") or {}
    local desks = 0
    for _ in pairs(Soc.Locations) do desks = desks + 1 end

    local recent = {}
    for _, r in ipairs(MySQL.query.await("SELECT society, actor_name, action, target_name, detail, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i') AS created FROM rsg_society_audit ORDER BY id DESC LIMIT 8") or {}) do
        recent[#recent + 1] = {
            society = Soc.S[r.society] and Soc.Label(r.society) or r.society, actor = r.actor_name or '', action = r.action,
            target = r.target_name or '', detail = r.detail or '', date = r.created,
        }
    end

    local warnings = {}
    if not Config.Payroll.Enabled then
        warnings[#warnings + 1] = 'ui_adm_warn_payroll_off'
    elseif not (RSGCore.Config and RSGCore.Config.Money and RSGCore.Config.Money.PayCheckSociety) then
        warnings[#warnings + 1] = 'ui_adm_warn_paycheck'
    end

    return {
        jobs = jobs, gangs = gangs, funds = funds / 100, desks = desks,
        fineCount = tonumber(fines.c) or 0, fineOwed = (tonumber(fines.owed) or 0) / 100,
        top = top, recent = recent, warnings = warnings,
    }
end

--- rsg-core jobs that do not have a society yet
function Tabs.job_options()
    local list = {}
    local ok, defs = pcall(function() return exports['rsg-core']:GetJobDefinitions() end)
    if ok and type(defs) == 'table' then
        for key, def in pairs(defs) do
            local name = type(key) == 'string' and key or (type(def) == 'table' and def.name)
            if type(name) == 'string' and name ~= 'unemployed' and not Soc.S[name] then
                list[#list + 1] = { value = name, label = ('%s (%s)'):format(type(def) == 'table' and def.label or name, name) }
            end
        end
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return { jobs = list }
end

function Tabs.societies(_, arg)
    local search = trim(arg.search):lower():sub(1, 40)
    local sType = (arg.type == 'job' or arg.type == 'gang') and arg.type or ''
    local offset = math.max(0, math.floor(tonumber(arg.offset) or 0))

    local jobMembers = {}
    local ok, rows = pcall(function() return MySQL.query.await('SELECT job, COUNT(*) AS c FROM player_jobs GROUP BY job') end)
    if ok and rows then
        for _, r in ipairs(rows) do jobMembers[r.job] = tonumber(r.c) or 0 end
    end

    local list = {}
    for name, s in pairs(Soc.S) do
        local label = Soc.Label(name)
        if (sType == '' or s.type == sType) and (search == '' or label:lower():find(search, 1, true) or name:lower():find(search, 1, true)) then
            list[#list + 1] = {
                name = name, label = label, type = s.type, balance = s.balance / 100, payroll = s.payroll,
                color = s.color, tag = s.tag,
                members = s.type == 'gang' and Soc.GangMemberCount(name) or (jobMembers[name] or 0),
            }
        end
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)

    local out, size = {}, Config.PageSize
    for i = offset + 1, math.min(#list, offset + size) do out[#out + 1] = list[i] end
    return { rows = out, more = #list > offset + size, total = #list, offset = offset }
end

function Tabs.s_overview(_, arg)
    local name, s = societyOf(arg)
    if not name then return nil, 'sv_err_unknown' end
    local ownerName = s.owner and charName(s.owner) or nil
    local inConfig = Config.Jobs[name] ~= nil
    for _, loc in ipairs(Config.Locations) do
        if loc.society == name then inConfig = true end
    end
    return {
        name = name, type = s.type, label = Soc.Label(name), color = s.color, tag = s.tag,
        owner = s.owner, ownerName = ownerName, balance = s.balance / 100, payroll = s.payroll,
        payrollEnabled = Config.Payroll.Enabled, members = memberCount(name, s), desks = deskCount(name),
        inConfig = inConfig, colors = Config.Gang.Colors, maxTag = Config.Gang.MaxTagLength,
        maxName = Config.Gang.MaxNameLength, maxFunds = Cfg.MaxFunds or 10000000,
    }
end

function Tabs.s_members(_, arg)
    local name, s = societyOf(arg)
    if not name then return nil, 'sv_err_unknown' end
    local grades = {}
    for _, g in ipairs(Soc.Grades(name)) do grades[#grades + 1] = { level = g.level, name = g.name, boss = g.boss } end
    local rows = {}
    for _, m in ipairs(Soc.GetMembers(name)) do
        rows[#rows + 1] = { cid = m.citizenid, name = m.name, level = m.level, grade = m.grade, boss = m.boss, online = m.online, owner = s.owner == m.citizenid }
    end
    return { rows = rows, grades = grades, gang = s.type == 'gang' }
end

function Tabs.s_ranks(_, arg)
    local name, s = societyOf(arg)
    if not name then return nil, 'sv_err_unknown' end
    local grades = {}
    for _, g in ipairs(Soc.Grades(name)) do
        local set = Soc.PermsFor(name, g.level, g.boss)
        local list = {}
        for _, p in ipairs(Soc.PermList(s.type)) do
            if set[p] then list[#list + 1] = p end
        end
        grades[#grades + 1] = { level = g.level, name = g.name, pay = g.payment / 100, boss = g.boss, perms = list }
    end
    return {
        grades = grades, allPerms = Soc.PermList(s.type), gang = s.type == 'gang',
        count = #grades, maxRanks = Config.Gang.MaxRanks or 10, maxPay = Config.Gang.MaxRankPay,
    }
end

function Tabs.s_ledger(_, arg)
    local name = societyOf(arg)
    if not name then return nil, 'sv_err_unknown' end
    local before = beforeId(arg)
    local rows = MySQL.query.await(
        "SELECT id, kind, amount_cents, balance_cents, actor, note, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i') AS created FROM rsg_society_ledger WHERE society = ? AND (? = 0 OR id < ?) ORDER BY id DESC LIMIT ?",
        { name, before, before, Config.PageSize + 1 }) or {}
    local more = #rows > Config.PageSize
    if more then rows[#rows] = nil end
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { id = r.id, kind = r.kind, amount = r.amount_cents / 100, balance = r.balance_cents / 100, actor = r.actor or '', note = r.note or '', date = r.created }
    end
    return { rows = out, more = more }
end

local function auditRows(society, before)
    local rows = MySQL.query.await(
        "SELECT id, society, actor_name, action, target_name, detail, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i') AS created FROM rsg_society_audit WHERE (? = '' OR society = ?) AND (? = 0 OR id < ?) ORDER BY id DESC LIMIT ?",
        { society, society, before, before, Config.PageSize + 1 }) or {}
    local more = #rows > Config.PageSize
    if more then rows[#rows] = nil end
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = {
            id = r.id, society = Soc.S[r.society] and Soc.Label(r.society) or r.society, actor = r.actor_name or '',
            action = r.action, target = r.target_name or '', detail = r.detail or '', date = r.created,
        }
    end
    return out, more
end

function Tabs.s_audit(_, arg)
    local name = societyOf(arg)
    if not name then return nil, 'sv_err_unknown' end
    local rows, more = auditRows(name, beforeId(arg))
    return { rows = rows, more = more }
end

function Tabs.s_fines(_, arg)
    local name = societyOf(arg)
    if not name then return nil, 'sv_err_unknown' end
    local rows, more = Soc.FineRows(name, beforeId(arg))
    return { rows = rows, more = more }
end

--- society dropdown for the global lists
local function societyOptions()
    local list = {}
    for name in pairs(Soc.S) do list[#list + 1] = { value = name, label = Soc.Label(name) } end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return list
end

function Tabs.audit(_, arg)
    local society = (type(arg.society) == 'string' and Soc.S[arg.society]) and arg.society or ''
    local rows, more = auditRows(society, beforeId(arg))
    return { rows = rows, more = more, societies = societyOptions() }
end

local FineStatus = { unpaid = true, paid = true, void = true }
function Tabs.fines(_, arg)
    local status = FineStatus[arg.status] and arg.status or ''
    local society = (type(arg.society) == 'string' and Soc.S[arg.society]) and arg.society or ''
    local before = beforeId(arg)
    local rows = MySQL.query.await(
        "SELECT id, society, citizenid, target_name, issuer_name, amount_cents, paid_cents, reason, status, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i') AS created FROM rsg_society_fines WHERE (? = '' OR status = ?) AND (? = '' OR society = ?) AND (? = 0 OR id < ?) ORDER BY id DESC LIMIT ?",
        { status, status, society, society, before, before, Config.PageSize + 1 }) or {}
    local more = #rows > Config.PageSize
    if more then rows[#rows] = nil end
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = {
            id = r.id, society = Soc.S[r.society] and Soc.Label(r.society) or r.society, cid = r.citizenid, target = r.target_name or '',
            issuer = r.issuer_name or '', reason = r.reason or '', amount = r.amount_cents / 100, paid = r.paid_cents / 100,
            status = r.status, date = r.created,
        }
    end
    return { rows = out, more = more, societies = societyOptions() }
end

function Tabs.players(_, arg)
    local term = trim(arg.search):lower():sub(1, 40)
    local rows, seen = {}, {}
    local function push(cid, name, online, src)
        if seen[cid] or #rows >= 25 then return end
        seen[cid] = true
        local gang = Soc.GangOf[cid]
        rows[#rows + 1] = { cid = cid, name = name, online = online, src = src, gang = gang and Soc.Label(gang) or nil }
    end
    for _, id in ipairs(RSGCore.Functions.GetPlayers()) do
        local P = RSGCore.Functions.GetPlayer(tonumber(id))
        if P then
            local cid, name = P.PlayerData.citizenid, Soc.PlayerName(P)
            if term == '' or name:lower():find(term, 1, true) or cid:lower():find(term, 1, true) or tostring(id) == term then
                push(cid, name, true, tonumber(id))
            end
        end
    end
    if #term >= 2 then
        local like = '%' .. term:gsub('[%%_\\]', '') .. '%'
        for _, r in ipairs(MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE citizenid LIKE ? OR charinfo LIKE ? LIMIT 100', { like, like }) or {}) do
            local name = Soc.FullName(decode(r.charinfo))
            -- the charinfo column also holds field names, so check the real name again here
            if name:lower():find(term, 1, true) or r.citizenid:lower():find(term, 1, true) then
                local P = RSGCore.Functions.GetPlayerByCitizenId(r.citizenid)
                push(r.citizenid, name, P ~= nil, P and P.PlayerData.source or nil)
            end
        end
    end
    return { rows = rows }
end

function Tabs.player(_, arg)
    local cid = type(arg.cid) == 'string' and arg.cid or nil
    if not cid or #cid > 50 then return nil, 'sv_err_player' end
    local name, P = charName(cid)
    if not name then return nil, 'sv_err_player' end

    local memberships = {}
    for _, society in ipairs(Soc.SocietiesOf(cid)) do
        local acc = Soc.Access(cid, society, P)
        if acc then
            memberships[#memberships + 1] = { name = society, label = Soc.Label(society), type = acc.type, grade = acc.gradeName, level = acc.level, boss = acc.boss }
        end
    end
    local fines, owed = {}, 0
    for _, r in ipairs(MySQL.query.await("SELECT id, society, amount_cents, paid_cents, reason, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i') AS created FROM rsg_society_fines WHERE citizenid = ? AND status = 'unpaid' ORDER BY id DESC LIMIT 50", { cid }) or {}) do
        local left = (r.amount_cents - r.paid_cents) / 100
        owed = owed + left
        fines[#fines + 1] = { id = r.id, society = Soc.S[r.society] and Soc.Label(r.society) or r.society, amount = r.amount_cents / 100, left = left, reason = r.reason or '', date = r.created }
    end
    return { cid = cid, name = name, online = P ~= nil, src = P and P.PlayerData.source or nil, memberships = memberships, fines = fines, owed = owed }
end

function Tabs.desks()
    local rows = {}
    for id, loc in pairs(Soc.Locations) do
        rows[#rows + 1] = {
            id = id, label = loc.name, society = loc.society, societyLabel = Soc.S[loc.society] and Soc.Label(loc.society) or loc.society,
            x = loc.coords.x, y = loc.coords.y, z = loc.coords.z, config = loc.db == nil, blip = loc.showblip == true,
        }
    end
    table.sort(rows, function(a, b)
        if a.societyLabel ~= b.societyLabel then return a.societyLabel:lower() < b.societyLabel:lower() end
        return a.id < b.id
    end)
    return { rows = rows, societies = societyOptions() }
end

function Tabs.tools()
    local count = 0
    for _ in pairs(Soc.S) do count = count + 1 end
    return {
        version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '?',
        societies = count,
        payroll = Config.Payroll.Enabled, gangInterval = Config.Payroll.GangInterval,
        paycheck = (RSGCore.Config and RSGCore.Config.Money and RSGCore.Config.Money.PayCheckSociety) == true,
        pruneDays = Config.PruneDays or 0, autoDatabase = Config.AutoDatabase == true,
        logging = Config.Logging.enabled == true, permission = ADMIN,
    }
end

-----------------------------------------------------------------------
-- Actions (writes)
-----------------------------------------------------------------------
function Actions.create_job(ctx, data)
    local name = type(data.job) == 'string' and data.job:lower() or nil
    if not name or not Soc.JobExists(name) then return reply(false, 'sv_admin_no_job') end
    if Soc.S[name] then return reply(false, 'sv_admin_exists', name) end
    if not Soc.EnsureJob(name, true) then return reply(false, 'sv_err_unknown') end
    audit(ctx, name, 'admin_create')
    return { ok = true, msg = locale('sv_admin_added', name), society = name }
end

function Actions.create_gang(ctx, data)
    local label = Soc.CleanLabel(data.label)
    if not label then return reply(false, 'sv_err_gang_name') end
    if Soc.LabelTaken(label) then return reply(false, 'sv_err_gang_taken') end

    local ownerCid, ownerName
    if trim(data.leader) ~= '' then
        ownerCid, ownerName = resolveTarget(data.leader)
        if not ownerCid then return reply(false, 'sv_err_player') end
        if Soc.GangOf[ownerCid] then return reply(false, 'sv_err_in_gang') end
    end

    local opts
    for _, c in ipairs(Config.Gang.Colors) do
        if c == data.color then opts = { color = c } end
    end
    local ok, result = Soc.CreateGang(label, ownerCid, ownerName, opts)
    if not ok then return reply(false, result) end
    audit(ctx, result, 'admin_create', label, ownerCid, ownerName)
    return { ok = true, msg = locale('sv_adm_gang_created', label), society = result }
end

--- Deletes a job society row set (account, rank permissions, desks, history). The job itself stays in rsg-core.
--- Callers must have checked that it is a job society that may be removed.
function Soc.DeleteJobSociety(name)
    for _, q in ipairs({
        'DELETE FROM rsg_society_perms WHERE society = ?',
        'DELETE FROM rsg_society_ranks WHERE society = ?',
        'DELETE FROM rsg_society_locations WHERE society = ?',
        'DELETE FROM rsg_society_ledger WHERE society = ?',
        'DELETE FROM rsg_society_audit WHERE society = ?',
        'DELETE FROM rsg_society_fines WHERE society = ?',
        'DELETE FROM rsg_societies WHERE name = ?',
    }) do MySQL.update.await(q, { name }) end
    MySQL.update.await('DELETE FROM rsg_society_meta WHERE k = ?', { 'motd:' .. name })

    Soc.S[name], Soc.Perms[name] = nil, nil
    for id, loc in pairs(Soc.Locations) do
        if loc.society == name then Soc.Locations[id] = nil end
    end
    Soc.BroadcastLocations()
end

--- Removes a job society (its account, rank permissions, desks and history). The job itself stays in rsg-core.
function Actions.delete_job(ctx, data)
    local name, s = societyOf(data)
    if not name or s.type ~= 'job' then return reply(false, 'sv_err_unknown') end
    if data.confirm ~= true then return reply(false, 'sv_err_unknown') end
    local label = Soc.Label(name)
    if Config.Jobs[name] then return reply(false, 'sv_adm_cfg_job') end
    for _, loc in ipairs(Config.Locations) do
        if loc.society == name then return reply(false, 'sv_adm_cfg_job') end
    end

    Soc.DeleteJobSociety(name)
    print(('^3[rsg-society] %s removed the job society %s (balance $%.2f)^7'):format(ctx.who, name, s.balance / 100))
    if Config.Logging.enabled then
        TriggerEvent('rsg-log:server:CreateLog', Config.Logging.channel, 'Society removed', 'red', ('%s removed %s'):format(ctx.who, label), false)
    end
    return { ok = true, msg = locale('sv_adm_removed', label), gone = true }
end

--- Deletes a gang. Members drop to no gang; the account is NOT paid out.
function Actions.disband(ctx, data)
    local name, s = societyOf(data)
    if not name or s.type ~= 'gang' then return reply(false, 'sv_adm_gang_only') end
    if data.confirm ~= true then return reply(false, 'sv_err_unknown') end
    local label = Soc.Label(name)
    local others = {}
    for cid in pairs(Soc.Members[name] or {}) do others[#others + 1] = cid end

    local balance = Soc.DisbandGang(name)
    print(('^3[rsg-society] %s disbanded the gang %s (balance $%.2f, not paid out)^7'):format(ctx.who, name, (balance or 0) / 100))
    if Config.Logging.enabled then
        TriggerEvent('rsg-log:server:CreateLog', Config.Logging.channel, 'Society disbanded', 'red', ('%s disbanded %s (admin panel)'):format(ctx.who, label), false)
    end
    for _, cid in ipairs(others) do
        local P = RSGCore.Functions.GetPlayerByCitizenId(cid)
        if P then Soc.Notify(P.PlayerData.source, label, locale('sv_disbanded_notice'), 'error') end
    end
    return { ok = true, msg = locale('sv_adm_disbanded', label), gone = true }
end

function Actions.funds(ctx, data)
    local name = societyOf(data)
    if not name then return reply(false, 'sv_err_unknown') end
    local mode = data.mode
    local cents = Soc.ToCents(data.amount)
    if (mode ~= 'add' and mode ~= 'remove') or not cents or cents > (Cfg.MaxFunds or 10000000) * 100 then return reply(false, 'sv_err_amount') end
    local note = Soc.Trunc(trim((tostring(data.reason or ''):gsub('[%c<>]', ''))), 120)
    if note == '' then note = ctx.who end

    if mode == 'add' then
        Soc.Credit(name, cents, 'admin', note, nil, ctx.who)
    elseif not Soc.Debit(name, cents, 'admin', note, nil, ctx.who) then
        return reply(false, 'sv_err_funds')
    end
    audit(ctx, name, 'admin_funds', ('%s $%.2f'):format(mode, cents / 100))
    return { ok = true, msg = locale('sv_admin_funds', Soc.Label(name), Soc.S[name].balance / 100) }
end

function Actions.payroll(ctx, data)
    local name, s = societyOf(data)
    if not name then return reply(false, 'sv_err_unknown') end
    local on = data.enabled == true
    s.payroll = on
    MySQL.update('UPDATE rsg_societies SET payroll = ? WHERE name = ?', { on and 1 or 0, name })
    audit(ctx, name, on and 'payroll_on' or 'payroll_off')
    return reply(true, on and 'sv_payroll_on' or 'sv_payroll_off')
end

function Actions.run_payroll(_, data)
    local name, s = societyOf(data)
    if not name or s.type ~= 'gang' then return reply(false, 'sv_adm_gang_only') end
    local paid, skipped = Soc.RunGangPayroll(name)
    return { ok = true, msg = locale('sv_adm_payroll_run', paid or 0, skipped or 0) }
end

function Actions.gang_info(ctx, data)
    local name, s = societyOf(data)
    if not name or s.type ~= 'gang' then return reply(false, 'sv_adm_gang_only') end
    local ok, key = Soc.SetInfo(name, { label = data.label, color = data.color, tag = data.tag }, ctx.cid, ctx.actor)
    if not ok then return reply(false, key) end
    return reply(true, key)
end

function Actions.set_owner(ctx, data)
    local name, s = societyOf(data)
    if not name or s.type ~= 'gang' then return reply(false, 'sv_adm_gang_only') end
    local cid = type(data.cid) == 'string' and data.cid or nil
    local m = cid and Soc.Members[name] and Soc.Members[name][cid]
    if not m then return reply(false, 'sv_err_not_member') end
    s.owner = cid
    MySQL.update('UPDATE rsg_societies SET owner = ? WHERE name = ?', { cid, name })
    TriggerEvent('rsg-society:server:gangUpdated', name)
    audit(ctx, name, 'transfer', nil, cid, m.name)
    return reply(true, 'sv_settings_saved')
end

function Actions.member_add(ctx, data)
    local name, s = societyOf(data)
    if not name then return reply(false, 'sv_err_unknown') end
    local cid, charLabel, P = resolveTarget(data.target)
    if not cid then return reply(false, 'sv_err_player') end
    local level = math.floor(tonumber(data.level) or -1)
    local grade = Soc.GradeOf(name, level)
    if not grade then return reply(false, 'sv_err_bad_rank') end

    local ok, why
    if s.type == 'gang' then
        ok, why = Soc.AddGangMember(name, cid, charLabel, level)
    else
        ok, why = Soc.AddJobMember(name, cid, level)
    end
    if not ok then return reply(false, why or 'sv_err_unknown') end
    audit(ctx, name, 'hire', grade.name, cid, charLabel)
    if P then Soc.Notify(P.PlayerData.source, Soc.Label(name), locale('sv_adm_you_added', Soc.Label(name)), 'success') end
    return { ok = true, msg = locale('sv_adm_member_added', charLabel) }
end

local function bossCount(name)
    local n = 0
    for _, m in pairs(Soc.Members[name] or {}) do
        local g = Soc.GradeOf(name, m.level)
        if g and g.boss then n = n + 1 end
    end
    return n
end

function Actions.member_level(ctx, data)
    local name, s = societyOf(data)
    if not name then return reply(false, 'sv_err_unknown') end
    local cid = type(data.cid) == 'string' and data.cid or nil
    local level = math.floor(tonumber(data.level) or -1)
    local newGrade = Soc.GradeOf(name, level)
    if not cid or not newGrade then return reply(false, 'sv_err_bad_rank') end

    local current, targetName
    if s.type == 'gang' then
        local m = Soc.Members[name] and Soc.Members[name][cid]
        if not m then return reply(false, 'sv_err_not_member') end
        current, targetName = m.level, m.name
        local oldGrade = Soc.GradeOf(name, current)
        if oldGrade and oldGrade.boss and not newGrade.boss and bossCount(name) <= 1 then return reply(false, 'sv_adm_last_boss') end
        if not Soc.SetGangLevel(name, cid, level) then return reply(false, 'sv_err_unknown') end
    else
        current = Soc.JobLevel(cid, name)
        if current == nil then return reply(false, 'sv_err_not_member') end
        targetName = charName(cid)
        if not Soc.SetJobLevel(name, cid, level) then return reply(false, 'sv_err_unknown') end
    end
    audit(ctx, name, level >= current and 'promote' or 'demote', newGrade.name, cid, targetName)
    return reply(true, 'sv_adm_level_set')
end

function Actions.member_remove(ctx, data)
    local name, s = societyOf(data)
    if not name then return reply(false, 'sv_err_unknown') end
    local cid = type(data.cid) == 'string' and data.cid or nil
    if not cid then return reply(false, 'sv_err_not_member') end
    local targetName = charName(cid) or '?'

    local ok
    if s.type == 'gang' then
        ok = Soc.RemoveGangMember(name, cid)
    else
        if Soc.JobLevel(cid, name) == nil then return reply(false, 'sv_err_not_member') end
        ok = Soc.RemoveJobMember(name, cid)
    end
    if not ok then return reply(false, 'sv_err_not_member') end
    audit(ctx, name, 'admin_remove', nil, cid, targetName)
    local P = RSGCore.Functions.GetPlayerByCitizenId(cid)
    if P then Soc.Notify(P.PlayerData.source, Soc.Label(name), locale('sv_you_fired', Soc.Label(name)), 'error') end
    return reply(true, 'sv_fired', targetName)
end

local function cleanRankName(value)
    local n = type(value) == 'string' and value:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '') or ''
    local len = utf8.len(n)
    if not len or len < 2 or len > 24 then return nil end
    return n
end

--- Saves one rank: permissions for jobs and gangs, plus name and wage for gangs (data.meta = { name, pay }).
function Actions.rank_save(ctx, data)
    local name, s = societyOf(data)
    if not name then return reply(false, 'sv_err_unknown') end
    local level = math.floor(tonumber(data.level) or -1)
    local grade = Soc.GradeOf(name, level)
    if not grade or grade.boss then return reply(false, 'sv_err_bad_rank') end
    if type(data.perms) ~= 'table' then return reply(false, 'sv_err_unknown') end

    local metaName, metaCents
    if s.type == 'gang' and type(data.meta) == 'table' then
        metaName = cleanRankName(data.meta.name)
        if not metaName then return reply(false, 'sv_err_rank_name') end
        local pay = tonumber(data.meta.pay) or 0
        if pay ~= pay or pay < 0 or pay > Config.Gang.MaxRankPay then return reply(false, 'sv_err_amount') end
        metaCents = math.floor(pay * 100 + 0.5)
    end

    local set, list = {}, {}
    for _, p in ipairs(data.perms) do
        if type(p) == 'string' and Soc.IsValidPerm(s.type, p) and not set[p] then
            set[p] = true
            list[#list + 1] = p
        end
    end
    table.sort(list)

    local shown = grade.name
    local rank = metaName and Soc.Ranks[name] and Soc.Ranks[name][level]
    if rank then
        rank.name, rank.payment = metaName, metaCents
        MySQL.update('UPDATE rsg_society_ranks SET name = ?, payment_cents = ? WHERE society = ? AND level = ?', { metaName, metaCents, name, level })
        Soc.SyncGangDef(name)
        audit(ctx, name, 'rank_edit', ('%s $%.2f'):format(metaName, metaCents / 100))
        shown = metaName
    end
    Soc.Perms[name] = Soc.Perms[name] or {}
    Soc.Perms[name][level] = set
    MySQL.insert('INSERT INTO rsg_society_perms (society, level, perms) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE perms = VALUES(perms)', { name, level, json.encode(list) })
    audit(ctx, name, 'perms', ('%s: %s'):format(shown, table.concat(list, ',')))
    return reply(true, 'sv_perms_saved', shown)
end

function Actions.rank_add(ctx, data)
    local name, s = societyOf(data)
    if not name or s.type ~= 'gang' then return reply(false, 'sv_adm_gang_only') end
    local n = cleanRankName(data.rankName)
    if not n then return reply(false, 'sv_err_rank_name') end
    local ok, result = Soc.AddRank(name, n)
    if not ok then return reply(false, result) end
    audit(ctx, name, 'rank_add', n)
    return reply(true, 'sv_rank_added', n)
end

function Actions.rank_delete(ctx, data)
    local name, s = societyOf(data)
    if not name or s.type ~= 'gang' then return reply(false, 'sv_adm_gang_only') end
    local ok, result = Soc.RemoveRank(name, math.floor(tonumber(data.level) or -1))
    if not ok then return reply(false, result) end
    audit(ctx, name, 'rank_delete', result)
    return reply(true, 'sv_rank_deleted', result)
end

function Actions.fine_void(ctx, data)
    local id = math.floor(tonumber(data.id) or 0)
    local society = MySQL.scalar.await("SELECT society FROM rsg_society_fines WHERE id = ? AND status = 'unpaid' LIMIT 1", { id })
    if not society or not Soc.VoidFine(society, id, ctx.cid, ctx.actor) then return reply(false, 'sv_err_unknown') end
    return reply(true, 'sv_fine_voided')
end

function Actions.fines_forgive(ctx, data)
    local cid = type(data.cid) == 'string' and data.cid or nil
    if not cid or #cid > 50 then return reply(false, 'sv_err_player') end
    local count = 0
    for _, r in ipairs(MySQL.query.await("SELECT id, society FROM rsg_society_fines WHERE citizenid = ? AND status = 'unpaid'", { cid }) or {}) do
        if Soc.VoidFine(r.society, r.id, ctx.cid, ctx.actor) then count = count + 1 end
    end
    return { ok = true, msg = locale('sv_adm_forgiven', count) }
end

function Actions.desk_add(ctx, data)
    local name = societyOf(data)
    if not name then return reply(false, 'sv_err_unknown') end
    local ped = GetPlayerPed(ctx.src)
    if not ped or ped == 0 then return reply(false, 'sv_err_unknown') end
    local pos, heading = GetEntityCoords(ped), GetEntityHeading(ped)
    local label = Soc.Trunc(trim((tostring(data.label or ''):gsub('[%c<>]', ''))), 80)
    if label == '' then label = Soc.Label(name) end
    local id = MySQL.insert.await('INSERT INTO rsg_society_locations (society, label, x, y, z, heading, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        name, label, pos.x, pos.y, pos.z, heading, ctx.who,
    })
    if not id then return reply(false, 'sv_err_unknown') end
    Soc.Locations['db_' .. id] = { id = 'db_' .. id, name = label, society = name, coords = vector3(pos.x, pos.y, pos.z), showblip = false, db = id }
    Soc.BroadcastLocations()
    audit(ctx, name, 'admin_desk', ('%.1f %.1f %.1f'):format(pos.x, pos.y, pos.z))
    return reply(true, 'sv_admin_desk_added', name)
end

function Actions.desk_remove(ctx, data)
    local loc = type(data.id) == 'string' and Soc.Locations[data.id]
    if not loc then return reply(false, 'sv_admin_no_desk') end
    if not loc.db then return reply(false, 'sv_adm_cfg_desk') end
    MySQL.update.await('DELETE FROM rsg_society_locations WHERE id = ?', { loc.db })
    Soc.Locations[data.id] = nil
    Soc.BroadcastLocations()
    audit(ctx, loc.society, 'admin_desk_removed')
    return reply(true, 'sv_admin_desk_removed')
end

--- The client only moves the admin when this answer says so (the answer comes from the server, not the NUI).
function Actions.desk_goto(_, data)
    local loc = type(data.id) == 'string' and Soc.Locations[data.id]
    if not loc then return reply(false, 'sv_admin_no_desk') end
    return { ok = true, close = true, teleport = { x = loc.coords.x, y = loc.coords.y, z = loc.coords.z } }
end

function Actions.storage_open(ctx, data)
    local name, s = societyOf(data)
    if not name then return reply(false, 'sv_err_unknown') end
    local cfg = Config.Storage[s.type] or Config.Storage.job
    exports['rsg-inventory']:OpenInventory(ctx.src, 'society_' .. name, {
        label = locale('sv_storage_label', Soc.Label(name)), maxweight = cfg.maxWeight, slots = cfg.slots,
    })
    audit(ctx, name, 'storage')
    return { ok = true, close = true }
end

function Actions.migrate()
    Soc.Migrate(true)
    return reply(true, 'sv_admin_migrated')
end

function Actions.reload()
    Soc.Load()
    Soc.BroadcastLocations()
    return reply(true, 'sv_adm_reloaded')
end

function Actions.prune(ctx, data)
    local days = math.floor(tonumber(data.days) or 0)
    if days < 7 or days > 3650 then return reply(false, 'sv_adm_days') end
    local total = 0
    for _, q in ipairs({
        'DELETE FROM rsg_society_ledger WHERE created_at < (NOW() - INTERVAL ? DAY)',
        'DELETE FROM rsg_society_audit WHERE created_at < (NOW() - INTERVAL ? DAY)',
        "DELETE FROM rsg_society_fines WHERE status <> 'unpaid' AND created_at < (NOW() - INTERVAL ? DAY)",
    }) do
        total = total + (tonumber(MySQL.update.await(q, { days })) or 0)
    end
    print(('^3[rsg-society] %s pruned %d row(s) older than %d days^7'):format(ctx.who, total, days))
    return { ok = true, msg = locale('sv_adm_pruned', total) }
end

-----------------------------------------------------------------------
-- Callbacks
-----------------------------------------------------------------------
registerCallback('rsg-society:server:adminOpen', function(src)
    if Soc.OnReadCooldown(src) then return { ok = false, msg = locale('sv_err_slow') } end
    local ctx, why = guard(src)
    if not ctx then return { ok = false, msg = locale(why) } end
    local res = Tabs.dashboard()
    res.ok = true
    return res
end)

registerCallback('rsg-society:server:adminTab', function(src, tab, arg)
    local fn = type(tab) == 'string' and Tabs[tab]
    if not fn then return { ok = false, msg = locale('sv_err_unknown') } end
    local ctx, why = guard(src)
    if not ctx then return { ok = false, msg = locale(why), closed = why == 'sv_adm_denied' } end
    if Soc.OnReadCooldown(src) then return { ok = false, msg = locale('sv_err_slow') } end
    local res, key = fn(ctx, type(arg) == 'table' and arg or {})
    if not res then return { ok = false, msg = locale(key or 'sv_err_unknown') } end
    res.ok = true
    return res
end)

registerCallback('rsg-society:server:adminAct', function(src, action, data)
    local fn = type(action) == 'string' and Actions[action]
    if not fn then return { ok = false, msg = locale('sv_err_unknown') } end
    local ctx, why = guard(src)
    if not ctx then return { ok = false, msg = locale(why), closed = why == 'sv_adm_denied' } end
    if Soc.OnCooldown(src) then return { ok = false, msg = locale('sv_err_slow') } end
    return fn(ctx, type(data) == 'table' and data or {}) or { ok = false, msg = locale('sv_err_unknown') }
end)

--- RemoveJobSociety(name) -> ok, balance (dollars): for resources that create their own job societies (rsg-stores) and close them again.
--- Removes the account, rank permissions, desks and history of a JOB society and returns what was in the account so the caller can pay it out.
--- Refuses gangs and societies named in Config.Jobs / Config.Locations. The job itself stays in rsg-core (delete it there).
exports('RemoveJobSociety', function(name)
    local s = type(name) == 'string' and Soc.S[name]
    if not s or s.type ~= 'job' or Config.Jobs[name] then return false, 0 end
    for _, loc in ipairs(Config.Locations) do
        if loc.society == name then return false, 0 end
    end
    local balance = s.balance / 100
    Soc.DeleteJobSociety(name)
    print(('^3[rsg-society] %s removed the job society %s (balance $%.2f)^7'):format(GetInvokingResource() or 'unknown', name, balance))
    return true, balance
end)
