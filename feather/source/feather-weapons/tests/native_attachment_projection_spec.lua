Config={}
dofile('shared/constants.lua')
dofile('shared/definitions/ammunition.lua')
dofile('shared/definitions/attachments.lua')
dofile('shared/definitions/weapons.lua')
dofile('shared/character_ammunition_materialization.lua')
local identity={characterId='c',sessionId='s',epoch='e'}
local item={itemInstanceId=135,itemRevision=4,serialNumber='serial',definitionId='repeater_carbine',
 nativeWeaponName='WEAPON_REPEATER_CARBINE',attachments={{definitionId='carbine_wide_sight',slot='sight'}},cosmetics={}}
local build=WeaponNativeAttachmentProjection.Build
local p=assert(build(item,WeaponDefinitionCatalog,identity))
assert(p.itemRevision==4 and p.components[1].nativeSlot==468034421)
p.components[1].nativeComponentName='tamper'; p.epoch='tamper'
assert(item.attachments[1].nativeComponentName==nil and identity.epoch=='e','private projection, no metadata mutation')
item.attachments[1].nativeComponentName='injected'; assert(not build(item,WeaponDefinitionCatalog,identity))
item.attachments[1].nativeComponentName=nil
item.attachments[2]=item.attachments[1]; assert(not build(item,WeaponDefinitionCatalog,identity)); item.attachments[2]=nil
item.attachments.foo=true; assert(not build(item,WeaponDefinitionCatalog,identity)); item.attachments.foo=nil
item.attachments[1].slot='barrel'; assert(not build(item,WeaponDefinitionCatalog,identity)); item.attachments[1].slot='sight'
item.itemRevision=-1; assert(not build(item,WeaponDefinitionCatalog,identity)); item.itemRevision=4
item.nativeWeaponName='WEAPON_REVOLVER_CATTLEMAN'; assert(not build(item,WeaponDefinitionCatalog,identity)); item.nativeWeaponName='WEAPON_REPEATER_CARBINE'
local allowed=WeaponDefinitionCatalog.weapons.repeater_carbine.attachmentSlots.sight
WeaponDefinitionCatalog.weapons.repeater_carbine.attachmentSlots.sight={}
assert(not build(item,WeaponDefinitionCatalog,identity))
WeaponDefinitionCatalog.weapons.repeater_carbine.attachmentSlots.sight=allowed
item.cosmetics.tint=1; assert(not build(item,WeaponDefinitionCatalog,identity)); item.cosmetics={}
item.attachments={}; assert(#assert(build(item,WeaponDefinitionCatalog,identity)).components==0)
assert(not build(item,WeaponDefinitionCatalog,{characterId='c',sessionId='s'}))
print('attachment projection PASS (canonical names only, proved mapping, compatibility, identity/revision, defensive copy, no writes)')
