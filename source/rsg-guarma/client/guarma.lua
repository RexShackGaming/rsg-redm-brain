-------------------------------------
-- Guarma world state: horizon, water, minimap, ambience, shipwreck,
-- population and island weather. Natives checked in natives/db/INDEX.tsv,
-- usage taken from RDR2 decompiled guama*.c / camp_guarma.c / aguasdulces.c
-------------------------------------
local GUARMA_MAP = 1935063277
local WORLD_MAP  = -1868977180

local inGuarma = false
local weatherPaused = false

local function WeatherAvailable()
    return Config.Weather.enabled and GetResourceState('rsg-weather') == 'started'
end

-------------------------------------
-- island weather
-------------------------------------
local function SetHurricaneVariation(state)
    if state then
        Citizen.InvokeNative(0x3373779BAF7CAF48, 'HURRICANE', 'HURRICANE_guama') -- _SET_WEATHER_VARIATION
    else
        Citizen.InvokeNative(0x0E71C80FA4EC8147, 'HURRICANE', false)             -- _CLEAR_WEATHER_VARIATION
    end
end

local function ApplyIslandWeather(weather)
    if not inGuarma or not WeatherAvailable() or not weather then return end
    exports['rsg-weather']:setMyWeather(weather, Config.Weather.transition, false) -- also pauses rsg-weather sync
    SetHurricaneVariation(weather == 'hurricane')
    weatherPaused = true
end

local function RestoreServerWeather()
    if not weatherPaused then return end
    weatherPaused = false
    SetHurricaneVariation(false)
    if GetResourceState('rsg-weather') == 'started' then
        exports['rsg-weather']:setSyncEnabled(true)
    end
end

AddStateBagChangeHandler('guarmaWeather', 'global', function(_, _, value)
    ApplyIslandWeather(value)
end)

-------------------------------------
-- world switch
-------------------------------------
local function SetAmbience(state)
    if not Config.Guarma.AmbientAudio then return end
    Citizen.InvokeNative(0xF3638DAE8C4045E1, 'AZL_Endlesss_Summer_Enable', state, true)      -- SET_AMBIENT_ZONE_LIST_STATE_PERSISTENT
    Citizen.InvokeNative(0xF3638DAE8C4045E1, 'AZL_Endlesss_Summer_Disable', not state, true)
end

local function SetShipwreck(state)
    local wreck = Config.Guarma.Shipwreck
    if not wreck.enabled then return end
    local active = Citizen.InvokeNative(0xD779B9B910BD3B7C, wreck.ipl)                       -- IS_IPL_ACTIVE_HASH
    if state and not active then
        Citizen.InvokeNative(0x59767C5A7A9AE6DA, wreck.ipl)                                   -- REQUEST_IPL_HASH
    elseif not state and active then
        Citizen.InvokeNative(0x5A3E5CF7B4014B96, wreck.ipl)                                   -- REMOVE_IPL_HASH
    end
    Citizen.InvokeNative(0x3CACC83F6FED837C, wreck.cullbox, state)                            -- SET_MAPDATACULLBOX_ENABLED
end

function SetGuarmaWorld(state)
    if inGuarma == state then return end
    inGuarma = state

    Citizen.InvokeNative(0x74E2261D2A66849A, state)                                           -- _SET_GUARMA_WORLDHORIZON_ACTIVE
    Citizen.InvokeNative(0xE8770EE02AEE45C2, state and 1 or 0)                                -- _SET_WORLD_WATER_TYPE
    Citizen.InvokeNative(0xA657EC9DBC6CC900, state and GUARMA_MAP or WORLD_MAP)               -- _SET_MINIMAP_ZONE
    SetAmbience(state)
    SetShipwreck(state)

    if state then
        ApplyIslandWeather(GlobalState.guarmaWeather)
    else
        RestoreServerWeather()
    end

    TriggerEvent('rsg-guarma:client:guarmaChanged', state)
end

function IsPlayerInGuarma()
    return inGuarma
end

local function IsGuarmaCoords(coords)
    return coords.x >= 0 and coords.y <= -4096
end

-- keeps the world in sync (login inside Guarma, admin teleports, swimming)
CreateThread(function()
    while true do
        SetGuarmaWorld(IsGuarmaCoords(GetEntityCoords(cache.ped)))
        Wait(1000)
    end
end)

-------------------------------------
-- population (per-frame natives, only runs while on Guarma)
-------------------------------------
local populationRunning = false
AddEventHandler('rsg-guarma:client:guarmaChanged', function(state)
    local pop = Config.Guarma.Population
    if not state or not pop.enabled or populationRunning then return end
    -- 1.0 is the game default, so there is nothing to do every frame
    if pop.humanDensity == 1.0 and pop.pedRange == 1.0 and pop.scenarioDensity == 1.0 and pop.scenarioRange == 1.0 then return end
    populationRunning = true
    CreateThread(function()
        while inGuarma do
            Citizen.InvokeNative(0xBA0980B5C0A11924, pop.humanDensity)    -- _SET_AMBIENT_HUMAN_DENSITY_MULTIPLIER_THIS_FRAME
            Citizen.InvokeNative(0x0B919E1FB47CC4E0, pop.pedRange)        -- SET_AMBIENT_PED_RANGE_MULTIPLIER_THIS_FRAME
            Citizen.InvokeNative(0x95423627A9CA598E, pop.scenarioDensity) -- _SET_SCENARIO_PED_DENSITY_THIS_FRAME
            Citizen.InvokeNative(0xA77FA7BE9312F8C0, pop.scenarioRange)   -- _SET_SCENARIO_PED_RANGE_MULTIPLIER_THIS_FRAME
            Wait(0)
        end
        populationRunning = false
    end)
end)

-------------------------------------
-- cleanup
-------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetAmbience(false)
    SetShipwreck(false)
    RestoreServerWeather()
end)
