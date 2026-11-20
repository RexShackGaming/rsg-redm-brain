local notify = RSGGangsClient.Notify

---------------------------------------------------------------------
-- Helpers shared with client/equipment.lua
---------------------------------------------------------------------
function RSGGangsClient.LoadModel(modelHash)
    RequestModel(modelHash)
    local waited = 0
    while not HasModelLoaded(modelHash) and waited < 5000 do
        Wait(50)
        waited = waited + 50
    end
    return HasModelLoaded(modelHash)
end

-- Network id of a freshly created entity. Polls slowly to avoid "no net object" warning spam.
function RSGGangsClient.GetValidNetworkId(entity, maxWaitMs)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    local start = GetGameTimer()
    while netId == 0 and (GetGameTimer() - start) < (maxWaitMs or 2000) do
        Wait(250)
        netId = NetworkGetNetworkIdFromEntity(entity)
    end
    return netId
end

-- Adds rsg-target options to an entity, retrying a few times until the target system accepts it.
function RSGGangsClient.AddEntityTarget(entity, options)
    CreateThread(function()
        for _ = 1, 10 do
            if not DoesEntityExist(entity) then return end
            if pcall(function() exports['rsg-target']:addLocalEntity(entity, options) end) then return end
            Wait(500)
        end
        print('^1[rsg-gangs] could not register a target option: is rsg-target started before rsg-gangs?^7')
    end)
end

function RSGGangsClient.RemoveEntityTarget(entity)
    pcall(function() exports['rsg-target']:removeLocalEntity(entity) end)
end

---------------------------------------------------------------------
-- Wagon ownership tracking (net id <-> gang)
---------------------------------------------------------------------
local wagonGangByNetId = {}
local wagonNetIdByGang = {}

local function trackWagon(gangName, netId)
    local previous = wagonNetIdByGang[gangName]
    if previous and previous ~= netId then wagonGangByNetId[previous] = nil end
    wagonGangByNetId[netId] = gangName
    wagonNetIdByGang[gangName] = netId
end

local function forgetWagon(gangName)
    local netId = wagonNetIdByGang[gangName]
    if netId then wagonGangByNetId[netId] = nil end
    wagonNetIdByGang[gangName] = nil
end

RegisterNetEvent('rsg-gangs:client:wagonRegistered', function(gangName, netId)
    if gangName and netId then trackWagon(gangName, netId) end
end)

RegisterNetEvent('rsg-gangs:client:wagonUnregistered', function(gangName)
    if gangName then forgetWagon(gangName) end
end)

local registrySynced = false

RegisterNetEvent('rsg-gangs:client:wagonRegistrySync', function(registry)
    registrySynced = true
    for gangName, netId in pairs(registry or {}) do trackWagon(gangName, netId) end
end)

---------------------------------------------------------------------
-- Spawning
---------------------------------------------------------------------
local function isAreaClear(coords, radius)
    for _, pool in ipairs({ 'CPed', 'CVehicle', 'CObject' }) do
        local ok, entities = pcall(GetGamePool, pool)
        if ok and entities then
            for _, entity in ipairs(entities) do
                if DoesEntityExist(entity) and #(GetEntityCoords(entity) - coords) <= radius then
                    return false
                end
            end
        end
    end
    return true
end

local function findClearSpawnPoint(ped)
    local cfg = Config.GangVehicle
    local origin = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local forward = GetEntityForwardVector(ped)

    for attempt = 0, cfg.maxAttempts - 1 do
        local distance = cfg.spawnDistance + (attempt * cfg.attemptStep)
        local x, y, z = origin.x + forward.x * distance, origin.y + forward.y * distance, origin.z

        local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z + 5.0, false)
        if foundGround then z = groundZ end

        local spawnCoords = vector3(x, y, z)
        if isAreaClear(spawnCoords, cfg.checkRadius) then
            return spawnCoords, heading
        end
    end
    return nil, nil
end

-- Deletes a vehicle even when another client owns it (asks for network control first).
local function deleteVehicleSafe(vehicle)
    if not DoesEntityExist(vehicle) then return end
    if NetworkGetEntityIsNetworked(vehicle) and not NetworkHasControlOfEntity(vehicle) then
        NetworkRequestControlOfEntity(vehicle)
        local waited = 0
        while not NetworkHasControlOfEntity(vehicle) and waited < 1000 do
            Wait(50)
            waited = waited + 50
        end
    end
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteEntity(vehicle)
    if DoesEntityExist(vehicle) then DeleteVehicle(vehicle) end
end

-- Removes an old copy of this wagon model at the spawn spot (e.g. left over after a script restart).
local function clearExistingWagonsNear(coords, modelHash, radius)
    local ok, vehicles = pcall(GetGamePool, 'CVehicle')
    if not ok or not vehicles then return end

    -- Orphans can have drifted a little, so look wider than the spawn clearance.
    local range = math.max(radius or 3.0, 15.0)
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) and GetEntityModel(vehicle) == modelHash
            and #(GetEntityCoords(vehicle) - coords) <= range then
            deleteVehicleSafe(vehicle)
        end
    end
end

-- The target is registered on the wagon MODEL, not on one entity: every client gets it, it
-- survives the wagon being respawned, and it comes back after a resource restart.
local wagonTargetModel = nil

local function registerWagonTarget()
    if not Config.GangVehicle.useTargetMenu or wagonTargetModel then return end

    local modelHash = joaat(Config.GangVehicle.model)
    local ok = pcall(function()
        exports['rsg-target']:addModel(modelHash, {
            {
                name = 'rsg_gangs_manage_wagon',
                icon = 'fa-solid fa-flag',
                label = locale('notify_wagon_manage_outfit'),
                distance = 2.5,
                canInteract = function(targetEntity)
                    if not targetEntity or not DoesEntityExist(targetEntity) then return false end
                    local owner = wagonGangByNetId[NetworkGetNetworkIdFromEntity(targetEntity)]
                    return owner ~= nil and owner == RSGGangsClient.gangName
                end,
                onSelect = function()
                    TriggerEvent('rsg-gangs:client:openMenu')
                end,
            },
        })
    end)
    if ok then wagonTargetModel = modelHash end
end

CreateThread(function()
    local attempts = 0
    while not wagonTargetModel and attempts < 20 do
        registerWagonTarget()
        if wagonTargetModel then break end
        attempts = attempts + 1
        Wait(1000)
    end
end)

local spawningGangs = {} -- [gangName] = true while this client is creating that gang's wagon

-- Creates, tags and registers the wagon. Returns true on success.
local function createWagon(coords, heading, gangName)
    -- Never create a second wagon for a gang that already has a live one.
    local knownNetId = wagonNetIdByGang[gangName]
    if knownNetId then
        local existing = NetworkGetEntityFromNetworkId(knownNetId)
        if existing ~= 0 and DoesEntityExist(existing) then return end
    end

    local modelHash = joaat(Config.GangVehicle.model)
    if not RSGGangsClient.LoadModel(modelHash) then
        notify(locale('notify_wagon_model_failed'), 'error')
        return
    end

    clearExistingWagonsNear(coords, modelHash, Config.GangVehicle.checkRadius)

    local wagon = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, false)
    SetModelAsNoLongerNeeded(modelHash)

    if not DoesEntityExist(wagon) then
        notify(locale('notify_wagon_spawn_failed'), 'error')
        return
    end

    SetVehicleExtra(wagon, 1, 0)
    SetVehicleExtra(wagon, 2, 0)
    SetVehicleExtra(wagon, 3, 0)
    AddLightPropSetToVehicle(wagon, joaat('pg_teamster_chuckwagon002x_lightupgrade3'))
    SetVehicleLivery(wagon, 10)
    AddAdditionalPropSetForVehicle(wagon, joaat('pg_teamster_chuckwagon002x_gen'))
    SetVehicleTint(wagon, 10)
    SetEntityAsMissionEntity(wagon, true, true)
    SetVehicleOnGroundProperly(wagon)

    local netId = RSGGangsClient.GetValidNetworkId(wagon, 15000)
    if netId == 0 then
        print('^3[rsg-gangs] no network id for the gang wagon, deleting it so the server can retry^7')
        deleteVehicleSafe(wagon)
        return
    end

    trackWagon(gangName, netId)
    TriggerServerEvent('rsg-gangs:server:gangWagonSpawned', gangName, netId, GetEntityCoords(wagon), GetEntityHeading(wagon))
    -- Tag the entity so a later restart can recognise (and remove) it if it is left behind.
    pcall(function() Entity(wagon).state:set('rsgGangWagon', gangName, true) end)
    return true
end

local function spawnWagonAt(coords, heading, gangName)
    if spawningGangs[gangName] then return false end
    spawningGangs[gangName] = true
    local ok, result = pcall(createWagon, coords, heading, gangName)
    spawningGangs[gangName] = nil
    if not ok then
        print(('^1[rsg-gangs] wagon spawn failed: %s^7'):format(tostring(result)))
        return false
    end
    return result == true
end

-- A brand-new gang: find a free spot near the founder and park the wagon there.
RegisterNetEvent('rsg-gangs:client:findGangVehicleSpot', function(gangName)
    if not Config.GangVehicle.enabled then return end

    local spawnCoords, heading = findClearSpawnPoint(PlayerPedId())
    if not spawnCoords then
        TriggerServerEvent('rsg-gangs:server:gangVehicleSpotFailed')
        return
    end

    TriggerServerEvent('rsg-gangs:server:gangVehicleSpotFound', gangName, spawnCoords, heading)
    if spawnWagonAt(spawnCoords, heading, gangName) then
        notify(locale('notify_wagon_arrived'), 'success')
    end
end)

-- The server asked this client to (re)spawn a gang's saved wagon.
RegisterNetEvent('rsg-gangs:client:spawnGangWagonAt', function(gangName, wagon)
    if not Config.GangVehicle.enabled then return end
    if type(gangName) ~= 'string' or type(wagon) ~= 'table' or not wagon.x then return end

    spawnWagonAt(vector3(wagon.x, wagon.y, wagon.z), wagon.heading or 0.0, gangName)
end)

-- The server dropped this wagon (nobody near, admin move, reset): delete it if it is here.
RegisterNetEvent('rsg-gangs:client:despawnGangWagon', function(gangName, netId)
    if type(netId) ~= 'number' or netId == 0 then return end
    if NetworkDoesNetworkIdExist(netId) then
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity ~= 0 and DoesEntityExist(entity) then deleteVehicleSafe(entity) end
    end
    -- A duplicate being removed must not make this client forget the real wagon.
    if gangName and wagonNetIdByGang[gangName] == netId then forgetWagon(gangName) end
end)

---------------------------------------------------------------------
-- Restrict driving to gang members, and save the parking position
---------------------------------------------------------------------
local drivingWagon = nil -- { entity, gangName }
local blockedNotifiedFor = nil

local function forceExitVehicle(ped, veh)
    if GetPedInVehicleSeat(veh, -1) ~= ped then return end
    TaskLeaveVehicle(ped, veh, 16)
    if IsEntityAttachedToEntity(ped, veh) then DetachEntity(ped, true, true) end
end

local function reportWagonParked(entry)
    if not DoesEntityExist(entry.entity) then return end
    TriggerServerEvent('rsg-gangs:server:gangWagonMoved', entry.gangName, GetEntityCoords(entry.entity), GetEntityHeading(entry.entity))
end

CreateThread(function()
    while true do
        Wait(500)

        if Config.GangVehicle.enabled then
            local ped = PlayerPedId()
            local veh = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or nil
            local isDriver = veh and DoesEntityExist(veh) and GetPedInVehicleSeat(veh, -1) == ped

            local ownerGang = isDriver and wagonGangByNetId[NetworkGetNetworkIdFromEntity(veh)] or nil
            local myGang = RSGGangsClient.gangName

            if ownerGang and Config.GangVehicle.restrictDriving and ownerGang ~= myGang then
                forceExitVehicle(ped, veh)
                if blockedNotifiedFor ~= veh then
                    notify(locale('notify_wagon_driving_restricted'), 'error')
                    blockedNotifiedFor = veh
                end
                ownerGang = nil
            elseif ownerGang and ownerGang == myGang and RSGGangsClient.hasDeployedEquipment then
                forceExitVehicle(ped, veh)
                if blockedNotifiedFor ~= veh then
                    notify(locale('notify_wagon_stow_equipment'), 'error')
                    blockedNotifiedFor = veh
                end
                ownerGang = nil
            else
                blockedNotifiedFor = nil
            end

            local sameWagon = ownerGang and drivingWagon and veh == drivingWagon.entity
            if drivingWagon and not sameWagon then
                reportWagonParked(drivingWagon)
                drivingWagon = nil
            end

            if ownerGang and ownerGang == myGang then
                drivingWagon = { entity = veh, gangName = ownerGang }
            end
        end
    end
end)

---------------------------------------------------------------------
-- Cleanup: remove the target with the resource
---------------------------------------------------------------------
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if wagonTargetModel then
        pcall(function() exports['rsg-target']:removeModel(wagonTargetModel) end)
        wagonTargetModel = nil
    end

    -- Positions are saved continuously by the heartbeats, so the wagon can go now.
    for _, netId in pairs(wagonNetIdByGang) do
        if NetworkDoesNetworkIdExist(netId) then
            local entity = NetworkGetEntityFromNetworkId(netId)
            if entity ~= 0 and DoesEntityExist(entity) and NetworkHasControlOfEntity(entity) then
                SetEntityAsMissionEntity(entity, true, true)
                DeleteEntity(entity)
            end
        end
    end
end)

---------------------------------------------------------------------
-- Keep the saved parking spot current, and clear wagons from before a restart
---------------------------------------------------------------------
-- Every client that has a wagon nearby keeps it alive on the server; members also report where it
-- stands, so the saved parking spot always follows the wagon.
CreateThread(function()
    while true do
        Wait(4000)
        if Config.GangVehicle.enabled then
            local myCoords = GetEntityCoords(PlayerPedId())
            for gangName, netId in pairs(wagonNetIdByGang) do
                if NetworkDoesNetworkIdExist(netId) then
                    local entity = NetworkGetEntityFromNetworkId(netId)
                    if entity ~= 0 and DoesEntityExist(entity) then
                        local c = GetEntityCoords(entity)
                        if #(c - myCoords) < 120.0 then
                            local stationary = GetEntitySpeed(entity) < 0.5
                                and not (drivingWagon and drivingWagon.entity == entity)
                            TriggerServerEvent('rsg-gangs:server:wagonHeartbeat', gangName, netId, c, GetEntityHeading(entity), stationary)
                        end
                    end
                end
            end
        end
    end
end)

-- A wagon tagged by the server (state bag) that is not in the current registry is left over from
-- before a restart. It must be seen untracked on two checks in a row before it is removed.
local suspectOrphans = {}

CreateThread(function()
    local modelHash = joaat(Config.GangVehicle.model)
    while true do
        Wait(4000)
        if registrySynced and Config.GangVehicle.enabled then
            local ok, vehicles = pcall(GetGamePool, 'CVehicle')
            local seen = {}
            if ok and vehicles then
                for _, vehicle in ipairs(vehicles) do
                    if DoesEntityExist(vehicle) and GetEntityModel(vehicle) == modelHash then
                        local tagged = Entity(vehicle).state.rsgGangWagon
                        local netId = NetworkGetEntityIsNetworked(vehicle) and NetworkGetNetworkIdFromEntity(vehicle) or 0
                        if tagged and not wagonGangByNetId[netId] then
                            seen[vehicle] = true
                            if suspectOrphans[vehicle] then
                                deleteVehicleSafe(vehicle)
                                seen[vehicle] = nil
                            end
                        end
                    end
                end
            end
            suspectOrphans = seen
        end
    end
end)
