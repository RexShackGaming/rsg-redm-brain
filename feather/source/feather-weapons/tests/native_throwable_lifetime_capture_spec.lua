dofile('server/services/native_throwable_lifetime_capture.lua')
local function fixture()
 local time,valid,mode,net=100,true,'normal',16
 local timers={}
 local api={now=function() return time end,current=function() return valid end,
 resolve=function() if mode=='missing' then return 0 end;return 50 end,
 later=function(ms,fn) timers[#timers+1]={ms=ms,fn=fn} end,tomahawk=function(hash) return hash==101 end,
 read=function(handle,target)
  assert(target==9)
  if mode=='exception' then error('native unavailable') end
  if mode=='absent' then return nil end
  if mode=='projectile' then return nil,'model_mismatch_0',
   {exists=true,entityType=3,netType=23,networkId=net,owner=9,model=0} end
  return {networkId=net,model=201,owner=mode=='foreign' and 8 or 9,
   bucket=mode=='bucket' and 2 or 1,playerBucket=1,nearby=mode~='far'}
 end}
 local capture=WeaponNativeThrowableLifetimeCapture.New(api,9,'ticket')
 local function cases(model) return {{worldEvidence={{kind='tomahawk_object_snapshot',object={networked=true,networkId=16,model=model or 201}}},
  pickupEvents={{kind='ai_pickup',rawSlots={1,1,16,201}}}}} end
 return capture,cases,function(m) mode=m end,function() valid=false end,function(n) net=n end,
 function() for _,t in ipairs(timers) do time=time+t.ms;t.fn() end;timers={} end
end
local c,cases,mode,close,net,timers=fixture()
c.Created(50);timers();c.Removed(50)
local r=c.Report(cases());assert(r.phase=='matched' and #r.matches==1 and r.matches[1].removedObserved)
assert(r.matches[1].networkId==16 and r.matches[1].originConfirmed==false and r.noWrites and #r.records==4)
assert(c.Report(cases(999)).phase=='unconfirmed','same network ID with wrong model refuses')
assert(c.Report({{worldEvidence={false,17,{kind='tomahawk_object_snapshot',object=17}}}}).phase=='unconfirmed')
assert(c.Report({{worldEvidence='invalid'}}).phase=='unconfirmed','malformed diagnostic rows do not interrupt safe restoration')
assert(c.Report({{pickupEvents={{kind='ai_pickup',rawSlots={1,1,16,201}}}}}).phase=='unconfirmed',
 'collector player index16 does not provide a world network ID')
for _,bad in ipairs({'foreign','bucket','far','absent','exception'}) do
 local c,cases,mode=fixture();mode(bad);c.Created(50)
 assert(c.Report(cases()).phase=='unconfirmed',bad)
end
local c,cases,mode,close,net,timers=fixture()
c.Created(50);c.Removed(50);c.Created(50);timers()
r=c.Report(cases());assert(r.phase=='unconfirmed' and #r.matches==2 and r.matches[1].ambiguous,
 'reused handle/network ID has two lifetimes; stale timers cannot sample the replacement as the original')
local c,cases,mode,close,net,timers=fixture()
c.Created(50);net(17);timers();assert(c.Report(cases()).phase=='unconfirmed','changed network ID taints earlier samples too')
local c,cases,mode,close,net,timers=fixture()
c.Created(50);close();timers();c.Removed(50)
assert(#c.Report(cases()).records==1,'late callbacks and removal cannot cross session end')
local c,cases=fixture()
for i=1,65 do c.Created(i) end
assert(c.Report(cases()).truncated and c.Report(cases()).phase=='unconfirmed','bounded creation attempts')
local c,cases=fixture()
c.Projectile(8,{weaponHash=101});c.Projectile(9,{weaponHash=0/0});c.Projectile(9,{weaponHash=999})
assert(#c.Report(cases()).records==0)
c.Projectile(9,{weaponHash=101,projectileHash=55,unknownNetworkId=16})
r=c.Report(cases());assert(#r.records==1 and r.records[1].fields.unknownNetworkId==nil and r.phase=='unconfirmed')
print('PASS server throwable lifetime: scoped read-only samples, bucket/owner/proximity gates, removal, reuse ambiguity, stale timers and no event-index authority')

local c,cases,mode=fixture()
c.Hint(16,201)
local r=c.Report(cases())
assert(r.phase=='observed_without_creation' and r.counters.createdCallbacks==0 and r.counters.hintRequests==1
 and r.counters.hintResolved==1 and r.matches[1].creationObserved==false and r.originConfirmed==false,
 'real-time lookup proves visibility only; it cannot invent a creation callback or paid ownership')
local c,cases,mode=fixture();mode('missing');c.Hint(16,201)
assert(c.Report(cases()).rejected.lookup_missing==1)
local c,cases,mode=fixture();mode('foreign');c.Hint(16,201)
assert(c.Report(cases()).rejected.owner_mismatch==1 and c.Report(cases()).phase=='unconfirmed')
local c,cases=fixture();c.Hint(16,999)
assert(c.Report(cases()).rejected.lookup_identity_mismatch==1)
for i=1,20 do c.Hint(16,201) end
assert(c.Report(cases()).counters.hintRequests==8,'bounded untrusted hint reads')
local c,cases,mode,close,net,timers=fixture()
mode('missing');c.Hint(16,201);mode('normal');timers()
local report=c.Report(cases())
assert(report.phase=='observed_without_creation' and report.counters.hintRequests==1
 and report.counters.hintResolved==1 and report.counters.lookupAttempts==2,
 'one hint may repeat native reads after propagation delay, without repeating any gameplay mutation')
local c,cases,mode,close,net,timers=fixture()
mode('missing');c.Hint(16,201);close();timers()
assert(c.Report(cases()).counters.lookupAttempts==1,'pending readiness reads stop at session end')
local c,cases,mode,close,net,timers=fixture()
mode('missing');c.Hint(16,201);timers()
assert(c.Report(cases()).counters.lookupAttempts==6,'persistent absence is bounded to six reads')

local c,cases,mode,close,net,timers=fixture()
mode('projectile');c.Created(50);c.Hint(16,201);c.Removed(50);timers()
local r=c.Report(cases())
assert(r.phase=='unconfirmed' and #r.matches==0 and r.originConfirmed==false)
assert(r.records[1].kind=='server_projectile_unverified_sample')
assert(r.records[1].readback.model==0 and r.records[1].readback.netType==23)
assert(r.records[2].kind=='server_lookup_rejected' and r.records[2].creationObserved==true)
assert(r.records[2].lifetimeId==r.records[1].lifetimeId)
assert(r.records[3].kind=='server_projectile_unverified_removed'
 and r.records[3].lifetimeId==r.records[1].lifetimeId)
assert(r.counters.hintResolved==0,'diagnostic projectile must not become a verified Tomahawk')
local c,cases,mode,close,net,timers=fixture()
mode('projectile');c.Created(50);c.Removed(50);c.Created(50);timers()
local r=c.Report(cases())
assert(r.records[1].lifetimeId~=r.records[3].lifetimeId and r.phase=='unconfirmed',
 'reused unverified handles retain separate lifetimes without granting authority')
print('PASS unverified WorldProjectile lifecycle retains model-zero evidence without matching or credit')
