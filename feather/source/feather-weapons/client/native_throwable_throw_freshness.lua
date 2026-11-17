-- Bounded pre-throw observation. This establishes temporal association only;
-- paid ownership still comes from the server receipt/challenge.
WeaponNativeThrowableThrowFreshness={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function same(a,b) return type(a)=='table' and type(b)=='table' and a.characterId==b.characterId
 and a.sessionId==b.sessionId and a.epoch==b.epoch and a.ped==b.ped end
local function int(v) return type(v)=='number' and v>=0 and v<math.huge and v%1==0 end
function WeaponNativeThrowableThrowFreshness.New(api)
 local state,busy=nil,false
 local F={}
 function F.Tick()
  if busy then return false end;busy=true
  local ok=pcall(function()
   local world=api.world()
   if not world or world.alive~=true then state=nil;return end
   -- Read-only capture must continue while the ammunition observation awaits
   -- its server receipt: the projectile may become a Pickup before that reply.
   -- Rebuild/close still suspends observation, and Ready still blocks firing.
   if world.observationBusy==true or (world.observationBusy==nil and world.busy) then return end
   if not state or not same(world,state.identity) then state={identity=copy(world),phase='baseline'} end
   if state.phase=='captured' then
    if (api.now()-state.observed)%4294967296>=90000 then state.phase='review_required' end
    return
   end
   if state.phase=='review_required' then return end
   local quantity=api.quantity();local candidate=api.probe(copy(world))
   local after=api.world()
   if not same(after,world) or after.alive~=true or not int(quantity) or quantity>3 then
    state.phase='review_required';return
   end
   local now=api.now()
   if state.phase=='baseline' then
    -- Existing owned projectile makes a fresh association ambiguous. Do not
    -- remember it as this throw or switch to an unowned/world-pool search.
    if candidate then return end
    state.phase='armed';state.quantity=quantity;state.last=now;state.expectedRevision=world.revision;return
   end
   if (now-state.last)%4294967296>250 then state.phase='review_required';return end
   if quantity==state.quantity then
    if candidate then state.phase='review_required' else state.last=now;state.expectedRevision=world.revision end
    return
   end
   if quantity~=state.quantity-1 then state.phase='review_required';return end
   if not candidate then state.phase='review_required';return end
   state.phase='captured';state.object=copy(candidate);state.observed=now
  end)
  busy=false
  if not ok then state=state or {};state.phase='review_required' end
  return ok
 end
 function F.Candidate(identity)
  if not state or state.phase~='captured' or not same(identity,state.identity)
   or (api.now()-state.observed)%4294967296>=90000 then return nil end
  return copy(state.object)
 end
 function F.Status() return state and copy(state) or {phase='idle'} end
 function F.Matches(operationId)
  return state and state.phase=='captured' and int(state.expectedRevision)
   and operationId=='observe:'..state.expectedRevision or false
 end
 return F
end
