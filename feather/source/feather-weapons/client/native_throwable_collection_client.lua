-- Server-armed client composition only. No events, threads or permissions are
-- installed here. The production host must call BeforeStep BEFORE ammo sampling.
WeaponNativeThrowableCollectionClient={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function equal(a,b)
 if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function text(v) return type(v)=='string' and #v>0 and #v<=128 and not v:find('%c') end
local function same(a,b) return type(a)=='table' and type(b)=='table' and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch and text(a.characterId) and text(a.sessionId) and text(a.epoch) end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowableCollectionClient.New(api)
 for _,key in ipairs({'world','snapshot','pools','now','send','escrow','suspend'}) do assert(type(api)=='table' and callable(api[key]),'Collection client port required: '..key) end
 local state,used,count=nil,{},0
 local C={}
 local function hold(why)
  if state then state.phase='review_required';state.reason=why end
  pcall(api.suspend,why);return false
 end
 local function live()
  local w=api.world()
  return same(w,state.identity) and w.alive==true and w.ped==state.ped and w.bucket==state.bucket
 end
 local function observed()
  local pools=api.pools()
  if type(pools)~='table' then return nil end
  local n=pools.ammo_tomahawk_regular
  pools=copy(pools);pools.ammo_tomahawk_regular=0
  if not equal(pools,state.baseline) then return nil end
  return n
 end
 local function sendEvent()
  if state.phase~='held' or not state.event or state.sent then return end
  state.sent=true -- the collection request is never automatically replayed
  api.send('observe',{ticket=state.ticket,event=copy(state.event)})
 end
 function C.Arm(packet,origin)
  if origin~=true or type(packet)~='table' or not text(packet.ticket) or not same(packet.identity,api.world())
   or packet.lifetimeMs~=30000 or type(packet.bucket)~='number' or packet.bucket<0 or packet.bucket%1~=0 then return false end
  if state then return state.ticket==packet.ticket and state.phase=='armed' end
  if used[packet.ticket] or count>=64 then return false end
  local w,snapshot=api.world(),api.snapshot()
  if not w or w.alive~=true or w.bucket~=packet.bucket or type(w.ped)~='number' or w.ped<1
   or type(snapshot)~='table' or not same(snapshot,packet.identity) or type(snapshot.pools)~='table'
   or snapshot.pools.ammo_tomahawk_regular~=0 or not equal(api.pools(),snapshot.pools) then return false end
  used[packet.ticket]=true;count=count+1
  state={ticket=packet.ticket,identity=copy(packet.identity),bucket=packet.bucket,ped=w.ped,
   baseline=copy(snapshot.pools),revision=snapshot.revision,started=api.now(),phase='armed'}
  return true
 end
 function C.Event(event)
  if not state or (state.phase~='armed' and state.phase~='held') or state.event or not live()
   or type(event)~='table' or event.kind~='ai_pickup' or event.referenceBuild~=1491 or event.queue~=0
   or event.eventHash~=-178091376 or event.nativeTomahawkQuantity~=1 or event.collectorIsLocal~=true
   or event.collectorPlayerIndex~=event.localPlayerIndex then return false end
  local raw=event.rawSlots
  if type(raw)~='table' or #raw~=8 then return false end
  for key,n in pairs(raw) do
   if type(key)~='number' or key%1~=0 or key<1 or key>8 or type(n)~='number' or n%1~=0 or n< -2147483648 or n>2147483647 then return false end
  end
  if (raw[1]&0xffffffff)~=3397143806 or raw[2]~=1 or raw[3]~=event.localPlayerIndex
   or (raw[4]&0xffffffff)~=3358573347 or raw[7]~=1 or (raw[8]&0xffffffff)~=2783539927 then return false end
  state.event={kind=event.kind,referenceBuild=1491,queue=0,eventHash=event.eventHash,
   nativeTomahawkQuantity=1,localPlayerIndex=event.localPlayerIndex,rawSlots=copy(raw)}
  local ok=pcall(sendEvent);if not ok then return hold('native_collection_send_uncertain') end
  return true
 end
 function C.BeforeStep(runtime)
  if not state then return true end
  if state.phase=='review_required' then return false end
  if state.phase=='cleaned' then
   -- Keep querying the one handoff while the normal driver owns the released
   -- equipment rebuild. Never request native cleanup or the claim again.
   if (api.now()-state.cleanedAt)%4294967296>60000 then return hold('native_collection_result_timeout') end
   if not state.lastPoll or (api.now()-state.lastPoll)%4294967296>=250 then
    state.lastPoll=api.now()
    local ok=pcall(api.send,'status',{ticket=state.ticket})
    if not ok then return hold('native_collection_status_unavailable') end
   end
   return true
  end
  local ok,value=pcall(function()
   if not live() then return hold('native_collection_scope_changed') end
   local snapshot=api.snapshot()
   if not snapshot or snapshot.revision~=state.revision or not same(snapshot,state.identity)
    or not equal(snapshot.pools,state.baseline) then return hold('native_collection_baseline_changed') end
   if state.phase=='armed' then
    local n=observed()
    if n==0 then
     if (api.now()-state.started)%4294967296>30000 then state=nil end
     return true
    end
    if n~=1 then return hold('native_collection_increase_unconfirmed') end
    state.phase='holding';state.runtime=runtime
    if runtime.BeginNativeCollectionHold(state.ticket,state.identity)~=true then return hold('native_collection_runtime_hold_refused') end
    state.phase='held';state.heldAt=api.now()
    sendEvent()
   end
   if not state or state.phase=='cleaned' then return true end -- a yielding send may already settle the handoff
   if (api.now()-state.heldAt)%4294967296>10000 then return hold('native_collection_handoff_timeout') end
   if state.sent and (not state.lastPoll or (api.now()-state.lastPoll)%4294967296>=250) then
    state.lastPoll=api.now();api.send('status',{ticket=state.ticket}) -- reads only, never repeat observe
   end
   return true
  end)
  return ok and value or hold('native_collection_client_adapter_failed')
 end
 function C.Escrow(packet,origin)
  if origin~=true or not state or type(packet)~='table' or packet.ticket~=state.ticket
   or not same(packet.identity,state.identity) then return false end
  if state.phase=='cleaned' then api.send('cleaned',{ticket=state.ticket,receipt=copy(state.receipt)});return true end
  if state.phase~='held' or not state.sent then return false end
  state.phase='cleaning' -- no duplicate request can repeat native cleanup
  local ok,value=pcall(function()
   if not live() or observed()~=1 then return hold('native_collection_escrow_scope_changed') end
   state.escrow=api.escrow(copy(state.identity),state.runtime)
   local receipt=state.escrow.Begin(state.ticket,state.identity,state.baseline)
   state.receipt=copy(receipt) -- available to the runtime's exact cleanup check
   if receipt.phase~='cleaned' then return hold('native_collection_escrow_unconfirmed') end
   if state.runtime.EndNativeCollectionHold(state.ticket)~=true then return hold('native_collection_runtime_release_unconfirmed') end
   state.receipt.runtimeReleased=true;state.phase='cleaned';state.cleanedAt=api.now()
   api.send('cleaned',{ticket=state.ticket,receipt=copy(state.receipt)})
   return true
  end)
  return ok and value or hold('native_collection_cleanup_uncertain')
 end
 function C.ReadEscrow(ticket)
  return state and ticket==state.ticket and copy(state.receipt) or {phase='pending'}
 end
 function C.Result(packet,origin)
  if origin~=true or not state or type(packet)~='table' or packet.ticket~=state.ticket or type(packet.result)~='table' then return false end
  local r=packet.result
  if r.phase=='review_required' or r.phase=='refused' then return hold('native_collection_server_review_required') end
  if r.phase~='complete' then return true end
  local w=api.world()
  if state.phase~='cleaned' or not same(r.collector,state.identity) or not same(r.identity,w)
   or w.characterId~=state.identity.characterId or w.sessionId~=state.identity.sessionId or w.alive~=true then return false end
  state=nil;return true
 end
 function C.Status() return state and {phase=state.phase,ticket=state.ticket,reason=state.reason,sent=state.sent==true} or {phase='idle'} end
 return C
end
