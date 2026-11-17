for _,path in ipairs({'server/services/native_throwable_transition_binding.lua','server/services/native_throwable_transition_protocol.lua',
 'client/native_throwable_throw_freshness.lua','client/native_throwable_landing_capture.lua','client/native_throwable_landing_adapter.lua',
 'client/native_throwable_placement_client.lua'}) do dofile(path) end
local clock,quantity,deletions,writes=0,2,0,0
local exists,marks={},{}
local world={characterId='j',sessionId='s',epoch='e',revision=4,ped=7,alive=true,bucket=1,position={x=0,y=0,z=0}}
local canonical={custody='spent',operationId='observe:4',itemId=42,itemRevision=8,
 origin={characterId='j',sessionId='s',epoch='e'},metadata={weaponDefinitionId='throwable_tomahawk',serialNumber='paid-42'}}
local challenge={id='throw',identity=canonical.origin,operationId='observe:4',units={{itemId=42,itemRevision=8}},lifetimeMs=90000}
local rows={
 [100]={exists=true,netType=23,networkId=20,owner=1,bucket=1,model=0},
 [200]={exists=true,netType=8,networkId=57,owner=1,bucket=1,model=0}}
local protocol,client,token=nil,nil,0
joaat=function(name) return name=='w_melee_tomahawk01' and 3358573347 or name=='w_melee_tomahawk02' and 123 or 456 end
DecorIsRegisteredAsType=function() return true end
DecorExistOn=function(entity) return marks[entity]~=nil end
DecorSetInt=function(entity,_,n) marks[entity]=n;return true end
DecorGetInt=function(entity) return marks[entity] end
DoesEntityExist=function(entity) return exists[entity]==true end
GetEntityModel=function() return 3358573347 end
NetworkGetEntityIsNetworked=function() return true end
NetworkGetNetworkIdFromEntity=function(entity) return entity==8 and 20 or 57 end
NetworkHasControlOfEntity=function() return true end
GetProjectileOfProjectileTypeWithinDistance=function() return exists[8]==true,{},8 end
GetClosestObjectOfType=function(_,_,_,radius,model) assert(radius==1.5);return exists[9] and model==3358573347 and 9 or 0 end
GetGameTimer=function() return clock end
GetEntityCoords=function() return {x=1,y=0,z=0} end
GetEntitySpeed=function() return 0 end
IsEntityAttached=function(entity) return entity==9 end
GetEntityAttachedTo=function(entity) assert(entity==9);return 500 end
DeleteObject=function(entity) assert(entity==9,'only authorized successor may be deleted');deletions=deletions+1;exists[9]=false;rows[200].exists=false end
protocol=WeaponNativeThrowableTransitionProtocol.New({now=function() return clock end,
 actor=function(source) return source==1 and world or nil end,read=function(handle) return rows[handle] end,
 challenge=function(source,id) return source==1 and id=='throw' and challenge or nil end,spend=function() return canonical end,
 newId=function() token=token+1;return 'token-'..token end,
 place=function(source,spec) assert(deletions==1 and not exists[9]);assert(spec.itemId==42 and spec.itemRevision==8);writes=writes+1;error('lost commit reply') end,
 readPlacement=function() return {phase='available',id='pickup'} end})
client=WeaponNativeThrowablePlacementClient.New({world=function() return world end,now=function() return clock end,
 quantity=function() return quantity end,probe=function() return exists[8] and {entity=8,model=3358573347,networked=true,networkId=20} or nil end,
 newLanding=function(authorize,fresh) return WeaponNativeThrowableLandingAdapter.New(function() return world end,authorize,fresh) end,
 send=function(action,request) local result=protocol.Handle(1,action,request);assert(client.Result(action,request.id,result),action..':'..result.phase) end})
client.Tick();clock=50;quantity=1;exists[8]=true;assert(protocol.Created(100));client.Tick()
if not THROWABLE_DELAYED_CHALLENGE then assert(client.Challenge(challenge));client.Tick() end
clock=150;exists[8]=false;rows[100].exists=false;protocol.Removed(100);exists[9]=true;assert(protocol.Created(200))
client.Tick()
local offset=0
if THROWABLE_DELAYED_CHALLENGE then
 assert(client.Status().phase=='observing' and client.Status().landing.phase=='transition_pending')
 assert(protocol.Diagnostics().phase=='idle' and deletions==0 and writes==0,
  'early observation cannot request server authority or mutate paid storage')
 clock=3300;client.Tick()
 assert(client.Challenge(challenge),'receipt arriving after projectile removal must bind preserved continuity')
 client.Tick();offset=3150
end
assert(client.Status().phase=='capturing' and marks[9]~=nil and deletions==0)
assert(client.Status().landing.originalObject.entity==8 and client.Status().landing.object.entity==9)
clock=200+offset;client.Tick();clock=950+offset;client.Tick();assert(client.Status().phase=='cleanup_authorized')
clock=1000+offset;client.Tick();assert(deletions==1 and writes==0,'client absence alone cannot publish before server removal')
clock=1100+offset;protocol.Removed(200);clock=3100+offset;client.Tick();assert(writes==1 and client.Status().phase=='awaiting_publication')
clock=5200+offset;client.Tick();assert(writes==1 and deletions==1 and client.Status().phase=='complete')
assert(protocol.Handle(1,'cleaned',{id='throw',cleanupToken='token-2'}).phase=='available' and writes==1)
print('PASS composed projectile->Pickup: server lifetime/paid receipt authorization, new client marker, exact successor cleanup, server absence gate and receipt-only lost-write completion')
