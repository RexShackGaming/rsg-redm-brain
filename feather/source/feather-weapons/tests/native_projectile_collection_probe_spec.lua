dofile('server/services/native_throwable_transition_binding.lua')
dofile('server/services/native_projectile_collection_observation.lua')
dofile('server/services/native_projectile_collection_probe.lua')
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local event={referenceBuild=1491,kind='ai_pickup',queue=0,eventHash=-178091376,localPlayerIndex=16,nativeTomahawkQuantity=1,
 rawSlots={-897823490,1,16,-936393949,0,147252816,1,-1511427369}}
local function fixture(foreign)
 local time,live=0,true
 local identity={characterId='jane',sessionId='sid',epoch='native-loan:ticket'}
 local actor={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch,alive=true,bucket=0,position={x=0,y=0,z=0}}
 local rows={[1]={exists=true,networkId=23,netType=23,owner=4,bucket=0},[2]={exists=true,networkId=24,netType=8,owner=4,bucket=0}}
 local tasks={}
 local p=WeaponNativeProjectileCollectionProbe.New({identity=identity,target=4,collector=foreign and 8 or nil,current=function() return live end,
  actor=function(source)
   if source==4 then return copy(actor) end
   if foreign and source==8 then local c=copy(actor);c.characterId='collector';c.sessionId='collector-sid';c.epoch='collector-epoch';return c end
  end,read=function(handle) return copy(rows[handle]) end,
  now=function() return time end,later=function(delay,fn) tasks[#tasks+1]={at=time+delay,fn=fn} end})
 assert(p.Created(1));time=150;rows[1].exists=false;p.Removed(1)
 time=160;assert(p.Created(2))
 return p,actor,rows,function(v)
  time=v
  local old=tasks;tasks={}
  for _,task in ipairs(old) do if task.at<=time then task.fn() else tasks[#tasks+1]=task end end
 end,function(v) live=v end
end
local p,a,rows,time,live=fixture()
assert(p.Hint('owned_projectile',{networkId=23,model=3358573347}))
assert(p.Hint('collection_candidate',{networkId=24,model=3358573347,position={x=0,y=0,z=0}}))
assert(p.Hint('collection_event',event));assert(p.Report().observation.phase=='pending')
rows[2].exists=false;p.Removed(2);time(300)
local r=p.Report();assert(r.phase=='correlated_observation' and r.observation.itemId==900000001 and not r.canClaim and r.syntheticNativeOnly)
assert(r.observation.pickupNetworkId==24 and r.observation.itemRevision==1 and r.economicWrites==0)
assert(not p.Hint('collection_event',event),'one event per synthetic native loan')
local p,a,rows,time=fixture()
p.Hint('collection_event',event)
assert(p.Report().reason=='collection_before_binding')
local p,a,rows,time=fixture()
p.Hint('owned_projectile',{networkId=23,model=3358573347})
p.Hint('collection_candidate',{networkId=24,model=3358573347,position={x=0,y=0,z=0}})
p.Hint('collection_candidate',{networkId=25,model=3358573347,position={x=0,y=0,z=0}})
assert(p.Report().reason=='competing_native_candidates' and p.Report().phase=='review_required')
local p,a,rows,time,live=fixture();live(false)
assert(not p.Hint('owned_projectile',{networkId=23,model=3358573347}),'no hints after scope closes')
local p,a,rows,time=fixture(true)
p.Hint('owned_projectile',{networkId=23,model=3358573347},4)
p.Hint('collection_candidate',{networkId=24,model=3358573347,position={x=0,y=0,z=0}},4)
assert(not p.Hint('collection_event',event,4),'thrower cannot substitute for designated collector')
assert(not p.Hint('collection_candidate',{networkId=25,model=3358573347,position={x=0,y=0,z=0}},8),'collector cannot choose origin lifetime')
assert(p.Hint('collection_event',event,8))
rows[2].exists=false;p.Removed(2);time(300)
assert(p.Report().observation.collector.characterId=='collector' and p.Report().observation.origin.characterId=='jane')
print('PASS synthetic collection probe composition: real lifetime binding, watched native collection/removal, early event and competing candidate refusal; no Inventory ports')

-- Real synthetic lifetime store: ambiguity refuses attribution, while cleanup
-- requires two actual projectile/Pickup callback pairs and native absence.
for _,separation in ipairs({0,3}) do
 local clock=0
 local actor={characterId='jane',sessionId='sid',epoch='loan',alive=true,bucket=0,position={x=0,y=0,z=0}}
 local rows={}
 local p=WeaponNativeProjectileCollectionProbe.New({competing=true,target=4,collector=8,identity=copy(actor),
  current=function() return true end,now=function() return clock end,
  actor=function(id) if id==4 then return copy(actor) end;if id==8 then local a=copy(actor);a.characterId='john';return a end end,
  read=function(handle) return copy(rows[handle]) end})
 for index=1,2 do
  local projectile=20+index;local pickup=30+index
  rows[index]={exists=true,networkId=projectile,netType=23,owner=4,bucket=0}
  p.Created(index);p.Hint('owned_projectile',{networkId=projectile,model=3358573347},4)
  clock=clock+100;rows[index].exists=false;p.Removed(index)
  rows[index+2]={exists=true,networkId=pickup,netType=8,owner=4,bucket=0}
  p.Created(index+2);p.Hint('collection_candidate',{networkId=pickup,model=3358573347,position={x=index==2 and separation or 0,y=0,z=0}},4)
 end
 p.Hint('collection_event',event,8)
 local r=p.Report();assert(r.expectedAmbiguityRefused==(separation==0) and not r.syntheticBatchAbsent and not r.canClaim)
 assert(r.competingDistanceSquared==separation^2)
 rows[3].exists=false;p.Removed(3)
 assert(not p.Report().syntheticBatchAbsent,'one remaining pickup cannot certify the pair')
 rows[4].exists=false
 assert(not p.Report().syntheticBatchAbsent,'native disappearance still requires registered removal')
 p.Removed(4)
 assert(p.Report().syntheticBatchAbsent and p.Report().reason=='competing_native_candidates')
 rows[4].exists=true
 assert(not p.Report().syntheticBatchAbsent,'reappearing/reused native handle invalidates absence')
end
