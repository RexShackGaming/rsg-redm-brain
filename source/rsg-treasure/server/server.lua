local RSGCore = exports['rsg-core']:GetCoreObject()

local hunts = {}      -- [citizenid] = { idx = location index, centre = vector3, digStart = ms }
local cooldown = {}   -- [src] = os.time() of last payout attempt

local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('title'), description = desc, type = ntype or 'inform', duration = 5000 })
end

local function pickLocation()
    local taken = {}
    for _, h in pairs(hunts) do taken[h.idx] = true end
    local free = {}
    for i = 1, #Config.Locations do
        if not taken[i] then free[#free + 1] = i end
    end
    if #free == 0 then return math.random(#Config.Locations) end
    return free[math.random(#free)]
end

-- offset circle centre so the exact spot is somewhere inside it
local function circleCentre(loc)
    local r = Config.SearchRadius * 0.6 * math.sqrt(math.random())
    local a = math.random() * 2 * math.pi
    return vector3(loc.x + r * math.cos(a), loc.y + r * math.sin(a), loc.z)
end

local function playerDist(src, hunt)
    local ppos = GetEntityCoords(GetPlayerPed(src))
    return #(ppos - Config.Locations[hunt.idx]), ppos
end

-- checks shared by dig start and payout; returns true or false after notifying the player
local function canDig(src, hunt)
    if not exports['rsg-inventory']:HasItem(src, Config.MapItem, 1) then
        notify(src, locale('no_map'), 'error')
        return false
    end
    if not exports['rsg-inventory']:HasItem(src, Config.DetectorItem, 1) then
        notify(src, locale('need_detector'), 'error')
        return false
    end
    if Config.RequiredItem and not exports['rsg-inventory']:HasItem(src, Config.RequiredItem, 1) then
        local item = RSGCore.Shared.Items[Config.RequiredItem]
        notify(src, locale('need_tool', item and item.label or Config.RequiredItem), 'error')
        return false
    end
    return true
end

RSGCore.Functions.CreateUseableItem(Config.MapItem, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid

    local hunt = hunts[cid]
    if hunt then
        -- same circle every time, so re-using the map can't be used to triangulate the spot
        notify(src, locale('hunt_active'), 'warning')
        TriggerClientEvent('rsg-treasure:client:startHunt', src, Config.Locations[hunt.idx], hunt.centre)
        SendLog('Hunts', locale('log_reopen_title'), locale('log_reopen_desc'), 'hunt', src,
            { { name = locale('log_location'), value = tostring(hunt.idx), inline = true } })
        return
    end

    local idx = pickLocation()
    local loc = Config.Locations[idx]
    hunts[cid] = { idx = idx, centre = circleCentre(loc) }
    TriggerClientEvent('rsg-treasure:client:startHunt', src, loc, hunts[cid].centre)
    notify(src, locale('hunt_started'), 'success')
    SendLog('Hunts', locale('log_start_title'), locale('log_start_desc'), 'hunt', src, {
        { name = locale('log_location'), value = tostring(idx), inline = true },
        { name = locale('log_spot'), value = ('%.2f, %.2f, %.2f'):format(loc.x, loc.y, loc.z), inline = true },
    })
end)

-- restore the search circle after a relog / resource restart
RegisterNetEvent('rsg-treasure:server:resume', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local hunt = hunts[Player.PlayerData.citizenid]
    if hunt then TriggerClientEvent('rsg-treasure:client:startHunt', src, Config.Locations[hunt.idx], hunt.centre) end
end)

-- client asks before the dig anim: everything is checked up front so the player
-- never sits through the full dig only to be refused. Starts the server-side dig timer.
RSGCore.Functions.CreateCallback('rsg-treasure:server:digStart', function(src, cb)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end
    local hunt = hunts[Player.PlayerData.citizenid]
    if not hunt then return cb(false) end
    if playerDist(src, hunt) > Config.DigDistance + 1.0 then
        notify(src, locale('too_far'), 'error')
        return cb(false)
    end
    if not canDig(src, hunt) then return cb(false) end
    hunt.digStart = GetGameTimer()
    cb(true)
end)

-- roll loot and make sure all of it fits before anything is taken or given
local function rollLoot(src)
    local loot = {}
    for _, r in ipairs(Config.Rewards) do
        local itemData = RSGCore.Shared.Items[r.item]
        if itemData and math.random(100) <= r.chance then
            local amount = math.random(r.min, r.max)
            if not exports['rsg-inventory']:CanAddItem(src, r.item, amount) then return nil end
            loot[#loot + 1] = { item = r.item, amount = amount, data = itemData }
        end
    end
    return loot
end

-- answers true when the treasure was paid out, false otherwise (client then reburies the box)
RSGCore.Functions.CreateCallback('rsg-treasure:server:dig', function(src, cb)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end
    local cid = Player.PlayerData.citizenid

    local now = os.time()
    if cooldown[src] and now - cooldown[src] < Config.Cooldown then
        notify(src, locale('slow_down'), 'error')
        SendLog('Security', locale('log_spam_title'), locale('log_spam_desc'), 'warn', src)
        return cb(false)
    end
    cooldown[src] = now

    local hunt = hunts[cid]
    if not hunt then
        notify(src, locale('no_hunt'), 'error')
        TriggerClientEvent('rsg-treasure:client:endHunt', src)
        SendLog('Security', locale('log_nohunt_title'), locale('log_nohunt_desc'), 'alert', src)
        return cb(false)
    end

    -- must have started digging and stayed for (most of) the dig, so the callback can't be fired directly
    local started = hunt.digStart
    hunt.digStart = nil
    if not started or GetGameTimer() - started < Config.DigTime - 1500 then
        notify(src, locale('too_fast'), 'error')
        SendLog('Security', locale('log_fast_title'), locale('log_fast_desc'), 'alert', src)
        return cb(false)
    end

    local dist, ppos = playerDist(src, hunt)
    if dist > Config.DigDistance + 1.0 then
        notify(src, locale('too_far'), 'error')
        SendLog('Security', locale('log_far_title'), locale('log_far_desc'), dist > 50.0 and 'alert' or 'warn', src, {
            { name = locale('log_distance'), value = ('%.1fm'):format(dist), inline = true },
            { name = locale('log_player_pos'), value = ('%.2f, %.2f, %.2f'):format(ppos.x, ppos.y, ppos.z), inline = true },
        })
        return cb(false)
    end

    if not canDig(src, hunt) then return cb(false) end

    local loot = rollLoot(src)
    if not loot then
        notify(src, locale('inv_full'), 'error') -- nothing taken; free space and dig again
        return cb(false)
    end

    -- consume the map first so the reward can't be claimed twice
    hunts[cid] = nil
    if not exports['rsg-inventory']:RemoveItem(src, Config.MapItem, 1, nil, 'treasure-dug') then
        notify(src, locale('no_map'), 'error')
        SendLog('Security', locale('log_nomap_title'), locale('log_nomap_desc'), 'warn', src)
        TriggerClientEvent('rsg-treasure:client:endHunt', src)
        return cb(false)
    end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[Config.MapItem], 'remove', 1)

    local cash = math.random(Config.Cash.min, Config.Cash.max)
    if cash > 0 then
        Player.Functions.AddMoney('cash', cash, 'treasure-hunt')
        notify(src, locale('found_cash', cash), 'success')
    end

    local found = {}
    for _, l in ipairs(loot) do
        if exports['rsg-inventory']:AddItem(src, l.item, l.amount, nil, nil, 'treasure-hunt') then
            TriggerClientEvent('rsg-inventory:client:ItemBox', src, l.data, 'add', l.amount)
            notify(src, locale('found_item', l.amount, l.data.label), 'success')
            found[#found + 1] = ('%sx %s'):format(l.amount, l.data.label)
        end
    end

    SendLog('Rewards', locale('log_dug_title'), locale('log_dug_desc'), 'reward', src, {
        { name = locale('log_cash'), value = ('$%s'):format(cash), inline = true },
        { name = locale('log_location'), value = tostring(hunt.idx), inline = true },
        { name = locale('log_items'), value = #found > 0 and table.concat(found, '\n') or locale('log_none') },
    })

    TriggerClientEvent('rsg-treasure:client:endHunt', src)
    cb(true)
end)

-- warn about reward items that don't exist so they aren't silently skipped forever
CreateThread(function()
    for _, r in ipairs(Config.Rewards) do
        if not RSGCore.Shared.Items[r.item] then
            print(('^3[rsg-treasure] reward item "%s" is not in shared items and will be skipped^7'):format(r.item))
        end
    end
end)

AddEventHandler('playerDropped', function()
    cooldown[source] = nil
end)
