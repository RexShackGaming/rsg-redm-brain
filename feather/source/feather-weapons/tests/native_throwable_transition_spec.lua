Config={AmmunitionPools={enabled=false},DevMode=true,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,
 CharacterAmmoTransportEnabled=true,NativeAlphaCharacterId='john',NativeAlphaLifecycleWearEnabled=true}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/definitions/ammunition.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','shared/character_lifecycle_wear.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua'}) do dofile(p) end
local commands,events,registered={},{},{}
RegisterCommand=function(n,f) commands[n]=f end
RegisterNetEvent=function(n,f) events[n]=f end
AddEventHandler=function() end; SetTimeout=function() end
GetGameTimer=function() return 100 end
GetResourceState=function() return 'stopped' end
GetInvokingResource=function() return 'feather-inventory' end
local flag=1
GetConvarInt=function(name) return name=='feather_native_throwable' and flag or 0 end
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='john',sessionId='s'}} end,
 IsSessionCurrent=function(_,sid,cid) return sid=='s' and cid=='john' end}
WeaponCharacterAmmoService={ValidateLoadout=function() return {ok=true} end}
local identity={characterId='john',sessionId='s',epoch='e1'}
local state={phase='active',identity=identity}
local request,assigned,writes,starts=nil,false,0,0
local uiResult
local row={id=170,revision=0,itemName='weapon_thrown_tomahawk',metadata=assert(WeaponNativeThrowableItem.Build(WeaponDefinitionCatalog,{serialNumber='T'}))}
TriggerClientEvent=function(name,_,value,scope,result)
 if name=='feather-weapons:client:native-equipment-release' then request=value end
 if name=='feather-weapons:client:native-equipment-result' then uiResult=result end
end
exports=setmetatable({['feather-inventory']={ReadNativeEquipmentTransition=function(_,context,item)
 local expected=assigned and {weapon_throwable={itemId=170,revision=0}} or {}
 return {ok=true,value={characterId='john',expected=expected,equipment={},candidate=item and row or nil,
  throwableEquipment={characterId='john',expected=expected,equipment=assigned and {throwable=row} or {}},
  brokenEquipmentContract=1,brokenPromotionContract=1}}
end,CommitNativeThrowableEquipment=function(_,context,spec)
 assert(state.phase=='released' and registered.ValidateNativeEquipmentCommit(context,spec))
 assert(spec.throwable and spec.throwableId==170 and spec.slot=='weapon_throwable' and #spec.lifecycleWear==0)
 local forged={}; for k,v in pairs(spec) do forged[k]=v end; forged.throwableId=171
 assert(not registered.ValidateNativeEquipmentCommit(context,forged))
 assigned=spec.action=='equip'; writes=writes+1; return {ok=true,value={}}
end,
GetCharacterFirearmRuntimeSnapshot=function()
 local limits=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)).limits
 local pools={}; for id in pairs(limits) do pools[id]=0 end
 return {ok=true,value={revision=9,pools=pools,throwableEquipment={characterId='john',revision=9,pools=pools,
  expected={weapon_throwable={itemId=170,revision=0}},equipment={throwable=row}}}}
end,
CommitNativeThrowableFunding=function(_,context,spec)
 assert(state.phase=='released' and registered.ValidateNativeEquipmentCommit(context,spec))
 assert(spec.action=='throwable-funding' and spec.amount==1 and spec.expectedRevision==9
  and spec.expectedPools.ammo_tomahawk_regular==0 and spec.operationId=='fund-v1')
 local forged={}; for k,v in pairs(spec) do forged[k]=v end; forged.amount=-1
 assert(not registered.ValidateNativeEquipmentCommit(context,forged))
 writes=writes+1; return {ok=true,value={revision=10}}
end}},{__call=function(_,name,fn) registered[name]=fn end})
WeaponCharacterAmmoDispatcher={Status=function() return state end,Start=function()
 starts=starts+1; identity={characterId='john',sessionId='s',epoch='e'..(starts+1)}
 state={phase='restoring',identity=identity}; return {ok=true,value=identity}
end}
dofile('server/services/native_equipment_transition.lua')
local function finish()
 local old=request.identity; state={phase='released',identity=old}; source=7
 events['feather-weapons:server:native-equipment-released'](request.ticket,old,true,{epoch=old.epoch,items={}})
 assert(state.phase=='restoring'); state={phase='active',identity=identity}
 events['feather-weapons:server:native-equipment-restored'](request.ticket,identity)
end
flag=0; commands.WeaponNativeEquipmentChange(0,{'7','equip','weapon_throwable','170'}); assert(not request and writes==0)
flag=1; commands.WeaponNativeEquipmentChange(0,{'7','equip','weapon_throwable','170'}); assert(request and writes==0)
finish(); assert(assigned and writes==1)
commands.WeaponNativeEquipmentChange(0,{'7','unequip','weapon_throwable'}); assert(writes==1)
finish(); assert(not assigned and writes==2)
assigned=true
commands.WeaponNativeThrowableFunding(0,{'7','2','fund-v1'}); assert(writes==2)
commands.WeaponNativeThrowableFunding(0,{'7','1','fund-v1'}); assert(writes==2)
finish(); assert(assigned and writes==3)
source=7
events['feather-weapons:server:native-equipment-ui']('options-1','options',{itemId=170,scope=identity})
assert(uiResult.ok and #uiResult.value.options==1 and uiResult.value.options[1].action=='unequip'
 and uiResult.value.options[1].slot=='weapon_throwable' and writes==3)
events['feather-weapons:server:native-equipment-ui']('change-1','change',
 {itemId=170,scope=identity,action='unequip',slot='weapon_throwable'})
assert(writes==3); finish(); assert(not assigned and writes==4 and uiResult.ok)
events['feather-weapons:server:native-equipment-ui']('options-2','options',{itemId=170,scope=identity})
assert(uiResult.ok and #uiResult.value.options==1 and uiResult.value.options[1].action=='equip')
print('throwable actual reservation coordinator PASS: gated equip/unequip, release before exact item/slot ticket, final wear, fresh same-session rebuild')
