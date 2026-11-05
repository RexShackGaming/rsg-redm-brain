Config={}
for _,f in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/attachments.lua',
 'shared/definitions/weapons.lua','shared/validation.lua','shared/character_ammunition_item.lua','shared/character_attachments.lua'}) do dofile(f) end
local weapon=WeaponDefinitionCatalog.weapons.repeater_carbine
local attachment=WeaponDefinitionCatalog.attachments.carbine_wide_sight
local meta={schemaVersion=2,weaponDefinitionId=weapon.id,serialNumber='copy',condition=100,quality=100,
 maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},
 ammo={ownership='character',type=weapon.ammunitionType},attachments={},cosmetics={},
 flags={stolen=false,evidence=false,disabled=false},provenance={}}
local plan=assert(WeaponCharacterAttachments.Plan(meta,weapon,attachment,'attachment-install'))
assert(plan.material.direction=='consume' and plan.material.quantity==1 and #meta.attachments==0)
assert(plan.after.attachments[1].definitionId=='carbine_wide_sight' and plan.after.ammo.ownership=='character')
assert(not WeaponCharacterAttachments.Plan(plan.after,weapon,attachment,'attachment-install'))
local remove=assert(WeaponCharacterAttachments.Plan(plan.after,weapon,attachment,'attachment-remove'))
assert(remove.material.direction=='return' and next(remove.after.attachments)==nil and #plan.after.attachments==1)
assert(not WeaponCharacterAttachments.Plan(meta,weapon,attachment,'attachment-remove'))
meta.flags.evidence=true; assert(not WeaponCharacterAttachments.Plan(meta,weapon,attachment,'attachment-install')); meta.flags.evidence=false
meta.ammo.loaded=0; assert(not WeaponCharacterAttachments.Plan(meta,weapon,attachment,'attachment-install')); meta.ammo.loaded=nil
plan.after.attachments[1].nativeComponentName='injected'
assert(not WeaponCharacterAttachments.Plan(plan.after,weapon,attachment,'attachment-remove'))
local old=attachment.itemName; attachment.itemName='other_material'
assert(not WeaponCharacterAttachments.Plan(meta,weapon,attachment,'attachment-install')); attachment.itemName=old
print('canonical attachment intent PASS (consume/return one, metadata private/no ammo edits, duplicate/missing/evidence/instruction refusal)')
