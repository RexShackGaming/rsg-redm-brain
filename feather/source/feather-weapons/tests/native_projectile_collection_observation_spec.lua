dofile('server/services/native_projectile_collection_observation.lua')
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local event={referenceBuild=1491,kind='ai_pickup',queue=0,eventHash=-178091376,localPlayerIndex=16,nativeTomahawkQuantity=1,
 rawSlots={-897823490,1,16,-936393949,0,147252816,1,-1511427369}}
local function fixture()
 local time,removed=0,false
 local origin={characterId='jane',sessionId='origin',epoch='origin-epoch'}
 local actor={characterId='john',sessionId='collector',epoch='collector-epoch',alive=true,bucket=0,position={x=0,y=0,z=0}}
 local proof={kind='paid_throwable_transition',identity=copy(origin),itemId=109,itemRevision=2,pickupLifetime=4,pickupNetworkId=24}
 local api={now=function() return time end,actor=function(source) return source==8 and copy(actor) end,
  current=function() return not removed end,absent=function() return removed end}
 local p=WeaponNativeProjectileCollectionObservation.New(api)
 assert(p.Watch('unit109',proof,{x=0,y=0,z=0},0).phase=='watching')
 return p,api,actor,proof,function(v) time=v end,function(v) removed=v end
end

do
 local p,api,a=fixture()
 api.actor=function() coroutine.yield('medical_wait');return copy(a) end
 local worker=coroutine.create(function() return p.Observe(8,'yielded',event) end)
 assert(select(2,coroutine.resume(worker))=='medical_wait')
 local waiting=p.Read(8,'yielded')
 assert(waiting.phase=='pending' and waiting.reason=='observation_read_in_flight','busy observer read is not invalid input')
 api.actor=function() return copy(a) end
 assert(coroutine.resume(worker))
 assert(p.Read(8,'yielded').phase=='pending')
end

-- Two collectors may observe the same disappearing lifetime while its server
-- removal is pending. Only one observation can retain it when removal settles.
for _,winner in ipairs({8,9}) do
 local p,api,a,proof,time,removed=fixture()
 local second=copy(a);second.characterId='second';second.sessionId='second-session';second.epoch='second-epoch'
 api.actor=function(source) return source==8 and copy(a) or source==9 and copy(second) end
 assert(p.Observe(8,'race',event).phase=='pending')
 assert(p.Observe(9,'race',event).phase=='pending')
 removed(true)
 local won=p.Read(winner,'race');local lost=p.Read(winner==8 and 9 or 8,'race')
 assert(won.phase=='correlated_observation' and lost.reason=='lifetime_already_observed')
 assert(p.Read(winner,'race').phase=='correlated_observation','read-only rereads are stable')
 assert(p.Observe(winner,'replay',event).reason=='lifetime_already_observed')
 assert(not won.canClaim and not lost.canClaim and won.economicWrites==0 and lost.economicWrites==0)
end
local p,api,a,proof,time,removed=fixture()
assert(p.Observe(8,'event1',event).phase=='pending')
removed(true);local result=p.Read(8,'event1')
assert(result.phase=='correlated_observation' and result.itemId==109 and result.itemRevision==2 and result.pickupNetworkId==24)
assert(result.origin.characterId=='jane' and result.collector.characterId=='john','collector may differ from thrower')
assert(result.canClaim==false and result.pickupCredits==false and result.originConfirmed==false and result.economicWrites==0)
result.itemId=999;assert(p.Read(8,'event1').itemId==109,'report copies cannot mutate retained identity')
assert(p.Observe(8,'event1',event).reason=='duplicate_observation_use_read')
assert(p.Observe(8,'event2',event).reason=='lifetime_already_observed')
a.sessionId='replacement';assert(p.Read(8,'event1').reason=='collector_scope_changed')
for _,mode in ipairs({'two-live','two-removed','distant-other','wrong-bucket-other'}) do
 local p,api,a,proof,time,removed=fixture()
 local other=copy(proof);other.itemId=110;other.pickupLifetime=5;other.pickupNetworkId=25
 assert(p.Watch('other',other,{x=mode=='distant-other' and 10 or 0,y=0,z=0},mode=='wrong-bucket-other' and 1 or 0).phase=='watching')
 removed(mode~='two-live')
 local r=p.Observe(8,'event',event)
 assert(r.phase==((mode=='two-live' or mode=='two-removed') and 'review_required' or 'correlated_observation'),mode)
 if mode=='two-live' or mode=='two-removed' then assert(r.reason=='ambiguous_bound_candidates') end
end
for _,mode in ipairs({'bucket','distance','dead','missing-source','build','collector','quantity','slots','unknown-model','network-event'}) do
 local p,api,a,proof,time,removed=fixture();removed(true);local e=copy(event);local source=8
 if mode=='bucket' then a.bucket=1 elseif mode=='distance' then a.position.x=3 elseif mode=='dead' then a.alive=false
 elseif mode=='missing-source' then source=9 elseif mode=='build' then e.referenceBuild=1492
 elseif mode=='collector' then e.rawSlots[3]=17 elseif mode=='quantity' then e.nativeTomahawkQuantity=2
 elseif mode=='slots' then e.rawSlots[9]=0 elseif mode=='unknown-model' then e.rawSlots[4]=0
 elseif mode=='network-event' then e.kind='network_pickup';e.queue=1 end
 local r=p.Observe(source,'event',e);assert(r.phase=='refused' or r.phase=='review_required',mode)
 assert(not r.canClaim)
end
local p,api,a,proof,time,removed=fixture()
assert(p.Observe(8,'event',event).phase=='pending');time(751);removed(true)
assert(p.Read(8,'event').reason=='collection_window_expired')
local p,api,a,proof,time,removed=fixture()
assert(p.Observe(8,'pending-competing',event).phase=='pending')
local other=copy(proof);other.itemId=110;other.pickupLifetime=5;other.pickupNetworkId=25
assert(p.Watch('late-nearby',other,{x=0,y=0,z=0},0).phase=='watching')
removed(true)
assert(p.Read(8,'pending-competing').reason=='ambiguous_bound_candidates',
 'a nearby lifetime arriving during pending removal invalidates the earlier single-candidate observation')
local p,api,a,proof,time,removed=fixture()
assert(p.Observe(8,'event',event).phase=='pending')
api.absent=function() a.epoch='changed';return true end
assert(p.Read(8,'event').reason=='collector_scope_changed','yielding proof read cannot cross collector epoch')
local p,api,a,proof,time,removed=fixture()
api.current=function() return false end
assert(p.Observe(8,'event',event).reason=='transition_authority_changed')
local p,api,a,proof,time,removed=fixture()
api.absent=function() error('native read failed') end
assert(p.Observe(8,'event',event).reason=='collection_read_unavailable')
-- Opaque AI f_5 cannot select a unit, regardless of a coincidental net ID.
local p,api,a,proof,time,removed=fixture();removed(true)
local e=copy(event);e.rawSlots[6]=24
assert(p.Observe(8,'event',e).reason=='client_event_not_ownership_proof')
print('PASS staged collection observation: exact watched identity, cross-player collector, competing lifetime ambiguity, scopes, expiry, replay, native read failure; no economic authority')

-- Diagnose the live no-bound-candidate result without weakening any filter.
for _,mode in ipairs({'distance','bucket','expired'}) do
 local p,api,a,proof,time,removed=fixture();removed(true)
 if mode=='distance' then a.position.x=3 elseif mode=='bucket' then a.bucket=1 else time(120001) end
 local r=p.Observe(8,'diagnostic',event)
 assert(r.reason=='no_bound_candidate' and not r.canClaim and r.economicWrites==0)
 local d=r.candidateDiagnostics;assert(d.version==1 and d.candidateCount==0 and #d.watches==1)
 local w=d.watches[1]
 assert(w.pickupNetworkId==24 and w.pickupLifetime==4 and not w.accepted)
 assert(w.withinDistance==(mode~='distance') and w.bucketMatches==(mode~='bucket') and w.withinWindow==(mode~='expired'))
 if mode=='distance' then assert(w.distanceSquared==9 and d.collectorPosition.x==3 and w.position.x==0) end
 w.position.x=999;assert(p.Read(8,'diagnostic').candidateDiagnostics.watches[1].position.x==0)
end
