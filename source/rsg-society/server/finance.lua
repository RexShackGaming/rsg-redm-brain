local RSGCore = Soc.Core

local lastBossNotice = {} -- [society] = GetGameTimer() of the last "wages skipped" message

-----------------------------------------------------------------------
-- Paying a player (same rule as rsg-core's paycheck: home bank branch, cash as fallback)
-----------------------------------------------------------------------
local function payPlayer(Player, dollars, note)
    if GetResourceState('rsg-banking') == 'started' then
        local ok, branch = pcall(function()
            return exports['rsg-banking']:AddHomeMoney(Player.PlayerData.citizenid, dollars, note)
        end)
        if ok and branch then return true end
    end
    return Player.Functions.AddMoney('cash', dollars, note) and true or false
end
Soc.PayPlayer = payPlayer

-----------------------------------------------------------------------
-- Payroll
-----------------------------------------------------------------------
--- tells online members with the payroll permission that wages were skipped (at most once a minute per society)
local function noticeBosses(name, skipped)
    if not Config.Payroll.NotifyBosses then return end
    local now = GetGameTimer()
    if lastBossNotice[name] and now - lastBossNotice[name] < 60000 then return end
    lastBossNotice[name] = now
    Soc.Audit(name, nil, nil, 'payroll_skipped', locale('sv_audit_skipped', skipped))
    for _, src in ipairs(RSGCore.Functions.GetPlayers()) do
        local Player = RSGCore.Functions.GetPlayer(tonumber(src))
        if Player then
            local acc = Soc.Access(Player.PlayerData.citizenid, name, Player)
            if acc and acc.perms.payroll then
                Soc.Notify(tonumber(src), Soc.Label(name), locale('sv_payroll_empty_boss'), 'error')
            end
        end
    end
end

--- Called by rsg-core's paycheck loop for every wage. Answers 'paid' (society paid, core hands the money to the player),
--- 'skipped' (society can't afford it, nobody is paid) or 'unmanaged' (not a society job, core pays as it always did).
exports('ProcessWage', function(src, jobName, amount)
    -- this moves society money, so only the paycheck loop of rsg-core may call it
    if GetInvokingResource() ~= Config.Payroll.TrustedWageCaller then return 'unmanaged' end
    if not Soc.Ready or not Config.Payroll.Enabled then return 'unmanaged' end
    local s = Soc.S[jobName]
    if not s or s.type ~= 'job' or not s.payroll then return 'unmanaged' end
    local cents = Soc.ToCents(amount)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not cents or not Player then return 'unmanaged' end

    if Soc.Debit(jobName, cents, 'payroll', locale('sv_ledger_wage'), Player.PlayerData.citizenid, Soc.PlayerName(Player)) then
        return 'paid'
    end
    if Config.Payroll.NotifyEmployee then
        Soc.Notify(src, Soc.Label(jobName), locale('sv_wage_skipped'), 'error')
    end
    noticeBosses(jobName, 1)
    return 'skipped'
end)

--- Core calls this when it could not hand over a wage that ProcessWage already took from the account.
exports('RefundWage', function(jobName, amount)
    if GetInvokingResource() ~= Config.Payroll.TrustedWageCaller then return false end
    local s = Soc.S[jobName]
    local cents = Soc.ToCents(amount)
    if not s or not cents then return false end
    return Soc.Credit(jobName, cents, 'refund', locale('sv_ledger_wage_refund')) ~= nil
end)

--- Pays every online member of a gang society their rank wage out of the account, highest rank first.
--- A wage the account can't cover is skipped. Returns paid, skipped.
function Soc.RunGangPayroll(name)
    local s = Soc.S[name]
    if not s or s.type ~= 'gang' then return 0, 0 end
    local due = {}
    local grades = {}
    for _, g in ipairs(Soc.Grades(name)) do grades[g.level] = g end
    for cid, m in pairs(Soc.Members[name] or {}) do
        local Player = RSGCore.Functions.GetPlayerByCitizenId(cid)
        local g = grades[m.level]
        if Player and g and g.payment > 0 then due[#due + 1] = { Player = Player, level = m.level, cents = g.payment } end
    end
    table.sort(due, function(a, b) return a.level > b.level end)

    local paid, skipped = 0, 0
    for _, d in ipairs(due) do
        local cid = d.Player.PlayerData.citizenid
        if Soc.Debit(name, d.cents, 'payroll', locale('sv_ledger_wage'), cid, Soc.PlayerName(d.Player)) then
            if payPlayer(d.Player, d.cents / 100, 'society-payroll') then
                paid = paid + 1
                Soc.Notify(d.Player.PlayerData.source, Soc.Label(name), locale('sv_wage_received', d.cents / 100), 'inform')
            else
                Soc.Credit(name, d.cents, 'refund', locale('sv_ledger_wage_refund'), cid)
                skipped = skipped + 1
            end
        else
            skipped = skipped + 1
            if Config.Payroll.NotifyEmployee then
                Soc.Notify(d.Player.PlayerData.source, Soc.Label(name), locale('sv_wage_skipped'), 'error')
            end
        end
    end
    if skipped > 0 then noticeBosses(name, skipped) end
    return paid, skipped
end
exports('RunPayroll', function(name)
    if not Soc.S[name] or Soc.S[name].type ~= 'gang' then return 0, 0 end
    return Soc.RunGangPayroll(name)
end)

-----------------------------------------------------------------------
-- Fines
-----------------------------------------------------------------------
local function moneyCents(Player, moneyType)
    return math.floor((tonumber(Player.Functions.GetMoney(moneyType)) or 0) * 100 + 0.5)
end

--- Takes up to `cents` from a player (Config.Fines.PayWith order). Returns how many cents were taken.
local function takeFromPlayer(Player, cents)
    local types = Config.Fines.PayWith
    if not Config.Fines.AllowPartial then
        local total = 0
        for _, t in ipairs(types) do total = total + moneyCents(Player, t) end
        if total < cents then return 0 end
    end
    local taken, remaining = 0, cents
    for _, t in ipairs(types) do
        if remaining <= 0 then break end
        local take = math.min(moneyCents(Player, t), remaining)
        if take > 0 and Player.Functions.RemoveMoney(t, take / 100, 'society-fine') then
            taken = taken + take
            remaining = remaining - take
        end
    end
    return taken
end

local collecting = {} -- [citizenid] = true while a collection runs

--- Collects every unpaid fine of an online player. Returns cents collected.
local function collectFines(Player)
    local cid = Player.PlayerData.citizenid
    local rows = MySQL.query.await("SELECT id, society, amount_cents, paid_cents FROM rsg_society_fines WHERE citizenid = ? AND status = 'unpaid' ORDER BY id", { cid }) or {}
    local collected = 0
    for _, f in ipairs(rows) do
        if not Soc.S[f.society] then
            MySQL.update("UPDATE rsg_society_fines SET status = 'void' WHERE id = ?", { f.id })
        else
            local owed = (tonumber(f.amount_cents) or 0) - (tonumber(f.paid_cents) or 0)
            local taken = owed > 0 and takeFromPlayer(Player, owed) or 0
            if taken > 0 then
                collected = collected + taken
                Soc.Credit(f.society, taken, 'fine', locale('sv_ledger_fine', f.id), cid, Soc.PlayerName(Player))
                local paid = (tonumber(f.paid_cents) or 0) + taken
                if paid >= tonumber(f.amount_cents) then
                    MySQL.update("UPDATE rsg_society_fines SET paid_cents = ?, status = 'paid', paid_at = NOW() WHERE id = ?", { paid, f.id })
                    Soc.Audit(f.society, cid, Soc.PlayerName(Player), 'fine_paid', ('#%d $%.2f'):format(f.id, paid / 100))
                else
                    MySQL.update('UPDATE rsg_society_fines SET paid_cents = ? WHERE id = ?', { paid, f.id })
                end
            end
        end
    end
    return collected
end

--- Only one collection per player at a time: the queries yield, so two overlapping runs (login, payroll tick,
--- /payfines, a fresh fine) used to read the same unpaid fine and charge the player twice.
function Soc.CollectFines(Player)
    local cid = Player.PlayerData.citizenid
    if collecting[cid] then return 0 end
    collecting[cid] = true
    local ok, result = pcall(collectFines, Player)
    collecting[cid] = nil
    if not ok then
        print(('^1[rsg-society] collecting fines for %s failed: %s^7'):format(cid, tostring(result)))
        return 0
    end
    return result
end

function Soc.IsCollecting(cid) return collecting[cid] == true end

--- Total still owed by a citizen (cents) and the number of open fines
function Soc.Owed(cid)
    local row = MySQL.single.await("SELECT COUNT(*) AS n, COALESCE(SUM(amount_cents - paid_cents), 0) AS owed FROM rsg_society_fines WHERE citizenid = ? AND status = 'unpaid'", { cid })
    return row and tonumber(row.owed) or 0, row and tonumber(row.n) or 0
end

-- A fine takes cash and bank at once, so one rogue member with the 'fines' permission could empty a player in seconds:
-- cap how many fines one person can issue inside a window.
local issueLog = {} -- [issuer citizenid] = { os.time(), ... }
local function issueLimited(cid)
    local limit = Config.Fines.IssueLimit or 0
    if limit <= 0 or not cid then return false end
    local now, window = os.time(), (Config.Fines.IssueWindowMinutes or 10) * 60
    local keep = {}
    for _, at in ipairs(issueLog[cid] or {}) do
        if now - at < window then keep[#keep + 1] = at end
    end
    issueLog[cid] = keep
    if #keep >= limit then return true end
    keep[#keep + 1] = now
    return false
end

--- Issues a fine and collects it at once when the player is online.
--- issuer: { cid, name } or nil for a script. Returns ok, fineId | reasonKey, collectedCents.
function Soc.IssueFine(issuer, targetCid, name, amount, reason)
    if not Config.Fines.Enabled then return false, 'sv_err_fines_off' end
    local s = Soc.S[name]
    if not s then return false, 'sv_err_unknown' end
    local cents = Soc.ToCents(amount)
    if not cents or cents < Config.Fines.Min * 100 or cents > Config.Fines.Max * 100 then return false, 'sv_err_fine_amount' end
    if issuer and issuer.cid and issueLimited(issuer.cid) then return false, 'sv_err_fine_limit' end
    reason = type(reason) == 'string' and reason:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '') or ''
    if #reason > 200 then reason = reason:sub(1, 200) end

    local Target = RSGCore.Functions.GetPlayerByCitizenId(targetCid)
    local targetName
    if Target then
        targetName = Soc.PlayerName(Target)
    else
        local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { targetCid })
        if not row then return false, 'sv_err_player' end
        local ok, info = pcall(json.decode, row.charinfo)
        targetName = Soc.FullName(ok and info or nil)
    end

    local id = MySQL.insert.await('INSERT INTO rsg_society_fines (society, citizenid, target_name, issuer_cid, issuer_name, amount_cents, reason) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        name, targetCid, Soc.Trunc(targetName, 100), issuer and issuer.cid or nil, Soc.Trunc(issuer and issuer.name or 'system', 100), cents, reason,
    })
    if not id then return false, 'sv_err_unknown' end

    Soc.Audit(name, issuer and issuer.cid, issuer and issuer.name, 'fine_issue', ('#%d $%.2f %s'):format(id, cents / 100, reason), targetCid, targetName)
    local collected = 0
    if Target then
        Soc.Notify(Target.PlayerData.source, Soc.Label(name), locale('sv_fine_received', cents / 100, Soc.Label(name)), 'error')
        collected = Soc.CollectFines(Target)
        if collected < cents then
            Soc.Notify(Target.PlayerData.source, Soc.Label(name), locale('sv_fine_unpaid_left'), 'inform')
        end
    end
    TriggerEvent('rsg-society:server:fineIssued', name, targetCid, cents / 100, id)
    return true, id, collected
end

--- IssueFine(sourceOrNil, targetServerIdOrCitizenid, society, amount, reason) -> ok, fineId | reasonKey
exports('IssueFine', function(src, targetId, name, amount, reason)
    local issuer
    if src then
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return false, 'sv_err_player' end
        local acc = Soc.Access(Player.PlayerData.citizenid, name, Player)
        if not acc or not acc.perms.fines then return false, 'sv_err_no_permission' end
        issuer = { cid = Player.PlayerData.citizenid, name = Soc.PlayerName(Player) }
    else
        issuer = { cid = nil, name = GetInvokingResource() or 'system' }
    end
    local cid = Soc.ResolveCid(targetId)
    if not cid then return false, 'sv_err_player' end
    local ok, a = Soc.IssueFine(issuer, cid, name, amount, reason)
    return ok, a
end)

function Soc.VoidFine(name, fineId, actorCid, actorName)
    fineId = math.floor(tonumber(fineId) or 0)
    local row = MySQL.single.await("SELECT id, citizenid, target_name, amount_cents FROM rsg_society_fines WHERE id = ? AND society = ? AND status = 'unpaid' LIMIT 1", { fineId, name })
    if not row then return false end
    MySQL.update("UPDATE rsg_society_fines SET status = 'void' WHERE id = ?", { fineId })
    Soc.Audit(name, actorCid, actorName, 'fine_void', ('#%d $%.2f'):format(fineId, row.amount_cents / 100), row.citizenid, row.target_name)
    return true
end

--- one page of a society's fines, newest first
function Soc.FineRows(name, before)
    before = math.floor(tonumber(before) or 0)
    local rows = MySQL.query.await(
        "SELECT id, citizenid, target_name, issuer_name, amount_cents, paid_cents, reason, status, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i') AS created FROM rsg_society_fines WHERE society = ? AND (? = 0 OR id < ?) ORDER BY id DESC LIMIT ?",
        { name, before, before, Config.PageSize + 1 }) or {}
    local more = #rows > Config.PageSize
    if more then rows[#rows] = nil end
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = {
            id = r.id, cid = r.citizenid, target = r.target_name, issuer = r.issuer_name, reason = r.reason or '',
            amount = r.amount_cents / 100, paid = r.paid_cents / 100, status = r.status, date = r.created,
        }
    end
    return out, more
end

-- Collect when a character loads
AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    if not Config.Fines.Enabled or not Config.Fines.CollectOnLogin or not Player then return end
    SetTimeout(5000, function()
        local live = RSGCore.Functions.GetPlayerByCitizenId(Player.PlayerData.citizenid)
        if not live then return end
        local owed = Soc.Owed(live.PlayerData.citizenid)
        if owed <= 0 then return end
        local collected = Soc.CollectFines(live)
        if collected > 0 then
            Soc.Notify(live.PlayerData.source, locale('sv_fines_title'), locale('sv_fines_collected', collected / 100), 'inform')
        end
    end)
end)

-- Player commands
RSGCore.Commands.Add('fines', locale('cmd_fines_desc'), {}, false, function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    local owed, count = Soc.Owed(Player.PlayerData.citizenid)
    if count == 0 then
        return Soc.Notify(source, locale('sv_fines_title'), locale('sv_fines_none'), 'success')
    end
    Soc.Notify(source, locale('sv_fines_title'), locale('sv_fines_owed', owed / 100, count), 'inform')
end)

RSGCore.Commands.Add('payfines', locale('cmd_payfines_desc'), {}, false, function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    if Soc.IsCollecting(Player.PlayerData.citizenid) then return Soc.Notify(source, locale('sv_fines_title'), locale('sv_err_slow'), 'error') end
    local owed = Soc.Owed(Player.PlayerData.citizenid)
    if owed <= 0 then return Soc.Notify(source, locale('sv_fines_title'), locale('sv_fines_none'), 'success') end
    local collected = Soc.CollectFines(Player)
    if collected <= 0 then return Soc.Notify(source, locale('sv_fines_title'), locale('sv_err_cant_afford'), 'error') end
    Soc.Notify(source, locale('sv_fines_title'), locale('sv_fines_collected', collected / 100), 'success')
end)

-----------------------------------------------------------------------
-- Timers and housekeeping
-----------------------------------------------------------------------
local function gangPayrollTick()
    SetTimeout(math.max(1, Config.Payroll.GangInterval) * 60 * 1000, gangPayrollTick)
    if not Soc.Ready then return end
    if Config.Payroll.Enabled then
        for name, s in pairs(Soc.S) do
            if s.type == 'gang' and s.payroll then Soc.RunGangPayroll(name) end
        end
    end
    if Config.Fines.Enabled and Config.Fines.CollectOnPayroll then
        for _, row in ipairs(MySQL.query.await("SELECT DISTINCT citizenid FROM rsg_society_fines WHERE status = 'unpaid'") or {}) do
            local Player = RSGCore.Functions.GetPlayerByCitizenId(row.citizenid)
            if Player then
                local collected = Soc.CollectFines(Player)
                if collected > 0 then
                    Soc.Notify(Player.PlayerData.source, locale('sv_fines_title'), locale('sv_fines_collected', collected / 100), 'inform')
                end
            end
        end
    end
end

Soc.OnStart(40, function()
    if (Config.PruneDays or 0) > 0 then
        MySQL.update('DELETE FROM rsg_society_ledger WHERE created_at < (NOW() - INTERVAL ? DAY)', { Config.PruneDays })
        MySQL.update('DELETE FROM rsg_society_audit WHERE created_at < (NOW() - INTERVAL ? DAY)', { Config.PruneDays })
        MySQL.update("DELETE FROM rsg_society_fines WHERE status <> 'unpaid' AND created_at < (NOW() - INTERVAL ? DAY)", { Config.PruneDays })
    end
    SetTimeout(math.max(1, Config.Payroll.GangInterval) * 60 * 1000, gangPayrollTick)
end)
