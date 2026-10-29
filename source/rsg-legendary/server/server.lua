local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Hunts = {}       -- [src] = { animal, clues = {vector2}, step, spawn, state = 'tracking'|'spawned', netId, expires }
local Starting = {}    -- [src] = true while a map is being used (blocks double-use)
local lastAction = {}  -- [src] = GetGameTimer() of the last buy/sell

---------------------------------
-- Helpers
---------------------------------
local function notify(src, desc, ntype)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('title'), description = desc, type = ntype or 'inform' })
end

local function rateLimited(src)
    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < 750 then return true end
    lastAction[src] = now
    return false
end

local function playerPos(src)
    return GetEntityCoords(GetPlayerPed(src))
end

local function nearTrapper(src)
    local pos = playerPos(src)
    for _, t in ipairs(Config.Trappers) do
        if #(pos - t.coords.xyz) <= Config.TrapperServerDistance then return true end
    end
    return false
end

local function dist2D(a, b)
    return #(vector2(a.x, a.y) - vector2(b.x, b.y))
end

local function endHunt(src, msgKey, ntype, logEvent)
    local hunt = Hunts[src]
    if not hunt then return end
    Hunts[src] = nil
    if logEvent then
        local a = Config.Animals[hunt.animal]
        LegendaryLog(logEvent, src, locale('log_hunt_ended', a.label), {
            { name = locale('log_f_stage'), value = hunt.state == 'spawned' and locale('log_stage_found') or locale('log_stage_clue', hunt.step, #hunt.clues) },
        })
    end
    TriggerClientEvent('rsg-legendary:client:endHunt', src)
    if msgKey then notify(src, locale(msgKey), ntype) end
end

---------------------------------
-- Database (table is created automatically)
---------------------------------
MySQL.ready(function()
    local ok, err = pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS `rsg_legendary_cooldowns` (
            `citizenid` VARCHAR(50) NOT NULL,
            `animal` VARCHAR(50) NOT NULL,
            `last_hunt` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`, `animal`)
        )
    ]])
    if not ok then
        print('^1[rsg-legendary]^7 failed to create database table: ' .. tostring(err))
    elseif Config.Debug then
        print('^2[rsg-legendary]^7 database table ready')
    end
end)

-- returns { [animal] = secondsLeft } for animals still on cooldown
local function getCooldowns(citizenid)
    local rows = MySQL.query.await(
        'SELECT animal, UNIX_TIMESTAMP(last_hunt) AS t FROM rsg_legendary_cooldowns WHERE citizenid = ?', { citizenid }) or {}
    local out, now, cd = {}, os.time(), Config.CooldownHours * 3600
    for _, r in ipairs(rows) do
        local left = (r.t + cd) - now
        if left > 0 then out[r.animal] = left end
    end
    return out
end

local function getHuntingXP(src, Player)
    if GetResourceState('rsg-hunting') == 'started' then
        local ok, xp = pcall(function() return exports['rsg-hunting']:GetHuntingXP(src) end)
        if ok and tonumber(xp) then return tonumber(xp) end
    end
    return tonumber(Player.Functions.GetRep(Config.XPRequirement.RepName)) or 0
end

local function requiredXP(animal)
    if not Config.XPRequirement or not Config.XPRequirement.Enabled then return 0 end
    return animal.minXP or Config.XPRequirement.DefaultMinXP or 0
end

local function cooldownMsg(src, seconds)
    notify(src, locale('on_cooldown', math.ceil(seconds / 3600)), 'error')
end

---------------------------------
-- Trapper menu
---------------------------------
lib.callback.register('rsg-legendary:server:getMenu', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not nearTrapper(src) then return nil end
    local cds = getCooldowns(Player.PlayerData.citizenid)
    local xp = getHuntingXP(src, Player)

    local animals = {}
    for key, a in pairs(Config.Animals) do
        animals[#animals + 1] = { key = key, label = a.label, description = a.description, price = a.price, cooldown = cds[key] or 0, minXP = requiredXP(a) }
    end
    table.sort(animals, function(x, y) return x.label < y.label end)

    local pelts = {}
    for item, price in pairs(Config.SellPrices) do
        local count = exports['rsg-inventory']:GetItemCount(src, item) or 0
        if count > 0 then
            local def = RSGCore.Shared.Items[item]
            pelts[#pelts + 1] = { name = item, label = def and def.label or item, count = count, price = price }
        end
    end
    table.sort(pelts, function(x, y) return x.label < y.label end)

    return { animals = animals, pelts = pelts, cash = Player.Functions.GetMoney(Config.MoneyType) or 0, xp = xp }
end)

lib.callback.register('rsg-legendary:server:buyMap', function(src, key)
    if rateLimited(src) or type(key) ~= 'string' then return false end
    local Player = RSGCore.Functions.GetPlayer(src)
    local animal = Config.Animals[key]
    if not Player or not animal then return false end
    if not nearTrapper(src) then notify(src, locale('too_far'), 'error') return false end

    local left = getCooldowns(Player.PlayerData.citizenid)[key]
    if left then cooldownMsg(src, left) return false end

    local need, have = requiredXP(animal), getHuntingXP(src, Player)
    if have < need then notify(src, locale('xp_too_low', need, have), 'error') return false end

    if not exports['rsg-inventory']:CanAddItem(src, Config.MapItem, 1) then
        notify(src, locale('inventory_full'), 'error') return false
    end
    if not Player.Functions.RemoveMoney(Config.MoneyType, animal.price, 'legendary-map') then
        notify(src, locale('no_money'), 'error') return false
    end
    exports['rsg-inventory']:AddItem(src, Config.MapItem, 1, { animal = key, description = animal.label }, nil, 'legendary-map-buy')
    notify(src, locale('map_bought', animal.label), 'success')
    LegendaryLog('map_bought', src, locale('log_map_bought', animal.label), {
        { name = locale('log_f_price'), value = ('$%s (%s)'):format(animal.price, Config.MoneyType) },
    })
    return true
end)

lib.callback.register('rsg-legendary:server:sell', function(src, item)
    if rateLimited(src) or type(item) ~= 'string' then return false end
    local Player = RSGCore.Functions.GetPlayer(src)
    local price = Config.SellPrices[item]
    if not Player or not price then return false end
    if not nearTrapper(src) then notify(src, locale('too_far'), 'error') return false end

    local count = exports['rsg-inventory']:GetItemCount(src, item) or 0
    if count <= 0 then return false end
    if not exports['rsg-inventory']:RemoveItem(src, item, count, nil, 'legendary-sell') then return false end
    local total = price * count
    Player.Functions.AddMoney(Config.MoneyType, total, 'legendary-sell')
    notify(src, locale('sold', count, total), 'success')
    local def = RSGCore.Shared.Items[item]
    LegendaryLog('sold', src, locale('log_sold', count, def and def.label or item), {
        { name = locale('log_f_item'), value = item }, { name = locale('log_f_each'), value = '$' .. price }, { name = locale('log_f_total'), value = ('$%s (%s)'):format(total, Config.MoneyType) },
    })
    return true
end)

---------------------------------
-- Use the map: start a hunt
---------------------------------
RSGCore.Functions.CreateUseableItem(Config.MapItem, function(source, item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local key = item and item.info and item.info.animal
    local animal = key and Config.Animals[key]
    if not animal then
        notify(src, locale('map_blank'), 'error')
        LegendaryLog('suspicious', src, locale('log_sus_map'), { { name = locale('log_f_map_animal'), value = tostring(key) } })
        return
    end
    if Hunts[src] or Starting[src] then notify(src, locale('already_hunting'), 'error') return end

    Starting[src] = true   -- the DB query below yields; stop a second map being used meanwhile
    local left = getCooldowns(Player.PlayerData.citizenid)[key]
    if left then Starting[src] = nil cooldownMsg(src, left) return end
    if not exports['rsg-inventory']:RemoveItem(src, Config.MapItem, 1, item.slot, 'legendary-map-use') then
        Starting[src] = nil return
    end

    -- random clue trail heading out from the zone centre, animal beyond the last clue
    local clues, angle, base = {}, math.random() * math.pi * 2, animal.zone
    for i = 1, Config.ClueCount do
        local r = Config.ClueSpread * (i / Config.ClueCount)
        local a = angle + (math.random() - 0.5) * 0.8
        clues[i] = vector2(base.x + math.cos(a) * r, base.y + math.sin(a) * r)
    end
    local last = clues[#clues]

    Hunts[src] = {
        animal = key, clues = clues, step = 1, state = 'tracking',
        spawn = vector2(last.x + math.cos(angle) * Config.SpawnOffset, last.y + math.sin(angle) * Config.SpawnOffset),
        expires = os.time() + Config.HuntDuration,
    }
    Starting[src] = nil
    TriggerClientEvent('rsg-legendary:client:startHunt', src, {
        animal = key, zone = base, radius = animal.radius, clue = clues[1], total = Config.ClueCount,
    })
    notify(src, locale('hunt_started', animal.label), 'success')
    LegendaryLog('hunt_started', src, locale('log_hunt_started', animal.label), {
        { name = locale('log_f_zone'), value = ('%.1f, %.1f (r %dm)'):format(base.x, base.y, animal.radius) },
        { name = locale('log_f_expires'), value = ('<t:%d:R>'):format(Hunts[src].expires) },
    })
end)

---------------------------------
-- Clue trail
---------------------------------
lib.callback.register('rsg-legendary:server:inspectClue', function(src)
    local hunt = Hunts[src]
    if not hunt or hunt.state ~= 'tracking' then return nil end
    if os.time() > hunt.expires then endHunt(src, 'hunt_expired', 'error', 'expired') return nil end
    local dist = dist2D(playerPos(src), hunt.clues[hunt.step])
    if dist > Config.ClueInspectDist then
        if dist > 50.0 then   -- a real player is always next to the clue they inspect
            LegendaryLog('suspicious', src, locale('log_sus_clue_far'), { { name = locale('log_f_distance'), value = ('%.1fm'):format(dist) } })
        end
        return nil
    end

    hunt.step = hunt.step + 1
    LegendaryLog('clue_found', src, locale('log_clue_found', hunt.step - 1, #hunt.clues, Config.Animals[hunt.animal].label))
    if hunt.step > #hunt.clues then
        hunt.state = 'spawned'
        return { spawn = hunt.spawn }
    end
    return { clue = hunt.clues[hunt.step], found = hunt.step - 1 }
end)

-- client tells us which networked ped is its legendary; only that entity can be skinned for rewards
RegisterNetEvent('rsg-legendary:server:animalSpawned', function(netId)
    local src = source
    local hunt = Hunts[src]
    if not hunt or hunt.state ~= 'spawned' or type(netId) ~= 'number' then return end
    if hunt.netId then   -- only replace the registered animal if it no longer exists (despawned)
        local old = NetworkGetEntityFromNetworkId(hunt.netId)
        if old and old ~= 0 and DoesEntityExist(old) then return end
    end
    local animal = Config.Animals[hunt.animal]
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or GetEntityModel(ent) ~= animal.model or dist2D(GetEntityCoords(ent), hunt.spawn) > 50.0 then
        LegendaryLog('suspicious', src, locale('log_sus_spawn'), { { name = locale('log_f_netid'), value = netId } })
        return
    end
    local respawn = hunt.netId ~= nil
    hunt.netId = netId
    LegendaryLog('animal_spawn', src, locale(respawn and 'log_animal_respawned' or 'log_animal_appeared', animal.label))
end)

---------------------------------
-- Skin: validate the carcass and pay out
---------------------------------
lib.callback.register('rsg-legendary:server:skin', function(src, netId)
    local Player = RSGCore.Functions.GetPlayer(src)
    local hunt = Hunts[src]
    if not Player or not hunt or hunt.state ~= 'spawned' then return false end
    local animal = Config.Animals[hunt.animal]
    if type(netId) ~= 'number' or netId ~= hunt.netId then
        LegendaryLog('suspicious', src, locale('log_sus_wrong_carcass', animal.label),
            { { name = locale('log_f_sent_netid'), value = tostring(netId) }, { name = locale('log_f_expected'), value = tostring(hunt.netId) } })
        return false
    end

    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) or GetEntityModel(ent) ~= animal.model then return false end
    if GetEntityHealth(ent) > 0 then
        notify(src, locale('not_dead'), 'error')
        LegendaryLog('suspicious', src, locale('log_sus_alive', animal.label))
        return false
    end
    local dist = #(playerPos(src) - GetEntityCoords(ent))
    if dist > Config.SkinMaxDistance then
        notify(src, locale('too_far'), 'error')
        if dist > 50.0 then
            LegendaryLog('suspicious', src, locale('log_sus_skin_far', animal.label), { { name = locale('log_f_distance'), value = ('%.1fm'):format(dist) } })
        end
        return false
    end

    for _, r in ipairs(animal.rewards) do
        if not exports['rsg-inventory']:CanAddItem(src, r.item, r.amount) then
            notify(src, locale('inventory_full'), 'error') return false
        end
    end

    Hunts[src] = nil   -- claim first so a second request can't pay out twice
    for _, r in ipairs(animal.rewards) do
        exports['rsg-inventory']:AddItem(src, r.item, r.amount, nil, nil, 'legendary-skin')
    end
    DeleteEntity(ent)
    notify(src, locale('skinned', animal.label), 'success')
    local got = {}
    for _, r in ipairs(animal.rewards) do
        local def = RSGCore.Shared.Items[r.item]
        got[#got + 1] = ('%dx %s'):format(r.amount, def and def.label or r.item)
    end
    LegendaryLog('skinned', src, locale('log_skinned', animal.label), {
        { name = locale('log_f_rewards'), value = table.concat(got, '\n'), inline = false },
        { name = locale('log_f_cooldown'), value = Config.CooldownHours .. 'h' },
    })
    MySQL.insert('INSERT INTO rsg_legendary_cooldowns (citizenid, animal, last_hunt) VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE last_hunt = NOW()',
        { Player.PlayerData.citizenid, hunt.animal })
    return true
end)

---------------------------------
-- Expiry, abandon, disconnect
---------------------------------
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for src, h in pairs(Hunts) do
            if now > h.expires then endHunt(src, 'hunt_expired', 'error', 'expired') end
        end
    end
end)

AddEventHandler('playerDropped', function()
    Hunts[source], Starting[source], lastAction[source] = nil, nil, nil
end)

RSGCore.Commands.Add('abandonhunt', locale('cmd_abandon'), {}, false, function(source)
    if Hunts[source] then endHunt(source, 'hunt_abandoned', 'inform', 'abandoned')
    else notify(source, locale('no_hunt'), 'error') end
end)

RSGCore.Commands.Add('legendpreview', locale('cmd_preview'), {
    { name = 'animal', help = locale('cmd_help_animal') }, { name = 'preset', help = locale('cmd_help_preset') },
}, true, function(source, args)
    if not Config.Animals[args[1]] then notify(source, locale('unknown_animal'), 'error') return end
    local preset = math.max(0, math.floor(tonumber(args[2]) or 0))
    TriggerClientEvent('rsg-legendary:client:preview', source, args[1], preset)
    LegendaryLog('admin', source, locale('log_admin_preview', Config.Animals[args[1]].label, preset))
end, 'admin')
