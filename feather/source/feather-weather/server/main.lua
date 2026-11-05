local W, resource = Weather, GetCurrentResourceName()
local created = WeatherEngine.New(WeatherConfig, ('%s:%s:%s'):format(resource, os.time(), GetGameTimer()))
local engine = created.ok and created.value or nil
local lastTick, lastSync = GetGameTimer(), GetGameTimer()
local requests, rejected = {}, 0
local status = engine and 'starting' or 'invalid_config'
if not engine then print(('[feather-weather] %s'):format(created.message)) end

local function Ready()
    if not engine then return false end
    for _, name in ipairs(WeatherConfig.conflictResources) do
        local state = GetResourceState(name)
        if state == 'started' or state == 'starting' then
            status = 'conflict:' .. name
            return false
        end
    end
    status = 'ready'
    return true
end

local function WallSeconds()
    local utc = os.date('!*t')
    return (utc.wday - 1) * 86400 + utc.hour * 3600 + utc.min * 60 + utc.sec
end

local function Advance()
    local now = GetGameTimer()
    local elapsed = W.Elapsed(now, lastTick) / 1000
    lastTick = now
    return engine:Advance(elapsed, WallSeconds())
end

local function Broadcast()
    TriggerClientEvent('feather-weather:snapshot', -1, engine:Snapshot())
    lastSync = GetGameTimer()
end

local function Unavailable() return W.Err('unavailable', 'Weather authority is not ready: ' .. status) end
local function ReadState()
    if not Ready() then return Unavailable() end
    Advance()
    return W.Ok(engine:Snapshot())
end
local function Capabilities()
    Ready()
    return W.Ok({ resource=resource, version=GetResourceMetadata(resource, 'version', 0), contract=W.CONTRACT,
        state=status, restartPolicy='reset_to_config', rejectedRequests=rejected,
        features={ clock=1, weather=1, forecast=1, baseWind=1, snowCoverage=1, localOverrides=1,
            regions=1, automaticWind=1, seasons=1, persistence=false },
        regionPolicy={enabled=engine ~= nil and engine.config.regions ~= nil and engine.config.regions.enabled or false,
            ruleCount=engine and engine.config.regions and #engine.config.regions.rules or 0},
        limits={ maxForecast=engine and engine.config.forecastCount or 0, maxRate=120, maxTransitionSeconds=300 } })
end

local function Mutate(action, spec, console)
    local owner = GetInvokingResource()
    if not console and (not owner or WeatherConfig.trustedResources[owner] ~= true) then
        rejected = math.min(2147483647, rejected + 1)
        return W.Err('denied', 'Invoking server resource is not allowed to mutate Weather.')
    end
    if not Ready() then return Unavailable() end
    Advance()
    local result = engine:Mutate(action, spec)
    if result.ok then
        -- Apply wall mode/offset immediately, including reset-to-config.
        engine:Advance(0, WallSeconds())
        result = W.Ok(engine:Snapshot())
        Broadcast()
        TriggerEvent('feather-weather:changed', { action=action, owner=owner or 'operator', state=engine:Snapshot() })
    end
    return result
end

exports('GetCapabilities', Capabilities)
exports('GetState', ReadState)
exports('GetForecast', function(options)
    if not Ready() then return Unavailable() end
    Advance()
    return engine:Forecast(options)
end)
for name, action in pairs({ SetClock='clock', SetWeather='weather', SetWind='wind', SetWindControl='windControl', SetSeason='season', SetPattern='pattern', ResetEnvironment='reset' }) do
    local operation = action
    exports(name, function(spec) return Mutate(operation, spec, false) end)
end

-- The only inbound network request is read-only bootstrap. No network setters.
RegisterNetEvent('feather-weather:bootstrap', function(requestId)
    local player = source
    if not W.Number(player, 1, 2147483647, true) or not GetPlayerName(player) then return end
    local now, last = GetGameTimer(), requests[player]
    if last and W.Elapsed(now, last) < 1000 then
        rejected = math.min(2147483647, rejected + 1)
        return
    end
    requests[player] = now
    if not W.Number(requestId, 1, 2147483647, true) or not Ready() then return end
    Advance()
    TriggerClientEvent('feather-weather:bootstrapReply', player, requestId, engine:Snapshot())
end)
AddEventHandler('playerDropped', function() requests[source] = nil end)

local function Output(player, result)
    -- Console output avoids a hard Chat dependency. In-game operators see their F8 log.
    if player == 0 then print('[feather-weather] ' .. json.encode(result))
    else TriggerClientEvent('feather-weather:operatorResult', player, result) end
end
local function Command(name, callback)
    RegisterCommand(name, function(player, args)
        if player ~= 0 and not IsPlayerAceAllowed(player, 'command.' .. name) then
            Output(player, W.Err('denied', 'Command permission required.'))
            return
        end
        Output(player, callback(args))
    end, true)
end
Command('fwstate', function() return Capabilities() end)
Command('fwforecast', function()
    if not Ready() then return Unavailable() end
    Advance()
    return engine:Forecast()
end)
Command('fwweather', function(args)
    if #args ~= 1 then return W.Err('invalid_input', 'Usage: fwweather <weather-name>; sets manual frozen weather.') end
    return Mutate('weather', { name=args[1], frozen=true }, true)
end)
Command('fwclock', function(args)
    if #args ~= 2 then return W.Err('invalid_input', 'Usage: fwclock <hour 0-23> <minute 0-59>; sets frozen simulated time.') end
    local hour, minute = tonumber(args[1]), tonumber(args[2])
    if not W.Number(hour, 0, 23, true) or not W.Number(minute, 0, 59, true) then return W.Err('invalid_input', 'Invalid hour/minute.') end
    return Mutate('clock', { mode='simulated', seconds=hour * 3600 + minute * 60, frozen=true }, true)
end)
Command('fwwind', function(args)
    local direction, speed = tonumber(args[1]), tonumber(args[2])
    if #args ~= 2 or not direction or not speed then return W.Err('invalid_input', 'Usage: fwwind <degrees 0..<360> <speed 0-30>.') end
    return Mutate('wind', { direction=direction, speed=speed }, true)
end)
Command('fwreset', function(args)
    if #args ~= 0 then return W.Err('invalid_input', 'Usage: fwreset; resets all domains to configuration.') end
    return Mutate('reset', nil, true)
end)
Command('fwseason', function(args)
    if #args<1 or #args>2 then return W.Err('invalid_input','Usage: fwseason <spring|summer|autumn|winter> [day].') end
    local day=tonumber(args[2] or '1')
    if not day then return W.Err('invalid_input','Invalid season day.') end
    return Mutate('season',{name=args[1],day=day,enabled=true},true)
end)
Command('fwwindauto', function(args)
    if #args~=1 or (args[1]~='on' and args[1]~='off') then return W.Err('invalid_input','Usage: fwwindauto <on|off>.') end
    return Mutate('windControl',{automatic=args[1]=='on',frozen=false},true)
end)

CreateThread(function()
    if not engine then return end
    local previous
    while true do
        local ready = Ready()
        if status ~= previous then
            print(('[feather-weather] authority %s'):format(status))
            previous = status
        end
        if ready then
            local changed = Advance()
            if changed or W.Elapsed(GetGameTimer(), lastSync) >= WeatherConfig.syncIntervalMs then Broadcast() end
        else
            -- Do not catch up time accumulated while another provider has authority.
            lastTick = GetGameTimer()
        end
        Wait(WeatherConfig.tickIntervalMs)
    end
end)
