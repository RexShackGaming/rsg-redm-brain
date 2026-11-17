dofile('server/services/native_throwable_transition_binding.lua')
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function fixture()
 local time=100
 local actor={characterId='j',sessionId='s',epoch='e',alive=true,bucket=1}
 local challenge={identity=copy(actor),operationId='observe:1',units={{itemId=42,itemRevision=8}}}
 challenge.identity.alive=nil;challenge.identity.bucket=nil
 local spend={custody='spent',operationId='observe:1',itemId=42,itemRevision=8,origin=copy(challenge.identity),
  metadata={weaponDefinitionId='throwable_tomahawk',serialNumber='paid-42',maintenance={damage=0.1}}}
 local rows={
  [10]={exists=true,netType=23,networkId=108,owner=4,bucket=1,model=0},
  [20]={exists=true,netType=8,networkId=25,owner=4,bucket=1,model=0}}
 local api={now=function() return time end,actor=function(source) return source==4 and copy(actor) or nil end,
  read=function(handle) return copy(rows[handle]) end,
  challenge=function(source,id) return source==4 and id=='challenge' and copy(challenge) or nil end,
  spend=function() return copy(spend) end}
 local t=WeaponNativeThrowableTransitionBinding.New(api)
 assert(t.Created(10));time=250;t.Removed(10);rows[10].exists=false
 time=260;assert(t.Created(20))
 return t,api,actor,challenge,spend,rows,function(v) time=v end
end
local t,api,a,c,s,rows,time=fixture()
local result=t.Link(4,'challenge',108,25)
assert(result.phase=='linked' and result.proof.itemId==42 and result.proof.metadata.maintenance.damage==0.1
 and result.proof.serverModelReadable==false and result.proof.originConfirmed==false)
assert(t.Current(result.proof));assert(t.Link(4,'challenge',108,25).phase=='pending')
do
 local t,api,a,c,s,rows,time=fixture();local linked=t.Link(4,'challenge',108,25)
 rows[20].exists=false;t.Removed(20)
 local spends,challenges,actors=0,0,0
 local readSpend,readChallenge,readActor=api.spend,api.challenge,api.actor
 api.spend=function(...) spends=spends+1;return readSpend(...) end
 api.challenge=function(...) challenges=challenges+1;return readChallenge(...) end
 api.actor=function(...) actors=actors+1;return readActor(...) end
 for _=1,20 do assert(t.GuardAbsent(linked.proof)) end
 assert(spends==0 and challenges==0 and actors==20,'transaction continuation checks fresh actor/lifetime without reopening paid receipt queries')
 assert(t.Absent(linked.proof) and spends==1 and challenges==1,'full correlation still verifies canonical receipt')
 a.alive=false;assert(not t.GuardAbsent(linked.proof));a.alive=true
 a.epoch='changed';assert(not t.GuardAbsent(linked.proof));a.epoch='e'
 rows[20].exists=true;assert(not t.GuardAbsent(linked.proof));rows[20].exists=false
 time(90300);assert(not t.GuardAbsent(linked.proof),'continuation authority expires')
end
local altered=copy(result.proof);altered.metadata.serialNumber='forged';assert(not t.Current(altered))
rows[20].owner=7;assert(not t.Current(result.proof),'ownership migration revokes cleanup authority')
assert(not t.CollectionPresent(result.proof,7),'unknown collector cannot adopt a migrated lifetime')
rows[20].owner=nil;assert(not t.Current(result.proof),'unreadable owner must never match a missing collector override')
for _,mode in ipairs({'session','receipt','late','ambiguous','reused','missing','source'}) do
 local t,api,a,c,s,rows,time=fixture()
 if mode=='session' then a.sessionId='new' elseif mode=='receipt' then s.itemRevision=9
 elseif mode=='late' then rows[20].exists=false;t.Removed(20);time(5000);rows[30]={exists=true,netType=8,networkId=26,owner=4,bucket=1};t.Created(30)
 elseif mode=='ambiguous' then rows[30]={exists=true,netType=8,networkId=26,owner=4,bucket=1};t.Created(30)
 elseif mode=='reused' then t.Removed(20);rows[30]=copy(rows[20]);t.Created(30)
 elseif mode=='missing' then rows[20].exists=false end
 local result=t.Link(mode=='source' and 5 or 4,'challenge',108,mode=='late' and 26 or 25)
 assert(result.phase=='refused',mode)
end
local t,api,a,c,s,rows,time=fixture();local result=t.Link(4,'challenge',108,25)
rows[30]={exists=true,netType=8,networkId=26,owner=4,bucket=1};t.Created(30)
assert(not t.Current(result.proof),'a late competing lifetime revokes existing link')
local t,api,a,c,s,rows,time=fixture();local original=api.spend;local calls=0
api.spend=function(...)
 calls=calls+1;assert(t.Link(4,'challenge',108,25).phase=='pending','reserve before yielding receipt')
 return original(...)
end
assert(t.Link(4,'challenge',108,25).phase=='linked' and calls==2)
local t,api,a,c,s,rows,time=fixture();local read=api.read
rows[30]={exists=true,netType=8,networkId=26,owner=4,bucket=1}
api.read=function(handle) assert(not t.Created(handle),'creation callback reserved before yielding native ports');return read(handle) end
assert(t.Created(30))
local t,api,a,c,s,rows,time=fixture();local actor=api.actor;local once=true
rows[40]={exists=true,netType=23,networkId=109,owner=4,bucket=1}
api.actor=function(source)
 if once then once=false;time(350);rows[40].exists=false;t.Removed(40) end
 return actor(source)
end
time(300);assert(t.Created(40));time(360)
rows[50]={exists=true,netType=8,networkId=27,owner=4,bucket=1};assert(t.Created(50))
assert(t.Link(4,'challenge',109,27).phase=='linked','removal during yielding creation read preserves event timing')
print('PASS staged transition binding: observed projectile/Pickup lifetimes, exact paid metadata, ambiguity/reuse/session/native ownership refusal and pre-yield reservation; no model0-as-match')
dofile('server/services/native_projectile_collection_observation.lua')
local t,api,a,c,s,rows,time=fixture()
local linked=t.Link(4,'challenge',108,25);assert(linked.phase=='linked')
local collector={characterId='other-player',sessionId='collector-session',epoch='collector-epoch',alive=true,bucket=1,position={x=0,y=0,z=0}}
local originActor=api.actor
api.actor=function(source) if source==8 then return copy(collector) end;return originActor(source) end
local observations=WeaponNativeProjectileCollectionObservation.New({now=api.now,current=t.Current,absent=t.Absent,present=t.CollectionPresent,pending=t.CollectionPending,
 actor=function(source) return source==8 and copy(collector) end})
local forged=copy(linked.proof);forged.metadata.serialNumber='different-unit'
assert(observations.Watch('forged',forged,{x=0,y=0,z=0},1).reason=='transition_not_current')
assert(observations.Watch('real',linked.proof,{x=0,y=0,z=0},1).phase=='watching')
local event={referenceBuild=1491,kind='ai_pickup',queue=0,eventHash=-178091376,localPlayerIndex=16,nativeTomahawkQuantity=1,
 rawSlots={-897823490,1,16,-936393949,0,147252816,1,-1511427369}}
rows[20].owner=8
assert(not t.Current(linked.proof),'migration must still revoke cleanup authority')
assert(t.CollectionPresent(linked.proof,8),'designated collector may be observed while waiting for removal')
rows[20].exists=false
assert(not t.Current(linked.proof) and not t.Absent(linked.proof),'native absence alone cannot certify cleanup')
assert(t.CollectionPending(linked.proof,8),'registered lifetime may wait for delayed removal callback')
s.metadata.extra='changed'
assert(not t.CollectionPending(linked.proof,8),'receipt changes remain fatal even in native/callback gap')
s.metadata.extra=nil
local pending=observations.Observe(8,'live-shaped-event',event)
assert(pending.phase=='pending' and pending.reason=='awaiting_lifetime_removal_settlement')
t.Removed(20)
local correlated=observations.Read(8,'live-shaped-event')
assert(correlated.phase=='correlated_observation' and correlated.itemId==42 and correlated.itemRevision==8
 and correlated.pickupLifetime==linked.proof.pickupLifetime and correlated.collector.characterId=='other-player'
 and not correlated.canClaim and correlated.economicWrites==0)
print('PASS real transition binding + collection observation composition: exact proof/metadata validation, server removal, foreign collector; no item credit')
local t,api,a,c,s,rows,time=fixture();local linked=t.Link(4,'challenge',108,25)
t.Removed(20) -- callback can precede native finalization too
assert(not t.Current(linked.proof) and not t.Absent(linked.proof))
assert(t.CollectionPending(linked.proof,4),'callback before native absence remains observation-only pending')
rows[20].networkId=999
assert(not t.CollectionPending(linked.proof,4),'pending settlement never accepts a replaced native lifetime')
rows[20].networkId=25;rows[20].exists=false
assert(t.Absent(linked.proof),'only callback plus native absence confirms the exact registered lifetime')
