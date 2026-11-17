-- Concrete server ports; normal admission remains behind the staged units gate.
WeaponNativeThrowablePickupServer={}
local S=WeaponNativeThrowablePickupServer
local backend,challenges,ready=nil,nil,false
local nativeCollection
local function nativeEnabled()
 return ready and nativeCollection and Config.NativeThrowableNativeCollectionContract==1
  and type(GetConvarInt)=='function' and GetConvarInt('feather_native_paid_collection',0)==1
end
local function enabled() return ready and WeaponNativeThrowablePolicy.UnitsEnabled() end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function same(a,b) return a and b and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function value(result)
 if type(result)~='table' or result.ok~=true then error('pickup_storage_unavailable') end
 return result.value
end
local function actor(source)
 local session=CoreAdapter.ResolveSession(source)
 local state=WeaponCharacterAmmoDispatcher.Status(source)
 local bound=state and state.identity
 if not session or not session.ok or not bound or bound.characterId~=session.value.characterId
  or bound.sessionId~=session.value.sessionId then return nil end
 local ped=GetPlayerPed(source)
 if not ped or ped==0 or not DoesEntityExist(ped) then return nil end
 local medical=exports['feather-medical']:ReadNativeWeaponCondition(source,
  {characterId=bound.characterId,sessionId=bound.sessionId})
 if not medical or not medical.ok or not CoreAdapter.IsSessionCurrent(source,bound.sessionId,bound.characterId) then return nil end
 local position=GetEntityCoords(ped)
 return {characterId=bound.characterId,sessionId=bound.sessionId,epoch=bound.epoch,
  alive=medical.value.lifeState=='alive',bucket=GetPlayerRoutingBucket(source),
  position={x=position.x,y=position.y,z=position.z}}
end
local function context(source)
 local a=actor(source);if not a then return nil end
 return {resource='feather-weapons',actorSource=source,characterId=a.characterId,sessionId=a.sessionId,epoch=a.epoch}
end
exports('ValidateNativeThrowablePickupStorage',function(kind,bound,record)
 if GetInvokingResource()~='feather-inventory' or not enabled() then return false end
 if kind=='native-binding' then return nativeEnabled() and true or false end
 if kind=='page' or kind=='binding' then return true end
 if type(bound)~='table' or type(bound.actorSource)~='number' then return false end
 if kind=='native-bind' then
  -- The reserved writer checks fresh Medical for origin and collector. Verify
  -- the supplied origin scope here without repeating that same Medical query.
  local session=CoreAdapter.ResolveSession(bound.actorSource)
  local state=WeaponCharacterAmmoDispatcher.Status(bound.actorSource)
  if not nativeEnabled() or not session or not session.ok or not state or not same(state.identity,bound)
   or session.value.characterId~=bound.characterId or session.value.sessionId~=bound.sessionId
   or not CoreAdapter.IsSessionCurrent(bound.actorSource,bound.sessionId,bound.characterId) then return false end
  return nativeCollection.ValidateBinding(bound.actorSource,record)==true
 end
 local current=context(bound.actorSource)
 if not same(current,bound) then return false end
 if kind=='spend' then return true end -- reader itself verifies the exact receipt's origin
 if kind=='bind' then return backend.ValidateBinding(bound.actorSource,record) end
 return false
end)
function S.Ready() return enabled() end
-- Server-local installation only. No net event/export can replace this writer.
function S.AttachNativeCollection(service)
 if nativeCollection or type(service)~='table' or type(service.ValidateBinding)~='function'
  or Config.NativeThrowableNativeCollectionContract~=1 or type(GetConvarInt)~='function'
  or GetConvarInt('feather_native_paid_collection',0)~=1 then return false end
 nativeCollection=service;return true
end
function S.ConfirmedSpend(source,bound,operationId,itemIds)
 if not enabled() or not challenges then return false,'pickup_not_ready' end
 return challenges.Confirmed(source,bound,operationId,itemIds)
end
function S.Start()
 if ready then return true end
 if not WeaponNativeThrowablePolicy.UnitsEnabled() then return true end
 -- Do not activate a server-only half of the feature. Client wiring must ship
 -- the same contract before this gate can be admitted in a deployment.
 if Config.NativeThrowablePickupContract~=1 then return false,'pickup_client_contract_required' end
 if GetResourceState('feather-toolkit')~='started' then return false,'pickup_toolkit_required' end
 if type(GetNetTypeFromEntity)~='function' then return false,'pickup_nettype_native_required' end
 backend=WeaponNativeThrowablePickupBackend.New({enabled=enabled,actor=actor,
  now=function() return GetGameTimer()%4294967296 end,wait=Wait,
  readBinding=function(id) return value(exports['feather-inventory']:ReadNativeThrowablePromptBinding(id)) end,
  readPage=function(cursor) return value(exports['feather-inventory']:ReadNativeThrowablePromptPage(cursor)) end,
  readSpent=function(source,operationId,itemId)
   local bound=context(source);if not bound then return nil end
   return value(exports['feather-inventory']:ReadNativeThrowableSpentUnit(bound,operationId,itemId))
  end,
  newId=function() return 'tomahawk:'..assert(DB.value('SELECT UUID()')) end,
  persistBinding=function(source,record)
   local bound=context(source);if not bound then return {phase='refused'} end
   local result=exports['feather-inventory']:BindNativeThrowablePromptPickup(bound,record)
   if not result or result.ok~=true then
    -- A failed driver call may have committed. Keep pending for receipt reads.
    if result and result.error and result.error.code=='pickup_storage_denied' then return {phase='refused'} end
    return {phase='pending'}
   end
   return result.value.binding
  end,
  beginPickup=function(...) return WeaponNativeEquipmentBindings.PickupTransition(...) end,
  pickupStatus=function(...) return WeaponNativeEquipmentBindings.PickupTransitionStatus(...) end,
  sendOffers=function(source,snapshot) TriggerClientEvent('feather-weapons:client:throwable-pickup-offers',source,snapshot) end,
  reply=function(source,id,scope,result) TriggerClientEvent('feather-weapons:client:throwable-pickup-result',source,id,scope,result) end})
 challenges=WeaponNativeThrowablePickupChallenges.New({actor=actor,
  now=function() return GetGameTimer()%4294967296 end,
  newId=function() return 'throw:'..assert(DB.value('SELECT UUID()')) end,
  spend=function(source,operationId,itemId)
   local bound=context(source);if not bound then return nil end
   return value(exports['feather-inventory']:ReadNativeThrowableSpentUnit(bound,operationId,itemId))
  end,
  send=function(source,packet) TriggerClientEvent('feather-weapons:client:throwable-spend-challenge',source,packet) end})
 ready=true
 if Config.NativeThrowableNativeCollectionContract==1 and type(GetConvarInt)=='function' and GetConvarInt('feather_native_paid_collection',0)==1 then
  assert(WeaponNativeThrowableCollectionHost.Start({actor=actor,attach=S.AttachNativeCollection,
   limits=function() return assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)).limits end,
   challenge=function(source,id) return challenges.Read(source,id) end,
   spend=function(source,operationId,itemId)
    local bound=context(source);if not bound then return nil end
    return value(exports['feather-inventory']:ReadNativeThrowableSpentUnit(bound,operationId,itemId))
   end,
   read=function(handle)
    if not DoesEntityExist(handle) then return {exists=false} end
    return {exists=true,netType=GetNetTypeFromEntity(handle),networkId=NetworkGetNetworkIdFromEntity(handle),
     owner=NetworkGetEntityOwner(handle),bucket=GetEntityRoutingBucket(handle)}
   end}),'native_collection_host_failed')
 end
 local transport=backend.InstallTransport()
 local transition=WeaponNativeThrowableTransitionProtocol.New({actor=actor,later=SetTimeout,
  challenge=function(source,id) return challenges.Read(source,id) end,
  spend=function(source,operationId,itemId)
   local bound=context(source);if not bound then return nil end
   return value(exports['feather-inventory']:ReadNativeThrowableSpentUnit(bound,operationId,itemId))
  end,
  read=function(handle)
   if not DoesEntityExist(handle) then return {exists=false} end
   return {exists=true,netType=GetNetTypeFromEntity(handle),networkId=NetworkGetNetworkIdFromEntity(handle),
    owner=NetworkGetEntityOwner(handle),bucket=GetEntityRoutingBucket(handle)}
  end,
  newId=function() return 'cleanup:'..assert(DB.value('SELECT UUID()')) end,
  now=function() return GetGameTimer()%4294967296 end,
  place=backend.Place,readPlacement=backend.ReadPlacement})
 AddEventHandler('entityCreated',function(handle) if enabled() then transition.Created(handle) end end)
 AddEventHandler('entityRemoved',function(handle) if enabled() then transition.Removed(handle) end end)
 local rates={}
 RegisterNetEvent('feather-weapons:server:throwable-placement-request',function(action,request)
  local player=source
  if not enabled() or type(player)~='number' or type(request)~='table' then return end
  local now=GetGameTimer()%4294967296;local rate=rates[player]
  if not rate or (now-rate.started)%4294967296>=1000 then rate={started=now,count=0};rates[player]=rate end
  if rate.count>=4 then return end;rate.count=rate.count+1
  local ok,result=pcall(transition.Handle,player,action,request)
  if type(request.id)=='string' and #request.id<=64 and challenges.Read(player,request.id) then
   local response=ok and result or {phase='pending',id=request.id}
   TriggerClientEvent('feather-weapons:client:throwable-placement-result',player,action,request.id,response)
  end
 end)
 AddEventHandler('playerDropped',function() rates[source]=nil end)
 AddEventHandler('playerDropped',function() backend.Forget(source) end)
 CreateThread(function()
  while enabled() do
   local ok,why=pcall(backend.Step)
   if not ok then print('[feather-weapons] pickup offer reload unavailable; prior snapshot retained') end
   Wait(1000)
  end
 end)
 return true
end
-- Full transition protocol remains behind the closed combined live contract;
-- native acceptance must pass before enabling ordinary paid units.
