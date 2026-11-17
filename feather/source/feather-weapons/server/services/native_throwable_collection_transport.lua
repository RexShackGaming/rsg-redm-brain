-- Bounded transport composition. No public net handlers are installed here.
-- Arms originate in a verified server watch, never a client-selected paid item.
WeaponNativeThrowableCollectionTransport={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function equal(a,b)
 if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function text(v) return type(v)=='string' and #v>0 and #v<=128 and not v:find('%c') end
local function same(a,b) return type(a)=='table' and type(b)=='table' and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowableCollectionTransport.New(api)
 for _,k in ipairs({'enabled','now','actor','prepare','newTicket','send'}) do assert(type(api)=='table' and callable(api[k]),'Collection transport port required: '..k) end
 for _,k in ipairs({'Observe','ReadObservation','Begin','Read'}) do assert(type(api.service)=='table' and callable(api.service[k]),'Collection service method required: '..k) end
 local arms,tickets,count={},{},0
 local T={}
 local function current(a,restoring)
  local actor=api.actor(a.source)
  return api.enabled()==true and type(actor)=='table' and actor.alive==true and actor.bucket==a.bucket
   and actor.characterId==a.identity.characterId and actor.sessionId==a.identity.sessionId
   and (restoring or actor.epoch==a.identity.epoch)
 end
 function T.Arm(source,watchId)
  local previous=arms[source]
  if previous and previous.phase=='armed' and not previous.observed and not previous.began
   and (api.now()-previous.started)%4294967296>30000 then arms[source]=nil end
  if api.enabled()~=true or type(source)~='number' or source<1 or source%1~=0 or source==math.huge
   or not text(watchId) or count>=64 or (arms[source] and arms[source].phase~='complete') then return false end
  local prepared=api.prepare(source,watchId)
  if type(prepared)~='table' or not same(prepared.identity,api.actor(source)) then return false end
  local ticket=api.newTicket()
  if not text(ticket) or tickets[ticket] then return false end
  local a={source=source,identity=copy(prepared.identity),bucket=prepared.bucket,watchId=watchId,
   ticket=ticket,started=api.now(),phase='armed'}
  arms[source]=a;tickets[ticket]=a;count=count+1
  if not current(a,false) then a.phase='review_required';return false end
  api.send(source,'arm',{ticket=ticket,identity=copy(a.identity),bucket=a.bucket,lifetimeMs=30000})
  return true
 end
 function T.Ticket(authorization)
  local a=type(authorization)=='table' and arms[authorization.source]
  if not a or not current(a,false) or authorization.eventId~=a.ticket or authorization.watchId~=a.watchId
   or not same(authorization.collector,a.identity) then return nil end
  return a.ticket
 end
 function T.BeginEscrow(source,ticket,identity)
  local a=arms[source]
  if not a or a.ticket~=ticket or not same(a.identity,identity) or not current(a,false)
   or not a.began or a.phase~='starting' then return false end
  a.phase='escrow_pending'
  api.send(source,'escrow',{ticket=ticket,identity=copy(identity)})
  return true
 end
 function T.ReadEscrow(source,ticket,identity)
  local a=arms[source]
  if not a or a.ticket~=ticket or not same(a.identity,identity) or not current(a,false) then return {phase='pending'} end
  return a.receipt and copy(a.receipt) or {phase='pending'}
 end
 local function progress(a)
  if not a.began then
   if not a.observed then return {phase='pending'} end
   local observation=api.service.ReadObservation(a.source,a.ticket)
   a.observation=copy(observation) -- server-only diagnostic; never a claim input
   if observation.phase=='pending' then return {phase='pending'} end
   if observation.phase~='correlated_observation' then return {phase='review_required',reason=observation.reason} end
   a.began=true;a.phase='starting' -- reserve before Begin may yield/send cleanup
   return api.service.Begin(a.source,a.ticket)
  end
  return api.service.Read(a.source,a.ticket) -- never dispatch another Begin
 end
 local function handle(source,action,packet)
  if api.enabled()~=true or type(packet)~='table' or not text(packet.ticket)
   or (action~='observe' and action~='cleaned' and action~='status') then return false end
  local a=arms[source]
  if not a or packet.ticket~=a.ticket or not current(a,a.began==true) then return false end
  local now=api.now()
  if not a.rateAt or (now-a.rateAt)%4294967296>=1000 then a.rateAt=now;a.rate=0 end
  if a.rate>=8 then return false end;a.rate=a.rate+1
  if a.phase=='complete' or a.phase=='review_required' then
   api.send(source,'result',{ticket=a.ticket,result=copy(a.result)});return true
  end
  local ok,result=pcall(function()
   if action=='observe' then
    if a.observed or a.began or (now-a.started)%4294967296>30000 or not current(a,false) then return nil end
    a.observed=true -- one observation request; retries must use status
    local observed=api.service.Observe(source,a.ticket,packet.event)
    a.observation=copy(observed)
    if observed.phase~='pending' and observed.phase~='correlated_observation' then return {phase='review_required',reason=observed.reason} end
   elseif action=='cleaned' then
    if not a.began or not current(a,false) then return nil end
    local receipt=packet.receipt
    if type(receipt)~='table' or receipt.phase~='cleaned' or receipt.ticket~=a.ticket
     or not same(receipt.identity,a.identity) or receipt.quantityBefore~=1 or receipt.quantityAfter~=0
     or receipt.guidCaptured~=true or receipt.guidReleased~=true or receipt.otherPoolsUnchanged~=true
     or receipt.runtimeReleased~=true then return nil end
    -- Retain only the supported receipt fields; no client-selected item/GUID.
    local retained={phase='cleaned',ticket=a.ticket,identity=copy(a.identity),quantityBefore=1,quantityAfter=0,
     guidCaptured=true,guidReleased=true,otherPoolsUnchanged=true,runtimeReleased=true}
    if a.receipt and not equal(a.receipt,retained) then return nil end
    a.receipt=retained
   end
   return progress(a)
  end)
  if not ok then result={phase='pending'} end -- uncertain outcome: subsequent status reads only
  if not result then return false end
  if result.phase=='complete' or result.phase=='review_required' or result.phase=='refused' then
   a.phase=result.phase=='complete' and 'complete' or 'review_required';a.result=copy(result)
  end
  api.send(source,'result',{ticket=a.ticket,result=copy(result)})
  return true
 end
 local function queued(a,action,packet)
  if action=='status' then return true end -- next read may poll again
  a.queue=a.queue or {}
  if a.queue[action] then return true end
  local retained={ticket=a.ticket}
  if action=='observe' then
   if a.observed or type(packet.event)~='table' or type(packet.event.rawSlots)~='table' or #packet.event.rawSlots~=8 then return false end
   retained.event={rawSlots={}}
   for _,key in ipairs({'kind','referenceBuild','queue','eventHash','nativeTomahawkQuantity','localPlayerIndex'}) do
    local v=packet.event[key];if type(v)~='string' and type(v)~='number' then return false end
    if type(v)=='string' and #v>96 then return false end
    retained.event[key]=v
   end
   for n=1,8 do
    local v=packet.event.rawSlots[n];if type(v)~='number' then return false end
    retained.event.rawSlots[n]=v
   end
  elseif action=='cleaned' then
   if a.receipt then return true end
   local r=packet.receipt
   if type(r)~='table' or type(r.identity)~='table' then return false end
   retained.receipt={identity={}}
   for _,key in ipairs({'characterId','sessionId','epoch'}) do
    if not text(r.identity[key]) then return false end;retained.receipt.identity[key]=r.identity[key]
   end
   for _,key in ipairs({'phase','ticket','quantityBefore','quantityAfter','guidCaptured','guidReleased','otherPoolsUnchanged','runtimeReleased'}) do
    local v=r[key];if type(v)~='string' and type(v)~='number' and type(v)~='boolean' then return false end
    if type(v)=='string' and #v>128 then return false end
    retained.receipt[key]=v
   end
  else return false end
  a.queue[action]=retained;return true
 end
 function T.Handle(source,action,packet)
  if type(packet)~='table' or not text(packet.ticket) then return false end
  local a=arms[source]
  if not a or a.ticket~=packet.ticket then return false end
  -- actor/medical/receipt ports can yield. Reserve BEFORE the first such read,
  -- so status cannot race an in-flight Observe into a false terminal refusal.
  if a.handling then return queued(a,action,packet) end
  a.handling=true
  local ok,result=pcall(handle,source,action,packet)
  -- Keep at most one observation and one cleanup report across the yield;
  -- status retries are read-only. Drain reports without replaying mutations.
  for _,nextAction in ipairs({'observe','cleaned'}) do
   local pending=a.queue and a.queue[nextAction]
   if pending then a.queue[nextAction]=nil;pcall(handle,source,nextAction,pending) end
  end
  a.handling=false
  return ok and result or false
 end
 function T.Diagnostics(source)
  local a=arms[source]
  return a and copy(a.observation) or nil -- no actor/SQL/native call or progress
 end
 return T
end
