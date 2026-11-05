Config={AmmunitionPools={enabled=false},DevMode=true,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,
 CharacterAmmoTransportEnabled=true,NativeAlphaCharacterId='john',NativeAlphaLifecycleWearEnabled=true}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/native_knife.lua',
 'shared/character_lifecycle_wear.lua'}) do dofile(p) end
local commands,events,registered={},{},{}
RegisterCommand=function(n,f) commands[n]=f end
RegisterNetEvent=function(n,f) events[n]=f end
AddEventHandler=function() end
SetTimeout=function() end
GetGameTimer=function() return 100 end
GetResourceState=function() return 'stopped' end
local flag=1
GetConvarInt=function(n) return n=='feather_native_knife' and flag or 0 end
GetInvokingResource=function() return 'feather-inventory' end
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='john',sessionId='s'}} end,
 IsSessionCurrent=function(_,sid,cid) return sid=='s' and cid=='john' end}
WeaponCharacterAmmoService={ValidateLoadout=function() return {ok=true} end}
local id={characterId='john',sessionId='s',epoch='e1'}
local state={phase='active',identity=id}
local request,writes,assigned,starts=nil,0,false,0
local reply
local row={id=90,revision=0,itemName='weapon_melee_knife',metadata=assert(WeaponNativeKnife.Build(
 WeaponDefinitionCatalog.weapons.melee_knife,{serialNumber='KNIFE'}))}
TriggerClientEvent=function(name,_,value,scope,result)
 if name=='feather-weapons:client:native-equipment-release' then request=value
 elseif name=='feather-weapons:client:native-equipment-result' then reply=result end
end
exports=setmetatable({['feather-inventory']={
 ReadNativeEquipmentTransition=function(_,context,item)
  local expected=assigned and {weapon_melee={itemId=90,revision=0}} or {}
  return {ok=true,value={characterId='john',expected=expected,equipment={},candidate=item and row or nil,
   knifeEquipment={characterId='john',expected=expected,equipment=assigned and {melee=row} or {}},
   brokenEquipmentContract=1,brokenPromotionContract=1}}
 end,
 CommitNativeKnifeEquipment=function(_,context,spec)
  assert(state.phase=='released' and registered.ValidateNativeEquipmentCommit(context,spec))
  assert(spec.knifeId==90 and spec.slot=='weapon_melee' and #spec.lifecycleWear==0)
  assigned=spec.action=='equip'; writes=writes+1; return {ok=true,value={}}
 end}}, {__call=function(_,name,fn) registered[name]=fn end})
WeaponCharacterAmmoDispatcher={Status=function() return state end,Start=function()
 starts=starts+1; local bundle={}; WeaponNativeEquipmentBindings.Attach(3,bundle)
 assert(bundle.equipmentTransition.ticket==request.ticket)
 id={characterId='john',sessionId='s',epoch='e'..(starts+1)}
 state={phase='restoring',identity=id}; return {ok=true,value=id}
end}
dofile('server/services/native_equipment_transition.lua')
local function finish()
 local old=request.identity; state={phase='released',identity=old}; source=3
 events['feather-weapons:server:native-equipment-released'](request.ticket,old,true,{epoch=old.epoch,items={}})
 assert(state.phase=='restoring')
 state={phase='active',identity=id}
 events['feather-weapons:server:native-equipment-restored'](request.ticket,id)
 assert(not registered.ValidateNativeEquipmentCommit({actorSource=3},{}),'ticket cannot outlive completion')
end
flag=0; commands.WeaponNativeEquipmentChange(0,{'3','equip','weapon_melee','90'}); assert(not request and writes==0)
flag=1; commands.WeaponNativeEquipmentChange(0,{'3','equip','weapon_melee','90'})
assert(request and writes==0,'no write before exact release')
finish(); assert(assigned and writes==1)
commands.WeaponNativeEquipmentChange(0,{'3','unequip','weapon_melee'})
assert(writes==1); finish(); assert(not assigned and writes==2 and starts==2)
print('knife real reserved transition PASS (default-off preflight, exact release/final wear, canonical commit, restore ack/ticket retirement)')
source=3
events['feather-weapons:server:native-equipment-ui']('knife-options','options',{itemId=90,scope=id})
assert(reply.ok and #reply.value.options==1 and reply.value.options[1].slot=='weapon_melee' and reply.value.options[1].action=='equip')
events['feather-weapons:server:native-equipment-ui']('knife-equip','change',{itemId=90,scope=id,action='equip',slot='weapon_melee'})
assert(writes==2); finish(); assert(writes==3 and assigned)
events['feather-weapons:server:native-equipment-ui']('knife-options2','options',{itemId=90,scope=id})
assert(reply.ok and #reply.value.options==1 and reply.value.options[1].action=='unequip')
events['feather-weapons:server:native-equipment-ui']('knife-unequip','change',{itemId=90,scope=id,action='unequip',slot='weapon_melee'})
finish(); assert(writes==4 and not assigned)
print('knife normal UI routing PASS (server options, selected item/slot, same reserved transition, no knife repair/ammo options)')
