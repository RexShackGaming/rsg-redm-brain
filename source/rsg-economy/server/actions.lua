-- rsg-economy: panel data and the actions players and officials can take (all validated here)
local RSGCore = exports['rsg-core']:GetCoreObject()

local finite, round2 = RSGEcon.finite, RSGEcon.round2

local function itemLabel(name)
    local it = RSGCore.Shared.Items and RSGCore.Shared.Items[name]
    return it and it.label or name
end

------------------------------------------
-- throttling: one action per player at a time, and not more than every 400 ms
------------------------------------------
local lastAction, busy, lastRead, lastLedger = {}, {}, {}, {}
local lastDeposit, lastRepGain = {}, {}

local function throttleRead(src, store, ms)
    local now = GetGameTimer()
    if store[src] and now - store[src] < ms then return false end
    store[src] = now
    return true
end

local function guarded(name, fn)
    RSGCore.Functions.CreateCallback(name, function(source, cb, ...)
        if busy[source] or not throttleRead(source, lastAction, 400) then
            return cb({ ok = false, msg = locale('msg_busy') })
        end
        busy[source] = true
        local args = { ... }
        local ok, a, b = pcall(function() return fn(source, table.unpack(args)) end)
        busy[source] = nil
        if not ok then
            print(('[rsg-economy] ^1%s failed: %s^7'):format(name, tostring(a)))
            return cb({ ok = false, msg = locale('msg_failed') })
        end
        cb({ ok = a == true, msg = b })
    end)
end

AddEventHandler('playerDropped', function()
    lastAction[source], busy[source], lastRead[source], lastLedger[source], lastDeposit[source] = nil, nil, nil, nil, nil
end)

local function canSee(src, region)
    return Config.Treasury.PublicBalance or RSGEcon.IsOfficial(src, region)
end

-- withdrawals still being processed, per region (counted against the daily limit before they reach the ledger)
local pendingWithdraw = {}

-- money officials already took out of a region today (UTC day), from the ledger. nil when the database fails.
local function withdrawnToday(region)
    local dayStart = os.time() - (os.time() % 86400)
    local ok, used = pcall(MySQL.scalar.await, "SELECT COALESCE(SUM(-amount), 0) FROM rsg_economy_ledger WHERE region = ? AND kind = 'withdraw' AND created >= ?", { region, dayStart })
    if not ok then return nil end
    return tonumber(used) or 0
end

-- money one official already took out of a region today
local function withdrawnTodayBy(region, citizenid)
    local dayStart = os.time() - (os.time() % 86400)
    local ok, used = pcall(MySQL.scalar.await, "SELECT COALESCE(SUM(-amount), 0) FROM rsg_economy_ledger WHERE region = ? AND kind = 'withdraw' AND created >= ? AND actor LIKE ?", { region, dayStart, '%(' .. citizenid .. ')' })
    if not ok then return nil end
    return tonumber(used) or 0
end

local function isAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.AdminPermission)
end

-- region the panel opens on: the town the player stands in, else one they run, else the first
local function defaultRegion(src, regions)
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local near = RSGEcon.GetRegionAt(GetEntityCoords(ped))
        if near then return near end
    end
    for _, r in ipairs(regions) do
        if r.official then return r.id end
    end
    return regions[1] and regions[1].id
end

------------------------------------------
-- panel data (read-only)
------------------------------------------
local function buildRegion(src, id, r)
    local official = RSGEcon.IsOfficial(src, id)
    local taxes = {}
    for key, c in pairs(Config.Tax.Categories) do
        taxes[#taxes + 1] = {
            key = key, label = locale(c.label), rate = RSGEcon.GetTaxRate(id, key),
            min = c.min, max = c.max, default = c.default, order = c.order or 0,
        }
    end
    table.sort(taxes, function(a, b) return a.order < b.order end)

    local projects = {}
    for _, p in ipairs(Config.Projects) do
        local e = RSGEcon.Projects[id] and RSGEcon.Projects[id][p.id]
        projects[#projects + 1] = {
            id = p.id, label = locale(p.label), cost = p.cost, days = p.days or 0,
            active = RSGEcon.HasProject(id, p.id), expires = e or 0,
        }
    end

    local movers = {}
    for item, e in pairs(RSGEcon.Market[id] or {}) do
        local mult = RSGEcon.GetMarketMultiplier(item, id)
        if math.abs(mult - 1) >= 0.005 then
            movers[#movers + 1] = { item = item, label = itemLabel(item), multiplier = mult }
        end
    end
    table.sort(movers, function(a, b) return math.abs(a.multiplier - 1) > math.abs(b.multiplier - 1) end)
    while #movers > 12 do movers[#movers] = nil end

    return {
        id = id, label = RSGEcon.RegionLabel(id), order = r.order or 0, official = official,
        mayor = (RSGEcon.GetMayor(id) or {}).name,
        balance = canSee(src, id) and RSGEcon.GetTreasury(id) or nil,
        taxes = taxes, projects = projects, movers = movers,
    }
end

RSGCore.Functions.CreateCallback('rsg-economy:server:getPanel', function(source, cb)
    if not throttleRead(source, lastRead, 700) then return cb(nil) end
    if not RSGEcon.Ready then return cb(nil) end
    local regions = {}
    for id, r in pairs(Config.Regions) do regions[#regions + 1] = buildRegion(source, id, r) end
    table.sort(regions, function(a, b) return a.order < b.order end)
    cb({
        regions = regions,
        defaultRegion = defaultRegion(source, regions),
        admin = isAdmin(source),
        elections = Config.Elections and Config.Elections.Enabled == true,
        step = Config.Tax.Step,
        canWithdraw = Config.Treasury.Withdraw.Enabled,
        dailyLimit = Config.Treasury.Withdraw.DailyLimit,
        donations = Config.Treasury.AllowPublicDonations,
        maxAmount = Config.Treasury.MaxAmount,
    })
end)

RSGCore.Functions.CreateCallback('rsg-economy:server:getLedger', function(source, cb, region)
    if not throttleRead(source, lastLedger, 700) then return cb(nil) end
    if type(region) ~= 'string' or not Config.Regions[region] or not canSee(source, region) or not RSGEcon.Ready then return cb(nil) end
    local size = math.max(1, math.min(50, tonumber(Config.Treasury.Ledger.PageSize) or 20))
    local ok, rows = pcall(MySQL.query.await, 'SELECT amount, kind, reason, actor, created FROM rsg_economy_ledger WHERE region = ? ORDER BY created DESC, id DESC LIMIT ?', { region, size })
    if not ok then return cb(nil) end

    local official = RSGEcon.IsOfficial(source, region)
    local out = {}
    for _, r in ipairs(rows or {}) do
        local actor = tostring(r.actor or '')
        -- citizen ids are only for officials: "First Last (ABC12345)" becomes "First Last"
        if not official then actor = (actor:gsub('%s*%b()$', '')) end
        out[#out + 1] = { amount = tonumber(r.amount) or 0, kind = r.kind, reason = r.reason, actor = actor, created = tonumber(r.created) or 0 }
    end

    -- what an official can still withdraw today
    local remaining
    local limit = tonumber(Config.Treasury.Withdraw.DailyLimit) or 0
    if official and Config.Treasury.Withdraw.Enabled then
        if limit > 0 then
            local used = withdrawnToday(region)
            if used then remaining = math.max(0, limit - used - (pendingWithdraw[region] or 0)) end
        end
        local personal = tonumber(Config.Treasury.Withdraw.PlayerDailyLimit) or 0
        local P = RSGCore.Functions.GetPlayer(source)
        if personal > 0 and P then
            local usedBy = withdrawnTodayBy(region, P.PlayerData.citizenid)
            if usedBy then
                local left = math.max(0, personal - usedBy)
                remaining = remaining and math.min(remaining, left) or left
            end
        end
    end
    cb({ rows = out, remaining = remaining })
end)

------------------------------------------
-- actions
------------------------------------------
local function parseAmount(v)
    local n = tonumber(v)
    if not n or not finite(n) then return nil end
    n = round2(n)
    if n <= 0 or n > (tonumber(Config.Treasury.MaxAmount) or 1000000) then return nil end
    return n
end

local function regionOf(v)
    if type(v) == 'string' and Config.Regions[v] then return v end
end

local lastTaxChange = {}

guarded('rsg-economy:server:setTax', function(src, region, category, rate)
    region = regionOf(region)
    if not region or type(category) ~= 'string' or not Config.Tax.Categories[category] then return false, locale('msg_failed') end
    if not RSGEcon.IsOfficial(src, region) then return false, locale('msg_not_official') end
    rate = tonumber(rate)
    if not rate or not finite(rate) then return false, locale('msg_failed') end

    local key = region .. '|' .. category
    local now = os.time()
    local cd = tonumber(Config.Tax.ChangeCooldown) or 0
    if lastTaxChange[key] and now - lastTaxChange[key] < cd then
        return false, locale('msg_tax_cooldown', cd - (now - lastTaxChange[key]))
    end
    local ok, new = RSGEcon.SetTaxRate(region, category, rate, RSGEcon.ActorName(src))
    if not ok then return false, locale('msg_failed') end
    lastTaxChange[key] = now
    return true, locale('msg_tax_set', locale(Config.Tax.Categories[category].label), RSGEcon.RegionLabel(region), ('%.1f%%'):format(new * 100))
end)

guarded('rsg-economy:server:withdraw', function(src, region, amount)
    region = regionOf(region)
    amount = parseAmount(amount)
    if not region or not amount then return false, locale('msg_invalid_amount') end
    if not Config.Treasury.Withdraw.Enabled then return false, locale('msg_withdraw_disabled') end
    if not RSGEcon.IsOfficial(src, region) then return false, locale('msg_not_official') end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false, locale('msg_failed') end

    -- daily limit: money already taken today (ledger) plus withdrawals still in flight
    local limit = tonumber(Config.Treasury.Withdraw.DailyLimit) or 0
    pendingWithdraw[region] = (pendingWithdraw[region] or 0) + amount
    local function release() pendingWithdraw[region] = math.max(0, (pendingWithdraw[region] or 0) - amount) end

    local used = withdrawnToday(region)
    if not used then release() return false, locale('msg_failed') end

    -- personal limit: one official cannot empty the daily allowance of the whole town
    local personal = tonumber(Config.Treasury.Withdraw.PlayerDailyLimit) or 0
    if personal > 0 then
        local usedBy = withdrawnTodayBy(region, Player.PlayerData.citizenid)
        if not usedBy then release() return false, locale('msg_failed') end
        if usedBy + amount > personal + 0.0001 then
            release()
            return false, locale('msg_personal_limit', ('%.2f'):format(math.max(0, personal - usedBy)))
        end
    end
    if limit > 0 and used + pendingWithdraw[region] > limit + 0.0001 then
        release()
        return false, locale('msg_limit_reached', ('%.2f'):format(math.max(0, limit - used)))
    end

    if not RSGEcon.WithdrawTreasury(region, amount, 'withdrawal', RSGEcon.ActorName(src), 'withdraw', true) then
        release()
        return false, locale('msg_insufficient_treasury')
    end
    -- persist the lower balance before paying out, so a crash can never pay twice
    RSGEcon.SaveTreasuryNow(region)
    local paid = Player.Functions.AddMoney(Config.MoneyType, amount, 'town-treasury-withdrawal')
    if paid == false then
        RSGEcon.DepositTreasury(region, amount, 'refund: payout failed', 'system', 'admin', true)
        release()
        return false, locale('msg_failed')
    end
    release()

    -- a big withdrawal warns the other officials who are online
    local alertAt = tonumber(Config.Treasury.Withdraw.AlertAbove) or 0
    if alertAt > 0 and amount >= alertAt then
        for psrc in pairs(RSGCore.Functions.GetRSGPlayers()) do
            if psrc ~= src and RSGEcon.IsOfficial(psrc, region) then
                TriggerClientEvent('RSGCore:Client:Notify', psrc, {
                    title = locale('notify_title'), type = 'warning', duration = 8000,
                    description = locale('notify_large_withdrawal', RSGEcon.ActorName(src), ('%.2f'):format(amount), RSGEcon.RegionLabel(region)),
                })
            end
        end
    end
    return true, locale('msg_withdrawn', ('%.2f'):format(amount), RSGEcon.RegionLabel(region))
end)

guarded('rsg-economy:server:deposit', function(src, region, amount)
    region = regionOf(region)
    amount = parseAmount(amount)
    if not region or not amount then return false, locale('msg_invalid_amount') end
    if not Config.Treasury.AllowPublicDonations and not RSGEcon.IsOfficial(src, region) then return false, locale('msg_not_official') end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false, locale('msg_failed') end

    -- a minimum and a short cooldown stop tiny donations from flooding the ledger or farming reputation
    local minDeposit = tonumber(Config.Treasury.MinDeposit) or 0
    if amount < minDeposit then return false, locale('msg_min_deposit', ('%.2f'):format(minDeposit)) end
    local now = os.time()
    local wait = tonumber(Config.Treasury.DepositCooldown) or 0
    if wait > 0 and lastDeposit[src] and now - lastDeposit[src] < wait then return false, locale('msg_busy') end

    if not Player.Functions.RemoveMoney(Config.MoneyType, amount, 'town-treasury-deposit') then
        return false, locale('msg_no_money')
    end
    if not RSGEcon.DepositTreasury(region, amount, 'donation', RSGEcon.ActorName(src), 'deposit', true) then
        Player.Functions.AddMoney(Config.MoneyType, amount, 'town-treasury-deposit-refund') -- treasury full or not ready: give it back
        return false, locale('msg_failed')
    end
    lastDeposit[src] = now
    RSGEcon.SaveTreasuryNow(region)

    -- reputation for big enough donations, once per cooldown per town
    local action = Config.Treasury.DonationAction
    if action and Config.UseReputation and GetResourceState('rsg-reputation') == 'started'
        and amount >= (tonumber(Config.Treasury.DonationRepMin) or 0) then
        local key = ('%s|%s'):format(Player.PlayerData.citizenid or src, region)
        if not lastRepGain[key] or now - lastRepGain[key] >= (tonumber(Config.Treasury.DonationRepCooldown) or 0) then
            lastRepGain[key] = now
            pcall(function() exports['rsg-reputation']:ApplyAction(src, action, region) end)
        end
    end
    return true, locale('msg_deposited', ('%.2f'):format(amount), RSGEcon.RegionLabel(region))
end)

guarded('rsg-economy:server:fundProject', function(src, region, projectId)
    region = regionOf(region)
    local def = type(projectId) == 'string' and RSGEcon.GetProjectDef(projectId)
    if not region or not def then return false, locale('msg_failed') end
    if not RSGEcon.IsOfficial(src, region) then return false, locale('msg_not_official') end
    if RSGEcon.HasProject(region, def.id) then return false, locale('msg_project_active') end

    local cost = tonumber(def.cost) or 0
    local days = tonumber(def.days) or 0
    local expires = days > 0 and (os.time() + math.floor(days * 86400)) or 0

    -- claim the project before paying: paying waits on the database, and a second official must not fund it meanwhile
    RSGEcon.Projects[region] = RSGEcon.Projects[region] or {}
    local previous = RSGEcon.Projects[region][def.id]
    RSGEcon.Projects[region][def.id] = expires
    if cost <= 0 or not RSGEcon.WithdrawTreasury(region, cost, 'project: ' .. def.id, RSGEcon.ActorName(src), 'project', true) then
        RSGEcon.Projects[region][def.id] = previous
        return false, locale('msg_insufficient_treasury')
    end
    RSGEcon.SaveTreasuryNow(region)
    RSGEcon.SaveProjectNow(region, def.id)
    pcall(RSGEcon.SyncProjects)
    TriggerEvent('rsg-economy:server:projectFunded', region, def.id, expires, src)
    return true, locale('msg_project_funded', locale(def.label), RSGEcon.RegionLabel(region))
end)

------------------------------------------
-- elections
------------------------------------------
local lastElection = {}

RSGCore.Functions.CreateCallback('rsg-economy:server:getElection', function(source, cb, region)
    if not throttleRead(source, lastElection, 700) or not RSGEcon.Ready then return cb(nil) end
    local ok, view = pcall(RSGEcon.ElectionView, source, regionOf(region))
    cb(ok and view or nil)
end)

guarded('rsg-economy:server:electionRegister', function(src, region, platform)
    region = regionOf(region)
    if not region then return false, locale('msg_failed') end
    return RSGEcon.ElectionRegister(src, region, platform)
end)

guarded('rsg-economy:server:electionWithdraw', function(src, region)
    region = regionOf(region)
    if not region then return false, locale('msg_failed') end
    return RSGEcon.ElectionWithdraw(src, region)
end)

guarded('rsg-economy:server:electionVote', function(src, region, candidate)
    region = regionOf(region)
    if not region then return false, locale('msg_failed') end
    return RSGEcon.ElectionVote(src, region, candidate)
end)

------------------------------------------
-- admin: towns
------------------------------------------
local lastAdmin = {}

RSGCore.Functions.CreateCallback('rsg-economy:server:getAdmin', function(source, cb)
    if not throttleRead(source, lastAdmin, 700) or not isAdmin(source) then return cb(nil) end
    cb(RSGEcon.AdminList())
end)

guarded('rsg-economy:server:adminSaveRegion', function(src, data)
    if not isAdmin(src) then return false, locale('msg_admin_only') end
    local ok, key, label = RSGEcon.AdminSaveRegion(src, data)
    return ok, locale(key, label)
end)

guarded('rsg-economy:server:adminDeleteRegion', function(src, id)
    if not isAdmin(src) then return false, locale('msg_admin_only') end
    local ok, key, label = RSGEcon.AdminDeleteRegion(id)
    return ok, locale(key, label)
end)
