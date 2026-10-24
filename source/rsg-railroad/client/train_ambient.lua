local RSGCore = exports['rsg-core']:GetCoreObject()


local ambientTrains = {}
local ambientSpawned = false
local StartAmbientTrainThreads

local function SpawnTrain(trainid, route, trainhash, startcoords, direction)
    SetRandomTrains(false)
    local trainWagons = GetNumCarsFromTrainConfig(trainhash)
    for wagonIndex = 0, trainWagons - 1 do
        local trainWagonModel = GetTrainModelFromTrainConfigByCarIndex(trainhash, wagonIndex)
        while not HasModelLoaded(trainWagonModel) do
            RequestModel(trainWagonModel, 1)
            Wait(100)
        end
    end
    local train = CreateMissionTrain(trainhash, startcoords.x, startcoords.y, startcoords.z, direction)
    SetTrainSpeed(train, 0.0)
    SetModelAsNoLongerNeeded(train)
    NetworkRegisterEntityAsNetworked(train)
    return train
end


function SpawnAmbientRouteTrains()
    if ambientSpawned then return end
    for k, v in ipairs(Config.TrainSetup) do
        local train = SpawnTrain(v.trainid, v.route, v.trainhash, v.startcoords, v.reversed or false)
        SetTransportConfigFlag(train, 0, 1)
        table.insert(ambientTrains, train)
    end
    ambientSpawned = true
    for i, v in ipairs(Config.TrainSetup) do
        if ambientTrains[i] then StartAmbientTrainThreads(ambientTrains[i], v.route) end
    end
end

function DespawnAmbientRouteTrains()
    for _, train in ipairs(ambientTrains) do
        if DoesEntityExist(train) then
            DeleteEntity(train)
        end
    end
    ambientTrains = {}
    ambientSpawned = false
end

RegisterNetEvent('rsg-railroad:setAmbientState', function(active)
    if active and not ambientSpawned then
        local shouldSpawn = lib.callback.await('rsg-railroad:shouldSpawnAmbient', false)
        if shouldSpawn then
            SpawnAmbientRouteTrains()
        end
    elseif not active and ambientSpawned then
        DespawnAmbientRouteTrains()
        TriggerServerEvent('rsg-railroad:ambientDespawned')
    end
end)


-- per-route config lookups (resolved once instead of every frame)
local RouteSwitches = {
    trainRouteOne   = function() return Config.RouteOneTrainSwitches end,
    tramRouteOne    = function() return Config.RouteOneTramSwitches end,
    trainRouteThree = function() return Config.RouteThreeTrainSwitches end,
}
local RouteStops = {
    trainRouteOne   = { stops = function() return Config.RouteOneTrainStops end,   cruise = 5.0, full = 15.0, whistle = true },
    tramRouteOne    = { stops = function() return Config.RouteOneTramStops end,    cruise = 1.0, full = 2.0 },
    trainRouteThree = { stops = function() return Config.RouteThreeTrainStops end, cruise = 8.0, full = 12.0 },
}

-- loops end as soon as the train is despawned, so respawning no longer stacks dead threads
local function TrainAlive(train)
    return train and ambientSpawned and DoesEntityExist(train)
end

local function RunTrackSwitches(train, route)
    local getter = RouteSwitches[route]
    if not getter then return end
    local switches = getter() or {}
    while TrainAlive(train) do
        local traincoords = GetEntityCoords(train)
        for i = 1, #switches do
            local s = switches[i]
            if #(s.coords - traincoords) < 15 then
                SetTrainTrackJunctionSwitch(s.trainTrack, s.junctionIndex, s.enabled)
                Citizen.InvokeNative(0x3ABFA128F5BF5A70, s.trainTrack, s.junctionIndex, s.enabled)
            end
        end
        Wait(250) -- was every frame; 15m trigger radius is still hit at full speed
    end
end

local function RunRoute(train, route)
    local cfg = RouteStops[route]
    if not cfg then return end
    local stops = cfg.stops() or {}
    while TrainAlive(train) do
        local traincoords = GetEntityCoords(train)
        for i = 1, #stops do
            if not TrainAlive(train) then return end
            local stop = stops[i]
            local distance = #(stop.coords - traincoords)
            if distance < stop.dst then
                SetTrainCruiseSpeed(train, cfg.cruise)
                Wait(1000)
                if distance < stop.dst2 then
                    SetTrainCruiseSpeed(train, 0.0)
                    if cfg.whistle then TriggerTrainWhistle(train, "STOPPED", 1, 0) end
                    Wait(stop.waittime)
                    if not TrainAlive(train) then return end
                    if cfg.whistle then TriggerTrainWhistle(train, "NEXT_STATION", 1, 0) end
                    SetTrainCruiseSpeed(train, cfg.cruise)
                    Wait(10000)
                end
            elseif distance > stop.dst then
                SetTrainCruiseSpeed(train, cfg.full)
                Wait(25)
            end
        end
        Wait(100)
    end
end

StartAmbientTrainThreads = function(train, route)
    CreateThread(function() RunTrackSwitches(train, route) end)
    CreateThread(function() RunRoute(train, route) end)
end

-------------------------------------------------------------------------------
-- setup train blips
-------------------------------------------------------------------------------
function trainChecker(train)
    if IsThisModelATrain(GetEntityModel(train)) then
        local trainTrailerNumber = Citizen.InvokeNative(0x60B7D1DCC312697D, train)
        local isTrainIsReal = GetTrainCarriage(train,trainTrailerNumber-1)
        if isTrainIsReal ~= 0 then
            if not Citizen.InvokeNative(0x9FA00E2FC134A9D0, train) then
                local createdBlip = addBlipToTrain(-399496385, train, "Train")
                if Config.Debug then
                   
                end
            end
        end
    end
end

function addBlipToTrain(blipType,train,blipText)
    local blip = Citizen.InvokeNative(0x23f74c2fda6e7c61, blipType, train)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, blipText)
    return blip
end

function getTrains()
    local handle, firstVehicle = FindFirstVehicle()
    trainChecker(firstVehicle)
    local isExist, nextVeh = FindNextVehicle(handle)
    while isExist do
        trainChecker(nextVeh)
        isExist, nextVeh = FindNextVehicle(handle)
    end
    EndFindVehicle(handle)
end

Citizen.CreateThread(function()
    while true do
        getTrains()
        Wait(10000)
    end
end)

function FindNearestName(coords)
    local nearestDist = math.huge
    local nearestName = locale('unknown')
    for _, stop in ipairs(Config.RouteOneTrainStops) do
        local dist = #(stop.coords - coords)
        if dist < nearestDist then
            nearestDist = dist
            nearestName = stop.name
        end
    end
    for _, stop in ipairs(Config.RouteOneTramStops) do
        local dist = #(stop.coords - coords)
        if dist < nearestDist then
            nearestDist = dist
            nearestName = stop.name
        end
    end
    for _, stop in ipairs(Config.RouteThreeTrainStops) do
        local dist = #(stop.coords - coords)
        if dist < nearestDist then
            nearestDist = dist
            nearestName = stop.name
        end
    end
    if nearestDist > 200 then
        nearestName = locale('hud_en_route')
    end
    return nearestName
end

RegisterNetEvent('rsg-railroad:client:trainpos', function()
    local options = {}

    if ActiveTrain and DoesEntityExist(ActiveTrain) then
        local coords = GetEntityCoords(ActiveTrain)
        local label = ActiveTrainConfig and ActiveTrainConfig.label or locale('hud_active_train')
        table.insert(options, { title = label, description = FindNearestName(coords), icon = 'train' })
    end

    for _, train in ipairs(ambientTrains) do
        if DoesEntityExist(train) then
            local coords = GetEntityCoords(train)
            table.insert(options, { title = locale('menu_route_train'), description = FindNearestName(coords), icon = 'train' })
        end
    end

    if ambientTram and DoesEntityExist(ambientTram) then
        local coords = GetEntityCoords(ambientTram)
        table.insert(options, { title = locale('menu_saint_denis_trolley'), description = FindNearestName(coords), icon = 'tram' })
    end

    if #options == 0 then
        Notify(locale('no_trains_found'), 'error')
        return
    end

    lib.registerContext({ id = 'trainpos_menu', title = locale('menu_train_locations'), options = options })
    lib.showContext('trainpos_menu')
end)

RegisterNetEvent('rsg-railroad:client:setjunction', function(args)
    if #args < 3 then
        print('Usage: /setjunction <trackName> <junctionIndex> <0|1>')
        print('Example: /setjunction TRAINS_OLD_WEST03 2 1')
        return
    end
    local hash = joaat(args[1])
    local idx = tonumber(args[2])
    local enabled = tonumber(args[3]) == 1
    SetTrainTrackJunctionSwitch(hash, idx, enabled)
    Citizen.InvokeNative(0x3ABFA128F5BF5A70, hash, idx, enabled and 1 or 0)
    print(string.format('Set junction: hash=%d (%s), idx=%d, enabled=%s', hash, args[1], idx, tostring(enabled)))
end)