local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Stills  = {}   -- [id] = data
local Objects = {}   -- [id] = entity
local placing = false
local Fx      = {}    -- [id] = { particle handles }
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
    return lib.progressBar({
        duration = duration, label = label, useWhileDead = false, canCancel = true,
        disable = { move = true, combat = true, car = true },
        anim = dict and { dict = dict, clip = clip, flag = 1 } or nil,
    })
end

---------------------------------
-- brewing particle effects
---------------------------------
local function stopFx(id)
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
    for _, e in ipairs(Config.BrewFx.effects) do
        UseParticleFxAsset(dict)
        local h = StartParticleFxLoopedOnEntity(e.name, obj, e.offset.x, e.offset.y, e.offset.z, 0.0, 0.0, 0.0, e.scale, false, false, false)
        if h and h ~= 0 then handles[#handles + 1] = h end
    end
    Fx[id] = handles
end

local function updateFx(id)
    local s = Stills[id]
    if s and s.brewing then startFx(id) else stopFx(id) end
end

---------------------------------
-- props
---------------------------------
local openStillMenu, closeUi

local function despawnStill(id)
    stopFx(id)
    local obj = Objects[id]
    if obj and DoesEntityExist(obj) then
        exports.ox_target:removeLocalEntity(obj)
        DeleteObject(obj)
    end
    Objects[id] = nil
end

local function spawnStill(s)
    if Objects[s.id] then return end
    if not loadModel(Config.StillProp) then return end
    local obj = CreateObject(Config.StillProp, s.coords.x, s.coords.y, s.coords.z, false, false, false)
    SetEntityHeading(obj, s.heading)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    Objects[s.id] = obj

    exports.ox_target:addLocalEntity(obj, {
        {
            name = 'moonshine_check_' .. s.id,
            icon = 'fa-solid fa-whiskey-glass',
            label = locale('cl_check'),
            distance = 2.5,
            onSelect = function() openStillMenu(s.id) end,
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
local function startStreaming()
    if streaming then return end
    streaming = true
    CreateThread(function()
        while streaming do
            refreshNearby()
            Wait(2000)
        end
    end)
end

local function loadStills()
    local list = lib.callback.await('rsg-moonshine:server:getStills', false)
    for id in pairs(Objects) do despawnStill(id) end
    for id in pairs(WorldObj) do stopFx(id) end
    WorldObj = {}
    Stills = {}
    for _, s in ipairs(list or {}) do Stills[s.id] = s end
    refreshNearby()
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
    for id in pairs(Objects) do despawnStill(id) end
    for id in pairs(WorldObj) do stopFx(id) end
    if Config.WorldStills and Config.WorldStills.enabled then exports.ox_target:removeModel(Config.WorldStills.models, 'moonshine_world_still') end
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
    'ui_firebox', 'ui_fuel_left', 'ui_burns', 'ui_each', 'ui_nofuel', 'ui_paused', 'ui_add', 'ui_jugs', 'ui_need_jugs', 'ui_level', 'ui_requires', 'ui_max_level', 'ui_xp',
}

closeUi = function()
    if not uiOpen then return end
    uiOpen, uiReady = nil, false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

openStillMenu = function(id)
    if uiOpen then return end
    local state = lib.callback.await('rsg-moonshine:server:getState', false, id)
    if not state then return end
    uiOpen = id

    local strings = {}
    for _, k in ipairs(UiLocale) do strings[k] = locale(k) end
    Wait(150) -- let ox_target finish closing and release its own focus first
    if uiOpen ~= id then return end
    -- focus is only given once the page confirms it rendered (see 'opened' callback)
    SendNUIMessage({ action = 'open', state = state, locale = strings, imagePath = Config.ImagePath })
    SetTimeout(2000, function()
        if uiOpen == id and not uiReady then
            print('^1[rsg-moonshine] NUI did not respond - check the html files are on the server and run "refresh" then "ensure rsg-moonshine"^7')
            uiOpen = nil
            SetNuiFocus(false, false)
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
                local st = lib.callback.await('rsg-moonshine:server:getState', false, id)
                if uiOpen == id and st then SendNUIMessage({ action = 'update', state = st }) end
            end
        end
    end)
end

RegisterNUICallback('opened', function(_, cb)
    if uiOpen then
        uiReady = true
        SetNuiFocus(true, true)
    end
    cb('ok')
end)

RegisterNUICallback('uiError', function(data, cb)
    print(('^1[rsg-moonshine] NUI error: %s^7'):format(tostring(data and data.msg)))
    uiReady = false
    uiOpen = nil
    SetNuiFocus(false, false)
    cb('ok')
end)

-- emergency release if the cursor ever gets stuck
RegisterCommand('moonshine_unfocus', function()
    uiOpen, uiReady = nil, false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end, false)

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb('ok')
end)

RegisterNUICallback('action', function(data, cb)
    if not uiOpen then return cb('ok') end
    local id = uiOpen
    local state = lib.callback.await('rsg-moonshine:server:action', false, id, data.action, data.data)
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
    exports.ox_target:addModel(Config.WorldStills.models, {
        {
            name = 'moonshine_world_still',
            icon = 'fa-solid fa-whiskey-glass',
            label = locale('cl_check'),
            distance = Config.WorldStills.distance or 2.5,
            canInteract = function(entity) return not isPlacedStill(entity) end,
            onSelect = function(data)
                local s = lib.callback.await('rsg-moonshine:server:getWorldStill', false, GetEntityCoords(data.entity))
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
-- placement
---------------------------------
RegisterNetEvent('rsg-moonshine:client:placeStill', function()
    if placing then return end
    if not loadModel(Config.StillProp) then return end
    placing = true

    local ped = PlayerPedId()
    local heading = GetEntityHeading(ped)
    local ghost = CreateObject(Config.StillProp, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(ghost, 170, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    lib.showTextUI(locale('cl_place_help'))

    CreateThread(function()
        local result
        while placing do
            Wait(0)
            local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.0, 0.0)
            local found, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 2.0, false)
            local z = found and gz or pos.z - 1.0
            SetEntityCoordsNoOffset(ghost, pos.x, pos.y, z, false, false, false)
            SetEntityHeading(ghost, heading)

            DisableControlAction(0, 0x07CE1E61, true) -- attack (LMB)
            DisableControlAction(0, 0xF84FA74F, true) -- aim (RMB)
            if IsControlPressed(0, 0xA65EBAB4) then heading = heading + 1.5 end -- left arrow
            if IsControlPressed(0, 0xDEB34313) then heading = heading - 1.5 end -- right arrow

            if IsDisabledControlJustPressed(0, 0x07CE1E61) then
                result = { coords = vector3(pos.x, pos.y, z), heading = heading % 360.0 }
                placing = false
            elseif IsDisabledControlJustPressed(0, 0xF84FA74F) or IsEntityDead(ped) then
                placing = false
            end
        end

        DeleteObject(ghost)
        lib.hideTextUI()
        if not result then
            return lib.notify({ title = locale('cl_still'), description = locale('cl_place_cancel'), type = 'inform' })
        end
        -- quick client pre-check so players aren't made to sit through the progress bar for a placement the server will refuse
        for _, z in ipairs(Config.BlockedZones) do
            if #(result.coords - z.coords) < z.radius then
                return lib.notify({ title = locale('cl_still'), description = locale('sv_blocked'):format(z.name), type = 'error' })
            end
        end
        for _, st in pairs(Stills) do
            if #(result.coords - st.coords) < Config.MinStillDist then
                return lib.notify({ title = locale('cl_still'), description = locale('sv_too_close'), type = 'error' })
            end
        end
        TaskTurnPedToFaceCoord(ped, result.coords.x, result.coords.y, result.coords.z, 1000)
        Wait(1000)
        if progress(locale('cl_loading'), 5000, 'amb_work@world_human_crouch_inspect@male_c@idle_a', 'idle_a') then
            TriggerServerEvent('rsg-moonshine:server:placeStill', result.coords, result.heading)
        end
    end)
end)
