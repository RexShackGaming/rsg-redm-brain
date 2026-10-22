local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Plants   = {}   -- [id] = plant data from server
local Spawned  = {}   -- [id] = { entity, stage, dead, zone }
local UIPlant  = nil  -- id of plant open in the UI
local MyCid    = nil
local GpsPlant = nil  -- id of plant we are routing to

---------------------------------
-- helpers
---------------------------------
local function getCid()
    if not MyCid then
        local pd = RSGCore.Functions.GetPlayerData()
        MyCid = pd and pd.citizenid
    end
    return MyCid
end

local function plantPos(p) return vector3(p.x, p.y, p.z) end

local function getStage(crop, growth)
    local idx = 1
    for i, st in ipairs(crop.stages) do
        if growth >= st.from then idx = i end
    end
    return idx
end

local function clearGps()
    if GpsPlant then
        ClearGpsMultiRoute()
        GpsPlant = nil
    end
end

local function closeUI()
    UIPlant = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---------------------------------
-- NUI strings (sent once so the UI is fully localised)
---------------------------------
local UI_KEYS = {
    'ui_my_plants', 'ui_close', 'ui_back', 'ui_growth', 'ui_water', 'ui_fertiliser', 'ui_health',
    'ui_stage', 'ui_withered', 'ui_dead', 'ui_ready', 'ui_needs_water', 'ui_thirsty', 'ui_growing',
    'ui_btn_water', 'ui_btn_fertilise', 'ui_btn_harvest', 'ui_btn_remove', 'ui_my_crops',
    'ui_plant_count', 'ui_plants_count', 'ui_note_dead', 'ui_note_ready', 'ui_note_dry',
    'ui_note_minute', 'ui_note_minutes', 'ui_note_fertilised', 'ui_not_yours', 'ui_empty', 'ui_away',
}

CreateThread(function()
    local strings = {}
    for _, k in ipairs(UI_KEYS) do strings[k] = locale(k) end
    SendNUIMessage({ action = 'locale', strings = strings })
end)

---------------------------------
-- ui payloads
---------------------------------
local function remainingMinutes(p, crop)
    if p.growth >= 100 then return 0 end
    local rate = 100 / crop.growTime
    if p.fertilizer > 0 then rate = rate * Config.FertilizerBoost end
    return math.ceil((100 - p.growth) / rate)
end

local function uiPayload(p, pedPos)
    local crop = Config.Crops[p.crop]
    return {
        id = p.id,
        label = crop.label,
        growth = p.growth, water = p.water, fertilizer = p.fertilizer, health = p.health,
        dead = p.dead,
        stage = getStage(crop, p.growth), stages = #crop.stages,
        ready = p.growth >= 100 and not p.dead,
        isOwner = p.owner == getCid(),
        ownerOnly = Config.OwnerOnlyHarvest,
        remaining = remainingMinutes(p, crop),
        thirsty = p.water <= Config.MinWaterToGrow,
        distance = math.floor(#((pedPos or GetEntityCoords(PlayerPedId())) - plantPos(p))),
    }
end

local function myPlantsPayload()
    local list, cid = {}, getCid()
    local pedPos = GetEntityCoords(PlayerPedId())
    for _, p in pairs(Plants) do
        if p.owner == cid then list[#list + 1] = uiPayload(p, pedPos) end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

local function openUI(id)
    local p = Plants[id]
    if not p or Utils.busy then return end
    UIPlant = id
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', plant = uiPayload(p) })
end

---------------------------------
-- spawning
---------------------------------
local function despawn(id)
    local s = Spawned[id]
    if s then
        Utils.deleteProp(s.entity)
        if s.zone then exports.ox_target:removeZone(s.zone) end
    end
    Spawned[id] = nil
end

local function addTarget(plant)
    if not Config.UseTarget then return nil end
    return exports.ox_target:addSphereZone({
        coords = vector3(plant.x, plant.y, plant.z + 0.5),
        radius = Config.TargetRadius,
        debug = Config.Debug,
        options = {
            {
                name = ('rsg_farming_plant_%s'):format(plant.id),
                label = locale('tend_target', Config.Crops[plant.crop].label),
                icon = Config.TargetIcon,
                distance = Config.InteractDistance + 0.5,
                canInteract = function() return not Utils.busy and Plants[plant.id] ~= nil end,
                onSelect = function() openUI(plant.id) end,
            },
        },
    })
end

local function spawn(plant, stageIdx)
    local st = Config.Crops[plant.crop].stages[stageIdx]
    local obj = Utils.spawnProp(st.prop, plant.x, plant.y, plant.z + (st.zOffset or 0.0), plant.h)
    if not obj then return end
    SetEntityCollision(obj, false, false)
    if plant.dead then SetEntityAlpha(obj, 140, false) end
    -- keep the existing target zone if we are only swapping the model
    local old = Spawned[plant.id]
    Spawned[plant.id] = { entity = obj, stage = stageIdx, dead = plant.dead, zone = old and old.zone or addTarget(plant) }
end

---------------------------------
-- sync
---------------------------------
local function applySync(list)
    local new = {}
    for _, p in ipairs(list or {}) do new[p.id] = p end
    for id in pairs(Spawned) do
        if not new[id] then despawn(id) end
    end
    Plants = new
    if GpsPlant and not Plants[GpsPlant] then clearGps() end
    if UIPlant then
        if Plants[UIPlant] then
            SendNUIMessage({ action = 'update', plant = uiPayload(Plants[UIPlant]) })
        else
            closeUI()
        end
    end
end

RegisterNetEvent('rsg-farming:client:sync', applySync)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    MyCid = nil
    applySync(lib.callback.await('rsg-farming:server:getPlants', false))
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    MyCid = nil
    closeUI()
    clearGps()
end)

CreateThread(function()
    Wait(1000)
    applySync(lib.callback.await('rsg-farming:server:getPlants', false))
end)

---------------------------------
-- streaming props + gps arrival
---------------------------------
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for id, p in pairs(Plants) do
            local crop = Config.Crops[p.crop]
            if crop then
                local s = Spawned[id]
                if #(pos - plantPos(p)) <= Config.RenderDistance then
                    local stage = getStage(crop, p.growth)
                    if not s or s.stage ~= stage or s.dead ~= p.dead or not DoesEntityExist(s.entity) then
                        if s then Utils.deleteProp(s.entity) end
                        spawn(p, stage)
                    end
                elseif s then
                    despawn(id)
                end
            end
        end
        if GpsPlant and Plants[GpsPlant] and #(pos - plantPos(Plants[GpsPlant])) < 5.0 then clearGps() end
        Wait(1000)
    end
end)

---------------------------------
-- [G] prompt interaction (only when ox_target is disabled)
---------------------------------
if not Config.UseTarget then
    CreateThread(function()
        local shown = false
        while true do
            local sleep = 750
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local nearest, nearestDist = nil, Config.InteractDistance

            if not UIPlant and Utils.canAct() then
                for id, p in pairs(Plants) do
                    local d = #(pos - plantPos(p))
                    if d < 10.0 then sleep = 0 end
                    if d < nearestDist then nearest, nearestDist = id, d end
                end
            end

            if nearest then
                if shown ~= nearest then
                    lib.showTextUI(locale('tend_plant', Config.Crops[Plants[nearest].crop].label))
                    shown = nearest
                end
                if IsControlJustReleased(0, Config.InteractKey) then
                    lib.hideTextUI(); shown = false
                    openUI(nearest)
                end
            elseif shown then
                lib.hideTextUI(); shown = false
            end
            Wait(sleep)
        end
    end)
end

---------------------------------
-- actions
---------------------------------
local ACTIONS = {
    water     = { cb = 'rsg-farming:server:water',     scenario = 'water',     time = 'WaterTime',     label = 'watering' },
    fertilize = { cb = 'rsg-farming:server:fertilize', scenario = 'fertilize', time = 'FertilizeTime', label = 'fertilizing' },
    harvest   = { cb = 'rsg-farming:server:harvest',   scenario = 'harvest',   time = 'HarvestTime',   label = 'harvesting' },
    destroy   = { cb = 'rsg-farming:server:destroy' },
}

local function runAction(name, id)
    local act, p = ACTIONS[name], Plants[id]
    closeUI()
    if not act or not p or not Utils.canAct() then return end
    Utils.busy = true

    local proceed = true
    if act.scenario then
        local canDo, reason = lib.callback.await('rsg-farming:server:precheck', false, name, id)
        if not canDo then
            Utils.notify(reason, 'error')
            Utils.busy = false
            return
        end
        Utils.face(p.x, p.y)
        proceed = Utils.playScenario(Config.Scenarios[act.scenario], Config[act.time], locale(act.label))
    end

    if proceed then
        local ok, msg = lib.callback.await(act.cb, false, id)
        Utils.notify(msg, ok and 'success' or 'error')
    else
        Utils.notify(locale('cancelled'), 'error')
    end
    Utils.busy = false
end

---------------------------------
-- planting
---------------------------------
RegisterNetEvent('rsg-farming:client:startPlacing', function(cropKey)
    local crop = Config.Crops[cropKey]
    if not crop or not Utils.canAct() then return end
    Utils.busy = true

    local coords, heading = Placement.Start(crop.stages[#crop.stages].prop, function(pos)
        for _, p in pairs(Plants) do
            if #(plantPos(p) - pos) < Config.MinPlantDistance then
                return false, locale('place_too_close')
            end
        end
        return true
    end)

    if coords then
        Utils.face(coords.x, coords.y)
        if Utils.playScenario(Config.Scenarios.plant, Config.PlantTime, locale('planting')) then
            local ok, msg = lib.callback.await('rsg-farming:server:plant', false, cropKey, coords, heading)
            Utils.notify(msg, ok and 'success' or 'error')
        else
            Utils.notify(locale('cancelled'), 'error')
        end
    end
    Utils.busy = false
end)

---------------------------------
-- NUI callbacks
---------------------------------
RegisterNUICallback('close', function(_, cb)
    UIPlant = nil
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('action', function(data, cb)
    cb('ok')
    local id = tonumber(data.id)
    if type(data.action) ~= 'string' or not id then return end
    CreateThread(function() runAction(data.action, id) end)
end)

RegisterNUICallback('openPlant', function(data, cb)
    cb('ok')
    local id = tonumber(data.id)
    local p = id and Plants[id]
    if not p then return end
    if #(GetEntityCoords(PlayerPedId()) - plantPos(p)) <= Config.InteractDistance + 1.0 then
        openUI(id)
    else
        -- too far: route to it on the map instead
        SetNuiFocus(false, false)
        ClearGpsMultiRoute()
        StartGpsMultiRoute(joaat('COLOR_YELLOW'), true, true)
        AddPointToGpsMultiRoute(p.x, p.y, p.z)
        SetGpsMultiRouteRender(true)
        GpsPlant = id
        Utils.notify(locale('gps_set'), 'inform')
    end
end)

RegisterNUICallback('showList', function(_, cb)
    cb('ok')
    UIPlant = nil
    SendNUIMessage({ action = 'list', plants = myPlantsPayload() })
end)

-- "back" from the list into the plant that was open
RegisterNUICallback('reopen', function(data, cb)
    cb('ok')
    local id = tonumber(data.id)
    if id and Plants[id] then
        UIPlant = id
        SendNUIMessage({ action = 'update', plant = uiPayload(Plants[id]) })
    else
        closeUI()
    end
end)

---------------------------------
-- my plants overview
---------------------------------
RegisterCommand('myplants', function()
    if Utils.busy then return end
    UIPlant = nil
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'list', plants = myPlantsPayload() })
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Spawned) do despawn(id) end
    SetNuiFocus(false, false)
    lib.hideTextUI()
    ClearGpsMultiRoute()
end)
