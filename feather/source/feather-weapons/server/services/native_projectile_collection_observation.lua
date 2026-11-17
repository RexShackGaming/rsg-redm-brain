-- Staged read-only correlation. No routes, grants, claims or native mutations.
-- A collection event is a client observation, not proof of economic ownership.
-- Ports must bind Watch to an existing server-authorized transition lifetime.
WeaponNativeProjectileCollectionObservation={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function same(a,b) return type(a)=='table' and type(b)=='table' and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function int(v,min) return type(v)=='number' and v>=min and v<math.huge and v%1==0 end
local function text(v) return type(v)=='string' and #v>0 and #v<=128 and not v:find('%c') end
local function identity(v) return type(v)=='table' and text(v.characterId) and text(v.sessionId) and text(v.epoch) end
local function pos(v)
 if type(v)~='table' then return false end
 for _,k in ipairs({'x','y','z'}) do if type(v[k])~='number' or v[k]~=v[k] or math.abs(v[k])>10000000 then return false end end
 return true
end
local function distance(a,b) return (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2 end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeProjectileCollectionObservation.New(api)
 for _,k in ipairs({'now','actor','current','absent'}) do assert(callable(api[k]),'Collection observation port required: '..k) end
 local watches,items,nets,observations={},{},{},{}
 local count,events,busy=0,0,false
 local watchMs=api.watchMs==180000 and 180000 or 120000
 local P={}
 local function result(phase,reason)
  return {phase=phase,reason=reason,originConfirmed=false,pickupCredits=false,economicWrites=0,canClaim=false}
 end
 function P.Watch(id,proof,position,bucket)
  if busy or not text(id) or watches[id] or count>=64 or type(proof)~='table' or not identity(proof.identity)
   or not int(proof.itemId,1) or not int(proof.itemRevision,0) or not int(proof.pickupLifetime,1)
   or not int(proof.pickupNetworkId,1) or not pos(position) or not int(bucket,0)
   or (proof.kind~='paid_throwable_transition' and proof.kind~='synthetic_throwable_transition') then return result('refused','invalid_watch') end
  local key=proof.itemId..':'..proof.itemRevision
  if items[key] or nets[proof.pickupNetworkId] then return result('refused','duplicate_lifetime_or_unit') end
  -- Reserve before potentially yielding proof validation. No caller-selected
  -- item, position, event handle or nearest object bypasses that validation.
  busy=true
  local ok,valid=pcall(api.current,copy(proof))
  busy=false
  if not ok or valid~=true then return result('refused','transition_not_current') end
  watches[id]={proof=copy(proof),position=copy(position),bucket=bucket,started=api.now()}
  items[key]=id;nets[proof.pickupNetworkId]=id;count=count+1
  return result('watching')
 end
 local function evaluate(s)
  local actor=api.actor(s.source)
  -- Retain the actual filter inputs, including rejected watches. A missing
  -- candidate must not conceal whether distance, bucket or age rejected it.
  local diagnostic={version=1,source=s.source,receivedPosition=copy(s.position),
   collectorPosition=actor and copy(actor.position),receivedBucket=s.bucket,
   collectorBucket=actor and actor.bucket,maximumDistanceSquared=4,
   maximumWatchAgeMs=watchMs,watches={},candidateCount=0}
  local function outcome(phase,reason)
   local out=result(phase,reason);out.candidateDiagnostics=copy(diagnostic);return out
  end
  if not identity(actor) or not same(actor,s.identity) or actor.alive~=true or actor.bucket~=s.bucket
   or not pos(actor.position) or distance(actor.position,s.position)>4 then return outcome('review_required','collector_scope_changed') end
  if (api.now()-s.received)%4294967296>750 then return outcome('review_required','collection_window_expired') end
  local candidates={}
  for id,w in pairs(watches) do
   -- Include all nearby watched lifetimes, even already removed ones: removal
   -- cannot resolve two simultaneous native collection possibilities.
   local age=(api.now()-w.started)%4294967296
   local d=distance(actor.position,w.position)
   local accepted=w.bucket==actor.bucket and age<=watchMs and d<=4
   diagnostic.watches[#diagnostic.watches+1]={watchId=id,pickupNetworkId=w.proof.pickupNetworkId,
    pickupLifetime=w.proof.pickupLifetime,position=copy(w.position),bucket=w.bucket,
    ageMs=age,distanceSquared=d,bucketMatches=w.bucket==actor.bucket,
    withinWindow=age<=watchMs,withinDistance=d<=4,accepted=accepted}
   if accepted then candidates[#candidates+1]=id end
  end
  table.sort(diagnostic.watches,function(a,b) return a.watchId<b.watchId end)
  diagnostic.candidateCount=#candidates
  if #candidates~=1 then return outcome('review_required',#candidates==0 and 'no_bound_candidate' or 'ambiguous_bound_candidates') end
  local id=candidates[1];local w=watches[id]
  if s.candidate and s.candidate~=id then return outcome('review_required','candidate_changed') end
  s.candidate=id
  if w.observation and w.observation~=s.key then return outcome('review_required','lifetime_already_observed') end
  local absent=api.absent(copy(w.proof))
  if absent~=true then
   local present
   if callable(api.present) then present=api.present(copy(w.proof),s.source) else present=api.current(copy(w.proof)) end
   if present~=true then
    if callable(api.pending) and api.pending(copy(w.proof),s.source)==true then return outcome('pending','awaiting_lifetime_removal_settlement') end
    return outcome('review_required','transition_authority_changed')
   end
   return outcome('pending','awaiting_server_removal')
  end
  -- Recheck after yielding ports; a second watcher or moved collector changes
  -- the result. The caller may only retain diagnostic evidence, never credit.
  local a=api.actor(s.source)
  if not same(a,s.identity) or a.alive~=true or a.bucket~=s.bucket or not pos(a.position)
   or distance(a.position,w.position)>4 then return outcome('review_required','collector_scope_changed') end
  w.observation=s.key
  local out=outcome('correlated_observation','client_event_not_ownership_proof')
  out.watchId=id;out.itemId=w.proof.itemId;out.itemRevision=w.proof.itemRevision
  out.pickupNetworkId=w.proof.pickupNetworkId;out.pickupLifetime=w.proof.pickupLifetime
  out.origin=copy(w.proof.identity);out.collector=copy(s.identity)
  return out
 end
 function P.Observe(source,id,event)
  if busy or not int(source,1) or not text(id) or type(event)~='table' then return result('refused','invalid_observation') end
  local key=source..':'..id
  if observations[key] then return result('refused','duplicate_observation_use_read') end
  -- Current live evidence supports AI collection only. Network handle semantics
  -- and any future arrows require their own explicit profile, not guessed slots.
  local raw=event.rawSlots
  if events>=128 or event.referenceBuild~=1491 or event.queue~=0 or event.eventHash~=-178091376
   or event.kind~='ai_pickup' or type(raw)~='table' or #raw~=8
   or not int(event.localPlayerIndex,0) or event.localPlayerIndex>255 or event.nativeTomahawkQuantity~=1 then return result('refused','unsupported_collection_observation') end
  for k,v in pairs(raw) do if not int(k,1) or k>8 or not int(v,-2147483648) or v>2147483647 then return result('refused','invalid_event_slots') end end
  if (raw[1]&0xffffffff)~=3397143806 or raw[2]~=1 or raw[3]~=event.localPlayerIndex
   or (raw[4]&0xffffffff)~=3358573347 or raw[7]~=1 or (raw[8]&0xffffffff)~=2783539927 then return result('refused','collection_profile_mismatch') end
  busy=true
  local ok,out=pcall(function()
   local a=api.actor(source)
   if not identity(a) or a.alive~=true or not int(a.bucket,0) or not pos(a.position) then return result('refused','collector_unavailable') end
   local s={source=source,key=key,identity={characterId=a.characterId,sessionId=a.sessionId,epoch=a.epoch},bucket=a.bucket,
    position=copy(a.position),received=api.now()}
   observations[key]=s;events=events+1
   s.result=evaluate(s);return copy(s.result)
  end)
  busy=false
  return ok and out or result('review_required','collection_read_unavailable')
 end
 function P.Read(source,id)
  if not int(source,1) or not text(id) then return result('refused','invalid_read') end
  if busy then return result('pending','observation_read_in_flight') end
  local s=observations[source..':'..id]
  if not s then return result('refused','observation_not_found') end
  local checked,actor=pcall(api.actor,source)
  if not checked or not same(actor,s.identity) then return result('refused','collector_scope_changed') end
  if s.result and s.result.phase~='pending' then return copy(s.result) end
  busy=true;local ok,out=pcall(evaluate,s);busy=false
  s.result=ok and out or result('review_required','collection_read_unavailable')
  return copy(s.result)
 end
 return P
end
