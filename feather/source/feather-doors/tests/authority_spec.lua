dofile('server/contract.lua');dofile('server/authority.lua')
local C=DoorsContract
local passed=0
local function check(ok,label) assert(ok,label);passed=passed+1 end
local function copy(t) local o={};for k,v in pairs(t) do o[k]=v end;return o end
local id='11111111-1111-1111-1111-111111111111'
local account='22222222-2222-2222-2222-222222222222'
local character='33333333-3333-3333-3333-333333333333'
local sessionId='44444444-4444-4444-4444-444444444444'
local propertyId='55555555-5555-5555-5555-555555555555'
local row,actor,owner,staff,ready,hook,reads,sessionReads,api,policyCalls
local function reset()
 row={door_id=id,manager_resource='manager',revision=2,delegation_epoch=2,status='active',authority_mode='property',
 binding_property_id=propertyId,binding_link_id=id,binding_property_epoch=1}
 actor={accountId=account,characterId=character,sessionId=sessionId,generation=1}
 owner=true;staff=false;ready=true;hook=nil;reads=0;sessionReads=0;policyCalls=0
 api=DoorsAuthority.New({Read=function() reads=reads+1;if hook then hook('read',reads) end;return copy(row) end},{
 session=function() sessionReads=sessionReads+1;if hook then hook('session',sessionReads) end;return C.Ok(copy(actor)) end,
 interest=function(r) check(r.propertyId==propertyId and r.holderId==character and r.interestType=='owner','canonical actor owner selector');
 if hook then hook('interest') end;return C.Ok({propertyId=propertyId,matched=owner,propertyStatus='active'}) end,
 policy=function(action,r) policyCalls=policyCalls+1;check(action=='doors.grant.manage' and r.source==5 and r.subject.doorId==id,'exact staff policy');
 if hook then hook('policy') end;return C.Ok({allowed=staff}) end},function() return ready end)
end
local function request(extra) local r={doorId=id,actorSource=5,operation='grant',capability='door.unlock',path='property'};for k,v in pairs(extra or {}) do r[k]=v end;return r end
reset();local result=api:Check('manager',request());check(result.ok and result.value.allowed and result.value.advisory and result.value.epoch==2,'owner advisory allow')
reset();owner=false;check(not api:Check('manager',request()).value.allowed,'tenant nonowner denied')
reset();row.authority_mode='standalone';check(not api:Check('manager',request()).value.allowed,'standalone has no Property authority')
reset();check(api:Check('foreign',request()).code=='not_found','manager scope enforced')
for _,status in ipairs({'suspended','retired'}) do reset();row.status=status;check(not api:Check('manager',request()).value.allowed,'inactive denies') end
reset();row.effective_status='unavailable';check(not api:Check('manager',request()).value.allowed,'source unavailable denies')
reset();check(not api:Check('manager',request({path='staff'})).value.allowed,'unconfigured staff denied')
reset();staff=true;row.authority_mode='standalone';check(api:Check('manager',request({path='staff'})).value.allowed,'explicit staff standalone allow')
for _,op in ipairs({'list','revoke'}) do reset();local r=request({operation=op});if op=='list' then r.capability=nil end;check(api:Check('manager',r).value.allowed,'owner operation '..op) end
for _,extra in ipairs({{actorSource=0},{actorSource=1.5},{actorId=character},{staff=true},{owner=true},{path='system'},{operation='use'},{capability='door.open'}}) do
 reset();check(api:Check('manager',request(extra)).code=='invalid_request','forged unsupported request rejected')
end
reset();local r=request({operation='list'});check(api:Check('manager',r).code=='invalid_request','list rejects capability')
reset();ready=false;check(api:Check('manager',request()).code=='unavailable','not ready')
for _,field in ipairs({'accountId','characterId','sessionId','generation'}) do reset();actor[field]=nil;check(api:Check('manager',request()).code=='actor_unavailable','malformed actor '..field) end
for _,field in ipairs({'revision','delegation_epoch','binding_property_epoch','binding_link_id','manager_resource'}) do
 reset();hook=function(stage) if stage=='interest' then row[field]=field=='binding_link_id' and propertyId or field=='manager_resource' and 'foreign' or 3 end end
 check(api:Check('manager',request()).code=='target_changed','changed target '..field)
end
reset();hook=function(stage,n) if stage=='session' and n==2 then row.revision=3 end end
check(api:Check('manager',request()).code=='target_changed','target change during final session lookup')
reset();hook=function(stage) if stage=='interest' then actor.generation=2 end end
check(api:Check('manager',request()).code=='stale_session','actor generation changed')
reset();hook=function(stage) if stage=='interest' then api:Bump(5) end end
check(api:Check('manager',request()).code=='stale_session','session event fence changed')
reset();hook=function(stage) if stage=='interest' then api:Drop() end end
check(api:Check('manager',request()).code=='unavailable','dependency generation changed')
reset();hook=function(stage,n) if stage=='read' and n==3 then api:Bump(5) end end
check(api:Check('manager',request()).code=='stale_session','session changed during final target lookup')
reset();hook=function(stage) if stage=='policy' then error('offline') end end
check(api:Check('manager',request({path='staff'})).code=='policy_unavailable','policy exception fails closed')
reset();hook=function(stage) if stage=='interest' then error('offline') end end
check(api:Check('manager',request()).code=='property_unavailable','Property exception fails closed')
print(('PASS %d grant authority checks'):format(passed))
