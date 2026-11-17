-- Real client freshness/controller/native adapter plus server handshake;
-- only native engine and canonical publication storage ports are modeled.
for _,path in ipairs({'client/native_throwable_throw_freshness.lua','client/native_throwable_landing_capture.lua',
 'client/native_throwable_landing_adapter.lua','client/native_throwable_placement_client.lua',
 'server/services/native_throwable_placement_handshake.lua'}) do dofile(path) end
local clock,quantity,exists,marker=0,2,false,nil
local deletions,writes,client,server=0,0,nil,nil
local world={characterId='jane',sessionId='session',epoch='epoch',ped=7,revision=4,alive=true,bucket=1,position={x=0,y=0,z=0}}
local object={entity=8,model=3358573347,networked=true,networkId=9}
joaat=function(name) return name=='w_melee_tomahawk01' and 3358573347 or name=='w_melee_tomahawk02' and 123 or 456 end
DecorIsRegisteredAsType=function() return true end
DecorExistOn=function() return marker~=nil end
DecorSetInt=function(_,_,value) marker=value;return true end
DecorGetInt=function() return marker end
DoesEntityExist=function() return exists end
GetEntityModel=function() return object.model end
NetworkGetEntityIsNetworked=function() return true end
NetworkGetNetworkIdFromEntity=function() return 9 end
NetworkHasControlOfEntity=function() return true end
GetProjectileOfProjectileTypeWithinDistance=function() return exists,{},8 end
GetGameTimer=function() return clock end
GetEntityCoords=function() return {x=1,y=0,z=0} end
GetEntitySpeed=function() return 0 end
IsEntityAttached=function() return false end
DeleteObject=function() deletions=deletions+1;exists=false end
local challenge={id='throw',identity={characterId='jane',sessionId='session',epoch='epoch'},operationId='observe:4',
 units={{itemId=42,itemRevision=8}},lifetimeMs=90000}
server=WeaponNativeThrowablePlacementHandshake.New({actor=function() return world end,
 challenge=function(source,id) if source==1 and id=='throw' then
  return {phase='issued',identity=challenge.identity,units=challenge.units,operationId=challenge.operationId} end end,
 newId=function() return 'cleanup-token' end,
 place=function(source,spec)
  assert(not exists and deletions==1,'publication must follow positive native absence')
  assert(source==1 and spec.itemId==42 and spec.itemRevision==8 and spec.spendOperationId=='observe:4')
  writes=writes+1;return {phase='available',id='pickup'}
 end,
 read=function() return {phase='available',id='pickup'} end})
client=WeaponNativeThrowablePlacementClient.New({world=function() return world end,
 now=function() return clock end,quantity=function() return quantity end,
 probe=function() return exists and object or nil end,
 newLanding=function(authorize,fresh) return WeaponNativeThrowableLandingAdapter.New(function() return world end,authorize,fresh) end,
 send=function(action,request)
  local result=server.Handle(1,action,request);result.id=request.id
  assert(client.Result(action,request.id,result))
 end})
client.Tick();assert(client.Ready())
clock=50;quantity=1;exists=true;client.Tick();assert(not client.Ready())
assert(client.Challenge(challenge));client.Tick();assert(deletions==0 and writes==0)
clock=800;client.Tick();assert(client.Status().phase=='cleanup_authorized' and writes==0)
client.Tick();assert(client.Status().phase=='complete' and writes==1 and deletions==1)
assert(client.Challenge(challenge));client.Tick();client.Tick()
assert(client.Status().phase=='complete' and client.AcknowledgeCompletion('throw'));client.Tick()
assert(client.Ready() and writes==1 and deletions==1)
print('PASS composed throwable placement: pre-observed paid-revision association, actual decorator/stable-landing/cleanup controller, server token and single post-absence publication')
