-- Backward compatibility with the old weathersync resource.
-- * exports.weathersync:xxx()  -> handled by `provide 'weathersync'` + exports in server.lua
-- * server-side TriggerEvent('weathersync:xxx', ...) from other resources -> handled below
-- * client TriggerServerEvent('weathersync:xxx', ...) -> handled below WITH an admin check
--   (the old resource let any client change the weather; this one does not)

local API = RSGWeather

local handlers = {
    ['weathersync:setWeather']          = API.setWeather,
    ['weathersync:resetWeather']        = API.resetWeather,
    ['weathersync:setWeatherPattern']   = API.setWeatherPattern,
    ['weathersync:resetWeatherPattern'] = API.resetWeatherPattern,
    ['weathersync:setTime']             = API.setTime,
    ['weathersync:resetTime']           = API.resetTime,
    ['weathersync:setTimescale']        = API.setTimescale,
    ['weathersync:resetTimescale']      = API.resetTimescale,
    ['weathersync:setSyncDelay']        = API.setSyncDelay,
    ['weathersync:resetSyncDelay']      = API.resetSyncDelay,
    ['weathersync:setWind']             = API.setWind,
    ['weathersync:resetWind']           = API.resetWind,
}

for event, fn in pairs(handlers) do
    if Config.EnableLegacyNetEvents then RegisterNetEvent(event) end
    AddEventHandler(event, function(...)
        local src = source
        -- source is '' / 0 / nil for server-side TriggerEvent; a number for clients
        local id = tonumber(src)
        if id and id > 0 and not RSGWeatherIsAdmin(id) then
            print(('^1[rsg-weather] player %s tried legacy event %s without permission^7'):format(id, event))
            RSGWeatherDeny(id, L('wh_what_legacy', 'legacy event %s', event))
            return
        end
        fn(...)
        local args = { ... }
        for i, v in ipairs(args) do args[i] = type(v) == 'table' and '{table}' or tostring(v) end
        RSGWeatherLog('admin', L('wh_legacy_event', '📜 Legacy event: %s', event), nil, {
            { name = L('wh_called_by', 'Called by'), value = (id and id > 0) and L('wh_player', 'player') or L('wh_resource_named', 'resource %s', tostring(GetInvokingResource() or '?')) },
            { name = L('wh_arguments', 'Arguments'), value = #args > 0 and table.concat(args, ', ') or L('none', 'none') },
        }, (id and id > 0) and id or false)
    end)
end

-- old client -> server requests
RegisterNetEvent('weathersync:init', function()
    -- nothing to do: clients read GlobalState directly
end)

RegisterNetEvent('weathersync:requestUpdatedForecast', function()
    local src = source
    if not RSGWeatherForecastAllowed(src) then return end
    TriggerClientEvent('weathersync:updateForecast', src, API.getForecast())
end)

RegisterNetEvent('weathersync:requestUpdatedAdminUi', function()
    local src = source
    if not RSGWeatherIsAdmin(src) then RSGWeatherDeny(src, L('wh_what_legacy_ui', 'legacy admin UI')); return end
    local s = API.getState()
    TriggerClientEvent('weathersync:updateAdminUi', src, s.weather, s.time, s.timescale, s.windDirection, s.windSpeed, s.syncDelay)
end)
