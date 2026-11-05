local commands,events,timers={},{},{}
Config={DevMode=true,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaCharacterId='Jane',NativeAlphaLifecycleWearEnabled=true}
dofile('shared/constants.lua')
RegisterCommand=function(n,f) commands[n]=f end
RegisterNetEvent=function(n,f) events[n]=f end
AddEventHandler=function(n,f) events[n]=f end
SetTimeout=function(ms,f) if ms==500 then timers[#timers+1]=f end end
GetGameTimer=function() return 0 end
GetPlayers=function() return {'1'} end
GetResourceState=function() return 'stopped' end
exports=setmetatable({}, {__call=function() end})
local id={characterId='Jane',sessionId='s',epoch='e'}
CoreAdapter={ResolveSession=function() return {ok=true,value=id} end}
WeaponCharacterAmmoDispatcher={Status=function() return {phase='active',identity=id} end}
local output
json={encode=function(s) output=s; return 'status' end}
dofile('server/services/native_equipment_transition.lua')
assert(not WeaponNativeEquipmentBindings.IsStopping(1))
commands.WeaponNativePrepareStopAll(1,{})
assert(not WeaponNativeEquipmentBindings.IsStopping(1),'client cannot latch')
commands.WeaponNativePrepareStopAll(0,{'unexpected'})
assert(not WeaponNativeEquipmentBindings.IsStopping(1),'invalid args cannot latch')
commands.WeaponNativePrepareStopAll(0,{})
assert(WeaponNativeEquipmentBindings.IsStopping(1) and WeaponNativeEquipmentBindings.IsStopping(999),
 'latch blocks every dispatcher Start, including newly joining sources')
commands.WeaponNativeShutdownStatus(0,{})
assert(output.phase=='draining' and output.total==1)
-- Missing Inventory adapter makes release fail closed; no automatic retry/reset.
table.remove(timers,1)()
commands.WeaponNativeShutdownStatus(0,{})
assert(output.phase=='failed' and WeaponNativeEquipmentBindings.IsStopping(1))
print('Native global shutdown command binding PASS (console/args gates, admission latch, refused release retained)')
