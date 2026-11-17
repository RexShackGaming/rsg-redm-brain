-- Exercise concrete startup admission without registering a partial service.
local registered,threads,installed=0,0,0
local exportFns={}
dofile('server/services/native_throwable_pickup_challenges.lua')
dofile('server/services/native_throwable_placement_handshake.lua')
dofile('server/services/native_throwable_transition_binding.lua')
dofile('server/services/native_throwable_transition_protocol.lua')
RegisterNetEvent=function() end
exports=setmetatable({}, {__call=function(_,name,fn) registered=registered+1;exportFns[name]=fn end})
Config={}
local units=false
WeaponNativeThrowablePolicy={UnitsEnabled=function() return units end}
local toolkit='stopped'
GetResourceState=function(name) assert(name=='feather-toolkit');return toolkit end
WeaponNativeThrowablePickupBackend={New=function()
 installed=installed+1
 return {InstallTransport=function() end,Forget=function() end,Step=function() end}
end}
AddEventHandler=function() end
CreateThread=function() threads=threads+1 end
dofile('server/services/native_throwable_pickup_server.lua')
assert(registered==1 and WeaponNativeThrowablePickupServer.Start())
assert(not WeaponNativeThrowablePickupServer.Ready() and installed==0 and threads==0)
units=true
local ok,reason=WeaponNativeThrowablePickupServer.Start()
assert(not ok and reason=='pickup_client_contract_required' and installed==0)
Config.NativeThrowablePickupContract=1
ok,reason=WeaponNativeThrowablePickupServer.Start()
assert(not ok and reason=='pickup_toolkit_required' and installed==0)
toolkit='started'
ok,reason=WeaponNativeThrowablePickupServer.Start()
assert(not ok and reason=='pickup_nettype_native_required' and installed==0)
GetNetTypeFromEntity=function() return 8 end
assert(WeaponNativeThrowablePickupServer.Start() and WeaponNativeThrowablePickupServer.Ready())
assert(installed==1 and threads==1)
assert(WeaponNativeThrowablePickupServer.Start() and installed==1)
units=false
assert(not WeaponNativeThrowablePickupServer.Ready())
print('PASS concrete pickup host: disabled default, matching client contract and Toolkit admission, single installation and live gate revocation')
units=true
local nativeGate=0
GetConvarInt=function() return nativeGate end
Config.NativeThrowableNativeCollectionContract=1
GetInvokingResource=function() return 'feather-inventory' end
local service={ValidateBinding=function(source,record) return source==1 and record.token=='reserved' end}
assert(not WeaponNativeThrowablePickupServer.AttachNativeCollection(service))
nativeGate=1
assert(not exportFns.ValidateNativeThrowablePickupStorage('native-binding'),'feature flag cannot replace attached writer')
assert(WeaponNativeThrowablePickupServer.AttachNativeCollection(service))
assert(not WeaponNativeThrowablePickupServer.AttachNativeCollection(service),'writer cannot be replaced')
assert(exportFns.ValidateNativeThrowablePickupStorage('native-binding'))
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='jane',sessionId='session'}} end,
 IsSessionCurrent=function() return true end}
WeaponCharacterAmmoDispatcher={Status=function() return {identity={characterId='jane',sessionId='session',epoch='epoch'}} end}
GetPlayerPed=function() return 7 end;DoesEntityExist=function() return true end
GetEntityCoords=function() return {x=0,y=0,z=0} end;GetPlayerRoutingBucket=function() return 0 end
local medicalReads=0
exports['feather-medical']={ReadNativeWeaponCondition=function() medicalReads=medicalReads+1;return {ok=true,value={lifeState='alive'}} end}
local bound={actorSource=1,characterId='jane',sessionId='session',epoch='epoch'}
assert(exportFns.ValidateNativeThrowablePickupStorage('native-bind',bound,{token='reserved'}))
assert(medicalReads==0,'native binding delegates Medical to the exact reserved writer instead of querying it twice')
assert(not exportFns.ValidateNativeThrowablePickupStorage('native-bind',bound,{token='forged'}))
bound.epoch='stale';assert(not exportFns.ValidateNativeThrowablePickupStorage('native-bind',bound,{token='reserved'}))
nativeGate=0;assert(not exportFns.ValidateNativeThrowablePickupStorage('native-binding'))
print('PASS native storage host admission: default-off, single server writer, exact reservation/current epoch and live gate revocation')
