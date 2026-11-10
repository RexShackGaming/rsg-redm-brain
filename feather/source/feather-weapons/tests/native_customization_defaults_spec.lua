-- Normal shipped config, real catalog/policy and real station/authorization.
vector3=function(x,y,z) return {x=x,y=y,z=z} end
dofile('config.lua')
local switches={}
GetConvarInt=function(name,default) if switches[name]~=nil then return switches[name] end; return default end
for _,file in ipairs({'shared/constants.lua','shared/errors.lua','shared/definitions/ammunition.lua',
 'shared/definitions/attachments.lua','shared/definitions/weapons.lua','shared/validation.lua',
 'shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua','shared/character_ammunition_item.lua',
 'shared/character_attachments.lua','shared/character_maintenance.lua','shared/character_ammunition_materialization.lua',
 'server/services/attachments.lua'}) do dofile(file) end
assert(Config.DevMode==false and Config.NativeAlphaRepairEnabled==true)
local function copy(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out end
local identity={characterId='Jane',sessionId='s',epoch='e'}
local candidate={id=128,revision=17,itemName='weapon_revolver_cattleman',metadata={schemaVersion=2,
 weaponDefinitionId='revolver_cattleman',serialNumber='normal-copy',condition=89,quality=100,
 maintenance={degradation=.11,permanentDegradation=.1,damage=.1,dirt=0,soot=.015},
 ammo={ownership='character',type='ammo_revolver_regular'},attachments={},cosmetics={},
 flags={stolen=false,evidence=false,disabled=false},provenance={}}}
local events={}
RegisterCommand=function() end;AddEventHandler=function() end;SetTimeout=function() end
RegisterNetEvent=function(name,fn) events[name]=fn end
local clock=100;GetGameTimer=function() return clock end
GetResourceState=function() return 'stopped' end
GetInvokingResource=function() return 'feather-inventory' end
local position=copy(Config.Attachments.stations.valentine.coords)
GetPlayerPed=function() return 42 end;GetEntityCoords=function() return position end
CoreAdapter={ResolveSession=function() return {ok=true,value=identity} end,IsSessionCurrent=function() return true end}
WeaponCharacterAmmoService={ValidateLoadout=function() return {ok=true} end}
WeaponCharacterAmmoDispatcher={Status=function() return {phase='active',identity=identity} end}
local parts,oil,authorized=1,1,true
exports=setmetatable({['feather-core']={Authorize=function() return WeaponResult.Ok({allowed=authorized}) end},
 ['feather-inventory']={ReadNativeEquipmentTransition=function()
 return {ok=true,value={characterId='Jane',expected={weapon={itemId=128,revision=17}},
  equipment={primary=copy(candidate)},candidate=copy(candidate)}}
 end,ReadNativeAttachmentMaterial=function() return {ok=true,value={definitionId=9,quantity=parts}} end,
 ReadNativeRepairMaterial=function() return {ok=true,value={definitionId=10,quantity=oil}} end}
},{__call=function() end})
local reply,releases=nil,0
TriggerClientEvent=function(name,_,_,_,value)
 if name=='feather-weapons:client:native-equipment-result' then reply=value else releases=releases+1 end
end
dofile('server/services/native_equipment_transition.lua')
source=1
local function preview()
 clock=clock+5000
 events['feather-weapons:server:native-equipment-ui']('defaults:'..clock,'options',{itemId=128,scope=identity})
 assert(reply and reply.ok,'normal default preview must remain available')
 local found={}
 for _,option in ipairs(reply.value.options) do
  if option.kind=='attachment' then found[option.attachmentId]=true end
  if option.kind=='repair' then found.repair=true end
 end
 return found
end
local found=preview()
assert(found.cattleman_long_barrel and found.cattleman_wide_sight and found.repair,
 'no manual convars or development mode needed with normal config and materials')
assert(WeaponNativeAttachmentMappings.CaptureModel('WEAPON_REVOLVER_SCHOFIELD')
 and WeaponNativeAttachmentMappings.CaptureModel('WEAPON_REVOLVER_LEMAT'),'tested model mappings are admitted')
parts=0;oil=0;found=preview()
assert(not next(found),'missing materials hide unpaid customization actions')
parts=1;oil=1;position={x=0,y=0,z=0};found=preview()
assert(not found.cattleman_wide_sight and not found.cattleman_long_barrel and found.repair,
 'attachments require bench proximity; ordinary oil cleaning remains field-usable')
position=copy(Config.Attachments.stations.valentine.coords)
Config.Attachments.authorization.enabled=true;authorized=false;found=preview()
assert(not found.cattleman_wide_sight and found.repair,'configured gunsmith permission is enforced')
authorized=true;found=preview();assert(found.cattleman_wide_sight)
switches.feather_native_attachment_transactions=0;found=preview()
assert(not found.cattleman_wide_sight and found.repair,'explicit attachment transaction disable overrides default')
switches.feather_native_attachment_transactions=nil;switches.feather_native_saved_attachments=0;found=preview()
assert(not found.cattleman_wide_sight,'explicit saved reconstruction disable overrides default')
switches.feather_native_saved_attachments=nil;Config.NativeAlphaRepairEnabled=false;found=preview()
assert(found.cattleman_wide_sight and not found.repair,'explicit cleaning disable remains independent')
Config.NativeAlphaRepairEnabled=true
candidate.metadata.attachments={{definitionId='cattleman_wide_sight',slot='sight'}}
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
local plan=assert(WeaponCharacterAmmoMaterialization.Build({primary=candidate},WeaponDefinitionCatalog,registry,identity))
assert(WeaponCharacterAmmoMaterialization.Validate(plan,registry,identity),'saved customized copy reconstructs under missing-convar defaults')
switches.feather_native_attachment_transactions=0
assert(WeaponCharacterAmmoMaterialization.Validate(plan,registry,identity),'disabling modifications does not disable saved reconstruction')
switches.feather_native_saved_attachments=0
assert(not WeaponCharacterAmmoMaterialization.Validate(plan,registry,identity)
 and #candidate.metadata.attachments==1,'disabled reconstruction refuses rather than stripping saved components')
assert(releases==0,'all options checks are read-only and never dispatch releases or item mutations')
print('Customization defaults PASS (normal config, no switches, bench/material/authorization gates, explicit disables, experimental isolation)')
