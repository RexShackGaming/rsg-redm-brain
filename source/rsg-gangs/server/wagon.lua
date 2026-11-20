local RSGCore = exports['rsg-core']:GetCoreObject()

local gangWagons = {}    -- [gangName] = netId of the live wagon
local pendingSpawns = {} -- [gangName] = os.time() the spawn request expires (stops double requests)

local SPAWN_REQUEST_SECONDS = 20
local WAGON_RESET_COOLDOWN_SECONDS = 30
local wagonResetCooldowns = {}

local function wagonEntity(gangName)
    local netId = gangWagons[gangName]
    if not netId then return nil end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) then return nil end
    return entity
end

-- Live position of a spawned wagon. Used for despawn checks instead of the saved parking
-- spot, because a wagon being driven can be far from where it was last parked.
local function wagonLiveCoords(gangName)
    local entity = wagonEntity(gangName)
    return entity and GetEntityCoords(entity) or nil
end

local function deleteGangWagon(gangName)
    local entity = wagonEntity(gangName)
    if entity then DeleteEntity(entity) end
    if gangWagons[gangName] then
        gangWagons[gangName] = nil
        TriggerClientEvent('rsg-gangs:client:wagonUnregistered', -1, gangName)
    end
    pendingSpawns[gangName] = nil
end

RSGGangs.DeleteGangWagon = deleteGangWagon

-- Saves a new parking spot for a gang's wagon (memory + database).
local function setWagonLocation(gang, coords, heading)
    local wagon = { x = coords.x, y = coords.y, z = coords.z, heading = heading }
    if not RSGGangs.DbOk(
        'UPDATE rsg_gangs SET wagon_x = ?, wagon_y = ?, wagon_z = ?, wagon_heading = ? WHERE name = ?',
        { wagon.x, wagon.y, wagon.z, wagon.heading, gang.name }
    ) then
        return false
    end
    gang.wagon = wagon
    return true
end

RSGGangs.SetWagonLocation = setWagonLocation

-- Asks one client to spawn the wagon and gives it the one-off right to register what it spawned.
local function requestClientSpawn(src, gang)
    pendingSpawns[gang.name] = os.time() + SPAWN_REQUEST_SECONDS
    RSGGangs.Grant(src, 'wagon:' .. gang.name, SPAWN_REQUEST_SECONDS + 30)
    TriggerClientEvent('rsg-gangs:client:spawnGangWagonAt', src, gang.name, gang.wagon)
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
    if not RSGGangs.IsNear(src, coords, 60.0) then return end

    setWagonLocation(gang, coords, heading)
end)

RegisterNetEvent('rsg-gangs:server:gangVehicleSpotFailed', function()
    RSGGangs.Notify(source, locale('notify_wagon_no_clear_space'), 'error')
end)

-- A driver parked the wagon somewhere new.
RegisterNetEvent('rsg-gangs:server:gangWagonMoved', function(gangName, coords, heading)
    local src = source
    if RSGGangs.OnCooldown(src, 'wagonMoved', 2000) then return end

    local gang = memberGang(src)
    if not gang or gang.name ~= gangName then return end
    if not RSGGangs.ValidCoords(coords) or not RSGGangs.IsFinite(heading) then return end
    if RSGGangs.GangHasDeployedEquipment(gang.name) then return end

    -- The wagon has to be the real, live gang wagon, and the reporter has to be next to it.
    local entity = wagonEntity(gang.name)
    if not entity then return end
    if not RSGGangs.IsNear(src, coords, 60.0) then return end
    if #(GetEntityCoords(entity) - vector3(coords.x, coords.y, coords.z)) > 30.0 then return end

    setWagonLocation(gang, coords, heading)
end)

-- The client reports the wagon it spawned. Accepted only with a server grant, and only if the
-- entity really is a vehicle of the gang-wagon model.
RegisterNetEvent('rsg-gangs:server:gangWagonSpawned', function(gangName, netId)
    local src = source
    if type(gangName) ~= 'string' or type(netId) ~= 'number' then return end
    if not RSGGangs.ConsumeGrant(src, 'wagon:' .. gangName) then return end

    local gang = RSGGangs.Gangs[gangName]
    if not gang then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) then return end
    if GetEntityType(entity) ~= 2 then return end
    if GetEntityModel(entity) ~= joaat(Config.GangVehicle.model) then
        DeleteEntity(entity)
        return
    end

    -- Another wagon is already live for this gang (duplicate spawn): remove the new one.
    local existing = wagonEntity(gangName)
    if existing and existing ~= entity then
        DeleteEntity(entity)
        pendingSpawns[gangName] = nil
        return
    end

    gangWagons[gangName] = netId
    pendingSpawns[gangName] = nil
    TriggerClientEvent('rsg-gangs:client:wagonRegistered', -1, gangName, netId)
end)

RegisterNetEvent('rsg-gangs:server:requestWagonRegistry', function()
    local src = source
    if RSGGangs.OnCooldown(src, 'wagonRegistry', 2000) then return end
    TriggerClientEvent('rsg-gangs:client:wagonRegistrySync', src, gangWagons)
end)

---------------------------------------------------------------------
-- Respawn a stuck wagon (needs the 'equipment' permission)
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:resetWagon', function()
    local src = source
    local gang, citizenid = memberGang(src)
    if not gang then RSGGangs.Notify(src, locale('error_no_gang'), 'error') return end

    if not RSGGangs.HasPermission(gang.members[citizenid].rank, 'equipment') then
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
                local live = wagonLiveCoords(gangName)
                if live then
                    if not RSGGangs.NearestPlayer(positions, live, Config.DespawnProximityRadius) then
                        deleteGangWagon(gangName)
                    end
                else
                    -- The entity is gone (destroyed, or its owner left): forget the stale net id.
                    if gangWagons[gangName] then
                        gangWagons[gangName] = nil
                        TriggerClientEvent('rsg-gangs:client:wagonUnregistered', -1, gangName)
                    end

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

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for gangName in pairs(gangWagons) do
        local entity = wagonEntity(gangName)
        if entity then DeleteEntity(entity) end
    end
end)
