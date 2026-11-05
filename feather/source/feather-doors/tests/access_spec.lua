dofile('server/contract.lua'); dofile('server/access.lua')
dofile('../feather-access/config.lua')
dofile('../feather-access/server/foundation.lua')
Access.Ready=function() return Access.Ok(true) end
GetResourceState=function() return 'started' end
GetGameTimer=function() return 10 end
SetTimeout=function() end
CreateThread=function(fn) fn() end
promise={new=function() return {resolve=function(self,value) self.value=value end} end}
Citizen={Await=function(p) return assert(p.value,'missing mock promise result') end}
dofile('../feather-access/server/providers.lua')
local C=DoorsContract
local passed=0
local function check(ok,label) assert(ok,label); passed=passed+1 end
check(Access.Providers.ValidateConfig().ok,'actual Access config accepts Doors vocabulary')
check(Config.Grants.Readers['feather-doors']==nil and Config.Grants.Managers['feather-doors']==nil,'no new grant reader/manager authority')
local id='11111111-1111-1111-1111-111111111111'
local row={door_id=id,manager_resource='owner',status='active',revision=1,delegation_epoch=1}
local available,ready,malformed,mutateAfter=true,true,false,false
local failRead=false
local function copy(t) local out={};for k,v in pairs(t) do out[k]=v end;return out end
local db={one=function() if failRead then error('database unavailable') end;return row and copy(row) end}
local api
local port={available=function() return available end,call=function(name,request)
    if name=='AwaitReady' then return Access.Ok(true) end
    if name=='GetCapabilities' then return Access.Ok({contract=1}) end
    if name=='RegisterTargetProvider' then
        -- Actual Access supports Cfx reference-shaped callable tables too.
        local resolve=request.resolve
        request.resolve=setmetatable({__cfx_functionReference='test'}, {__call=function(_,spec) return resolve(spec) end})
        return Access.Providers.RegisterTarget(request,'feather-doors')
    end
    if name=='UnregisterTargetProvider' then return Access.Providers.UnregisterTarget(request,'feather-doors') end
    if name=='ResolveTargetContext' then
        local result=Access.Providers.ResolveTarget(request,'feather-doors')
        if mutateAfter then row.revision=row.revision+1; row.delegation_epoch=row.delegation_epoch+1 end
        if malformed then result.value.epoch=99 end
        return result
    end
    error('unknown operation')
end}
api=DoorsAccess.New(db,port,function() return ready end)
check(api:Context('owner',{doorId=id}).code=='provider_unavailable','unregistered fails closed')
check(api:Register().ok and api.registered,'register through actual Access provider implementation')
check(api:Register().code=='already_registered','duplicate registration not silently replaced')
local result=api:Context('owner',{doorId=id})
check(result.ok and result.value.epoch==1 and result.value.status=='active','active target roundtrip')
check(result.value.capabilities[1]=='door.lock' and result.value.capabilities[2]=='door.unlock','exact sorted vocabulary')
failRead=true;check(api:Context('owner',{doorId=id}).code=='provider_unavailable','database failure yields closed envelope');failRead=false
check(api:Context('foreign',{doorId=id}).code=='not_found','context wrapper manager scope')
check(api:Context('owner',{doorId=id,actorSource=1}).code=='invalid_request','no forged actor fields')
check(Access.Providers.ResolveTarget({targetType='doors.group',targetId=id},'foreign').code=='authorization_denied','actual Access context caller denial')
check(Access.Providers.RegisterTarget({targetType='doors.group',contract=1,resolve=function() end},'foreign').code=='authorization_denied','actual Access provider ownership denial')
check(not Access.Providers.Authorize(result.value,{resource='owner',system=true},'grant','door.unlock').ok,'resource manager never implicitly grant manager')
row.revision=2
check(api:Context('owner',{doorId=id}).value.epoch==1,'metadata revision does not stand in for epoch')
row.status='suspended';row.delegation_epoch=2;row.revision=3
check(api:Context('owner',{doorId=id}).value.status=='suspended','suspended target preserved')
row.status='active';row.delegation_epoch=3;row.revision=4
check(api:Context('owner',{doorId=id}).value.epoch==3,'resumption exposes new epoch')
row.status='retired';row.delegation_epoch=4;row.revision=5
check(api:Context('owner',{doorId=id}).value.status=='retired','retired target preserved')
malformed=true
check(api:Context('owner',{doorId=id}).code=='provider_invalid','mismatched Access envelope refused')
malformed=false;mutateAfter=true
check(api:Context('owner',{doorId=id}).code=='target_changed','after-yield target revalidation')
mutateAfter=false;row.delegation_epoch=0
check(not api:Context('owner',{doorId=id}).ok,'invalid stored epoch fails closed')
row.delegation_epoch=4;row.status='unexpected'
check(not api:Context('owner',{doorId=id}).ok,'unknown persisted status fails closed')
row.status='retired';ready=false
check(not api:Context('owner',{doorId=id}).ok,'foundation loss fails closed')
ready=true;available=false;api:Drop()
check(not api.registered and not api:Context('owner',{doorId=id}).ok,'Access stop invalidates local registration')
available=true;Access.Providers.DropOwner('feather-doors')
check(api:Register().ok,'explicit re-registration after Access recovery')
check(api:Unregister().ok and not api.registered,'explicit unregister')
check(not api:Resolve({targetType='doors.group',targetId=id}).ok,'old callback refuses after unregister')
print(('PASS %d Access target provider checks'):format(passed))
