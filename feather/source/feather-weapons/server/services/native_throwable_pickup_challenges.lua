-- Server-local admission from a confirmed spend. A challenge is not a grant or
-- projectile ownership proof. Publication still requires the cleanup handshake.
WeaponNativeThrowablePickupChallenges={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function same(a,b) return type(a)=='table' and type(b)=='table' and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function int(v,min) return type(v)=='number' and v==v and v<math.huge and v>=min and v%1==0 end
local function text(v,max) return type(v)=='string' and #v>0 and #v<=max and not v:find('%c') end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowablePickupChallenges.New(api)
 for _,k in ipairs({'actor','spend','newId','send','now'}) do assert(callable(api[k]),'Challenge port required: '..k) end
 local seen,count={},0
 local C={}
 function C.Confirmed(source,identity,operationId,itemIds)
  if not int(source,1) or not same(identity,identity) or not text(identity.characterId,128)
   or not text(identity.sessionId,128) or not text(identity.epoch,128) or not text(operationId,40)
   or type(itemIds)~='table' or #itemIds<1 or #itemIds>3 then return false,'invalid_spend_challenge' end
  local key=identity.characterId..':'..operationId
  if seen[key] then return false,'spend_already_reserved' end
  if count>=256 then return false,'challenge_capacity' end
  -- Reserve before storage/UUID/send ports can yield or reenter.
  local state={source=source,identity=copy(identity),operationId=operationId,phase='preparing'}
  seen[key]=state;count=count+1
  local ok,reason=pcall(function()
   local actor=api.actor(source)
   assert(same(actor,identity) and actor.alive==true,'challenge_owner_changed')
   local units,ids={},{}
   for _,id in ipairs(itemIds) do
    assert(int(id,1) and not ids[id],'invalid_spent_item');ids[id]=true
    local row=api.spend(source,operationId,id)
    assert(type(row)=='table' and row.custody=='spent' and row.operationId==operationId
     and row.itemId==id and int(row.itemRevision,0) and same(row.origin,identity)
     and type(row.metadata)=='table' and row.metadata.weaponDefinitionId=='throwable_tomahawk'
     and text(row.metadata.serialNumber,128),'confirmed_paid_spend_required')
    units[#units+1]={itemId=id,itemRevision=row.itemRevision}
   end
   actor=api.actor(source)
   assert(same(actor,identity) and actor.alive==true,'challenge_owner_changed')
   local id=api.newId();assert(text(id,64),'challenge_id_unavailable')
   actor=api.actor(source)
   assert(same(actor,identity) and actor.alive==true,'challenge_owner_changed')
   state.id=id;state.units=units;state.started=api.now();state.phase='issued'
   api.send(source,{id=id,identity=copy(identity),operationId=operationId,units=copy(units),lifetimeMs=90000})
  end)
  if not ok then state.phase='review_required';return false,tostring(reason) end
  return true
 end
 function C.Read(source,id)
  for _,state in pairs(seen) do
   if state.source==source and state.id==id then
    local actor=api.actor(source)
    if not same(actor,state.identity) or actor.alive~=true then return nil end
    if (api.now()-state.started)%4294967296>=90000 then return nil end
    return copy(state)
   end
  end
 end
 return C
end
