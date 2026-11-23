-- rsg-economy: things that run on their own - treasury interest, weekly reports, project wages, project state for clients
RSGEcon = RSGEcon or {}
local RSGCore = exports['rsg-core']:GetCoreObject()
local round2 = RSGEcon.round2

local function money(n) return ('%.2f'):format(n or 0) end

------------------------------------------
-- project state for client scripts (GlobalState['rsg-economy:projects'][region][projectId] = true)
------------------------------------------
local lastSync
function RSGEcon.SyncProjects()
    local out = {}
    for region in pairs(Config.Regions) do
        for _, p in ipairs(Config.Projects) do
            if RSGEcon.HasProject(region, p.id) then
                out[region] = out[region] or {}
                out[region][p.id] = true
            end
        end
    end
    local encoded = json.encode(out)
    if encoded ~= lastSync then
        lastSync = encoded
        GlobalState['rsg-economy:projects'] = out
    end
end

------------------------------------------
-- interest: once per UTC day
------------------------------------------
local function payInterest()
    local cfg = Config.Treasury.Interest
    if not cfg or not cfg.Enabled then return end
    local today = tostring(math.floor(os.time() / 86400))
    if RSGEcon.Meta.interest_day == today then return end
    -- record the day first and wait for it: a crash half way must never pay twice
    if not RSGEcon.SetMeta('interest_day', today, true) then return end

    local percent = tonumber(cfg.PercentPerDay) or 0
    local minBalance = tonumber(cfg.MinBalance) or 0
    local maxBalance = tonumber(cfg.MaxBalance) or math.huge
    if percent <= 0 then return end
    for region in pairs(Config.Regions) do
        local balance = RSGEcon.Treasury[region] or 0
        if balance >= minBalance and balance > 0 then
            local amount = round2(math.min(balance, maxBalance) * percent / 100)
            if amount > 0 then RSGEcon.DepositTreasury(region, amount, 'daily interest', 'rsg-economy', 'interest') end
        end
    end
end

------------------------------------------
-- weekly report by telegram: the mayor and the officials who are online
------------------------------------------
local function reportRecipients(region)
    local list, seen = {}, {}
    local function add(cid)
        if cid and not seen[cid] then seen[cid] = true; list[#list + 1] = cid end
    end
    local mayor = RSGEcon.GetMayor(region)
    if mayor then add(mayor.citizenid) end
    for src, P in pairs(RSGCore.Functions.GetRSGPlayers()) do
        if RSGEcon.IsOfficial(src, region) then add(P.PlayerData.citizenid) end
    end
    return list
end

local function sendReport(region, now)
    local recipients = reportRecipients(region)
    if #recipients == 0 then return end
    local ok, rows = pcall(MySQL.query.await, 'SELECT kind, COALESCE(SUM(amount), 0) AS total FROM rsg_economy_ledger WHERE region = ? AND created >= ? GROUP BY kind', { region, now - 7 * 86400 })
    if not ok then return end
    local t = {}
    for _, r in ipairs(rows or {}) do t[r.kind] = tonumber(r.total) or 0 end

    local label = RSGEcon.RegionLabel(region)
    local subject = locale('report_subject', label)
    local body = locale('report_body', money(RSGEcon.Treasury[region]), money(t.tax), money(t.deposit), money(t.interest),
        money(-(t.withdraw or 0)), money(-(t.payout or 0)), money(-(t.project or 0)))
    for _, cid in ipairs(recipients) do
        pcall(function()
            exports['rsg-telegram']:SendTelegram(cid, subject, body, { senderName = locale('tg_sender') })
        end)
    end
end

local function sendReports()
    local cfg = Config.Report
    if not cfg or not cfg.Enabled or GetResourceState('rsg-telegram') ~= 'started' then return end
    local now = os.time()
    if tonumber(os.date('!%w', now)) ~= (tonumber(cfg.Weekday) or 1) then return end
    local today = os.date('!%Y%m%d', now)
    if RSGEcon.Meta.report_day == today then return end
    if not RSGEcon.SetMeta('report_day', today, true) then return end
    for region in pairs(Config.Regions) do sendReport(region, now) end
end
RSGEcon.SendReports = sendReports

------------------------------------------
-- project wages: on-duty players with the town's law job, paid from the treasury
------------------------------------------
local nextWage = {}

local function payWages()
    local now = os.time()
    for _, p in ipairs(Config.Projects) do
        local e = p.effect
        if e and e.type == 'wage' then
            local interval = math.max(1, tonumber(e.interval) or 30) * 60
            if not nextWage[p.id] then nextWage[p.id] = now + interval end
            if now >= nextWage[p.id] then
                nextWage[p.id] = now + interval
                local amount = round2(tonumber(e.amount) or 0)
                if amount > 0 then
                    for region, r in pairs(Config.Regions) do
                        if r.lawJob and RSGEcon.HasProject(region, p.id) then
                            local paid = {}
                            for _, P in pairs(RSGCore.Functions.GetRSGPlayers()) do
                                local job = P.PlayerData.job
                                if job and job.name == r.lawJob and job.onduty then paid[#paid + 1] = P end
                            end
                            if #paid > 0 and RSGEcon.WithdrawTreasury(region, round2(amount * #paid), 'wage: ' .. p.id, 'rsg-economy', 'payout') then
                                for _, P in ipairs(paid) do
                                    P.Functions.AddMoney('cash', amount, 'town-project-wage')
                                    TriggerClientEvent('RSGCore:Client:Notify', P.PlayerData.source, {
                                        title = locale('notify_title'), description = locale('notify_wage', money(amount), RSGEcon.RegionLabel(region)),
                                        type = 'inform', duration = 5000,
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

------------------------------------------
-- one timer for all of it
------------------------------------------
CreateThread(function()
    while not RSGEcon.WaitReady() do Wait(1000) end
    while true do
        pcall(RSGEcon.SyncProjects)
        local ok, err = pcall(function()
            payInterest()
            sendReports()
            payWages()
        end)
        if not ok then print(('[rsg-economy] ^1automation failed: %s^7'):format(tostring(err))) end
        Wait(60 * 1000)
    end
end)
