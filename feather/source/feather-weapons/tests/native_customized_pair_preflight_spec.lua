Config={DevMode=true,NativeAlphaRuntime=true,NativeAlphaCharacterId='Jane',NativeAlphaLifecycleWearEnabled=true,
 CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true}
GetConvarInt=function() return 1 end
for _,file in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/attachments.lua',
 'shared/definitions/weapons.lua','shared/validation.lua','shared/character_ammunition_catalog.lua',
 'shared/character_ammunition_policy.lua','shared/character_ammunition_item.lua','shared/character_attachments.lua',
 'shared/character_ammunition_materialization.lua'}) do dofile(file) end
local function copy(v) if type(v)~='table' then return v end; local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out end
local function row(id)
 return {id=id,revision=0,itemName='weapon_revolver_cattleman',metadata={schemaVersion=2,
  weaponDefinitionId='revolver_cattleman',serialNumber='ordinary-'..id,condition=100,quality=100,
  maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},
  ammo={ownership='character',type='ammo_revolver_regular'},attachments={},cosmetics={},
  flags={stolen=false,evidence=false,disabled=false},provenance={}}}
end
local rows={primary=row(901),offhand=row(902)}
local identity={characterId='Jane',sessionId='s',epoch='e'}
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
local plan=assert(WeaponCharacterAmmoMaterialization.Build(rows,WeaponDefinitionCatalog,registry,identity))
assert(WeaponCharacterAmmoMaterialization.Validate(plan,registry,identity),'ordinary identical pair unchanged')
rows.offhand.metadata.attachments={{definitionId='cattleman_wide_sight',slot='sight'}}
plan=assert(WeaponCharacterAmmoMaterialization.Build(rows,WeaponDefinitionCatalog,registry,identity))
local valid,why=WeaponCharacterAmmoMaterialization.Validate(plan,registry,identity)
assert(valid,why)
rows.offhand.metadata.attachments={}
rows.offhand.metadata.maintenance.permanentDegradation=0.1
rows.offhand.metadata.maintenance.degradation=0.1
rows.offhand.metadata.maintenance.damage=0.1
rows.offhand.metadata.condition=90
plan=assert(WeaponCharacterAmmoMaterialization.Build(rows,WeaponDefinitionCatalog,registry,identity))
assert(WeaponCharacterAmmoMaterialization.Validate(plan,registry,identity),'normal worn pair is admitted with exact GUID ownership enabled')
GetConvarInt=function(_,default) return default end
assert(WeaponCharacterAmmoMaterialization.Validate(plan,registry,identity),'fresh server defaults admit worn pair without manual GUID switch')
GetConvarInt=function() return 0 end
valid,why=WeaponCharacterAmmoMaterialization.Validate(plan,registry,identity)
assert(not valid and why=='pair_permanent_guid_ownership_required')
GetConvarInt=function() return 1 end
rows.offhand.metadata.maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0}
rows.offhand.metadata.condition=100
local commands,events,options,releases,materialReads={},{},nil,0,0
RegisterCommand=function(name,fn) commands[name]=fn end
RegisterNetEvent=function(name,fn) events[name]=fn end
AddEventHandler=function() end; SetTimeout=function() end; GetGameTimer=function() return 1 end
GetResourceState=function() return 'stopped' end
CoreAdapter={ResolveSession=function() return {ok=true,value=identity} end,IsSessionCurrent=function() return true end}
WeaponCharacterAmmoService={ValidateLoadout=function() return {ok=true} end}
WeaponCharacterAmmoDispatcher={Status=function() return {phase='active',identity=identity} end}
AttachmentService={AuthorizeNativeModification=function() return {ok=true} end}
exports=setmetatable({['feather-inventory']={ReadNativeEquipmentTransition=function()
 return {ok=true,value={characterId='Jane',expected={weapon={itemId=901,revision=0},weapon_offhand={itemId=902,revision=0}},
  equipment=copy(rows),candidate=copy(rows.offhand)}}
end,ReadNativeAttachmentMaterial=function()
 materialReads=materialReads+1; return {ok=true,value={definitionId=9,quantity=1}}
end}},{__call=function() end})
TriggerClientEvent=function(name,_,_,_,result)
 if name=='feather-weapons:client:native-equipment-result' then options=result
 else releases=releases+1 end
end
dofile('server/services/native_equipment_transition.lua')
source=2
events['feather-weapons:server:native-equipment-ui']('options','options',{itemId=902,scope=identity})
assert(options.ok)
local attachmentOption=false
for _,option in ipairs(options.value.options) do if option.kind=='attachment' then attachmentOption=true end end
assert(attachmentOption and materialReads>0 and releases==0,'preview admits scoped attachments without releasing or writing')
commands.WeaponNativeAttachmentChange(0,{'2','install','902','cattleman_wide_sight'})
assert(releases==1,'direct intent reaches the normal sealed transition rather than a same-model veto')
print('Customized pair preflight PASS (canonical pair projection and normal scoped attachment transition)')
