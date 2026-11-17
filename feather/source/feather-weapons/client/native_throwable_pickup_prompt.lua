-- Constructed only by the future authoritative recovery route. No events,
-- threads, grants or manifest admission; visual offers are never ownership.
WeaponNativeThrowablePickupPrompt={}
local function copy(v)
 if type(v)~='table' then return v end
 local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out
end
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function text(v) return type(v)=='string' and #v>0 and #v<=96 and not v:find('%c') end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowablePickupPrompt.New(api)
 for _,key in ipairs({'world','create','remove','enable','show','completed','claim','readClaim','label'}) do
  assert(type(api)=='table' and callable(api[key]),'Pickup prompt port required: '..key)
 end
 local offers,prompt,pending,stopped,handoff={},nil,nil,false,nil
 local lastResult
 local function hide() if prompt then api.enable(prompt,false) end end
 local function clear() if prompt then api.remove(prompt);prompt=nil end end
 local function current()
  local w=api.world()
  if type(w)~='table' or w.alive~=true or w.busy==true or not text(w.characterId)
   or not text(w.sessionId) or not text(w.epoch) or not finite(w.bucket) or w.bucket%1~=0 or w.bucket<0
   or type(w.position)~='table' then return nil end
  for _,axis in ipairs({'x','y','z'}) do if not finite(w.position[axis]) then return nil end end
  return w
 end
 local function same(a,b)
  return a and b and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch
 end
 local function outcome(request,result)
  local now=current()
  if type(result)~='table' or not now then return end
  local sameLogin=now.characterId==request.identity.characterId and now.sessionId==request.identity.sessionId
  local fresh=sameLogin and result.phase=='claimed' and type(result.identity)=='table'
   and same(now,result.identity) and now.epoch~=request.identity.epoch
  if not same(now,request.identity) and not fresh then return end
  lastResult={phase=result.phase,id=request.id,code=result.code}
  if result.phase=='claimed' and result.id==request.id and result.revision==request.revision then
   offers[pending.id]=nil;pending=nil
   if fresh then handoff=copy(result.identity) end
  elseif result.phase=='refused' and same(now,request.identity) then pending=nil end
 end
 local P={}
 function P.Replace(rows)
  if stopped then return false end
  if type(rows)~='table' or #rows>64 then return false end
  local nextOffers={}
  for _,row in ipairs(rows) do
   if type(row)~='table' or not text(row.id) or nextOffers[row.id] or row.kind~='tomahawk'
    or not finite(row.revision) or row.revision<0 or row.revision%1~=0
    or not finite(row.bucket) or row.bucket<0 or row.bucket%1~=0 or type(row.position)~='table' then return false end
   for _,axis in ipairs({'x','y','z'}) do if not finite(row.position[axis]) then return false end end
   nextOffers[row.id]={id=row.id,revision=row.revision,bucket=row.bucket,position=copy(row.position)}
  end
  offers=nextOffers;return true
 end
 function P.Tick()
  if stopped then return 750 end
  local w=current()
  if pending or not w then hide();return 750 end
  local nearest,distance
  for _,row in pairs(offers) do
   if row.bucket==w.bucket then
    local d=0;for _,axis in ipairs({'x','y','z'}) do d=d+(row.position[axis]-w.position[axis])^2 end
    if d<=4 and (not distance or d<distance or d==distance and row.id<nearest.id) then nearest,distance=row,d end
   end
  end
  if not nearest then hide();return 750 end
  if not prompt then prompt=api.create(api.label('pickup'));assert(prompt,'Pickup prompt creation failed') end
  api.enable(prompt,true)
  if api.show(api.label('tomahawk'),copy(nearest))==false then hide();return 750 end
  if api.completed(prompt)==true then
   -- Reserve before the RPC can yield or recursively re-enter the UI.
   pending={id=nearest.id,revision=nearest.revision,identity={characterId=w.characterId,sessionId=w.sessionId,epoch=w.epoch}}
   hide()
   local request=copy(pending)
   local ok,result=pcall(api.claim,request)
   if ok and pending then outcome(request,result) end
  end
  return 0
 end
 function P.ReadPending()
  local now=current()
  if stopped or not pending or not now or now.characterId~=pending.identity.characterId
   or now.sessionId~=pending.identity.sessionId then return false end
  local request=copy(pending)
  local ok,result=pcall(api.readClaim,request)
  if ok and pending then outcome(request,result) end
  return pending==nil
 end
 function P.LanguageChanged() clear() end
 function P.Stop() hide();clear();stopped=true;offers={} end
 function P.Status() return {pending=copy(pending),stopped=stopped,handoff=copy(handoff),lastResult=copy(lastResult)} end
 return P
end
