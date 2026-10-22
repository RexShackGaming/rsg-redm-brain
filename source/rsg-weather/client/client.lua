
---------------------------------
-- local state
---------------------------------
local syncEnabled    = true
local appliedWeather = nil   -- weather actually applied to the game (after region translation)
local snowOnGround   = false
local localWeather   = nil   -- used when sync disabled
local windDirection  = 0.0

local function SetSnowCoverageType(t) Citizen.InvokeNative(0xF02A9C330BBFC5C7, t) end

local function applyWeather(weather, transition)
    transition = (transition or 1.0) + 0.0
    -- seasonal weather variation (e.g. Halloween blood moon), provided by client/seasonal.lua
    local variation = RSGWeatherClient and RSGWeatherClient.variationFor and RSGWeatherClient.variationFor(weather)
    if variation then
        Citizen.InvokeNative(0x80A398F16FFE3CC3)                                   -- CLEAR_OVERRIDE_WEATHER
        Citizen.InvokeNative(0x3373779BAF7CAF48, weather:upper(), variation, transition) -- SET_WEATHER_VARIATION
        Citizen.InvokeNative(0x59174F1AFE095B5A, joaat(weather), true, true, true, transition, false)
        return
    end
    -- _SET_WEATHER_TYPE(hash, p1, p2, overrideNetwork, transitionTime, p5)
    Citizen.InvokeNative(0x59174F1AFE095B5A, joaat(weather), true, false, true, transition, false)
end

local function applyTime(h, m, s, transitionMs)
    -- _NETWORK_CLOCK_TIME_OVERRIDE(h, m, s, transitionMs, freeze)
    Citizen.InvokeNative(0x669E223E64B1903C, h, m, s, math.floor(transitionMs or 0), true)
end

local function setSnow(on)
    if on ~= snowOnGround then
        snowOnGround = on
        SetSnowCoverageType(on and 3 or 0)
    end
end

---------------------------------
-- regions
---------------------------------
local function inSnowy(x, y)    return (x <= -700.0 and y >= 1090.0) or (x <= -500.0 and y >= 2388.0) end
local function inDesert(x, y)   return x <= -2050 and y <= -1750 end
local function inNorth(_, y)    return y >= 1050 end
local function inGuarma(x, y)   return x >= 0 and y <= -4096 end

local translations = {
    rain         = { snow = 'snow',           desert = 'thunder' },
    thunderstorm = { snow = 'blizzard',       desert = 'rain' },
    hurricane    = { snow = 'whiteout',       desert = 'sandstorm' },
    drizzle      = { snow = 'snowlight',      desert = 'sunny' },
    shower       = { snow = 'groundblizzard', desert = 'sunny' },
    fog          = { snowOnly = 'snowlight' },
    misty        = { snowOnly = 'snowlight' },
    snow         = { guarma = 'sunny' },
    snowlight    = { guarma = 'sunny' },
    blizzard     = { guarma = 'sunny' },
}

local function translateWeather(weather, coords)
    if not Config.RegionalWeather then return weather end
    local t = translations[weather]
    if not t then return weather end
    local x, y, z = coords.x, coords.y, coords.z
    if t.guarma then return inGuarma(x, y) and t.guarma or weather end
    if t.snowOnly then return inSnowy(x, y) and t.snowOnly or weather end
    if inSnowy(x, y) or (inNorth(x, y) and GetTemperatureAtCoords(x, y, z) < 0.0) then return t.snow end
    if inDesert(x, y) then return t.desert end
    return weather
end
TranslateWeatherForRegion = translateWeather

---------------------------------
-- weather sync
---------------------------------
local function syncWeather(force)
    if not syncEnabled then return end
    local data = GlobalState.rsgWeather
    if not data then return end

    local coords = GetEntityCoords(cache.ped)
    local translated = translateWeather(data.weather, coords)
    local transition = data.transition or 10.0

    if not appliedWeather then
        transition = 1.0
        SetSnowCoverageType(0); snowOnGround = false
    end

    setSnow(data.permanentSnow or (Config.DynamicSnow and (inSnowy(coords.x, coords.y) or IsSnowyWeather(translated))))

    if force or translated ~= appliedWeather then
        applyWeather(translated, transition)
        appliedWeather = translated
        TriggerEvent('rsg-weather:client:weatherChanged', translated, data.weather)
    end
end

AddStateBagChangeHandler('rsgWeather', 'global', function() SetTimeout(0, syncWeather) end)

---------------------------------
-- time sync
---------------------------------
local function syncTime()
    if not syncEnabled then return end
    local data = GlobalState.rsgTime
    if not data then return end
    local _, h, m, s = TimeToDHMS(data.time)
    applyTime(h, m, s, data.transition)
end

AddStateBagChangeHandler('rsgTime', 'global', function() SetTimeout(0, syncTime) end)

---------------------------------
-- wind (with altitude shear)
---------------------------------
local function syncWind()
    local data = GlobalState.rsgWind
    if not data then return end
    local ped = cache.ped
    local seaAlt = GetEntityCoords(ped).z - Config.MeanSeaLevel
    local groundAlt = GetEntityHeightAboveGround(ped)
    local dir = (data.direction + math.floor(seaAlt / Config.WindShearInterval) * Config.WindShearDirection) % 360
    local spd = data.speed + math.max(0, math.floor(groundAlt / Config.WindShearInterval)) * Config.WindShearSpeed
    windDirection = dir
    SetWindDirection(dir + 0.0)
    SetWindSpeed(spd + 0.0)
end

---------------------------------
-- region / wind refresh loop (player moving between regions)
---------------------------------
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn and not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    syncTime(); syncWeather(true); syncWind()
    while true do
        Wait(2000)
        syncWeather()
        syncWind()
    end
end)

---------------------------------
-- local overrides (sync off)
---------------------------------
-- silent for exports/legacy events (other scripts may toggle sync often); notify only from the command
local function toggleSync(notify)
    syncEnabled = not syncEnabled
    appliedWeather = nil
    if syncEnabled then
        localWeather = nil
        syncTime(); syncWeather(true)
    end
    if notify == true then
        lib.notify({ title = locale('title'), description = syncEnabled and locale('sync_on') or locale('sync_off'), type = 'inform' })
    end
end

local function setSyncEnabled(toggle)
    if syncEnabled ~= (toggle and true or false) then toggleSync() end
end

local function setMyWeather(weather, transition, permanentSnow)
    if not IsValidWeather(weather) then return end
    if syncEnabled then toggleSync() end
    transition = tonumber(transition) or 5.0
    if transition <= 0.0 then transition = 0.1 end
    applyWeather(weather:lower(), transition)
    localWeather = weather:lower()
    setSnow(permanentSnow and true or false)
end

local function setMyTime(h, m, s, transition)
    if syncEnabled then toggleSync() end
    applyTime(tonumber(h) or 0, tonumber(m) or 0, tonumber(s) or 0, tonumber(transition) or 0)
end

local function getWeather()
    return syncEnabled and appliedWeather or localWeather
end

RegisterNetEvent('rsg-weather:client:toggleSync', function() toggleSync(true) end)
RegisterNetEvent('rsg-weather:client:setMyTime', setMyTime)
RegisterNetEvent('rsg-weather:client:setMyWeather', setMyWeather)

---------------------------------
-- client exports (same names as weathersync + a few new ones)
---------------------------------
exports('toggleSync', function() toggleSync() end)
exports('setSyncEnabled', setSyncEnabled)
exports('isSyncEnabled', function() return syncEnabled end)
exports('setMyWeather', setMyWeather)
exports('setMyTime', setMyTime)
exports('isSnowOnGround', function() return snowOnGround end)
exports('getWeather', getWeather)
exports('getServerWeather', function() return GlobalState.rsgWeather and GlobalState.rsgWeather.weather end)
exports('getWindDirection', function() return windDirection end)

-- shared with legacy.lua / menu.lua
RSGWeatherClient = {
    toggleSync = function() toggleSync() end, setSyncEnabled = setSyncEnabled,
    setMyWeather = setMyWeather, setMyTime = setMyTime,
    getWindDirection = function() return windDirection end,
    isSyncEnabled = function() return syncEnabled end,
    resync = function() syncWeather(true) end,
    getAppliedWeather = function() return appliedWeather end,
}

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Citizen.InvokeNative(0x80A398F16FFE3CC3) -- CLEAR_OVERRIDE_WEATHER
    SetSnowCoverageType(0)
end)
