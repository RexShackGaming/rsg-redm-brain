-- rsg-lumberjack - Server
-- Ground logs, wood piles, wagon loads and carry state are in-memory only and
-- reset on resource restart. Planted trees persist in `rsg_lumberjack_trees`.

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- ============================================================================
-- STATE
-- ============================================================================
local PlantedTrees = {}     -- [id] = { id, owner_citizenid, x, y, z, heading, stage, state, watered, next_ts }
local GroundLogs = {}       -- [id] = { id, x, y, z, createdAt }
local WoodPieces = {}       -- [id] = { id, x, y, z, createdAt }
local WagonLoads = {}       -- [wagonNetId] = log count (authoritative)
local CarryingPlayers = {}  -- [src] = true
local PendingActions = {}   -- [src] = { kind, targetId, startedAt, duration }
local LastChopAt = {}       -- [src] = GetGameTimer()
local PlantingPlayers = {}  -- [src] = true while a DB insert is in flight
local LastSyncAt = {}       -- [src] = GetGameTimer() of last full sync

local nextLogId, nextWoodId = 1, 1

-- ============================================================================
-- HELPERS
-- ============================================================================
local function DebugPrint(...)
    if Config.Debug then print('[rsg-lumberjack]', ...) end
end

local function Notify(src, key, args, ntype)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('notify_title'),
        description = args and locale(key, table.unpack(args)) or locale(key),
        type = ntype or 'inform',
        duration = 5000
    })
end

local function NotifySuccess(src, key, args) Notify(src, key, args, 'success') end
local function NotifyError(src, key, args) Notify(src, key, args, 'error') end

local function IsFiniteNumber(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

local function GetPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function IsPlayerNear(src, x, y, z, maxDist)
    local c = GetPlayerCoords(src)
    if not c then return false end
    return #(c - vector3(x, y, z)) <= maxDist
end

local function HasItem(src, item)
    return exports['rsg-inventory']:HasItem(src, item, 1)
end

local function RemoveItem(src, item, reason)
    if exports['rsg-inventory']:RemoveItem(src, item, 1, nil, reason) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', 1)
        return true
    end
    return false
end

local function ToList(tbl)
    local list = {}
    for _, v in pairs(tbl) do list[#list + 1] = v end
    return list
end

local function GetGrowthDuration(stage)
    return Config.Planting.GrowthDurations[math.max(1, math.min(stage, 3))] or 60
end

-- Payload sent to clients. Includes seconds remaining *now* so clients can draw
-- a progress bar without relying on their own wall clock.
local function BuildTreePayload(t)
    local payload = {
        id = t.id,
        owner_citizenid = t.owner_citizenid,
        x = t.x, y = t.y, z = t.z,
        heading = t.heading,
        stage = t.stage,
        state = t.state,
        watered = t.watered,
    }
    if t.state == 'growing' and t.next_ts then
        payload.growth_duration = GetGrowthDuration(t.stage)
        payload.growth_remaining = math.max(0, t.next_ts - os.time())
    end
    return payload
end

local function BroadcastTree(t)
    TriggerClientEvent('rsg-lumberjack:client:updateTreeVisual', -1, BuildTreePayload(t))
end

-- Carry state: the owning client gets an event; everyone else reads the
-- replicated player state bag so late joiners / players streaming in see it.
local function SetCarrying(src, carrying)
    CarryingPlayers[src] = carrying or nil
    Player(src).state:set('lumberjackCarrying', carrying or nil, true)
    TriggerClientEvent(carrying and 'rsg-lumberjack:client:startCarrying' or 'rsg-lumberjack:client:stopCarrying', src)
end

-- ============================================================================
-- TREE PERSISTENCE
-- ============================================================================
-- Starts the growth timer for a tree's current stage once watering (if
-- required) is satisfied.
local function MaybeScheduleGrowth(t)
    if not t or t.stage >= 4 or t.state == 'growing' then return end
    if Config.Planting.RequireWater and t.watered ~= 1 then return end

    t.next_ts = os.time() + GetGrowthDuration(t.stage)
    t.state = 'growing'
    MySQL.update('UPDATE rsg_lumberjack_trees SET state = ?, next_stage_at = FROM_UNIXTIME(?) WHERE id = ?', { 'growing', t.next_ts, t.id })
    DebugPrint('Tree', t.id, 'growing, next stage at', t.next_ts)
end

CreateThread(function()
    -- Clear stale carry state bags left over from before a resource restart
    for _, id in ipairs(GetPlayers()) do
        Player(tonumber(id)).state:set('lumberjackCarrying', nil, true)
    end

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rsg_lumberjack_trees` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(64) NOT NULL,
            `owner_citizenid` VARCHAR(50) NOT NULL,
            `x` DOUBLE NOT NULL,
            `y` DOUBLE NOT NULL,
            `z` DOUBLE NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0,
            `model` VARCHAR(64) NOT NULL DEFAULT 'p_tree_birch_01_sapling',
            `stage` TINYINT UNSIGNED NOT NULL DEFAULT 1,
            `state` ENUM('planted','growing','ready','chopped') NOT NULL DEFAULT 'planted',
            `watered` TINYINT(1) NOT NULL DEFAULT 0,
            `fertilized` TINYINT(1) NOT NULL DEFAULT 0,
            `planted_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `next_stage_at` DATETIME NULL,
            PRIMARY KEY (`id`),
            INDEX `idx_owner` (`owner_citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- UNIX_TIMESTAMP avoids oxmysql's DATETIME -> millisecond conversion, which
    -- previously broke growth for every tree after a restart.
    local rows = MySQL.query.await([[
        SELECT id, owner_citizenid, x, y, z, heading, stage, state, watered,
               UNIX_TIMESTAMP(next_stage_at) AS next_ts
        FROM rsg_lumberjack_trees WHERE state != 'chopped'
    ]]) or {}

    PlantedTrees = {}
    for _, r in ipairs(rows) do
        local t = {
            id = r.id,
            owner_citizenid = r.owner_citizenid,
            x = r.x, y = r.y, z = r.z,
            heading = r.heading or 0.0,
            stage = tonumber(r.stage) or 1,
            state = r.state,
            watered = tonumber(r.watered) or 0,
            next_ts = tonumber(r.next_ts),
        }
        if t.state == 'growing' and not t.next_ts then t.state = 'planted' end
        PlantedTrees[t.id] = t
        MaybeScheduleGrowth(t) -- resumes trees that don't need watering
    end
    DebugPrint('Loaded', #rows, 'planted trees')

    -- Push to anyone already online (resource restart)
    TriggerClientEvent('rsg-lumberjack:client:setTrees', -1, (function()
        local list = {}
        for _, t in pairs(PlantedTrees) do list[#list + 1] = BuildTreePayload(t) end
        return list
    end)())
end)

-- ============================================================================
-- USEABLE ITEMS
-- ============================================================================
RSGCore.Functions.CreateUseableItem(Config.Planting.SeedItem, function(src)
    TriggerClientEvent('rsg-lumberjack:client:useSeed', src)
end)

RSGCore.Functions.CreateUseableItem(Config.Planting.WaterItem, function(src)
    TriggerClientEvent('rsg-lumberjack:client:useWater', src)
end)

-- ============================================================================
-- INITIAL SYNC (on player load / resource start)
-- ============================================================================
RegisterNetEvent('rsg-lumberjack:server:requestSync', function()
    local src = source
    local now = GetGameTimer()
    if LastSyncAt[src] and now - LastSyncAt[src] < 5000 then return end -- full sync is heavy; block spam
    LastSyncAt[src] = now
    TriggerClientEvent('rsg-lumberjack:client:syncGroundLogs', src, ToList(GroundLogs))
    TriggerClientEvent('rsg-lumberjack:client:syncWoodPieces', src, ToList(WoodPieces))
    if CarryingPlayers[src] then TriggerClientEvent('rsg-lumberjack:client:startCarrying', src) end

    local trees = {}
    for _, t in pairs(PlantedTrees) do trees[#trees + 1] = BuildTreePayload(t) end
    TriggerClientEvent('rsg-lumberjack:client:setTrees', src, trees)
end)

-- ============================================================================
-- SECURE CHOP ACTION (wild tree / ground log / planted tree)
-- The client requests authorisation, runs the progress bar, then reports
-- completion. The server validates axe, cooldown, carry state, proximity and
-- elapsed time before granting anything.
-- ============================================================================
local VALID_KINDS = { wildtree = true, groundlog = true, plantedtree = true }

-- Returns an error locale key or nil when the target is valid for this player
local function ValidateChopTarget(src, kind, targetId)
    local maxDist = Config.Chopping.ServerDistance
    if kind == 'groundlog' then
        local log = GroundLogs[targetId]
        if not log then return 'log_not_found' end
        if not IsPlayerNear(src, log.x, log.y, log.z, maxDist) then return 'not_nearby' end
    elseif kind == 'plantedtree' then
        local t = PlantedTrees[targetId]
        if not t then return 'tree_not_found' end
        if t.stage < 4 or t.state ~= 'ready' then return 'tree_not_ready' end
        if not IsPlayerNear(src, t.x, t.y, t.z, maxDist) then return 'not_nearby' end
    end
    if kind ~= 'groundlog' and CarryingPlayers[src] then return 'already_carrying' end
    return nil
end

RSGCore.Functions.CreateCallback('rsg-lumberjack:server:requestChop', function(source, cb, kind, targetId)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return cb({ ok = false }) end
    if not VALID_KINDS[kind] or type(targetId) ~= 'number' then return cb({ ok = false, reason = 'invalid_request' }) end

    local now = GetGameTimer()
    local elapsedSinceChop = now - (LastChopAt[src] or -math.huge)
    if elapsedSinceChop < Config.Chopping.ChopCooldownMs then
        return cb({ ok = false, reason = 'cooldown_wait', args = { math.ceil((Config.Chopping.ChopCooldownMs - elapsedSinceChop) / 1000) } })
    end

    local pending = PendingActions[src]
    if pending and (now - pending.startedAt) < (pending.duration + Config.Chopping.ActionTimeoutMs) then
        return cb({ ok = false, reason = 'busy' })
    end

    if Config.Chopping.RequireAxe and not HasItem(src, Config.Chopping.AxeItem) then
        return cb({ ok = false, reason = 'need_axe' })
    end

    local err = ValidateChopTarget(src, kind, targetId)
    if err then return cb({ ok = false, reason = err }) end

    local duration = kind == 'groundlog' and Config.Chopping.LogChopDuration or Config.Chopping.TreeChopDuration
    PendingActions[src] = { kind = kind, targetId = targetId, startedAt = now, duration = duration }
    cb({ ok = true, duration = duration })
end)

RegisterNetEvent('rsg-lumberjack:server:cancelChop', function()
    PendingActions[source] = nil
end)

RegisterNetEvent('rsg-lumberjack:server:completeChop', function(kind, targetId)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end

    local pending = PendingActions[src]
    PendingActions[src] = nil -- single use

    if not pending or pending.kind ~= kind or pending.targetId ~= targetId then
        return NotifyError(src, 'invalid_request')
    end

    local elapsed = GetGameTimer() - pending.startedAt
    if elapsed < (pending.duration - 1500) then
        return NotifyError(src, 'invalid_request')
    end
    if elapsed > (pending.duration + Config.Chopping.ActionTimeoutMs) then
        return NotifyError(src, 'action_expired')
    end

    -- Re-validate: the target may have been taken, or the player walked away /
    -- picked up another log while the progress bar was running.
    local err = ValidateChopTarget(src, kind, targetId)
    if err then return NotifyError(src, err) end

    LastChopAt[src] = GetGameTimer()

    if kind == 'groundlog' then
        local log = GroundLogs[targetId]
        GroundLogs[targetId] = nil
        TriggerClientEvent('rsg-lumberjack:client:removeGroundLog', -1, targetId)

        local radius = Config.Items.SpawnRadius
        local now = os.time()
        for _ = 1, Config.Items.WoodAmountFromLog do
            local wood = {
                id = nextWoodId,
                x = log.x + (math.random() - 0.5) * radius,
                y = log.y + (math.random() - 0.5) * radius,
                z = log.z,
                createdAt = now,
            }
            nextWoodId = nextWoodId + 1
            WoodPieces[wood.id] = wood
            TriggerClientEvent('rsg-lumberjack:client:addWoodPiece', -1, wood)
        end
        NotifySuccess(src, 'chop_success_log')
    else
        if kind == 'plantedtree' then
            PlantedTrees[targetId] = nil
            MySQL.update('DELETE FROM rsg_lumberjack_trees WHERE id = ?', { targetId })
            TriggerClientEvent('rsg-lumberjack:client:removeTree', -1, targetId)
        end
        SetCarrying(src, true)
        NotifySuccess(src, 'chop_success_tree')
    end

    -- Axe break is rolled server-side
    if Config.Chopping.RequireAxe and Config.Chopping.AxeBreakChance > 0
        and math.random(100) <= Config.Chopping.AxeBreakChance
        and RemoveItem(src, Config.Chopping.AxeItem, 'lumberjack-axe-broke') then
        NotifyError(src, 'axe_broken')
    end

    DebugPrint('Player', src, 'completed chop', kind, targetId)
end)

-- ============================================================================
-- CARRYING / GROUND LOGS / WOOD
-- ============================================================================
RegisterNetEvent('rsg-lumberjack:server:dropLog', function()
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end
    if not CarryingPlayers[src] then return NotifyError(src, 'not_carrying') end

    -- Drop position is derived from the server-side ped, never the client
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local heading = math.rad(GetEntityHeading(ped))
    local log = {
        id = nextLogId,
        x = coords.x - math.sin(heading) * 1.0,
        y = coords.y + math.cos(heading) * 1.0,
        z = coords.z - 1.0,
        createdAt = os.time(),
    }
    nextLogId = nextLogId + 1

    SetCarrying(src, false)
    GroundLogs[log.id] = log
    TriggerClientEvent('rsg-lumberjack:client:addGroundLog', -1, log)
    NotifySuccess(src, 'log_dropped')
end)

RegisterNetEvent('rsg-lumberjack:server:pickupLog', function(logId)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end
    if CarryingPlayers[src] then return NotifyError(src, 'already_carrying') end

    local log = GroundLogs[logId]
    if not log then return NotifyError(src, 'log_not_found') end
    if not IsPlayerNear(src, log.x, log.y, log.z, Config.Chopping.ServerDistance) then return NotifyError(src, 'not_nearby') end

    GroundLogs[logId] = nil
    TriggerClientEvent('rsg-lumberjack:client:removeGroundLog', -1, logId)
    SetCarrying(src, true)
    NotifySuccess(src, 'log_picked_up')
end)

RegisterNetEvent('rsg-lumberjack:server:pickupWood', function(woodId)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end

    local wood = WoodPieces[woodId]
    if not wood then return NotifyError(src, 'wood_not_found') end
    if not IsPlayerNear(src, wood.x, wood.y, wood.z, Config.Chopping.ServerDistance) then return NotifyError(src, 'not_nearby') end

    local item = Config.Items.Wood
    if not exports['rsg-inventory']:CanAddItem(src, item, 1) then return NotifyError(src, 'inventory_full') end

    WoodPieces[woodId] = nil -- claim before adding so a double event can't dupe
    TriggerClientEvent('rsg-lumberjack:client:removeWoodPiece', -1, woodId)

    exports['rsg-inventory']:AddItem(src, item, 1, nil, nil, 'lumberjack-wood-pickup')
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'add', 1)
end)

-- ============================================================================
-- TREE PLANTING / GROWING
-- ============================================================================
RegisterNetEvent('rsg-lumberjack:server:plantTree', function(pos, heading)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or PlantingPlayers[src] then return end

    if type(pos) ~= 'table' or not (IsFiniteNumber(pos.x) and IsFiniteNumber(pos.y) and IsFiniteNumber(pos.z)) then
        return NotifyError(src, 'invalid_location')
    end
    -- The client picks the exact ground point, but it must be right in front of the player
    if not IsPlayerNear(src, pos.x, pos.y, pos.z, Config.Chopping.RaycastDistance + 2.5) then
        return NotifyError(src, 'invalid_location')
    end
    heading = tonumber(heading) or 0.0

    local citizenid = Player.PlayerData.citizenid
    local plantPos = vector3(pos.x, pos.y, pos.z)
    local ownedCount = 0
    for _, t in pairs(PlantedTrees) do
        if t.owner_citizenid == citizenid then ownedCount = ownedCount + 1 end
        if #(vector3(t.x, t.y, t.z) - plantPos) < Config.Planting.MinPlantDistance then
            return NotifyError(src, 'too_close_to_tree')
        end
    end
    if ownedCount >= Config.Planting.MaxTreesPerPlayer then
        return NotifyError(src, 'max_trees_reached', { Config.Planting.MaxTreesPerPlayer })
    end

    if not RemoveItem(src, Config.Planting.SeedItem, 'lumberjack-plant-tree') then
        return NotifyError(src, 'need_seed')
    end

    PlantingPlayers[src] = true
    local license = RSGCore.Functions.GetIdentifier(src, 'license') or citizenid
    local id = MySQL.insert.await(
        'INSERT INTO rsg_lumberjack_trees (identifier, owner_citizenid, x, y, z, heading, model, stage, state) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)',
        { license, citizenid, pos.x, pos.y, pos.z, heading, Config.Planting.StageModels[1], 'planted' }
    )
    PlantingPlayers[src] = nil

    if not id then
        exports['rsg-inventory']:AddItem(src, Config.Planting.SeedItem, 1, nil, nil, 'lumberjack-plant-refund')
        return NotifyError(src, 'error_generic')
    end

    local tree = {
        id = id,
        owner_citizenid = citizenid,
        x = pos.x, y = pos.y, z = pos.z,
        heading = heading,
        stage = 1,
        state = 'planted',
        watered = 0,
    }
    PlantedTrees[id] = tree
    MaybeScheduleGrowth(tree)
    BroadcastTree(tree)
    NotifySuccess(src, Config.Planting.RequireWater and 'tree_planted' or 'tree_planted_nowater')
end)

RegisterNetEvent('rsg-lumberjack:server:waterTree', function(id)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end

    local t = PlantedTrees[id]
    if not t then return NotifyError(src, 'tree_not_found') end
    if t.stage >= 4 then return NotifyError(src, 'tree_already_grown') end
    if t.watered == 1 or t.state == 'growing' then return NotifyError(src, 'tree_already_watered') end
    if not IsPlayerNear(src, t.x, t.y, t.z, Config.Chopping.ServerDistance) then return NotifyError(src, 'not_nearby') end

    if Config.Planting.RequireWater and not RemoveItem(src, Config.Planting.WaterItem, 'lumberjack-water-tree') then
        return NotifyError(src, 'need_water')
    end

    t.watered = 1
    MySQL.update('UPDATE rsg_lumberjack_trees SET watered = 1 WHERE id = ?', { id })
    MaybeScheduleGrowth(t)
    BroadcastTree(t)
    NotifySuccess(src, 'tree_watered')
end)

-- Growth tick
CreateThread(function()
    while true do
        Wait(Config.Planting.GrowthTickSeconds * 1000)
        local now = os.time()

        for id, t in pairs(PlantedTrees) do
            if t.state == 'growing' and t.next_ts and now >= t.next_ts then
                t.stage = math.min(t.stage + 1, 4)
                t.state = t.stage >= 4 and 'ready' or 'planted'
                t.next_ts = nil
                t.watered = 0
                MySQL.update('UPDATE rsg_lumberjack_trees SET stage = ?, state = ?, next_stage_at = NULL, watered = 0 WHERE id = ?', { t.stage, t.state, id })

                MaybeScheduleGrowth(t) -- continues automatically when watering isn't required
                BroadcastTree(t)

                local owner = RSGCore.Functions.GetPlayerByCitizenId(t.owner_citizenid)
                if owner then
                    if t.state == 'ready' then
                        NotifySuccess(owner.PlayerData.source, 'tree_ready')
                    elseif Config.Planting.RequireWater then
                        Notify(owner.PlayerData.source, 'tree_needs_water')
                    end
                end
            end
        end
    end
end)

-- ============================================================================
-- WAGON SYSTEM
-- ============================================================================
local function GetLogWagon(wagonNetId)
    if type(wagonNetId) ~= 'number' then return nil end
    local wagon = NetworkGetEntityFromNetworkId(wagonNetId)
    if not wagon or wagon == 0 or not DoesEntityExist(wagon) or GetEntityModel(wagon) ~= Config.Wagon.Model then
        return nil
    end
    return wagon
end

local function IsPlayerNearEntity(src, entity, maxDist)
    local c = GetPlayerCoords(src)
    return c and #(c - GetEntityCoords(entity)) <= maxDist
end

-- The authoritative log count lives in WagonLoads (clients can write state bags
-- on entities they own). The entity state bag only drives visuals, so every
-- client - including players who stream in later - sees the right stack.
local function SetWagonLogs(wagon, wagonNetId, count)
    WagonLoads[wagonNetId] = count > 0 and count or nil
    Entity(wagon).state:set('lumberjackLogs', count > 0 and count or nil, true)
end

RegisterNetEvent('rsg-lumberjack:server:addLogToWagon', function(wagonNetId)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end
    if not CarryingPlayers[src] then return NotifyError(src, 'not_carrying') end

    local wagon = GetLogWagon(wagonNetId)
    if not wagon then return NotifyError(src, 'need_wagon') end
    if not IsPlayerNearEntity(src, wagon, Config.Wagon.LoadDistance) then return NotifyError(src, 'not_nearby') end

    local count = WagonLoads[wagonNetId] or 0
    if count >= Config.Wagon.MaxLogsOnWagon then return NotifyError(src, 'wagon_full') end

    SetCarrying(src, false)
    SetWagonLogs(wagon, wagonNetId, count + 1)
    NotifySuccess(src, 'log_loaded', { count + 1, Config.Wagon.MaxLogsOnWagon })
end)

RegisterNetEvent('rsg-lumberjack:server:removeLogFromWagon', function(wagonNetId)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end
    if CarryingPlayers[src] then return NotifyError(src, 'already_carrying') end

    local count = WagonLoads[wagonNetId] or 0
    if count <= 0 then return NotifyError(src, 'wagon_empty') end

    local wagon = GetLogWagon(wagonNetId)
    if not wagon then return NotifyError(src, 'need_wagon') end
    if not IsPlayerNearEntity(src, wagon, Config.Wagon.LoadDistance) then return NotifyError(src, 'not_nearby') end

    SetWagonLogs(wagon, wagonNetId, count - 1)
    SetCarrying(src, true)
    NotifySuccess(src, 'log_unloaded')
end)

RegisterNetEvent('rsg-lumberjack:server:sellWagonLoad', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Wagon is resolved from the server-side ped, never from a client-sent id
    local wagon = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if not wagon or wagon == 0 or GetEntityModel(wagon) ~= Config.Wagon.Model then
        return NotifyError(src, 'need_wagon')
    end
    local wagonNetId = NetworkGetNetworkIdFromEntity(wagon)

    local count = WagonLoads[wagonNetId] or 0
    if count < Config.Wagon.MaxLogsOnWagon then
        return NotifyError(src, 'wagon_not_full', { count, Config.Wagon.MaxLogsOnWagon })
    end

    local wagonCoords = GetEntityCoords(wagon)
    local location
    for _, candidate in ipairs(Config.WagonSellLocations) do
        if #(wagonCoords - candidate.coords) <= candidate.radius then
            location = candidate
            break
        end
    end
    if not location then return NotifyError(src, 'not_at_sell_location') end

    SetWagonLogs(wagon, wagonNetId, 0) -- clear first so a double event can't pay twice
    Player.Functions.AddMoney('cash', location.price, 'lumberjack-wagon-sale')
    NotifySuccess(src, 'wagon_sold', { location.price })
    DebugPrint('Player', src, 'sold wagon at', location.coords, 'for', location.price)
end)

-- ============================================================================
-- CLEANUP (expired ground items, deleted wagons, dropped players)
-- ============================================================================
CreateThread(function()
    local lifetime = Config.Items.GroundDespawnMinutes * 60
    while true do
        Wait(60 * 1000)
        local now = os.time()
        for id, log in pairs(GroundLogs) do
            if now - log.createdAt >= lifetime then
                GroundLogs[id] = nil
                TriggerClientEvent('rsg-lumberjack:client:removeGroundLog', -1, id)
            end
        end
        for id, wood in pairs(WoodPieces) do
            if now - wood.createdAt >= lifetime then
                WoodPieces[id] = nil
                TriggerClientEvent('rsg-lumberjack:client:removeWoodPiece', -1, id)
            end
        end
        for netId in pairs(WagonLoads) do
            if not GetLogWagon(netId) then WagonLoads[netId] = nil end -- wagon deleted
        end
    end
end)

local function ClearPlayer(src)
    CarryingPlayers[src] = nil
    PendingActions[src] = nil
    LastChopAt[src] = nil
    PlantingPlayers[src] = nil
    LastSyncAt[src] = nil
end

AddEventHandler('playerDropped', function()
    ClearPlayer(source) -- player state bag is destroyed with the player
end)

-- Character logout / switch: drop the carried log state so it can't follow the next character
-- AddEventHandler (not RegisterNetEvent) so clients can't fire it for other players
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    src = tonumber(src)
    if not src then return end
    if CarryingPlayers[src] then SetCarrying(src, false) end
    ClearPlayer(src)
end)
