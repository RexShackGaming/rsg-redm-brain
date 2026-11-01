-- Client-side compatibility with old weathersync events.
-- Other resources that did TriggerEvent('weathersync:setSyncEnabled', false) etc. keep working.
local C = RSGWeatherClient

RegisterNetEvent('weathersync:toggleSync',     C.toggleSync)
RegisterNetEvent('weathersync:setSyncEnabled', C.setSyncEnabled)
RegisterNetEvent('weathersync:setMyWeather',   C.setMyWeather)
RegisterNetEvent('weathersync:setMyTime',      C.setMyTime)
RegisterNetEvent('weathersync:toggleForecast', function() TriggerEvent('rsg-weather:client:showForecast') end)
RegisterNetEvent('weathersync:openAdminUi',    function() TriggerEvent('rsg-weather:client:openAdminMenu') end)

-- re-emit the old local events so scripts listening to them still get updates
AddEventHandler('rsg-weather:client:weatherChanged', function(translated, serverWeather)
    TriggerEvent('weathersync:changeWeather', serverWeather, 10.0, false)
end)
