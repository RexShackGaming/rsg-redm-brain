local RSGCore = exports['rsg-core']:GetCoreObject()

local Stills  = {}   -- [id] = data
local Objects = {}   -- [id] = entity
local placing = false
local Fx      = {}    -- [id] = { particle handles }
local FxHeat  = {}    -- [id] = heat the smoke was started with
local uiOpen  = nil   -- still id while the NUI is open
local uiReady = false -- page confirmed it rendered
local WorldObj = {}   -- [id] = map prop entity for static world stills (never deleted by us)

---------------------------------
-- helpers
---------------------------------
local function isLaw()
    local job = RSGCore.Functions.GetPlayerData().job
    if not job then return false end
    for _, j in ipairs(Config.LawJobs) do
        if job.name == j then return (not Config.LawRequireDuty) or job.onduty end
    end
    return false
end

local function loadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model, false)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(model)
end

local function progress(label, duration, dict, clip)
    return RSGCore.Functions.ProgressBar({
        duration = duration, label = label, useWhileDead = false, canCancel = true,
        disable = { move = true, combat = true, mount = true },
        anim = dict and { dict = dict, clip = clip, flag = 1 } or nil,
    })
end

---------------------------------
-- brewing particle effects
---------------------------------
local function stopFx(id)
    FxHeat[id] = nil
    if not Fx[id] then return end
    for _, h in ipairs(Fx[id]) do StopParticleFxLooped(h, false) end
    Fx[id] = nil
end

local function startFx(id)
    local obj = Objects[id] or WorldObj[id]
    if Fx[id] or not obj or not Config.BrewFx.enabled then return end
    local dict = Config.BrewFx.dict
    local hash = joaat(dict)
    if not HasNamedPtfxAssetLoaded(hash) then
        RequestNamedPtfxAsset(hash)
        local t = GetGameTimer() + 5000
        while not HasNamedPtfxAssetLoaded(hash) and GetGameTimer() < t do Wait(10) end
        if not HasNamedPtfxAssetLoaded(hash) then return end
    end
    local handles = {}
    local heat = (Stills[id] and Stills[id].heat) or 'medium'
    local mult = 1.0
    for _, h in ipairs(Config.Heat) do if h.key == heat then mult = h.smoke end end
    FxHeat[id] = heat
    for _, e in ipairs(Config.BrewFx.effects) do
        UseParticleFxAsset(dict)
        local h = StartParticleFxLoopedOnEntity(e.name, obj, e.offset.x, e.offset.y, e.offset.z, 0.0, 0.0, 0.0, e.scale * mult, false, false, false)
        if h and h ~= 0 then handles[#handles + 1] = h end
    end
    Fx[id] = handles
end

local function updateFx(id)
    local s = Stills[id]
    if s and s.brewing then
        if FxHeat[id] and FxHeat[id] ~= (s.heat or 'medium') then stopFx(id) end -- smoke grows or shrinks with the fire
        startFx(id)
    else
        stopFx(id)
    end
end

---------------------------------
-- props
---------------------------------
local openStillMenu, closeUi, applyNuiFocus

local function despawnStill(id)
    stopFx(id)
    local obj = Objects[id]
    if obj and DoesEntityExist(obj) then
        exports['rsg-target']:removeLocalEntity(obj)
        DeleteObject(obj)
    end
    Objects[id] = nil
end

local function spawnStill(s)
    if Objects[s.id] then return end
    local model = s.kind == 'barrel' and Config.Barrel.prop or Config.StillProp
    if not loadModel(model) then return end
    local obj = CreateObject(model, s.coords.x, s.coords.y, s.coords.z, false, false, false)
    SetEntityHeading(obj, s.heading)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    Objects[s.id] = obj
    SetModelAsNoLongerNeeded(model)

    exports['rsg-target']:addLocalEntity(obj, {
        {
            name = 'moonshine_check_' .. s.id,
            icon = 'fa-solid fa-whiskey-glass',
            label = locale(s.kind == 'barrel' and 'cl_check_barrel' or 'cl_check'),
            distance = 2.5,
            onSelect = function() openStillMenu(s.id) end,
        },
        {
            name = 'moonshine_inspect_' .. s.id,
            icon = 'fa-solid fa-magnifying-glass',
            label = locale('cl_inspect'),
            distance = 2.5,
            canInteract = function() return Config.Inspect.enabled and isLaw() end,
            onSelect = function()
                if progress(locale('cl_inspecting'), Config.Inspect.time, 'amb_work@world_human_crouch_inspect@male_c@idle_a', 'idle_a') then
                    TriggerServerEvent('rsg-moonshine:server:inspect', s.id)
                end
            end,
        },
        {
            name = 'moonshine_destroy_' .. s.id,
            icon = 'fa-solid fa-hammer',
            label = locale('cl_destroy'),
            distance = 2.5,
            canInteract = function() return isLaw() end,
            onSelect = function()
                if progress(locale('cl_destroying'), Config.DestroyTime, 'amb_work@world_human_pickaxe@wall@male_d@base', 'base') then
                    TriggerServerEvent('rsg-moonshine:server:destroy', s.id)
                end
            end,
        },
    })
end

local function refreshNearby()
    local pos = GetEntityCoords(PlayerPedId())
    -- drop props for stills the server no longer tells us about (removed, or out of sync range)
    for id in pairs(Objects) do if not Stills[id] then despawnStill(id) end end
    for id in pairs(WorldObj) do if not Stills[id] then stopFx(id) WorldObj[id] = nil end end
    for id, s in pairs(Stills) do
        local near = #(pos - s.coords) <= Config.SpawnDist
        if s.world then
            -- map prop: just track the entity for particle effects
            if near and not (WorldObj[id] and DoesEntityExist(WorldObj[id])) then
                stopFx(id)
                WorldObj[id] = nil
                for _, m in ipairs(Config.WorldStills.models) do
                    local e = GetClosestObjectOfType(s.coords.x, s.coords.y, s.coords.z, 1.5, m, false, false, false)
                    if e and e ~= 0 then WorldObj[id] = e break end
                end
                updateFx(id)
            elseif not near and WorldObj[id] then
                stopFx(id)
                WorldObj[id] = nil
            end
        elseif near and not Objects[id] then
            spawnStill(s)
            updateFx(id)
        elseif not near and Objects[id] then
            despawnStill(id)
        end
    end
end

local streaming = false
local streamGen = 0
local function startStreaming()
    if streaming then return end
    streaming = true
    streamGen = streamGen + 1
    local gen = streamGen
    CreateThread(function()
        local tick = 0
        while streaming and gen == streamGen do
            -- the server only sends stills near us, so ask again every few seconds as we move
            if tick % 3 == 0 then
                local list = RSGCore.Functions.AwaitCallback('rsg-moonshine:server:getStills', 4000)
                if list then
                    local fresh = {}
                    for _, st in ipairs(list) do fresh[st.id] = st end
                    Stills = fresh
                end
            end
            tick = tick + 1
            refreshNearby()
            Wait(2000)
        end
    end)
end

local function loadStills()
    for id in pairs(Objects) do despawnStill(id) end
    for id in pairs(WorldObj) do stopFx(id) end
    WorldObj = {}
    Stills = {}
    startStreaming()
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', loadStills)
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    streaming = false
    closeUi()
    for id in pairs(Objects) do despawnStill(id) end
    for id in pairs(WorldObj) do stopFx(id) end
    WorldObj = {}
    Stills = {}
end)
AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then loadStills() end
end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    streaming = false
    closeUi()
    applyNuiFocus(false)
    for id in pairs(Objects) do despawnStill(id) end
    for id in pairs(WorldObj) do stopFx(id) end
    if Config.WorldStills and Config.WorldStills.enabled then exports['rsg-target']:removeModel(Config.WorldStills.models, 'moonshine_world_still') end
end)

RegisterNetEvent('rsg-moonshine:client:syncStill', function(s)
    Stills[s.id] = s
    if Objects[s.id] or WorldObj[s.id] then
        updateFx(s.id)
    elseif s.world then
        refreshNearby()
    elseif #(GetEntityCoords(PlayerPedId()) - s.coords) <= Config.SpawnDist then
        spawnStill(s)
        updateFx(s.id)
    end
end)

RegisterNetEvent('rsg-moonshine:client:explode', function(coords)
    -- visual and sound only (damage scale 0.0), same call and vfx hash as rsg-fireworks
    AddExplosionWithUserVfx(coords.x, coords.y, coords.z + 0.5, 32, 0x2FDA2B4A, 0.0, true, false, 0.0)
end)

RegisterNetEvent('rsg-moonshine:client:removeStill', function(id)
    if uiOpen == id then closeUi() end
    Stills[id] = nil
    WorldObj[id] = nil
    despawnStill(id)
end)

---------------------------------
-- still NUI
---------------------------------

local UiLocale = {
    'ui_title', 'ui_subtitle', 'ui_recipe', 'ui_choose_recipe', 'ui_hopper', 'ui_per_batch', 'ui_loaded', 'ui_have',
    'ui_load', 'ui_load_all', 'ui_unload', 'ui_status', 'ui_idle', 'ui_brewing', 'ui_waiting', 'ui_full',
    'ui_current_batch', 'ui_queued', 'ui_tank', 'ui_collect', 'ui_pickup', 'ui_change_recipe', 'ui_batch_time',
    'ui_makes', 'ui_close', 'ui_locked', 'ui_select',
    'ui_access', 'ui_trust_nearest', 'ui_trusted_none', 'ui_remove', 'ui_quality', 'ui_label', 'ui_label_save', 'ui_label_hint',
    'ui_firebox', 'ui_fuel_left', 'ui_burns', 'ui_each', 'ui_nofuel', 'ui_paused', 'ui_add', 'ui_jugs', 'ui_need_jugs', 'ui_level', 'ui_requires', 'ui_max_level', 'ui_xp',
    'ui_fermenting', 'ui_wash', 'ui_heat', 'ui_heat_low', 'ui_heat_medium', 'ui_heat_high', 'ui_heat_hint',
    'ui_proof', 'ui_rerun', 'ui_rerun_hint', 'ui_rerunning', 'ui_cut', 'ui_cut_tight', 'ui_cut_normal', 'ui_cut_loose',
    'ui_risk_none', 'ui_risk_low', 'ui_risk_med', 'ui_risk_high', 'ui_yield', 'ui_cask', 'ui_cask_install', 'ui_cask_none',
    'ui_cask_empty', 'ui_cask_age', 'ui_cask_ageing', 'ui_cask_collect', 'ui_cask_hint', 'ui_cask_next', 'ui_weather_cold', 'ui_weather_wet',
    'ui_night', 'ui_volume', 'ui_material_copper', 'ui_material_tin', 'ui_ingredient_quality', 'ui_wear', 'ui_water', 'ui_clean', 'ui_add_water', 'ui_sample', 'ui_sample_safe', 'ui_sample_foul', 'ui_dry', 'ui_barrel_title', 'ui_barrel_subtitle', 'ui_wash_take', 'ui_wash_load', 'ui_wash_carried',
}

-- every focus change goes through here so push-to-talk keeps working while the menu is open
local uiFocus = false
applyNuiFocus = function(enable)
    uiFocus = enable
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

CreateThread(function()
    while true do
        if uiFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            for _, c in ipairs(Config.PushToTalkControls or {}) do
                EnableControlAction(0, c, true)
                EnableControlAction(1, c, true)
                EnableControlAction(2, c, true)
            end
        else
            Wait(250)
        end
    end
end)

closeUi = function()
    if not uiOpen then return end
    uiOpen, uiReady = nil, false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

openStillMenu = function(id)
    if uiOpen then return end
    local state = RSGCore.Functions.AwaitCallback('rsg-moonshine:server:getState', nil, id)
    if not state then return end
    uiOpen = id

    local strings = {}
    for _, k in ipairs(UiLocale) do strings[k] = locale(k) end
    Wait(150) -- let rsg-target finish closing and release its own focus first
    if uiOpen ~= id then return end
    -- focus is only given once the page confirms it rendered (see 'opened' callback)
    SendNUIMessage({ action = 'open', state = state, locale = strings, imagePath = Config.ImagePath })
    SetTimeout(2000, function()
        if uiOpen == id and not uiReady then
            print('^1[rsg-moonshine] NUI did not respond - check the html files are on the server and run "refresh" then "ensure rsg-moonshine"^7')
            uiOpen = nil
            applyNuiFocus(false)
        end
    end)

    -- refresh loop + auto close when walking away / dying
    CreateThread(function()
        local ticks = 0
        while uiOpen == id do
            Wait(500)
            ticks = ticks + 1
            local ped = PlayerPedId()
            local s = Stills[id]
            if not s or IsEntityDead(ped) or #(GetEntityCoords(ped) - s.coords) > Config.InteractDist then
                closeUi()
                break
            end
            if ticks % 6 == 0 then -- every 3 seconds
                local st = RSGCore.Functions.AwaitCallback('rsg-moonshine:server:getState', nil, id)
                if uiOpen == id and st then SendNUIMessage({ action = 'update', state = st }) end
            end
        end
    end)
end

RegisterNUICallback('opened', function(_, cb)
    if uiOpen then
        uiReady = true
        applyNuiFocus(true)
    end
    cb('ok')
end)

RegisterNUICallback('uiError', function(data, cb)
    print(('^1[rsg-moonshine] NUI error: %s^7'):format(tostring(data and data.msg)))
    uiReady = false
    uiOpen = nil
    applyNuiFocus(false)
    cb('ok')
end)

-- emergency release if the cursor ever gets stuck
RegisterCommand('moonshine_unfocus', function()
    uiOpen, uiReady = nil, false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end, false)

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb('ok')
end)

RegisterNUICallback('action', function(data, cb)
    if not uiOpen then return cb('ok') end
    local id = uiOpen
    local state = RSGCore.Functions.AwaitCallback('rsg-moonshine:server:action', 5000, id, data.action, data.data)
    if state then
        SendNUIMessage({ action = 'update', state = state })
    elseif data.action == 'pickup' then
        closeUi()
    end
    cb('ok')
end)

---------------------------------
-- static world stills (map props)
---------------------------------
local function isPlacedStill(entity)
    for _, obj in pairs(Objects) do if obj == entity then return true end end
    return false
end

if Config.WorldStills and Config.WorldStills.enabled then
    exports['rsg-target']:addModel(Config.WorldStills.models, {
        {
            name = 'moonshine_world_still',
            icon = 'fa-solid fa-whiskey-glass',
            label = locale('cl_check'),
            distance = Config.WorldStills.distance or 2.5,
            canInteract = function(entity) return not isPlacedStill(entity) end,
            onSelect = function(data)
                local s = RSGCore.Functions.AwaitCallback('rsg-moonshine:server:getWorldStill', nil, GetEntityCoords(data.entity))
                if not s then return end
                Stills[s.id] = s
                WorldObj[s.id] = data.entity
                updateFx(s.id)
                openStillMenu(s.id)
            end,
        },
    })
end

---------------------------------
-- bootlegger buyers
---------------------------------
local BuyerZones = {}
if Config.Buyers and Config.Buyers.enabled then
    for i, spot in ipairs(Config.BuyerSpots) do
        BuyerZones[#BuyerZones + 1] = exports['rsg-target']:addSphereZone({
            coords = spot.coords, radius = Config.Buyers.distance,
            options = {{
                name = 'moonshine_buyer_' .. i, icon = 'fa-solid fa-sack-dollar', label = locale('cl_sell'), distance = Config.Buyers.distance,
                onSelect = function() RSGCore.Functions.AwaitCallback('rsg-moonshine:server:sell', 5000, i) end,
            }},
        })
    end
end
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, z in ipairs(BuyerZones) do exports['rsg-target']:removeZone(z) end
end)

---------------------------------
-- placement
---------------------------------
RegisterNetEvent('rsg-moonshine:client:placeStill', function(kind, material)
    if placing or uiOpen then return end
    kind = kind == 'barrel' and 'barrel' or 'still'
    placing = true

    CreateThread(function()
        local res = exports['rsg-gizmo']:Place(kind == 'barrel' and Config.Barrel.prop or Config.StillProp, {
            rotation = 'z',
            maxDistance = Config.PlaceDist,
            allowWater = false,
            validate = function(coords)
                for _, z in ipairs(Config.BlockedZones) do
                    if #(coords - z.coords) < z.radius then return false, locale('sv_blocked'):format(z.name) end
                end
                for _, st in pairs(Stills) do
                    local minD = (kind == 'barrel' or st.kind == 'barrel') and Config.Barrel.minDist or Config.MinStillDist
                    if #(coords - st.coords) < minD then return false, locale('sv_too_close') end
                end
                return true
            end,
        })
        if not res then
            placing = false
            return RSGCore.Functions.Notify({ title = locale('cl_still'), description = locale('cl_place_cancel'), type = 'inform' })
        end

        local ped = PlayerPedId()
        TaskTurnPedToFaceCoord(ped, res.coords.x, res.coords.y, res.coords.z, 1000)
        Wait(1000)
        if progress(locale('cl_loading'), 5000, 'amb_work@world_human_crouch_inspect@male_c@idle_a', 'idle_a') then
            TriggerServerEvent('rsg-moonshine:server:placeStill', res.coords, res.heading, kind, material)
        end
        placing = false
    end)
end)
