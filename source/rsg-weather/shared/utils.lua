lib.locale() -- loads locales/<ox:locale>.json once for client and server

-- Shared helpers (kept global with the same names as weathersync for compatibility)

WeatherTypes = {
    'blizzard', 'clouds', 'drizzle', 'fog', 'groundblizzard', 'hail', 'highpressure',
    'hurricane', 'misty', 'overcast', 'overcastdark', 'rain', 'sandstorm', 'shower',
    'sleet', 'snow', 'snowlight', 'sunny', 'thunder', 'thunderstorm', 'whiteout'
}
RDR2WeatherTypes = WeatherTypes -- legacy alias

DAY_LENGTH  = 86400
WEEK_LENGTH = 604800

function TimeToDHMS(time)
    time = math.floor(time or 0)
    return math.floor(time / 86400), math.floor(time / 3600) % 24, math.floor(time / 60) % 60, time % 60
end

function DHMSToTime(day, hour, minute, second)
    return (day or 0) * 86400 + (hour or 0) * 3600 + (minute or 0) * 60 + (second or 0)
end

-- translate a locale key, falling back to `fallback` when ox_lib has no entry for it
function L(key, fallback, ...)
    if type(locale) == 'function' then
        local ok, v = pcall(locale, key, ...)
        if ok and v and v ~= key then return v end
    end
    if fallback and select('#', ...) > 0 then return fallback:format(...) end
    return fallback or key
end

local DIRS = { 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'N' }
function GetCardinalDirection(h)
    local d = DIRS[math.floor(((h or 0) % 360 + 22.5) / 45) + 1]
    return L('dir_' .. d, d)
end

local DAYS = { 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' }
function GetDayOfWeek(day)
    local i = (day or 0) % 7
    return L('day_' .. i, DAYS[i + 1])
end

-- display name of a weather type ("overcastdark" -> "Dark Overcast" / translated)
function WeatherLabel(w)
    if not w then return '?' end
    return L('weather_' .. w, (w:gsub('^%l', string.upper)))
end

-- display name of a seasonal event
function SeasonLabel(name)
    if not name then return L('none', 'none') end
    local ev = Config and Config.Seasonal and Config.Seasonal.Events[name]
    return L('season_' .. name, ev and ev.label or name)
end

function IsValidWeather(weather)
    if type(weather) ~= 'string' then return false end
    weather = weather:lower()
    for i = 1, #WeatherTypes do
        if WeatherTypes[i] == weather then return true end
    end
    return false
end

function IsSnowyWeather(w)
    return w == 'blizzard' or w == 'groundblizzard' or w == 'snow' or w == 'whiteout' or w == 'snowlight'
end
