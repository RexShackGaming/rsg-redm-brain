dofile('shared/constants.lua') -- shared enrollment dependency from normal manifest
Config={}
dofile('shared/definitions/ammunition.lua')
dofile('shared/definitions/attachments.lua')
dofile('shared/definitions/weapons.lua')
local count,proved=0,0
for _,weapon in pairs(WeaponDefinitionCatalog.weapons) do
 for _,ids in pairs(weapon.attachmentSlots or {}) do
  for _,id in ipairs(ids) do
   count=count+1
   local attachment=WeaponDefinitionCatalog.attachments[id]
   local mapping=assert(WeaponNativeAttachmentMappings.Resolve(weapon,attachment,false))
   assert(type(mapping.nativeSlot)=='number' and mapping.nativeSlot~=0)
   local admitted=WeaponNativeAttachmentMappings.Resolve(weapon,attachment,true)
   if admitted then proved=proved+1; assert(id=='carbine_wide_sight' and admitted.stockComponentName) end
   mapping.nativeSlot=0
   assert(WeaponNativeAttachmentMappings.Resolve(weapon,attachment,false).nativeSlot~=0,'private result')
  end
 end
end
assert(count==38 and proved==1,'all observed pairs enrolled without opening unproved reconstruction')
local schofield=WeaponDefinitionCatalog.weapons.revolver_schofield
assert(WeaponNativeAttachmentMappings.Resolve(schofield,WeaponDefinitionCatalog.attachments.schofield_wide_sight,false).nativeSlot==1880805647)
assert(not WeaponNativeAttachmentMappings.Resolve(schofield,WeaponDefinitionCatalog.attachments.carbine_wide_sight,false))
Config={DevMode=true,NativeAlphaRuntime=true,NativeAlphaCharacterId='Jane'}
local flag,catalogFlag=0,0
GetConvarInt=function(name) return name=='feather_native_representative_attachments' and flag
 or name=='feather_native_catalog_attachments' and catalogFlag or 0 end
assert(not WeaponNativeAttachmentMappings.Resolve(schofield,WeaponDefinitionCatalog.attachments.schofield_wide_sight,true))
flag=1
for _,id in ipairs({'schofield_wide_sight','schofield_short_barrel'}) do
 local candidate=assert(WeaponNativeAttachmentMappings.Resolve(schofield,WeaponDefinitionCatalog.attachments[id],true))
 assert(candidate.representative and not candidate.reconstructionProved and not candidate.stockComponentName)
end
assert(WeaponNativeAttachmentMappings.CaptureModel('WEAPON_REVOLVER_SCHOFIELD'))
assert(not WeaponNativeAttachmentMappings.CaptureModel('WEAPON_REVOLVER_CATTLEMAN'))
Config.DevMode=false
assert(not WeaponNativeAttachmentMappings.Resolve(schofield,WeaponDefinitionCatalog.attachments.schofield_wide_sight,true))
Config.DevMode=true; flag=0; catalogFlag=1
local admitted=0
for _,weapon in pairs(WeaponDefinitionCatalog.weapons) do
 for _,ids in pairs(weapon.attachmentSlots or {}) do
  for _,id in ipairs(ids) do
   local mapping=WeaponNativeAttachmentMappings.Resolve(weapon,WeaponDefinitionCatalog.attachments[id],true)
   if weapon.id=='revolver_lemat' then assert(not mapping) else assert(mapping and mapping.catalogRollout); admitted=admitted+1 end
  end
 end
end
assert(admitted==36 and not WeaponNativeAttachmentMappings.CaptureModel('WEAPON_REVOLVER_LEMAT')
 and WeaponNativeAttachmentMappings.CaptureModel('WEAPON_SHOTGUN_SAWEDOFF'))
local attachment=WeaponDefinitionCatalog.attachments.cattleman_wide_sight
local nativeName=attachment.nativeComponentName; attachment.nativeComponentName='COMPONENT_INJECTED'
assert(not WeaponNativeAttachmentMappings.Resolve(WeaponDefinitionCatalog.weapons.revolver_cattleman,attachment,true))
attachment.nativeComponentName=nativeName
print('Native mapping registry PASS (38 observed pairs, signed slots, compatibility isolation, private projection, reconstruction gated)')
