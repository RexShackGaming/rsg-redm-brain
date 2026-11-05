-- RedM adapter only. Signatures checked against alloc8or/rdr3-nativedb-data.
-- Application attempts still require in-game visual acceptance on the supported build.
WeatherNative = {}
local N, W = WeatherNative, Weather
local lastWeather, lastWind, lastSnow, ownsClock, ownsSnow = nil, nil, nil, false, false

function N.Apply(state)
    local _, hour, minute, second = W.TimeParts(state.clock)
    -- Keep the native clock paused; the local elapsed-time projection drives it.
    Citizen.InvokeNative(0x669E223E64B1903C, hour, minute, second, 0, true)
    ownsClock = true
    if lastWeather ~= state.weatherToken then
        Citizen.InvokeNative(0x59174F1AFE095B5A, GetHashKey(state.weather.name), true, true, true,
            state.weather.transitionSeconds + 0.0, false)
        lastWeather = state.weatherToken
    end
    local windToken = ('%.6f:%.6f'):format(state.wind.direction, state.wind.speed)
    if lastWind ~= windToken then
        SetWindDirection(state.wind.direction + 0.0)
        SetWindSpeed(state.wind.speed + 0.0)
        lastWind = windToken
    end
    if lastSnow ~= state.snow then
        Citizen.InvokeNative(0xF02A9C330BBFC5C7, state.snow and 3 or 0)
        lastSnow, ownsSnow = state.snow, true
    end
end

function N.Release()
    -- Only release documented clock ownership and our forced snow mode.
    -- No guessed weather/wind restoration over a newly selected provider.
    if ownsClock then Citizen.InvokeNative(0xD972DF67326F966E) end
    if ownsSnow then Citizen.InvokeNative(0xF02A9C330BBFC5C7, 0) end
    lastWeather, lastWind, lastSnow, ownsClock, ownsSnow = nil, nil, nil, false, false
end
