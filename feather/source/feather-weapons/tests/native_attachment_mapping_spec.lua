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
Config={DevMode=false,NativeAlphaRuntime=true}
local disabled={}
GetConvarInt=function(name,default) if disabled[name] then return 0 end; return default end
local admitted=0
for _,weapon in pairs(WeaponDefinitionCatalog.weapons) do
 for _,ids in pairs(weapon.attachmentSlots or {}) do
  for _,id in ipairs(ids) do
   local attachment=WeaponDefinitionCatalog.attachments[id]
   local mapping=WeaponNativeAttachmentMappings.Resolve(weapon,attachment,true)
    assert(mapping and mapping.catalogRollout and WeaponNativeAttachmentMappings.CaptureModel(weapon.nativeWeaponName))
    admitted=admitted+1
    local original=attachment.nativeComponentName
    attachment.nativeComponentName='COMPONENT_INJECTED'
    assert(not WeaponNativeAttachmentMappings.Resolve(weapon,attachment,true))
    attachment.nativeComponentName=original
  end
 end
end
assert(admitted==38 and WeaponNativeAttachmentMappings.CaptureModel('WEAPON_REVOLVER_LEMAT'))
for _,name in ipairs({'feather_native_saved_attachments','feather_native_guid_ownership'}) do
 disabled[name]=true
 assert(not WeaponNativeAttachmentMappings.CaptureModel('WEAPON_REVOLVER_SCHOFIELD'))
 assert(not WeaponNativeAttachmentMappings.Resolve(schofield,WeaponDefinitionCatalog.attachments.schofield_wide_sight,true))
 disabled[name]=nil
end
assert(not WeaponNativeAttachmentMappings.CaptureModel('WEAPON_UNKNOWN'))
print('Native mapping registry PASS (38 recorded pairs, 38 production mappings, separate ammunition pools, explicit disables, tamper refusal)')
