local RSGCore = exports['rsg-core']:GetCoreObject()

local Hunts = {}       -- [src] = { cid, animal, clues = {vector2}, step, spawn, state = 'tracking'|'spawned', netId, expires, started, members = {[src]=true} }
local Starting = {}    -- [src] = true while a map is being used (blocks double-use)
local lastAction = {}  -- [src] = GetGameTimer() of the last buy/sell/command
local DbReady, RestoreHunt = false, nil
local MemberOf = {}    -- [memberSrc] = ownerSrc
local Invites = {}     -- [targetSrc] = { owner = src, expires = os.time() }

---------------------------------
-- Helpers
---------------------------------
local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('title'), description = desc, type = ntype or 'inform', duration = 5000 })
end

-- rsg-core callback wrapper: handlers just return their result
local function callback(name, fn)
    RSGCore.Functions.CreateCallback(name, function(src, cb, ...) cb(fn(src, ...)) end)
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

local function deleteEntity(netId)
    if not netId then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
end

-- what the client needs to draw the hunt (owner or group member)
local function clientData(hunt, member)
    local a = Config.Animals[hunt.animal]
    return {
        animal = hunt.animal, zone = a.zone, radius = a.radius, total = #hunt.clues, found = hunt.step - 1,
        clue = hunt.state == 'tracking' and hunt.clues[hunt.step] or nil,
        spawn = hunt.state == 'spawned' and hunt.spawn or nil,
        member = member or nil,
    }
end

local function saveHunt(hunt)
    if not Config.SaveHunts or not hunt.cid then return end
    local clues = {}
    for i, c in ipairs(hunt.clues) do clues[i] = { c.x, c.y } end
    MySQL.prepare('INSERT INTO rsg_legendary_hunts (citizenid, data, expires) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), expires = VALUES(expires)', {
        hunt.cid, json.encode({ animal = hunt.animal, clues = clues, step = hunt.step, state = hunt.state,
            spawn = { hunt.spawn.x, hunt.spawn.y }, started = hunt.started }), hunt.expires,
    })
end

local function deleteSaved(cid)
    if Config.SaveHunts and cid then MySQL.prepare('DELETE FROM rsg_legendary_hunts WHERE citizenid = ?', { cid }) end
end

local function syncMembers(hunt)
    for m in pairs(hunt.members) do TriggerClientEvent('rsg-legendary:client:startHunt', m, clientData(hunt, true)) end
end

local function removeMember(m, msgKey)
    local owner = MemberOf[m]
    MemberOf[m] = nil
    if owner and Hunts[owner] then Hunts[owner].members[m] = nil end
    TriggerClientEvent('rsg-legendary:client:endHunt', m)
    if msgKey then notify(m, locale(msgKey), 'inform') end
end

-- keepSaved: player dropped, leave the hunt in the DB so it is restored on their next login
local function endHunt(src, msgKey, ntype, logEvent, keepSaved)
    local hunt = Hunts[src]
    if not hunt then return end
    Hunts[src] = nil
    deleteEntity(hunt.netId)
    for m in pairs(hunt.members) do removeMember(m, 'group_ended') end
    if not keepSaved then deleteSaved(hunt.cid) end
    if logEvent then
        local a = Config.Animals[hunt.animal]
        LegendaryLog(logEvent, src, locale('log_hunt_ended', a.label), {
            { name = locale('log_f_stage'), value = hunt.state == 'spawned' and locale('log_stage_found') or locale('log_stage_clue', hunt.step, #hunt.clues) },
        })
    end
    if not keepSaved then TriggerClientEvent('rsg-legendary:client:endHunt', src) end
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
            `notified` TINYINT(1) NOT NULL DEFAULT 1,
            PRIMARY KEY (`citizenid`, `animal`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    if ok then
        -- older installs: add the telegram flag (existing rows count as already notified)
        pcall(MySQL.query.await, 'ALTER TABLE `rsg_legendary_cooldowns` ADD COLUMN IF NOT EXISTS `notified` TINYINT(1) NOT NULL DEFAULT 1')
        ok, err = pcall(MySQL.query.await, [[
            CREATE TABLE IF NOT EXISTS `rsg_legendary_trophies` (
                `id` INT NOT NULL AUTO_INCREMENT,
                `citizenid` VARCHAR(50) NOT NULL,
                `name` VARCHAR(100) NOT NULL,
                `animal` VARCHAR(50) NOT NULL,
                `seconds` INT NOT NULL,
                `quality` VARCHAR(20) NOT NULL DEFAULT 'good',
                `killed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                INDEX `idx_animal` (`animal`),
                INDEX `idx_citizenid` (`citizenid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])
    end
    if ok then
        ok, err = pcall(MySQL.query.await, [[
            CREATE TABLE IF NOT EXISTS `rsg_legendary_hunts` (
                `citizenid` VARCHAR(50) NOT NULL,
                `data` LONGTEXT NOT NULL,
                `expires` INT NOT NULL,
                PRIMARY KEY (`citizenid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])
    end
    if not ok then
        print('^1[rsg-legendary]^7 failed to create database tables: ' .. tostring(err))
        return
    end
    MySQL.query.await('DELETE FROM rsg_legendary_hunts WHERE expires < ?', { os.time() })
    if Config.Debug then print('^2[rsg-legendary]^7 database tables ready') end
    DbReady = true
    -- resource restart: restore hunts for players already online
    for src, Player in pairs(RSGCore.Functions.GetRSGPlayers()) do RestoreHunt(src, Player) end
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
-- Trophy board
---------------------------------
local trophyCache, trophyCacheAt = nil, 0

local function getBoard()
    if trophyCache and os.time() - trophyCacheAt < Config.Trophies.CacheSec then return trophyCache end
    local first = MySQL.query.await([[
        SELECT t.animal, t.name, UNIX_TIMESTAMP(t.killed_at) AS at FROM rsg_legendary_trophies t
        JOIN (SELECT animal, MIN(id) AS id FROM rsg_legendary_trophies GROUP BY animal) f ON f.id = t.id
    ]]) or {}
    local fastest = MySQL.query.await([[
        SELECT t.animal, t.name, t.seconds FROM rsg_legendary_trophies t
        JOIN (SELECT animal, MIN(seconds) AS s FROM rsg_legendary_trophies GROUP BY animal) f
          ON f.animal = t.animal AND f.s = t.seconds ORDER BY t.id
    ]]) or {}
    local board = {}
    for _, r in ipairs(first) do board[r.animal] = { first = r.name, firstAt = r.at } end
    for _, r in ipairs(fastest) do
        board[r.animal] = board[r.animal] or {}
        if not board[r.animal].fastest then board[r.animal].fastest, board[r.animal].seconds = r.name, r.seconds end
    end
    trophyCache, trophyCacheAt = board, os.time()
    return board
end

local function getTrophyRows(citizenid)
    return MySQL.query.await('SELECT animal, seconds, quality, UNIX_TIMESTAMP(killed_at) AS killed_at FROM rsg_legendary_trophies WHERE citizenid = ? ORDER BY id', { citizenid }) or {}
end

-- for other resources (e.g. rsg-housing wall trophies): every legendary this character has taken
exports('GetTrophies', function(citizenid)
    if type(citizenid) ~= 'string' then return {} end
    return getTrophyRows(citizenid)
end)

local function menuTrophies(citizenid)
    if not Config.Trophies.Enabled then return nil end
    local board, mine = getBoard(), {}
    for _, r in ipairs(getTrophyRows(citizenid)) do
        local m = mine[r.animal] or { kills = 0, perfect = 0 }
        m.kills = m.kills + 1
        if r.quality == 'perfect' then m.perfect = m.perfect + 1 end
        mine[r.animal] = m
    end
    local out = {}
    for key, a in pairs(Config.Animals) do
        local b, m = board[key] or {}, mine[key] or {}
        out[#out + 1] = { label = a.label, first = b.first, fastest = b.fastest, seconds = b.seconds, kills = m.kills or 0, perfect = m.perfect or 0 }
    end
    table.sort(out, function(x, y) return x.label < y.label end)
    return out
end

---------------------------------
-- Trapper menu
---------------------------------
callback('rsg-legendary:server:getMenu', function(src)
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

    return { animals = animals, pelts = pelts, cash = Player.Functions.GetMoney(Config.MoneyType) or 0, xp = xp,
        trophies = menuTrophies(Player.PlayerData.citizenid) }
end)

callback('rsg-legendary:server:buyMap', function(src, key)
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

callback('rsg-legendary:server:sell', function(src, item)
    if rateLimited(src) or type(item) ~= 'string' then return false end
    local Player = RSGCore.Functions.GetPlayer(src)
    local price = Config.SellPrices[item]
    if not Player or not price then return false end
    if not nearTrapper(src) then notify(src, locale('too_far'), 'error') return false end

    local count = exports['rsg-inventory']:GetItemCount(src, item) or 0
    if count <= 0 then return false end
    if not exports['rsg-inventory']:RemoveItem(src, item, count, nil, 'legendary-sell') then return false end
    local total = price * count
    if not Player.Functions.AddMoney(Config.MoneyType, total, 'legendary-sell') then
        exports['rsg-inventory']:AddItem(src, item, count, nil, nil, 'legendary-sell-refund')
        return false
    end
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
    if Hunts[src] or Starting[src] or MemberOf[src] then notify(src, locale('already_hunting'), 'error') return end

    Starting[src] = true   -- the DB query below yields; stop a second map being used meanwhile
    local okCd, cds = pcall(getCooldowns, Player.PlayerData.citizenid)
    local left = okCd and cds[key]
    if not okCd or left then Starting[src] = nil if left then cooldownMsg(src, left) end return end
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
        cid = Player.PlayerData.citizenid, animal = key, clues = clues, step = 1, state = 'tracking',
        spawn = vector2(last.x + math.cos(angle) * Config.SpawnOffset, last.y + math.sin(angle) * Config.SpawnOffset),
        expires = os.time() + Config.HuntDuration, started = os.time(), members = {},
    }
    Starting[src] = nil
    saveHunt(Hunts[src])
    TriggerClientEvent('rsg-legendary:client:startHunt', src, clientData(Hunts[src]))
    notify(src, locale('hunt_started', animal.label), 'success')
    LegendaryLog('hunt_started', src, locale('log_hunt_started', animal.label), {
        { name = locale('log_f_zone'), value = ('%.1f, %.1f (r %dm)'):format(base.x, base.y, animal.radius) },
        { name = locale('log_f_expires'), value = ('<t:%d:R>'):format(Hunts[src].expires) },
    })
end)

---------------------------------
-- Clue trail
---------------------------------
callback('rsg-legendary:server:inspectClue', function(src)
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
    if hunt.step > #hunt.clues then hunt.state = 'spawned' end
    saveHunt(hunt)
    syncMembers(hunt)
    if hunt.state == 'spawned' then return { spawn = hunt.spawn } end
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
callback('rsg-legendary:server:skin', function(src, netId)
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

    -- kill quality from the server's view of the carcass (cause of death = weapon hash)
    local perfect = false
    if Config.Quality.Enabled then
        local cause = GetPedCauseOfDeath(ent)
        for _, w in ipairs(Config.Quality.PerfectWeapons) do
            if cause == w then perfect = true break end
        end
    end
    local rewards = {}
    for i, r in ipairs(animal.rewards) do
        local amount = r.amount
        if i > 1 and perfect then amount = amount * Config.Quality.TrinketMult end
        rewards[i] = { item = r.item, amount = amount }
    end
    if rewards[2] and math.random() < (Config.BonusTrinketChance or 0) then
        rewards[2].amount = rewards[2].amount + 1
        rewards.bonus = true
    end

    for _, r in ipairs(rewards) do
        if not exports['rsg-inventory']:CanAddItem(src, r.item, r.amount) then
            notify(src, locale('inventory_full'), 'error') return false
        end
    end

    Hunts[src] = nil   -- claim first so a second request can't pay out twice
    deleteSaved(hunt.cid)
    for _, r in ipairs(rewards) do
        exports['rsg-inventory']:AddItem(src, r.item, r.amount, nil, nil, 'legendary-skin')
    end
    local carcass = GetEntityCoords(ent)
    DeleteEntity(ent)
    notify(src, locale(perfect and 'skinned_perfect' or 'skinned', animal.label), 'success')
    if rewards.bonus then notify(src, locale('bonus_trinket'), 'success') end

    local cooldownSql = 'INSERT INTO rsg_legendary_cooldowns (citizenid, animal, last_hunt, notified) VALUES (?, ?, NOW(), 0) ON DUPLICATE KEY UPDATE last_hunt = NOW(), notified = 0'
    MySQL.insert(cooldownSql, { Player.PlayerData.citizenid, hunt.animal })

    -- group members near the carcass share the trinkets (base amounts) and get the cooldown too
    local shared = {}
    for m in pairs(hunt.members) do
        MemberOf[m] = nil
        local MP = RSGCore.Functions.GetPlayer(m)
        if MP and #(playerPos(m) - carcass) <= Config.Group.ShareDistance then
            for i = 2, #animal.rewards do
                local r = animal.rewards[i]
                if exports['rsg-inventory']:CanAddItem(m, r.item, r.amount) then
                    exports['rsg-inventory']:AddItem(m, r.item, r.amount, nil, nil, 'legendary-group-share')
                end
            end
            MySQL.insert(cooldownSql, { MP.PlayerData.citizenid, hunt.animal })
            notify(m, locale('group_shared', animal.label), 'success')
            shared[#shared + 1] = GetPlayerName(m) or tostring(m)
        else
            notify(m, locale('group_ended'), 'inform')
        end
        TriggerClientEvent('rsg-legendary:client:endHunt', m)
    end

    if Config.Trophies.Enabled then
        local ci = Player.PlayerData.charinfo or {}
        MySQL.insert('INSERT INTO rsg_legendary_trophies (citizenid, name, animal, seconds, quality) VALUES (?, ?, ?, ?, ?)', {
            Player.PlayerData.citizenid, ('%s %s'):format(ci.firstname or '', ci.lastname or ''), hunt.animal,
            os.time() - (hunt.started or os.time()), perfect and 'perfect' or 'good',
        })
        trophyCache = nil
    end

    local got = {}
    for _, r in ipairs(rewards) do
        local def = RSGCore.Shared.Items[r.item]
        got[#got + 1] = ('%dx %s'):format(r.amount, def and def.label or r.item)
    end
    LegendaryLog('skinned', src, locale('log_skinned', animal.label), {
        { name = locale('log_f_rewards'), value = table.concat(got, '\n'), inline = false },
        { name = locale('log_f_quality'), value = perfect and locale('quality_perfect') or locale('quality_good') },
        { name = locale('log_f_group'), value = #shared > 0 and table.concat(shared, ', ') or '-' },
        { name = locale('log_f_cooldown'), value = Config.CooldownHours .. 'h' },
    })
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

---------------------------------
-- Saved hunts: restore on login / resource restart
---------------------------------
RestoreHunt = function(src, Player)
    if not Config.SaveHunts or not DbReady or Hunts[src] or not Player then return end
    local cid = Player.PlayerData.citizenid
    local row = MySQL.single.await('SELECT data, expires FROM rsg_legendary_hunts WHERE citizenid = ?', { cid })
    if not row then return end
    local ok, d = pcall(json.decode, row.data)
    if not ok or type(d) ~= 'table' or not Config.Animals[d.animal] or row.expires <= os.time() then
        deleteSaved(cid) return
    end
    local clues = {}
    for i, c in ipairs(d.clues or {}) do clues[i] = vector2(c[1], c[2]) end
    if #clues == 0 then deleteSaved(cid) return end
    Hunts[src] = {
        cid = cid, animal = d.animal, clues = clues, step = math.min(d.step or 1, #clues), state = d.state == 'spawned' and 'spawned' or 'tracking',
        spawn = vector2(d.spawn[1], d.spawn[2]), expires = row.expires, started = d.started or os.time(), members = {},
    }
    TriggerClientEvent('rsg-legendary:client:startHunt', src, clientData(Hunts[src]))
    notify(src, locale('hunt_restored', Config.Animals[d.animal].label), 'inform')
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    SetTimeout(5000, function() RestoreHunt(src, RSGCore.Functions.GetPlayer(src)) end)
end)

---------------------------------
-- Cooldown telegrams (rsg-telegram)
---------------------------------
if Config.CooldownTelegram.Enabled then
    CreateThread(function()
        while true do
            Wait(Config.CooldownTelegram.CheckMin * 60000)
            if DbReady and GetResourceState('rsg-telegram') == 'started' then
                local rows = MySQL.query.await([[
                    SELECT c.citizenid, c.animal, p.charinfo FROM rsg_legendary_cooldowns c
                    LEFT JOIN players p ON p.citizenid COLLATE utf8mb4_unicode_ci = c.citizenid COLLATE utf8mb4_unicode_ci
                    WHERE c.notified = 0 AND c.last_hunt <= (NOW() - INTERVAL ? HOUR) LIMIT 50
                ]], { Config.CooldownHours }) or {}
                for _, r in ipairs(rows) do
                    local a = Config.Animals[r.animal]
                    local ci = r.charinfo and json.decode(r.charinfo) or {}
                    if a then
                        MySQL.insert.await('INSERT INTO rsg_telegrams (citizenid, recipient_name, sender_citizenid, sender_name, subject, message) VALUES (?, ?, ?, ?, ?, ?)', {
                            r.citizenid, ('%s %s'):format(ci.firstname or '', ci.lastname or ''), 'rsg-legendary',
                            locale('telegram_sender'), locale('telegram_subject', a.label), locale('telegram_message', a.label),
                        })
                        local Target = RSGCore.Functions.GetPlayerByCitizenId(r.citizenid)
                        if Target then TriggerClientEvent('rsg-telegram:client:newTelegram', Target.PlayerData.source, locale('telegram_sender')) end
                    end
                    MySQL.update.await('UPDATE rsg_legendary_cooldowns SET notified = 1 WHERE citizenid = ? AND animal = ?', { r.citizenid, r.animal })
                end
            end
        end
    end)
end

---------------------------------
-- Disconnect, abandon, group hunts
---------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    if Hunts[src] then endHunt(src, nil, nil, nil, true) end   -- kept in the DB, restored on next login
    if MemberOf[src] then removeMember(src) end
    Invites[src], Starting[src], lastAction[src] = nil, nil, nil
end)

RSGCore.Commands.Add('abandonhunt', locale('cmd_abandon'), {}, false, function(source)
    if Hunts[source] then endHunt(source, 'hunt_abandoned', 'inform', 'abandoned')
    elseif MemberOf[source] then
        local owner = MemberOf[source]
        removeMember(source, 'group_left')
        notify(owner, locale('group_member_left', GetPlayerName(source) or source), 'inform')
    else notify(source, locale('no_hunt'), 'error') end
end)

if Config.Group.Enabled then
    RSGCore.Commands.Add('invitehunt', locale('cmd_invite'), { { name = 'id', help = locale('cmd_help_id') } }, true, function(source, args)
        local src, target = source, tonumber(args[1])
        if rateLimited(src) then return end
        local hunt = Hunts[src]
        if not hunt then notify(src, locale('no_hunt'), 'error') return end
        local TP = target and target ~= src and RSGCore.Functions.GetPlayer(target)
        if not TP then notify(src, locale('group_no_player'), 'error') return end
        local count = 0
        for _ in pairs(hunt.members) do count = count + 1 end
        if count >= Config.Group.MaxMembers then notify(src, locale('group_full'), 'error') return end
        if Hunts[target] or MemberOf[target] then notify(src, locale('group_busy'), 'error') return end
        if #(playerPos(src) - playerPos(target)) > Config.Group.InviteDistance then notify(src, locale('group_too_far'), 'error') return end
        if getCooldowns(TP.PlayerData.citizenid)[hunt.animal] then notify(src, locale('group_target_cooldown'), 'error') return end
        Invites[target] = { owner = src, expires = os.time() + Config.Group.InviteTimeout }
        local label = Config.Animals[hunt.animal].label
        notify(target, locale('group_invited', GetPlayerName(src) or src, label), 'inform')
        notify(src, locale('group_invite_sent'), 'success')
    end)

    RSGCore.Commands.Add('accepthunt', locale('cmd_accept'), {}, false, function(source)
        local src = source
        local inv = Invites[src]
        Invites[src] = nil
        local hunt = inv and inv.expires >= os.time() and Hunts[inv.owner]
        if not hunt then notify(src, locale('group_no_invite'), 'error') return end
        if Hunts[src] or MemberOf[src] then notify(src, locale('already_hunting'), 'error') return end
        local count = 0
        for _ in pairs(hunt.members) do count = count + 1 end
        if count >= Config.Group.MaxMembers then notify(src, locale('group_full'), 'error') return end
        hunt.members[src], MemberOf[src] = true, inv.owner
        TriggerClientEvent('rsg-legendary:client:startHunt', src, clientData(hunt, true))
        notify(src, locale('group_joined', Config.Animals[hunt.animal].label), 'success')
        notify(inv.owner, locale('group_member_joined', GetPlayerName(src) or src), 'success')
    end)
end

RSGCore.Commands.Add('legendpreview', locale('cmd_preview'), {
    { name = 'animal', help = locale('cmd_help_animal') }, { name = 'preset', help = locale('cmd_help_preset') },
}, true, function(source, args)
    if not Config.Animals[args[1]] then notify(source, locale('unknown_animal'), 'error') return end
    local preset = math.max(0, math.floor(tonumber(args[2]) or 0))
    TriggerClientEvent('rsg-legendary:client:preview', source, args[1], preset)
    LegendaryLog('admin', source, locale('log_admin_preview', Config.Animals[args[1]].label, preset))
end, 'admin')
