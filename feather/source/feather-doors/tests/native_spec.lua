-- Run from feather-doors with Lua 5.4: lua54.exe tests/native_spec.lua
dofile('client/native.lua')
local passed = 0
local function check(value, label)
    assert(value, label)
    passed=passed+1
end
local function fixture()
    local data = { [11]={registered=true,state=4,ratio=-0.5}, [22]={registered=false,state=-1,ratio=0} }
    local calls, fail = {}, {}
    local port = {}
    local function get(hash) return assert(data[hash], 'unknown hash') end
    function port.registered(hash)
        if fail.numeric then return get(hash).registered and 1 or 0 end
        return get(hash).registered
    end
    function port.state(hash) return get(hash).state end
    function port.ratio(hash) return get(hash).ratio end
    function port.add(hash)
        calls[#calls+1]='add:'..hash
        get(hash).registered=true; get(hash).state=0
        if fail.add then error('native add failed after registering') end
    end
    function port.remove(hash)
        calls[#calls+1]='remove:'..hash
        if fail.remove then error('native remove failed') end
        if fail.delayed then return end
        get(hash).registered=false
    end
    function port.setState(hash,state)
        calls[#calls+1]='state:'..hash..':'..state
        if fail.state then error('native set failed') end
        if not fail.readback then get(hash).state=state end
    end
    function port.setRatio(hash,ratio) calls[#calls+1]='ratio:'..hash; get(hash).ratio=ratio end
    return FeatherDoorsNative.New(port),data,calls,fail
end
local a,data,calls,fail=fixture()
check(#calls==0,'construction is inert')
check(not a:SetLocked(true),'no mutation before acquire')
for _,bad in ipairs({ {}, {11,11}, {11,22,33}, {0}, {-1}, {1.5}, {4294967296}, {[2]=22}, {11,extra=22} }) do
    check(not a:Acquire(bad),'reject malformed group')
end
check(#calls==0,'invalid input does not invoke mutation natives')
check(a:Acquire({11,22}),'acquire mixed ownership')
check(#calls==1 and calls[1]=='add:22','never re-register existing leaf')
check(not a:Acquire({11}),'refuse overlapping acquisition')
check(not a:SetLocked(1),'require exact boolean')
check(a:SetLocked(true),'lock pair')
check(data[11].state==1 and data[22].state==1,'both leaves locked')
check(data[11].ratio==0 and data[22].ratio==0,'close ratio applied')
local copy=a:Inspect(); copy[1].state=99
check(a:Inspect()[1].state==1,'snapshot is defensive')
check(a:SetLocked(false),'unlock pair')
check(data[11].state==0 and data[22].state==0,'both leaves unlocked')
check(a:Release(),'release mixed ownership')
check(data[11].registered and data[11].state==4 and data[11].ratio==-0.5,'restore existing baseline')
check(not data[22].registered,'remove only new registration')
check(#a:Inspect()==0,'no leases after cleanup')
local count=#calls; check(a:Release() and #calls==count,'repeated cleanup inert')
check(a:Acquire({22}),'re-registration after cleanup')
check(a:Release(),'re-registration cleanup')
a,data,calls,fail=fixture(); fail.add=true
check(not a:Acquire({11,22}),'partial registration reports failure')
check(data[11].state==4 and not data[22].registered and #a:Inspect()==0,'partial acquisition rolls back')
a,data,calls,fail=fixture(); check(a:Acquire({22}),'acquire removal retry fixture'); fail.remove=true
check(not a:Release() and #a:Inspect()==1,'failed cleanup retains lease')
fail.remove=false; check(a:Release() and #a:Inspect()==0,'cleanup retry succeeds')
a,data,calls,fail=fixture(); data[11].state=-1
check(not a:Acquire({11,22}) and #calls==0,'invalid baseline refuses whole group')
a,data,calls,fail=fixture(); check(a:Acquire({11}),'acquire readback fixture'); fail.readback=true
check(not a:SetLocked(true),'state readback mismatch is not success')
fail.readback=false; check(a:Release(),'cleanup readback fixture')
a,data,calls,fail=fixture(); check(a:Acquire({11}),'acquire registration-loss fixture')
data[11].registered=false; count=#calls
check(not a:SetLocked(false) and #calls==count,'lost registration never silently reclaimed')
check(not a:Release() and #a:Inspect()==1,'lost existing registration reports unresolved cleanup')
a,data,calls,fail=fixture(); fail.numeric=true
check(a:Acquire({22}),'numeric zero is unregistered, numeric one registered')
check(calls[1]=='add:22' and a:Inspect()[1].registered==true,'normalize registration readback')
check(a:Release(),'numeric registration cleanup')
check(not data[22].registered,'numeric zero confirms removal')
a,data,calls,fail=fixture(); fail.delayed=true
check(a:Acquire({22}),'acquire deferred-removal fixture')
check(not a:Release() and #a:Inspect()==1,'same-frame removal retains lease pending')
local removalCalls=#calls
check(not a:Release() and #calls==removalCalls,'pending removal is observed without reissuing native')
check(not a:SetLocked(true),'cleanup-pending lease cannot relock')
data[22].registered=false
check(a:Release() and #a:Inspect()==0,'later frame confirms removal')
print(('PASS %d native adapter checks'):format(passed))
