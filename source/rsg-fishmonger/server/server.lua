local RSGCore = exports['rsg-core']:GetCoreObject()

local Inventory = exports['rsg-inventory']
local busy, lastUse, spamHits = {}, {}, {}
local SPAM_ALERT_AT = 5 -- blocked requests before a spam alert is logged
local MAX_QTY_PER_FISH = 1000

---------------------------------
-- helpers
---------------------------------
local function round2(n) return math.floor(n * 100 + 0.5) / 100 end
local function today() return os.date('%Y-%m-%d') end

local function itemLabel(item)
    local data = RSGCore.Shared.Items[item]
    return data and data.label or item
end

local function locName(loc) return locale('loc_' .. loc.key) end
local function shopName(loc) return 'fishmonger_' .. loc.key end

local function countItem(Player, itemName)
    local total = 0
    for _, item in pairs(Player.PlayerData.items or {}) do
        if item and item.name == itemName then total = total + (tonumber(item.amount) or 0) end
    end
    return total
end

local function getFishCounts(Player)
    local counts = {}
    for item in pairs(Config.Fish) do counts[item] = countItem(Player, item) end
    return counts
end

-- returns near, distance, location
local function isNearLocation(src, index)
    local loc = Config.Locations[tonumber(index) or 0]
    if not loc then return false, nil, nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, nil, loc end
    local dist = #(GetEntityCoords(ped) - loc.coords.xyz)
    return dist <= Config.MaxUseDistance, dist, loc
end

-- in-game hour from rsg-weather (nil = unknown, treated as open)
local function currentHour()
    if not Config.OpeningHours.enabled or GetResourceState('rsg-weather') ~= 'started' then return nil end
    local ok, t = pcall(function() return exports['rsg-weather']:getTime() end)
    return ok and type(t) == 'table' and t.hour or nil
end

local function isOpen(loc)
    return FishmongerIsOpen(loc, currentHour())
end

---------------------------------
-- daily demand (deterministic per town per real day, no storage needed)
---------------------------------
local function demandFor(loc)
    local cfg = Config.Demand
    if not cfg.enabled or loc.demand == false then return 1.0 end
    local seed, h = today() .. loc.key, 7
    for i = 1, #seed do h = (h * 31 + seed:byte(i)) % 2147483647 end
    local r = (h % 10007) / 10006
    return round2(cfg.min + (cfg.max - cfg.min) * r)
end

---------------------------------
-- seller bonus (job + reputation)
---------------------------------
local function bonusFor(Player)
    local b, cfg = 0, Config.Bonus
    local job = Player.PlayerData.job
    if job and cfg.jobs[job.name] then b = b + cfg.jobs[job.name] end
    if cfg.rep.enabled then
        b = b + math.min(cfg.rep.max, (Player.Functions.GetRep(cfg.rep.name) or 0) * cfg.rep.perPoint)
    end
    return round2(b)
end

---------------------------------
-- daily stock (resource KVP, survives restarts, resets each real day)
---------------------------------
local function stockKey(loc) return 'stock:' .. loc.key end

local function getSold(loc)
    local raw = GetResourceKvpString(stockKey(loc))
    if not raw then return 0 end
    local ok, d = pcall(json.decode, raw)
    if ok and type(d) == 'table' and d.day == today() then return tonumber(d.sold) or 0 end
    return 0
end

local function addSold(loc, n)
    SetResourceKvp(stockKey(loc), json.encode({ day = today(), sold = getSold(loc) + n }))
end

-- nil = unlimited
local function stockLeft(loc)
    if not Config.DailyStock.enabled then return nil end
    local cap = loc.stock or Config.DailyStock.perLocation
    if not cap or cap <= 0 then return nil end
    return math.max(0, cap - getSold(loc))
end

local function addRep(Player, fish)
    local rep = Config.Bonus.rep
    if rep.enabled and rep.gainPerFish > 0 then Player.Functions.AddRep(rep.name, fish * rep.gainPerFish) end
end

---------------------------------
-- webhook helpers
---------------------------------
local function suspicious(src, reason, details)
    Webhook.Send('suspicious', {
        title = locale('wh_suspicious_title'),
        description = ('**%s**'):format(reason),
        src = src,
        alert = true,
        fields = details and { { name = locale('wh_details'), value = details } } or nil,
    })
end

local function cartBreakdown(validated, mult)
    local lines = {}
    for item, qty in pairs(validated) do
        local f = Config.Fish[item]
        lines[#lines + 1] = locale('wh_breakdown_line', qty, itemLabel(item), ('%.2f'):format(f.price * mult * qty), f.fillets * qty)
    end
    table.sort(lines)
    return table.concat(lines, '\n')
end

local function fail(key, ...)
    return { ok = false, message = locale(key, ...) }
end

---------------------------------
-- startup: validate config items + create shops
---------------------------------
local function createShops()
    if not Config.Shop.enabled then return end
    for _, loc in ipairs(Config.Locations) do
        Inventory:CreateShop({
            name = shopName(loc),
            label = locale('shop_label', locName(loc)),
            coords = loc.coords,
            items = Config.Shop.items,
            persistentStock = Config.Shop.persistentStock,
        })
    end
end

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
    if Config.Shop.enabled then
        for _, it in ipairs(Config.Shop.items) do
            if not items[it.name] then print(('^3[%s] shop item "%s" is not in shared items and will be skipped^7'):format(res, it.name)) end
        end
    end
    createShops()
end)

-- rebuild shops if rsg-inventory restarts
AddEventHandler('onResourceStart', function(r)
    if r == 'rsg-inventory' then SetTimeout(1000, createShops) end
end)

---------------------------------
-- checkout logic
---------------------------------
local function checkout(src, locationIndex, mode, cart)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return fail('sv_no_player') end
    if mode ~= 'sell' and mode ~= 'process' then
        suspicious(src, locale('wh_invalid_mode'), ('mode = `%s`'):format(tostring(mode)))
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
        suspicious(src, locale('wh_malformed_cart'), ('cart type = `%s`'):format(type(cart)))
        return fail('sv_cart_empty')
    end

    -- validate cart against config + shared items + real inventory
    local validated, rejected, totalFish, totalCash = {}, {}, 0, 0
    local fillets, totalFillets = {}, 0 -- [filletItem] = amount
    for item, rawQty in pairs(cart) do
        local fish = type(item) == 'string' and Config.Fish[item]
        local qty = math.tointeger(tonumber(rawQty)) or 0
        if not (fish and RSGCore.Shared.Items[item] and qty > 0 and qty <= MAX_QTY_PER_FISH) then
            rejected[#rejected + 1] = ('`%s` x `%s`'):format(tostring(item):sub(1, 50), tostring(rawQty):sub(1, 20))
        else
            local have = countItem(Player, item)
            if have < qty then
                suspicious(src, locale('wh_more_than_owned'), locale('wh_owned_info', itemLabel(item), qty, have))
                return fail('sv_not_enough', itemLabel(item))
            end
            validated[item] = qty
            totalFish = totalFish + qty
            totalCash = totalCash + fish.price * qty
            local fi = FishmongerFillet(item)
            fillets[fi] = (fillets[fi] or 0) + fish.fillets * qty
            totalFillets = totalFillets + fish.fillets * qty
        end
    end
    if #rejected > 0 then
        suspicious(src, locale('wh_invalid_entries'), table.concat(rejected, '\n', 1, math.min(#rejected, 20)))
    end
    if totalFish == 0 then return fail('sv_cart_empty') end

    local mult = 1.0
    if mode == 'sell' then
        local left = stockLeft(loc)
        if left and totalFish > left then
            return left > 0 and fail('sv_stock_left', left) or fail('sv_stock_full')
        end
        mult = demandFor(loc) * (1 + bonusFor(Player))
        totalCash = round2(totalCash * mult)
    end

    -- remove fish (rollback on any failure)
    local removed, added = {}, {}
    local function rollback()
        for aItem, aQty in pairs(added) do Inventory:RemoveItem(src, aItem, aQty, nil, 'fishmonger-rollback') end
        for rItem, rQty in pairs(removed) do Inventory:AddItem(src, rItem, rQty, nil, nil, 'fishmonger-rollback') end
    end
    for item, qty in pairs(validated) do
        if not Inventory:RemoveItem(src, item, qty, nil, 'fishmonger-' .. mode) then
            rollback()
            Webhook.Send('errors', { title = locale('wh_removal_failed_title'), src = src, description = locale('wh_removal_failed', qty, item) })
            return fail('sv_failed')
        end
        removed[item] = qty
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
        if stockLeft(loc) then addSold(loc, totalFish) end
    end
    addRep(Player, totalFish)

    local filletLines = {}
    for fi, amt in pairs(fillets) do filletLines[#filletLines + 1] = ('%d x %s'):format(amt, itemLabel(fi)) end
    local summary = {
        { name = locale('wh_location'), value = locName(loc), inline = true },
        { name = locale('wh_total_fish'), value = tostring(totalFish), inline = true },
        mode == 'sell'
            and { name = locale('wh_paid'), value = ('$%.2f (%s, x%.2f)'):format(totalCash, Config.MoneyType, mult), inline = true }
            or { name = locale('wh_fillets_given'), value = table.concat(filletLines, '\n'), inline = true },
        { name = locale('wh_breakdown'), value = cartBreakdown(validated, mult) },
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
    return { ok = true, message = locale('sv_sold', totalFish, ('%.2f'):format(totalCash)) }
end

---------------------------------
-- callbacks
---------------------------------
-- everything the menu needs; also used to refresh after a failed trade
RSGCore.Functions.CreateCallback('rsg-fishmonger:server:getMenuData', function(source, cb, locationIndex)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    local near, _, loc = isNearLocation(source, locationIndex)
    if not near then return cb(nil) end
    local open, oh, ch = isOpen(loc)
    if not open then return cb({ closed = true, message = locale('sv_closed', oh, ch) }) end
    cb({
        counts = getFishCounts(Player),
        demand = demandFor(loc),
        bonus = bonusFor(Player),
        stockLeft = stockLeft(loc) or -1, -- -1 = unlimited (nil would drop the key)
    })
end)

RSGCore.Functions.CreateCallback('rsg-fishmonger:server:checkout', function(source, cb, locationIndex, mode, cart)
    local src = source
    local now = GetGameTimer()
    if busy[src] or (lastUse[src] and now - lastUse[src] < Config.Cooldown) then
        spamHits[src] = (spamHits[src] or 0) + 1
        if spamHits[src] == SPAM_ALERT_AT then
            suspicious(src, locale('wh_spam'), locale('wh_spam_info', SPAM_ALERT_AT, Config.Cooldown))
        end
        return cb(fail('sv_wait'))
    end
    if lastUse[src] and now - lastUse[src] > Config.Cooldown * 10 then spamHits[src] = nil end
    busy[src], lastUse[src] = true, now

    -- pcall so an unexpected error can never leave the player locked as busy
    local ok, res = pcall(checkout, src, locationIndex, mode, cart)
    busy[src] = nil
    if not ok then
        print(('^1[%s] checkout error for %s: %s^7'):format(GetCurrentResourceName(), src, res))
        Webhook.Send('errors', { title = locale('wh_error_title'), src = src, description = ('```%s```'):format(tostring(res)) })
        return cb(fail('sv_failed'))
    end
    cb(res)
end)

---------------------------------
-- supplies shop
---------------------------------
RegisterNetEvent('rsg-fishmonger:server:openShop', function(locationIndex)
    local src = source
    if not Config.Shop.enabled or not RSGCore.Functions.GetPlayer(src) then return end
    local near, _, loc = isNearLocation(src, locationIndex)
    if not near then return end
    local open, oh, ch = isOpen(loc)
    if not open then
        return TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('cl_title'), description = locale('sv_closed', oh, ch), type = 'error', duration = 5000 })
    end
    if not Inventory:DoesShopExist(shopName(loc)) then createShops() end
    Inventory:OpenShop(src, shopName(loc))
end)

AddEventHandler('playerDropped', function()
    busy[source], lastUse[source], spamHits[source] = nil, nil, nil
end)
