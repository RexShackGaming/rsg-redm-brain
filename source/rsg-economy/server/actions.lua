-- rsg-economy: panel data and the actions players and officials can take (all validated here)
local RSGCore = exports['rsg-core']:GetCoreObject()

local function round2(v) return math.floor(v * 100 + 0.5) / 100 end
local function finite(v) return type(v) == 'number' and v == v and v > -math.huge and v < math.huge end

local function itemLabel(name)
    local it = RSGCore.Shared.Items and RSGCore.Shared.Items[name]
    return it and it.label or name
end

------------------------------------------
-- throttling: one action per player at a time, and not more than every 400 ms
------------------------------------------
local lastAction, busy, lastRead = {}, {}, {}

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
    lastAction[source], busy[source], lastRead[source] = nil, nil, nil
end)

local function canSee(src, region)
    return Config.Treasury.PublicBalance or RSGEcon.IsOfficial(src, region)
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
        step = Config.Tax.Step,
        canWithdraw = Config.Treasury.Withdraw.Enabled,
        dailyLimit = Config.Treasury.Withdraw.DailyLimit,
        donations = Config.Treasury.AllowPublicDonations,
        maxAmount = Config.Treasury.MaxAmount,
    })
end)

RSGCore.Functions.CreateCallback('rsg-economy:server:getLedger', function(source, cb, region)
    if not throttleRead(source, lastRead, 700) then return cb(nil) end
    if type(region) ~= 'string' or not Config.Regions[region] or not canSee(source, region) or not RSGEcon.Ready then return cb(nil) end
    local size = math.max(1, math.min(50, tonumber(Config.Treasury.Ledger.PageSize) or 20))
    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT amount, balance_after, kind, reason, actor, created FROM rsg_economy_ledger WHERE region = ? ORDER BY id DESC LIMIT ?', { region, size })
    end)
    if not ok then return cb(nil) end
    local out = {}
    for _, r in ipairs(rows or {}) do
        out[#out + 1] = { amount = tonumber(r.amount) or 0, kind = r.kind, reason = r.reason, actor = r.actor, created = tonumber(r.created) or 0 }
    end
    cb(out)
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

local pendingWithdraw = {}

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

    local dayStart = os.time() - (os.time() % 86400)
    local okq, used = pcall(function()
        return MySQL.scalar.await("SELECT COALESCE(SUM(-amount), 0) FROM rsg_economy_ledger WHERE region = ? AND kind = 'withdraw' AND created >= ?", { region, dayStart })
    end)
    if not okq then release() return false, locale('msg_failed') end
    used = tonumber(used) or 0
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
    return true, locale('msg_withdrawn', ('%.2f'):format(amount), RSGEcon.RegionLabel(region))
end)

guarded('rsg-economy:server:deposit', function(src, region, amount)
    region = regionOf(region)
    amount = parseAmount(amount)
    if not region or not amount then return false, locale('msg_invalid_amount') end
    if not Config.Treasury.AllowPublicDonations and not RSGEcon.IsOfficial(src, region) then return false, locale('msg_not_official') end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false, locale('msg_failed') end

    if not Player.Functions.RemoveMoney(Config.MoneyType, amount, 'town-treasury-deposit') then
        return false, locale('msg_no_money')
    end
    RSGEcon.DepositTreasury(region, amount, 'donation', RSGEcon.ActorName(src), 'deposit', true)
    RSGEcon.SaveTreasuryNow(region)

    local action = Config.Treasury.DonationAction
    if action and Config.UseReputation and GetResourceState('rsg-reputation') == 'started' then
        pcall(function() exports['rsg-reputation']:ApplyAction(src, action, region) end)
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
    if cost <= 0 or not RSGEcon.WithdrawTreasury(region, cost, 'project: ' .. def.id, RSGEcon.ActorName(src), 'project', true) then
        return false, locale('msg_insufficient_treasury')
    end
    local days = tonumber(def.days) or 0
    local expires = days > 0 and (os.time() + math.floor(days * 86400)) or 0
    RSGEcon.Projects[region] = RSGEcon.Projects[region] or {}
    RSGEcon.Projects[region][def.id] = expires
    RSGEcon.SaveTreasuryNow(region)
    RSGEcon.SaveProjectNow(region, def.id)
    TriggerEvent('rsg-economy:server:projectFunded', region, def.id, expires, src)
    return true, locale('msg_project_funded', locale(def.label), RSGEcon.RegionLabel(region))
end)
