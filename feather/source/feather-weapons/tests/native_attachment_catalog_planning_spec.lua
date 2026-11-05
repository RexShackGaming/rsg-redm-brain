Config={}
for _,file in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/attachments.lua',
 'shared/definitions/weapons.lua','shared/validation.lua','shared/character_ammunition_item.lua',
 'shared/character_attachments.lua','shared/character_ammunition_materialization.lua'}) do dofile(file) end
local function metadata(weapon)
 return {schemaVersion=2,weaponDefinitionId=weapon.id,serialNumber='ordinary',condition=100,quality=100,
  maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},
  ammo={ownership='character',type=weapon.ammunitionType},attachments={},cosmetics={},
  flags={stolen=false,evidence=false,disabled=false},provenance={}}
end
local identity={characterId='Jane',sessionId='s',epoch='e'}
local function item(weapon,meta)
 return {itemInstanceId=901,itemRevision=1,serialNumber=meta.serialNumber,definitionId=weapon.id,
  nativeWeaponName=weapon.nativeWeaponName,attachments=meta.attachments,cosmetics={}}
end
local count=0
for _,weapon in pairs(WeaponDefinitionCatalog.weapons) do
 for _,ids in pairs(weapon.attachmentSlots or {}) do
  for _,id in ipairs(ids) do
   local attachment=WeaponDefinitionCatalog.attachments[id]
   local before=metadata(weapon)
   if weapon.id=='revolver_lemat' then
    assert(not WeaponCharacterAttachments.PlanCatalog(before,weapon,attachment,'attachment-install'),
     'existing LeMat dual-ammo exclusion must not be relaxed by attachment planning')
    before.attachments={{definitionId=id,slot=attachment.slot}}
    assert(WeaponNativeAttachmentProjection.BuildCatalog(item(weapon,before),WeaponDefinitionCatalog,identity))
   else
   local install=assert(WeaponCharacterAttachments.PlanCatalog(before,weapon,attachment,'attachment-install'))
   assert(#before.attachments==0 and install.material.quantity==1 and install.material.itemName==attachment.itemName)
   local projection=assert(WeaponNativeAttachmentProjection.BuildCatalog(item(weapon,install.after),WeaponDefinitionCatalog,identity))
   assert(#projection.components==1 and projection.components[1].definitionId==id)
   local remove=assert(WeaponCharacterAttachments.PlanCatalog(install.after,weapon,attachment,'attachment-remove'))
   assert(#remove.after.attachments==0 and remove.material.direction=='return')
   if id~='carbine_wide_sight' then
    assert(not WeaponCharacterAttachments.Plan(before,weapon,attachment,'attachment-install'))
    assert(not WeaponNativeAttachmentProjection.Build(item(weapon,install.after),WeaponDefinitionCatalog,identity),
     'catalog planning cannot bypass live reconstruction gate')
   end
   end
   count=count+1
  end
 end
end
assert(count==38)
local weapon=WeaponDefinitionCatalog.weapons.revolver_schofield
local sight=WeaponDefinitionCatalog.attachments.schofield_wide_sight
local barrel=WeaponDefinitionCatalog.attachments.schofield_short_barrel
local first=assert(WeaponCharacterAttachments.PlanCatalog(metadata(weapon),weapon,sight,'attachment-install'))
local both=assert(WeaponCharacterAttachments.PlanCatalog(first.after,weapon,barrel,'attachment-install'))
assert(#both.after.attachments==2 and both.after.attachments[1].slot=='barrel')
local projection=assert(WeaponNativeAttachmentProjection.BuildCatalog(item(weapon,both.after),WeaponDefinitionCatalog,identity))
assert(#projection.components==2 and projection.components[1].nativeSlot==1985390213
 and projection.components[2].nativeSlot==1880805647)
local remove=assert(WeaponCharacterAttachments.PlanCatalog(both.after,weapon,sight,'attachment-remove'))
assert(#remove.after.attachments==1 and remove.after.attachments[1].definitionId==barrel.id)
both.after.attachments[1].nativeSlot=999
assert(not WeaponCharacterAttachments.PlanCatalog(both.after,weapon,sight,'attachment-remove'))
assert(not WeaponNativeAttachmentProjection.BuildCatalog(item(weapon,both.after),WeaponDefinitionCatalog,identity))
-- Exercise policies even though the shipped definitions currently have empty
-- dependencies. Removal must validate the remaining set, not just its target.
local originalPrerequisites,originalConflicts=sight.prerequisites,sight.conflicts
sight.prerequisites={barrel.id}
assert(not WeaponCharacterAttachments.PlanCatalog(metadata(weapon),weapon,sight,'attachment-install'))
local barrelFirst=assert(WeaponCharacterAttachments.PlanCatalog(metadata(weapon),weapon,barrel,'attachment-install'))
local dependent=assert(WeaponCharacterAttachments.PlanCatalog(barrelFirst.after,weapon,sight,'attachment-install'))
assert(not WeaponCharacterAttachments.PlanCatalog(dependent.after,weapon,barrel,'attachment-remove'))
assert(WeaponCharacterAttachments.PlanCatalog(dependent.after,weapon,sight,'attachment-remove'))
assert(not WeaponNativeAttachmentProjection.BuildCatalog(item(weapon,first.after),WeaponDefinitionCatalog,identity))
sight.prerequisites={}; sight.conflicts={barrel.id}
assert(not WeaponCharacterAttachments.PlanCatalog(barrelFirst.after,weapon,sight,'attachment-install'))
assert(not WeaponCharacterAttachments.PlanCatalog(first.after,weapon,barrel,'attachment-install'),'reverse conflict checked across complete set')
sight.prerequisites=originalPrerequisites; sight.conflicts=originalConflicts
print('Catalog planning PASS (38 projections, 36 pure install/remove pairs, LeMat exclusion retained, multislot/dependency/conflict policy, live gates unchanged)')
