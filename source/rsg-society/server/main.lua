local RSGCore = exports['rsg-core']:GetCoreObject()
Soc.Core = RSGCore

local Cooldowns, ReadCooldowns = {}, {}

-----------------------------------------------------------------------
-- Small helpers
-----------------------------------------------------------------------
function Soc.Notify(src, title, description, nType)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = title,
        description = description,
        type = nType or 'inform',
        duration = 5000,
    })
end

--- dollars (number) -> whole cents, or nil for anything that is not a sane positive amount
function Soc.ToCents(amount)
    amount = tonumber(amount)
    if not amount or amount ~= amount or amount == math.huge or amount == -math.huge then return nil end
    local cents = math.floor(amount * 100 + 0.5)
    if cents < 1 or cents > 100000000000 then return nil end
    return cents
end

function Soc.FullName(charinfo)
    if type(charinfo) ~= 'table' then return '?' end
    local name = (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or '?'
end

function Soc.PlayerName(Player)
    return Player and Soc.FullName(Player.PlayerData.charinfo) or '?'
end

function Soc.OnCooldown(src)
    local now = GetGameTimer()
    if Cooldowns[src] and (now - Cooldowns[src]) < Config.ActionCooldown then return true end
    Cooldowns[src] = now
    return false
end

--- lighter limit for reads (opening the menu, loading a tab) so nobody can hammer the database with them
function Soc.OnReadCooldown(src)
    local now = GetGameTimer()
    if ReadCooldowns[src] and (now - ReadCooldowns[src]) < (Config.ReadCooldown or 150) then return true end
    ReadCooldowns[src] = now
    return false
end

AddEventHandler('playerDropped', function()
    Cooldowns[source] = nil
    ReadCooldowns[source] = nil
end)

local function trunc(s, n)
    if s == nil then return nil end
    s = tostring(s)
    if #s > n then s = s:sub(1, n) end
    return s
end
Soc.Trunc = trunc

--- Job definition from rsg-core. Jobs live in the database (multi-job) and are added at runtime, so the copy of
--- RSGCore.Shared.Jobs this resource got at start can be empty or stale: ask rsg-core itself first.
function Soc.JobDef(name)
    if type(name) ~= 'string' or name == '' then return nil end
    local ok, def = pcall(function() return exports['rsg-core']:GetJobDefinition(name) end)
    if ok and type(def) == 'table' then return def end
    return RSGCore.Shared.Jobs[name]
end

function Soc.JobExists(name)
    return type(name) == 'string' and name ~= 'unemployed' and Soc.JobDef(name) ~= nil
end

--- The label to show: the live rsg-core job label for jobs, the stored label for gangs
function Soc.Label(name)
    local s = Soc.S[name]
    if not s then return name end
    if s.type == 'job' then
        local job = Soc.JobDef(name)
        if job and job.label then return job.label end
    end
    return s.label or name
end

-----------------------------------------------------------------------
-- Permissions
-----------------------------------------------------------------------
local sharedPerms, gangPerms = {}, {}
for _, p in ipairs(Config.Permissions) do sharedPerms[p] = true end
for _, p in ipairs(Config.GangPermissions) do gangPerms[p] = true end

--- ordered list of permissions that exist for a society type
function Soc.PermList(sType)
    local list = {}
    for _, p in ipairs(Config.Permissions) do list[#list + 1] = p end
    if sType == 'gang' then
        for _, p in ipairs(Config.GangPermissions) do list[#list + 1] = p end
    end
    return list
end

function Soc.IsValidPerm(sType, perm)
    if sharedPerms[perm] then return true end
    return sType == 'gang' and gangPerms[perm] == true
end

local function toSet(list, sType)
    local set = {}
    for _, p in ipairs(list or {}) do
        if Soc.IsValidPerm(sType, p) then set[p] = true end
    end
    return set
end
Soc.ToSet = toSet

--- grades of a society as an ordered array { level, name, payment (cents), boss }
function Soc.Grades(name)
    local s = Soc.S[name]
    if not s then return {} end
    local out = {}
    if s.type == 'gang' then
        for level, r in pairs(Soc.Ranks[name] or {}) do
            out[#out + 1] = { level = level, name = r.name, payment = r.payment or 0, boss = r.boss == true }
        end
    else
        local job = Soc.JobDef(name)
        for key, g in pairs(job and job.grades or {}) do
            local level = tonumber(key)
            if level then
                out[#out + 1] = {
                    level = level,
                    name = g.name or tostring(level),
                    payment = math.floor((tonumber(g.payment) or 0) * 100 + 0.5),
                    boss = g.isboss == true,
                }
            end
        end
    end
    table.sort(out, function(a, b) return a.level < b.level end)
    return out
end

function Soc.GradeOf(name, level)
    for _, g in ipairs(Soc.Grades(name)) do
        if g.level == level then return g end
    end
end

--- permission set for one grade of a society
function Soc.PermsFor(name, level, boss)
    local s = Soc.S[name]
    if not s then return {} end
    if boss then return toSet(Soc.PermList(s.type), s.type) end
    local override = Soc.Perms[name] and Soc.Perms[name][level]
    if override then return override end
    if s.type == 'job' then
        local cfg = Config.Jobs[name]
        return toSet(cfg and cfg.perms and cfg.perms[level], 'job')
    end
    return {}
end

-----------------------------------------------------------------------
-- Who is what: access of a citizen to a society
-----------------------------------------------------------------------
--- stored grade of a job for a citizen (online first, then the multi-job table), or nil
function Soc.JobLevel(cid, jobName, Player)
    Player = Player or RSGCore.Functions.GetPlayerByCitizenId(cid)
    if Player and Player.PlayerData.job and Player.PlayerData.job.name == jobName then
        return tonumber(Player.PlayerData.job.grade and Player.PlayerData.job.grade.level) or 0
    end
    local row = MySQL.scalar.await('SELECT grade FROM player_jobs WHERE citizenid = ? AND job = ? LIMIT 1', { cid, jobName })
    return row and tonumber(row) or nil
end

--- { level, boss, perms (set), gradeName, type } or nil when the citizen has nothing to do with the society
function Soc.Access(cid, name, Player)
    local s = Soc.S[name]
    if not s or not cid then return nil end
    local level
    if s.type == 'gang' then
        local m = Soc.Members[name] and Soc.Members[name][cid]
        level = m and m.level
    else
        if not Soc.JobExists(name) then return nil end
        level = Soc.JobLevel(cid, name, Player)
    end
    if level == nil then return nil end
    local grade = Soc.GradeOf(name, level)
    if not grade then return nil end
    return {
        level = level,
        boss = grade.boss,
        gradeName = grade.name,
        type = s.type,
        perms = Soc.PermsFor(name, level, grade.boss),
    }
end

--- accepts a server id or a citizenid
local function resolveCid(id)
    if type(id) == 'number' then
        local Player = RSGCore.Functions.GetPlayer(id)
        return Player and Player.PlayerData.citizenid, Player
    end
    if type(id) == 'string' and id ~= '' then
        return id, RSGCore.Functions.GetPlayerByCitizenId(id)
    end
end
Soc.ResolveCid = resolveCid

--- society names this citizen belongs to (gang first, then jobs that have a society)
function Soc.SocietiesOf(cid)
    local list = {}
    local gang = Soc.GangOf[cid]
    if gang and Soc.S[gang] then list[#list + 1] = gang end
    for _, row in ipairs(MySQL.query.await('SELECT job FROM player_jobs WHERE citizenid = ?', { cid }) or {}) do
        if Soc.S[row.job] and Soc.S[row.job].type == 'job' then list[#list + 1] = row.job end
    end
    return list
end

-----------------------------------------------------------------------
-- Desks
-----------------------------------------------------------------------
function Soc.NearDesk(src, name)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    for _, loc in pairs(Soc.Locations) do
        if loc.society == name and #(pos - loc.coords) <= Config.InteractDistance then return true end
    end
    return false
end

function Soc.LocationList()
    local list = {}
    for _, loc in pairs(Soc.Locations) do
        list[#list + 1] = {
            id = loc.id, name = loc.name, society = loc.society,
            x = loc.coords.x, y = loc.coords.y, z = loc.coords.z,
            showblip = loc.showblip == true,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function Soc.BroadcastLocations(target)
    TriggerClientEvent('rsg-society:client:locations', target or -1, Soc.LocationList())
end

-----------------------------------------------------------------------
-- Audit trail
-----------------------------------------------------------------------
function Soc.Audit(name, actorCid, actorName, action, detail, targetCid, targetName)
    if not name or not action then return end
    MySQL.insert('INSERT INTO rsg_society_audit (society, actor_cid, actor_name, action, target_cid, target_name, detail) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        name, trunc(actorCid, 50), trunc(actorName, 100), trunc(action, 40), trunc(targetCid, 50), trunc(targetName, 100), trunc(detail, 255),
    })
    if Config.Logging.enabled then
        TriggerEvent('rsg-log:server:CreateLog', Config.Logging.channel, 'Society: ' .. name, 'blue',
            ('%s | %s | %s | %s'):format(tostring(actorName or actorCid or '-'), action, tostring(targetName or targetCid or '-'), tostring(detail or '')), false)
    end
end

-----------------------------------------------------------------------
-- Accounts
-----------------------------------------------------------------------
local function ledger(name, cid, actor, kind, cents, balance, note)
    MySQL.insert('INSERT INTO rsg_society_ledger (society, citizenid, actor, kind, amount_cents, balance_cents, note) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        name, trunc(cid, 50), trunc(actor, 100), trunc(kind, 20), cents, balance, trunc(note, 200),
    })
end

--- Adds money to a society account. cents must be a positive integer. Returns the new balance (cents) or nil.
function Soc.Credit(name, cents, kind, note, cid, actor)
    local s = Soc.S[name]
    if not s or type(cents) ~= 'number' or cents < 1 then return nil end
    s.balance = s.balance + cents
    MySQL.update('UPDATE rsg_societies SET balance_cents = balance_cents + ? WHERE name = ?', { cents, name })
    ledger(name, cid, actor, kind, cents, s.balance, note)
    TriggerEvent('rsg-society:server:balanceChanged', name, s.balance / 100, cents / 100)
    return s.balance
end

--- Takes money from a society account. Returns false (and changes nothing) when the balance is too small.
function Soc.Debit(name, cents, kind, note, cid, actor)
    local s = Soc.S[name]
    if not s or type(cents) ~= 'number' or cents < 1 then return false end
    if s.balance < cents then return false end
    s.balance = s.balance - cents
    MySQL.update('UPDATE rsg_societies SET balance_cents = balance_cents - ? WHERE name = ?', { cents, name })
    ledger(name, cid, actor, kind, -cents, s.balance, note)
    TriggerEvent('rsg-society:server:balanceChanged', name, s.balance / 100, -cents / 100)
    return true
end

-----------------------------------------------------------------------
-- Registering societies
-----------------------------------------------------------------------
function Soc.RegisterRow(name, sType, label, opts)
    opts = opts or {}
    local payroll = opts.payroll
    if payroll == nil then
        payroll = sType == 'gang' and Config.Payroll.DefaultGangPayroll or Config.Payroll.DefaultJobPayroll
    end
    Soc.S[name] = {
        name = name, type = sType, label = label,
        color = opts.color, tag = opts.tag, owner = opts.owner,
        balance = opts.balance or 0, payroll = payroll == true,
    }
    local insert = opts.await and MySQL.insert.await or MySQL.insert
    insert('INSERT INTO rsg_societies (name, type, label, color, tag, owner, balance_cents, payroll) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE label = VALUES(label)', {
        name, sType, trunc(label, 80), opts.color, opts.tag, opts.owner, opts.balance or 0, payroll and 1 or 0,
    })
    return Soc.S[name]
end

--- Makes sure a job society exists (jobs only, and only for jobs that exist in rsg-core)
function Soc.EnsureJob(name, await)
    if Soc.S[name] then return Soc.S[name] end
    if not Soc.JobExists(name) then return nil end
    local job = Soc.JobDef(name)
    return Soc.RegisterRow(name, 'job', job.label or name, { await = await })
end

-----------------------------------------------------------------------
-- Loading
-----------------------------------------------------------------------
local function decode(text)
    if type(text) ~= 'string' or text == '' then return nil end
    local ok, value = pcall(json.decode, text)
    return ok and value or nil
end

function Soc.Load()
    -- built in locals and swapped in at the end: a reload (for example /societymigrate) must never leave
    -- the live tables empty while the queries below are running
    local S, Ranks, Perms, Members, GangOf, Locations = {}, {}, {}, {}, {}, {}

    for _, r in ipairs(MySQL.query.await('SELECT * FROM rsg_societies') or {}) do
        S[r.name] = {
            name = r.name, type = r.type, label = r.label, color = r.color, tag = r.tag, owner = r.owner,
            balance = tonumber(r.balance_cents) or 0, payroll = (tonumber(r.payroll) or 0) == 1,
        }
        if r.type == 'gang' then Members[r.name] = {} end
    end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM rsg_society_ranks') or {}) do
        Ranks[r.society] = Ranks[r.society] or {}
        Ranks[r.society][tonumber(r.level)] = { name = r.name, payment = tonumber(r.payment_cents) or 0, boss = (tonumber(r.is_boss) or 0) == 1 }
    end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM rsg_society_perms') or {}) do
        local s = S[r.society]
        if s then
            Perms[r.society] = Perms[r.society] or {}
            Perms[r.society][tonumber(r.level)] = toSet(decode(r.perms), s.type)
        end
    end
    for _, r in ipairs(MySQL.query.await('SELECT citizenid, society, level, name FROM rsg_society_members') or {}) do
        if Members[r.society] then
            Members[r.society][r.citizenid] = { level = tonumber(r.level) or 0, name = r.name }
            GangOf[r.citizenid] = r.society
        end
    end

    for _, r in ipairs(MySQL.query.await("SELECT k, v FROM rsg_society_meta WHERE k LIKE 'motd:%'") or {}) do
        local s = S[r.k:sub(6)]
        if s then s.motd = r.v end
    end

    -- desks: config first, then the ones admins added in game
    for _, loc in ipairs(Config.Locations) do
        Locations[loc.id] = { id = loc.id, name = loc.name, society = loc.society, coords = loc.coords, showblip = loc.showblip }
    end
    for _, r in ipairs(MySQL.query.await('SELECT id, society, label, x, y, z FROM rsg_society_locations') or {}) do
        local id = 'db_' .. r.id
        Locations[id] = { id = id, name = r.label or r.society, society = r.society, coords = vector3(r.x + 0.0, r.y + 0.0, r.z + 0.0), showblip = false, db = r.id }
    end

    Soc.S, Soc.Ranks, Soc.Perms, Soc.Members, Soc.GangOf, Soc.Locations = S, Ranks, Perms, Members, GangOf, Locations

    -- job societies named in the config
    for jobName in pairs(Config.Jobs) do
        if not Soc.S[jobName] and Soc.JobExists(jobName) then Soc.EnsureJob(jobName, true) end
    end
end

-----------------------------------------------------------------------
-- Startup
-----------------------------------------------------------------------
local jobsLoaded = false
AddEventHandler('rsg-multijob:server:jobsLoaded', function() jobsLoaded = true end)

local function waitForJobs()
    local waited = 0
    while waited < 15000 do
        if jobsLoaded then return end
        for jobName in pairs(Config.Jobs) do
            if Soc.JobDef(jobName) then return end
        end
        Wait(250)
        waited = waited + 250
    end
end

-- Other files register work that runs once after the data is loaded (lowest priority number first).
local startHooks = {}
function Soc.OnStart(priority, fn)
    startHooks[#startHooks + 1] = { p = priority, fn = fn }
end

MySQL.ready(function()
    CreateThread(function()
        if Config.AutoDatabase and not Soc.EnsureDatabase() then return end
        waitForJobs()
        Soc.Load()
        table.sort(startHooks, function(a, b) return a.p < b.p end)
        for _, hook in ipairs(startHooks) do
            local ok, err = pcall(hook.fn)
            if not ok then print(('^1[rsg-society] startup step failed: %s^7'):format(tostring(err))) end
        end
        Soc.Ready = true
        TriggerEvent('rsg-society:server:ready')
        local count = 0
        for _ in pairs(Soc.S) do count = count + 1 end
        print(('^2[rsg-society] ready: %d societies^7'):format(count))
        if Config.Payroll.Enabled and not (RSGCore.Config and RSGCore.Config.Money and RSGCore.Config.Money.PayCheckSociety) then
            print('^3[rsg-society] RSGConfig.Money.PayCheckSociety is false: job wages are still paid by rsg-core without using society funds. See DOCS.md, "rsg-core change".^7')
        end
    end)
end)

-----------------------------------------------------------------------
-- Exports: accounts (the first six names double as the rsg-bossmenu / rsg-gangmenu API)
-----------------------------------------------------------------------
local function invoker(reason)
    local who = GetInvokingResource() or 'unknown'
    return trunc((reason and reason ~= '') and ('%s [%s]'):format(reason, who) or who, 200), who
end

local function accountFor(name)
    if type(name) ~= 'string' or name == '' then return nil end
    return Soc.S[name] or Soc.EnsureJob(name)
end

--- EnsureJobSociety(jobName) -> boolean: creates the job's society if the job exists in rsg-core (used by resources that register their own jobs, e.g. rsg-ranch)
exports('EnsureJobSociety', function(name)
    return accountFor(name) ~= nil
end)

exports('GetAccount', function(name)
    local s = accountFor(name)
    return s and s.balance / 100 or 0
end)
exports('GetGangAccount', function(name)
    local s = type(name) == 'string' and Soc.S[name]
    return s and s.balance / 100 or 0
end)
exports('GetBalance', function(name)
    local s = accountFor(name)
    return s and s.balance / 100 or 0
end)

local function apiAdd(name, amount, reason, actor)
    local s = accountFor(name)
    local cents = Soc.ToCents(amount)
    if not s or not cents then return false end
    local note, who = invoker(reason)
    return Soc.Credit(name, cents, 'api', note, nil, actor or who) ~= nil
end
local function apiRemove(name, amount, reason, actor)
    local s = accountFor(name)
    local cents = Soc.ToCents(amount)
    if not s or not cents then return false end
    local note, who = invoker(reason)
    return Soc.Debit(name, cents, 'api', note, nil, actor or who)
end
exports('AddMoney', apiAdd)
exports('RemoveMoney', apiRemove)
exports('AddGangMoney', apiAdd)
exports('RemoveGangMoney', apiRemove)

--- IsReady() -> boolean: true once every society is loaded (other resources wait for this at start)
exports('IsReady', function() return Soc.Ready == true end)

exports('GetSociety', function(name)
    local s = Soc.S[name]
    if not s then return nil end
    local members = 0
    if s.type == 'gang' then
        for _ in pairs(Soc.Members[name] or {}) do members = members + 1 end
    end
    return {
        name = s.name, type = s.type, label = Soc.Label(name), color = s.color, tag = s.tag, owner = s.owner,
        balance = s.balance / 100, payroll = s.payroll, members = members,
    }
end)

exports('GetSocieties', function(sType)
    local list = {}
    for name, s in pairs(Soc.S) do
        if not sType or s.type == sType then list[#list + 1] = name end
    end
    table.sort(list)
    return list
end)

exports('GetPlayerSocieties', function(id)
    local cid = resolveCid(id)
    if not cid then return {} end
    local out = {}
    for _, name in ipairs(Soc.SocietiesOf(cid)) do
        local acc = Soc.Access(cid, name)
        if acc then out[#out + 1] = { name = name, type = acc.type, level = acc.level, boss = acc.boss, grade = acc.gradeName } end
    end
    return out
end)

--- HasPermission(serverIdOrCitizenid, society, permission) -> boolean
exports('HasPermission', function(id, name, perm)
    local cid, Player = resolveCid(id)
    if not cid or type(perm) ~= 'string' then return false end
    local acc = Soc.Access(cid, name, Player)
    return acc ~= nil and acc.perms[perm] == true
end)

exports('IsBoss', function(id, name)
    local cid, Player = resolveCid(id)
    if not cid then return false end
    local acc = Soc.Access(cid, name, Player)
    return acc ~= nil and acc.boss == true
end)

function Soc.GetMembers(name)
    local s = Soc.S[name]
    if not s then return {} end
    local list = {}
    local grades = {}
    for _, g in ipairs(Soc.Grades(name)) do grades[g.level] = g end
    if s.type == 'gang' then
        for cid, m in pairs(Soc.Members[name] or {}) do
            local g = grades[m.level]
            list[#list + 1] = { citizenid = cid, name = m.name, level = m.level, grade = g and g.name or '?', boss = g and g.boss or false, online = RSGCore.Functions.GetPlayerByCitizenId(cid) ~= nil }
        end
    else
        for _, r in ipairs(MySQL.query.await('SELECT pj.citizenid, pj.grade, p.charinfo FROM player_jobs pj LEFT JOIN players p ON p.citizenid = pj.citizenid WHERE pj.job = ?', { name }) or {}) do
            local level = tonumber(r.grade) or 0
            local g = grades[level]
            list[#list + 1] = { citizenid = r.citizenid, name = Soc.FullName(decode(r.charinfo)), level = level, grade = g and g.name or '?', boss = g and g.boss or false, online = RSGCore.Functions.GetPlayerByCitizenId(r.citizenid) ~= nil }
        end
    end
    table.sort(list, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return (a.name or '') < (b.name or '')
    end)
    return list
end
exports('GetMembers', Soc.GetMembers)

exports('Audit', function(name, actorCid, action, detail, targetCid)
    if not Soc.S[name] or type(action) ~= 'string' then return false end
    local _, who = invoker()
    Soc.Audit(name, actorCid, who, action, detail, targetCid)
    return true
end)

-- Another resource can add its own permission names later (for example 'plow'). They are stored per rank like the built-in ones.
exports('RegisterPermission', function(perm, gangOnly)
    if type(perm) ~= 'string' or perm == '' or #perm > 24 or not perm:match('^[%w_]+$') then return false end
    if sharedPerms[perm] or gangPerms[perm] then return true end
    if gangOnly then
        gangPerms[perm] = true
        Config.GangPermissions[#Config.GangPermissions + 1] = perm
    else
        sharedPerms[perm] = true
        Config.Permissions[#Config.Permissions + 1] = perm
    end
    return true
end)
