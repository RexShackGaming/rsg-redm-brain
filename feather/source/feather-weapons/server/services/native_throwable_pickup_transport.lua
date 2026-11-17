-- Explicit install by the normal recovery bootstrap once real ports are ready.
-- The event always takes its actor from Cfx `source`, never from client data.
WeaponNativeThrowablePickupTransport={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function text(v,max) return type(v)=='string' and #v>0 and #v<=max and not v:find('%c') end
local function int(v,min) return type(v)=='number' and v>=min and v<math.huge and v%1==0 end
local function sameLogin(a,b) return a and b and a.characterId==b.characterId and a.sessionId==b.sessionId end
local function same(a,b) return sameLogin(a,b) and a.epoch==b.epoch end
local function identity(v) return type(v)=='table' and text(v.characterId,128) and text(v.sessionId,128) and text(v.epoch,128) end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowablePickupTransport.New(api)
 for _,k in ipairs({'enabled','now','actor','claim','read','offers','reply'}) do assert(type(api)=='table' and callable(api[k]),'Pickup transport port required: '..k) end
 local states={}
 local T={}
 function T.Handle(source,id,scope,kind,data)
  if not int(source,1) or not text(id,96) or not identity(scope) or (kind~='claim' and kind~='status' and kind~='offers')
   or api.enabled()~=true or type(data)~='table' then return false end
  local payload={}
  if kind~='offers' then
   if not text(data.id,64) or not int(data.revision,0) then return false end
   payload={id=data.id,revision=data.revision}
  end
  for key in pairs(data) do if key~='id' and key~='revision' then return false end end
  local now=api.now();if not int(now,0) then return false end
  local state=states[source]
  if not state then
   state={scope=copy(scope),at=now,tokens=4,recent={},order={}};states[source]=state
  end
  state.tokens=math.min(4,state.tokens+(now-state.at)%4294967296/1000);state.at=now
  if state.tokens<1 or state.busy then return false end
  state.tokens=state.tokens-1
  local ok,actor=pcall(api.actor,source)
  if not ok or not identity(actor) or (kind=='status' and not sameLogin(actor,scope))
   or (kind~='status' and not same(actor,scope)) then return false end
  -- Only an authenticated actor change may reset dedup state. Client-supplied
  -- fake session IDs must not replenish the source's rate budget.
  if not sameLogin(state.scope,actor) then state.scope=copy(actor);state.recent={};state.order={} end
  local cached=state.recent[id]
  if cached then
   if cached.kind~=kind or not same(cached.scope,scope) or cached.payload.id~=payload.id or cached.payload.revision~=payload.revision then return false end
   api.reply(source,id,copy(scope),copy(cached.result));return true
  end
  local entry={kind=kind,scope=copy(scope),payload=copy(payload),result={phase='pending'}}
  state.recent[id]=entry;state.order[#state.order+1]=id
  if #state.order>16 then state.recent[table.remove(state.order,1)]=nil end
  state.busy=true
  local called,result=pcall(function()
   if kind=='offers' then return api.offers(source) end
   return api[kind=='claim' and 'claim' or 'read'](source,copy(payload))
  end)
  state.busy=false
  local checked,after=pcall(api.actor,source)
  if states[source]~=state or not checked or not sameLogin(after,scope) or api.enabled()~=true then return false end
  -- Response projection deliberately excludes durable receipt metadata.
  if called and type(result)=='table' and (result.phase=='claimed' or result.phase=='refused' or result.phase=='pending' or result.phase=='updated') then
   local clean={phase=result.phase}
   if result.phase=='refused' and text(result.code,96) then clean.code=result.code end
   if text(result.id,64) then clean.id=result.id end
   if int(result.revision,0) then clean.revision=result.revision end
   if identity(result.identity) and same(result.identity,after) then clean.identity=copy(result.identity) end
   entry.result=clean
  end
  api.reply(source,id,copy(scope),copy(entry.result));return true
 end
 function T.Forget(source) states[source]=nil end
 return T
end
function WeaponNativeThrowablePickupTransport.Install(api)
 local handler=WeaponNativeThrowablePickupTransport.New(api)
 RegisterNetEvent('feather-weapons:server:throwable-pickup-request',function(id,scope,kind,data)
  local target=source
  handler.Handle(target,id,scope,kind,data)
 end)
 AddEventHandler('playerDropped',function() handler.Forget(source) end)
 return handler
end
