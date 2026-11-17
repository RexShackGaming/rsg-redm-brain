-- Server prompt admission. Inactive until durable recovery publication and
-- released-owner transaction ports are installed; no public events or exports.
-- Visual/network projectile handles are deliberately absent from this contract.
WeaponNativeThrowablePickupClaims={}
local function copy(v)
 if type(v)~='table' then return v end
 local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out
end
local function equal(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end
 return true
end
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function int(v,min) return finite(v) and v>=min and v%1==0 end
local function text(v) return type(v)=='string' and #v>0 and #v<=96 and not v:find('%c') end
local function identity(v) return type(v)=='table' and text(v.characterId) and text(v.sessionId) and text(v.epoch) end
local function same(a,b) return identity(a) and identity(b) and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function position(v)
 if type(v)~='table' then return false end
 for _,k in ipairs({'x','y','z'}) do if not finite(v[k]) then return false end end
 return true
end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowablePickupClaims.New(api)
 for _,key in ipairs({'actor','binding','claim','readClaim','changed'}) do
  assert(type(api)=='table' and callable(api[key]),'Server pickup port required: '..key)
 end
 local held,actors={},{}
 local P={}
 local function refused(code) return {phase='refused',code=code} end
 local function notify(id) pcall(api.changed,id) end
 local function current(source,request,bound)
  local a=api.actor(source)
  if not identity(a) or a.alive~=true or not int(a.bucket,0) or not position(a.position)
   or bound and not same(a,bound) then return nil end
  local b=api.binding(request.id) -- read durable server record, never client coordinates
  if type(b)~='table' or b.kind~='paid_tomahawk_pickup' or b.phase~='available'
   or b.presentation~=nil and b.presentation~='prompt'
   or b.id~=request.id or b.revision~=request.revision or not int(b.itemId,1)
   or not int(b.itemRevision,0) or not identity(b.origin) or not int(b.bucket,0)
   or not position(b.position) or b.bucket~=a.bucket then return nil end
  local distance=0;for _,k in ipairs({'x','y','z'}) do distance=distance+(a.position[k]-b.position[k])^2 end
  if distance>4 then return nil end
  return a,b
 end
 local function finish(state,result)
  if type(result)~='table' or result.phase~='claimed' and result.phase~='refused' then return {phase='pending'} end
  -- Claimed results must identify the exact receipt and collector. A receipt
  -- from another player must never be delivered as this player's success.
  if result.phase=='claimed' and (result.id~=state.id or result.revision~=state.revision
   or result.itemId~=state.itemId or not same(result.collector,state.identity)) then return {phase='pending'} end
  held[state.id]=nil;if actors[state.source]==state then actors[state.source]=nil end
  notify(state.id)
  return copy(result)
 end
 function P.Claim(source,request)
  if not int(source,1) or type(request)~='table' or not text(request.id) or not int(request.revision,0) then return refused('invalid_request') end
  -- Lock before actor/binding/transaction ports can yield or recursively reenter.
  if held[request.id] or actors[source] then return {phase='pending'} end
  local state={id=request.id,revision=request.revision,source=source}
  held[state.id]=state;actors[source]=state
  local ok,a,b=pcall(current,source,request)
  -- No mutation has been requested yet, so failed admission reads are a
  -- definite refusal rather than an uncertain transaction.
  if not ok then return finish(state,refused('pickup_read_unavailable')) end
  if not a then return finish(state,refused('pickup_unavailable')) end
  b=copy(b)
  state.identity={characterId=a.characterId,sessionId=a.sessionId,epoch=a.epoch};state.itemId=b.itemId
  notify(state.id)
  local function authority()
   if held[state.id]~=state or actors[source]~=state then return false end
   local checked,actor,binding=pcall(current,source,request,state.identity)
   return checked and actor~=nil and equal(binding,b)
  end
  local committed,result=pcall(api.claim,source,copy(b),copy(state.identity),authority)
  if not committed then return {phase='pending'} end
  return finish(state,result)
 end
 function P.Read(source,request)
  if not int(source,1) or type(request)~='table' or not text(request.id) or not int(request.revision,0) then return refused('invalid_request') end
  local state=held[request.id]
  if not state or state.source~=source or state.revision~=request.revision or not state.identity then return refused('no_matching_request') end
  local ok,actor=pcall(api.actor,source)
  if not ok or not identity(actor) or actor.characterId~=state.identity.characterId
   or actor.sessionId~=state.identity.sessionId then return {phase='pending'} end
  local read,result=pcall(api.readClaim,copy(state)) -- query receipt only, never call claim again
  if not read then return {phase='pending'} end
  if not same(actor,state.identity) and (type(result)~='table' or result.phase~='claimed'
   or not same(actor,result.identity)) then return {phase='pending'} end
  return finish(state,result)
 end
 function P.Available(id) return held[id]==nil end
 return P
end
