local RSGCore = exports['rsg-core']:GetCoreObject()

-- The wagon is spawned and owned by a player's client. The server does NOT depend on being
-- able to see that entity: it keeps a registry entry per gang that nearby clients keep alive
-- with heartbeats (position included), and tells clients to delete the wagon when needed.
--   gangWagons[gangName] = { netId, coords = vector3, heading, seen = os.time() }
local gangWagons = {}
local pendingSpawns = {} -- [gangName] = os.time() the spawn request expires (stops double requests)

local SPAWN_REQUEST_SECONDS = 20
local HEARTBEAT_TIMEOUT_SECONDS = 20
local WAGON_RESET_COOLDOWN_SECONDS = 30
local wagonResetCooldowns = {}

local setWagonLocation

local function dbg(...)
    if Config.DebugWagon then print('^5[rsg-gangs:wagon]^7', ...) end
end

-- Live position of a spawned wagon (last heartbeat). Used for despawn checks and equipment
-- distance instead of the saved parking spot, because a driven wagon can be far from it.
local function wagonLiveCoords(gangName)
    local entry = gangWagons[gangName]
    return entry and entry.coords or nil
end

RSGGangs.WagonLiveCoords = wagonLiveCoords

-- Drops the registry entry and tells every client to delete the wagon if they have it.
local function deleteGangWagon(gangName)
    local entry = gangWagons[gangName]
    if entry then
        gangWagons[gangName] = nil
        TriggerClientEvent('rsg-gangs:client:despawnGangWagon', -1, gangName, entry.netId)
        TriggerClientEvent('rsg-gangs:client:wagonUnregistered', -1, gangName)
        dbg('deleted wagon of', gangName)
    end
    pendingSpawns[gangName] = nil
end

RSGGangs.DeleteGangWagon = deleteGangWagon

-- Saves a new parking spot for a gang's wagon (memory + database).
setWagonLocation = function(gang, coords, heading)
    local wagon = { x = coords.x, y = coords.y, z = coords.z, heading = heading }
    if not RSGGangs.DbOk(
        'UPDATE rsg_gangs SET wagon_x = ?, wagon_y = ?, wagon_z = ?, wagon_heading = ? WHERE name = ?',
        { wagon.x, wagon.y, wagon.z, wagon.heading, gang.name }
    ) then
        return false
    end
    gang.wagon = wagon
    dbg('saved parking spot for', gang.name, wagon.x, wagon.y, wagon.z)
    return true
end

RSGGangs.SetWagonLocation = setWagonLocation

-- Asks one client to spawn the wagon and gives it the one-off right to register what it spawned.
local function requestClientSpawn(src, gang)
    pendingSpawns[gang.name] = os.time() + SPAWN_REQUEST_SECONDS
    RSGGangs.Grant(src, 'wagon:' .. gang.name, SPAWN_REQUEST_SECONDS + 30)
    TriggerClientEvent('rsg-gangs:client:spawnGangWagonAt', src, gang.name, gang.wagon)
    dbg('asked', src, 'to spawn the wagon of', gang.name)
end

local function memberGang(src)
    local citizenid = RSGGangs.GetPlayerCitizenId(src)
    if not citizenid then return nil end
    return RSGGangs.FindGangByMember(citizenid), citizenid
end

---------------------------------------------------------------------
-- Wagon placement
---------------------------------------------------------------------
-- The client found a free spot after the gang was created. Only accepted with the grant the
-- server issued at creation, and only close to the player who is standing there.
RegisterNetEvent('rsg-gangs:server:gangVehicleSpotFound', function(gangName, coords, heading)
    local src = source
    if type(gangName) ~= 'string' or not RSGGangs.ValidCoords(coords) or not RSGGangs.IsFinite(heading) then return end
    if not RSGGangs.ConsumeGrant(src, 'spot:' .. gangName) then return end

    local gang, citizenid = memberGang(src)
    if not gang or gang.name ~= gangName then return end
    -- The spot may be on a road up to maxRoadDistance away from the founder.
    if not RSGGangs.IsNear(src, coords, math.max(60.0, (Config.GangVehicle.maxRoadDistance or 0.0) + 15.0)) then return end

    if setWagonLocation(gang, coords, heading) then
        -- The founder's client spawns the first wagon itself; keep the streaming loop from asking twice.
        pendingSpawns[gang.name] = os.time() + SPAWN_REQUEST_SECONDS
    end
end)

RegisterNetEvent('rsg-gangs:server:gangVehicleSpotFailed', function()
    RSGGangs.Notify(source, locale('notify_wagon_no_clear_space'), 'error')
end)

-- Clients near the wagon report it every few seconds. Any nearby client keeps it alive; only a
-- member of the owning gang can move its saved parking spot.
local function onHeartbeat(src, gangName, netId, coords, heading, stationary)
    if type(gangName) ~= 'string' or type(netId) ~= 'number' then return end
    if not RSGGangs.ValidCoords(coords) or not RSGGangs.IsFinite(heading) then return end
    if RSGGangs.OnCooldown(src, 'wagonBeat', 1500) then return end

    local entry = gangWagons[gangName]
    local gang = RSGGangs.Gangs[gangName]
    if not entry or not gang or entry.netId ~= netId then return end
    if not RSGGangs.IsNear(src, coords, 150.0) then return end

    local pos = vector3(coords.x, coords.y, coords.z)
    local member = memberGang(src)
    entry.seen = os.time()

    if member and member.name == gangName then
        entry.coords = pos
        entry.heading = heading
        if stationary and gang.wagon and not RSGGangs.GangHasDeployedEquipment(gangName)
            and #(pos - vector3(gang.wagon.x, gang.wagon.y, gang.wagon.z)) > 1.0 then
            setWagonLocation(gang, pos, heading)
        end
    end
end

RegisterNetEvent('rsg-gangs:server:wagonHeartbeat', function(...) onHeartbeat(source, ...) end)
-- Kept for the "driver got out" report.
RegisterNetEvent('rsg-gangs:server:gangWagonMoved', function(gangName, coords, heading)
    onHeartbeat(source, gangName, gangWagons[gangName] and gangWagons[gangName].netId, coords, heading, true)
end)

-- The client reports the wagon it spawned. Accepted only with a server grant. The server checks the
-- entity only when it can see it; it never rejects a wagon just because it cannot.
RegisterNetEvent('rsg-gangs:server:gangWagonSpawned', function(gangName, netId, coords, heading)
    local src = source
    if type(gangName) ~= 'string' or type(netId) ~= 'number' then return end
    if not RSGGangs.ConsumeGrant(src, 'wagon:' .. gangName) then return end

    local gang = RSGGangs.Gangs[gangName]
    if not gang or not gang.wagon then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity ~= 0 and DoesEntityExist(entity) then
        if GetEntityType(entity) ~= 2 or GetEntityModel(entity) ~= joaat(Config.GangVehicle.model) then
            DeleteEntity(entity)
            return
        end
    end

    local existing = gangWagons[gangName]
    if existing and existing.netId ~= netId and (os.time() - existing.seen) < HEARTBEAT_TIMEOUT_SECONDS then
        -- A live wagon is already registered: this one is a duplicate, tell clients to remove it.
        TriggerClientEvent('rsg-gangs:client:despawnGangWagon', -1, gangName, netId)
        pendingSpawns[gangName] = nil
        return
    end

    local pos = RSGGangs.ValidCoords(coords) and vector3(coords.x, coords.y, coords.z)
        or vector3(gang.wagon.x, gang.wagon.y, gang.wagon.z)
    gangWagons[gangName] = { netId = netId, coords = pos, heading = heading or gang.wagon.heading or 0.0, seen = os.time() }
    pendingSpawns[gangName] = nil
    TriggerClientEvent('rsg-gangs:client:wagonRegistered', -1, gangName, netId)
    dbg('registered wagon of', gangName, 'net id', netId)
end)

RegisterNetEvent('rsg-gangs:server:requestWagonRegistry', function()
    local src = source
    if RSGGangs.OnCooldown(src, 'wagonRegistry', 2000) then return end
    local registry = {}
    for gangName, entry in pairs(gangWagons) do registry[gangName] = entry.netId end
    TriggerClientEvent('rsg-gangs:client:wagonRegistrySync', src, registry)
end)

---------------------------------------------------------------------
-- Respawn a stuck wagon (needs the 'equipment' permission)
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:resetWagon', function()
    local src = source
    local gang, citizenid = memberGang(src)
    if not gang then RSGGangs.Notify(src, locale('error_no_gang'), 'error') return end

    if not RSGGangs.HasPermission(gang, citizenid, 'equipment') then
        RSGGangs.Notify(src, locale('error_no_permission'), 'error')
        return
    end

    if not gang.wagon then
        RSGGangs.Notify(src, locale('error_equipment_no_wagon'), 'error')
        return
    end

    -- The player has to be at the wagon they are resetting.
    local live = wagonLiveCoords(gang.name)
    local reference = live or vector3(gang.wagon.x, gang.wagon.y, gang.wagon.z)
    if not RSGGangs.IsNear(src, reference, Config.WagonInteractDistance) then
        RSGGangs.Notify(src, locale('error_too_far'), 'error')
        return
    end

    local last = wagonResetCooldowns[gang.name]
    if last and (os.time() - last) < WAGON_RESET_COOLDOWN_SECONDS then
        RSGGangs.Notify(src, locale('error_wagon_reset_cooldown', WAGON_RESET_COOLDOWN_SECONDS), 'error')
        return
    end
    wagonResetCooldowns[gang.name] = os.time()

    deleteGangWagon(gang.name)
    requestClientSpawn(src, gang)
    RSGGangs.Notify(src, locale('success_wagon_reset'), 'success')
end)

---------------------------------------------------------------------
-- Proximity streaming: a wagon exists only while someone is near it.
---------------------------------------------------------------------
CreateThread(function()
    while not RSGGangs.Loaded do Wait(100) end

    while true do
        local positions = RSGGangs.PlayerPositions()
        local now = os.time()

        for gangName, gang in pairs(RSGGangs.Gangs) do
            if gang.wagon then
                local entry = gangWagons[gangName]
                if entry and (now - entry.seen) > HEARTBEAT_TIMEOUT_SECONDS then
                    -- Nobody has seen it for a while (destroyed, or its clients left): forget it.
                    dbg('wagon of', gangName, 'timed out')
                    deleteGangWagon(gangName)
                    entry = nil
                end

                if entry then
                    if not RSGGangs.NearestPlayer(positions, entry.coords, Config.DespawnProximityRadius) then
                        deleteGangWagon(gangName)
                    end
                else
                    local waiting = pendingSpawns[gangName]
                    if not waiting or waiting < now then
                        pendingSpawns[gangName] = nil
                        local coords = vector3(gang.wagon.x, gang.wagon.y, gang.wagon.z)
                        local src = RSGGangs.NearestPlayer(positions, coords, Config.RespawnProximityRadius)
                        if src then
                            requestClientSpawn(src, gang)
                            Wait(500) -- stagger so a burst of nearby gangs does not spawn on one tick
                        end
                    end
                end
            end
        end

        Wait(Config.ProximityCheckInterval)
    end
end)
