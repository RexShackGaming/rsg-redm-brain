local RSGCore = exports['rsg-core']:GetCoreObject()

local Inventory = exports['rsg-inventory']
local busy, lastUse, spamHits, lastShop, lastAlert = {}, {}, {}, {}, {}
local SPAM_ALERT_AT = 5      -- blocked requests before a spam alert is logged
local MAX_QTY_PER_FISH = 1000
local DIST_SLACK = 1.5       -- extra metres on top of Config.MaxUseDistance (the client closes the menu at the exact limit)
local ALERT_COOLDOWN = 5000  -- ms between suspicious-activity webhooks per player (stops a flood hiding real logs)
local dbReady = false

---------------------------------
-- helpers
---------------------------------
local function round2(n) return math.floor(n * 100 + 0.5) / 100 end
local function round4(n) return math.floor(n * 10000 + 0.5) / 10000 end
local function today() return os.date('%Y-%m-%d') end

local function itemLabel(item)
    local data = RSGCore.Shared.Items[item]
    return data and data.label or item
end

local function locName(loc) return locale('loc_' .. loc.key) end

-- price paid for a fillet item (nil = not a sellable fillet)
local function filletPrice(item)
    local c = Config.FilletSale
    return c and c.enabled and c.items and tonumber(c.items[item]) or nil
end

local function isSellable(item) return Config.Fish[item] ~= nil or filletPrice(item) ~= nil end

local maxCartLines = 0
for _ in pairs(Config.Fish) do maxCartLines = maxCartLines + 1 end
for _ in pairs((Config.FilletSale and Config.FilletSale.items) or {}) do maxCartLines = maxCartLines + 1 end

-- returns near, distance, location
local function isNearLocation(src, index)
    local loc = Config.Locations[tonumber(index) or 0]
    if not loc then return false, nil, nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, nil, loc end
    local dist = #(GetEntityCoords(ped) - loc.coords.xyz)
    return dist <= Config.MaxUseDistance + DIST_SLACK, dist, loc
end

-- in-game hour from rsg-weather (nil = unknown, treated as open)
local function currentHour()
    if not Config.OpeningHours.enabled or GetResourceState('rsg-weather') ~= 'started' then return nil end
    local ok, t = pcall(function() return exports['rsg-weather']:getTime() end)
    return ok and type(t) == 'table' and t.hour or nil
end

-- close lower than open wraps past midnight; a location can override with hours = { open, close }
local function isOpen(loc)
    local cfg = Config.OpeningHours
    local h, hour = loc.hours or cfg, currentHour()
    if not cfg.enabled or hour == nil or h.open == h.close then return true, h.open, h.close end
    if h.open < h.close then return hour >= h.open and hour < h.close, h.open, h.close end
    return hour >= h.open or hour < h.close, h.open, h.close
end

---------------------------------
-- daily demand (deterministic per town per real day, no storage needed)
---------------------------------
local function hashString(seed)
    local h = 7
    for i = 1, #seed do h = (h * 31 + seed:byte(i)) % 2147483647 end
    return h
end

local function demandFor(loc)
    local cfg = Config.Demand
    if not cfg.enabled or loc.demand == false then return 1.0 end
    local r = (hashString(today() .. loc.key) % 10007) / 10006
    return round2(cfg.min + (cfg.max - cfg.min) * r)
end

---------------------------------
-- seller bonus (job + skill + reputation)
---------------------------------
local function bonusFor(Player)
    local b, cfg = 0, Config.Bonus
    local job = Player.PlayerData.job
    if job and cfg.jobs[job.name] then b = b + cfg.jobs[job.name] end
    if cfg.skill and cfg.skill.enabled and GetResourceState('rsg-skills') == 'started' then
        local ok, res = pcall(function() return exports['rsg-skills']:GetPerk(Player.PlayerData.source, cfg.skill.name, cfg.skill.perk) end)
        local perk = ok and tonumber(res) or 0
        b = b + math.max(0, perk) / 100
    end
    if cfg.rep.enabled then
        b = b + math.min(cfg.rep.max, (Player.Functions.GetRep(cfg.rep.name) or 0) * cfg.rep.perPoint)
    end
    return round2(b)
end

local function fishingLevel(src)
    if GetResourceState('rsg-skills') ~= 'started' then return 0 end
    local skill = (Config.Shop and Config.Shop.skill) or 'fishing'
    local ok, lvl = pcall(function() return exports['rsg-skills']:GetLevel(src, skill) end)
    return ok and tonumber(lvl) or 0
end

---------------------------------
-- rsg-economy (optional): town tax + standing price modifier
---------------------------------
local function economyQuote(src, loc, base)
    if not (Config.Economy and Config.Economy.Enabled) or GetResourceState('rsg-economy') ~= 'started' then return nil end
    local ok, q = pcall(function()
        local region = exports['rsg-economy']:GetRegionAt(vector3(loc.coords.x, loc.coords.y, loc.coords.z))
        if not region then return nil end
        return exports['rsg-economy']:Quote(src, { region = region, mode = 'sell', base = base, qty = 1, market = false })
    end)
    if ok and type(q) == 'table' and type(q.total) == 'number' and q.total >= 0 and q.total < math.huge then return q end
    return nil
end

-- price factor shown in the menu so the preview matches the payout (tax and standing are linear in the base)
local function economyFactor(src, loc)
    local q = economyQuote(src, loc, 1000)
    return q and (q.total / 1000) or 1.0
end

---------------------------------
-- fish quality: bigger and fresher fish pay more (read from the item's info)
---------------------------------
local function unitMult(info)
    local q = Config.Quality
    if not q or not q.enabled or type(info) ~= 'table' then return 1.0 end
    local m = 1.0
    if q.freshness and q.freshness.enabled then
        local quality = tonumber(info.quality)
        if quality then
            local lo = q.freshness.min or 0.6
            m = m * (lo + (1 - lo) * math.max(0, math.min(100, quality)) / 100)
        end
    end
    if q.size and q.size.enabled then
        local kg = tonumber(info.weight)
        if kg and kg > 0 then m = m * (1 + math.min(q.size.max or 0.15, kg * (q.size.perKg or 0.04))) end
    end
    return m
end

---------------------------------
-- inventory: every stack of a sellable item, in slot order (fish are unique, so each has its own info)
---------------------------------
local function inventoryStacks(Player)
    local by = {}
    for key, item in pairs(Player.PlayerData.items or {}) do
        if item and isSellable(item.name) then
            local amount = tonumber(item.amount) or 0
            if amount > 0 then
                local list = by[item.name]
                if not list then list = {}; by[item.name] = list end
                list[#list + 1] = { slot = tonumber(item.slot) or tonumber(key) or 0, amount = amount, info = item.info }
            end
        end
    end
    for _, list in pairs(by) do table.sort(list, function(a, b) return a.slot < b.slot end) end
    return by
end

-- picks the first `qty` units in slot order; returns picks, value-units (qty weighted by quality), enough
local function planPicks(stacksBy, item, qty)
    local picks, units, need = {}, 0, qty
    local isFish = Config.Fish[item] ~= nil
    for _, st in ipairs(stacksBy[item] or {}) do
        if need <= 0 then break end
        local take = math.min(st.amount, need)
        picks[#picks + 1] = { slot = st.slot, amount = take, info = st.info }
        units = units + take * (isFish and unitMult(st.info) or 1.0)
        need = need - take
    end
    return picks, units, need <= 0
end

local function removePicks(src, plan, reason)
    local removed = {}
    for item, picks in pairs(plan) do
        for _, p in ipairs(picks) do
            if not Inventory:RemoveItem(src, item, p.amount, p.slot, reason) then return false, removed end
            removed[#removed + 1] = { item = item, amount = p.amount, info = p.info }
        end
    end
    return true, removed
end

local function restoreFish(src, removed)
    for _, r in ipairs(removed) do Inventory:AddItem(src, r.item, r.amount, r.info, nil, 'fishmonger-rollback') end
end

---------------------------------
-- daily stock (MySQL, survives restarts)
-- resets at midnight, or recovers gradually when Config.DailyStock.recoveryPerHour > 0
---------------------------------
local stockCache = {} -- [loc.key] = { day = 'YYYY-MM-DD', sold = n, ts = os.time() of the last sale }

local function getSold(loc)
    local d = stockCache[loc.key]
    if not d then return 0 end
    local rate = tonumber(Config.DailyStock.recoveryPerHour) or 0
    if rate > 0 then
        return math.max(0, d.sold - math.max(0, os.time() - (d.ts or 0)) / 3600 * rate)
    end
    return d.day == today() and d.sold or 0
end

local function addSold(loc, n)
    local sold = math.ceil(getSold(loc)) + n
    local day, ts = today(), os.time()
    stockCache[loc.key] = { day = day, sold = sold, ts = ts }
    MySQL.update('INSERT INTO rsg_fishmonger_stock (`location`, `day`, `sold`, `updated`) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE `day` = VALUES(`day`), `sold` = VALUES(`sold`), `updated` = VALUES(`updated`)', { loc.key, day, sold, ts })
end

-- same schema as install.sql (keep the two in sync)
local function ensureDatabase()
    local ok, err = pcall(function()
        MySQL.query.await('CREATE TABLE IF NOT EXISTS `rsg_fishmonger_stock` (`location` VARCHAR(50) NOT NULL, `day` VARCHAR(10) NOT NULL, `sold` INT NOT NULL DEFAULT 0, `updated` INT NOT NULL DEFAULT 0, PRIMARY KEY (`location`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4')
        MySQL.query.await('CREATE TABLE IF NOT EXISTS `rsg_fishmonger_orders` (`citizenid` VARCHAR(50) NOT NULL, `location` VARCHAR(50) NOT NULL, `slot` TINYINT NOT NULL, `day` VARCHAR(10) NOT NULL, PRIMARY KEY (`citizenid`, `location`, `slot`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4')
        -- tables made by 3.2.x have no `updated` column
        local has = MySQL.scalar.await("SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rsg_fishmonger_stock' AND COLUMN_NAME = 'updated'")
        if (tonumber(has) or 0) == 0 then
            MySQL.query.await('ALTER TABLE `rsg_fishmonger_stock` ADD COLUMN `updated` INT NOT NULL DEFAULT 0')
        end
    end)
    if not ok then
        print(('^1[%s] could not create the database tables: %s^7'):format(GetCurrentResourceName(), tostring(err)))
        return false
    end
    print(('^2[%s] database tables ready^7'):format(GetCurrentResourceName()))
    return true
end

MySQL.ready(function()
    if Config.AutoDatabase ~= false and not ensureDatabase() then return end -- set false and import install.sql for a manual install
    local rows = MySQL.query.await('SELECT `location`, `day`, `sold`, `updated` FROM rsg_fishmonger_stock') or {}
    for _, r in ipairs(rows) do
        if not stockCache[r.location] then stockCache[r.location] = { day = r.day, sold = tonumber(r.sold) or 0, ts = tonumber(r.updated) or 0 } end
    end
    MySQL.update('DELETE FROM rsg_fishmonger_orders WHERE `day` < ?', { today() }) -- yesterday's completed orders
    dbReady = true
end)

-- nil = unlimited
local function stockLeft(loc)
    if not Config.DailyStock.enabled then return nil end
    local cap = loc.stock or Config.DailyStock.perLocation
    if not cap or cap <= 0 then return nil end
    return math.max(0, cap - math.ceil(getSold(loc)))
end

local function addRep(Player, fish)
    local rep = Config.Bonus.rep
    if rep.enabled and rep.gainPerFish > 0 and fish > 0 then pcall(Player.Functions.AddRep, rep.name, fish * rep.gainPerFish) end
end

---------------------------------
-- daily orders (contracts): each town posts a few fish orders per real day, same for everyone
---------------------------------
local orderFish = nil -- sorted list of orderable fish items (built on first use, once shared items are loaded)

local function contractsFor(loc)
    local cfg = Config.Contracts
    if not cfg or not cfg.enabled or loc.orders == false then return {} end
    if not orderFish then
        orderFish = {}
        for item in pairs(Config.Fish) do
            if RSGCore.Shared.Items[item] then orderFish[#orderFish + 1] = item end
        end
        table.sort(orderFish)
    end
    if #orderFish == 0 then return {} end
    local list = {}
    local span = math.max(1, (cfg.maxQty or 10) - (cfg.minQty or 3) + 1)
    for slot = 1, math.max(1, math.floor(cfg.perLocation or 2)) do
        local seed = today() .. loc.key .. slot
        local item = orderFish[hashString(seed .. 'f') % #orderFish + 1]
        local qty = (cfg.minQty or 3) + hashString(seed .. 'q') % span
        list[slot] = { slot = slot, item = item, qty = qty, reward = round2(Config.Fish[item].price * qty * (cfg.payMultiplier or 1.5)) }
    end
    return list
end

-- set of order slots this player already delivered today at this town
local function doneSlots(Player, loc)
    local done = {}
    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT `slot` FROM rsg_fishmonger_orders WHERE `citizenid` = ? AND `location` = ? AND `day` = ?', { Player.PlayerData.citizenid, loc.key, today() })
    end)
    if ok then for _, r in ipairs(rows or {}) do done[tonumber(r.slot)] = true end end
    return done
end

---------------------------------
-- webhook helpers
---------------------------------
local function suspicious(src, reason, details)
    local now = GetGameTimer()
    if lastAlert[src] and now - lastAlert[src] < ALERT_COOLDOWN then return end
    lastAlert[src] = now
    Webhook.Send('suspicious', {
        title = locale('wh_suspicious_title'),
        description = ('**%s**'):format(reason),
        src = src,
        alert = true,
        fields = details and { { name = locale('wh_details'), value = details } } or nil,
    })
end

-- a request the menu can never produce: log it, and optionally ban (Config.BanOnTamper)
local function tamper(src, reason, details)
    suspicious(src, reason, details)
    if Config.BanOnTamper then
        pcall(function() exports['rsg-core']:ExploitBan(src, 'rsg-fishmonger: ' .. tostring(reason)) end)
    end
end

local function cartBreakdown(lineCash, validated, mult)
    local lines = {}
    for item, qty in pairs(validated) do
        local fish = Config.Fish[item]
        lines[#lines + 1] = locale('wh_breakdown_line', qty, itemLabel(item), ('%.2f'):format((lineCash[item] or 0) * mult), fish and fish.fillets * qty or 0)
    end
    table.sort(lines)
    return table.concat(lines, '\n')
end

local function fail(key, ...)
    return { ok = false, message = locale(key, ...) }
end

---------------------------------
-- supplies shop: tiers unlock with the player's fishing level (each tier includes the ones below)
---------------------------------
local shopTiers = {}
local function buildShopTiers()
    shopTiers = {}
    local items = {}
    for _, it in ipairs(Config.Shop.items) do items[#items + 1] = it end
    shopTiers[1] = { level = 0, items = items }
    for _, tier in ipairs(Config.Shop.tiers or {}) do
        local merged = {}
        for _, it in ipairs(shopTiers[#shopTiers].items) do merged[#merged + 1] = it end
        for _, it in ipairs(tier.items or {}) do merged[#merged + 1] = it end
        shopTiers[#shopTiers + 1] = { level = tonumber(tier.level) or 0, items = merged }
    end
end

local function shopName(loc, tier) return 'fishmonger_' .. loc.key .. ((tier or 1) > 1 and ('_t' .. tier) or '') end

local function createShops()
    if not Config.Shop.enabled then return end
    buildShopTiers()
    for _, loc in ipairs(Config.Locations) do
        for i, tier in ipairs(shopTiers) do
            Inventory:CreateShop({
                name = shopName(loc, i),
                label = locale('shop_label', locName(loc)),
                coords = loc.coords,
                items = tier.items,
                persistentStock = Config.Shop.persistentStock,
            })
        end
    end
end

---------------------------------
-- item hints: "sells for about $x" added to each fish description
---------------------------------
local function applyItemHints()
    if not Config.ItemHints then return end
    for item, f in pairs(Config.Fish) do
        local shared = RSGCore.Shared.Items[item]
        if shared then
            local hint = locale('item_sell_hint', ('%.2f'):format(f.price))
            local desc = shared.description or ''
            if not desc:find(hint, 1, true) then
                local copy = {}
                for k, v in pairs(shared) do copy[k] = v end
                copy.description = desc ~= '' and (desc .. ' - ' .. hint) or hint
                pcall(function() exports['rsg-core']:UpdateItem(item, copy) end)
            end
        end
    end
end

---------------------------------
-- startup: validate config items + create shops
---------------------------------
CreateThread(function()
    local items, res = RSGCore.Shared.Items, GetCurrentResourceName()
    if not items[Config.FilletItem] then
        print(('^1[%s] Config.FilletItem "%s" does not exist in shared items^7'):format(res, Config.FilletItem))
    end
    for item, f in pairs(Config.Fish) do
        if not items[item] then
            print(('^3[%s] fish item "%s" is not in shared items and will be ignored^7'):format(res, item))
        end
        if f.fillet and not items[f.fillet] then
            print(('^1[%s] fillet item "%s" (for %s) does not exist in shared items^7'):format(res, f.fillet, item))
        end
    end
    if Config.FilletSale and Config.FilletSale.enabled then
        for item in pairs(Config.FilletSale.items or {}) do
            if not items[item] then print(('^3[%s] fillet sale item "%s" is not in shared items and will be ignored^7'):format(res, item)) end
        end
    end
    if Config.Shop.enabled then
        buildShopTiers()
        local seen = {}
        for _, tier in ipairs(shopTiers) do
            for _, it in ipairs(tier.items) do
                if not items[it.name] and not seen[it.name] then
                    seen[it.name] = true
                    print(('^3[%s] shop item "%s" is not in shared items and will be skipped^7'):format(res, it.name))
                end
            end
        end
    end
    createShops()
    applyItemHints()
end)

-- rebuild shops / hints if rsg-inventory or rsg-core restarts
AddEventHandler('onResourceStart', function(r)
    if r == 'rsg-inventory' then SetTimeout(1000, createShops) end
    if r == 'rsg-core' then SetTimeout(3000, applyItemHints) end
end)

---------------------------------
-- opening hours: tell every client when a town opens or closes (map blip colour)
---------------------------------
local function hoursSnapshot()
    local t = {}
    for i, loc in ipairs(Config.Locations) do t[i] = isOpen(loc) and true or false end
    return t
end

CreateThread(function()
    if not Config.OpeningHours.enabled then return end
    local last = ''
    while true do
        local snap = hoursSnapshot()
        local key = json.encode(snap)
        if key ~= last then
            last = key
            TriggerClientEvent('rsg-fishmonger:client:hours', -1, snap)
        end
        Wait(30000)
    end
end)

---------------------------------
-- checkout logic (sell / process)
---------------------------------
local function checkout(src, locationIndex, mode, cart)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return fail('sv_no_player') end
    if mode ~= 'sell' and mode ~= 'process' then
        tamper(src, locale('wh_invalid_mode'), ('mode = `%s`'):format(tostring(mode)))
        return fail('sv_failed')
    end
    local near, dist, loc = isNearLocation(src, locationIndex)
    if not near then
        suspicious(src, locale('wh_not_at_location'), loc
            and locale('wh_distance_info', locName(loc), dist and ('%.1f'):format(dist) or locale('wh_unknown'), ('%.1f'):format(Config.MaxUseDistance))
            or locale('wh_invalid_location', tostring(locationIndex)))
        return fail('sv_too_far')
    end
    local open, oh, ch = isOpen(loc)
    if not open then return fail('sv_closed', oh, ch) end
    if type(cart) ~= 'table' then
        tamper(src, locale('wh_malformed_cart'), ('cart type = `%s`'):format(type(cart)))
        return fail('sv_cart_empty')
    end
    -- a real cart never has more lines than there are sellable items; stops oversized tables burning server time
    local lines = 0
    for _ in pairs(cart) do
        lines = lines + 1
        if lines > maxCartLines then
            tamper(src, locale('wh_malformed_cart'), ('cart lines > %d'):format(maxCartLines))
            return fail('sv_failed')
        end
    end

    -- validate cart against config + shared items + real inventory
    local stacksBy = inventoryStacks(Player)
    local validated, plan, lineCash, rejected = {}, {}, {}, {}
    local totalFish, totalPieces, totalCash = 0, 0, 0
    local fillets, totalFillets = {}, 0 -- [filletItem] = amount
    for item, rawQty in pairs(cart) do
        local fish = type(item) == 'string' and Config.Fish[item] or nil
        local fPrice = type(item) == 'string' and not fish and filletPrice(item) or nil
        local qty = math.tointeger(tonumber(rawQty)) or 0
        if not ((fish or fPrice) and RSGCore.Shared.Items[item] and qty > 0 and qty <= MAX_QTY_PER_FISH) then
            rejected[#rejected + 1] = ('`%s` x `%s`'):format(tostring(item):sub(1, 50), tostring(rawQty):sub(1, 20))
        else
            if fPrice and mode == 'process' then return fail('sv_failed') end -- fillets can only be sold
            local picks, units, enough = planPicks(stacksBy, item, qty)
            if not enough then
                local have = 0
                for _, st in ipairs(stacksBy[item] or {}) do have = have + st.amount end
                suspicious(src, locale('wh_more_than_owned'), locale('wh_owned_info', itemLabel(item), qty, have))
                return fail('sv_not_enough', itemLabel(item))
            end
            validated[item] = qty
            plan[item] = picks
            totalPieces = totalPieces + qty
            lineCash[item] = (fish and fish.price or fPrice) * units
            totalCash = totalCash + lineCash[item]
            if fish then
                totalFish = totalFish + qty
                local fi = FishmongerFillet(item)
                fillets[fi] = (fillets[fi] or 0) + fish.fillets * qty
                totalFillets = totalFillets + fish.fillets * qty
            end
        end
    end
    if #rejected > 0 then
        tamper(src, locale('wh_invalid_entries'), table.concat(rejected, '\n', 1, math.min(#rejected, 20)))
    end
    if totalPieces == 0 then return fail('sv_cart_empty') end

    local mult = 1.0
    local econQuote = nil
    if mode == 'sell' then
        if totalFish > 0 and Config.DailyStock.enabled and not dbReady then return fail('sv_wait') end
        local left = stockLeft(loc)
        if left and totalFish > left then
            return left > 0 and fail('sv_stock_left', left) or fail('sv_stock_full')
        end
        mult = demandFor(loc) * (1 + bonusFor(Player))
        totalCash = round2(totalCash * mult)
        -- rsg-economy (optional): town tax + standing price modifier on the final payout
        econQuote = economyQuote(src, loc, totalCash)
        if econQuote then totalCash = round2(econQuote.total) end
    end

    -- remove fish (rollback on any failure)
    local removed, added = {}, {}
    local function rollback()
        for aItem, aQty in pairs(added) do Inventory:RemoveItem(src, aItem, aQty, nil, 'fishmonger-rollback') end
        restoreFish(src, removed)
    end
    local okRemove
    okRemove, removed = removePicks(src, plan, 'fishmonger-' .. mode)
    if not okRemove then
        rollback()
        Webhook.Send('errors', { title = locale('wh_removal_failed_title'), src = src, description = locale('wh_removal_failed', totalPieces, 'cart') })
        return fail('sv_failed')
    end

    if mode == 'process' then
        -- space is checked after removal so the weight freed by the fish counts
        for fi, amt in pairs(fillets) do
            if not Inventory:CanAddItem(src, fi, amt) or not Inventory:AddItem(src, fi, amt, nil, nil, 'fishmonger-process') then
                rollback()
                return fail('sv_no_space')
            end
            added[fi] = amt
        end
    else
        if not Player.Functions.AddMoney(Config.MoneyType, totalCash, 'fishmonger-sale') then
            rollback()
            Webhook.Send('errors', { title = locale('wh_payout_failed_title'), src = src, description = locale('wh_payout_failed', Config.MoneyType, ('%.2f'):format(totalCash)) })
            return fail('sv_failed')
        end
        if econQuote then pcall(function() exports['rsg-economy']:Record(src, econQuote) end) end -- money moved: bank the tax
        if totalFish > 0 and stockLeft(loc) then addSold(loc, totalFish) end
    end
    addRep(Player, totalFish)

    local filletLines = {}
    for fi, amt in pairs(fillets) do filletLines[#filletLines + 1] = ('%d x %s'):format(amt, itemLabel(fi)) end
    local summary = {
        { name = locale('wh_location'), value = locName(loc), inline = true },
        { name = locale('wh_total_fish'), value = tostring(totalPieces), inline = true },
        mode == 'sell'
            and { name = locale('wh_paid'), value = ('$%.2f (%s, x%.2f)'):format(totalCash, Config.MoneyType, mult), inline = true }
            or { name = locale('wh_fillets_given'), value = table.concat(filletLines, '\n'), inline = true },
        { name = locale('wh_breakdown'), value = cartBreakdown(lineCash, validated, mult) },
    }
    Webhook.Send(mode == 'sell' and 'sales' or 'processing', {
        title = locale(mode == 'sell' and 'wh_sold_title' or 'wh_processed_title'), src = src, fields = summary,
    })
    local W = SvConfig.Webhooks
    if (mode == 'sell' and W.largeSaleAlert > 0 and totalCash >= W.largeSaleAlert)
        or (mode == 'process' and W.largeProcessAlert > 0 and totalFish >= W.largeProcessAlert) then
        Webhook.Send('suspicious', {
            title = locale(mode == 'sell' and 'wh_large_sale_title' or 'wh_large_process_title'),
            description = locale('wh_large_desc'), src = src, alert = true, fields = summary,
        })
    end

    if mode == 'process' then
        return { ok = true, message = locale('sv_processed', totalFish, totalFillets) }
    end
    return { ok = true, message = locale('sv_sold', totalPieces, ('%.2f'):format(totalCash)) }
end

---------------------------------
-- deliver a daily order
---------------------------------
local function deliverOrder(src, locationIndex, slot)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return fail('sv_no_player') end
    local near, dist, loc = isNearLocation(src, locationIndex)
    if not near then
        suspicious(src, locale('wh_not_at_location'), loc
            and locale('wh_distance_info', locName(loc), dist and ('%.1f'):format(dist) or locale('wh_unknown'), ('%.1f'):format(Config.MaxUseDistance))
            or locale('wh_invalid_location', tostring(locationIndex)))
        return fail('sv_too_far')
    end
    local open, oh, ch = isOpen(loc)
    if not open then return fail('sv_closed', oh, ch) end

    slot = math.tointeger(tonumber(slot))
    local order = slot and contractsFor(loc)[slot]
    if not order then return fail('sv_order_invalid') end
    if doneSlots(Player, loc)[slot] then return fail('sv_order_already') end

    local picks, _, enough = planPicks(inventoryStacks(Player), order.item, order.qty)
    if not enough then return fail('sv_not_enough', itemLabel(order.item)) end

    -- mark it done first so it can never be claimed twice; undone again if anything below fails
    local cid = Player.PlayerData.citizenid
    MySQL.query.await('INSERT INTO rsg_fishmonger_orders (`citizenid`, `location`, `slot`, `day`) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE `day` = VALUES(`day`)', { cid, loc.key, slot, today() })
    local function undo()
        MySQL.query.await('DELETE FROM rsg_fishmonger_orders WHERE `citizenid` = ? AND `location` = ? AND `slot` = ?', { cid, loc.key, slot })
    end

    local ok, removed = removePicks(src, { [order.item] = picks }, 'fishmonger-order')
    if not ok then
        restoreFish(src, removed)
        undo()
        Webhook.Send('errors', { title = locale('wh_removal_failed_title'), src = src, description = locale('wh_removal_failed', order.qty, order.item) })
        return fail('sv_failed')
    end
    if not Player.Functions.AddMoney(Config.MoneyType, order.reward, 'fishmonger-order') then
        restoreFish(src, removed)
        undo()
        Webhook.Send('errors', { title = locale('wh_payout_failed_title'), src = src, description = locale('wh_payout_failed', Config.MoneyType, ('%.2f'):format(order.reward)) })
        return fail('sv_failed')
    end

    local cfg = Config.Contracts
    if (cfg.repReward or 0) > 0 then pcall(Player.Functions.AddRep, Config.Bonus.rep.name, cfg.repReward) end
    if (cfg.xpReward or 0) > 0 and GetResourceState('rsg-skills') == 'started' then
        pcall(function() exports['rsg-skills']:AddXP(src, (Config.Shop and Config.Shop.skill) or 'fishing', cfg.xpReward, 'fishmonger-order') end)
    end
    Webhook.Send('sales', {
        title = locale('wh_order_title'), src = src,
        fields = {
            { name = locale('wh_location'), value = locName(loc), inline = true },
            { name = locale('wh_total_fish'), value = ('%dx %s'):format(order.qty, itemLabel(order.item)), inline = true },
            { name = locale('wh_paid'), value = ('$%.2f (%s)'):format(order.reward, Config.MoneyType), inline = true },
        },
    })
    return { ok = true, message = locale('sv_order_done', ('%.2f'):format(order.reward)) }
end

---------------------------------
-- callbacks
---------------------------------
-- everything the menu needs; also used to refresh after a failed trade
RSGCore.Functions.CreateCallback('rsg-fishmonger:server:getMenuData', function(source, cb, locationIndex)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    local near, _, loc = isNearLocation(source, locationIndex)
    if not near then return cb({ denied = true, message = locale('sv_too_far') }) end
    local open, oh, ch = isOpen(loc)
    if not open then return cb({ denied = true, message = locale('sv_closed', oh, ch) }) end

    -- counts per item, plus each fish's quality multiplier in the order it would be sold (so the menu preview is exact)
    local counts, stacks = {}, {}
    for name, list in pairs(inventoryStacks(Player)) do
        local total, comp = 0, {}
        for _, st in ipairs(list) do
            total = total + st.amount
            if Config.Fish[name] then
                local m, last = round4(unitMult(st.info)), comp[#comp]
                if last and last.m == m then last.n = last.n + st.amount else comp[#comp + 1] = { n = st.amount, m = m } end
            end
        end
        counts[name] = total
        if #comp > 0 then stacks[name] = comp end
    end

    local orders = {}
    local done = doneSlots(Player, loc)
    for _, o in ipairs(contractsFor(loc)) do
        orders[#orders + 1] = { slot = o.slot, item = o.item, qty = o.qty, reward = o.reward, done = done[o.slot] == true }
    end

    cb({
        counts = counts,
        stacks = stacks,
        orders = orders,
        demand = demandFor(loc),
        bonus = bonusFor(Player),
        econ = economyFactor(source, loc),
        stockLeft = stockLeft(loc) or -1, -- -1 = unlimited (nil would drop the key)
    })
end)

-- one trade at a time per player, with a cooldown; pcall so an unexpected error can never leave the player locked as busy
local function runLocked(src, fn, ...)
    local now = GetGameTimer()
    if busy[src] or (lastUse[src] and now - lastUse[src] < Config.Cooldown) then
        spamHits[src] = (spamHits[src] or 0) + 1
        if spamHits[src] == SPAM_ALERT_AT then
            suspicious(src, locale('wh_spam'), locale('wh_spam_info', SPAM_ALERT_AT, Config.Cooldown))
        end
        return fail('sv_wait')
    end
    if lastUse[src] and now - lastUse[src] > Config.Cooldown * 10 then spamHits[src] = nil end
    busy[src], lastUse[src] = true, now

    local ok, res = pcall(fn, src, ...)
    busy[src] = nil
    if not ok then
        print(('^1[%s] checkout error for %s: %s^7'):format(GetCurrentResourceName(), src, res))
        Webhook.Send('errors', { title = locale('wh_error_title'), src = src, description = ('```%s```'):format(tostring(res)) })
        return fail('sv_failed')
    end
    return res
end

RSGCore.Functions.CreateCallback('rsg-fishmonger:server:checkout', function(source, cb, locationIndex, mode, cart)
    cb(runLocked(source, checkout, locationIndex, mode, cart))
end)

RSGCore.Functions.CreateCallback('rsg-fishmonger:server:deliverOrder', function(source, cb, locationIndex, slot)
    cb(runLocked(source, deliverOrder, locationIndex, slot))
end)

RSGCore.Functions.CreateCallback('rsg-fishmonger:server:getHours', function(_, cb)
    cb(hoursSnapshot())
end)

---------------------------------
-- supplies shop
---------------------------------
RegisterNetEvent('rsg-fishmonger:server:openShop', function(locationIndex)
    local src = source
    if not Config.Shop.enabled or not RSGCore.Functions.GetPlayer(src) then return end
    local now = GetGameTimer()
    if lastShop[src] and now - lastShop[src] < 1000 then return end
    lastShop[src] = now
    local near, _, loc = isNearLocation(src, locationIndex)
    if not near then return end
    local open, oh, ch = isOpen(loc)
    if not open then
        return TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('cl_title'), description = locale('sv_closed', oh, ch), type = 'error', duration = 5000 })
    end
    if #shopTiers == 0 then buildShopTiers() end

    -- highest tier this player's fishing level unlocks
    local level, tier = fishingLevel(src), 1
    for i, t in ipairs(shopTiers) do
        if level >= t.level then tier = i end
    end
    if not Inventory:DoesShopExist(shopName(loc, tier)) then createShops() end
    Inventory:OpenShop(src, shopName(loc, tier))
    local nextTier = shopTiers[tier + 1]
    if nextTier then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('cl_title'), description = locale('sv_shop_next_tier', nextTier.level), type = 'inform', duration = 5000, icon = 'fa-solid fa-fish' })
    end
end)

AddEventHandler('playerDropped', function()
    busy[source], lastUse[source], spamHits[source], lastShop[source], lastAlert[source] = nil, nil, nil, nil, nil
end)
