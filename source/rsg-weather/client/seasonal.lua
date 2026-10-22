-- Client side seasonal visuals: Halloween blood moon using the game's _MP_Pred weather variations
local bloodActive = false
local testMode    = false   -- /bloodmoon debug: force on regardless of date/time
local resetList   = {}      -- weather types whose variation we changed

local function currentNight()
    local s = GlobalState.rsgSeason
    if testMode then
        return (s and s.night) or (Config.Seasonal.Events.halloween and Config.Seasonal.Events.halloween.night)
    end
    return s and s.night
end

local function isNight(n)
    local h = GetClockHours()
    if n.fromHour > n.toHour then return h >= n.fromHour or h < n.toHour end
    return h >= n.fromHour and h < n.toHour
end

-- called by client.lua applyWeather() for every weather change
RSGWeatherClient.variationFor = function(weather)
    if not bloodActive or not RSGWeatherClient.isSyncEnabled() then return nil end
    local n = currentNight()
    local v = n and n.variations and n.variations[weather]
    if v then resetList[weather:upper()] = true end
    return v
end

local function resetVariations()
    for w in pairs(resetList) do
        Citizen.InvokeNative(0x0E71C80FA4EC8147, w, true) -- reset weather variation
    end
    resetList = {}
end

local function setBlood(on)
    if on == bloodActive then return end
    bloodActive = on
    if not on then
        resetVariations()
        Citizen.InvokeNative(0x80A398F16FFE3CC3) -- clear override so normal weather re-applies cleanly
    end
    RSGWeatherClient.resync()                     -- re-apply current weather with/without variation
    TriggerEvent('rsg-weather:client:bloodMoon', on)
end

CreateThread(function()
    Wait(3000)
    while true do
        local n = currentNight()
        setBlood(n ~= nil and n.variations ~= nil and (testMode or isNight(n)))
        Wait(5000)
    end
end)

AddStateBagChangeHandler('rsgSeason', 'global', function(_, _, value)
    SetTimeout(500, function()
        local n = currentNight()
        setBlood(n ~= nil and n.variations ~= nil and (testMode or isNight(n)))
        TriggerEvent('rsg-weather:client:seasonChanged', value and value.name)
    end)
end)

-- debug: /bloodmoon toggles a forced test and prints diagnostics
RegisterNetEvent('rsg-weather:client:bloodmoonDebug', function()
    testMode = not testMode
    local s = GlobalState.rsgSeason
    local n = currentNight()
    local w = RSGWeatherClient.getAppliedWeather()
    local info = locale('bloodmoon_info', SeasonLabel(s and s.name), GetClockHours(), tostring(n and isNight(n)),
        tostring(RSGWeatherClient.isSyncEnabled()), WeatherLabel(w),
        tostring(n and n.variations and w and n.variations[w] or locale('bloodmoon_no_variation')))
    print('[rsg-weather] blood moon: ' .. info)
    lib.notify({ title = locale('bloodmoon_title'), description = locale(testMode and 'bloodmoon_test_on' or 'bloodmoon_test_off') .. ' - ' .. info, type = 'inform', duration = 10000 })
    setBlood(n ~= nil and n.variations ~= nil and (testMode or isNight(n)))
end)

exports('getSeason', function() local s = GlobalState.rsgSeason; return s and s.name end)
exports('isBloodMoon', function() return bloodActive end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then resetVariations() end
end)
