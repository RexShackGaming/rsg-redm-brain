-- Inactive placement admission. Only confirmed spent paid units can be bound.
-- Landing coordinates are proposals, not proof of projectile ownership.
WeaponNativeThrowablePickupPlacement={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function equal(a,b)
 if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function int(v,min) return finite(v) and v>=min and v%1==0 end
local function text(v,max) return type(v)=='string' and #v>0 and #v<=max and not v:find('%c') end
local function pos(v)
 if type(v)~='table' then return false end
 for _,k in ipairs({'x','y','z'}) do if not finite(v[k]) then return false end end;return true
end
local function identity(v) return type(v)=='table' and text(v.characterId,128) and text(v.sessionId,128) and text(v.epoch,128) end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowablePickupPlacement.New(api)
 for _,k in ipairs({'actor','spend','newId','persist','read','publish'}) do
  assert(type(api)=='table' and callable(api[k]),'Placement port required: '..k)
 end
 local reserved,count={},0
 local P={}
 local function refuse(code) return {phase='refused',code=code} end
 local function ready(state,record)
  if type(record)~='table' then return {phase='pending'} end
  local normalized=copy(record);normalized.phase='available';normalized.claimPlan=nil;normalized.claimResult=nil
  if not equal(normalized,state.binding) or (record.phase~='available' and record.phase~='claimed') then return {phase='pending'} end
  state.complete=true
  -- Rendering delivery is idempotent by pickupId; publication never grants.
  if record.phase=='available' then pcall(api.publish,copy(record)) end
  return {phase=record.phase,id=record.pickupId,revision=record.pickupRevision}
 end
 function P.Place(source,spec)
  if not int(source,1) or type(spec)~='table' or not int(spec.itemId,1) or not int(spec.itemRevision,0)
   or not text(spec.spendOperationId,40) or not pos(spec.position) then return refuse('invalid_placement') end
  local key=spec.itemId..':'..spec.itemRevision
  if reserved[key] then return {phase='pending'} end
  if count>=64 then return refuse('placement_capacity') end
  local state={source=source};reserved[key]=state;count=count+1
  local function denied(code) reserved[key]=nil;count=count-1;return refuse(code) end
  local ok,actor,spend=pcall(function() return api.actor(source),api.spend(source,spec.spendOperationId,spec.itemId) end)
  if not ok or not identity(actor) or actor.alive~=true or not int(actor.bucket,0) or not pos(actor.position)
   or type(spend)~='table' or spend.custody~='spent' or not equal(spend.origin,
    {characterId=actor.characterId,sessionId=actor.sessionId,epoch=actor.epoch})
   or spend.operationId~=spec.spendOperationId or spend.itemId~=spec.itemId or spend.itemRevision~=spec.itemRevision
   or type(spend.metadata)~='table' or spend.metadata.weaponDefinitionId~='throwable_tomahawk'
   or not text(spend.metadata.serialNumber,128) then return denied('confirmed_paid_spend_required') end
  local distance=0;for _,k in ipairs({'x','y','z'}) do distance=distance+(actor.position[k]-spec.position[k])^2 end
  if distance>2500 then return denied('landing_out_of_range') end
  actor,spend=copy(actor),copy(spend)
  local generated,id=pcall(api.newId)
  if not generated or not text(id,64) then return denied('pickup_id_unavailable') end
  state.identity=copy(spend.origin)
  state.binding={version=3,kind='paid_tomahawk_pickup',phase='available',pickupId=id,pickupRevision=0,
   bucket=actor.bucket,position=copy(spec.position),origin=copy(spend.origin),originEventId=id,
   spendOperationId=spend.operationId,itemId=spend.itemId,itemRevision=spend.itemRevision,metadata=copy(spend.metadata)}
  local function authority()
   local checked,a,s=pcall(function() return api.actor(source),api.spend(source,spend.operationId,spend.itemId) end)
   if not checked or not identity(a) or a.alive~=true or a.bucket~=actor.bucket or not pos(a.position)
    or not equal({characterId=a.characterId,sessionId=a.sessionId,epoch=a.epoch},state.identity) or not equal(s,spend) then return false end
   local d=0;for _,k in ipairs({'x','y','z'}) do d=d+(a.position[k]-state.binding.position[k])^2 end
   return reserved[key]==state and d<=2500
  end
  local committed,result=pcall(api.persist,source,copy(state.binding),authority)
  if not committed or type(result)~='table' then return {phase='pending'} end
  if result.phase=='refused' then return denied('binding_refused') end
  return ready(state,result)
 end
 function P.Read(source,spec)
  if type(spec)~='table' or not int(spec.itemId,1) or not int(spec.itemRevision,0) then return refuse('invalid_read') end
  local state=reserved[spec.itemId..':'..spec.itemRevision]
  if not state or state.source~=source or not state.binding then return refuse('no_matching_placement') end
  local ok,a=pcall(api.actor,source)
  if not ok or not identity(a) or not equal({characterId=a.characterId,sessionId=a.sessionId,epoch=a.epoch},state.identity) then return {phase='pending'} end
  local read,result=pcall(api.read,state.binding.pickupId)
  return read and ready(state,result) or {phase='pending'}
 end
 return P
end
