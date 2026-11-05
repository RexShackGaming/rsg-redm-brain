dofile('shared/constants.lua') -- shared enrollment dependency from normal manifest
exports=function() end
Config={DevMode=false,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,NativeAlphaCharacterId='Jane'}
local events,commands,sent,timers={},{},{},{}
RegisterNetEvent=function(name,fn) events[name]=fn end
RegisterCommand=function(name,fn) commands[name]=fn end
AddEventHandler=function(name,fn) events[name]=fn end
SetTimeout=function(_,fn) timers[#timers+1]=fn end
GetResourceState=function() return 'stopped' end
GetGameTimer=function() return 10 end
TriggerClientEvent=function(name,target,request) sent[#sent+1]={name=name,target=target,request=request} end
local old={characterId='Jane',sessionId='s',epoch='old'}
local new={characterId='Jane',sessionId='s',epoch='new'}
local state={phase='active',identity=old}
local starts=0
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='Jane',sessionId='s'}} end,
 IsSessionCurrent=function(source,sid,char) return source==5 and sid=='s' and char=='Jane' end}
WeaponCharacterAmmoDispatcher={Status=function() return state end,Start=function(target)
 assert(target==5 and state.phase=='released')
 starts=starts+1
 local bundle={runtime=new}
 WeaponNativeEquipmentBindings.Attach(target,bundle)
 assert(bundle.equipmentTransition.ticket==sent[1].request.ticket and bundle.equipmentTransition.oldEpoch=='old')
 state={phase='restoring',identity=new}
 return {ok=true,value=new}
end}
local originalPrint=print
local output={}
print=function(v) output[#output+1]=v end
dofile('server/services/native_equipment_transition.lua')
commands.WeaponNativeEquipmentDryRun(0,{'5'}); assert(#sent==0)
Config.DevMode=true
commands.WeaponNativeEquipmentDryRun(1,{'5'}); assert(#sent==0)
commands.WeaponNativeEquipmentDryRun(0,{'5'}); assert(#sent==1 and starts==0)
local ticket=sent[1].request.ticket
source=7; events['feather-weapons:server:native-equipment-released'](ticket,old,true); assert(starts==0)
source=5
state={phase='released',identity=old}
events['feather-weapons:server:native-equipment-released'](ticket,old,true)
assert(starts==1)
events['feather-weapons:server:native-equipment-released'](ticket,old,true); assert(starts==1)
state={phase='active',identity=new}
events['feather-weapons:server:native-equipment-restored'](ticket,new)
assert(output[#output]:find('PASS final seal/owned cleanup/server release',1,true))
timers[1]()
commands.WeaponNativePrepareStop(0,{'5'})
assert(starts==1 and #sent==2 and not WeaponNativeEquipmentBindings.IsStopping(5))
commands.WeaponNativePrepareStop(0,{'5'}); assert(#sent==2,'duplicate prepare-stop cannot dispatch again')
local shutdownTicket=sent[2].request.ticket
state={phase='released',identity=new}
events['feather-weapons:server:native-equipment-released'](shutdownTicket,new,true)
assert(starts==1 and WeaponNativeEquipmentBindings.IsStopping(5),'prepared shutdown does not rebuild')
assert(output[#output]:find('[WeaponNativePrepareStop] PASS',1,true))
-- Execute the real dispatcher Start wrapper: even trusted readiness must not
-- create another native owner after an orderly shutdown has been prepared.
local startsAfterPark=0
local equipmentLeft=events['core.session.left.v1']
WeaponCharacterAmmoDispatch={New=function() return {Start=function() startsAfterPark=startsAfterPark+1 end} end}
WeaponCharacterAmmoActivation={New=function() return {} end}
dofile('server/services/character_ammunition_dispatch.lua')
assert(WeaponCharacterAmmoDispatcher.Start(5).error.code=='native_shutdown_prepared' and startsAfterPark==0)
equipmentLeft({source=5,sessionId='other'})
assert(WeaponNativeEquipmentBindings.IsStopping(5),'old session must not clear stop parking')
equipmentLeft({source=5,sessionId='s'})
assert(not WeaponNativeEquipmentBindings.IsStopping(5),'matching logout retires stop parking')
print=originalPrint
print('Native equipment dry-run bindings PASS (console/alpha gates, source binding, authoritative release, fresh dispatch/restore)')
