local RSGCore = exports['rsg-core']:GetCoreObject()

---------------------------------
-- state
---------------------------------
local State = {
    weather        = Config.Weather,
    time           = Config.Time,
    timescale      = Config.Timescale,
    timeFrozen     = Config.TimeIsFrozen,
    weatherFrozen  = Config.WeatherIsFrozen,
    permanentSnow  = Config.PermanentSnow,
    windDirection  = Config.WindDirection,
    windSpeed      = Config.WindSpeed,
    windFrozen     = Config.WindIsFrozen,
    syncDelay      = Config.SyncDelay,
    pattern        = Config.WeatherPattern,
}
local forecast, weatherTicks = {}, 0

local function debug(...)
    if Config.Debug then print('^3[rsg-weather]^7', ...) end
end

---------------------------------
-- pattern / forecast
---------------------------------
-- strict validation: a bad pattern would otherwise crash the main sync loop
local function validatePattern(pattern)
    if type(pattern) ~= 'table' or not next(pattern) then return false end
    local ok = true
    for weather, choices in pairs(pattern) do
        local sum = 0
        if not IsValidWeather(weather) or type(choices) ~= 'table' then
            print(('^1[rsg-weather] pattern entry "%s" is invalid^7'):format(tostring(weather)))
            ok = false
        else
            for to, chance in pairs(choices) do
                if not IsValidWeather(to) or type(chance) ~= 'number' or chance < 0 then
                    print(('^1[rsg-weather] pattern "%s" -> "%s" is invalid^7'):format(weather, tostring(to)))
                    ok = false
                else
                    sum = sum + chance
                end
            end
            if sum ~= 100 then
                print(('^1[rsg-weather] pattern "%s" adds up to %s, not 100^7'):format(weather, sum))
                ok = false
            end
        end
    end
    return ok
end

local function patternKeys()
    local keys = {}
    for k in pairs(State.pattern) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

local function nextWeather(weather)
    if State.weatherFrozen then return weather end
    local choices = State.pattern[weather]
    if not choices then
        -- current weather isn't in the active pattern (e.g. a new pattern was applied): jump into it
        local keys = patternKeys()
        return keys[1] and keys[math.random(#keys)] or weather
    end
    local c, r = 0, math.random(1, 100)
    for w, chance in pairs(choices) do
        c = c + chance
        if r <= c then return w end
    end
    return weather
end

local function nextWind(direction)
    if State.windFrozen then return direction end
    return ((direction + math.random(0, 90) - 45) % 360) * 1.0
end

local function generateForecast()
    local w, d = nextWeather(State.weather), nextWind(State.windDirection)
    forecast = { { weather = w, wind = d } }
    for i = 2, Config.MaxForecast do
        w, d = nextWeather(w), nextWind(d)
        forecast[i] = { weather = w, wind = d }
    end
end

---------------------------------
-- broadcast via GlobalState
---------------------------------
local function pushWeather(transition)
    local scale = State.timescale > 0 and State.timescale or 1
    GlobalState.rsgWeather = {
        weather = State.weather,
        transition = transition or (Config.WeatherInterval / scale / 4),
        permanentSnow = State.permanentSnow,
        stamp = os.time(),
    }
end

local function pushTime(transition)
    GlobalState.rsgTime = {
        time = State.time,
        timescale = State.timescale,
        frozen = State.timeFrozen,
        transition = transition or 0,
        stamp = GetGameTimer(),
    }
end

local function pushWind()
    GlobalState.rsgWind = { direction = State.windDirection, speed = State.windSpeed }
end

---------------------------------
-- API (names match old weathersync exports)
---------------------------------
local API = {}

function API.getWeather() return State.weather end

function API.setWeather(weather, transition, freeze, permanentSnow)
    if not IsValidWeather(weather) then return false end
    State.weather       = weather:lower()
    State.weatherFrozen = freeze and true or false
    State.permanentSnow = permanentSnow and true or false
    weatherTicks = 0
    generateForecast()
    pushWeather(lib.math.clamp(tonumber(transition) or 10.0, 0.1, 300.0))
    TriggerEvent('rsg-weather:server:weatherChanged', State.weather)
    return true
end

function API.resetWeather()
    State.weather       = Config.Weather
    State.weatherFrozen = Config.WeatherIsFrozen
    State.permanentSnow = Config.PermanentSnow
    generateForecast()
    pushWeather(10.0)
end

function API.setWeatherPattern(pattern)
    if not validatePattern(pattern) then return false end
    State.pattern = pattern
    generateForecast()
    return true
end

function API.resetWeatherPattern()
    State.pattern = Config.WeatherPattern
    generateForecast()
end

function API.getTime()
    local d, h, m, s = TimeToDHMS(State.time)
    return { day = d, hour = h, minute = m, second = s }
end

function API.setTime(d, h, m, s, transition, freeze)
    State.time       = DHMSToTime(math.floor(tonumber(d) or 0) % 7, lib.math.clamp(math.floor(tonumber(h) or 0), 0, 23),
                                  lib.math.clamp(math.floor(tonumber(m) or 0), 0, 59), lib.math.clamp(math.floor(tonumber(s) or 0), 0, 59))
    State.timeFrozen = freeze and true or false
    pushTime(lib.math.clamp(math.floor(tonumber(transition) or 0), 0, 600000))
end

function API.resetTime()
    State.time       = Config.Time
    State.timeFrozen = Config.TimeIsFrozen
    pushTime(0)
end

function API.getTimescale() return State.timescale end

function API.setTimescale(scale)
    State.timescale = lib.math.clamp(tonumber(scale) or Config.Timescale, 0, 1000) + 0.0
    pushTime(0)
end

function API.resetTimescale() API.setTimescale(Config.Timescale) end

function API.getWind() return { direction = State.windDirection, speed = State.windSpeed } end

function API.setWind(direction, speed, frozen)
    State.windDirection = ((tonumber(direction) or 0.0) % 360) + 0.0
    State.windSpeed     = lib.math.clamp(tonumber(speed) or 0.0, 0, 50) + 0.0
    State.windFrozen    = frozen and true or false
    generateForecast()
    pushWind()
end

function API.resetWind()
    State.windDirection = Config.WindDirection
    State.windSpeed     = Config.WindSpeed
    State.windFrozen    = Config.WindIsFrozen
    generateForecast()
    pushWind()
end

function API.getSyncDelay() return State.syncDelay end

function API.setSyncDelay(delay)
    State.syncDelay = lib.math.clamp(math.floor(tonumber(delay) or Config.SyncDelay), 500, 60000)
end

function API.resetSyncDelay() State.syncDelay = Config.SyncDelay end

function API.getForecast()
    local out = {}
    for i = 0, #forecast do
        local d, h, m, s, weather, wind
        if i == 0 then
            d, h, m, s = TimeToDHMS(State.time)
            weather, wind = State.weather, State.windDirection
        else
            local t = State.timeFrozen and State.time or (State.time + Config.WeatherInterval * i) % WEEK_LENGTH
            d, h, m, s = TimeToDHMS(t - t % Config.WeatherInterval)
            weather, wind = forecast[i].weather, forecast[i].wind
        end
        out[#out + 1] = { day = d, hour = h, minute = m, second = s, weather = weather, wind = wind }
    end
    return out
end

-- everything except the (large) pattern table, which the admin UI doesn't need every poll
function API.getState()
    local out = {}
    for k, v in pairs(State) do if k ~= 'pattern' then out[k] = v end end
    return out
end

function API.resetAll()
    API.resetWeatherPattern(); API.resetWeather(); API.resetTime(); API.resetTimescale(); API.resetWind(); API.resetSyncDelay()
    TriggerEvent('rsg-weather:server:patternsReset')
end

-- register every API function as an export (also reachable as exports.weathersync:xxx via 'provide')
-- setters called by OTHER resources are logged to Discord with the calling resource name
for name, fn in pairs(API) do
    if name:match('^set') or name:match('^reset') then
        exports(name, function(...)
            local invoker = GetInvokingResource()
            if invoker and invoker ~= GetCurrentResourceName() and RSGWeatherLog then
                local args = { ... }
                for i, v in ipairs(args) do args[i] = type(v) == 'table' and '{table}' or tostring(v) end
                RSGWeatherLog('admin', L('wh_export', '🔌 Export: %s', name), nil, {
                    { name = L('wh_resource', 'Resource'), value = invoker },
                    { name = L('wh_arguments', 'Arguments'), value = #args > 0 and table.concat(args, ', ') or L('none', 'none') },
                }, false)
            end
            return fn(...)
        end)
    else
        exports(name, fn)
    end
end

RSGWeather = API -- used by legacy.lua / commands.lua

---------------------------------
-- permission helper
---------------------------------
function RSGWeatherIsAdmin(src)
    if not src or src <= 0 then return true end -- console
    for _, perm in ipairs(Config.AdminPermissions) do
        if RSGCore.Functions.HasPermission(src, perm) then return true end
    end
    return false
end

---------------------------------
-- callbacks
---------------------------------
-- simple per-player cooldown so the forecast can't be spammed
local lastForecast = {}
function RSGWeatherForecastAllowed(src)
    local now = GetGameTimer()
    if lastForecast[src] and now - lastForecast[src] < 1000 then return false end
    lastForecast[src] = now
    return true
end
AddEventHandler('playerDropped', function() lastForecast[source] = nil end)

lib.callback.register('rsg-weather:server:getForecast', function(src)
    if not RSGWeatherForecastAllowed(src) then return nil end
    return API.getForecast()
end)

local function deny(src, what)
    RSGWeatherLog('security', L('wh_unauthorised', '🚫 Unauthorised attempt'), L('wh_unauthorised_desc', 'Player tried to use **%s** without permission.', what), nil, src)
end
RSGWeatherDeny = deny

lib.callback.register('rsg-weather:server:getAdminState', function(src)
    if not RSGWeatherIsAdmin(src) then deny(src, L('wh_what_panel', 'weather admin panel')); return nil end
    local s = API.getState()
    s.season = RSGWeatherSeason and RSGWeatherSeason.get() or nil
    return s
end)

local function logAction(src, action, data)
    local f, t = {}, ''
    if action == 'weather' then
        t = L('wh_weather_changed', '🌦️ Weather changed')
        f = { { name = L('wh_weather', 'Weather'), value = WeatherLabel(data.weather) }, { name = L('wh_transition', 'Transition'), value = (data.transition or 10) .. 's' },
              { name = L('wh_frozen', 'Frozen'), value = YesNo(data.freeze == true) }, { name = L('wh_permanent_snow', 'Permanent snow'), value = YesNo(data.permanentSnow == true) } }
    elseif action == 'time' then
        local tm = API.getTime()
        t = L('wh_time_changed', '🕰️ Time changed')
        f = { { name = L('wh_time', 'Time'), value = ('%s %02d:%02d'):format(GetDayOfWeek(tm.day), tm.hour, tm.minute) }, { name = L('wh_frozen', 'Frozen'), value = YesNo(data.freeze == true) } }
    elseif action == 'timescale' then t = L('wh_timescale_changed', '⏩ Timescale changed'); f = { { name = L('wh_timescale', 'Timescale'), value = API.getTimescale() } }
    elseif action == 'wind' then
        local w = API.getWind()
        t = L('wh_wind_changed', '🌬️ Wind changed'); f = { { name = L('wh_direction', 'Direction'), value = ('%d° %s'):format(math.floor(w.direction), GetCardinalDirection(w.direction)) }, { name = L('wh_speed', 'Speed'), value = w.speed }, { name = L('wh_frozen', 'Frozen'), value = YesNo(data.freeze == true) } }
    elseif action == 'syncdelay' then t = L('wh_syncdelay_changed', '🔁 Sync delay changed'); f = { { name = L('wh_delay', 'Delay'), value = API.getSyncDelay() .. ' ms' } }
    elseif action == 'season' then t = L('wh_season_mode_changed', '🎃 Season mode changed'); f = { { name = L('wh_mode', 'Mode'), value = tostring(data.mode) } }
    elseif action == 'reset' then t = L('wh_reset', '♻️ Everything reset to config')
    end
    RSGWeatherLog('admin', t, nil, f, src)
end
RSGWeatherLogAction = logAction

lib.callback.register('rsg-weather:server:adminAction', function(src, action, data)
    if not RSGWeatherIsAdmin(src) then deny(src, L('wh_what_action', 'weather admin action: %s', tostring(action))); return false end
    if type(data) ~= 'table' then data = {} end
    local ok = (function()
    if action == 'weather' then
        return API.setWeather(data.weather, data.transition, data.freeze, data.permanentSnow)
    elseif action == 'time' then
        API.setTime(data.day, data.hour, data.minute, data.second, data.transition, data.freeze)
    elseif action == 'timescale' then
        API.setTimescale(data.timescale)
    elseif action == 'wind' then
        API.setWind(data.direction, data.speed, data.freeze)
    elseif action == 'syncdelay' then
        API.setSyncDelay(data.delay)
    elseif action == 'season' then
        return RSGWeatherSeason and RSGWeatherSeason.setMode(data.mode) or false
    elseif action == 'reset' then
        API.resetAll()
    else
        return false
    end
    return true
    end)()
    if ok then logAction(src, action, data) end
    return ok
end)

---------------------------------
-- main loop
---------------------------------
CreateThread(function()
    validatePattern(State.pattern)
    math.randomseed(os.time())
    generateForecast()
    pushWeather(1.0); pushTime(0); pushWind()

    while true do
        local tick
        if State.timescale == 0 then
            tick = State.syncDelay / 1000
            if not State.timeFrozen then
                local now = os.date('*t', os.time() + Config.RealTimeOffset)
                State.time = now.sec + now.min * 60 + now.hour * 3600 + (now.wday - 1) * DAY_LENGTH
            end
        else
            tick = State.timescale * (State.syncDelay / 1000)
            if not State.timeFrozen then
                State.time = math.floor(State.time + tick) % WEEK_LENGTH
            end
        end

        if not State.weatherFrozen then
            if weatherTicks >= Config.WeatherInterval then
                local nxt  = table.remove(forecast, 1)
                local last = forecast[#forecast] or nxt
                State.weather, State.windDirection = nxt.weather, nxt.wind
                forecast[#forecast + 1] = { weather = nextWeather(last.weather), wind = nextWind(last.wind) }
                weatherTicks = 0
                pushWeather()
                pushWind()
                TriggerEvent('rsg-weather:server:weatherChanged', State.weather)
                RSGWeatherLog('weather', L('wh_weather_natural', '🌤️ Weather changed naturally'), nil, {
                    { name = L('wh_weather', 'Weather'), value = WeatherLabel(State.weather) }, { name = L('wh_wind', 'Wind'), value = GetCardinalDirection(State.windDirection) },
                }, false)
                debug('weather ->', State.weather)
            else
                weatherTicks = weatherTicks + tick
            end
        end

        -- smooth clock transition except across midnight
        local wraps = (DAY_LENGTH - (State.time % DAY_LENGTH) + tick) % DAY_LENGTH <= tick
        pushTime(wraps and 0 or State.syncDelay)

        Wait(State.syncDelay)
    end
end)
