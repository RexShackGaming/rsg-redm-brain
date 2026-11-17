-- Staged server-observed lifetime linker; no event registration/native writes.
-- RDR3 Pickup models are not readable server-side. This does NOT claim engine
-- origin proof: economic authority is an exact canonical paid-spend receipt.
WeaponNativeThrowableTransitionBinding={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function equal(a,b)
 if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function same(a,b) return type(a)=='table' and type(b)=='table' and a.characterId==b.characterId
 and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function int(v,min) return type(v)=='number' and v>=min and v<math.huge and v%1==0 end
local function text(v) return type(v)=='string' and #v>0 and #v<=128 and not v:find('%c') end
function WeaponNativeThrowableTransitionBinding.New(api)
 local lives,byNet,reserved,paid={}, {},{},{}
 local serial,count,pending=0,0,0
 local creating={}
 local diagnostics={creationEvents=0,registered=0,deferred=0,readErrors=0}
 local T={}
 local function captureCreated(handle,createdAt)
  if not int(handle,1) or count>=256 then return false end
  local row=api.read(handle)
  if type(row)~='table' or row.exists~=true then return false,'entity_not_ready' end
  if row.netType~=8 and row.netType~=23 then return false,'irrelevant_entity_type' end
  if not int(row.networkId,1) or not int(row.owner,1) or not int(row.bucket,0) then return false,'native_identity_not_ready' end
  local actor=api.actor(row.owner)
  if not actor or actor.alive~=true or not text(actor.characterId) or not text(actor.sessionId)
   or not text(actor.epoch) or actor.bucket~=row.bucket then return false,'actor_scope_not_ready' end
  -- Only actual entityCreated calls can populate this store. Hint lookup never
  -- manufactures creation history. Network ID reuse remains ambiguous.
  serial=serial+1;count=count+1
  local life={id=serial,handle=handle,networkId=row.networkId,netType=row.netType,owner=row.owner,bucket=row.bucket,
   identity={characterId=actor.characterId,sessionId=actor.sessionId,epoch=actor.epoch},created=createdAt}
  lives[handle]=life
  byNet[row.networkId]=byNet[row.networkId] or {}
  table.insert(byNet[row.networkId],life)
  diagnostics.registered=diagnostics.registered+1
  return true
 end
 function T.Created(handle)
  if not int(handle,1) or creating[handle] or count+pending>=256 then return false end
  diagnostics.creationEvents=diagnostics.creationEvents+1
  local preparation={created=api.now()};creating[handle]=preparation;pending=pending+1
  local function finish() if creating[handle]==preparation then creating[handle]=nil;pending=pending-1 end end
  local function attempt(final)
   if creating[handle]~=preparation then return false end
   local ok,result,reason=pcall(captureCreated,handle,preparation.created)
   if ok and result==true then
    if preparation.removed and lives[handle] then lives[handle].removed=preparation.removed end
    finish();return true
   end
   if not ok then diagnostics.readErrors=diagnostics.readErrors+1;diagnostics.lastReadError=tostring(result):sub(1,384) end
   diagnostics.lastCreationReason=ok and reason or 'native_read_exception'
   if final or not ok or reason=='irrelevant_entity_type' then finish() end
   return false
  end
  local ready=attempt(not api.later)
  if creating[handle]==preparation and api.later then
   diagnostics.deferred=diagnostics.deferred+1
   api.later(100,function() attempt(false) end)
   api.later(500,function() attempt(true) end)
  end
  return ready
 end
 function T.Removed(handle)
  if creating[handle] then creating[handle].removed=api.now() end
  local life=lives[handle];if life then life.removed=api.now() end
 end
 local function unique(net)
  local rows=byNet[net];return rows and #rows==1 and rows[1] or nil
 end
 local function eligible(pickup,projectile)
  return pickup.netType==8 and pickup.owner==projectile.owner and pickup.bucket==projectile.bucket
   and same(pickup.identity,projectile.identity) and not pickup.removed
   and (pickup.created-projectile.created)%4294967296<=3000
   and (pickup.created-projectile.created)%4294967296<=(projectile.removed-projectile.created)%4294967296+1500
 end
 local function candidateCount(projectile)
  local n=0;for _,rows in pairs(byNet) do for _,life in ipairs(rows) do
   if eligible(life,projectile) then n=n+1 end
  end end;return n
 end
 function T.Link(source,challengeId,projectileId,pickupId)
  if not int(source,1) or not text(challengeId) or not int(projectileId,1) or not int(pickupId,1) then return {phase='refused'} end
  local projectile,pickup=unique(projectileId),unique(pickupId)
  if byNet[projectileId] and #byNet[projectileId]~=1 or byNet[pickupId] and #byNet[pickupId]~=1 then
   return {phase='refused',reason='reused_network_lifetime'} end
  if not projectile or not pickup then return {phase='pending',reason='creation_callback_not_ready'} end
  if projectile.netType~=23 or pickup.netType~=8 then return {phase='refused',reason='transition_type_mismatch'} end
  if projectile.owner~=source or pickup.owner~=source then return {phase='refused',reason='transition_owner_mismatch'} end
  if not projectile.removed then return {phase='pending',reason='projectile_removal_not_ready'} end
  if not eligible(pickup,projectile) then return {phase='refused',reason='transition_scope_or_time_mismatch'} end
  if candidateCount(projectile)~=1 then return {phase='refused',reason='ambiguous_pickup_lifetime'} end
  if reserved[pickup.id] then return {phase='pending'} end
  local reservation={};reserved[pickup.id]=reservation
  local paidKey
  local function deny(reason)
   reserved[pickup.id]=nil;if paidKey and paid[paidKey]==reservation then paid[paidKey]=nil end
   return {phase='refused',reason=reason}
  end
  local ok,challenge,spend=pcall(function()
   local c=api.challenge(source,challengeId)
   if not c or type(c.units)~='table' or #c.units~=1 then return nil end
   return c,api.spend(source,c.operationId,c.units[1].itemId)
  end)
  local actor=api.actor(source)
  if not ok or not challenge or not same(actor,projectile.identity) or actor.alive~=true
   or not same(challenge.identity,projectile.identity) or type(spend)~='table' or spend.custody~='spent'
   or spend.operationId~=challenge.operationId or not same(spend.origin,projectile.identity)
   or not int(spend.itemId,1) or not int(spend.itemRevision,0)
   or spend.itemId~=challenge.units[1].itemId or spend.itemRevision~=challenge.units[1].itemRevision
   or type(spend.metadata)~='table' or spend.metadata.weaponDefinitionId~='throwable_tomahawk'
   or not text(spend.metadata.serialNumber) then return deny('canonical_paid_spend_required') end
  local key=spend.itemId..':'..spend.itemRevision
  if paid[key] then return deny('paid_unit_already_linked') end
  paidKey=key;paid[key]=reservation -- before the final yielding receipt recheck
  local proof={kind=api.synthetic==true and 'synthetic_throwable_transition' or 'paid_throwable_transition',identity=copy(projectile.identity),source=source,challengeId=challengeId,
   projectileLifetime=projectile.id,pickupLifetime=pickup.id,pickupNetworkId=pickupId,itemId=spend.itemId,itemRevision=spend.itemRevision,
   metadata=copy(spend.metadata),originConfirmed=false,serverModelReadable=false,
   economicAuthority=api.synthetic==true and 'isolated_native_fixture' or 'canonical_paid_spend'}
  local authorityStarted=type(challenge.started)=='number' and challenge.started or api.now()
  local function current(absent,collectorSource,awaitRemoval,transactionGuard)
   local function reject(why)
    if collectorSource then diagnostics.collectionRejection=why end
    return false
   end
   if collectorSource then diagnostics.collectionRejection=nil end
   local a=api.actor(source)
   if not same(a,proof.identity) or a.alive~=true or a.bucket~=pickup.bucket or reserved[pickup.id]~=reservation
    or unique(pickupId)~=pickup then return reject('origin_scope_or_lifetime_changed') end
   if absent then
    if not pickup.removed or candidateCount(projectile)~=0 then return reject('removal_callback_not_ready') end
   elseif awaitRemoval==true then
    local candidates=candidateCount(projectile)
    if pickup.removed and candidates~=0 or not pickup.removed and candidates~=1 then return reject('pickup_candidates_changed') end
   elseif pickup.removed or candidateCount(projectile)~=1 then return reject('pickup_callback_state_changed') end
   local row=api.read(pickup.handle)
   if collectorSource then
    diagnostics.collectionRead={exists=row and row.exists,networkId=row and row.networkId,netType=row and row.netType,
     owner=row and row.owner,bucket=row and row.bucket,removalCallbackObserved=pickup.removed~=nil,
     awaitingRemoval=awaitRemoval==true,nativeAbsent=row~=nil and row.exists==false}
   end
   local collector=collectorSource and api.actor(collectorSource)
   if collectorSource and (not int(collectorSource,1) or not collector or collector.alive~=true or collector.bucket~=pickup.bucket) then return reject('collector_scope_changed') end
   if absent then
    if not row or row.exists~=false then return reject('native_absence_not_ready') end
   elseif row and row.exists==false and awaitRemoval==true then
    -- Read-only observation can wait for entityRemoved after native absence.
    -- The strict absence branch above still requires the callback and unique
    -- registered generation; this branch grants no cleanup/claim authority.
   elseif not row or row.exists~=true or row.netType~=8 or row.networkId~=pickupId
    or (row.owner~=source and (not collectorSource or row.owner~=collectorSource)) or row.bucket~=pickup.bucket then return reject('native_pickup_readback_changed') end
   if transactionGuard then
    -- Only the paid binding/claim transaction may use this continuation guard.
    -- Its own tx connection rereads/locks the exact paid receipt and metadata.
    -- Reopening receipt transactions here multiplies I/O at every write guard.
    return api.synthetic~=true and (api.now()-authorityStarted)%4294967296<90000
   end
   local c=api.challenge(source,challengeId)
   if not c or not same(c.identity,proof.identity) or c.operationId~=spend.operationId
    or type(c.units)~='table' or #c.units~=1 or c.units[1].itemId~=spend.itemId or c.units[1].itemRevision~=spend.itemRevision then return reject('challenge_changed') end
   if not equal(api.spend(source,spend.operationId,spend.itemId),spend) then return reject('canonical_spend_changed') end
   return true
  end
  local checked,valid=pcall(current)
  if not checked or valid~=true then return deny('transition_authority_changed') end
  paid[key]=reservation;reservation.proof=copy(proof);reservation.current=current
  return {phase='linked',proof=copy(proof)}
 end
 function T.Current(proof)
  if type(proof)~='table' then return false end
  local reservation=reserved[proof.pickupLifetime]
  if not reservation or not equal(proof,reservation.proof) then return false end
  local ok,value=pcall(reservation.current);return ok and value==true
 end
 function T.Absent(proof)
  if type(proof)~='table' then return false end
  local reservation=reserved[proof.pickupLifetime]
  if not reservation or not equal(proof,reservation.proof) then return false end
  local ok,value=pcall(reservation.current,true);return ok and value==true
 end
 function T.GuardAbsent(proof)
  if type(proof)~='table' or proof.kind~='paid_throwable_transition' then return false end
  local reservation=reserved[proof.pickupLifetime]
  if not reservation or not equal(proof,reservation.proof) then return false end
  local ok,value=pcall(reservation.current,true,nil,nil,true)
  return ok and value==true
 end
 -- Read-only collection continuity may follow migration to the designated
 -- collector. This never relaxes Current(), which authorizes exact cleanup.
 function T.CollectionPresent(proof,collectorSource)
  if type(proof)~='table' or not int(collectorSource,1) then return false end
  local reservation=reserved[proof.pickupLifetime]
  if not reservation or not equal(proof,reservation.proof) then return false end
  local ok,value=pcall(reservation.current,false,collectorSource);return ok and value==true
 end
 function T.CollectionPending(proof,collectorSource)
  if type(proof)~='table' or not int(collectorSource,1) then return false end
  local reservation=reserved[proof.pickupLifetime]
  if not reservation or not equal(proof,reservation.proof) then return false end
  local ok,value=pcall(reservation.current,false,collectorSource,true);return ok and value==true
 end
 function T.Diagnostics(projectileId,pickupId)
  local result=copy(diagnostics);result.pendingCreations=pending
  local function snapshot(id)
   local rows=byNet[id];if not rows then return {generations=0} end
   local life=rows[#rows]
   return {generations=#rows,networkId=life.networkId,netType=life.netType,owner=life.owner,bucket=life.bucket,
    created=life.created,removed=life.removed}
  end
  result.projectile=snapshot(projectileId);result.pickup=snapshot(pickupId);return result
 end
 -- Synthetic negative-test cleanup only. This cannot attribute a paid item or
 -- authorize deletion. Every registered test lifetime must already be absent.
 function T.SyntheticBatchAbsent(source,expected,projectileHints,pickupHints)
  if api.synthetic~=true or not int(source,1) or expected~=2 or pending~=0 or diagnostics.readErrors~=0 then return false end
  if type(projectileHints)~='table' or type(pickupHints)~='table' then return false end
  local actor=api.actor(source)
  if not actor or actor.alive~=true then return false end
  local projectiles,pickups=0,0
  for _,life in pairs(lives) do
   if life.owner~=source or life.bucket~=actor.bucket or not same(life.identity,actor)
    or not life.removed or not unique(life.networkId) then return false end
   local ok,row=pcall(api.read,life.handle)
   if not ok or not row or row.exists~=false then return false end
   if life.netType==23 then
    if projectileHints[life.networkId]~=true then return false end
    projectiles=projectiles+1
   else
    if type(pickupHints[life.networkId])~='table' then return false end
    pickups=pickups+1
   end
  end
  local final=api.actor(source)
  return projectiles==expected and pickups==expected and diagnostics.registered==expected*2 and pending==0
   and final and final.alive==true and final.bucket==actor.bucket and same(final,actor) or false
 end
 return T
end
