-- Seasonal events (Halloween / Christmas / your own) switched by real date
local API = RSGWeather
local cfg = Config.Seasonal

-- 'auto' | 'off' | '<eventName>' (forced by admin, survives restarts)
-- Stored in MySQL (oxmysql) instead of resource KVP, so no server "db" folder is created
local mode = 'auto'
local modeLoaded = false

MySQL.ready(function()
    MySQL.query.await('CREATE TABLE IF NOT EXISTS rsg_weather_state (`key` VARCHAR(50) NOT NULL PRIMARY KEY, value VARCHAR(100) NOT NULL)')
    local saved = MySQL.scalar.await('SELECT value FROM rsg_weather_state WHERE `key` = ?', { 'season_mode' })
    if not saved then
        -- one-time migration from the old KVP value (only read if a db folder already exists)
        saved = GetResourceKvpString('season_mode')
        if saved then
            MySQL.prepare.await('INSERT INTO rsg_weather_state (`key`, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value)', { 'season_mode', saved })
            DeleteResourceKvp('season_mode')
        end
    end
    if saved and (saved == 'auto' or saved == 'off' or Config.Seasonal.Events[saved]) then mode = saved end
    modeLoaded = true
end)
local current = nil     -- name of the event currently applied

local function dayNumber(month, day) return month * 100 + day end

local function inRange(ev, now)
    local s, f = dayNumber(ev.start.month, ev.start.day), dayNumber(ev.finish.month, ev.finish.day)
    local n = dayNumber(now.month, now.day)
    if s <= f then return n >= s and n <= f end
    return n >= s or n <= f -- wraps over new year
end

local function eventForToday()
    local now = os.date('*t')
    for name, ev in pairs(cfg.Events) do
        if inRange(ev, now) then return name end
    end
end

local function publish()
    local ev = current and cfg.Events[current]
    GlobalState.rsgSeason = ev and { name = current, label = ev.label, icon = ev.icon, night = ev.night, forced = mode ~= 'auto' } or { name = nil, forced = mode ~= 'auto' }
end

local function startEvent(name)
    local ev = cfg.Events[name]
    if not ev then return end
    current = name
    if not API.setWeatherPattern(ev.pattern) then
        print(('^1[rsg-weather] seasonal "%s" has an invalid pattern, keeping current pattern^7'):format(name))
    end
    API.setWeather(ev.startWeather or 'sunny', 30.0, false, ev.permanentSnow)
    print(('^2[rsg-weather] seasonal event started: %s^7'):format(ev.label or name))
    RSGWeatherLog('season', L('wh_season_started', '%s %s started', ev.icon or '✦', SeasonLabel(name)), nil, {
        { name = L('wh_mode', 'Mode'), value = mode }, { name = L('wh_start_weather', 'Start weather'), value = WeatherLabel(ev.startWeather or 'sunny') },
        { name = L('wh_snow_on_ground', 'Snow on ground'), value = YesNo(ev.permanentSnow == true) },
    }, false)
    TriggerEvent('rsg-weather:server:seasonStarted', name)
    publish()
end

local function endEvent()
    if not current then publish() return end
    local old = current
    current = nil
    TriggerEvent('rsg-weather:server:restorePattern')  -- patterns.lua re-applies the admin's active pattern
    API.setWeather(Config.Weather, 30.0, Config.WeatherIsFrozen, Config.PermanentSnow)
    print(('^3[rsg-weather] seasonal event ended: %s^7'):format(old))
    RSGWeatherLog('season', L('wh_season_ended', '%s ended', SeasonLabel(old)), nil, { { name = L('wh_mode', 'Mode'), value = mode } }, false)
    TriggerEvent('rsg-weather:server:seasonEnded', old)
    publish()
end

local function evaluate()
    local want
    if mode == 'off' then want = nil
    elseif mode == 'auto' then want = cfg.Enabled and eventForToday() or nil
    else want = mode end
    if want == current then return publish() end
    if current then endEvent() end
    if want then startEvent(want) end
end

-- API
local function setSeasonMode(m)
    if m ~= 'auto' and m ~= 'off' and not cfg.Events[m] then return false end
    mode = m
    MySQL.prepare('INSERT INTO rsg_weather_state (`key`, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value)', { 'season_mode', m })
    evaluate()
    return true
end

exports('getSeason', function() return current, mode end)
exports('setSeasonMode', setSeasonMode)
RSGWeatherSeason = {
    setMode = setSeasonMode,
    get = function()
        local list = {}
        for name, ev in pairs(cfg.Events) do
            list[#list + 1] = { name = name, label = SeasonLabel(name), icon = ev.icon,
                range = ('%02d/%02d - %02d/%02d'):format(ev.start.day, ev.start.month, ev.finish.day, ev.finish.month) }
        end
        table.sort(list, function(a, b) return a.name < b.name end)
        return { current = current, mode = mode, events = list }
    end,
}

-- if an admin hits "reset all" during an event, keep the event running
AddEventHandler('rsg-weather:server:patternsReset', function()
    if current then local c = current; current = nil; startEvent(c) end
end)

CreateThread(function()
    for name, ev in pairs(cfg.Events) do
        local sum
        for from, choices in pairs(ev.pattern or {}) do
            sum = 0
            for _, c in pairs(choices) do sum = sum + c end
            if sum ~= 100 then print(('^1[rsg-weather] seasonal "%s" block "%s" adds up to %d^7'):format(name, from, sum)) end
        end
    end
    Wait(1500) -- let patterns.lua load first
    while not modeLoaded do Wait(100) end -- wait for the saved season mode from MySQL
    publish()
    while true do
        evaluate()
        Wait(cfg.CheckInterval * 1000)
    end
end)
