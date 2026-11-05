local registered,events={},{ }
Config={DevMode=false,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true}
local scope={characterId='Jane',sessionId='s',epoch='e1'}
local clock=0
local world={characterId='Jane',sessionId='s',ped=10}
WeaponCharacterAmmoWorldContext={Read=function() return world and {ok=true,value=world} or {ok=false} end}
WeaponCharacterAmmoActiveOwner={Status=function() return {bootstrap={runtime={phase='active',session={ammo={phase='active',ped=10,baseline=scope}}}}} end}
local caller='feather-inventory'
GetInvokingResource=function() return caller end
exports=function(name,fn) registered[name]=fn end
RegisterNetEvent=function(name,fn) events[name]=fn end
GetGameTimer=function() return clock end
local sent=0
local mode='reply'
Wait=function(ms) clock=clock+ms end
TriggerServerEvent=function(_,id,kind,intent)
 if kind=='attachment-change' then assert(intent.attachmentId=='carbine_wide_sight') end
 sent=sent+1
 source=1; events['feather-weapons:client:native-equipment-result'](id,intent.scope,{ok=true,value={identity=scope}})
 if mode=='timeout' then return end
 if mode=='world-loss' then world=nil; return end
 local old=intent.scope
 if kind=='change' then scope={characterId='Jane',sessionId='s',epoch='e2'} end
 source=65535
 events['feather-weapons:client:native-equipment-result'](id,old,{ok=true,value={identity=scope,options={}}})
end
dofile('client/native_equipment_actions.lua')
caller='foreign'; assert(not registered.GetNativeEquipmentControls(112).ok and sent==0); caller='feather-inventory'
assert(registered.GetNativeEquipmentControls(112).ok and sent==1)
local old=scope
assert(registered.ChangeNativeEquipment(112,'unequip','weapon',scope).ok)
assert(not registered.ChangeNativeEquipment(112,'equip','weapon',old).ok and sent==2)
caller='foreign'
assert(not registered.ChangeNativeAttachment(901,'install',scope).ok and sent==2)
caller='feather-inventory'
assert(not registered.ChangeNativeAttachment(901,'install',old).ok and sent==2,'stale attachment panel cannot dispatch')
assert(not registered.ChangeNativeAttachment(901,'invalid',scope).ok and sent==2)
assert(not registered.ChangeNativeAttachment(901,'install',scope,{}).ok and sent==2)
assert(registered.ChangeNativeAttachment(901,'install',scope,'carbine_wide_sight').ok and sent==3)
assert(not registered.RepairNativeEquipment(901,old).ok and sent==3)
assert(registered.RepairNativeEquipment(901,scope).ok and sent==4)
mode='timeout'; assert(not registered.GetNativeEquipmentControls(112).ok and clock>=50000,'forged client-origin reply cannot complete')
mode='world-loss'; assert(not registered.GetNativeEquipmentControls(112).ok)
print('Native equipment client UI PASS (caller/current scope, trusted reply, new-epoch settle, timeout, lifecycle loss)')
