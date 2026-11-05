Config={DevMode=true,NativeAlphaRuntime=true,NativeAlphaCharacterId='Jane',NativeAlphaRepairEnabled=true,
 CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true}
for _,file in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/attachments.lua',
 'shared/definitions/weapons.lua','shared/validation.lua','shared/character_ammunition_catalog.lua',
 'shared/character_ammunition_policy.lua','shared/character_ammunition_item.lua','shared/character_maintenance.lua',
 'shared/character_ammunition_materialization.lua'}) do dofile(file) end
local function copy(v) if type(v)~='table' then return v end; local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out end
local events,registered,commands={},{ },{}
RegisterCommand=function(name,fn) commands[name]=fn end; RegisterNetEvent=function(name,fn) events[name]=fn end
local statusOutput
json={encode=function(value) statusOutput=value; return 'snapshot' end}
AddEventHandler=function() end; SetTimeout=function() end; GetGameTimer=function() return 1 end
GetConvarInt=function() return 0 end; GetResourceState=function() return 'stopped' end
GetInvokingResource=function() return 'feather-inventory' end
local identity={characterId='Jane',sessionId='s',epoch='e'}
local state={phase='active',identity=identity}
local candidate={id=128,revision=7,itemName='weapon_revolver_cattleman',metadata={schemaVersion=2,
 weaponDefinitionId='revolver_cattleman',serialNumber='ordinary',condition=90,quality=100,
 maintenance={degradation=0.1,permanentDegradation=0.1,damage=0.1,dirt=0.7,soot=0},
 ammo={ownership='character',type='ammo_revolver_regular'},attachments={},cosmetics={},
 flags={stolen=false,evidence=false,disabled=false},provenance={}}}
local quantity,writes,releases=0,0,0
local request,replies=nil,{}
CoreAdapter={ResolveSession=function() return {ok=true,value=identity} end,IsSessionCurrent=function() return true end}
WeaponCharacterAmmoService={ValidateLoadout=function() return {ok=true} end}
WeaponCharacterAmmoDispatcher={Status=function() return state end,Start=function()
 identity={characterId='Jane',sessionId='s',epoch='fresh'}; state={phase='restoring',identity=identity}
 return {ok=true,value=identity}
end}
exports=setmetatable({['feather-inventory']={ReadNativeEquipmentTransition=function()
 return {ok=true,value={characterId='Jane',expected={weapon={itemId=128,revision=candidate.revision}},
  equipment={primary=copy(candidate)},candidate=copy(candidate)}}
end,ReadNativeRepairMaterial=function() return {ok=true,value={definitionId=9,quantity=quantity}} end,
CommitNativeRepairTransition=function(_,context,spec)
 assert(state.phase=='released' and registered.ValidateNativeEquipmentCommit(context,spec))
 assert(spec.material.quantity==1 and spec.material.itemName=='gun_oil')
 writes=writes+1; quantity=quantity-1; candidate.metadata=copy(spec.after); candidate.revision=candidate.revision+1
 return {ok=true,value={}}
end}},{__call=function(_,name,fn) registered[name]=fn end})
TriggerClientEvent=function(name,_,value,scope,result)
 if name=='feather-weapons:client:native-equipment-result' then replies[#replies+1]={id=value,result=result}
 else request=value; releases=releases+1 end
end
dofile('server/services/native_equipment_transition.lua')
source=2
local function preview(id)
 events['feather-weapons:server:native-equipment-ui'](id,'options',{itemId=128,scope=identity})
 return replies[#replies].result.value.options
end
for _,option in ipairs(preview('missing')) do assert(option.kind~='repair') end
quantity=1
commands.WeaponNativeRepairStatus(0,{'2','128'})
assert(statusOutput.repairAvailable and statusOutput.materialQuantity==1 and statusOutput.noSQLWrites)
assert(writes==0 and releases==0,'status must not release or pay')
local found=false
for _,option in ipairs(preview('available')) do if option.kind=='repair' then found=true end end
assert(found and writes==0 and releases==0,'repair preview is read-only')
events['feather-weapons:server:native-equipment-ui']('repair','repair-change',{itemId=128,action='repair',scope=identity})
assert(request and releases==1 and writes==0)
state={phase='released',identity=identity}
events['feather-weapons:server:native-equipment-released'](request.ticket,identity,true)
assert(writes==1 and quantity==0 and state.phase=='restoring')
state={phase='active',identity=identity}
events['feather-weapons:server:native-equipment-restored'](request.ticket,identity)
assert(replies[#replies].id=='repair' and replies[#replies].result.ok)
assert(candidate.revision==8 and candidate.metadata.condition==90 and candidate.metadata.maintenance.dirt==0
 and candidate.metadata.maintenance.permanentDegradation==0.1,'permanent ceiling retained')
commands.WeaponNativeRepairStatus(0,{'2','128'})
assert(statusOutput.repairAvailable==false and statusOutput.itemRevision==8)
print('Repair UI binding PASS (quantity-gated preview, sealed release before payment, fresh restore, permanent ceiling, no ammo changes)')
