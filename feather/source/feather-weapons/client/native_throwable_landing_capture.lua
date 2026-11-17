-- Staged capture state machine. Candidate lookup is NOT paid ownership proof.
-- Cleanup requires an independent authorization port; no native deletion here.
WeaponNativeThrowableLandingCapture={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function same(a,b) return type(a)=='table' and type(b)=='table' and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch and a.ped==b.ped end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function pos(v) return type(v)=='table' and finite(v.x) and finite(v.y) and finite(v.z) end
local function distance(a,b) return (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2 end
local function exact(a,b) return type(a)=='table' and type(b)=='table' and a.entity==b.entity and a.model==b.model
 and a.networked==b.networked and a.networkId==b.networkId and a.captureToken==b.captureToken end
local function attachment(sample,state)
 if sample.attached==false then return {attached=false} end
 if sample.attached~=true or not state.transitioned then return nil,'unapproved_attachment' end
 local parent=sample.attachmentParent
 if not finite(parent) or parent<0 or parent%1~=0 then return nil,'pickup_attachment_unreadable' end
 return {attached=true,parent=parent} -- parent0 may represent an internal attachment
end
local function sameAttachment(a,b) return a and b and a.attached==b.attached and a.parent==b.parent end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowableLandingCapture.New(api)
 for _,key in ipairs({'world','now','candidate','read','authorizeCleanup','remove','absent'}) do
  assert(callable(api[key]),'Landing capture port required: '..key)
 end
 local state,busy=nil,false
 local C={}
 local function hold(reason) state.phase='review_required';state.reason=reason;return copy(state) end
 function C.BeginObservation()
  if state then return false end
  local world=api.world()
  if type(world)~='table' or world.alive~=true or not finite(world.ped) or world.ped<=0 then return false end
  -- No paid unit or cleanup authority exists yet. Preserve short-lived native
  -- continuity while the independent server spend transaction is outstanding.
  state={phase='capturing',identity=copy(world),started=api.now(),observationOnly=true}
  return true
 end
 function C.BindChallenge(challenge)
  if not state or busy or not state.observationOnly or state.phase=='review_required'
   or type(challenge)~='table' or type(challenge.id)~='string' or #challenge.id<1 or #challenge.id>64
   or type(challenge.units)~='table' or #challenge.units~=1 then return false end
  local w=api.world();local identity=challenge.identity
  if not same(w,state.identity) or w.alive~=true or type(identity)~='table'
   or w.characterId~=identity.characterId or w.sessionId~=identity.sessionId or w.epoch~=identity.epoch
   or (api.now()-state.started)%4294967296>=90000 then return false end
  state.id=challenge.id;state.unit=copy(challenge.units[1]);state.observationOnly=nil
  return true
 end
 function C.Start(challenge)
  if state then return false,'capture_already_reserved' end
  if type(challenge)~='table' or type(challenge.id)~='string' or #challenge.id<1 or #challenge.id>64
   or type(challenge.units)~='table' or #challenge.units~=1 then return false,'single_spend_required' end
  local world=api.world()
  local identity=challenge.identity
  if type(world)~='table' or type(identity)~='table' or world.characterId~=identity.characterId
   or world.sessionId~=identity.sessionId or world.epoch~=identity.epoch or world.alive~=true
   or not finite(world.ped) or world.ped<=0 then return false,'capture_owner_changed' end
  state={phase='capturing',id=challenge.id,identity=copy(world),started=api.now(),unit=copy(challenge.units[1])}
  return true
 end
 function C.Tick()
  if not state or busy or state.phase~='capturing' then return state and copy(state) end
  busy=true
  local ok,result=pcall(function()
   local world=api.world();local now=api.now()
   if not same(world,state.identity) or world.alive~=true then return hold('capture_owner_changed') end
   if (now-state.started)%4294967296>=90000 then return hold('landing_timeout') end
   if not state.object then
    local candidate=api.candidate(copy(state.identity))
    if not candidate then return copy(state) end
    if type(candidate)~='table' or not finite(candidate.entity) or candidate.entity<=0
     or (candidate.model~=3358573347 and candidate.model~=joaat('w_melee_tomahawk02')%4294967296)
     or type(candidate.captureToken)~='string' or #candidate.captureToken==0 then return hold('candidate_unverified') end
    state.object=copy(candidate)
   end
   local sample=api.read(copy(state.object))
   state.lastSample=type(sample)=='table' and copy(sample) or nil
   local after=api.world()
   if not same(after,state.identity) or after.alive~=true then return hold('capture_owner_changed') end
   if sample==nil and not state.transitioned and api.proposeTransition then
    state.transitionStarted=state.transitionStarted or now
    if (now-state.transitionStarted)%4294967296>3000 then return hold('pickup_transition_timeout') end
    local proposal=api.proposeTransition(copy(state))
    if proposal then
     state.transitionProposal=copy(proposal);state.phase='transition_pending'
    end
    return copy(state)
   end
   if not exact(sample,state.object) or not pos(sample.position) or not finite(sample.speed)
    or sample.speed<0 then return hold('tracked_object_changed') end
   local attached,reason=attachment(sample,state)
   if not attached then return hold(reason) end
   if state.attachment and not sameAttachment(state.attachment,attached) then state.stableSince=nil;state.stableOrigin=nil end
   state.attachment=attached
   if not pos(world.position) or distance(world.position,sample.position)>2500 then return hold('landing_out_of_range') end
   if sample.speed>0.1 or state.stableOrigin and distance(state.stableOrigin,sample.position)>0.0025 then
    state.stableSince=nil;state.stableOrigin=nil;state.position=copy(sample.position);return copy(state)
   end
   state.position=copy(sample.position);state.stableSince=state.stableSince or now
   state.stableOrigin=state.stableOrigin or copy(sample.position)
   if (now-state.stableSince)%4294967296>=750 then state.phase='landed' end
   return copy(state)
  end)
  busy=false
  if not ok then state.detail=tostring(result):sub(1,384);return hold('capture_read_failed') end
  return result
 end
 function C.AcceptTransition(approval)
  if not state or busy or state.observationOnly or state.phase~='transition_pending' or not api.acceptTransition
   or type(approval)~='table' or type(approval.transitionToken)~='string' or #approval.transitionToken==0
   or approval.id~=state.id or approval.projectileNetworkId~=state.transitionProposal.projectileNetworkId
   or approval.pickupNetworkId~=state.transitionProposal.pickupNetworkId then return false end
  busy=true;state.phase='adopting_transition'
  local ok,result=pcall(function()
   local w=api.world();if not same(w,state.identity) or w.alive~=true then return nil end
   return api.acceptTransition(copy(approval),copy(state))
  end)
  busy=false
  if not ok or type(result)~='table' or type(result.captureToken)~='string' then
   if not ok then state.detail=tostring(result):sub(1,384) end
   hold('pickup_transition_unconfirmed');return false
  end
  state.originalObject=state.object;state.object=copy(result);state.transitioned=true
  state.transitionToken=approval.transitionToken;state.stableSince=nil;state.stableOrigin=nil
  state.attachment=nil
  state.position=nil;state.phase='capturing';return true
 end
 function C.Cleanup()
  if not state or busy or state.phase~='landed' or state.observationOnly then return false,'landing_required' end
  busy=true;state.phase='cleanup_pending'
  local ok,result=pcall(function()
   local world=api.world()
   if not same(world,state.identity) or world.alive~=true then return false end
   -- A matching handle/model alone never authorizes destruction.
   if api.authorizeCleanup(copy(state))~=true then return false end
   local sample=api.read(copy(state.object))
   if not exact(sample,state.object) or not pos(sample.position) or distance(sample.position,state.position)>0.0025
    or not finite(sample.speed) or sample.speed>0.1 then return false end
   if not sameAttachment(attachment(sample,state),state.attachment) then return false end
   world=api.world();if not same(world,state.identity) or world.alive~=true then return false end
   -- Reserve before a yielding native wrapper; uncertainty must not repeat it.
   state.removeAttempted=true
   if api.remove(copy(state.object))~=true then return false end
   return api.absent(copy(state.object))==true
  end)
  busy=false
  if not ok or result~=true then
   if not ok then state.detail=tostring(result):sub(1,384) end
   hold('original_cleanup_unconfirmed');return false,state.reason
  end
  state.phase='cleaned';return true,copy(state)
 end
 function C.Status()
  local view=state and copy(state) or {phase='idle'}
  if api.diagnostic then
   local ok,value=pcall(api.diagnostic)
   if ok and type(value)=='table' then view.nativeDiagnostic=copy(value) end
  end
  return view
 end
 return C
end
