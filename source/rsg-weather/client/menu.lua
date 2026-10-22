
-- every locale key starting with ui_ is sent to the NUI (elements use data-l="key")
local uiLocaleCache
function UiLocale()
    if uiLocaleCache then return uiLocaleCache end
    local res = GetCurrentResourceName()
    local en = json.decode(LoadResourceFile(res, 'locales/en.json') or '{}') or {}
    local lang = json.decode(LoadResourceFile(res, ('locales/%s.json'):format(GetConvar('ox:locale', 'en'))) or '{}') or {}
    uiLocaleCache = {}
    -- ui_*, weather_*, season_* keys go to the NUI; selected language overrides English
    for _, src in ipairs({ en, lang }) do
        for k, v in pairs(src) do
            if k:sub(1, 3) == 'ui_' or k:sub(1, 8) == 'weather_' or k:sub(1, 7) == 'season_' then uiLocaleCache[k] = v end
        end
    end
    return uiLocaleCache
end

local function fmtTime(h, m)
    if ShouldUse_24HourClock() then return ('%02d:%02d'):format(h, m) end
    local hh = h % 12
    return ('%d:%02d %s'):format(hh == 0 and 12 or hh, m, h >= 12 and 'PM' or 'AM')
end

---------------------------------
-- forecast NUI (everyone) - toggle overlay, no focus so players can keep moving
---------------------------------
local forecastOpen = false

local function buildForecast()
    local forecast = lib.callback.await('rsg-weather:server:getForecast', false)
    if not forecast or not forecast[1] then return nil end
    local coords = GetEntityCoords(cache.ped)

    local temp = GetTemperatureAtCoords(coords.x, coords.y, coords.z)
    local tempStr = ShouldUseMetricTemperature() and ('%d°C'):format(math.floor(temp)) or ('%d°F'):format(math.floor(temp * 9 / 5 + 32))
    local metric = ShouldUseMetricMeasurements and ShouldUseMetricMeasurements() or ShouldUseMetricTemperature()
    local ws = GetWindSpeed() * 3.6
    local dir = GetCardinalDirection(RSGWeatherClient.getWindDirection())
    local windStr = metric and ('%d kph %s'):format(math.floor(ws), dir) or ('%d mph %s'):format(math.floor(ws * 0.621371), dir)

    local entries = {}
    for i, f in ipairs(forecast) do
        entries[i] = {
            day = GetDayOfWeek(f.day),
            time = fmtTime(f.hour, f.minute),
            weather = TranslateWeatherForRegion(f.weather, coords),
            label = WeatherLabel(TranslateWeatherForRegion(f.weather, coords)),
            wind = GetCardinalDirection(f.wind),
        }
    end

    return {
        entries = entries,
        temperature = tempStr,
        wind = windStr,
        windDeg = RSGWeatherClient.getWindDirection(),
        altitude = math.floor(coords.z - Config.MeanSeaLevel),
        synced = RSGWeatherClient.isSyncEnabled(),
        season = GlobalState.rsgSeason and GlobalState.rsgSeason.name and { name = GlobalState.rsgSeason.name, label = SeasonLabel(GlobalState.rsgSeason.name), icon = GlobalState.rsgSeason.icon } or nil,
    }
end

local forecastGen = 0
local function toggleForecast()
    forecastOpen = not forecastOpen
    forecastGen = forecastGen + 1
    if not forecastOpen then
        SendNUIMessage({ action = 'forecastClose' })
        return
    end
    SendNUIMessage({ action = 'locale', locale = UiLocale() })
    local gen = forecastGen
    CreateThread(function()
        local nextRefresh, hidden = 0, false
        while forecastOpen and gen == forecastGen do
            -- hide while the pause menu is open
            local paused = IsPauseMenuActive()
            if paused ~= hidden then
                hidden = paused
                SendNUIMessage({ action = paused and 'forecastClose' or 'forecastShow' })
            end
            if not paused and GetGameTimer() >= nextRefresh then
                local data = buildForecast()
                if data and gen == forecastGen then SendNUIMessage({ action = 'forecast', data = data }) end
                nextRefresh = GetGameTimer() + 5000
            end
            Wait(500)
        end
    end)
end

RegisterNetEvent('rsg-weather:client:showForecast', toggleForecast)
exports('toggleForecast', toggleForecast)
exports('isForecastOpen', function() return forecastOpen end)

---------------------------------
-- admin NUI
---------------------------------
local uiOpen = false

local function closeUi()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function pushState()
    local s = lib.callback.await('rsg-weather:server:getAdminState', false)
    if s then SendNUIMessage({ action = 'state', state = s }) end
end

RegisterNetEvent('rsg-weather:client:openAdminMenu', function()
    local s = lib.callback.await('rsg-weather:server:getAdminState', false)
    if not s then return lib.notify({ title = locale('title'), description = locale('no_permission'), type = 'error' }) end
    local p = lib.callback.await('rsg-weather:server:getPatterns', false)
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', state = s, patterns = p, weatherTypes = WeatherTypes, locale = UiLocale() })
    CreateThread(function()
        while uiOpen do Wait(2000); if uiOpen then pushState() end end
    end)
end)

RegisterNUICallback('close', function(_, cb) closeUi(); cb({}) end)

RegisterNUICallback('action', function(data, cb)
    local ok = lib.callback.await('rsg-weather:server:adminAction', false, data.name, data.data)
    pushState()
    cb({ ok = ok })
end)

RegisterNUICallback('savePattern', function(data, cb)
    local ok, res = lib.callback.await('rsg-weather:server:savePattern', false, data.name, data.pattern, data.apply)
    if ok then cb({ ok = true, patterns = res }) else cb({ ok = false, error = res }) end
end)

RegisterNUICallback('deletePattern', function(data, cb)
    local ok, res = lib.callback.await('rsg-weather:server:deletePattern', false, data.name)
    cb({ ok = ok, patterns = res })
end)

RegisterNUICallback('applyPattern', function(data, cb)
    local ok, res = lib.callback.await('rsg-weather:server:applyPattern', false, data.name)
    cb({ ok = ok, patterns = res })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and uiOpen then SetNuiFocus(false, false) end
end)
