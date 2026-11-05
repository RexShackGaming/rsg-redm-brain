dofile('config.lua')
dofile('shared/contract.lua')
dofile('client/regions.lua')
local W,R,passed=Weather,WeatherRegions,0
local hashes={GrizzliesWest=0x62162401,NewAustin=0x79E6A26B,GaptoothRidge=0x84D7AD0E,
    ChollaSprings=0xF9831C72,RioBravo=0x8016C23F,HennigansStead=0x35390B10,GuarmaD=0xE1736CD7}
local function hash(name) return hashes[name] end
local function policy(change)
    local c=W.Copy(WeatherConfig.regions); c.enabled=true
    if change then change(c) end
    return c
end
local function model(change) return R.New(policy(change),hash) end
local function eq(a,b) assert(a==b,('expected %s; got %s'):format(tostring(b),tostring(a))) end
local function test(name,fn) fn(); passed=passed+1; print('PASS '..name) end
local global={[0]=0,[10]=0}
local snow={[0]=0,[10]=hashes.GrizzliesWest}
local desert={[10]=hashes.GaptoothRidge}
local tropical={[10]=hashes.GuarmaD}
local function settle(r,observation,now) r:Observe(observation,now or 0); r:Observe(observation,(now or 0)+2) end

test('optional missing/disabled region configuration remains valid',function()
    local c=W.Copy(WeatherConfig); c.regions=nil; assert(W.Config(c))
    local called=false
    local disabled=policy(); disabled.enabled=false
    local r=R.New(disabled,function() called=true end)
    r:Sample(1,function() called=true end)
    eq(called,false); eq(r:Context(1).status,'disabled')
    local name,coverage=r:Translate('rain',false); eq(name,'rain'); eq(coverage,false)
end)
test('named presets use catalogue-backed zone hashes',function()
    local r=model(); eq(#r.rules,3)
    eq(r.rules[1].hashes[0x62162401],true)
end)
test('signed/unsigned zone hashes match without overflow guesses',function()
    eq(R.Hash(-221059932),0xF2D2E4A4)
    eq(R.Hash(4294967296),nil); eq(R.Hash(0/0),nil)
end)
test('snow district commits only after stable membership',function()
    local r=model(); r:Observe(snow,0); eq(r:Context(0).id,'global')
    eq(r:Context(0).pending,'grizzlies_snow')
    r:Observe(snow,1); eq(r:Context(1).id,'global')
    r:Observe(snow,2); eq(r:Context(2).id,'grizzlies_snow')
end)
test('default snow policy translates precipitation without forcing ground coverage',function()
    local r=model(); settle(r,snow)
    local name,coverage=r:Translate('rain',false); eq(name,'snow'); eq(coverage,false)
    eq(r:Translate('drizzle',false),'snowlight'); eq(r:Translate('thunderstorm',false),'blizzard')
end)

test('custom automatic coverage remains opt-in and clears on regional exit',function()
    local r=model(function(c) c.rules[1].autoSnow=true end); settle(r,snow)
    local _,coverage=r:Translate('rain',false); eq(coverage,true)
    settle(r,global,3); _,coverage=r:Translate('rain',false); eq(coverage,false)
end)
test('unmapped sunny weather stays sunny without forced snow',function()
    local r=model(); settle(r,snow)
    local name,coverage=r:Translate('sunny',false); eq(name,'sunny'); eq(coverage,false)
end)
test('desert reduces precipitation without changing the global input',function()
    local r=model(); settle(r,desert)
    eq(r:Translate('rain',false),'drizzle'); eq(r:Translate('hurricane',false),'sandstorm')
    eq(r:Translate('thunderstorm',false),'thunderstorm'); eq(r:Translate('thunder',false),'thunder')
    local name,coverage=r:Translate('snow',false); eq(name,'overcast'); eq(coverage,false)
end)
test('Guarma translates snow into tropical precipitation',function()
    local r=model(); settle(r,tropical)
    local name,coverage=r:Translate('snow',false); eq(name,'rain'); eq(coverage,false)
end)
test('explicit global forced coverage is preserved in every region',function()
    local r=model(); settle(r,tropical)
    local _,coverage=r:Translate('snow',true); eq(coverage,true)
end)
test('boundary bounce cancels pending climate switch',function()
    local r=model(); settle(r,snow)
    r:Observe(global,3); r:Observe(snow,4)
    eq(r:Context(4).id,'grizzlies_snow'); eq(r:Context(4).pending,nil)
    eq(r:Translate('rain',false),'snow')
end)
test('returning to ordinary zones clears regional automatic coverage',function()
    local r=model(); settle(r,snow); settle(r,global,3)
    local name,coverage=r:Translate('rain',false); eq(name,'rain'); eq(coverage,false)
    eq(r:Context(5).id,'global')
end)
test('teleport between policies uses a bounded fresh candidate interval',function()
    local r=model(); settle(r,snow); settle(r,desert,10)
    eq(r:Context(12).id,'new_austin_dry'); eq(r:Translate('rain',false),'drizzle')
end)
test('priority wins overlaps; configuration order resolves ties',function()
    local r=model(function(c)
        c.rules[2].zoneType=0; c.rules[2].zones={'NewAustin'}; c.rules[2].priority=100
    end)
    settle(r,{[0]=hashes.NewAustin,[10]=hashes.GrizzliesWest})
    eq(r:Context(2).id,'grizzlies_snow')
    r=model(function(c) c.rules[2].zoneType=0; c.rules[2].zones={'NewAustin'}; c.rules[2].priority=101 end)
    settle(r,{[0]=hashes.NewAustin,[10]=hashes.GrizzliesWest})
    eq(r:Context(2).id,'new_austin_dry')
end)
test('translation is single-pass even when map contains a chain',function()
    local r=model(function(c) c.rules[1].weather.snow='rain' end)
    settle(r,snow)
    eq(r:Translate('rain',false),'snow'); eq(r:Translate('rain',false),'snow')
end)
test('native errors fall back to global and can recover',function()
    local r=model(); settle(r,snow)
    r:Sample(3,function() error('native failed') end)
    eq(r:Context(3).status,'fallback'); eq(r:Translate('rain',false),'rain')
    settle(r,snow,4); eq(r:Context(6).id,'grizzlies_snow'); eq(r:Context(6).error,nil)
end)
test('unknown zero zones are valid shared policy observations',function()
    local r=model(); settle(r,global)
    eq(r:Context(2).id,'global'); eq(r:Context(2).error,nil)
end)
test('district-only observation reproduces live Grizzlies probe and selects snow',function()
    local r=model(); settle(r,{[10]=1645618177})
    eq(r:Context(2).id,'grizzlies_snow'); eq(r:Context(2).observedZones[0],nil)
    eq(r:Translate('rain',false),'snow')
end)
test('state-only observation selects its policy independently',function()
    local r=model(function(c) c.rules[2].zoneType=0; c.rules[2].zones={'NewAustin'} end)
    settle(r,{[0]=hashes.NewAustin})
    eq(r:Context(2).id,'new_austin_dry'); eq(r:Translate('rain',false),'drizzle')
end)
test('live Valentine district stays global while unsigned Tumbleweed selects desert',function()
    local r=model(); settle(r,{[0]=false,[10]=131399519})
    eq(r:Context(2).id,'global'); eq(r:Translate('rain',false),'rain')
    settle(r,{[0]=false,[10]=2228727054},3)
    eq(r:Context(5).id,'new_austin_dry'); eq(r:Translate('rain',false),'drizzle')
end)
test('each catalogued New Austin district can match without a state',function()
    for _,name in ipairs({'GaptoothRidge','ChollaSprings','RioBravo','HennigansStead'}) do
        local r=model(); settle(r,{[10]=hashes[name]})
        eq(r:Context(2).id,'new_austin_dry')
    end
end)
test('false missing zone does not discard another valid type',function()
    local r=model(); settle(r,{[0]=false,[10]=hashes.GrizzliesWest})
    eq(r:Context(2).id,'grizzlies_snow')
end)
test('both absent zone results fail back rather than pretending global membership',function()
    local r=model(); settle(r,snow); r:Observe({},3)
    eq(r:Context(3).status,'fallback'); eq(r:Context(3).error,'zone_probe_unavailable')
    eq(r:Translate('rain',false),'rain')
end)
test('malformed zone is rejected even when the other type is valid',function()
    eq(R.Observation({[0]=0/0,[10]=hashes.GrizzliesWest}),nil)
    eq(R.Observation({[0]='bad',[10]=hashes.GrizzliesWest}),nil)
end)
test('sampling cadence bounds probe work independently of client tick',function()
    local r=model(); local count=0
    for i=0,20 do r:Sample(i*0.25,function() count=count+1; return snow end) end
    eq(count,6)
end)
test('region changes provide a bounded blend window',function()
    local r=model(); settle(r,snow)
    eq(r:TransitionFloor(2),10); eq(r:TransitionFloor(7),5); eq(r:TransitionFloor(20),0)
end)
test('compiled rules and diagnostic reads are detached',function()
    local c=policy(); local r=R.New(c,hash); c.rules[1].weather.rain='fog'
    settle(r,snow); eq(r:Translate('rain',false),'snow')
    local context=r:Context(2); context.observedZones[10]=0
    eq(r:Context(2).observedZones[10],hashes.GrizzliesWest)
end)
for _,case in ipairs({
    {'empty enabled rules',function(c) c.rules={} end},
    {'duplicate IDs',function(c) c.rules[2].id=c.rules[1].id end},
    {'invalid target weather',function(c) c.rules[1].weather.rain='unknown' end},
    {'invalid source weather',function(c) c.rules[1].weather.unknown='rain' end},
    {'unknown policy key',function(c) c.settleMilliseconds=1 end},
    {'invalid native type',function(c) c.rules[1].zoneType=-1 end},
    {'zero sampling interval',function(c) c.sampleIntervalMs=0 end},
    {'nonfinite settle time',function(c) c.settleMs=0/0 end},
    {'oversized rules',function(c) for i=4,17 do c.rules[i]=W.Copy(c.rules[1]); c.rules[i].id='extra_'..i end end},
    {'duplicate zone names',function(c) c.rules[1].zones={'GrizzliesWest','grizzlieswest'} end},
    {'cyclic rule entry',function(c) c.rules[1].weather.rain=c end}
}) do
    test('reject '..case[1],function() local c=policy(case[2]); assert(not W.RegionalPolicy(c)) end)
end
print(('Regional policy checks: %d passed'):format(passed))
