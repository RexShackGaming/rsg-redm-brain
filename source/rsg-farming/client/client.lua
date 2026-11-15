local RSGCore = exports['rsg-core']:GetCoreObject()

local Plants   = {}   -- [id] = plant data from server (no citizenid)
local Mine     = {}   -- [id] = true for plants this character owns (sent by the server)
local Spawned  = {}   -- [id] = { entity, stage, dead, zone }
local UIPlant  = nil  -- id of plant open in the UI
local GpsPlant = nil  -- id of plant we are routing to

---------------------------------
-- helpers
---------------------------------
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
    Utils.setNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

---------------------------------
-- NUI strings (sent once so the UI is fully localised)
---------------------------------
local UI_KEYS = {
    'ui_my_plants', 'ui_close', 'ui_back', 'ui_growth', 'ui_water', 'ui_fertiliser', 'ui_health',
    'ui_stage', 'ui_withered', 'ui_dead', 'ui_ready', 'ui_needs_water', 'ui_thirsty', 'ui_growing',
    'ui_btn_water', 'ui_btn_fertilise', 'ui_btn_harvest', 'ui_btn_remove', 'ui_btn_treat', 'ui_pests', 'ui_note_pests', 'ui_my_crops',
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
local function uiPayload(p, pedPos)
    local crop = Config.Crops[p.crop]
    return {
        id = p.id,
        label = crop.label,
        growth = p.growth, water = p.water, fertilizer = p.fertilizer, health = p.health,
        dead = p.dead,
        stage = getStage(crop, p.growth), stages = #crop.stages,
        ready = p.growth >= 100 and not p.dead,
        isOwner = Mine[p.id] == true,
        ownerOnly = Config.OwnerOnlyHarvest,
        remaining = p.eta or 0, -- worked out by the server (season, fertiliser and pests included)
        pest = p.pest == true,
        pestsEnabled = Config.Pests.enabled,
        thirsty = p.water <= Config.MinWaterToGrow,
        distance = math.floor(#((pedPos or GetEntityCoords(PlayerPedId())) - plantPos(p))),
    }
end

local function myPlantsPayload()
    local list = {}
    local pedPos = GetEntityCoords(PlayerPedId())
    for id, p in pairs(Plants) do
        if Mine[id] and Config.Crops[p.crop] then list[#list + 1] = uiPayload(p, pedPos) end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

local function openUI(id)
    local p = Plants[id]
    if not p or Utils.busy then return end
    UIPlant = id
    Utils.setNuiFocus(true)
    SendNUIMessage({ action = 'open', plant = uiPayload(p) })
end

---------------------------------
-- spawning
---------------------------------
local function despawn(id)
    local s = Spawned[id]
    if s then
        Utils.deleteProp(s.entity)
        if s.zone then exports['rsg-target']:removeZone(s.zone) end
    end
    Spawned[id] = nil
end

local function addTarget(plant)
    if not Config.UseTarget then return nil end
    return exports['rsg-target']:addSphereZone({
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
local function refreshUI()
    if not UIPlant then return end
    if Plants[UIPlant] then
        SendNUIMessage({ action = 'update', plant = uiPayload(Plants[UIPlant]) })
    else
        closeUI()
    end
end

-- full list (every tick / login): list = plants, mine = ids this character owns
local function applySync(list, mine)
    local new = {}
    for _, p in ipairs(list or {}) do new[p.id] = p end
    for id in pairs(Spawned) do
        if not new[id] then despawn(id) end
    end
    Plants = new
    Mine = {}
    for _, id in ipairs(mine or {}) do Mine[id] = true end
    if GpsPlant and not Plants[GpsPlant] then clearGps() end
    refreshUI()
end

RegisterNetEvent('rsg-farming:client:sync', applySync)

-- single plant changed (water / fertilise / planted)
RegisterNetEvent('rsg-farming:client:plantUpdate', function(p)
    if type(p) ~= 'table' or not p.id then return end
    Plants[p.id] = p
    if UIPlant == p.id then
        SendNUIMessage({ action = 'update', plant = uiPayload(p) })
    end
end)

RegisterNetEvent('rsg-farming:client:plantRemove', function(id)
    Plants[id] = nil
    Mine[id] = nil
    despawn(id)
    if GpsPlant == id then clearGps() end
    if UIPlant == id then closeUI() end
end)

RegisterNetEvent('rsg-farming:client:plantMine', function(id)
    Mine[id] = true
end)

local function loadPlants()
    local list, mine = RSGCore.Functions.AwaitCallback('rsg-farming:server:getPlants', nil)
    applySync(list, mine)
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', loadPlants)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    closeUI()
    clearGps()
    for id in pairs(Spawned) do despawn(id) end
    Plants, Mine = {}, {}
end)

CreateThread(function()
    Wait(1000)
    loadPlants()
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
-- [G] prompt interaction (only when rsg-target is disabled)
---------------------------------
if not Config.UseTarget then
    CreateThread(function()
        local shown = false
        while true do
            local sleep = 750
            local pos = GetEntityCoords(PlayerPedId())
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
                    exports['rsg-core']:DrawText(locale('tend_plant', Config.Crops[Plants[nearest].crop].label), 'left')
                    shown = nearest
                end
                if IsControlJustReleased(0, Config.InteractKey) then
                    exports['rsg-core']:HideText(); shown = false
                    openUI(nearest)
                end
            elseif shown then
                exports['rsg-core']:HideText(); shown = false
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
    treat     = { cb = 'rsg-farming:server:treat',     scenario = 'treat',     time = 'TreatTime',     label = 'treating' },
    harvest   = { cb = 'rsg-farming:server:harvest',   scenario = 'harvest',   time = 'HarvestTime',   label = 'harvesting' },
    destroy   = { cb = 'rsg-farming:server:destroy' },
}

local function runAction(name, id)
    local act, p = ACTIONS[name], Plants[id]
    closeUI()
    if not act or not p or not Utils.canAct() then return end

    Utils.guard(function()
        local proceed = true
        if act.scenario then
            local canDo, reason = RSGCore.Functions.AwaitCallback('rsg-farming:server:precheck', nil, name, id)
            if not canDo then
                Utils.notify(reason, 'error')
                return
            end
            Utils.face(p.x, p.y)
            proceed = Utils.playScenario(Config.Scenarios[act.scenario], Config[act.time], locale(act.label))
        end

        if proceed then
            local ok, msg = RSGCore.Functions.AwaitCallback(act.cb, nil, id)
            Utils.notify(msg, ok and 'success' or 'error')
        else
            Utils.notify(locale('cancelled'), 'error')
        end
    end)
end

---------------------------------
-- planting
---------------------------------
RegisterNetEvent('rsg-farming:client:startPlacing', function(cropKey)
    local crop = Config.Crops[cropKey]
    if not crop or not Utils.canAct() then return end

    Utils.guard(function()
        local coords, heading = Utils.place(crop.stages[#crop.stages].prop, function(pos)
            if Utils.inBlockedZone(pos) then return false, locale('place_blocked_zone') end
            local minSq = Config.MinPlantDistance * Config.MinPlantDistance
            for _, p in pairs(Plants) do
                local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
                if dx * dx + dy * dy + dz * dz < minSq then
                    return false, locale('place_too_close')
                end
            end
            return true
        end)
        if not coords then return end

        Utils.face(coords.x, coords.y)
        if Utils.playScenario(Config.Scenarios.plant, Config.PlantTime, locale('planting')) then
            local ok, msg = RSGCore.Functions.AwaitCallback('rsg-farming:server:plant', nil, cropKey, coords, heading)
            Utils.notify(msg, ok and 'success' or 'error')
        else
            Utils.notify(locale('cancelled'), 'error')
        end
    end)
end)

---------------------------------
-- NUI callbacks
---------------------------------
RegisterNUICallback('close', function(_, cb)
    UIPlant = nil
    Utils.setNuiFocus(false)
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
    if not p then
        Utils.setNuiFocus(false) -- plant vanished while the list was open: don't leave the cursor stuck
        return
    end
    if #(GetEntityCoords(PlayerPedId()) - plantPos(p)) <= Config.InteractDistance + 1.0 then
        openUI(id)
    else
        -- too far: route to it on the map instead
        Utils.setNuiFocus(false)
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
    if not Utils.canAct() then return end
    UIPlant = nil
    Utils.setNuiFocus(true)
    SendNUIMessage({ action = 'list', plants = myPlantsPayload() })
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Spawned) do despawn(id) end
    exports['rsg-core']:HideText()
    ClearGpsMultiRoute()
end)
