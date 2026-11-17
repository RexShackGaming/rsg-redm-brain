-- Transport only. Construction/registration is explicit; no native or economic
-- writes and no implicit retry of a claim after timeout.
WeaponNativeThrowablePickupClientTransport={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function text(v,max) return type(v)=='string' and #v>0 and #v<=max and not v:find('%c') end
local function identity(v) return type(v)=='table' and text(v.characterId,128) and text(v.sessionId,128) and text(v.epoch,128) end
local function sameLogin(a,b) return a and b and a.characterId==b.characterId and a.sessionId==b.sessionId end
local function same(a,b) return sameLogin(a,b) and a.epoch==b.epoch end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowablePickupClientTransport.New(api)
 for _,key in ipairs({'world','now','wait','send','register'}) do assert(type(api)=='table' and callable(api[key]),'Pickup client transport port required: '..key) end
 local sequence,pending,stopped=0,nil,false
 local function pendingResult() return {phase='pending'} end
 api.register(function(serverSource,id,scope,result)
  if stopped or serverSource~=65535 or not pending or pending.id~=id or not same(scope,pending.scope)
   or type(result)~='table' then return false end
  if result.phase~='claimed' and result.phase~='refused' and result.phase~='pending' and result.phase~='updated' then return false end
  pending.result=copy(result);return true
 end)
 local P={}
 function P.Call(kind,data,prior)
  if stopped or pending then return pendingResult() end
  if kind~='claim' and kind~='status' and kind~='offers' then return {phase='refused'} end
  local world=api.world();local scope=prior or world
  if not identity(world) or not identity(scope) or not sameLogin(world,scope)
   or kind~='status' and not same(world,scope) then return {phase='refused'} end
  if type(data)~='table' then return {phase='refused'} end
  local clean={}
  if kind~='offers' then
   if not text(data.id,64) or type(data.revision)~='number' or data.revision<0 or data.revision>=math.huge
    or data.revision%1~=0 then return {phase='refused'} end
   clean={id=data.id,revision=data.revision}
  end
  local started=api.now()
  if type(started)~='number' or started~=started or started<0 or started>=math.huge then return pendingResult() end
  sequence=sequence+1
  local request={id=('pickup:%s:%s'):format(started,sequence),scope={characterId=scope.characterId,sessionId=scope.sessionId,epoch=scope.epoch}}
  pending=request
  local called,result=pcall(function()
   api.send(request.id,copy(request.scope),kind,clean)
   while not stopped and pending==request and (api.now()-started)%4294967296<50000 do
    if not sameLogin(api.world(),request.scope) then return pendingResult() end
    if request.result then
     local answer=request.result
     if answer.phase=='claimed' then
      local now=api.world()
      if answer.id~=clean.id or answer.revision~=clean.revision
       or not identity(answer.identity) or not same(now,answer.identity) then return pendingResult() end
     end
     return answer
    end
    api.wait(50)
   end
   return pendingResult()
  end)
  if pending==request then pending=nil end
  return called and result or pendingResult()
 end
 function P.Stop() stopped=true end
 return P
end
function WeaponNativeThrowablePickupClientTransport.Install(world)
 return WeaponNativeThrowablePickupClientTransport.New({world=world,now=function() return GetGameTimer()%4294967296 end,wait=Wait,
  register=function(handler)
   RegisterNetEvent('feather-weapons:client:throwable-pickup-result',function(id,scope,result)
    handler(source,id,scope,result)
   end)
  end,
  send=function(id,scope,kind,data) TriggerServerEvent('feather-weapons:server:throwable-pickup-request',id,scope,kind,data) end})
end
