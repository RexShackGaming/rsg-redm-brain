local W, resource = Weather, GetCurrentResourceName()
local valid = W.Config(WeatherConfig)
local overrides = valid and WeatherOverrides.New(WeatherConfig, ('local:%s'):format(GetGameTimer())) or nil
local regions = valid and WeatherRegions.New(WeatherConfig.regions, GetHashKey) or nil
local snapshot, receivedAt, latency, effective, pending
local sequence, nextRequest, nowSeconds, previousTimer = 0, 0, 0, GetGameTimer()
local status, lastError, lastPrinted = 'waiting', nil, nil
local ProbeZones

local function Now()
    local timer = GetGameTimer()
    nowSeconds = nowSeconds + W.Elapsed(timer, previousTimer) / 1000
    previousTimer = timer
    return nowSeconds
end
local function Conflict()
    for _, name in ipairs(WeatherConfig.conflictResources) do
        local state = GetResourceState(name)
        if state == 'started' or state == 'starting' then return name end
    end
end
local function Request(now)
    if pending and now - pending.sentAt < 10 then return end
    sequence = sequence % 2147483647 + 1
    pending = { id=sequence, sentAt=now }
    TriggerServerEvent('feather-weather:bootstrap', sequence)
    nextRequest = now + 10
end
local function Accept(value, now, halfRtt)
    if not W.Snapshot(value) then return false end
    if snapshot and snapshot.epoch == value.epoch and snapshot.revision >= value.revision then return false end
    snapshot, receivedAt, latency = W.Copy(value), now, math.min(halfRtt or latency or 0, 1)
    return true
end
RegisterNetEvent('feather-weather:bootstrapReply', function(requestId, value)
    if source ~= 65535 or not valid or not pending or pending.id ~= requestId then return end
    local now = Now()
    local halfRtt = (now - pending.sentAt) / 2
    if halfRtt > 5 or not W.Snapshot(value) then return end
    Accept(value, now, halfRtt)
    pending = nil
end)
RegisterNetEvent('feather-weather:snapshot', function(value)
    if source ~= 65535 or not valid or not W.Snapshot(value) then return end
    local now = Now()
    if not snapshot or snapshot.epoch ~= value.epoch then
        Request(now) -- A new server epoch must be established through matched bootstrap.
        return
    end
    Accept(value, now)
end)
RegisterNetEvent('feather-weather:operatorResult', function(result)
    if source == 65535 then print('[feather-weather] ' .. json.encode(result)) end
end)

local function Available()
    if not valid then return W.Err('invalid_config', 'Invalid Weather configuration.') end
    if status ~= 'ready' then return W.Err('unavailable', 'Weather client is ' .. status) end
end
exports('GetLocalState', function()
    local unavailable = Available()
    if unavailable then return unavailable end
    return W.Ok(W.Copy({ epoch=snapshot.epoch, revision=snapshot.revision, state=status,
        effective=effective, snapshotAgeSeconds=Now() - receivedAt, lastError=lastError,
        evidence='application_attempt_only' }))
end)
RegisterCommand('fwregion', function(_,args)
    if not regions then print('[feather-weather] regional policy unavailable'); return end
    if args and args[1] == 'probe' and #args == 1 then
        -- Explicit read-only experiment, usable while policy is disabled.
        local ok, zones=pcall(ProbeZones)
        local observed,problem=WeatherRegions.Observation(ok and zones or nil)
        print('[feather-weather] ' .. json.encode({ok=observed ~= nil,action='region_probe',
            state=observed and observed[0],district=observed and observed[10],
            stateType=ok and type(zones)=='table' and type(zones[0]) or nil,
            districtType=ok and type(zones)=='table' and type(zones[10]) or nil,
            missing=observed and {state=observed[0]==nil,district=observed[10]==nil},
            evidence='zone_observation_only', error=not observed and (ok and problem or tostring(zones)) or nil}))
        return
    end
    if args and #args > 0 then print('[feather-weather] Usage: fwregion [probe] in client F8.'); return end
    print('[feather-weather] ' .. json.encode({region=regions:Context(Now()),
        authoritativeWeather=snapshot and snapshot.weather.name,
        effectiveWeather=effective and effective.weather.name,
        effectiveSnow=effective and effective.snow, evidence='application_attempt_only'}))
end, false)
exports('AcquireOverride', function(spec)
    local unavailable = Available()
    if unavailable then return unavailable end
    local owner = GetInvokingResource()
    if not owner then return W.Err('denied', 'An invoking client resource is required.') end
    return overrides:Acquire(owner, spec, Now())
end)
exports('UpdateOverride', function(handle, spec)
    local unavailable = Available()
    if unavailable then return unavailable end
    return overrides:Update(GetInvokingResource(), handle, spec, Now())
end)
exports('ReleaseOverride', function(handle)
    if not overrides then return W.Err('unavailable', 'Overrides are not initialized.') end
    return overrides:Release(GetInvokingResource(), handle)
end)
AddEventHandler('onClientResourceStop', function(name)
    if overrides then overrides:ReleaseOwner(name) end
    if name == resource then WeatherNative.Release() end
end)

local function Project(now)
    local winners, count = overrides:Resolve(now)
    local age = now - receivedAt + latency
    local clock = snapshot.clock.seconds
    if not snapshot.clock.frozen then clock = (clock + age * W.Rate(snapshot.clock)) % W.WEEK end
    local transition = math.max(0, snapshot.transitionRemainingSeconds - age)
    local regionalName, regionalSnow = regions:Translate(snapshot.weather.name,snapshot.weather.snow)
    -- Crossing a climate boundary blends even when global weather has not changed.
    transition = math.max(transition,regions:TransitionFloor(now))
    local wind=snapshot.wind
    if snapshot.windMotion then
        wind=W.ProjectWind(wind,snapshot.windMotion.target,age,snapshot.windMotion.degreesPerSecond,snapshot.windMotion.speedPerSecond)
    end
    return { clock=winners.clock and winners.clock.value or clock,
        weather=winners.weather and winners.weather.value or { name=regionalName, transitionSeconds=transition },
        weatherToken=winners.weather and winners.weather.token
            or (snapshot.epoch .. ':' .. snapshot.transitionId .. ':' .. regionalName),
        wind=winners.wind and winners.wind.value or wind,
        snow=winners.snow and winners.snow.value or (not winners.snow and regionalSnow or false),
        channels=winners, overrideCount=count, region=regions:Context(now), authoritativeWeather=snapshot.weather.name }
end

ProbeZones = function()
    local ped=PlayerPedId()
    if ped == 0 then return nil end
    local coords=GetEntityCoords(ped)
    if not coords or not W.Number(coords.x,-100000,100000)
        or not W.Number(coords.y,-100000,100000) or not W.Number(coords.z,-100000,100000) then return nil end
    -- _GET_MAP_ZONE_AT_COORDS: STATE=0, DISTRICT=10. No temperature feedback.
    return {[0]=Citizen.InvokeNative(0x43AD8FC02B429D33,coords.x,coords.y,coords.z,0),
        [10]=Citizen.InvokeNative(0x43AD8FC02B429D33,coords.x,coords.y,coords.z,10)}
end

CreateThread(function()
    if not valid then
        status = 'invalid_config'
        print('[feather-weather] client configuration invalid; no native ownership acquired.')
        return
    end
    while true do
        local now, conflict = Now(), Conflict()
        if conflict then
            if snapshot or effective then WeatherNative.Release() end
            status, snapshot, effective = 'conflict:' .. conflict, nil, nil
        elseif not NetworkIsSessionStarted() then
            status = 'waiting_session'
        else
            local stale = snapshot and now - receivedAt > WeatherConfig.syncIntervalMs / 1000 * 3 + 10
            if (not snapshot or stale) and now >= nextRequest then Request(now) end
            if snapshot then
                regions:Sample(now,ProbeZones)
                effective = Project(now)
                local applied, message = pcall(WeatherNative.Apply, effective)
                status = applied and (stale and 'degraded' or 'ready') or 'native_error'
                lastError = nil
                if not applied then lastError = tostring(message) end
            else
                status = 'waiting_snapshot'
            end
        end
        if status ~= lastPrinted then
            print(('[feather-weather] client %s%s'):format(status, lastError and (': ' .. lastError) or ''))
            lastPrinted = status
        end
        Wait(WeatherConfig.clientIntervalMs)
    end
end)
