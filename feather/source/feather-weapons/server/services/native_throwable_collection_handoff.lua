-- Server-only paid collection coordinator. Deliberately not registered in the
-- manifest: concrete native escrow and durable binding ports must be composed
-- before enabling this path. Correlation alone never authorizes an item grant.
WeaponNativeThrowableCollectionHandoff={}
local function copy(v)
 if type(v)~='table' then return v end
 local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r
end
local function equal(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function int(v,min) return type(v)=='number' and v>=min and v<math.huge and v%1==0 end
local function text(v) return type(v)=='string' and #v>0 and #v<=128 and not v:find('%c') end
local function identity(v) return type(v)=='table' and text(v.characterId) and text(v.sessionId) and text(v.epoch) end
local function same(a,b) return identity(a) and identity(b) and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowableCollectionHandoff.New(api)
 for _,k in ipairs({'actor','resolve','current','ticket','beginEscrow','readEscrow','bind','readBinding','claim','readClaim'}) do
  assert(type(api)=='table' and callable(api[k]),'Paid collection handoff port required: '..k)
 end
 local units,actors,tickets={},{},{}
 local count=0
 local H={}
 local function actor(source)
  local ok,value=pcall(api.actor,source)
  return ok and type(value)=='table' and value or nil
 end
 local function result(s)
  -- No metadata, serial, native GUID or authority callback in public status.
  return {phase=s.phase,reason=s.reason,ticket=s.ticket,itemId=s.itemId,itemRevision=s.itemRevision,
   bindingId=s.binding and s.binding.id,collector=copy(s.identity),identity=copy(s.restoredIdentity)}
 end
 local function hold(s,why) s.phase='review_required';s.reason=why;return result(s) end
 local function live(s)
  if actors[s.source]~=s or units[s.key]~=s then return false end
  if api.currentChecksActor==true then
   return api.current(copy(s.authorization),copy(s.identity))==true
  end
  local a=actor(s.source)
  if actors[s.source]~=s or units[s.key]~=s or not same(a,s.identity)
   or a.alive~=true or a.bucket~=s.bucket then return false end
  if api.current(copy(s.authorization),copy(s.identity))~=true then return false end
  a=actor(s.source) -- current may yield across resources
  return same(a,s.identity) and a.alive==true and a.bucket==s.bucket
 end
 local function finished(s,value)
  if type(value)~='table' or value.phase~='claimed' or value.id~=s.binding.id
   or value.revision~=s.binding.revision or value.itemId~=s.itemId or not same(value.collector,s.identity)
   or not identity(value.identity) or value.identity.characterId~=s.identity.characterId
   or value.identity.sessionId~=s.identity.sessionId then return false end
  local a=actor(s.source)
  if not same(a,value.identity) or a.alive~=true or a.bucket~=s.bucket then return false end
  s.phase='complete';s.restoredIdentity=copy(value.identity)
  -- Keep the canonical unit reservation and receipt forever in this host.
  -- A repeated event cannot spend/transfer it again; only the actor lock ends.
  if actors[s.source]==s then actors[s.source]=nil end
  return true
 end
 local function claim(s)
  if not live(s) then return hold(s,'collection_authority_changed') end
  s.phase='claim_pending' -- reserve before calling a yielding transaction port
  local ok,value=pcall(api.claim,s.source,copy(s.binding),copy(s.identity),function() return live(s) end)
  if ok and finished(s,value) then return result(s) end
  -- Even a definite economic refusal follows native cleanup. Retain the paid
  -- unit for review instead of silently publishing a second pickup or refund.
  if ok and type(value)=='table' and value.phase=='refused' then return hold(s,'paid_claim_refused') end
  return result(s)
 end
 local function bound(s,value)
  local expected=s.authorization.binding
  if type(value)~='table' or not equal(value,expected) then return false end
  s.binding=copy(value);return true
 end
 local function bind(s)
  if not live(s) then return hold(s,'collection_authority_changed') end
  s.phase='binding_pending'
  local ok,value=pcall(api.bind,copy(s.authorization),function() return live(s) end)
  if ok and bound(s,value) then return claim(s) end
  if ok and type(value)=='table' and value.phase=='refused' then return hold(s,'paid_binding_refused') end
  return result(s)
 end
 local function cleaned(s,value)
  return type(value)=='table' and value.phase=='cleaned' and value.ticket==s.ticket
   and same(value.identity,s.identity) and value.quantityBefore==1 and value.quantityAfter==0
   and value.guidCaptured==true and value.guidReleased==true and value.otherPoolsUnchanged==true
 end
 function H.Begin(source,observationId)
  if not int(source,1) or not text(observationId) then return {phase='refused',reason='invalid_request'} end
  if actors[source] then return result(actors[source]) end
  if count>=64 then return {phase='refused',reason='handoff_capacity'} end
  -- Reserve the actor before resolve can yield. Resolve must read the server's
  -- retained observation + confirmed spend; it never accepts client item IDs.
  local s={source=source,phase='admitting'};actors[source]=s
  local ok,a=pcall(api.resolve,source,observationId)
  local actor=actor(source)
  local b=ok and type(a)=='table' and a.binding
  if not b or a.kind~='paid_native_collection' or a.phase~='correlated'
   or not same(a.collector,actor) or actor.alive~=true or not int(actor.bucket,0)
   or a.bucket~=actor.bucket or not int(b.itemId,1) or not int(b.itemRevision,0)
   or not text(b.id) or not int(b.revision,0) or b.presentation~='native'
   or b.version~=4 or b.kind~='paid_tomahawk_native_pickup'
   or b.pickupId~=b.id or b.pickupRevision~=b.revision
   or b.phase~='available' or not same(b.origin,a.origin)
   or not identity(a.origin) or type(b.metadata)~='table'
   or b.metadata.weaponDefinitionId~='throwable_tomahawk' or not text(b.metadata.serialNumber) then
   actors[source]=nil;return {phase='refused',reason='paid_collection_not_authorized'}
  end
  local key=b.itemId..':'..b.itemRevision
  if units[key] then actors[source]=nil;return {phase='refused',reason='unit_already_reserved'} end
  s.authorization=copy(a);s.identity=copy(a.collector);s.bucket=a.bucket
  s.itemId=b.itemId;s.itemRevision=b.itemRevision;s.key=key
  units[key]=s;count=count+1
  local checked,current=pcall(live,s)
  if not checked or not current then return hold(s,'collection_authority_changed') end
  local issued,ticket=pcall(api.ticket,copy(a))
  if not issued or not text(ticket) or tickets[ticket] then return hold(s,'escrow_ticket_unavailable') end
  s.ticket=ticket;tickets[ticket]=s;s.phase='escrow_pending'
  -- A request is not cleanup proof. Only readEscrow may confirm the bounded,
  -- server-ticketed exact-GUID retirement and complete native baseline check.
  local sent,value=pcall(api.beginEscrow,source,ticket,copy(s.identity))
  if sent and value==false then return hold(s,'native_escrow_refused') end
  return result(s)
 end
 function H.Read(source,ticket)
  local s=tickets[ticket]
  if not s or s.source~=source then return {phase='refused',reason='unknown_handoff'} end
  if s.reading then return result(s) end
  if s.phase=='complete' or s.phase=='review_required' then return result(s) end
  -- Status can yield; serialize it so callbacks cannot request two binds or
  -- claims while the first read is still awaiting its receipt.
  s.reading=true
  local ok,value=pcall(function()
   if s.phase=='claim_pending' then
    local receipt=api.readClaim(source,copy(s.binding),copy(s.identity))
    if not finished(s,receipt) and type(receipt)=='table' and receipt.phase=='refused' then hold(s,'paid_claim_refused') end
    return result(s)
   end
   if not live(s) then return hold(s,'collection_authority_changed') end
   if s.phase=='binding_pending' then
    local receipt=api.readBinding(copy(s.authorization)) -- never call bind again
    if bound(s,receipt) then return claim(s) end
    if type(receipt)=='table' and receipt.phase=='refused' then return hold(s,'paid_binding_refused') end
   elseif s.phase=='escrow_pending' then
    local receipt=api.readEscrow(source,ticket,copy(s.identity))
    if cleaned(s,receipt) then return bind(s) end
    if type(receipt)=='table' and receipt.phase~='pending' then return hold(s,'native_escrow_unconfirmed') end
   end
   return result(s)
  end)
  s.reading=false
  -- An exception after a mutation request is uncertain, never permission to
  -- replay that mutation. Subsequent reads consult only the matching receipt.
  return ok and value or result(s)
 end
 return H
end
