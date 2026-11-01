local RSGCore = exports['rsg-core']:GetCoreObject()
local API = RSGWeather

local function notify(src, desc, ntype)
    if src and src > 0 then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('title'), description = desc, type = ntype or 'inform', duration = 5000 })
    else
        print('[rsg-weather] ' .. desc)
    end
end

local function num(v) return ToNum(v, nil) end
local function flag(v) return tonumber(v) == 1 end

-- registers an admin command through rsg-core (ACE restricted) and re-checks permission server side
local function adminCommand(name, help, params, fn)
    RSGCore.Commands.Add(name, help, params, false, function(src, args)
        if src > 0 and not RSGWeatherIsAdmin(src) then
            RSGWeatherDeny(src, '/' .. name)
            return notify(src, locale('no_permission'), 'error')
        end
        fn(src, args)
    end, table.unpack(Config.AdminPermissions))
end

local function p(name, help) return { name = name, help = locale(help) } end

adminCommand('weather', locale('cmd_weather'), { p('type', 'arg_weather'), p('transition', 'arg_transition'), p('freeze', 'arg_freeze'), p('snow', 'arg_snow') }, function(src, args)
    local w = args[1] and args[1]:lower()
    if not IsValidWeather(w) then return notify(src, locale('unknown_weather', tostring(w)), 'error') end
    local t = Clamp(num(args[2]) or 10.0, 0.1, 300.0)
    API.setWeather(w, t + 0.0, flag(args[3]), flag(args[4]))
    notify(src, locale('weather_set', WeatherLabel(w)), 'success')
    RSGWeatherLogAction(src, 'weather', { weather = w, transition = t, freeze = flag(args[3]), permanentSnow = flag(args[4]) })
end)

adminCommand('time', locale('cmd_time'), { p('day', 'arg_day'), p('hour', 'arg_hour'), p('minute', 'arg_minute'), p('second', 'arg_second'), p('transition', 'arg_transition_ms'), p('freeze', 'arg_freeze') }, function(src, args)
    if num(args[1]) then
        API.setTime(num(args[1]), num(args[2]) or 0, num(args[3]) or 0, num(args[4]) or 0, num(args[5]) or 0, flag(args[6]))
        RSGWeatherLogAction(src, 'time', { freeze = flag(args[6]) })
    end
    local t = API.getTime()
    notify(src, locale('time_set', GetDayOfWeek(t.day), t.hour, t.minute))
end)

adminCommand('timescale', locale('cmd_timescale'), { p('scale', 'arg_scale') }, function(src, args)
    if num(args[1]) then API.setTimescale(num(args[1])); RSGWeatherLogAction(src, 'timescale', {}) end
    notify(src, locale('timescale_set', API.getTimescale()))
end)

adminCommand('wind', locale('cmd_wind'), { p('direction', 'arg_direction'), p('speed', 'arg_speed'), p('freeze', 'arg_freeze') }, function(src, args)
    if not num(args[1]) then return notify(src, locale('cmd_wind'), 'error') end
    API.setWind(num(args[1]), num(args[2]) or 0.0, flag(args[3]))
    RSGWeatherLogAction(src, 'wind', { freeze = flag(args[3]) })
    local w = API.getWind()
    notify(src, locale('wind_set', math.floor(w.direction), w.speed), 'success')
end)

adminCommand('syncdelay', locale('cmd_syncdelay'), { p('delay', 'arg_delay') }, function(src, args)
    if num(args[1]) then API.setSyncDelay(num(args[1])); RSGWeatherLogAction(src, 'syncdelay', {}) end
    notify(src, locale('syncdelay_set', API.getSyncDelay()))
end)

adminCommand('weatherui', locale('cmd_weatherui'), {}, function(src)
    if src > 0 then TriggerClientEvent('rsg-weather:client:openAdminMenu', src) end
end)

adminCommand('weathersync', locale('cmd_weathersync'), {}, function(src)
    if src > 0 then TriggerClientEvent('rsg-weather:client:toggleSync', src) end
end)

adminCommand('mytime', locale('cmd_mytime'), { p('hour', 'arg_hour'), p('minute', 'arg_minute'), p('second', 'arg_second'), p('transition', 'arg_transition_ms') }, function(src, args)
    if src <= 0 or not num(args[1]) then return end
    TriggerClientEvent('rsg-weather:client:setMyTime', src, num(args[1]), num(args[2]) or 0, num(args[3]) or 0, num(args[4]) or 0)
end)

adminCommand('myweather', locale('cmd_myweather'), { p('type', 'arg_weather'), p('transition', 'arg_transition'), p('snow', 'arg_snow') }, function(src, args)
    if src <= 0 then return end
    local w = args[1] and args[1]:lower()
    if not IsValidWeather(w) then return notify(src, locale('unknown_weather', tostring(w)), 'error') end
    TriggerClientEvent('rsg-weather:client:setMyWeather', src, w, num(args[2]) or 5.0, flag(args[3]))
end)

RSGCore.Commands.Add('forecast', locale('cmd_forecast'), {}, false, function(src)
    if src > 0 then
        TriggerClientEvent('rsg-weather:client:showForecast', src)
    else
        for _, f in ipairs(API.getForecast()) do
            print(('%s %02d:%02d  %s  %s'):format(GetDayOfWeek(f.day), f.hour, f.minute, WeatherLabel(f.weather), GetCardinalDirection(f.wind)))
        end
    end
end, 'user')

adminCommand('season', locale('cmd_season'), { p('mode', 'arg_season_mode') }, function(src, args)
    local mode = args[1] and args[1]:lower()
    if mode then
        if not RSGWeatherSeason.setMode(mode) then return notify(src, locale('season_unknown', mode), 'error') end
        RSGWeatherLogAction(src, 'season', { mode = mode })
    end
    local s = RSGWeatherSeason.get()
    notify(src, locale('season_status', SeasonLabel(s.current), s.mode), 'inform')
end)

adminCommand('bloodmoon', locale('cmd_bloodmoon'), {}, function(src)
    if src > 0 then TriggerClientEvent('rsg-weather:client:bloodmoonDebug', src) end
end)

adminCommand('weatherwebhook', locale('cmd_weatherwebhook'), { p('action', 'arg_webhook_action') }, function(src, args)
    local a = args[1] and args[1]:lower()
    if a == 'test' then
        for cat, c in pairs(WebhookConfig.Categories) do
            if c.enabled then RSGWeatherLog(cat, L('wh_test', '🧪 Webhook test'), L('wh_test_desc', 'Test message for category **%s**.', cat), nil, src) end
        end
        notify(src, locale('webhook_test_sent'), 'success')
    elseif a == 'forecast' then
        RSGWeatherPostForecast()
        notify(src, locale('webhook_forecast_sent'), 'success')
    else
        notify(src, locale('webhook_usage'), 'error')
    end
end)
