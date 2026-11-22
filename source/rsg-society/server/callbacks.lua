local RSGCore = Soc.Core

-- A handler that errors must still answer, otherwise the menu waits for the full timeout.
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

-- menu actions that need a job member to be on duty (Config.OnDuty)
local dutyActions = {}
for _, a in ipairs(Config.OnDuty.Actions or {}) do dutyActions[a] = true end

-- ledger kinds the finance tab can filter by
local LedgerKinds = {}
for _, k in ipairs({ 'deposit', 'withdraw', 'payroll', 'fine', 'refund', 'api', 'admin', 'migration', 'bonus', 'transfer' }) do LedgerKinds[k] = true end

-----------------------------------------------------------------------
-- Guard: who is asking, and may they?
-----------------------------------------------------------------------
local function guard(src, name, needPerm)
    if not Soc.Ready then return nil, 'sv_err_not_ready' end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil, 'sv_err_player' end
    if type(name) ~= 'string' then return nil, 'sv_err_unknown' end
    local s = Soc.S[name]
    if not s then return nil, 'sv_err_unknown' end
    local cid = Player.PlayerData.citizenid
    local acc = Soc.Access(cid, name, Player)
    if not acc then return nil, 'sv_err_no_access' end
    if (s.type == 'job' or Config.Gang.RequireDesk) and not Soc.NearDesk(src, name) then return nil, 'sv_err_far' end
    if needPerm and not acc.perms[needPerm] then return nil, 'sv_err_no_permission' end
    return { src = src, Player = Player, cid = cid, name = name, s = s, acc = acc, who = Soc.PlayerName(Player) }
end

local function permArray(acc, sType)
    local list = {}
    for _, p in ipairs(Soc.PermList(sType)) do
        if acc.perms[p] then list[#list + 1] = p end
    end
    return list
end

--- everything the menu header and the tab bar need
local function buildView(ctx)
    local s = ctx.s
    local acc = Soc.Access(ctx.cid, ctx.name, ctx.Player) or ctx.acc
    return {
        name = ctx.name, type = s.type, label = Soc.Label(ctx.name), color = s.color, tag = s.tag,
        balance = (acc.perms.finance or acc.perms.deposit or acc.perms.withdraw or acc.perms.payroll) and s.balance / 100 or nil,
        payroll = s.payroll,
        members = s.type == 'gang' and Soc.GangMemberCount(ctx.name) or nil,
        maxMembers = s.type == 'gang' and Config.Gang.MaxMembers or nil,
        me = { cid = ctx.cid, grade = acc.gradeName, level = acc.level, boss = acc.boss },
        perms = permArray(acc, s.type),
        remoteStorage = s.type == 'job' or Config.Gang.RemoteStorage,
        maxTransaction = Config.MaxTransaction,
        motd = s.motd,
    }
end

-----------------------------------------------------------------------
-- Open
-----------------------------------------------------------------------
registerCallback('rsg-society:server:open', function(src, ref)
    if not Soc.Ready then return { ok = false, msg = locale('sv_err_not_ready') } end
    if Soc.OnReadCooldown(src) then return { ok = false, msg = locale('sv_err_slow') } end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(ref) ~= 'table' then return { ok = false, msg = locale('sv_err_player') } end
    local cid = Player.PlayerData.citizenid

    local name
    if ref.gang then
        name = Soc.GangOf[cid]
        if not name then
            if not Config.Gang.Enabled then return { ok = false, msg = locale('sv_err_no_gang') } end
            return {
                ok = true,
                create = { cost = Config.Gang.CreateCost, min = Config.Gang.MinNameLength, max = Config.Gang.MaxNameLength },
            }
        end
    else
        name = ref.society
    end

    local ctx, why = guard(src, name)
    if not ctx then return { ok = false, msg = locale(why) } end
    local view = buildView(ctx)
    if #view.perms == 0 and not (ctx.s.type == 'gang') then return { ok = false, msg = locale('sv_err_no_access') } end
    return { ok = true, view = view }
end)

-----------------------------------------------------------------------
-- Tabs
-----------------------------------------------------------------------
local function nearbyPlayers(ctx, excludeMembers)
    local myPed = GetPlayerPed(ctx.src)
    local list = {}
    if not myPed or myPed == 0 then return list end
    local mine = GetEntityCoords(myPed)
    for _, id in ipairs(RSGCore.Functions.GetPlayers()) do
        id = tonumber(id)
        if id and id ~= ctx.src then
            local ped = GetPlayerPed(id)
            local Target = RSGCore.Functions.GetPlayer(id)
            if Target and ped and ped ~= 0 and #(GetEntityCoords(ped) - mine) <= Config.HireDistance then
                local tcid = Target.PlayerData.citizenid
                local member = ctx.s.type == 'gang' and Soc.GangOf[tcid] == ctx.name or (ctx.s.type == 'job' and Soc.JobLevel(tcid, ctx.name, Target) ~= nil)
                if not (excludeMembers and member) then
                    list[#list + 1] = { id = id, name = Soc.PlayerName(Target) }
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local Tabs = {}

function Tabs.members(ctx)
    if not ctx.acc.perms.members then return nil, 'sv_err_no_permission' end
    local assign = {}
    for _, g in ipairs(Soc.Grades(ctx.name)) do
        if g.level <= Soc.MaxAssignable(ctx.acc) then assign[#assign + 1] = { level = g.level, name = g.name } end
    end
    return {
        members = Soc.MemberRows(ctx.name, ctx.acc, ctx.cid),
        assignable = assign,
        canHire = ctx.acc.perms.hire == true,
        canFire = ctx.acc.perms.fire == true,
        canPromote = ctx.acc.perms.promote == true,
        canTransfer = ctx.s.type == 'gang' and ctx.acc.boss == true,
        canBonus = ctx.acc.perms.bonus == true and (Config.Bonus.Max or 0) > 0,
    }
end

function Tabs.nearby(ctx, arg)
    local purpose = type(arg) == 'table' and arg.purpose or nil
    if purpose == 'fine' then
        if not ctx.acc.perms.fines then return nil, 'sv_err_no_permission' end
        return { players = nearbyPlayers(ctx, false) }
    end
    if not ctx.acc.perms.hire then return nil, 'sv_err_no_permission' end
    return { players = nearbyPlayers(ctx, true) }
end

function Tabs.ranks(ctx)
    if not ctx.acc.perms.ranks then return nil, 'sv_err_no_permission' end
    local grades = {}
    for _, g in ipairs(Soc.Grades(ctx.name)) do
        local set = Soc.PermsFor(ctx.name, g.level, g.boss)
        local list = {}
        for _, p in ipairs(Soc.PermList(ctx.s.type)) do
            if set[p] then list[#list + 1] = p end
        end
        local editable = not g.boss and (g.level < ctx.acc.level or (Config.AllowEqualRank and ctx.acc.boss and g.level <= ctx.acc.level))
        grades[#grades + 1] = { level = g.level, name = g.name, pay = g.payment / 100, boss = g.boss, perms = list, editable = editable and true or false, deletable = ctx.s.type == 'gang' and editable and true or false }
    end
    local grantable = {}
    for _, p in ipairs(Soc.PermList(ctx.s.type)) do
        if ctx.acc.boss or ctx.acc.perms[p] then grantable[#grantable + 1] = p end
    end
    return {
        grades = grades, allPerms = Soc.PermList(ctx.s.type), grantable = grantable, gang = ctx.s.type == 'gang',
        canEditRanks = ctx.s.type == 'gang', count = #grades, maxRanks = Config.Gang.MaxRanks or 10,
    }
end

function Tabs.finance(ctx, arg)
    if not ctx.acc.perms.finance then return nil, 'sv_err_no_permission' end
    local before = math.floor(tonumber(type(arg) == 'table' and arg.before or 0) or 0)
    local kind = type(arg) == 'table' and type(arg.kind) == 'string' and LedgerKinds[arg.kind] and arg.kind or ''
    local rows = MySQL.query.await(
        "SELECT id, kind, amount_cents, balance_cents, actor, note, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i') AS created FROM rsg_society_ledger WHERE society = ? AND (? = 0 OR id < ?) AND (? = '' OR kind = ?) ORDER BY id DESC LIMIT ?",
        { ctx.name, before, before, kind, kind, Config.PageSize + 1 }) or {}
    local more = #rows > Config.PageSize
    if more then rows[#rows] = nil end
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { id = r.id, kind = r.kind, amount = r.amount_cents / 100, balance = r.balance_cents / 100, actor = r.actor or '', note = r.note or '', date = r.created }
    end
    local wages = {}
    for _, g in ipairs(Soc.Grades(ctx.name)) do wages[#wages + 1] = { name = g.name, pay = g.payment / 100 } end
    local targets = {}
    if Config.Transfers.Enabled and ctx.acc.perms.withdraw then
        for other, o in pairs(Soc.S) do
            if other ~= ctx.name and (not Config.Transfers.SameTypeOnly or o.type == ctx.s.type) then
                targets[#targets + 1] = { name = other, label = Soc.Label(other) }
            end
        end
        table.sort(targets, function(a, b) return a.label < b.label end)
    end
    return {
        balance = ctx.s.balance / 100, ledger = out, more = more, payroll = ctx.s.payroll,
        canDeposit = ctx.acc.perms.deposit == true, canWithdraw = ctx.acc.perms.withdraw == true, canPayroll = ctx.acc.perms.payroll == true,
        wages = wages, max = Config.MaxTransaction, payrollEnabled = Config.Payroll.Enabled,
        transferTargets = targets, transferMax = Config.Transfers.Max,
    }
end

function Tabs.fines(ctx, arg)
    if not (ctx.acc.perms.fines or ctx.acc.perms.finevoid) then return nil, 'sv_err_no_permission' end
    local rows, more = Soc.FineRows(ctx.name, type(arg) == 'table' and arg.before or 0)
    return { fines = rows, more = more, canIssue = ctx.acc.perms.fines == true, canVoid = ctx.acc.perms.finevoid == true, min = Config.Fines.Min, max = Config.Fines.Max, enabled = Config.Fines.Enabled }
end

function Tabs.audit(ctx, arg)
    if not ctx.acc.perms.audit then return nil, 'sv_err_no_permission' end
    local before = math.floor(tonumber(type(arg) == 'table' and arg.before or 0) or 0)
    local rows = MySQL.query.await(
        "SELECT id, actor_name, action, target_name, detail, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i') AS created FROM rsg_society_audit WHERE society = ? AND (? = 0 OR id < ?) ORDER BY id DESC LIMIT ?",
        { ctx.name, before, before, Config.PageSize + 1 }) or {}
    local more = #rows > Config.PageSize
    if more then rows[#rows] = nil end
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { id = r.id, actor = r.actor_name or '', action = r.action, target = r.target_name or '', detail = r.detail or '', date = r.created }
    end
    return { rows = out, more = more }
end

--- who put what into the shared storage and took what out (rsg-inventory keeps this log)
function Tabs.stash(ctx)
    if not ctx.acc.perms.audit then return nil, 'sv_err_no_permission' end
    local ok, rows = pcall(function() return exports['rsg-inventory']:GetStashHistory('society_' .. ctx.name, 100) end)
    local out = {}
    for _, r in ipairs(ok and type(rows) == 'table' and rows or {}) do
        local item = RSGCore.Shared.Items[r.item]
        out[#out + 1] = { name = r.name or '', action = r.action, item = item and item.label or r.item, amount = r.amount, time = tonumber(r.time) or 0 }
    end
    return { rows = out }
end

function Tabs.settings(ctx)
    local acc, s = ctx.acc, ctx.s
    if s.type ~= 'gang' then return { gang = false } end
    return {
        gang = true, label = Soc.Label(ctx.name), color = s.color, tag = s.tag or '', colors = Config.Gang.Colors,
        canEdit = acc.perms.settings == true, canDisband = acc.perms.disband == true, maxTag = Config.Gang.MaxTagLength,
        minName = Config.Gang.MinNameLength, maxName = Config.Gang.MaxNameLength, boss = acc.boss,
    }
end

registerCallback('rsg-society:server:tab', function(src, name, tab, arg)
    if Soc.OnReadCooldown(src) then return { ok = false, msg = locale('sv_err_slow') } end
    local ctx, why = guard(src, name)
    if not ctx then return { ok = false, msg = locale(why) } end
    local fn = Tabs[tab]
    if not fn then return { ok = false, msg = locale('sv_err_unknown') } end
    local data, reason = fn(ctx, arg)
    if not data then return { ok = false, msg = locale(reason or 'sv_err_unknown') } end
    data.ok = true
    return data
end)

-----------------------------------------------------------------------
-- Actions
-----------------------------------------------------------------------
local Actions = {}

local function targetNear(ctx, targetSrc)
    targetSrc = math.floor(tonumber(targetSrc) or -1)
    if targetSrc == ctx.src then return nil end
    local Target = RSGCore.Functions.GetPlayer(targetSrc)
    local a, b = GetPlayerPed(ctx.src), GetPlayerPed(targetSrc)
    if not Target or not a or a == 0 or not b or b == 0 then return nil end
    if #(GetEntityCoords(a) - GetEntityCoords(b)) > Config.HireDistance then return nil, 'sv_err_too_far' end
    return Target
end

local function memberOf(ctx, cid)
    if type(cid) ~= 'string' or cid == '' then return nil end
    if ctx.s.type == 'gang' then
        local m = Soc.Members[ctx.name][cid]
        return m and { level = m.level, name = m.name } or nil
    end
    local level = Soc.JobLevel(cid, ctx.name)
    if level == nil then return nil end
    local row = MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { cid })
    local ok, info = pcall(json.decode, row or '')
    return { level = level, name = Soc.FullName(ok and info or nil) }
end

function Actions.invite(ctx, data)
    if not ctx.acc.perms.hire then return reply(false, 'sv_err_no_permission') end
    local Target, why = targetNear(ctx, data.target)
    if not Target then return reply(false, why or 'sv_err_player') end
    local tcid = Target.PlayerData.citizenid

    local level = math.floor(tonumber(data.level) or 0)
    if level > Soc.MaxAssignable(ctx.acc) or not Soc.GradeOf(ctx.name, level) then return reply(false, 'sv_err_bad_rank') end

    local member = ctx.s.type == 'gang' and Soc.GangOf[tcid] ~= nil or (ctx.s.type == 'job' and Soc.JobLevel(tcid, ctx.name, Target) ~= nil)
    if member then return reply(false, 'sv_err_already_member') end
    if ctx.s.type == 'gang' and Config.Gang.MaxMembers > 0 and Soc.GangMemberCount(ctx.name) >= Config.Gang.MaxMembers then
        return reply(false, 'sv_err_gang_full')
    end

    if ctx.s.type == 'job' and not Config.JobHireNeedsConsent then
        local ok, key = Soc.AddJobMember(ctx.name, tcid, level)
        if not ok then return reply(false, key) end
        local tname = Soc.PlayerName(Target)
        Soc.Audit(ctx.name, ctx.cid, ctx.who, 'hire', Soc.GradeOf(ctx.name, level).name, tcid, tname)
        Soc.Notify(Target.PlayerData.source, Soc.Label(ctx.name), locale('sv_you_joined', Soc.Label(ctx.name)), 'success')
        return reply(true, 'sv_hired', tname)
    end

    local ok, key = Soc.SendInvite(ctx.src, Target.PlayerData.source, ctx.name, level)
    if not ok then return reply(false, key) end
    return reply(true, 'sv_invite_sent', Soc.PlayerName(Target))
end

function Actions.fire(ctx, data)
    if not ctx.acc.perms.fire then return reply(false, 'sv_err_no_permission') end
    local cid = data.cid
    if cid == ctx.cid then return reply(false, 'sv_err_self') end
    local m = memberOf(ctx, cid)
    if not m then return reply(false, 'sv_err_not_member') end
    if not Soc.CanManage(ctx.acc, m.level) then return reply(false, 'sv_err_outranked') end

    local ok
    if ctx.s.type == 'gang' then ok = Soc.RemoveGangMember(ctx.name, cid) else ok = Soc.RemoveJobMember(ctx.name, cid) end
    if not ok then return reply(false, 'sv_err_unknown') end
    Soc.Audit(ctx.name, ctx.cid, ctx.who, 'fire', nil, cid, m.name)
    local Target = RSGCore.Functions.GetPlayerByCitizenId(cid)
    if Target then Soc.Notify(Target.PlayerData.source, Soc.Label(ctx.name), locale('sv_you_fired', Soc.Label(ctx.name)), 'error') end
    return reply(true, 'sv_fired', m.name)
end

function Actions.setrank(ctx, data)
    if not ctx.acc.perms.promote then return reply(false, 'sv_err_no_permission') end
    local cid = data.cid
    if cid == ctx.cid then return reply(false, 'sv_err_self') end
    local m = memberOf(ctx, cid)
    if not m then return reply(false, 'sv_err_not_member') end
    if not Soc.CanManage(ctx.acc, m.level) then return reply(false, 'sv_err_outranked') end

    local level = math.floor(tonumber(data.level) or -1)
    local grade = Soc.GradeOf(ctx.name, level)
    if not grade or level > Soc.MaxAssignable(ctx.acc) then return reply(false, 'sv_err_bad_rank') end
    if level == m.level then return reply(false, 'sv_err_same_rank') end

    local ok
    if ctx.s.type == 'gang' then ok = Soc.SetGangLevel(ctx.name, cid, level) else ok = Soc.SetJobLevel(ctx.name, cid, level) end
    if not ok then return reply(false, 'sv_err_unknown') end
    Soc.Audit(ctx.name, ctx.cid, ctx.who, level > m.level and 'promote' or 'demote', grade.name, cid, m.name)
    local Target = RSGCore.Functions.GetPlayerByCitizenId(cid)
    if Target then Soc.Notify(Target.PlayerData.source, Soc.Label(ctx.name), locale('sv_rank_now', grade.name), 'inform') end
    return reply(true, 'sv_rank_set', m.name, grade.name)
end

function Actions.transfer(ctx, data)
    if ctx.s.type ~= 'gang' or not ctx.acc.boss then return reply(false, 'sv_err_no_permission') end
    local cid = data.cid
    if cid == ctx.cid then return reply(false, 'sv_err_self') end
    local m = memberOf(ctx, cid)
    if not m then return reply(false, 'sv_err_not_member') end
    local below = Soc.GradeOf(ctx.name, ctx.acc.level - 1)
    if not below then return reply(false, 'sv_err_bad_rank') end
    Soc.SetGangLevel(ctx.name, cid, ctx.acc.level)
    Soc.SetGangLevel(ctx.name, ctx.cid, below.level)
    ctx.s.owner = cid
    MySQL.update('UPDATE rsg_societies SET owner = ? WHERE name = ?', { cid, ctx.name })
    Soc.Audit(ctx.name, ctx.cid, ctx.who, 'transfer', nil, cid, m.name)
    local Target = RSGCore.Functions.GetPlayerByCitizenId(cid)
    if Target then Soc.Notify(Target.PlayerData.source, Soc.Label(ctx.name), locale('sv_now_leader'), 'success') end
    return reply(true, 'sv_transferred', m.name)
end

local function sanitizeAmount(amount)
    local cents = Soc.ToCents(amount)
    if not cents or cents > Config.MaxTransaction * 100 then return nil end
    return cents
end

function Actions.deposit(ctx, data)
    if not ctx.acc.perms.deposit then return reply(false, 'sv_err_no_permission') end
    local cents = sanitizeAmount(data.amount)
    if not cents then return reply(false, 'sv_err_amount') end
    if (tonumber(ctx.Player.Functions.GetMoney('cash')) or 0) < cents / 100 then return reply(false, 'sv_err_cant_afford') end
    if not ctx.Player.Functions.RemoveMoney('cash', cents / 100, 'society-deposit') then return reply(false, 'sv_err_cant_afford') end
    Soc.Credit(ctx.name, cents, 'deposit', nil, ctx.cid, ctx.who)
    Soc.Audit(ctx.name, ctx.cid, ctx.who, 'deposit', ('$%.2f'):format(cents / 100))
    return reply(true, 'sv_deposited', cents / 100)
end

function Actions.withdraw(ctx, data)
    if not ctx.acc.perms.withdraw then return reply(false, 'sv_err_no_permission') end
    local cents = sanitizeAmount(data.amount)
    if not cents then return reply(false, 'sv_err_amount') end
    local limit = Config.Withdraw.DailyLimit or 0
    if limit > 0 and not (Config.Withdraw.BossesExempt and ctx.acc.boss) then
        local used = tonumber(MySQL.scalar.await(
            "SELECT COALESCE(-SUM(amount_cents), 0) FROM rsg_society_ledger WHERE society = ? AND citizenid = ? AND kind = 'withdraw' AND created_at > (NOW() - INTERVAL 1 DAY)",
            { ctx.name, ctx.cid })) or 0
        if used + cents > limit * 100 then
            return reply(false, 'sv_err_withdraw_limit', ('%.2f'):format(math.max(0, limit * 100 - used) / 100))
        end
    end
    if not Soc.Debit(ctx.name, cents, 'withdraw', nil, ctx.cid, ctx.who) then return reply(false, 'sv_err_funds') end
    if not ctx.Player.Functions.AddMoney('cash', cents / 100, 'society-withdraw') then
        Soc.Credit(ctx.name, cents, 'refund', locale('sv_ledger_withdraw_failed'), ctx.cid, ctx.who)
        return reply(false, 'sv_err_unknown')
    end
    Soc.Audit(ctx.name, ctx.cid, ctx.who, 'withdraw', ('$%.2f'):format(cents / 100))
    return reply(true, 'sv_withdrew', cents / 100)
end

function Actions.payroll(ctx, data)
    if not ctx.acc.perms.payroll then return reply(false, 'sv_err_no_permission') end
    local on = data.enabled == true
    ctx.s.payroll = on
    MySQL.update('UPDATE rsg_societies SET payroll = ? WHERE name = ?', { on and 1 or 0, ctx.name })
    Soc.Audit(ctx.name, ctx.cid, ctx.who, on and 'payroll_on' or 'payroll_off')
    return reply(true, on and 'sv_payroll_on' or 'sv_payroll_off')
end

--- Validates the name and wage of a gang rank. Returns name, cents, or nil, reasonKey.
local function cleanRankMeta(meta)
    local name = type(meta.name) == 'string' and meta.name:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '') or ''
    local len = utf8.len(name)
    if not len or len < 2 or len > 24 then return nil, 'sv_err_rank_name' end
    local pay = tonumber(meta.pay) or 0
    if pay ~= pay or pay < 0 or pay > Config.Gang.MaxRankPay then return nil, 'sv_err_amount' end
    return name, math.floor(pay * 100 + 0.5)
end

--- Saves what one rank may do. For gangs the same call can also rename the rank and set its wage (data.meta = { name, pay }),
--- so the Ranks tab saves with a single request (two requests in a row would trip the action cooldown).
function Actions.perms(ctx, data)
    if not ctx.acc.perms.ranks then return reply(false, 'sv_err_no_permission') end
    local level = math.floor(tonumber(data.level) or -1)
    local grade = Soc.GradeOf(ctx.name, level)
    if not grade or grade.boss then return reply(false, 'sv_err_bad_rank') end
    if not (level < ctx.acc.level or (Config.AllowEqualRank and ctx.acc.boss and level <= ctx.acc.level)) then return reply(false, 'sv_err_outranked') end
    if type(data.perms) ~= 'table' then return reply(false, 'sv_err_unknown') end

    local metaName, metaCents
    if data.meta ~= nil then
        if ctx.s.type ~= 'gang' or type(data.meta) ~= 'table' then return reply(false, 'sv_err_unknown') end
        local n, c = cleanRankMeta(data.meta)
        if not n then return reply(false, c) end
        metaName, metaCents = n, c
    end

    local set, list = {}, {}
    for _, p in ipairs(data.perms) do
        if type(p) == 'string' and Soc.IsValidPerm(ctx.s.type, p) and not set[p] then
            if not (ctx.acc.boss or ctx.acc.perms[p]) then return reply(false, 'sv_err_grant_own') end
            set[p] = true
            list[#list + 1] = p
        end
    end
    table.sort(list)

    -- every check passed: write
    local rank = metaName and Soc.Ranks[ctx.name] and Soc.Ranks[ctx.name][level]
    if rank then
        rank.name, rank.payment = metaName, metaCents
        MySQL.update('UPDATE rsg_society_ranks SET name = ?, payment_cents = ? WHERE society = ? AND level = ?', { metaName, metaCents, ctx.name, level })
        Soc.SyncGangDef(ctx.name)
        Soc.Audit(ctx.name, ctx.cid, ctx.who, 'rank_edit', ('%s $%.2f'):format(metaName, metaCents / 100))
        grade = { name = metaName }
    end
    Soc.Perms[ctx.name] = Soc.Perms[ctx.name] or {}
    Soc.Perms[ctx.name][level] = set
    MySQL.insert('INSERT INTO rsg_society_perms (society, level, perms) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE perms = VALUES(perms)', { ctx.name, level, json.encode(list) })
    Soc.Audit(ctx.name, ctx.cid, ctx.who, 'perms', ('%s: %s'):format(grade.name, table.concat(list, ',')))
    return reply(true, 'sv_perms_saved', grade.name)
end

--- One-off payment from the account to an online member.
function Actions.bonus(ctx, data)
    if not ctx.acc.perms.bonus or (Config.Bonus.Max or 0) <= 0 then return reply(false, 'sv_err_no_permission') end
    local cents = Soc.ToCents(data.amount)
    if not cents or cents > Config.Bonus.Max * 100 then return reply(false, 'sv_err_amount') end
    local cid = data.cid
    if type(cid) ~= 'string' or cid == ctx.cid then return reply(false, 'sv_err_self') end
    local m = memberOf(ctx, cid)
    if not m then return reply(false, 'sv_err_not_member') end
    local Target = RSGCore.Functions.GetPlayerByCitizenId(cid)
    if not Target then return reply(false, 'sv_err_offline_member') end

    if not Soc.Debit(ctx.name, cents, 'bonus', m.name, ctx.cid, ctx.who) then return reply(false, 'sv_err_funds') end
    if not Soc.PayPlayer(Target, cents / 100, 'society-bonus') then
        Soc.Credit(ctx.name, cents, 'refund', locale('sv_ledger_wage_refund'), ctx.cid, ctx.who)
        return reply(false, 'sv_err_unknown')
    end
    Soc.Audit(ctx.name, ctx.cid, ctx.who, 'bonus', ('$%.2f'):format(cents / 100), cid, m.name)
    Soc.Notify(Target.PlayerData.source, Soc.Label(ctx.name), locale('sv_bonus_received', ('%.2f'):format(cents / 100)), 'success')
    return reply(true, 'sv_bonus_sent', m.name, ('%.2f'):format(cents / 100))
end

--- Moves money from this account to another society account.
function Actions.transfer_funds(ctx, data)
    if not Config.Transfers.Enabled or not ctx.acc.perms.withdraw then return reply(false, 'sv_err_no_permission') end
    local to = type(data.to) == 'string' and data.to or nil
    local target = to and Soc.S[to]
    if not target or to == ctx.name or (Config.Transfers.SameTypeOnly and target.type ~= ctx.s.type) then return reply(false, 'sv_err_unknown') end
    local cents = Soc.ToCents(data.amount)
    if not cents or cents > (Config.Transfers.Max or 0) * 100 or cents > Config.MaxTransaction * 100 then return reply(false, 'sv_err_amount') end

    if not Soc.Debit(ctx.name, cents, 'transfer', Soc.Label(to), ctx.cid, ctx.who) then return reply(false, 'sv_err_funds') end
    Soc.Credit(to, cents, 'transfer', Soc.Label(ctx.name), ctx.cid, ctx.who)
    Soc.Audit(ctx.name, ctx.cid, ctx.who, 'transfer_funds', ('$%.2f -> %s'):format(cents / 100, to))
    Soc.Audit(to, ctx.cid, ctx.who, 'transfer_funds', ('$%.2f <- %s'):format(cents / 100, ctx.name))
    return reply(true, 'sv_transferred_funds', ('%.2f'):format(cents / 100), Soc.Label(to))
end

--- The announcement members see on the Overview tab. Empty text clears it.
function Actions.motd(ctx, data)
    if not ctx.acc.perms.announce then return reply(false, 'sv_err_no_permission') end
    local text = type(data.text) == 'string' and data.text:gsub('[%c<>]', ' '):gsub('^%s+', ''):gsub('%s+$', '') or ''
    local max = Config.Motd.MaxLength or 200
    local len = utf8.len(text)
    if not len or len > max or #text > 255 then return reply(false, 'sv_err_motd', max) end
    if text ~= '' then
        ctx.s.motd = text
        MySQL.insert('INSERT INTO rsg_society_meta (k, v) VALUES (?, ?) ON DUPLICATE KEY UPDATE v = VALUES(v)', { 'motd:' .. ctx.name, text })
    else
        ctx.s.motd = nil
        MySQL.update('DELETE FROM rsg_society_meta WHERE k = ?', { 'motd:' .. ctx.name })
    end
    Soc.Audit(ctx.name, ctx.cid, ctx.who, 'motd', text)
    return reply(true, 'sv_motd_saved')
end

--- Gang ranks: add one just below the boss rank / delete one (its members move down).
function Actions.rank_add(ctx, data)
    if ctx.s.type ~= 'gang' or not ctx.acc.perms.ranks then return reply(false, 'sv_err_no_permission') end
    local name, why = cleanRankMeta({ name = data.name, pay = 0 })
    if not name then return reply(false, why) end
    local ok, res = Soc.AddRank(ctx.name, name)
    if not ok then return reply(false, res) end
    Soc.Audit(ctx.name, ctx.cid, ctx.who, 'rank_add', name)
    return reply(true, 'sv_rank_added', name)
end

function Actions.rank_delete(ctx, data)
    if ctx.s.type ~= 'gang' or not ctx.acc.perms.ranks then return reply(false, 'sv_err_no_permission') end
    local level = math.floor(tonumber(data.level) or -1)
    local grade = Soc.GradeOf(ctx.name, level)
    if not grade or grade.boss then return reply(false, 'sv_err_bad_rank') end
    if not (level < ctx.acc.level or (Config.AllowEqualRank and ctx.acc.boss and level <= ctx.acc.level)) then return reply(false, 'sv_err_outranked') end
    local ok, res = Soc.RemoveRank(ctx.name, level)
    if not ok then return reply(false, res) end
    Soc.Audit(ctx.name, ctx.cid, ctx.who, 'rank_delete', grade.name)
    return reply(true, 'sv_rank_deleted', grade.name)
end

function Actions.fine(ctx, data)
    if not ctx.acc.perms.fines then return reply(false, 'sv_err_no_permission') end
    local Target, why = targetNear(ctx, data.target)
    if not Target then return reply(false, why or 'sv_err_player') end
    local ok, a, collected = Soc.IssueFine({ cid = ctx.cid, name = ctx.who }, Target.PlayerData.citizenid, ctx.name, data.amount, data.reason)
    if not ok then return reply(false, a) end
    return reply(true, 'sv_fine_issued', Soc.PlayerName(Target), (collected or 0) / 100)
end

function Actions.voidfine(ctx, data)
    if not ctx.acc.perms.finevoid then return reply(false, 'sv_err_no_permission') end
    if not Soc.VoidFine(ctx.name, data.id, ctx.cid, ctx.who) then return reply(false, 'sv_err_unknown') end
    return reply(true, 'sv_fine_voided')
end

local function openStash(src, name, s)
    local cfg = Config.Storage[s.type] or Config.Storage.job
    exports['rsg-inventory']:OpenInventory(src, 'society_' .. name, {
        label = locale('sv_storage_label', Soc.Label(name)),
        maxweight = cfg.maxWeight,
        slots = cfg.slots,
    })
end

function Actions.storage(ctx)
    if not ctx.acc.perms.storage then return reply(false, 'sv_err_no_permission') end
    if ctx.s.type == 'gang' and not Config.Gang.RemoteStorage then return reply(false, 'sv_err_storage_remote') end
    openStash(ctx.src, ctx.name, ctx.s)
    Soc.Audit(ctx.name, ctx.cid, ctx.who, 'storage')
    return { ok = true, close = true }
end

--- For other resources (a gang strongbox, a station locker): opens the society stash if the player may use storage.
exports('OpenStorage', function(src, name)
    local Player = RSGCore.Functions.GetPlayer(src)
    local s = type(name) == 'string' and Soc.S[name]
    if not Player or not s then return false end
    local acc = Soc.Access(Player.PlayerData.citizenid, name, Player)
    if not acc or not acc.perms.storage then return false end
    openStash(src, name, s)
    Soc.Audit(name, Player.PlayerData.citizenid, Soc.PlayerName(Player), 'storage')
    return true
end)

function Actions.settings(ctx, data)
    if ctx.s.type ~= 'gang' or not ctx.acc.perms.settings then return reply(false, 'sv_err_no_permission') end
    local ok, key = Soc.SetInfo(ctx.name, data, ctx.cid, ctx.who)
    if not ok then return reply(false, key) end
    return reply(true, key)
end

function Actions.leave(ctx)
    if ctx.s.type ~= 'gang' then return reply(false, 'sv_err_unknown') end
    if ctx.acc.boss then
        local bosses = 0
        for _, m in pairs(Soc.Members[ctx.name]) do
            local g = Soc.GradeOf(ctx.name, m.level)
            if g and g.boss then bosses = bosses + 1 end
        end
        if bosses <= 1 then return reply(false, 'sv_err_leader_leave') end
    end
    Soc.Audit(ctx.name, ctx.cid, ctx.who, 'leave')
    Soc.RemoveGangMember(ctx.name, ctx.cid)
    return { ok = true, msg = locale('sv_left', Soc.Label(ctx.name)), closed = true }
end

function Actions.disband(ctx, data)
    if ctx.s.type ~= 'gang' or not ctx.acc.perms.disband then return reply(false, 'sv_err_no_permission') end
    if data.confirm ~= true then return reply(false, 'sv_err_unknown') end
    local label = Soc.Label(ctx.name)
    local others = {}
    for cid in pairs(Soc.Members[ctx.name]) do others[#others + 1] = cid end

    local balance = Soc.DisbandGang(ctx.name)
    if balance and balance > 0 and Config.Gang.DisbandPayout == 'leader' then
        if not ctx.Player.Functions.AddMoney('cash', balance / 100, 'society-disband') then
            -- the account is already gone, so say so loudly instead of losing the money silently
            print(('^1[rsg-society] could not pay out $%.2f of disbanded gang %s to %s^7'):format(balance / 100, ctx.name, ctx.cid))
        end
    end
    if Config.Logging.enabled then
        TriggerEvent('rsg-log:server:CreateLog', Config.Logging.channel, 'Society disbanded', 'red', ('%s disbanded %s'):format(ctx.who, label), false)
    end
    for _, cid in ipairs(others) do
        local P = RSGCore.Functions.GetPlayerByCitizenId(cid)
        if P and cid ~= ctx.cid then Soc.Notify(P.PlayerData.source, label, locale('sv_disbanded_notice'), 'error') end
    end
    return { ok = true, msg = locale('sv_disbanded', label), closed = true }
end

registerCallback('rsg-society:server:act', function(src, name, action, data)
    local fn = Actions[action]
    if not fn then return { ok = false, msg = locale('sv_err_unknown') } end
    data = type(data) == 'table' and data or {}
    local ctx, why = guard(src, name)
    if not ctx then return { ok = false, msg = locale(why), closed = why == 'sv_err_no_access' } end
    if Soc.OnCooldown(src) then return { ok = false, msg = locale('sv_err_slow') } end
    if Config.OnDuty.Enabled and ctx.s.type == 'job' and dutyActions[action] then
        local job = ctx.Player.PlayerData.job
        if not (job and job.name == ctx.name and job.onduty) then return { ok = false, msg = locale('sv_err_off_duty') } end
    end

    local res = fn(ctx, data) or { ok = false, msg = locale('sv_err_unknown') }
    if not res.closed and Soc.S[name] then
        local fresh = guard(src, name)
        if fresh then res.view = buildView(fresh) else res.closed = true end
    end
    return res
end)

-----------------------------------------------------------------------
-- Creating a gang (no society exists yet, so it has its own callback)
-----------------------------------------------------------------------
registerCallback('rsg-society:server:createGang', function(src, label)
    if not Soc.Ready then return { ok = false, msg = locale('sv_err_not_ready') } end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return { ok = false, msg = locale('sv_err_player') } end
    if not Config.Gang.Enabled then return { ok = false, msg = locale('sv_err_no_gang') } end
    if Soc.OnCooldown(src) then return { ok = false, msg = locale('sv_err_slow') } end
    local cid = Player.PlayerData.citizenid
    if Soc.GangOf[cid] then return { ok = false, msg = locale('sv_err_in_gang') } end

    local clean = Soc.CleanLabel(label)
    if not clean then return { ok = false, msg = locale('sv_err_gang_name') } end
    if Soc.LabelTaken(clean) then return { ok = false, msg = locale('sv_err_gang_taken') } end

    local cost = Config.Gang.CreateCost
    if cost > 0 then
        if (tonumber(Player.Functions.GetMoney('cash')) or 0) < cost or not Player.Functions.RemoveMoney('cash', cost, 'society-gang-create') then
            return { ok = false, msg = locale('sv_err_cant_afford') }
        end
    end
    local ok, result = Soc.CreateGang(clean, cid, Soc.PlayerName(Player))
    if not ok then
        if cost > 0 then Player.Functions.AddMoney('cash', cost, 'society-gang-create-refund') end
        return { ok = false, msg = locale(result) }
    end
    return { ok = true, msg = locale('sv_gang_created', clean), society = result }
end)
