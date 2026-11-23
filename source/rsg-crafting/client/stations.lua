---------------------------------------------
-- crafting stations: props / target zones that open the crafting book
---------------------------------------------
local RSGCore = exports['rsg-core']:GetCoreObject()

local stations = {} -- [id] = { id, type, coords, rotation, entity?, zone?, failed? }

local function notify(description, ntype)
    RSGCore.Functions.Notify({ title = locale('notify_title'), description = description, type = ntype or 'inform', duration = 5000 })
end

local function loadModel(model)
    local hash = joaat(model)
    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 5000 do
        Wait(50)
        waited = waited + 50
    end
    return HasModelLoaded(hash) and hash or nil
end

local function despawn(s)
    if s.zone then
        exports['rsg-target']:removeZone(s.zone)
        s.zone = nil
    end
    if s.entity then
        exports['rsg-target']:removeLocalEntity(s.entity)
        if DoesEntityExist(s.entity) then DeleteEntity(s.entity) end
        s.entity = nil
    end
end

local function spawn(s)
    local def = Config.Stations.Types[s.type]
    if not def or s.entity or s.zone or s.failed then return end

    local options = {
        {
            name = 'rsg_crafting_station_' .. s.id,
            icon = def.icon or 'fa-solid fa-hammer',
            label = locale('station_use', locale(def.label)),
            distance = 2.0,
            onSelect = function() TriggerEvent('rsg-crafting:client:openBook') end,
        },
    }

    if def.model then
        local hash = loadModel(def.model)
        if not hash then
            s.failed = true
            print(('^1[rsg-crafting] station model "%s" could not be loaded^7'):format(def.model))
            return
        end
        local obj = CreateObject(hash, s.coords.x, s.coords.y, s.coords.z, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        SetEntityRotation(obj, s.rotation.x, s.rotation.y, s.rotation.z, 2, true)
        FreezeEntityPosition(obj, true)
        s.entity = obj
        exports['rsg-target']:addLocalEntity(obj, options)
    else
        s.zone = exports['rsg-target']:addSphereZone({
            coords = s.coords, radius = def.zoneRadius or 1.5, options = options,
        })
    end
end

local function setStations(list)
    for _, s in pairs(stations) do despawn(s) end
    stations = {}
    for _, s in ipairs(list or {}) do
        if Config.Stations.Types[s.type] then stations[s.id] = s end
    end
end

RegisterNetEvent('rsg-crafting:client:setStations', setStations)

RegisterNetEvent('rsg-crafting:client:addStation', function(s)
    if type(s) == 'table' and Config.Stations.Types[s.type] then stations[s.id] = s end
end)

RegisterNetEvent('rsg-crafting:client:removeStation', function(id)
    local s = stations[id]
    if s then
        despawn(s)
        stations[id] = nil
    end
end)

-- first load
CreateThread(function()
    if not Config.Stations.Enabled then return end
    setStations(RSGCore.Functions.AwaitCallback('rsg-crafting:server:getStations', 15000))
end)

-- only stations near the player exist as props / zones
CreateThread(function()
    if not Config.Stations.Enabled then return end
    local range = Config.Stations.SpawnDistance or 60.0
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for _, s in pairs(stations) do
            local dist = #(pos - s.coords)
            if dist <= range then
                spawn(s)
            elseif dist > range + 15.0 then
                despawn(s)
            end
        end
        Wait(1500)
    end
end)

-- /craftstation: choose the spot (gizmo for prop stations, your position otherwise), the server validates and saves it
RegisterNetEvent('rsg-crafting:client:placeStation', function(stationType)
    local def = Config.Stations.Types[stationType]
    if not def then return notify(locale('station_invalid_type'), 'error') end
    CreateThread(function()
        local coords, rotation
        if def.model then
            local res = exports['rsg-gizmo']:Place(def.model, { maxDistance = 8.0, rotation = 'z' })
            if not res then return end
            coords, rotation = res.coords, res.rotation
        else
            local ped = PlayerPedId()
            coords, rotation = GetEntityCoords(ped), vector3(0.0, 0.0, GetEntityHeading(ped))
        end
        TriggerServerEvent('rsg-crafting:server:createStation', stationType, coords, rotation)
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, s in pairs(stations) do despawn(s) end
end)
