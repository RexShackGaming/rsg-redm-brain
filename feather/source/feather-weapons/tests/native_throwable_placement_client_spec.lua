dofile('client/native_throwable_throw_freshness.lua')
dofile('client/native_throwable_placement_client.lua')
local function fixture()
 local w={characterId='j',sessionId='s',epoch='e',ped=7,revision=4,alive=true}
 local n,t,obj=2,0,nil;local sent,cleanups={},0
 local p
 local api={world=function() return w end,quantity=function() return n end,probe=function() return obj end,now=function() return t end,
 send=function(action,request) sent[#sent+1]={action=action,request=request} end,
 newLanding=function(authorize,fresh)
  assert(fresh(w).entity==8)
  return {Start=function() return true end,Tick=function() return {phase='landed',position={x=1,y=0,z=0}} end,
   Cleanup=function() assert(authorize({id='throw'}));cleanups=cleanups+1;return true end}
 end}
 p=WeaponNativeThrowablePlacementClient.New(api)
 local packet={id='throw',operationId='observe:4',lifetimeMs=90000,identity=w,units={{itemId=42,itemRevision=8}}}
 p.Tick();assert(p.Ready());n=1;t=100;obj={entity=8};p.Tick();assert(not p.Ready())
 return p,w,packet,sent,function(time) t=time end,function() return cleanups end,api
end
local p,w,packet,sent,time,cleanups=fixture()
assert(p.Challenge(packet));assert(p.Challenge(packet));p.Tick()
assert(sent[1].action=='landing' and cleanups()==0)
time(2200);p.Tick();assert(sent[2].action=='status','lost landing reply uses read only')
assert(not p.Result('landing','wrong',{id='wrong',phase='cleanup_authorized',cleanupToken='token'}))
assert(p.Result('status','throw',{id='throw',phase='cleanup_authorized',cleanupToken='token'}))
p.Tick();assert(cleanups()==1 and sent[3].action=='cleaned')
assert(not p.Result('landing','throw',{id='throw',phase='cleanup_authorized',cleanupToken='token'}))
time(4300);p.Tick();assert(sent[4].action=='status' and cleanups()==1)
assert(p.Result('status','throw',{id='throw',phase='available',pickupId='pickup'}));p.Tick()
assert(p.Status().phase=='complete','async completion must remain visible across Tick')
assert(not p.AcknowledgeCompletion('foreign'));assert(p.AcknowledgeCompletion('throw'))
assert(not p.AcknowledgeCompletion('throw'),'completion ACK is idempotently refused after rearm')
assert(p.Status().phase=='observing' and p.Challenge(packet),'completed challenge duplicate is inert')
assert(p.Status().phase=='observing')
local p,w,packet,sent,time,cleanups=fixture();packet.operationId='observe:3';assert(not p.Challenge(packet) and #sent==0)
local p,w,packet,sent,time,cleanups=fixture();assert(p.Challenge(packet));p.Tick();w.sessionId='other';p.Tick()
assert(p.Status().phase=='review_required' and cleanups()==0)
local p,w,packet,sent,time,cleanups,api=fixture();assert(p.Challenge(packet));api.send=function() error('transport failed') end;p.Tick()
time(2200);api.send=function(action) assert(action=='status') end;p.Tick();assert(cleanups()==0)
print('PASS placement client: real freshness association, cleanup authorization, exact one cleanup, lost-reply read-only polling and completed challenge replay refusal')
