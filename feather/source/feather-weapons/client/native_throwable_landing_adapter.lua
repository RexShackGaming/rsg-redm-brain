-- Concrete native ports, staged and not automatically constructed. Decorators
-- establish continuity AFTER capture, never original paid/projectile ownership.
WeaponNativeThrowableLandingAdapter={}
local marker='fw_throw_capture_v1'
local issued=0
local function yes(v) return v==true or v==1 end
local function uint(v) return v & 0xffffffff end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowableLandingAdapter.New(world,authorize,freshCandidate)
 assert(callable(world) and callable(authorize) and callable(freshCandidate),'Landing world/cleanup/freshness authority required')
 if not yes(DecorIsRegisteredAsType(marker,3)) then DecorRegister(marker,3) end
 assert(yes(DecorIsRegisteredAsType(marker,3)),'landing_marker_unavailable')
 local captured,attempted,lastReject,proposal=nil,false,nil,nil
 local function reject(reason) lastReject=reason;return false end
 local function fingerprint(entity)
  if type(entity)~='number' or entity<=0 or not yes(DoesEntityExist(entity)) then return nil end
  local model=uint(GetEntityModel(entity))
  if model~=uint(joaat('w_melee_tomahawk01')) and model~=uint(joaat('w_melee_tomahawk02')) then return nil end
  local networked=yes(NetworkGetEntityIsNetworked(entity))
  local net=networked and NetworkGetNetworkIdFromEntity(entity) or nil
  if networked and (type(net)~='number' or net<=0 or net%1~=0) then return nil end
  return {entity=entity,model=model,networked=networked,networkId=net}
 end
 local function matches(object)
  if not captured or type(object)~='table' or object.captureToken~=captured.captureToken
   or object.entity~=captured.entity then return reject('capture_identity_changed') end
  local f=fingerprint(object.entity)
  if not f then return reject('entity_or_model_unavailable') end
  if f.model~=captured.model or f.networked~=captured.networked or f.networkId~=captured.networkId then
   return reject('network_fingerprint_changed') end
  if not yes(DecorExistOn(object.entity,marker)) then return reject('capture_marker_missing') end
  if DecorGetInt(object.entity,marker)~=captured.marker then return reject('capture_marker_changed') end
  return true
 end
 local function controlled(entity)
  return not yes(NetworkGetEntityIsNetworked(entity)) or yes(NetworkHasControlOfEntity(entity))
 end
 local ports={world=world,now=function() return GetGameTimer()%4294967296 end,
  candidate=function(identity)
   if captured then return nil end
   local fresh=freshCandidate(identity)
   if type(fresh)~='table' then return nil end
   -- Only the targeted ownedOnly lookup; no broad object scan or unowned fallback.
   local found,_,entity=GetProjectileOfProjectileTypeWithinDistance(identity.ped,
    joaat('WEAPON_THROWN_TOMAHAWK'),50.0,false,true)
   if not yes(found) then return nil end
   local f=fingerprint(entity)
   if not f or f.entity~=fresh.entity or f.model~=fresh.model or f.networked~=fresh.networked
    or f.networkId~=fresh.networkId then lastReject='fresh_candidate_changed';return nil end
   if not controlled(entity) then lastReject='candidate_control_missing';return nil end
   if yes(DecorExistOn(entity,marker)) then lastReject='candidate_already_marked';return nil end
   assert(issued<2147483647,'landing_marker_exhausted');issued=issued+1
   -- Reserve before stamping: a failed/readback-unknown marker cannot be adopted.
   captured=f;captured.marker=issued;captured.captureToken=marker..':'..issued
   assert(yes(DecorSetInt(entity,marker,issued)) and matches(captured),'landing_marker_write_unconfirmed')
   return {entity=f.entity,model=f.model,networked=f.networked,networkId=f.networkId,captureToken=f.captureToken}
  end,
  read=function(object)
   if not matches(object) then return nil end
   local position=GetEntityCoords(object.entity)
   local attached=yes(IsEntityAttached(object.entity))
   local sample={entity=object.entity,model=captured.model,networked=captured.networked,networkId=captured.networkId,
    captureToken=captured.captureToken,position={x=position.x,y=position.y,z=position.z},
    speed=GetEntitySpeed(object.entity),attached=attached,
    attachmentParent=attached and GetEntityAttachedTo(object.entity) or nil}
   if not matches(object) then return nil end
   return sample
  end,
  proposeTransition=function(state)
   -- Never hand off merely because the marker/model changed on a live handle.
   if yes(DoesEntityExist(captured.entity)) then error('original_projectile_still_exists') end
   if not state.position then return nil end
   local p=state.position;local candidates={};local seen={}
   for _,name in ipairs({'w_melee_tomahawk01','w_melee_tomahawk02'}) do
    local entity=GetClosestObjectOfType(p.x,p.y,p.z,1.5,joaat(name),false,false,false)
    if type(entity)=='number' and entity>0 and entity~=captured.entity and not seen[entity] then
     local f=fingerprint(entity)
     if f and f.networked and f.networkId~=captured.networkId and controlled(entity)
      and not yes(DecorExistOn(entity,marker)) then candidates[#candidates+1]=f;seen[entity]=true end
    end
   end
   if #candidates>1 then error('multiple_landed_pickup_candidates') end
   if #candidates==0 then return nil end
   proposal={original=captured,pickup=candidates[1]}
   return {projectileNetworkId=captured.networkId,pickupNetworkId=proposal.pickup.networkId}
  end,
  acceptTransition=function(approval,state)
   if not proposal or approval.projectileNetworkId~=proposal.original.networkId
    or approval.pickupNetworkId~=proposal.pickup.networkId or yes(DoesEntityExist(proposal.original.entity)) then return nil end
   local f=fingerprint(proposal.pickup.entity);local old=proposal.pickup
   if not f or f.model~=old.model or f.networkId~=old.networkId or not f.networked
    or not controlled(f.entity) or yes(DecorExistOn(f.entity,marker)) then return nil end
   local p=GetEntityCoords(f.entity);local q=state.position
   if not q or (p.x-q.x)^2+(p.y-q.y)^2+(p.z-q.z)^2>2.25 then return nil end
   assert(issued<2147483647,'landing_marker_exhausted');issued=issued+1
   captured=f;captured.marker=issued;captured.captureToken=marker..':'..issued
   assert(yes(DecorSetInt(f.entity,marker,issued)) and matches(captured),'pickup_marker_write_unconfirmed')
   lastReject=nil
   return {entity=f.entity,model=f.model,networked=f.networked,networkId=f.networkId,captureToken=f.captureToken}
  end,
  authorizeCleanup=function(state)
   return matches(state.object) and controlled(state.object.entity) and authorize(state)==true
  end,
  remove=function(object)
   if attempted then return reject('cleanup_already_attempted') end
   if not matches(object) then return false end
   if not controlled(object.entity) then return reject('cleanup_control_missing') end
   attempted=true
   -- No mission-entity adoption or network control requests. Existing local
   -- control + independent challenge authorization are both mandatory.
   DeleteObject(object.entity)
   if yes(DoesEntityExist(object.entity)) then return reject('deleted_object_still_exists') end
   return true
  end,
  diagnostic=function() return {lastReject=lastReject,removeAttempted=attempted} end,
  absent=function(object)
   -- A reused handle is not positive absence; retain uncertainty in that case.
   return captured and object.entity==captured.entity and not yes(DoesEntityExist(object.entity))
  end}
 return WeaponNativeThrowableLandingCapture.New(ports)
end
-- Isolated-loan diagnostic ONLY. It never supplies a candidate to gameplay and
-- never transfers a marker/authority to an observed replacement entity.
function WeaponNativeThrowableLandingAdapter.Survey(prior,current,wait,now,observed)
 local report={surveyVersion=2,noWrites=true,originConfirmed=false,observations={},readFailures=0,closestReads=0}
 if type(prior)~='table' or type(prior.object)~='table' then return report end
 local original=prior.object;local started=now();local seen={}
 local function record(kind,entity)
  if #report.observations>=6 or type(entity)~='number' or entity<=0 then return end
  local exists=yes(DoesEntityExist(entity));local model=exists and uint(GetEntityModel(entity)) or nil
  local net=exists and yes(NetworkGetEntityIsNetworked(entity)) and NetworkGetNetworkIdFromEntity(entity) or nil
  local stamped=exists and yes(DecorExistOn(entity,marker)) and DecorGetInt(entity,marker) or nil
  local key=kind..':'..entity..':'..tostring(exists)..':'..tostring(model)..':'..tostring(net)..':'..tostring(stamped)
  if seen[key] then return end;seen[key]=true
  local row={kind=kind,elapsedMs=(now()-started)%4294967296,
   entity=entity,exists=exists,model=model,networkId=net,marker=stamped}
  report.observations[#report.observations+1]=row
  -- Notify immediately while the released test remains reserved. Waiting until
  -- the whole survey returns can suppress server delayed native-read samples.
  if observed and kind=='closest_at_landing' and exists and net then
   local ok=pcall(observed,{kind=kind,entity=entity,exists=exists,model=model,networkId=net})
   if not ok then report.hintDeliveryFailed=true end
  end
 end
 local delays={100,150,250,500}
 for index=1,5 do
  if not current() then report.contextChanged=true;break end
  local ok=pcall(function()
   record('original',original.entity)
   local identity=prior.identity
   if identity and identity.ped then
    local found,_,entity=GetProjectileOfProjectileTypeWithinDistance(identity.ped,joaat('WEAPON_THROWN_TOMAHAWK'),50.0,false,true)
    if yes(found) then record('owned_lookup',entity) end
   end
   if original.networkId and type(NetworkGetEntityFromNetworkId)=='function' then
    if type(NetworkDoesNetworkIdExist)=='function' and not yes(NetworkDoesNetworkIdExist(original.networkId)) then
     report.originalNetworkMissing=true
    else record('network_lookup',NetworkGetEntityFromNetworkId(original.networkId)) end
   end
   -- Targeted spatial reads bypass the partial CObject list. Both native model
   -- queries include local/network/script objects; results remain evidence only.
   if prior.position and type(GetClosestObjectOfType)=='function' then
    local p=prior.position
    for _,name in ipairs({'w_melee_tomahawk01','w_melee_tomahawk02'}) do
     report.closestReads=report.closestReads+1
     local entity=GetClosestObjectOfType(p.x,p.y,p.z,3.0,joaat(name),false,false,false)
     if type(entity)=='number' and entity>0 and yes(DoesEntityExist(entity))
      and uint(GetEntityModel(entity))==uint(joaat(name)) then
      record('closest_at_landing',entity)
     end
    end
   end
  end)
  if not ok then report.readFailures=report.readFailures+1 end
  if delays[index] then wait(delays[index]) end
 end
 return report
end
