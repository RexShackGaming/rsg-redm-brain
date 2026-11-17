-- Explicit transition/cleanup protocol. No public registration on load.
-- Synthetic acceptance uses the same protocol with NO economic storage ports.
WeaponNativeThrowableTransitionProtocol={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function same(a,b) return type(a)=='table' and type(b)=='table' and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function text(v) return type(v)=='string' and #v>0 and #v<=64 and not v:find('%c') end
local function int(v) return type(v)=='number' and v>0 and v<math.huge and v%1==0 end
local function pos(v) if type(v)~='table' then return false end;for _,k in ipairs({'x','y','z'}) do
 local n=v[k];if type(n)~='number' or n~=n or math.abs(n)==math.huge then return false end end;return true end
local function distance(a,b) return (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2 end
function WeaponNativeThrowableTransitionProtocol.New(api)
 local binding=WeaponNativeThrowableTransitionBinding.New(api)
 local states,count={},0
 local P={Created=binding.Created,Removed=binding.Removed}
 local function current(s)
  local a=api.actor(s.source);local c=api.challenge(s.source,s.id)
  return a and a.alive==true and same(a,s.identity) and a.bucket==s.bucket and c and same(c.identity,s.identity)
   and (not s.position or pos(a.position) and distance(a.position,s.position)<=2500)
   and c.operationId==s.operationId and type(c.units)=='table' and #c.units==1
   and c.units[1].itemId==s.unit.itemId and c.units[1].itemRevision==s.unit.itemRevision
 end
 local function reply(s)
  local r={id=s.id,phase=s.phase}
  if s.phase=='held' then r.phase='refused';r.reason=s.reason;return r end
  if s.phase=='transition_authorized' then r.transitionToken=s.transitionToken;r.projectileNetworkId=s.projectileId;r.pickupNetworkId=s.pickupId end
  if s.phase=='cleanup_authorized' then r.cleanupToken=s.cleanupToken end
  if s.phase=='available' or s.phase=='claimed' then r.pickupId=s.publishedId end
  if s.phase~='transition_authorized' and s.phase~='cleanup_authorized' and s.phase~='available' and s.phase~='claimed' then r.phase='pending' end
  return r
 end
 local function publish(s)
  if not binding.Absent(s.proof) or not current(s) then return reply(s) end
  s.phase='publishing';s.busy=true
  local ok,result=pcall(api.place,s.source,{itemId=s.unit.itemId,itemRevision=s.unit.itemRevision,
   spendOperationId=s.operationId,position=copy(s.position)})
  s.busy=false
  if ok and type(result)=='table' and (result.phase=='available' or result.phase=='claimed') then s.phase=result.phase;s.publishedId=result.id end
  return reply(s)
 end
 local function link(s)
  if (api.now()-s.requested)%4294967296>=5000 then s.phase='held';s.reason='transition_lifetime_readiness_timeout';return reply(s) end
  s.phase='linking';s.busy=true
  local ok,result=pcall(binding.Link,s.source,s.id,s.projectileId,s.pickupId)
  s.busy=false
  if ok and result and result.phase=='pending' and result.reason~='link_reserved' then
   s.phase='waiting_lifetime';s.reason=result.reason;return reply(s)
  end
  if not ok or not result or result.phase~='linked' then
   s.phase='held';s.reason=ok and result and result.reason or 'transition_link_unavailable';return reply(s)
  end
  s.proof=result.proof;s.busy=true
  local made,token=pcall(api.newId);s.busy=false
  if made and text(token) and current(s) and binding.Current(s.proof) then
   s.transitionToken=token;s.phase='transition_authorized';s.reason=nil
  end
  return reply(s)
 end
 function P.Handle(source,action,r)
  if not int(source) or type(r)~='table' or not text(r.id) then return {phase='refused'} end
  local allowed={id=true}
  if action=='transition' then allowed.projectileNetworkId=true;allowed.pickupNetworkId=true
  elseif action=='landing' then allowed.position=true;allowed.transitionToken=true
  elseif action=='cleaned' then allowed.cleanupToken=true
  elseif action~='status' then return {phase='refused',id=r.id} end
  for k in pairs(r) do if not allowed[k] then return {phase='refused',id=r.id} end end
  local s=states[r.id]
  if s then
   if s.source~=source or not current(s) then return {phase='refused',id=r.id} end
   if s.busy then return {phase='pending',id=r.id} end
  end
  if action=='transition' then
   if not int(r.projectileNetworkId) or not int(r.pickupNetworkId) then return {phase='refused',id=r.id} end
   if s then
    if s.projectileId~=r.projectileNetworkId or s.pickupId~=r.pickupNetworkId then return {phase='refused',id=r.id} end
    return reply(s)
   end
   if count>=128 then return {phase='refused',id=r.id} end
   local c=api.challenge(source,r.id);local a=api.actor(source)
   if not c or not a or a.alive~=true or not same(a,c.identity) or type(c.units)~='table' or #c.units~=1 then return {phase='refused',id=r.id} end
   s={id=r.id,source=source,identity=copy(c.identity),bucket=a.bucket,unit=copy(c.units[1]),operationId=c.operationId,
    projectileId=r.projectileNetworkId,pickupId=r.pickupNetworkId,phase='linking',requested=api.now()}
   states[r.id]=s;count=count+1
   return link(s)
  end
  if not s then return {phase='refused',id=r.id} end
  if action=='landing' then
   if not text(r.transitionToken) or r.transitionToken~=s.transitionToken or not pos(r.position) then return {phase='refused',id=r.id} end
   if s.position then
    if distance(s.position,r.position)>0 then return {phase='refused',id=r.id} end
    return reply(s)
   end
   local a=api.actor(source)
   if s.phase~='transition_authorized' or not pos(a.position) or distance(a.position,r.position)>2500 or not binding.Current(s.proof) then return {phase='refused',id=r.id} end
   s.position={x=r.position.x,y=r.position.y,z=r.position.z};s.phase='authorizing';s.busy=true
   local ok,token=pcall(api.newId);s.busy=false
   if ok and text(token) and current(s) and binding.Current(s.proof) then s.cleanupToken=token;s.phase='cleanup_authorized' end
   return reply(s)
  elseif action=='cleaned' then
   if not text(r.cleanupToken) or r.cleanupToken~=s.cleanupToken then return {phase='refused',id=r.id} end
   if s.phase~='cleanup_authorized' then return reply(s) end
   s.phase='awaiting_absence';return publish(s)
  elseif s.phase=='waiting_lifetime' then return link(s)
  elseif s.phase=='awaiting_absence' then return publish(s)
  elseif s.phase=='publishing' then
   s.busy=true
   local ok,result=pcall(api.readPlacement,s.source,{itemId=s.unit.itemId,itemRevision=s.unit.itemRevision})
   s.busy=false
   if ok and result and (result.phase=='available' or result.phase=='claimed') then s.phase=result.phase;s.publishedId=result.id end
  end
  return reply(s)
 end
 function P.Diagnostics()
  for _,s in pairs(states) do
   return {phase=s.phase,reason=s.reason,source=s.source,requested=s.requested,now=api.now(),binding=binding.Diagnostics(s.projectileId,s.pickupId)}
  end
  return {phase='idle',binding=binding.Diagnostics()}
 end
 return P
end
