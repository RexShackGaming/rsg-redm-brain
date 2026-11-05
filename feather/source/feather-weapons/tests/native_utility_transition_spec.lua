Config={AmmunitionPools={enabled=false},DevMode=true,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,
 CharacterAmmoTransportEnabled=true,NativeAlphaCharacterId='john',NativeAlphaLifecycleWearEnabled=true}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/native_utility_catalog.lua',
 'shared/native_utility_item.lua','shared/character_lifecycle_wear.lua'}) do dofile(p) end
local commands,events,registered={},{},{}
RegisterCommand=function(n,f) commands[n]=f end; RegisterNetEvent=function(n,f) events[n]=f end
AddEventHandler=function() end; SetTimeout=function() end; GetGameTimer=function() return 100 end
GetResourceState=function() return 'stopped' end
local gate,reinforcedGate=0,0
GetConvarInt=function(n) return n=='feather_native_utility' and gate or n=='feather_native_lasso_reinforced' and reinforcedGate or 0 end
GetInvokingResource=function() return 'feather-inventory' end
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='john',sessionId='s'}} end,
 IsSessionCurrent=function(_,sid,cid) return sid=='s' and cid=='john' end}
WeaponCharacterAmmoService={ValidateLoadout=function() return {ok=true} end}
local id={characterId='john',sessionId='s',epoch='e1'}
local state={phase='active',identity=id}
local request,writes,assigned,starts=nil,0,false,0
local reply
local row={id=200,revision=0,itemName='weapon_lasso',metadata={schemaVersion=2,weaponDefinitionId='utility_lasso',
 serialNumber='L',condition=100,quality=100,flags={stolen=false,evidence=false,disabled=false},attachments={},cosmetics={},provenance={}}}
local assignedRow,assignedSlot
TriggerClientEvent=function(name,_,value,scope,result)
 if name=='feather-weapons:client:native-equipment-release' then request=value
 elseif name=='feather-weapons:client:native-equipment-result' then reply=result end
end
exports=setmetatable({['feather-inventory']={
 ReadNativeEquipmentTransition=function(_,context,item)
  local expected=assigned and {[assignedSlot]={itemId=assignedRow.id,revision=0}} or {}
  return {ok=true,value={characterId='john',expected=expected,equipment={},candidate=item and row or nil,
   utilityEquipment={characterId='john',expected=expected,equipment=assigned and {[assignedSlot=='weapon_utility' and 'utility' or 'utility_secondary']=assignedRow} or {}},
   brokenEquipmentContract=1,brokenPromotionContract=1}}
 end,
 CommitNativeUtilityEquipment=function(_,context,spec)
  assert(state.phase=='released' and registered.ValidateNativeEquipmentCommit(context,spec))
  assert(spec.utility and (spec.utilityId==200 or spec.utilityId==201) and #spec.lifecycleWear==0)
  assert(spec.slot=='weapon_utility' or (reinforcedGate==1 and spec.slot=='weapon_utility_secondary'))
  assigned=spec.action=='equip'; assignedRow=assigned and row or nil; assignedSlot=assigned and spec.slot or nil
  writes=writes+1; return {ok=true,value={}}
 end}}, {__call=function(_,name,fn) registered[name]=fn end})
WeaponCharacterAmmoDispatcher={Status=function() return state end,Start=function()
 starts=starts+1; local bundle={}; WeaponNativeEquipmentBindings.Attach(4,bundle)
 assert(bundle.equipmentTransition.ticket==request.ticket)
 id={characterId='john',sessionId='s',epoch='e'..(starts+1)}
 state={phase='restoring',identity=id}; return {ok=true,value=id}
end}
dofile('server/services/native_equipment_transition.lua')
local function finish()
 local old=request.identity; state={phase='released',identity=old}; source=4
 events['feather-weapons:server:native-equipment-released'](request.ticket,old,true,{epoch=old.epoch,items={}})
 assert(state.phase=='restoring'); state={phase='active',identity=id}
 events['feather-weapons:server:native-equipment-restored'](request.ticket,id)
 assert(not registered.ValidateNativeEquipmentCommit({actorSource=4},{}))
end
commands.WeaponNativeEquipmentChange(0,{'4','equip','weapon_utility','200'}); assert(not request and writes==0)
gate=1; commands.WeaponNativeEquipmentChange(0,{'4','equip','weapon_utility','200'})
assert(request and writes==0,'lasso write waits for exact released-owner acknowledgement')
finish(); assert(assigned and writes==1)
commands.WeaponNativeEquipmentChange(0,{'4','unequip','weapon_utility'})
assert(writes==1); finish(); assert(not assigned and writes==2 and starts==2)
source=4
events['feather-weapons:server:native-equipment-ui']('utility-options','options',{itemId=200,scope=id})
assert(reply.ok and #reply.value.options==1 and reply.value.options[1].slot=='weapon_utility'
 and reply.value.options[1].action=='equip')
events['feather-weapons:server:native-equipment-ui']('utility-equip','change',{itemId=200,scope=id,action='equip',slot='weapon_utility'})
assert(writes==2); finish(); assert(assigned and writes==3)
events['feather-weapons:server:native-equipment-ui']('utility-options-equipped','options',{itemId=200,scope=id})
assert(reply.ok and #reply.value.options==1 and reply.value.options[1].action=='unequip')
dofile('shared/native_lasso_policy.lua'); reinforcedGate=1
row={id=201,revision=0,itemName='weapon_lasso_reinforced',metadata=assert(WeaponNativeUtilityItem.Build(
 WeaponDefinitionCatalog.weapons.utility_lasso_reinforced,{serialNumber='R'}))}
local oldRequest=request
commands.WeaponNativeEquipmentChange(0,{'4','equip','weapon_utility_secondary','201'})
assert(request==oldRequest and writes==3 and assignedRow.id==200,'family conflict refused before release or write')
commands.WeaponNativeEquipmentChange(0,{'4','unequip','weapon_utility'}); finish()
assert(not assigned and writes==4)
commands.WeaponNativeEquipmentChange(0,{'4','equip','weapon_utility_secondary','201'}); finish()
assert(assignedRow.id==201 and assignedSlot=='weapon_utility_secondary' and writes==5)
commands.WeaponNativeEquipmentChange(0,{'4','unequip','weapon_utility_secondary'}); finish()
assert(not assigned and writes==6)
print('staged utility transition PASS: default-off intent, reserved release/final wear, canonical commit, fresh epoch/restore ack and ticket retirement; mocked Inventory')
