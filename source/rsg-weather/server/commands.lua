local API = RSGWeather

local function notify(src, desc, ntype)
    if src and src > 0 then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('title'), description = desc, type = ntype or 'inform' })
    else
        print('[rsg-weather] ' .. desc)
    end
end

local adminGroup = {}
for i, perm in ipairs(Config.AdminPermissions) do adminGroup[i] = 'group.' .. perm end

lib.addCommand('weather', {
    help = locale('cmd_weather'),
    params = {
        { name = 'type', type = 'string', help = locale('arg_weather') },
        { name = 'transition', type = 'number', help = locale('arg_transition'), optional = true },
        { name = 'freeze', type = 'number', help = locale('arg_freeze'), optional = true },
        { name = 'snow', type = 'number', help = locale('arg_snow'), optional = true },
    },
    restricted = adminGroup,
}, function(src, args)
    local w = args.type:lower()
    if not IsValidWeather(w) then return notify(src, locale('unknown_weather', w), 'error') end
    local t = math.max(args.transition or 10.0, 0.1)
    API.setWeather(w, t + 0.0, args.freeze == 1, args.snow == 1)
    notify(src, locale('weather_set', WeatherLabel(w)), 'success')
    RSGWeatherLogAction(src, 'weather', { weather = w, transition = t, freeze = args.freeze == 1, permanentSnow = args.snow == 1 })
end)

lib.addCommand('time', {
    help = locale('cmd_time'),
    params = {
        { name = 'day', type = 'number', help = locale('arg_day'), optional = true },
        { name = 'hour', type = 'number', help = locale('arg_hour'), optional = true },
        { name = 'minute', type = 'number', help = locale('arg_minute'), optional = true },
        { name = 'second', type = 'number', help = locale('arg_second'), optional = true },
        { name = 'transition', type = 'number', help = locale('arg_transition_ms'), optional = true },
        { name = 'freeze', type = 'number', help = locale('arg_freeze'), optional = true },
    },
    restricted = adminGroup,
}, function(src, args)
    if args.day then
        API.setTime(args.day, args.hour or 0, args.minute or 0, args.second or 0, args.transition or 0, args.freeze == 1)
        RSGWeatherLogAction(src, 'time', { freeze = args.freeze == 1 })
    end
    local t = API.getTime()
    notify(src, locale('time_set', GetDayOfWeek(t.day), t.hour, t.minute))
end)

lib.addCommand('timescale', {
    help = locale('cmd_timescale'),
    params = { { name = 'scale', type = 'number', help = locale('arg_scale'), optional = true } },
    restricted = adminGroup,
}, function(src, args)
    if args.scale then API.setTimescale(args.scale); RSGWeatherLogAction(src, 'timescale', {}) end
    notify(src, locale('timescale_set', API.getTimescale()))
end)

lib.addCommand('wind', {
    help = locale('cmd_wind'),
    params = {
        { name = 'direction', type = 'number', help = locale('arg_direction') },
        { name = 'speed', type = 'number', help = locale('arg_speed'), optional = true },
        { name = 'freeze', type = 'number', help = locale('arg_freeze'), optional = true },
    },
    restricted = adminGroup,
}, function(src, args)
    API.setWind(args.direction, args.speed or 0.0, args.freeze == 1)
    RSGWeatherLogAction(src, 'wind', { freeze = args.freeze == 1 })
    local w = API.getWind()
    notify(src, locale('wind_set', math.floor(w.direction), w.speed), 'success')
end)

lib.addCommand('syncdelay', {
    help = locale('cmd_syncdelay'),
    params = { { name = 'delay', type = 'number', help = locale('arg_delay'), optional = true } },
    restricted = adminGroup,
}, function(src, args)
    if args.delay then API.setSyncDelay(args.delay); RSGWeatherLogAction(src, 'syncdelay', {}) end
    notify(src, locale('syncdelay_set', API.getSyncDelay()))
end)

lib.addCommand('weatherui', { help = locale('cmd_weatherui'), restricted = adminGroup }, function(src)
    if src > 0 then TriggerClientEvent('rsg-weather:client:openAdminMenu', src) end
end)

lib.addCommand('weathersync', { help = locale('cmd_weathersync'), restricted = adminGroup }, function(src)
    if src > 0 then TriggerClientEvent('rsg-weather:client:toggleSync', src) end
end)

lib.addCommand('mytime', {
    help = locale('cmd_mytime'),
    params = {
        { name = 'hour', type = 'number', help = locale('arg_hour') },
        { name = 'minute', type = 'number', help = locale('arg_minute'), optional = true },
        { name = 'second', type = 'number', help = locale('arg_second'), optional = true },
        { name = 'transition', type = 'number', help = locale('arg_transition_ms'), optional = true },
    },
    restricted = adminGroup,
}, function(src, args)
    TriggerClientEvent('rsg-weather:client:setMyTime', src, args.hour, args.minute or 0, args.second or 0, args.transition or 0)
end)

lib.addCommand('myweather', {
    help = locale('cmd_myweather'),
    params = {
        { name = 'type', type = 'string', help = locale('arg_weather') },
        { name = 'transition', type = 'number', help = locale('arg_transition'), optional = true },
        { name = 'snow', type = 'number', help = locale('arg_snow'), optional = true },
    },
    restricted = adminGroup,
}, function(src, args)
    local w = args.type:lower()
    if not IsValidWeather(w) then return notify(src, locale('unknown_weather', w), 'error') end
    TriggerClientEvent('rsg-weather:client:setMyWeather', src, w, args.transition or 5.0, args.snow == 1)
end)

lib.addCommand('forecast', { help = locale('cmd_forecast') }, function(src)
    if src > 0 then
        TriggerClientEvent('rsg-weather:client:showForecast', src)
    else
        for _, f in ipairs(API.getForecast()) do
            print(('%s %02d:%02d  %s  %s'):format(GetDayOfWeek(f.day), f.hour, f.minute, WeatherLabel(f.weather), GetCardinalDirection(f.wind)))
        end
    end
end)

lib.addCommand('season', {
    help = locale('cmd_season'),
    params = { { name = 'mode', type = 'string', help = locale('arg_season_mode'), optional = true } },
    restricted = adminGroup,
}, function(src, args)
    if args.mode then
        if not RSGWeatherSeason.setMode(args.mode:lower()) then return notify(src, locale('season_unknown', args.mode), 'error') end
        RSGWeatherLogAction(src, 'season', { mode = args.mode:lower() })
    end
    local s = RSGWeatherSeason.get()
    notify(src, locale('season_status', SeasonLabel(s.current), s.mode), 'inform')
end)

lib.addCommand('bloodmoon', { help = locale('cmd_bloodmoon'), restricted = adminGroup }, function(src)
    if src > 0 then TriggerClientEvent('rsg-weather:client:bloodmoonDebug', src) end
end)

lib.addCommand('weatherwebhook', {
    help = locale('cmd_weatherwebhook'),
    params = { { name = 'action', type = 'string', help = locale('arg_webhook_action') } },
    restricted = adminGroup,
}, function(src, args)
    local a = args.action:lower()
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
