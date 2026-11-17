-- Landing coordinates and cleanup ACK are client reports, not engine proof.
-- Authority to publish comes from one exact confirmed paid spend plus the
-- current challenge. Unknown publication outcomes are queried, never replayed.
WeaponNativeThrowablePlacementHandshake={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function same(a,b) return type(a)=='table' and type(b)=='table' and a.characterId==b.characterId
 and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function text(v) return type(v)=='string' and #v>0 and #v<=64 and not v:find('%c') end
local function pos(v) if type(v)~='table' then return false end
 for _,k in ipairs({'x','y','z'}) do local n=v[k];if type(n)~='number' or n~=n or math.abs(n)==math.huge then return false end end;return true end
local function distance(a,b) return (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2 end
function WeaponNativeThrowablePlacementHandshake.New(api)
 local states,count={},0
 local H={}
 local function challenge(source,id)
  local c=api.challenge(source,id);local a=api.actor(source)
  if not c or c.phase~='issued' or not same(a,c.identity) or a.alive~=true
   or type(c.units)~='table' or #c.units~=1 or not pos(a.position) then return nil end
  return c,a
 end
 local function reply(state)
  if state.phase=='cleanup_authorized' then return {phase=state.phase,id=state.id,cleanupToken=state.token} end
  if state.phase=='available' or state.phase=='claimed' then return {phase=state.phase,id=state.id,pickupId=state.pickupId} end
  return {phase='pending',id=state.id}
 end
 function H.Handle(source,action,request)
  if type(source)~='number' or source<1 or source%1~=0 or type(request)~='table' or not text(request.id)
   or (action~='landing' and action~='cleaned' and action~='status') then return {phase='refused'} end
  for k in pairs(request) do if k~='id' and not(action=='landing' and k=='position')
   and not(action=='cleaned' and k=='cleanupToken') then return {phase='refused'} end end
  local c,a=challenge(source,request.id)
  if not c then return {phase='refused'} end
  local state=states[request.id]
  if state and (state.source~=source or not same(state.identity,c.identity)) then return {phase='refused'} end
  if state and state.busy then return {phase='pending',id=request.id} end
  if action=='landing' then
   if not pos(request.position) or distance(request.position,a.position)>2500 then return {phase='refused'} end
   if state then
    if distance(state.position,request.position)>0 then return {phase='refused'} end
    return reply(state)
   end
   if count>=256 then return {phase='refused'} end
   state={id=request.id,source=source,identity=copy(c.identity),
    position={x=request.position.x,y=request.position.y,z=request.position.z},bucket=a.bucket,
    unit=copy(c.units[1]),operationId=c.operationId,phase='pending',busy=true}
   states[request.id]=state;count=count+1
   local ok,token=pcall(api.newId)
   local fresh,actor=challenge(source,request.id)
   state.busy=false
   if not ok or not text(token) or not fresh or actor.bucket~=state.bucket
    or distance(actor.position,state.position)>2500 then return reply(state) end
   state.token=token;state.phase='cleanup_authorized';return reply(state)
  end
  if not state then return {phase='refused'} end
  if action=='cleaned' then
   if not text(request.cleanupToken) or request.cleanupToken~=state.token then return {phase='refused'} end
   if state.phase~='cleanup_authorized' then return reply(state) end
   if a.bucket~=state.bucket or distance(a.position,state.position)>2500 then return {phase='refused'} end
   state.phase='pending';state.busy=true -- before yielding transaction entry
   local ok,result=pcall(api.place,source,{itemId=state.unit.itemId,itemRevision=state.unit.itemRevision,
    spendOperationId=state.operationId,position=copy(state.position)})
   state.busy=false
   if ok and type(result)=='table' and (result.phase=='available' or result.phase=='claimed') then
    state.phase=result.phase;state.pickupId=result.id
   end
   return reply(state)
  end
  if state.phase=='pending' and state.token then
   state.busy=true
   local ok,result=pcall(api.read,source,{itemId=state.unit.itemId,itemRevision=state.unit.itemRevision})
   state.busy=false
   if ok and type(result)=='table' and (result.phase=='available' or result.phase=='claimed') then
    state.phase=result.phase;state.pickupId=result.id
   end
  end
  return reply(state)
 end
 return H
end
function WeaponNativeThrowablePlacementHandshake.Install(api)
 local h=WeaponNativeThrowablePlacementHandshake.New(api)
 local limits={}
 RegisterNetEvent('feather-weapons:server:throwable-placement-request',function(action,request)
  local player=source
  if not api.enabled() or type(player)~='number' or player<1 or player%1~=0 then return end
  local now=api.now();local rate=limits[player]
  if not rate or (now-rate.started)%4294967296>=1000 then rate={started=now,count=0};limits[player]=rate end
  if rate.count>=4 then return end;rate.count=rate.count+1
  local ok,result=pcall(h.Handle,player,action,request)
  -- Replies are advisory; the same source/current challenge is rechecked after
  -- a yielding storage call so a reused player ID cannot receive old tokens.
  local id=type(request)=='table' and request.id
  if not text(id) or not api.challenge(player,id) then return end
  local response=ok and result or {phase='pending'};response.id=id
  api.reply(player,action,id,response)
 end)
 AddEventHandler('playerDropped',function() limits[source]=nil end)
 return h
end
