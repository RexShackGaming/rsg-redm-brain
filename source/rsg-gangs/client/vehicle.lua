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

RegisterNetEvent('rsg-gangs:client:wagonRegistrySync', function(registry)
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

-- Removes an old copy of this wagon model at the spawn spot (e.g. left over after a script restart).
local function clearExistingWagonsNear(coords, modelHash, radius)
    local ok, vehicles = pcall(GetGamePool, 'CVehicle')
    if not ok or not vehicles then return end

    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) and GetEntityModel(vehicle) == modelHash
            and #(GetEntityCoords(vehicle) - coords) <= radius then
            RSGGangsClient.RemoveEntityTarget(vehicle)
            DeleteEntity(vehicle)
        end
    end
end

local function addWagonTarget(entity, gangName)
    if not Config.GangVehicle.useTargetMenu then return end

    RSGGangsClient.AddEntityTarget(entity, {
        {
            name = 'rsg_gangs_manage_wagon',
            icon = 'fa-solid fa-flag',
            label = locale('notify_wagon_manage_outfit'),
            distance = 2.5,
            canInteract = function(targetEntity)
                if not DoesEntityExist(targetEntity) then return false end
                local owner = wagonGangByNetId[NetworkGetNetworkIdFromEntity(targetEntity)] or gangName
                return owner ~= nil and owner == RSGGangsClient.gangName
            end,
            onSelect = function()
                TriggerEvent('rsg-gangs:client:openMenu')
            end,
        },
    })
end

local function spawnWagonAt(coords, heading, gangName)
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
    addWagonTarget(wagon, gangName)

    local netId = RSGGangsClient.GetValidNetworkId(wagon, 15000)
    if netId == 0 then
        print('^3[rsg-gangs] no network id for the gang wagon, deleting it so the server can retry^7')
        RSGGangsClient.RemoveEntityTarget(wagon)
        DeleteEntity(wagon)
        return
    end

    trackWagon(gangName, netId)
    TriggerServerEvent('rsg-gangs:server:gangWagonSpawned', gangName, netId)
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
    spawnWagonAt(spawnCoords, heading, gangName)
    notify(locale('notify_wagon_arrived'), 'success')
end)

-- The server asked this client to (re)spawn a gang's saved wagon.
RegisterNetEvent('rsg-gangs:client:spawnGangWagonAt', function(gangName, wagon)
    if not Config.GangVehicle.enabled then return end
    if type(gangName) ~= 'string' or type(wagon) ~= 'table' or not wagon.x then return end

    spawnWagonAt(vector3(wagon.x, wagon.y, wagon.z), wagon.heading or 0.0, gangName)
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
