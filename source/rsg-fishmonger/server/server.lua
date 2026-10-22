local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Inventory = exports['rsg-inventory']
local busy, lastUse, spamHits = {}, {}, {}
local SPAM_ALERT_AT = 5 -- blocked requests before a spam alert is logged
local MAX_QTY_PER_FISH = 1000

---------------------------------
-- startup: validate config items exist
---------------------------------
CreateThread(function()
    local items = RSGCore.Shared.Items
    if not items[Config.FilletItem] then
        print(('^1[%s] Config.FilletItem "%s" does not exist in shared items^7'):format(GetCurrentResourceName(), Config.FilletItem))
    end
    for item in pairs(Config.Fish) do
        if not items[item] then
            print(('^3[%s] fish item "%s" is not in shared items and will be ignored^7'):format(GetCurrentResourceName(), item))
        end
    end
end)

---------------------------------
-- helpers
---------------------------------
local function countItem(Player, itemName)
    local total = 0
    for _, item in pairs(Player.PlayerData.items or {}) do
        if item and item.name == itemName then
            total = total + (tonumber(item.amount) or 0)
        end
    end
    return total
end

local function getFishCounts(Player)
    local counts = {}
    for item in pairs(Config.Fish) do
        counts[item] = countItem(Player, item)
    end
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

local function itemLabel(item)
    local data = RSGCore.Shared.Items[item]
    return data and data.label or item
end

local function locName(loc)
    return locale('loc_' .. loc.key)
end

local function suspicious(src, reason, details)
    Webhook.Send('suspicious', {
        title = locale('wh_suspicious_title'),
        description = ('**%s**'):format(reason),
        src = src,
        alert = true,
        fields = details and { { name = locale('wh_details'), value = details } } or nil,
    })
end

local function cartBreakdown(validated)
    local lines = {}
    for item, qty in pairs(validated) do
        local f = Config.Fish[item]
        lines[#lines + 1] = locale('wh_breakdown_line', qty, itemLabel(item), ('%.2f'):format(f.price * qty), f.fillets * qty)
    end
    table.sort(lines)
    return table.concat(lines, '\n')
end

local function round2(n)
    return math.floor(n * 100 + 0.5) / 100
end

local function itemBox(src, item, action, qty)
    local data = RSGCore.Shared.Items[item]
    if data then TriggerClientEvent('rsg-inventory:client:ItemBox', src, data, action, qty) end
end

local function fail(key, ...)
    return { ok = false, message = locale(key, ...) }
end

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
    if type(cart) ~= 'table' then
        suspicious(src, locale('wh_malformed_cart'), ('cart type = `%s`'):format(type(cart)))
        return fail('sv_cart_empty')
    end

    -- validate cart against config + shared items + real inventory
    local validated, rejected, totalFish, totalCash, totalFillets = {}, {}, 0, 0, 0
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
            totalFillets = totalFillets + fish.fillets * qty
        end
    end
    if #rejected > 0 then
        suspicious(src, locale('wh_invalid_entries'), table.concat(rejected, '\n', 1, math.min(#rejected, 20)))
    end
    if totalFish == 0 then return fail('sv_cart_empty') end

    -- remove fish (rollback on any failure)
    local removed = {}
    local function rollback()
        for rItem, rQty in pairs(removed) do
            Inventory:AddItem(src, rItem, rQty, nil, nil, 'fishmonger-rollback')
        end
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
        if not Inventory:CanAddItem(src, Config.FilletItem, totalFillets)
            or not Inventory:AddItem(src, Config.FilletItem, totalFillets, nil, nil, 'fishmonger-process') then
            rollback()
            return fail('sv_no_space')
        end
    else
        totalCash = round2(totalCash)
        if not Player.Functions.AddMoney(Config.MoneyType, totalCash, 'fishmonger-sale') then
            rollback()
            Webhook.Send('errors', { title = locale('wh_payout_failed_title'), src = src, description = locale('wh_payout_failed', Config.MoneyType, ('%.2f'):format(totalCash)) })
            return fail('sv_failed')
        end
    end

    for item, qty in pairs(removed) do itemBox(src, item, 'remove', qty) end

    local summary = {
        { name = locale('wh_location'), value = locName(loc), inline = true },
        { name = locale('wh_total_fish'), value = tostring(totalFish), inline = true },
        mode == 'sell'
            and { name = locale('wh_paid'), value = ('$%.2f (%s)'):format(totalCash, Config.MoneyType), inline = true }
            or { name = locale('wh_fillets_given'), value = ('%d x %s'):format(totalFillets, itemLabel(Config.FilletItem)), inline = true },
        { name = locale('wh_breakdown'), value = cartBreakdown(validated) },
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
        itemBox(src, Config.FilletItem, 'add', totalFillets)
        return { ok = true, message = locale('sv_processed', totalFish, totalFillets) }
    end
    return { ok = true, message = locale('sv_sold', totalFish, ('%.2f'):format(totalCash)) }
end

---------------------------------
-- callbacks
---------------------------------
lib.callback.register('rsg-fishmonger:server:getFishCounts', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return nil end
    return getFishCounts(Player)
end)

lib.callback.register('rsg-fishmonger:server:checkout', function(source, locationIndex, mode, cart)
    local src = source
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

    -- pcall so an unexpected error can never leave the player locked as busy
    local ok, res = pcall(checkout, src, locationIndex, mode, cart)
    busy[src] = nil
    if not ok then
        print(('^1[%s] checkout error for %s: %s^7'):format(GetCurrentResourceName(), src, res))
        Webhook.Send('errors', { title = locale('wh_error_title'), src = src, description = ('```%s```'):format(tostring(res)) })
        return fail('sv_failed')
    end
    return res
end)

AddEventHandler('playerDropped', function()
    busy[source], lastUse[source], spamHits[source] = nil, nil, nil
end)
