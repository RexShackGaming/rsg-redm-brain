-- Client orchestration only; no economic mutation or native deletion on load.
WeaponNativeThrowablePlacementClient={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function same(a,b) return type(a)=='table' and type(b)=='table' and a.characterId==b.characterId
 and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function text(v,max) return type(v)=='string' and #v>0 and #v<=max and not v:find('%c') end
local function int(v,min) return type(v)=='number' and v>=min and v<math.huge and v%1==0 end
function WeaponNativeThrowablePlacementClient.New(api)
 local freshness=WeaponNativeThrowableThrowFreshness.New(api)
 local state,landing=nil,nil
 local seen,count={},0
 local P={}
 local function hold(reason) if state then state.phase='review_required';state.reason=reason end end
 local function current()
  local w=api.world();return state and same(w,state.identity) and w.alive==true
 end
 local function createLanding()
  local ok,value=pcall(api.newLanding,function(captured)
   return state and state.phase=='cleaning' and current() and captured.id==state.id
    and text(state.cleanupToken,64) or false
  end,function(identity) return freshness.Candidate(identity) end)
  if ok and type(value)=='table' then landing=value;return true end
  return false,value
 end
 local function send(action,payload)
  state.lastSend=api.now();state.sentAction=action
  -- Caller reserves phase first; a thrown transport error never repeats action.
  local ok=pcall(api.send,action,payload)
  if not ok then state.uncertain=true end
 end
 function P.Challenge(packet)
  if type(packet)~='table' or not text(packet.id,64) or not text(packet.operationId,40)
   or type(packet.units)~='table' or #packet.units~=1 or type(packet.units[1])~='table'
   or not int(packet.units[1].itemId,1) or not int(packet.units[1].itemRevision,0)
   or packet.lifetimeMs~=90000 then return false end
  local w=api.world()
  if not same(w,packet.identity) or w.alive~=true then return false end
  if seen[packet.id] then return true end -- duplicate server delivery is inert
  if state or count>=256 then return false end
  -- Do not create a fresh native lookup AFTER the paid challenge and adopt an
  -- older owned projectile. Only a pre-observed matching ledger decrease fits.
  if not freshness.Candidate(w) or not freshness.Matches(packet.operationId) then return false end
  seen[packet.id]=true;count=count+1
  state={id=packet.id,identity=copy(w),phase='capturing',started=api.now(),operationId=packet.operationId}
  if not landing then
   local ok,value=createLanding()
   if not ok then state.detail=tostring(value):sub(1,384);hold('landing_adapter_failed');return false end
  end
  local started,result
  if landing.BindChallenge and landing.Status().observationOnly then started,result=pcall(landing.BindChallenge,packet)
  else started,result=pcall(landing.Start,packet) end
  if not started or result~=true then state.detail=tostring(result):sub(1,384);hold('landing_start_failed');return false end
  return true
 end
 function P.Result(action,id,result)
  if not state or id~=state.id or not current() or type(result)~='table' or result.id~=id
   or (action~='transition' and action~='landing' and action~='cleaned' and action~='status') then return false end
  if result.phase=='transition_authorized' then
   if state.phase~='awaiting_transition' or not text(result.transitionToken,64) then return false end
   state.phase='adopting_transition'
   local ok,accepted=pcall(landing.AcceptTransition,result)
   if not ok or accepted~=true then hold('pickup_transition_unconfirmed');return false end
   state.transitionToken=result.transitionToken;state.phase='capturing';return true
  end
  if result.phase=='cleanup_authorized' then
   if state.phase~='awaiting_cleanup' or (action~='landing' and action~='status') or not text(result.cleanupToken,64) then return false end
   state.cleanupToken=result.cleanupToken;state.phase='cleanup_authorized';return true
  end
  if result.phase=='available' or result.phase=='claimed' then
   if state.phase~='awaiting_publication' or not text(result.pickupId,64) then return false end
   -- Completion is useful only after this client confirmed exact absence.
   if not state.cleaned then return false end
   state.phase='complete';state.pickupId=result.pickupId;return true
  end
  if result.phase=='refused' then
   if type(result.reason)=='string' then state.detail=result.reason:sub(1,384) end
   hold('placement_refused');return true
  end
  return result.phase=='pending'
 end
 function P.Tick()
  if not state then
   freshness.Tick()
   local w=api.world()
   if freshness.Candidate(w) then
    if not landing then
     assert(createLanding(),'landing_observation_adapter_failed')
     if landing.BeginObservation then assert(landing.BeginObservation(),'landing_observation_start_failed') end
    end
    -- Observe/mark only. No transition request, cleanup or publication can be
    -- sent until Challenge matches the canonical server spend operation.
    if landing.BeginObservation then
     local observed=landing.Tick()
     assert(observed and observed.phase~='review_required','landing_observation_unconfirmed')
    end
   end
   return
  end
  if state.phase=='complete' then
   -- Network completion can arrive BETWEEN Tick and Status calls. Keep its
   -- evidence latched until the owning caller explicitly acknowledges it.
   return
  end
  if state.phase=='review_required' then return end
  if not current() then hold('placement_owner_changed');return end
  if (api.now()-state.started)%4294967296>=90000 then hold('placement_timeout');return end
  if state.phase=='capturing' then
   local ok,result=pcall(landing.Tick)
   if not ok or not result or result.phase=='review_required' then
    state.detail=type(result)=='table' and result.reason or tostring(result):sub(1,384)
    hold('landing_unconfirmed');return
   end
   if result.phase=='landed' then
    state.phase='awaiting_cleanup'
    send('landing',{id=state.id,position=copy(result.position),transitionToken=state.transitionToken})
   elseif result.phase=='transition_pending' then
    state.phase='awaiting_transition'
    send('transition',{id=state.id,projectileNetworkId=result.transitionProposal.projectileNetworkId,
     pickupNetworkId=result.transitionProposal.pickupNetworkId})
   end
  elseif state.phase=='cleanup_authorized' then
   state.phase='cleaning' -- reserve before a yielding native cleanup wrapper
   local ok,clean=pcall(landing.Cleanup)
   if not ok or clean~=true then
    if not ok then state.detail=tostring(clean):sub(1,384) end
    hold('original_cleanup_unconfirmed');return
   end
   state.cleaned=true;state.phase='awaiting_publication'
   send('cleaned',{id=state.id,cleanupToken=state.cleanupToken})
  elseif state.phase=='awaiting_transition' or state.phase=='awaiting_cleanup' or state.phase=='awaiting_publication' then
   if (api.now()-state.lastSend)%4294967296>=2000 then send('status',{id=state.id}) end
  end
 end
 function P.Ready()
  if state then return false end
  local f=freshness.Status();local w=api.world()
  return f.phase=='armed' and same(w,f.identity) and w.ped==f.identity.ped and w.alive==true and not w.busy
 end
 function P.AcknowledgeCompletion(id)
  if not state or state.phase~='complete' or state.id~=id then return false end
  -- Rearms observation only. It never creates/refunds ammunition or replays a claim.
  state=nil;landing=nil;freshness=WeaponNativeThrowableThrowFreshness.New(api);return true
 end
 function P.Status()
  if state then
   local view=copy(state);view.freshness=freshness.Status()
   if landing then
    local ok,value=pcall(landing.Status)
    if ok and type(value)=='table' then view.landing=value end
   end
   return view
  end
  local f=freshness.Status()
  return {phase=f.phase=='review_required' and 'review_required' or 'observing',freshness=f,
   landing=landing and landing.Status() or nil}
 end
 return P
end
