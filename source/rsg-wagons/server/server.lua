local RSGCore = exports['rsg-core']:GetCoreObject()

local activeWagons = {}   -- [src] = { id, netId, model, condition, look, pending, called }
local cooldowns = {}      -- [src] = GetGameTimer() of last action
local dbReady = false

-- ===================== DATABASE =====================
local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `player_wagons` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `model` VARCHAR(50) NOT NULL,
  `name` VARCHAR(40) NOT NULL,
  `wagon_condition` INT(11) NOT NULL DEFAULT 100,
  `store` VARCHAR(50) NOT NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 0,
  `livery` INT(11) NOT NULL DEFAULT -1,
  `tint` INT(11) NOT NULL DEFAULT -1,
  `propset` VARCHAR(64) NULL DEFAULT NULL,
  `lantern` VARCHAR(64) NULL DEFAULT NULL,
  `cargo` LONGTEXT NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

local function ensureDatabase()
    local ok, err = pcall(function() MySQL.query.await(SCHEMA) end)
    if not ok then
        print('^1[rsg-wagons] database setup failed: ' .. tostring(err) .. '^7')
        return false
    end
    -- upgrade tables from older versions (never destructive)
    local columns = {
        { 'livery',  'INT(11) NOT NULL DEFAULT -1' },
        { 'tint',    'INT(11) NOT NULL DEFAULT -1' },
        { 'propset', 'VARCHAR(64) NULL DEFAULT NULL' },
        { 'lantern', 'VARCHAR(64) NULL DEFAULT NULL' },
        { 'cargo',   'LONGTEXT NULL DEFAULT NULL' },
    }
    for _, col in ipairs(columns) do
        local ok2, err2 = pcall(function()
            local has = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'player_wagons' AND COLUMN_NAME = ?]], { col[1] })
            if (tonumber(has) or 0) == 0 then
                MySQL.query.await(('ALTER TABLE `player_wagons` ADD COLUMN `%s` %s'):format(col[1], col[2]))
                print(('^2[rsg-wagons] added %s column^7'):format(col[1]))
            end
        end)
        if not ok2 then print(('^1[rsg-wagons] could not add %s column: %s^7'):format(col[1], tostring(err2))) end
    end
    print('^2[rsg-wagons] database tables ready^7')
    return true
end

CreateThread(function()
    if Config.AutoDatabase and not ensureDatabase() then return end
    -- wagons that were out stay out across restarts: the owner can call them (J) after logging in
    dbReady = true
end)

-- ===================== HELPERS =====================
local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('sv_title'), description = desc, type = ntype or 'inform' })
end

local function onCooldown(src)
    local now = GetGameTimer()
    if cooldowns[src] and now - cooldowns[src] < Config.ActionCooldown then return true end
    cooldowns[src] = now
    return false
end

local function nearStore(src, storeKey)
    local store = Config.Stores[storeKey]
    if not store then return false end
    local pcoords = GetEntityCoords(GetPlayerPed(src))
    local npc = vector3(store.npc.x, store.npc.y, store.npc.z)
    local prev = vector3(store.preview.x, store.preview.y, store.preview.z)
    -- player is at the counter, or within the yard near the preview spot
    return #(pcoords - npc) <= (Config.InteractDistance + 3.0) or #(pcoords - prev) <= Config.StoreDistance
end

local function sellValue(row)
    local data = Config.Wagons[row.model]
    if not data then return 0 end
    local value = data.price * Config.SellPercent
    if (row.wagon_condition or 100) < Config.DamagedThreshold then
        value = value * Config.DamagedSellModifier
    end
    return math.floor(value)
end

local function conditionTier(cond)
    -- mirrors RDR2 fence comments: damaged / poor / average / quality / exceptional
    if cond < Config.DamagedThreshold then return 'damaged' end
    if cond >= 99 then return 'exceptional' end
    if cond >= 96 then return 'quality' end
    if cond >= 93 then return 'average' end
    return 'poor'
end

-- returns the livery id if it exists for this model, else the model's first livery (or -1 if it has none)
local function validLivery(model, livery)
    local list = Config.Liveries and Config.Liveries[model]
    if not list or #list == 0 then return -1 end
    livery = tonumber(livery)
    for _, l in ipairs(list) do if l.id == livery then return livery end end
    return list[1].id
end

-- returns the tint if valid for this model (-1 = default colour), else -1
local function validTint(model, tint)
    local count = Config.Tints and Config.Tints[model] or 0
    tint = math.floor(tonumber(tint) or -1)
    if tint >= 0 and tint < count then return tint end
    return -1
end

-- cargo / lantern propset name if it's in the config list for this model, else nil
local function validPropset(list, model, name)
    if type(name) ~= 'string' or name == '' then return nil end
    for _, p in ipairs((list and list[model]) or {}) do
        if p.name == name then return name end
    end
    return nil
end

-- ===== hunting cart helpers =====
local HC = Config.HuntingCart or {}
local function isHuntCart(model) return HC.enabled and HC.models and HC.models[model] == true end

local function getCargo(row)
    if type(row.cargo) ~= 'string' or row.cargo == '' then return {} end
    local ok, data = pcall(json.decode, row.cargo)
    return (ok and type(data) == 'table') and data or {}
end

local function tarpLevel(count)
    local cap = math.max(1, HC.capacity or 20)
    local min, max = HC.tarpMin or 0.0, HC.tarpMax or 1.0
    return min + (max - min) * math.min(1.0, count / cap)
end

-- everything other clients need to dress the wagon the same way (shared via entity state bag)
local function lookOf(row)
    local look = {
        livery = row.livery or -1, tint = row.tint or -1,
        propset = validPropset(Config.Propsets, row.model, row.propset),
        lantern = validPropset(Config.Lanterns, row.model, row.lantern),
    }
    if isHuntCart(row.model) then
        local count = #getCargo(row)
        look.propset = HC.tarp          -- the pelt tarp is always fitted
        look.tarp = tarpLevel(count)    -- and rises as the cart fills
        look.cargo = count
    end
    return look
end

local function getOwned(citizenid)
    local rows = MySQL.query.await('SELECT id, model, name, wagon_condition, store, active, livery, tint FROM player_wagons WHERE citizenid = ? ORDER BY id', { citizenid }) or {}
    local list = {}
    for _, r in ipairs(rows) do
        local data = Config.Wagons[r.model]
        list[#list + 1] = {
            id = r.id,
            model = r.model,
            name = r.name,
            label = data and data.label or r.model,
            category = data and data.category or 'wagons',
            condition = r.wagon_condition,
            conditionTier = conditionTier(r.wagon_condition),
            store = r.store,
            storeLabel = Config.Stores[r.store] and Config.Stores[r.store].label or r.store,
            active = r.active == 1,
            livery = r.livery or -1,
            tint = r.tint or -1,
            sellValue = sellValue(r),
            repairCost = (Config.YardRepair and Config.YardRepair.enabled and r.wagon_condition < 100)
                and math.ceil((100 - r.wagon_condition) * Config.YardRepair.pricePerPercent) or 0,
            weight = data and data.weight or 0,
            slots = data and data.slots or 0,
        }
    end
    return list
end

local function getRow(id, citizenid)
    return MySQL.single.await('SELECT * FROM player_wagons WHERE id = ? AND citizenid = ?', { id, citizenid })
end

-- remove the player's wagon from the world.
-- save ~= false : it was stored -> active = 0
-- save == false : player left / resource stopped -> it stays "out" (active = 1) and keeps its last condition
local function despawnActive(src, save)
    local active = activeWagons[src]
    if not active then return end
    local ent = active.netId and NetworkGetEntityFromNetworkId(active.netId) or 0
    if ent and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
    if save ~= false then
        MySQL.update('UPDATE player_wagons SET active = 0 WHERE id = ?', { active.id })
    elseif active.condition then
        MySQL.update('UPDATE player_wagons SET wagon_condition = ? WHERE id = ?', { active.condition, active.id })
    end
    activeWagons[src] = nil
end

-- the wagon's health lives on the owner's client, so the server only accepts reports that LOWER it:
-- a modified client can't "repair" its wagon by reporting 100%. Repairs are done server side.
-- 0 is reserved for "wrecked"; a reported condition is at least 1%.
local function reportedCondition(active, condition)
    local known = active and active.condition or 100
    if known <= 0 then return 0 end
    condition = math.floor(math.max(1, math.min(100, tonumber(condition) or known)))
    return math.min(condition, known)
end

local function sanitizeName(name, fallback)
    if type(name) ~= 'string' then return fallback end
    name = name:gsub('[<>"\'`\\]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #name == 0 then return fallback end
    return name:sub(1, Config.NameMaxLength)
end

-- ===================== CALLBACKS =====================
RSGCore.Functions.CreateCallback('rsg-wagons:server:getOwned', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not dbReady then return cb({}) end
    cb(getOwned(Player.PlayerData.citizenid))
end)

-- buy a wagon: everything worked out from server config
RSGCore.Functions.CreateCallback('rsg-wagons:server:buy', function(source, cb, storeKey, model, name, livery, tint)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not dbReady then return cb(false) end
    if onCooldown(src) then return cb(false) end

    local data = type(model) == 'string' and Config.Wagons[model] or nil
    local store = type(storeKey) == 'string' and Config.Stores[storeKey] or nil
    if not data or not store then return cb(false) end
    if data.stores then
        local allowed = false
        for _, s in ipairs(data.stores) do if s == storeKey then allowed = true break end end
        if not allowed then return cb(false) end
    end
    if not nearStore(src, storeKey) then
        notify(src, locale('sv_too_far'), 'error')
        return cb(false)
    end

    local cid = Player.PlayerData.citizenid
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM player_wagons WHERE citizenid = ?', { cid }) or 0
    if count >= Config.MaxWagons then
        notify(src, locale('sv_max_wagons', Config.MaxWagons), 'error')
        return cb(false)
    end

    if not Player.Functions.RemoveMoney(Config.MoneyType, data.price, 'rsg-wagons purchase ' .. model) then
        notify(src, locale('sv_no_money'), 'error')
        return cb(false)
    end

    local id = MySQL.insert.await('INSERT INTO player_wagons (citizenid, model, name, wagon_condition, store, active, livery, tint) VALUES (?, ?, ?, 100, ?, 0, ?, ?)',
        { cid, model, sanitizeName(name, data.label), storeKey, validLivery(model, livery), validTint(model, tint) })
    if not id then
        Player.Functions.AddMoney(Config.MoneyType, data.price, 'rsg-wagons refund')
        return cb(false)
    end

    notify(src, locale('sv_bought', data.label, data.price), 'success')
    TriggerEvent('rsg-log:server:CreateLog', 'shops', 'Wagon Purchased', 'green',
        ('%s (%s) bought %s for $%s'):format(GetPlayerName(src), cid, model, data.price))
    cb(true, getOwned(cid))
end)

-- take a wagon out: returns model + spawn point, client creates the networked vehicle
RSGCore.Functions.CreateCallback('rsg-wagons:server:takeOut', function(source, cb, storeKey, id)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not dbReady then return cb(false) end
    if onCooldown(src) then return cb(false) end
    id = tonumber(id)
    local store = type(storeKey) == 'string' and Config.Stores[storeKey] or nil
    if not id or not store then return cb(false) end
    if not nearStore(src, storeKey) then notify(src, locale('sv_too_far'), 'error') return cb(false) end

    local row = getRow(id, Player.PlayerData.citizenid)
    if not row or not Config.Wagons[row.model] then return cb(false) end
    if activeWagons[src] then
        notify(src, locale('sv_already_out'), 'error')
        return cb(false)
    end

    activeWagons[src] = { id = id, netId = nil, model = row.model, pending = true, look = lookOf(row), condition = row.wagon_condition }
    MySQL.update.await('UPDATE player_wagons SET active = 1, store = ? WHERE id = ?', { storeKey, id })
    cb(true, { id = id, model = row.model, name = row.name, condition = row.wagon_condition, livery = row.livery or -1, tint = row.tint or -1, coords = store.preview })
end)

RegisterNetEvent('rsg-wagons:server:registerSpawned', function(id, netId)
    local src = source
    local active = activeWagons[src]
    if not active or active.id ~= tonumber(id) or not active.pending then return end
    -- the entity can take a moment to replicate to the server after the client creates it
    local ent = 0
    local timeout = GetGameTimer() + 5000
    repeat
        ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
        if ent and ent ~= 0 and DoesEntityExist(ent) then break end
        Wait(100)
    until GetGameTimer() > timeout
    if not ent or ent == 0 or not DoesEntityExist(ent) then
        print(('^3[rsg-wagons] %s spawned wagon %s but the entity never reached the server^7'):format(src, tostring(id)))
        return
    end
    if activeWagons[src] ~= active then return end
    if (GetEntityModel(ent) & 0xFFFFFFFF) ~= (joaat(active.model) & 0xFFFFFFFF) then
        print(('^3[rsg-wagons] %s registered an entity with the wrong model^7'):format(src))
        return
    end
    active.netId = tonumber(netId)
    active.pending = false
    active.called = nil
    Entity(ent).state:set('rsgWagonId', active.id, true)
    if active.look then Entity(ent).state:set('rsgWagonLook', active.look, true) end
end)

-- spawn failed client side
RegisterNetEvent('rsg-wagons:server:spawnFailed', function(id)
    local src = source
    local active = activeWagons[src]
    if not active or active.id ~= tonumber(id) or not active.pending then return end
    if active.called then
        -- a call failed: the wagon stays out, just away
        active.pending, active.called = false, nil
        return
    end
    MySQL.update('UPDATE player_wagons SET active = 0 WHERE id = ?', { active.id })
    activeWagons[src] = nil
end)

-- find the yard closest to the player's wagon (or the player, if the wagon is wrecked/gone)
local function nearestYard(src)
    local active = activeWagons[src]
    local pcoords = GetEntityCoords(GetPlayerPed(src))
    local ent = active and active.netId and NetworkGetEntityFromNetworkId(active.netId) or 0
    local wcoords = (ent ~= 0 and DoesEntityExist(ent)) and GetEntityCoords(ent) or pcoords
    local bestKey, bestDist
    for key, store in pairs(Config.Stores) do
        local npc = vector3(store.npc.x, store.npc.y, store.npc.z)
        local prev = vector3(store.preview.x, store.preview.y, store.preview.z)
        local wd = math.min(#(wcoords - npc), #(wcoords - prev))
        local pd = math.min(#(pcoords - npc), #(pcoords - prev))
        if wd <= Config.StoreRadius and pd <= Config.StoreRadius and (not bestDist or wd < bestDist) then
            bestKey, bestDist = key, wd
        end
    end
    return bestKey
end

local function storeWagon(src, Player, storeKey, condition)
    condition = math.max(1, reportedCondition(activeWagons[src], condition)) -- a stored wreck is kept at 1%
    MySQL.update.await('UPDATE player_wagons SET wagon_condition = ?, store = ? WHERE id = ?', { condition, storeKey, activeWagons[src].id })
    despawnActive(src, true)
    notify(src, locale('sv_stored'), 'success')
    return getOwned(Player.PlayerData.citizenid)
end

-- store from the yard keeper menu
RSGCore.Functions.CreateCallback('rsg-wagons:server:store', function(source, cb, storeKey, condition)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end
    if onCooldown(src) then return cb(false) end
    local store = type(storeKey) == 'string' and Config.Stores[storeKey] or nil
    if not store or not activeWagons[src] then notify(src, locale('sv_none_out'), 'error') return cb(false) end
    if not nearStore(src, storeKey) then notify(src, locale('sv_too_far'), 'error') return cb(false) end
    if nearestYard(src) ~= storeKey then notify(src, locale('sv_wagon_too_far'), 'error') return cb(false) end
    cb(true, storeWagon(src, Player, storeKey, condition))
end)

-- store from the wagon target / yard prompt: uses whichever yard is nearest
RSGCore.Functions.CreateCallback('rsg-wagons:server:storeNearest', function(source, cb, condition)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end
    if onCooldown(src) then return cb(false) end
    if not activeWagons[src] then notify(src, locale('sv_none_out'), 'error') return cb(false) end
    local storeKey = nearestYard(src)
    if not storeKey then notify(src, locale('sv_no_yard'), 'error') return cb(false) end
    cb(true, storeWagon(src, Player, storeKey, condition))
end)

-- trade a stored wagon back to the yard
RSGCore.Functions.CreateCallback('rsg-wagons:server:sell', function(source, cb, storeKey, id)
    local src = source
    local function fail(key, why)
        if key then notify(src, locale(key), 'error') end
        if why then print(('^3[rsg-wagons] sell failed for %s (wagon %s): %s^7'):format(src, tostring(id), why)) end
        cb(false)
    end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return fail() end
    if not dbReady then return fail('sv_try_again') end
    if onCooldown(src) then return fail('sv_slow_down') end
    id = tonumber(id)
    if not id or not Config.Stores[storeKey] then return fail('sv_try_again') end
    if not nearStore(src, storeKey) then return fail('sv_too_far') end

    local row = getRow(id, Player.PlayerData.citizenid)
    if not row then return fail('sv_not_yours') end
    if row.active == 1 or (activeWagons[src] and activeWagons[src].id == id) then
        return fail('sv_store_first')
    end

    local value = sellValue(row)
    local ok, affected = pcall(MySQL.update.await, 'DELETE FROM player_wagons WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
    if not ok then return fail('sv_try_again', 'delete failed: ' .. tostring(affected)) end
    if not affected or affected < 1 then return fail('sv_try_again', 'delete affected 0 rows') end
    if value > 0 then Player.Functions.AddMoney(Config.MoneyType, value, 'rsg-wagons trade-in') end
    pcall(function() exports['rsg-inventory']:ClearStash('wagon_' .. id) end)

    notify(src, locale('sv_sold', row.name, value), 'success')
    cb(true, getOwned(Player.PlayerData.citizenid))
end)

-- rename an owned wagon
RSGCore.Functions.CreateCallback('rsg-wagons:server:rename', function(source, cb, id, name)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not dbReady then return cb(false) end
    if onCooldown(source) then notify(source, locale('sv_slow_down'), 'error') return cb(false) end
    id = tonumber(id)
    local clean = sanitizeName(name, nil)
    if not id or not clean then return cb(false) end
    local affected = MySQL.update.await('UPDATE player_wagons SET name = ? WHERE id = ? AND citizenid = ?', { clean, id, Player.PlayerData.citizenid })
    if not affected or affected < 1 then return cb(false) end
    cb(true, getOwned(Player.PlayerData.citizenid))
end)

-- ===================== SEND AWAY / CALL =====================
-- send the wagon away: it stays "out" (not stored) but is removed from the world until called
RSGCore.Functions.CreateCallback('rsg-wagons:server:fleeWagon', function(source, cb, condition)
    local src = source
    local active = activeWagons[src]
    if not active or active.pending then return cb(false) end
    if onCooldown(src) then notify(src, locale('sv_slow_down'), 'error') return cb(false) end
    condition = reportedCondition(active, condition)
    MySQL.update.await('UPDATE player_wagons SET wagon_condition = ? WHERE id = ?', { condition, active.id })
    active.condition = condition
    local ent = active.netId and NetworkGetEntityFromNetworkId(active.netId) or 0
    if ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
    active.netId = nil
    cb(true)
end)

-- call the wagon back: removes any old copy and lets the client spawn it near the player
RSGCore.Functions.CreateCallback('rsg-wagons:server:callWagon', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local active = activeWagons[src]
    if not Player or not active then notify(src, locale('sv_none_out'), 'error') return cb(false) end
    if active.pending then return cb(false) end
    if onCooldown(src) then notify(src, locale('sv_slow_down'), 'error') return cb(false) end
    local row = getRow(active.id, Player.PlayerData.citizenid)
    if not row or not Config.Wagons[row.model] then return cb(false) end
    if (active.condition or row.wagon_condition) <= 0 then notify(src, locale('sv_wrecked'), 'error') return cb(false) end
    local ent = active.netId and NetworkGetEntityFromNetworkId(active.netId) or 0
    if ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
    active.netId, active.pending, active.called = nil, true, true
    active.look = lookOf(row)
    active.condition = row.wagon_condition
    cb(true, { id = row.id, model = row.model, name = row.name, condition = row.wagon_condition, livery = row.livery or -1, tint = row.tint or -1 })
end)

-- ===================== CUSTOMISE (cargo / lanterns) =====================
RSGCore.Functions.CreateCallback('rsg-wagons:server:setLook', function(source, cb, propset, lantern)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local active = activeWagons[src]
    if not Player or not active or not active.netId then return cb(false) end
    if onCooldown(src) then notify(src, locale('sv_slow_down'), 'error') return cb(false) end
    local ent = NetworkGetEntityFromNetworkId(active.netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return cb(false) end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent)) > Config.UseDistance + 4.0 then
        notify(src, locale('sv_wagon_too_far'), 'error')
        return cb(false)
    end
    local row = getRow(active.id, Player.PlayerData.citizenid)
    if not row then return cb(false) end
    local p = validPropset(Config.Propsets, row.model, propset)
    local l = validPropset(Config.Lanterns, row.model, lantern)
    MySQL.update.await("UPDATE player_wagons SET propset = NULLIF(?, ''), lantern = NULLIF(?, '') WHERE id = ?", { p or '', l or '', row.id })
    row.propset, row.lantern = p, l
    active.look = lookOf(row)
    Entity(ent).state:set('rsgWagonLook', active.look, true)
    notify(src, locale('sv_custom_saved'), 'success')
    cb(true, active.look)
end)

-- ===================== REPAIRS =====================
local function chargeRepair(src, Player)
    local c = Config.FieldRepair.cost or {}
    if c.type == 'item' then
        local item = Player.Functions.GetItemByName(c.item)
        if not item or (item.amount or 0) < (c.amount or 1) then
            local label = (RSGCore.Shared.Items[c.item] and RSGCore.Shared.Items[c.item].label) or c.item
            notify(src, locale('sv_repair_need_item', c.amount or 1, label), 'error')
            return false
        end
        if not Player.Functions.RemoveItem(c.item, c.amount or 1) then return false end
        if RSGCore.Shared.Items[c.item] then
            TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[c.item], 'remove', c.amount or 1)
        end
        return true
    end
    if not Player.Functions.RemoveMoney(Config.MoneyType, c.amount or 0, 'rsg-wagons field repair') then
        notify(src, locale('sv_repair_no_money'), 'error')
        return false
    end
    return true
end

-- patch the wagon that's out (damaged or wrecked) up to FieldRepair.condition
RSGCore.Functions.CreateCallback('rsg-wagons:server:fieldRepair', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local active = activeWagons[src]
    if not Config.FieldRepair.enabled or not Player then return cb(false) end
    if not active then notify(src, locale('sv_none_out'), 'error') return cb(false) end
    if active.pending then return cb(false) end
    if onCooldown(src) then notify(src, locale('sv_slow_down'), 'error') return cb(false) end
    local row = getRow(active.id, Player.PlayerData.citizenid)
    if not row then return cb(false) end
    local current = active.condition or row.wagon_condition
    local target = Config.FieldRepair.condition
    if current >= target then notify(src, locale('sv_repair_not_needed', target .. '%'), 'inform') return cb(false) end

    -- a wagon in the world must be within reach; a wrecked one can be patched from anywhere
    local ent = active.netId and NetworkGetEntityFromNetworkId(active.netId) or 0
    if current > 0 and ent ~= 0 and DoesEntityExist(ent)
        and #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent)) > Config.UseDistance + 4.0 then
        notify(src, locale('sv_wagon_too_far'), 'error')
        return cb(false)
    end
    if not chargeRepair(src, Player) then return cb(false) end

    if current <= 0 and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) active.netId = nil end -- clear the wreck
    MySQL.update.await('UPDATE player_wagons SET wagon_condition = ? WHERE id = ?', { target, active.id })
    active.condition = target
    notify(src, locale('sv_repair_patched', target .. '%'), 'success')
    cb(true, target, current <= 0)
end)

-- full repair of a stored wagon at a yard
RSGCore.Functions.CreateCallback('rsg-wagons:server:yardRepair', function(source, cb, storeKey, id)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not dbReady or not Config.YardRepair.enabled then return cb(false) end
    if onCooldown(src) then notify(src, locale('sv_slow_down'), 'error') return cb(false) end
    id = tonumber(id)
    if not id or not Config.Stores[storeKey] then return cb(false) end
    if not nearStore(src, storeKey) then notify(src, locale('sv_too_far'), 'error') return cb(false) end
    local row = getRow(id, Player.PlayerData.citizenid)
    if not row then return cb(false) end
    if row.active == 1 or (activeWagons[src] and activeWagons[src].id == id) then
        notify(src, locale('sv_store_first'), 'error')
        return cb(false)
    end
    if row.wagon_condition >= 100 then return cb(false) end
    local price = math.ceil((100 - row.wagon_condition) * Config.YardRepair.pricePerPercent)
    if price > 0 and not Player.Functions.RemoveMoney(Config.MoneyType, price, 'rsg-wagons yard repair') then
        notify(src, locale('sv_repair_no_money'), 'error')
        return cb(false)
    end
    MySQL.update.await('UPDATE player_wagons SET wagon_condition = 100 WHERE id = ?', { id })
    notify(src, locale('sv_repaired', price), 'success')
    cb(true, getOwned(Player.PlayerData.citizenid))
end)

-- ===================== HUNTING CART (stow carcasses, sell the load) =====================
local function activeCart(src, Player)
    local active = activeWagons[src]
    if not active or not active.netId or not isHuntCart(active.model) then return nil end
    local ent = NetworkGetEntityFromNetworkId(active.netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent)) > Config.UseDistance + 4.0 then
        notify(src, locale('sv_wagon_too_far'), 'error')
        return nil
    end
    local row = getRow(active.id, Player.PlayerData.citizenid)
    if not row then return nil end
    return active, ent, row
end

local function saveCargo(active, ent, row, cargo)
    MySQL.update.await('UPDATE player_wagons SET cargo = ? WHERE id = ?', { json.encode(cargo), row.id })
    row.cargo = json.encode(cargo)
    active.look = lookOf(row)
    Entity(ent).state:set('rsgWagonLook', active.look, true)
end

RSGCore.Functions.CreateCallback('rsg-wagons:server:stowCarcass', function(source, cb, netId, quality)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not HC.enabled then return cb(false) end
    if onCooldown(src) then notify(src, locale('sv_slow_down'), 'error') return cb(false) end
    local active, cart, row = activeCart(src, Player)
    if not active then return cb(false) end

    local cargo = getCargo(row)
    if #cargo >= (HC.capacity or 20) then notify(src, locale('sv_cart_full', #cargo .. '/' .. HC.capacity), 'error') return cb(false) end

    netId = math.tointeger(tonumber(netId))
    local carcass = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if not carcass or carcass == 0 or not DoesEntityExist(carcass) or GetEntityType(carcass) ~= 1 or IsPedAPlayer(carcass) then
        notify(src, locale('sv_not_carcass'), 'error') return cb(false)
    end
    if GetEntityHealth(carcass) > 0 then notify(src, locale('sv_not_dead'), 'error') return cb(false) end
    local model = GetEntityModel(carcass)
    local animal = HC.animals and HC.animals[model]
    if not animal then notify(src, locale('sv_not_carcass'), 'error') return cb(false) end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(carcass)) > (HC.horseRange or 6.0) + 2.0 then
        notify(src, locale('sv_not_carcass'), 'error') return cb(false)
    end
    if not (HC.qualityMultiplier or {})[quality] then quality = 'poor' end

    DeleteEntity(carcass)
    cargo[#cargo + 1] = { m = model, q = quality }
    saveCargo(active, cart, row, cargo)
    notify(src, locale('sv_stowed', animal.name, #cargo .. '/' .. HC.capacity), 'success')
    cb(true, #cargo)
end)

local function nearButcher(coords)
    for _, b in ipairs(HC.butchers or {}) do
        if #(coords - b.coords) <= (HC.sellRange or 25.0) then return b end
    end
    return nil
end

RSGCore.Functions.CreateCallback('rsg-wagons:server:sellCargo', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not HC.enabled then return cb(false) end
    if onCooldown(src) then notify(src, locale('sv_slow_down'), 'error') return cb(false) end
    local active, cart, row = activeCart(src, Player)
    if not active then return cb(false) end
    local butcher = nearButcher(GetEntityCoords(cart))
    if not butcher then notify(src, locale('sv_no_butcher'), 'error') return cb(false) end
    local cargo = getCargo(row)
    if #cargo == 0 then notify(src, locale('sv_cart_empty'), 'error') return cb(false) end

    local cash, items, xp = 0, {}, 0
    for _, c in ipairs(cargo) do
        local animal = HC.animals[c.m]
        if animal then
            local mult = HC.qualityMultiplier[c.q] or 1
            cash = cash + (tonumber(animal.money) or 0) * mult
            for _, name in ipairs(animal.items or {}) do
                if RSGCore.Shared.Items[name] then items[name] = (items[name] or 0) + (HC.itemQuantity[c.q] or 1) end
            end
            xp = xp + (HC.xpPerCarcass or 0) * mult
        end
    end
    -- items first: if they don't fit, keep the load
    for name, qty in pairs(items) do
        if not exports['rsg-inventory']:CanAddItem(src, name, qty) then
            notify(src, locale('sv_inventory_full'), 'error')
            return cb(false)
        end
    end

    saveCargo(active, cart, row, {})
    cash = math.floor(cash * 100 + 0.5) / 100
    if cash > 0 then Player.Functions.AddMoney(HC.moneyType or 'cash', cash, 'rsg-wagons hunting cart') end
    for name, qty in pairs(items) do exports['rsg-inventory']:AddItem(src, name, qty, nil, nil, 'rsg-wagons hunting cart') end
    if xp > 0 and GetResourceState('rsg-hunting') == 'started' then
        pcall(function() exports['rsg-hunting']:AwardHuntingXP(src, xp) end)
    end
    notify(src, locale('sv_load_sold', tostring(#cargo), ('%.2f'):format(cash)), 'success')
    TriggerEvent('rsg-log:server:CreateLog', 'shops', 'Hunting Cart Sold', 'green',
        ('%s (%s) sold %d carcasses at %s for $%.2f'):format(GetPlayerName(src), Player.PlayerData.citizenid, #cargo, butcher.name, cash))
    cb(true, cash, #cargo)
end)

-- ===================== WAGON STORAGE =====================
RegisterNetEvent('rsg-wagons:server:openStorage', function(netId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local wagonId = Entity(ent).state.rsgWagonId
    if not wagonId then
        -- fall back to the server's own record of this player's active wagon
        local active = activeWagons[src]
        if active and active.netId == tonumber(netId) then wagonId = active.id end
    end
    if not wagonId then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent)) > Config.UseDistance + 2.0 then return end

    local row = getRow(wagonId, Player.PlayerData.citizenid)
    if not row then notify(src, locale('sv_not_yours'), 'error') return end
    local data = Config.Wagons[row.model]
    if not data then return end

    exports['rsg-inventory']:OpenInventory(src, 'wagon_' .. wagonId, {
        label = row.name,
        maxweight = data.weight * 1000,
        slots = data.slots,
    })
end)

-- ===================== CLEANUP =====================
AddEventHandler('playerDropped', function()
    local src = source
    despawnActive(src, false) -- stays out: callable after reconnecting
    cooldowns[src] = nil
end)

-- character logout without leaving the server (multicharacter)
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    despawnActive(src, false)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(activeWagons) do despawnActive(src, false) end
end)

-- ===================== RESTORE AFTER RESTART / RELOG =====================
-- condition 0 in the database marks a wagon that was wrecked while out
RegisterNetEvent('rsg-wagons:server:restore', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or activeWagons[src] then return end
    local timeout = GetGameTimer() + 10000
    while not dbReady and GetGameTimer() < timeout do Wait(250) end
    if not dbReady then return end
    local cid = Player.PlayerData.citizenid
    local rows = MySQL.query.await('SELECT id, model, name, wagon_condition FROM player_wagons WHERE citizenid = ? AND active = 1 ORDER BY id', { cid }) or {}
    if #rows == 0 then return end
    local row = rows[1]
    -- only one wagon can be out: put any extras back at their yard
    for i = 2, #rows do MySQL.update('UPDATE player_wagons SET active = 0 WHERE id = ?', { rows[i].id }) end
    if not Config.Wagons[row.model] then
        MySQL.update('UPDATE player_wagons SET active = 0 WHERE id = ?', { row.id })
        return
    end
    activeWagons[src] = { id = row.id, netId = nil, model = row.model, condition = row.wagon_condition }
    TriggerClientEvent('rsg-wagons:client:restore', src, {
        id = row.id, name = row.name, model = row.model,
        condition = row.wagon_condition, wrecked = row.wagon_condition <= 0,
    })
end)

-- the client reports the wagon's condition now and then, so it survives a restart
RegisterNetEvent('rsg-wagons:server:condition', function(condition, wrecked)
    local src = source
    local active = activeWagons[src]
    if not active then return end
    if wrecked == true then
        active.condition = 0 -- 0 = wrecked (only ever set here)
        MySQL.update('UPDATE player_wagons SET wagon_condition = 0 WHERE id = ?', { active.id })
        return
    end
    active.condition = reportedCondition(active, condition) -- stays 0 (wrecked) until patched or returned
end)

-- ===================== EXPORTS =====================
exports('GetActiveWagon', function(src)
    local a = activeWagons[src]
    if not a then return nil end
    return { id = a.id, netId = a.netId, model = a.model }
end)

exports('GetPlayerWagons', function(citizenid)
    return getOwned(citizenid)
end)
