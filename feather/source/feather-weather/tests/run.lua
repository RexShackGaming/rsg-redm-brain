-- Offline Lua 5.4 checks. Execute from the resource root: lua54 tests/run.lua
dofile('config.lua')
dofile('shared/contract.lua')
dofile('server/engine.lua')
dofile('client/overrides.lua')
dofile('client/regions.lua')
local W, passed, failed = Weather, 0, 0
local function test(name, callback)
    local ok, message = pcall(callback)
    if ok then passed = passed + 1 else failed = failed + 1 end
    print(('%s %s%s'):format(ok and 'PASS' or 'FAIL', name, ok and '' or (': ' .. tostring(message))))
end
local function eq(actual, expected) assert(actual == expected, ('expected %s, got %s'):format(tostring(expected), tostring(actual))) end
local function near(actual, expected) assert(math.abs(actual - expected) < 0.00001, ('expected %s, got %s'):format(expected, actual)) end
local function engine(patch)
    local config = W.Copy(WeatherConfig)
    if patch then patch(config) end
    local created = WeatherEngine.New(config, 'test:1', function() return 100 end)
    assert(created.ok, created.message)
    return created.value
end

test('manifest acknowledgement matches approved text and working World when available', function()
    local function line(path)
        local file = assert(io.open(path, 'r'))
        local content = file:read('*a'); file:close()
        return assert(content:match("rdr3_warning [^\r\n]+"))
    end
    eq(line('fxmanifest.lua'), "rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'")
    local sibling = io.open('../feather-world/fxmanifest.lua', 'r')
    if sibling then sibling:close(); eq(line('fxmanifest.lua'), line('../feather-world/fxmanifest.lua')) end
end)
test('valid default configuration and detached initial state', function()
    local e = engine()
    assert(W.Snapshot(e:Snapshot()))
    local state = e:Snapshot(); state.clock.seconds = 0
    eq(e.clock.seconds, 21600)
end)
test('fractional ticks retain clock fractions', function()
    local e = engine(function(c) c.clock.rate = 0.1 end)
    for _ = 1, 100 do e:Advance(0.1, 0) end
    near(e.clock.seconds, 21601)
end)
test('clock normalizes weekly rollover', function()
    local e = engine(function(c) c.clock.seconds = W.WEEK - 1; c.clock.rate = 1 end)
    e:Advance(2, 0); eq(e.clock.seconds, 1)
end)
test('clock freeze leaves weather progression independent', function()
    local e = engine(function(c) c.clock.frozen = true end)
    local nextWeather = e:Forecast().value.entries[1].name
    e:Advance(120, 0)
    eq(e.clock.seconds, 21600); eq(e.weather.name, nextWeather)
end)
test('weather freeze leaves clock progression independent', function()
    local e = engine(function(c) c.weather.frozen = true end)
    e:Advance(120, 0)
    eq(e.weather.name, 'sunny'); eq(e.clock.seconds, 25200)
    eq(e.progress, 0); eq(e:Forecast().value.paused, true)
end)
test('zero rate pauses simulation without invoking wall mode', function()
    local e = engine(function(c) c.clock.rate = 0 end)
    e:Advance(120, 123456)
    eq(e.clock.seconds, 21600); eq(e.progress, 0)
    eq(e:Forecast().value.entries[1].dueRealSeconds, nil)
end)
test('wall mode uses injected UTC with fixed offset and one-times weather', function()
    local e = engine(function(c) c.clock.mode='wall'; c.clock.offsetSeconds=-3600 end)
    e:Advance(10, 3601)
    eq(e.clock.seconds, 1); eq(e.progress, 10)
end)
test('frozen wall mode preserves displayed time', function()
    local e = engine(function(c) c.clock.mode='wall'; c.clock.frozen=true end)
    e:Advance(10, 100)
    eq(e.clock.seconds, 21600); eq(e.progress, 10)
end)
test('forecast entries are the actual consumed schedule', function()
    local e = engine()
    local forecast = e:Forecast().value.entries
    for i = 1, 5 do e:Advance(120, 0); eq(e.weather.name, forecast[i].name) end
end)
test('delayed ticks consume multiple steps and retain overshoot', function()
    local e = engine()
    local forecast = e:Forecast().value.entries
    e:Advance(250, 0)
    eq(e.weather.name, forecast[2].name); eq(e.progress, 300)
    near(e:Forecast().value.entries[1].dueRealSeconds, 110)
    near(e.transitionRemaining, 5)
end)
test('long-stall recovery is bounded and visible', function()
    local e = engine(function(c) c.maxCatchUpSteps = 2 end)
    local before = e.weather.name
    e:Advance(1000, 0)
    eq(e.weather.name, before); eq(e.catchUpResets, 1); eq(e.progress, 0); eq(e.generation, 2)
end)
test('forecast length one can progress repeatedly', function()
    local e = engine(function(c) c.forecastCount = 1 end)
    for _ = 1, 20 do e:Advance(120, 0); eq(#e.queue, 1) end
end)
test('rate changes retime forecast while retaining queued choices and progress', function()
    local e = engine(); e:Advance(10, 0)
    local before = e:Forecast().value
    assert(e:Mutate('clock', { rate=15 }).ok)
    local after = e:Forecast().value
    eq(after.entries[1].name, before.entries[1].name)
    near(after.entries[1].dueRealSeconds, before.entries[1].dueRealSeconds * 2)
end)
test('manual exceptional weather resumes through a valid graph', function()
    local e = engine(); assert(e:Mutate('weather', { name='snow' }).ok)
    e:Advance(120, 0); assert(W.types[e.weather.name])
end)
test('reset restores all defaults immediately', function()
    local e = engine(); e:Mutate('clock', { seconds=0 }); e:Mutate('wind', { speed=20 })
    assert(e:Mutate('reset').ok)
    eq(e.clock.seconds, 21600); eq(e.wind.speed, 0); eq(e.progress, 0)
end)
test('invalid mutation leaves authority revision and state unchanged', function()
    local e = engine(); local before = e:Snapshot()
    assert(not e:Mutate('weather', { name='fake' }).ok)
    eq(e.revision, before.revision); eq(e.weather.name, before.weather.name)
end)
for name, action, spec in (function()
    local values = {
        { 'NaN clock rate', 'clock', { rate=0/0 } },
        { 'infinite clock rate', 'clock', { rate=math.huge } },
        { 'negative clock rate', 'clock', { rate=-1 } },
        { 'unknown patch key', 'clock', { frozne=true } },
        { 'nested/cyclic patch', 'clock', { seconds={} } },
        { 'nonboolean freeze', 'weather', { frozen=1 } },
        { 'negative transition', 'weather', { transitionSeconds=-1 } },
        { 'oversized transition', 'weather', { transitionSeconds=301 } },
        { 'wind direction endpoint', 'wind', { direction=360 } },
        { 'wind speed bound', 'wind', { speed=31 } },
        { 'reset options', 'reset', { clock=true } }
    }
    local i = 0
    return function() i=i+1; if values[i] then return table.unpack(values[i]) end end
end)() do
    test('reject ' .. name, function() assert(not engine():Mutate(action, spec).ok) end)
end
test('closed graph rejects absent destination row', function()
    assert(not W.Pattern({ sunny={ {name='rain', weight=100} } }))
end)
test('graph rejects invalid total and empty rows', function()
    assert(not W.Pattern({ sunny={ {name='sunny', weight=99} } }))
    assert(not W.Pattern({ sunny={} }))
end)
test('graph rejects cyclic/unbounded structures before copying', function()
    local p = {}; p.sunny=p
    assert(not engine():Mutate('pattern', p).ok)
end)
test('graph replacement copies caller data and invalidates schedule', function()
    local e = engine()
    local p = { fog={ {name='fog', weight=100} } }
    assert(e:Mutate('pattern', p).ok)
    p.fog[1].weight = 0
    e:Advance(120, 0); eq(e.weather.name, 'fog')
end)
test('invalid startup config fails without engine', function()
    local c = W.Copy(WeatherConfig); c.forecastCount = 0
    eq(WeatherEngine.New(c, 'x').code, 'invalid_config')
end)
test('bootstrap snapshot validation rejects malformed/nonfinite payloads', function()
    local state = engine():Snapshot(); state.revision = 0/0
    assert(not W.Snapshot(state))
    assert(not W.Snapshot({}))
end)
test('elapsed timer handles unsigned and signed wrap', function()
    eq(W.Elapsed(10, 4294967290), 16)
    eq(W.Elapsed(-2147483640, 2147483640), 16)
end)
test('forecast reads are bounded and detached', function()
    local e = engine()
    assert(not e:Forecast({count=1000}).ok)
    assert(not e:Forecast({unknown=true}).ok)
    local forecast = e:Forecast().value; forecast.entries[1].name='bad'
    assert(e:Forecast().value.entries[1].name ~= 'bad')
end)

local function overrides()
    local c = W.Copy(WeatherConfig)
    c.overrideOwners = { scene={maxPriority=10}, stables={maxPriority=5} }
    return WeatherOverrides.New(c, 'client:1')
end
local function scene(priority, ttl) return {clock=43200, weather={name='sunny', transitionSeconds=0}, snow=false, priority=priority or 1, ttlSeconds=ttl or 30} end
test('unknown client owner is denied', function()
    eq(overrides():Acquire('unknown', scene(), 0).code, 'denied')
end)
test('client owner cannot exceed priority or TTL bounds', function()
    local o = overrides()
    assert(not o:Acquire('scene', scene(11), 0).ok)
    assert(not o:Acquire('scene', scene(1, 3601), 0).ok)
end)
test('override rejects unknown channels and invalid values', function()
    local o = overrides()
    local spec = scene(); spec.syncEnabled=false
    assert(not o:Acquire('scene', spec, 0).ok)
    spec=scene(); spec.clock=math.huge
    assert(not o:Acquire('scene', spec, 0).ok)
end)
test('channel precedence chooses higher priority and oldest tie', function()
    local o = overrides()
    o:Acquire('stables', scene(1), 0)
    local first = o:Acquire('scene', scene(5), 0).value.handle
    o:Acquire('stables', scene(5), 0)
    local winners = o:Resolve(1)
    eq(winners.weather.owner, 'scene'); eq(winners.clock.token, first .. ':1')
    eq(winners.snow.value, false)
end)
test('owner cannot update or release another owner handle', function()
    local o = overrides(); local h = o:Acquire('scene', scene(), 0).value.handle
    eq(o:Update('stables', h, scene(), 1).code, 'denied')
    eq(o:Release('stables', h).code, 'denied')
end)
test('release is idempotent and expires without tombstone growth', function()
    local o = overrides(); local h = o:Acquire('scene', scene(), 0).value.handle
    eq(o:Release('scene', h).value.released, true)
    eq(o:Release('scene', h).value.released, false)
    o:Acquire('scene', scene(1, 1), 0)
    local winners, count = o:Resolve(1); eq(count, 0); eq(next(winners), nil)
end)
test('update renews TTL atomically and retains handle ordering', function()
    local o = overrides(); local h = o:Acquire('scene', scene(), 0).value.handle
    assert(o:Update('scene', h, scene(2, 30), 20).ok)
    local winners, count = o:Resolve(40)
    eq(count, 1); eq(winners.clock.token, h .. ':2')
    assert(not o:Update('scene', h, scene(), 50).ok)
end)
test('unchanged scene renewal extends TTL without restarting presentation', function()
    local o = overrides(); local h = o:Acquire('scene', scene(1, 30), 0).value.handle
    local before = o:Resolve(1).weather.token
    assert(o:Update('scene', h, scene(1, 60), 20).ok)
    eq(o:Resolve(40).weather.token, before)
    local changed = scene(1, 60); changed.weather.name = 'rain'
    assert(o:Update('scene', h, changed, 50).ok)
    assert(o:Resolve(51).weather.token ~= before)
end)
test('owner stop releases only that owner channels', function()
    local o = overrides(); o:Acquire('scene', scene(), 0); o:Acquire('stables', scene(), 0)
    o:ReleaseOwner('scene')
    local winners, count = o:Resolve(1)
    eq(count, 1); eq(winners.clock.owner, 'stables')
end)
test('override capacity is bounded and expiry recovers slots', function()
    local o = overrides()
    for _ = 1, 16 do assert(o:Acquire('scene', scene(1, 1), 0).ok) end
    eq(o:Acquire('scene', scene(), 0).code, 'limit')
    assert(o:Acquire('scene', scene(), 2).ok)
end)

-- Cfx boundary harness: actual server entry point, mocked runtime only.
local registered, events, commands, threads, sent = {}, {}, {}, {}, {}
local timer, owner, conflict, permission = 0, nil, false, false
function GetCurrentResourceName() return 'feather-weather' end
function GetGameTimer() return timer end
function GetResourceState() return conflict and 'started' or 'missing' end
function GetResourceMetadata() return '0.1.0' end
function GetInvokingResource() return owner end
function GetPlayerName(id) return id == 12 and 'test' or nil end
function IsPlayerAceAllowed() return permission end
function exports(name, callback) registered[name] = callback end
function RegisterNetEvent(name, callback) events[name] = callback end
function AddEventHandler(name, callback) events[name] = callback end
function RegisterCommand(name, callback) commands[name] = callback end
function CreateThread(callback) threads[#threads+1] = callback end
function TriggerClientEvent(...) sent[#sent+1] = {...} end
function TriggerEvent() end
json = { encode=function() return '{}' end }
dofile('server/main.lua')
test('server exposes no inbound network mutation handlers', function()
    eq(events['feather-weather:setWeather'], nil)
    eq(events['weathersync:setWeather'], nil)
    assert(events['feather-weather:bootstrap'])
end)
test('untrusted server mutation denied and trusted caller admitted', function()
    owner='other'; eq(registered.SetWeather({name='rain'}).code, 'denied')
    WeatherConfig.trustedResources.test=true; owner='test'
    assert(registered.SetWeather({name='rain'}).ok)
    eq(registered.GetState().value.weather.name, 'rain')
end)
test('conflicting provider blocks reads and writes', function()
    conflict=true
    eq(registered.GetState().code, 'unavailable')
    eq(registered.SetClock({seconds=0}).code, 'unavailable')
    assert(registered.GetCapabilities().value.state:match('conflict:'))
    conflict=false
end)
test('bootstrap rejects malformed IDs and throttles requests', function()
    source=12; timer=2000
    local before=#sent
    events['feather-weather:bootstrap']({})
    eq(#sent, before)
    events['feather-weather:bootstrap'](1); eq(#sent, before)
    timer=3000; events['feather-weather:bootstrap'](2)
    eq(#sent, before+1); eq(sent[#sent][1], 'feather-weather:bootstrapReply'); eq(sent[#sent][3], 2)
end)
test('unpermissioned command cannot mutate authority', function()
    permission=false; local before=registered.GetState().value.weather.name
    commands.fwweather(12, {'snow'})
    eq(registered.GetState().value.weather.name, before)
end)
test('console command mutation uses validated setters', function()
    commands.fwclock(0, {'bad', '1'})
    assert(registered.GetState().value.clock.seconds ~= 60)
    commands.fwclock(0, {'12', '30'})
    eq(registered.GetState().value.clock.seconds, 45000)
end)

-- Actual client entry point with a deterministic coroutine scheduler and native recorder.
-- These baseline cases isolate global presentation; regional cases enable it below.
assert(WeatherConfig.regions.enabled==true, 'Shipped regional default must be enabled')
WeatherConfig.regions.enabled=false
registered, events, threads = {}, {}, {}
timer, owner, conflict = 0, nil, false
local outgoing, applications, releases = {}, {}, 0
WeatherConfig.overrideOwners.scene = {maxPriority=10}
WeatherConfig.overrideOwners.stables = {maxPriority=5}
function NetworkIsSessionStarted() return true end
function TriggerServerEvent(...) outgoing[#outgoing+1] = {...} end
function Wait() coroutine.yield() end
WeatherNative = {
    Apply=function(state) applications[#applications+1] = W.Copy(state) end,
    Release=function() releases=releases+1 end
}
dofile('client/main.lua')
local clientThread = coroutine.create(threads[1])
local function clientTick(ms)
    timer = timer + (ms or 250)
    local resumed, message = coroutine.resume(clientThread)
    assert(resumed, message)
end
local clientAuthority = engine()
local function reply()
    source=65535
    local requestId = outgoing[#outgoing][2]
    events['feather-weather:bootstrapReply'](requestId, clientAuthority:Snapshot())
end
test('client waits for matched server bootstrap before native ownership', function()
    clientTick()
    eq(#applications, 0)
    source=65535
    events['feather-weather:bootstrapReply'](999, clientAuthority:Snapshot())
    clientTick(); eq(#applications, 0)
    reply(); clientTick()
    eq(#applications, 1); assert(registered.GetLocalState().ok)
    eq(registered.GetLocalState().value.lastError, nil)
end)
test('client rejects spoofed local and stale server snapshots', function()
    local state = clientAuthority:Snapshot(); state.revision=100; state.weather.name='snow'
    source=0; events['feather-weather:snapshot'](state); clientTick()
    eq(applications[#applications].weather.name, 'sunny')
    source=65535; events['feather-weather:snapshot'](state); clientTick()
    eq(applications[#applications].weather.name, 'snow')
    events['feather-weather:snapshot'](clientAuthority:Snapshot()); clientTick()
    eq(applications[#applications].weather.name, 'snow')
end)
local sceneHandle
test('scene override affects local channels while global updates continue', function()
    owner='scene'
    sceneHandle = registered.AcquireOverride(scene(10, 30)).value.handle
    clientTick(); eq(applications[#applications].weather.name, 'sunny')
    local state=clientAuthority:Snapshot(); state.revision=101; state.weather.name='rain'; state.weather.snow=true
    source=65535; events['feather-weather:snapshot'](state); clientTick()
    eq(applications[#applications].weather.name, 'sunny')
    eq(applications[#applications].snow, false)
end)
test('final release applies newest authority including snow and wind', function()
    owner='scene'; assert(registered.ReleaseOverride(sceneHandle).ok)
    clientTick(); eq(applications[#applications].weather.name, 'rain')
    eq(applications[#applications].snow, true)
end)
test('client owner stop restores global state on next application tick', function()
    owner='scene'; assert(registered.AcquireOverride(scene()).ok)
    clientTick(); eq(applications[#applications].weather.name, 'sunny')
    events.onClientResourceStop('scene'); clientTick()
    eq(applications[#applications].weather.name, 'rain')
end)
test('client expiry restores authority without consumer callback', function()
    owner='scene'; assert(registered.AcquireOverride(scene(10, 1)).ok)
    clientTick(); eq(applications[#applications].weather.name, 'sunny')
    clientTick(1001); eq(applications[#applications].weather.name, 'rain')
end)
test('client clock projection advances from receipt without comparing host timers', function()
    local before=applications[#applications].clock
    clientTick(1000)
    near(applications[#applications].clock - before, 30)
end)
test('client marks stale authority degraded and retries bootstrap', function()
    local before=#outgoing
    clientTick(30000)
    assert(#outgoing > before)
    eq(registered.GetLocalState().code, 'unavailable')
    reply(); clientTick()
    -- Old-epoch same revision reply must not roll back newer cached state.
    eq(applications[#applications].weather.name, 'rain')
end)
test('client conflict stops native applications and releases even degraded state', function()
    conflict=true; local before=#applications
    clientTick()
    eq(#applications, before); eq(releases, 1)
    assert(not registered.AcquireOverride(scene()).ok)
    conflict=false
end)
test('new server epoch requires matched fresh bootstrap', function()
    clientAuthority=engine(); clientAuthority.epoch='test:2'
    source=65535; events['feather-weather:snapshot'](clientAuthority:Snapshot())
    clientTick(); local before=#applications
    eq(registered.GetLocalState().code, 'unavailable')
    reply(); clientTick()
    eq(#applications, before+1); eq(registered.GetLocalState().value.epoch, 'test:2')
end)

-- Enabled-region actual-client integration with injected native observations.
do
    registered,events,threads={},{},{}
    timer,owner,conflict=0,nil,false
    outgoing,applications={},{}
    WeatherConfig.regions.enabled=true
    local zoneHashes={GrizzliesWest=0x62162401,GaptoothRidge=0x84D7AD0E,
        ChollaSprings=0xF9831C72,RioBravo=0x8016C23F,HennigansStead=0x35390B10,GuarmaD=0xE1736CD7}
    local stateHash,districtHash,probeCalls=0,0,0
    function GetHashKey(name) return zoneHashes[name] end
    function PlayerPedId() return 42 end
    function GetEntityCoords() return {x=0,y=0,z=100} end
    Citizen={InvokeNative=function(native,_,_,_,zoneType)
        assert(native==0x43AD8FC02B429D33)
        probeCalls=probeCalls+1
        return zoneType==0 and stateHash or districtHash
    end}
    WeatherNative={Apply=function(state) applications[#applications+1]=W.Copy(state) end,Release=function() end}
    dofile('client/main.lua')
    clientThread=coroutine.create(threads[1])
    clientAuthority=engine()
    assert(clientAuthority:Mutate('weather',{name='rain',transitionSeconds=0,frozen=true,snow=false}).ok)
    clientTick(); reply(); clientTick()
    test('enabled region client starts with global weather in ordinary zones',function()
        eq(applications[#applications].weather.name,'rain')
        eq(applications[#applications].region.id,'global')
    end)
    test('movement translates rain without a new global event or server mutation',function()
        local before=clientAuthority:Snapshot()
        districtHash=zoneHashes.GrizzliesWest
        for _=1,3 do clientTick(1000) end
        local applied=applications[#applications]
        eq(applied.weather.name,'snow'); eq(applied.snow,false)
        eq(applied.authoritativeWeather,'rain'); eq(clientAuthority.weather.name,'rain')
        eq(clientAuthority.revision,before.revision)
        eq(applied.weather.transitionSeconds,10)
    end)
    test('unchanged regional weather retains its transition identity',function()
        local token=applications[#applications].weatherToken
        clientTick(1000); eq(applications[#applications].weatherToken,token)
    end)
    test('Character-style explicit channels bypass climate and suppress regional snow',function()
        owner='scene'; sceneHandle=registered.AcquireOverride(scene(10,30)).value.handle
        clientTick(); eq(applications[#applications].weather.name,'sunny'); eq(applications[#applications].snow,false)
        eq(applications[#applications].clock,43200)
    end)
    test('region sampling continues under scenes and release uses latest location',function()
        districtHash=0
        for _=1,3 do clientTick(1000) end
        eq(applications[#applications].region.id,'global')
        eq(applications[#applications].weather.name,'sunny')
        assert(registered.ReleaseOverride(sceneHandle).ok); clientTick()
        eq(applications[#applications].weather.name,'rain'); eq(applications[#applications].snow,false)
    end)
    test('desert translation preserves global forced coverage as separate authority',function()
        stateHash=0; districtHash=zoneHashes.GaptoothRidge
        assert(clientAuthority:Mutate('weather',{name='snow',snow=true}).ok)
        source=65535; events['feather-weather:snapshot'](clientAuthority:Snapshot())
        for _=1,3 do clientTick(1000) end
        eq(applications[#applications].weather.name,'overcast'); eq(applications[#applications].snow,true)
    end)
    test('client loop bounds zone native calls to two per sample',function()
        local before=probeCalls
        for _=1,20 do clientTick(250) end
        eq(probeCalls-before,10)
    end)
    test('explicit region probe only reads zones and does not advance regional state',function()
        local before=probeCalls
        local current=registered.GetLocalState().value.effective.region.revision
        commands.fwregion(0,{'probe'})
        eq(probeCalls-before,2)
        eq(registered.GetLocalState().value.effective.region.revision,current)
    end)
    test('actual client accepts district-only region sample from live report',function()
        stateHash=nil; districtHash=zoneHashes.GrizzliesWest
        -- The fake native must preserve nil for STATE instead of using Lua's and/or fallback.
        Citizen.InvokeNative=function(_,_,_,_,kind)
            if kind==0 then return nil end
            return districtHash
        end
        for _=1,3 do clientTick(1000) end
        eq(applications[#applications].region.id,'grizzlies_snow')
        commands.fwregion(0,{'probe'})
    end)
end

-- Native calls are inspected for dispatch/cadence only; this is not visual acceptance.
local nativeCalls = {}
Citizen = { InvokeNative=function(hash, ...) nativeCalls[#nativeCalls+1]={hash, ...} end }
function GetHashKey(name) return name end
function SetWindDirection(value) nativeCalls[#nativeCalls+1]={'direction',value} end
function SetWindSpeed(value) nativeCalls[#nativeCalls+1]={'speed',value} end
dofile('client/native.lua')
test('native adapter does not restart unchanged weather transitions', function()
    local state={clock=43200, weather={name='sunny',transitionSeconds=10}, weatherToken='test:1',wind={direction=0,speed=0},snow=false}
    WeatherNative.Apply(state); WeatherNative.Apply(state)
    local weatherCalls=0
    for _, call in ipairs(nativeCalls) do if call[1] == 0x59174F1AFE095B5A then weatherCalls=weatherCalls+1 end end
    eq(weatherCalls, 1)
end)
test('native release clears owned clock and resets forced snow without claiming full restoration', function()
    local before=#nativeCalls
    WeatherNative.Release()
    eq(#nativeCalls, before+2)
    eq(nativeCalls[before+1][1], 0xD972DF67326F966E)
    eq(nativeCalls[before+2][1], 0xF02A9C330BBFC5C7)
end)

print(('Weather checks: %d passed, %d failed'):format(passed, failed))
if failed > 0 then os.exit(1) end
