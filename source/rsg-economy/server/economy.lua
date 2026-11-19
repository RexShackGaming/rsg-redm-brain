-- rsg-economy: taxes, treasuries, dynamic prices, quotes and exports
RSGEcon = RSGEcon or {}
local RSGCore = exports['rsg-core']:GetCoreObject()

------------------------------------------
-- helpers
------------------------------------------
local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function finite(v)
    return type(v) == 'number' and v == v and v > -math.huge and v < math.huge
end

local function round2(v) return math.floor(v * 100 + 0.5) / 100 end

local function validRegion(r) return type(r) == 'string' and Config.Regions[r] ~= nil end
local function validItem(i) return type(i) == 'string' and #i > 0 and #i <= 50 end

local function regionLabel(region)
    local r = Config.Regions[region]
    return locale(r and r.label or region)
end
RSGEcon.RegionLabel = regionLabel

local function actorName(src)
    if not src or src == 0 then return 'system' end
    local P = RSGCore.Functions.GetPlayer(src)
    if not P then return 'player ' .. tostring(src) end
    local ci = P.PlayerData.charinfo or {}
    return ('%s %s (%s)'):format(ci.firstname or '?', ci.lastname or '?', P.PlayerData.citizenid or '?')
end
RSGEcon.ActorName = actorName

------------------------------------------
-- taxes
------------------------------------------
function RSGEcon.GetTaxRate(region, category)
    if not validRegion(region) then return nil end
    local cat = Config.Tax.Categories[category]
    if not cat then return nil end
    local set = RSGEcon.Taxes[region]
    if set and set[category] ~= nil then return set[category] end
    return cat.default
end

-- returns ok, newRate | reason ('invalid' / 'unknown')
function RSGEcon.SetTaxRate(region, category, rate, actor)
    if not validRegion(region) then return false, 'unknown' end
    local cat = Config.Tax.Categories[category]
    if not cat then return false, 'unknown' end
    if not finite(rate) then return false, 'invalid' end
    local step = tonumber(Config.Tax.Step) or 0.005
    if step > 0 then rate = math.floor(rate / step + 0.5) * step end
    rate = clamp(math.floor(rate * 10000 + 0.5) / 10000, cat.min, cat.max)

    local old = RSGEcon.GetTaxRate(region, category)
    RSGEcon.Taxes[region] = RSGEcon.Taxes[region] or {}
    RSGEcon.Taxes[region][category] = rate
    RSGEcon.MarkTax(region, category)
    if old ~= rate then
        RSGEcon.Ledger(region, 0, RSGEcon.Treasury[region] or 0, 'tax_rate',
            ('%s %.2f%% -> %.2f%%'):format(category, old * 100, rate * 100), actor or 'system')
        TriggerEvent('rsg-economy:server:taxChanged', region, category, rate, old)
    end
    return true, rate
end

------------------------------------------
-- treasury
------------------------------------------
function RSGEcon.GetTreasury(region)
    if not validRegion(region) then return nil end
    return RSGEcon.Treasury[region] or 0
end

-- adds money; returns the new balance or nil
function RSGEcon.DepositTreasury(region, amount, reason, actor, kind, awaitLedger)
    if not validRegion(region) or not finite(amount) then return nil end
    amount = round2(amount)
    if amount <= 0 then return nil end
    local bal = round2((RSGEcon.Treasury[region] or 0) + amount)
    RSGEcon.Treasury[region] = bal
    RSGEcon.MarkTreasury(region)
    if kind ~= 'tax' or Config.Treasury.Ledger.LogTax then
        RSGEcon.Ledger(region, amount, bal, kind or 'deposit', reason or '', actor or 'system', awaitLedger)
    end
    TriggerEvent('rsg-economy:server:treasuryChanged', region, bal, amount, kind or 'deposit')
    return bal
end

-- removes money; returns the new balance, or nil when the treasury cannot cover it
function RSGEcon.WithdrawTreasury(region, amount, reason, actor, kind, awaitLedger)
    if not validRegion(region) or not finite(amount) then return nil end
    amount = round2(amount)
    if amount <= 0 then return nil end
    local cur = RSGEcon.Treasury[region] or 0
    if cur + 0.0001 < amount then return nil end
    local bal = math.max(0, round2(cur - amount))
    RSGEcon.Treasury[region] = bal
    RSGEcon.MarkTreasury(region)
    RSGEcon.Ledger(region, -amount, bal, kind or 'withdraw', reason or '', actor or 'system', awaitLedger)
    TriggerEvent('rsg-economy:server:treasuryChanged', region, bal, -amount, kind or 'withdraw')
    return bal
end

function RSGEcon.SetTreasury(region, value, actor)
    if not validRegion(region) or not finite(value) then return nil end
    local bal = math.max(0, round2(value))
    local old = RSGEcon.Treasury[region] or 0
    RSGEcon.Treasury[region] = bal
    RSGEcon.MarkTreasury(region)
    RSGEcon.Ledger(region, round2(bal - old), bal, 'admin', 'set balance', actor or 'system')
    TriggerEvent('rsg-economy:server:treasuryChanged', region, bal, bal - old, 'admin')
    return bal
end

------------------------------------------
-- dynamic prices
------------------------------------------
local function marketCfg(item)
    local m = Config.Market
    local o = m.Items and m.Items[item] or {}
    return {
        sensitivity = o.sensitivity or m.Sensitivity,
        min = o.min or m.MinMultiplier,
        max = o.max or m.MaxMultiplier,
        perUnit = o.perUnit or m.PressurePerUnit,
    }
end

-- pressure right now (it fades with the half life)
local function currentPressure(entry, now)
    local hl = (tonumber(Config.Market.HalfLifeHours) or 12) * 3600
    if hl <= 0 then return 0 end
    return entry.pressure * 0.5 ^ (math.max(0, now - entry.updated) / hl)
end

function RSGEcon.GetPressure(item, region)
    if not validItem(item) or not validRegion(region) then return 0 end
    local e = RSGEcon.Market[region] and RSGEcon.Market[region][item]
    if not e then return 0 end
    return currentPressure(e, os.time())
end

function RSGEcon.GetMarketMultiplier(item, region)
    if not Config.Market.Enabled or not validItem(item) or not validRegion(region) then return 1.0 end
    local c = marketCfg(item)
    return clamp(1 - RSGEcon.GetPressure(item, region) * c.sensitivity, c.min, c.max)
end

-- mode 'sell' = players sold to the town (oversupply, prices fall); 'buy' = players bought (demand, prices rise)
function RSGEcon.RecordTrade(item, region, qty, mode)
    if not Config.Market.Enabled or not validItem(item) or not validRegion(region) then return false end
    qty = tonumber(qty) or 1
    if not finite(qty) or qty < 1 then return false end
    qty = math.min(math.floor(qty), 10000)
    local c = marketCfg(item)
    local delta = qty * c.perUnit * (mode == 'sell' and 1 or -1)
    local now = os.time()
    RSGEcon.Market[region] = RSGEcon.Market[region] or {}
    local e = RSGEcon.Market[region][item] or { pressure = 0, updated = now }
    e.pressure = clamp(currentPressure(e, now) + delta, -1, 1)
    e.updated = now
    RSGEcon.Market[region][item] = e
    RSGEcon.MarkMarket(region, item)
    return true
end

function RSGEcon.ResetMarket(region, item)
    local n = 0
    for r, list in pairs(RSGEcon.Market) do
        if not region or r == region then
            for i in pairs(list) do
                if not item or i == item then
                    list[i] = nil
                    RSGEcon.MarkMarket(r, i)
                    n = n + 1
                end
            end
        end
    end
    return n
end

-- drops entries whose pressure has faded away
CreateThread(function()
    while true do
        Wait(10 * 60 * 1000)
        local now = os.time()
        for region, list in pairs(RSGEcon.Market) do
            for item, e in pairs(list) do
                if math.abs(currentPressure(e, now)) < 0.005 then
                    list[item] = nil
                    RSGEcon.MarkMarket(region, item)
                end
            end
        end
    end
end)

------------------------------------------
-- quotes
------------------------------------------
local function repModifier(src, region)
    if not src or not Config.UseReputation then return 0.0 end
    if GetResourceState('rsg-reputation') ~= 'started' then return 0.0 end
    local ok, mod = pcall(function() return exports['rsg-reputation']:GetPriceModifier(src, region) end)
    if ok and finite(mod) then return mod end
    return 0.0
end

--[[ opts: { region, mode = 'buy'|'sell', base = unit price, qty = 1, item = 'name'?, category = 'sales'|'trade'|..., market = false?, reputation = false? }
     returns nil for bad input, otherwise
     { region, mode, category, item, qty, base, marketMultiplier, repModifier, unitPrice, subtotal, taxRate, tax, total }
     buy:  total = subtotal + tax (what the player pays). sell: total = subtotal - tax (what the player receives). ]]
function RSGEcon.Quote(src, o)
    if type(o) ~= 'table' or not validRegion(o.region) then return nil end
    local mode = o.mode == 'sell' and 'sell' or 'buy'
    local base = tonumber(o.base)
    if not base or not finite(base) or base < 0 then return nil end
    local qty = tonumber(o.qty) or 1
    if not finite(qty) or qty < 1 or qty > 10000 then return nil end
    qty = math.floor(qty)
    local category = o.category or (mode == 'sell' and 'trade' or 'sales')
    if not Config.Tax.Categories[category] then return nil end

    local mult = 1.0
    if o.item ~= nil and o.market ~= false then
        if not validItem(o.item) then return nil end
        mult = RSGEcon.GetMarketMultiplier(o.item, o.region)
    end
    local rep = 0.0
    if o.reputation ~= false then rep = repModifier(src, o.region) end
    local factor = mode == 'buy' and (1 + rep) or (1 - rep)
    if factor < 0.1 then factor = 0.1 end

    local unit = round2(base * mult * factor)
    local subtotal = round2(unit * qty)
    local rate = RSGEcon.GetTaxRate(o.region, category)
    local tax = round2(subtotal * rate)
    local total = mode == 'buy' and round2(subtotal + tax) or round2(math.max(0, subtotal - tax))
    return {
        region = o.region, mode = mode, category = category, item = o.item, qty = qty, base = base,
        marketMultiplier = mult, repModifier = rep, unitPrice = unit, subtotal = subtotal,
        taxRate = rate, tax = tax, total = total,
    }
end

-- call once the money has really moved: banks the tax in the treasury and moves the market
function RSGEcon.Record(src, q)
    if type(q) ~= 'table' or not validRegion(q.region) then return false end
    local ok = false
    if finite(q.tax) and q.tax > 0 then
        ok = RSGEcon.DepositTreasury(q.region, q.tax, ('%s tax%s'):format(tostring(q.category), q.item and (': ' .. tostring(q.item)) or ''), actorName(src), 'tax') ~= nil
    end
    if q.item ~= nil and validItem(q.item) then
        RSGEcon.RecordTrade(q.item, q.region, q.qty, q.mode)
        ok = true
    end
    return ok
end

------------------------------------------
-- projects
------------------------------------------
function RSGEcon.HasProject(region, id)
    if not validRegion(region) or type(id) ~= 'string' then return false end
    local e = RSGEcon.Projects[region] and RSGEcon.Projects[region][id]
    if e == nil then return false end
    return e == 0 or e > os.time()
end

function RSGEcon.GetProjectDef(id)
    for _, p in ipairs(Config.Projects) do
        if p.id == id then return p end
    end
end

------------------------------------------
-- officials
------------------------------------------
function RSGEcon.IsOfficial(src, region)
    if not validRegion(region) then return false end
    local P = RSGCore.Functions.GetPlayer(src)
    if not P then return false end
    for _, o in ipairs(Config.Regions[region].officials or {}) do
        local minGrade = tonumber(o.minGrade) or 0
        local held, grade = false, nil
        local ok, h, g = pcall(function() return exports['rsg-core']:HasPlayerJob(src, o.job) end)
        if ok then held, grade = h, g end
        if held and (tonumber(grade) or 0) >= minGrade then
            -- on-duty only matters for the active job
            if not Config.RequireOnDuty or (P.PlayerData.job and P.PlayerData.job.name == o.job and P.PlayerData.job.onduty) then return true end
        end
        local job = P.PlayerData.job
        if job and job.name == o.job then
            local level = job.grade and tonumber(job.grade.level) or 0
            if (job.isboss or level >= minGrade) and (not Config.RequireOnDuty or job.onduty) then return true end
        end
    end
    return false
end

------------------------------------------
-- exports
------------------------------------------
exports('Quote', RSGEcon.Quote)
exports('Record', RSGEcon.Record)
exports('GetTaxRate', RSGEcon.GetTaxRate)
exports('SetTaxRate', RSGEcon.SetTaxRate)
exports('GetTreasury', RSGEcon.GetTreasury)
exports('DepositTreasury', function(region, amount, reason, actor) return RSGEcon.DepositTreasury(region, amount, reason, actor, 'deposit') end)
exports('WithdrawTreasury', function(region, amount, reason, actor) return RSGEcon.WithdrawTreasury(region, amount, reason, actor, 'payout') end)
exports('GetMarketMultiplier', RSGEcon.GetMarketMultiplier)
exports('GetPressure', RSGEcon.GetPressure)
exports('RecordTrade', RSGEcon.RecordTrade)
exports('ResetMarket', RSGEcon.ResetMarket)
exports('IsOfficial', RSGEcon.IsOfficial)
exports('HasProject', RSGEcon.HasProject)
exports('GetRegions', function() return Config.Regions end)

-- nearest region (with `coords`) to a position, within maxDistance (default Config.RegionRadius); nil when none is close enough.
-- coords may be a vector3/vector4 or a table with x, y, z. Returns regionId, distance.
exports('GetRegionAt', function(coords, maxDistance)
    if type(coords) ~= 'vector3' and type(coords) ~= 'vector4' and type(coords) ~= 'table' then return nil end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z) or 0.0
    if not x or not y then return nil end
    local limit = tonumber(maxDistance) or Config.RegionRadius or 800.0
    local best, bestDist
    for id, r in pairs(Config.Regions) do
        local c = r.coords
        if c then
            local d = #(vector3(x, y, z) - vector3(c.x, c.y, c.z))
            if d <= limit and (not bestDist or d < bestDist) then best, bestDist = id, d end
        end
    end
    return best, bestDist
end)
exports('GetCategories', function() return Config.Tax.Categories end)
