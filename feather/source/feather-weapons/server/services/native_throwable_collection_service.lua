-- Paid composition factory only. No routes, threads or Inventory/native writes
-- on load. Unlike the acceptance probe, all spend/challenge ports are real paid
-- authorities and synthetic proofs are rejected before a handoff can begin.
WeaponNativeThrowableCollectionService={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function equal(a,b)
 if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function same(a,b) return type(a)=='table' and type(b)=='table' and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function pos(v)
 if type(v)~='table' then return false end
 for _,k in ipairs({'x','y','z'}) do local n=v[k];if type(n)~='number' or n~=n or math.abs(n)>10000000 then return false end end
 return true
end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowableCollectionService.New(api)
 for _,k in ipairs({'now','actor','read','challenge','spend','newId','collectorEmpty','ticket','beginEscrow','readEscrow','bind','readBinding','claim','readClaim'}) do
  assert(type(api)=='table' and callable(api[k]),'Paid collection service port required: '..k)
 end
 local binding=WeaponNativeThrowableTransitionBinding.New({now=api.now,later=api.later,actor=api.actor,
  read=api.read,challenge=api.challenge,spend=api.spend})
 local observer=WeaponNativeProjectileCollectionObservation.New({now=api.now,actor=api.actor,current=binding.Current,
  absent=binding.Absent,present=binding.CollectionPresent,pending=binding.CollectionPending})
 local watches,authorized,received,writing={},{},{},{}
 local registering=false
 local S={Created=binding.Created,Removed=binding.Removed}
 function S.Prepare(source,id)
  local w=watches[id]
  local actor=api.actor(source)
  if not w or not actor or actor.alive~=true or actor.bucket~=w.bucket or not pos(actor.position)
   or binding.Current(w.proof)~=true or api.collectorEmpty(source,copy(actor))~=true
   or (actor.position.x-w.position.x)^2+(actor.position.y-w.position.y)^2+(actor.position.z-w.position.z)^2>2500 then return nil end
  local after=api.actor(source)
  if not same(actor,after) or after.alive~=true or after.bucket~=w.bucket then return nil end
  return {identity={characterId=actor.characterId,sessionId=actor.sessionId,epoch=actor.epoch},bucket=w.bucket}
 end
 function S.Watch(source,challengeId,projectileId,pickupId,position)
  if registering or not pos(position) then return {phase='refused',reason='invalid_watch'} end
  registering=true
  local ok,result=pcall(function()
   local linked=binding.Link(source,challengeId,projectileId,pickupId)
   if linked.phase~='linked' then return linked end
   local proof=linked.proof
   if proof.kind~='paid_throwable_transition' or proof.economicAuthority~='canonical_paid_spend' then
    return {phase='refused',reason='paid_transition_required'}
   end
   local actor=api.actor(source)
   local challenge=api.challenge(source,challengeId)
   if not same(actor,proof.identity) or actor.alive~=true or not challenge or not pos(actor.position)
    or (actor.position.x-position.x)^2+(actor.position.y-position.y)^2+(actor.position.z-position.z)^2>2500 then
    return {phase='review_required',reason='paid_watch_scope_changed'}
   end
   local id=api.newId()
   if type(id)~='string' or #id<1 or #id>64 or id:find('%c') or watches[id] then
    return {phase='review_required',reason='paid_watch_id_unavailable'}
   end
   local watched=observer.Watch(id,proof,position,actor.bucket)
   if watched.phase~='watching' then return watched end
   watches[id]={proof=copy(proof),position=copy(position),bucket=actor.bucket,operationId=challenge.operationId}
   return {phase='watching',id=id}
  end)
  registering=false
  return ok and result or {phase='review_required',reason='paid_watch_unavailable'}
 end
 local function resolve(source,eventId)
  local key=source..':'..eventId
  if not received[key] or (api.now()-received[key])%4294967296>10000 then return nil end
  if authorized[key] then return copy(authorized[key]) end
  local event=observer.Read(source,eventId)
  if event.phase~='correlated_observation' then return nil end
  local w=watches[event.watchId]
  local actor=api.actor(source)
  if not w or not same(actor,event.collector) or actor.alive~=true or actor.bucket~=w.bucket
   or event.itemId~=w.proof.itemId or event.itemRevision~=w.proof.itemRevision
   or not same(event.origin,w.proof.identity) or binding.Absent(w.proof)~=true
   or api.collectorEmpty(source,copy(event.collector))~=true then return nil end
  local record={version=4,kind='paid_tomahawk_native_pickup',presentation='native',phase='available',
   pickupId=event.watchId,pickupRevision=0,id=event.watchId,revision=0,bucket=w.bucket,position=copy(w.position),
   origin=copy(w.proof.identity),originEventId=event.watchId,spendOperationId=w.operationId,
   itemId=w.proof.itemId,itemRevision=w.proof.itemRevision,metadata=copy(w.proof.metadata)}
  local value={kind='paid_native_collection',phase='correlated',collector=copy(event.collector),
   origin=copy(event.origin),originSource=w.proof.source,bucket=w.bucket,binding=record,watchId=event.watchId,eventId=eventId,source=source}
  -- No yielding port between the final recheck and retention. The handoff
  -- revalidates this exact retained record before every mutation boundary.
  local after=api.actor(source)
  if not same(after,event.collector) or after.alive~=true or after.bucket~=w.bucket then return nil end
  authorized[key]=copy(value);return value
 end
 local function current(value,identity)
  if type(value)~='table' or type(value.source)~='number' or type(value.eventId)~='string' then return false end
  local saved=authorized[value.source..':'..value.eventId]
  local w=saved and watches[saved.watchId]
  if not equal(value,saved) or not w or not same(identity,saved.collector)
   or binding.GuardAbsent(w.proof)~=true then return false end
  -- Recheck collector AFTER the yielding origin guard. One fresh medical read
  -- per actor suffices; canonical paid data is locked by the owning SQL tx.
  local actor=api.actor(value.source)
  if not same(actor,identity) or actor.alive~=true or actor.bucket~=w.bucket then return false end
  -- Empty-carry admission was read before escrow. Do not reenter Inventory's
  -- snapshot reader from inside its claim transaction; the v4 released plan
  -- and atomic ledger/item CAS enforce that zero baseline at commit instead.
  return true
 end
 local function persist(value,authority)
  local originSource=value.originSource
  if writing[originSource] then return {phase='refused'} end
  local reservation={record=copy(value.binding),current=authority}
  writing[originSource]=reservation -- before the cross-resource transaction can yield
  local ok,result=pcall(api.bind,copy(value),authority)
  if ok and equal(result,value.binding) then writing[originSource]=nil end
  -- Unknown write outcomes stay reserved; only receipt reads may settle them.
  -- The reservation never causes another mutation to be dispatched.
  if not ok then error('paid_native_binding_reply_unavailable') end
  return result
 end
 function S.ValidateBinding(originSource,record)
  local reservation=writing[originSource]
  if not reservation or not equal(record,reservation.record) then return false end
  local ok,value=pcall(reservation.current)
  return ok and value==true
 end
 local function readBinding(value)
  local result=api.readBinding(copy(value))
  local reservation=writing[value.originSource]
  if reservation and equal(result,reservation.record) and equal(result,value.binding) then
   writing[value.originSource]=nil -- confirmed receipt settles the writer; no replay
  end
  return result
 end
 local handoff=WeaponNativeThrowableCollectionHandoff.New({actor=api.actor,resolve=resolve,current=current,currentChecksActor=true,
  ticket=api.ticket,beginEscrow=api.beginEscrow,readEscrow=api.readEscrow,bind=persist,readBinding=readBinding,
  claim=api.claim,readClaim=api.readClaim})
 function S.Observe(source,eventId,event)
  local started=api.now()
  local result=observer.Observe(source,eventId,event)
  if result.phase=='pending' or result.phase=='correlated_observation' then received[source..':'..eventId]=started end
  return result
 end
 S.ReadObservation=observer.Read
 S.Begin=handoff.Begin
 S.Read=handoff.Read
 return S
end
