Config={AmmunitionPools={enabled=false},Escrow={maxTotal=200}}
dofile('shared/constants.lua'); dofile('shared/definitions/ammunition.lua'); dofile('shared/definitions/weapons.lua')
dofile('shared/validation.lua'); dofile('shared/character_ammunition_item.lua'); dofile('shared/character_maintenance.lua')
dofile('shared/character_lifecycle_wear.lua')
local definition=WeaponDefinitionCatalog.weapons.revolver_cattleman
local metadata={schemaVersion=2,weaponDefinitionId=definition.id,serialNumber='serial',condition=90,quality=100,
 maintenance={degradation=0.1,permanentDegradation=0.1,damage=0.1,dirt=0,soot=0},
 ammo={ownership='character',type=definition.ammunitionType},attachments={},cosmetics={},
 flags={stolen=false,evidence=false,disabled=false},provenance={}}
local rows={primary={id=128,revision=2,itemName=definition.itemName,metadata=metadata}}
local report={epoch='e',items={{itemInstanceId=128,itemRevision=2,
 maintenance={degradation=0.10000000149,permanentDegradation=0.10000000149,damage=0.1,dirt=0,soot=0}}}}
assert(#WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'e')==0)
report.items[1].maintenance.dirt=0.3
local changes=assert(WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'e'))
assert(#changes==1 and changes[1].after.maintenance.dirt==0.3 and metadata.maintenance.dirt==0)
assert(not WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'old'))
report.items[1].itemRevision=1; assert(not WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'e'))
report.items[1].itemRevision=2; report.items[2]=report.items[1]
assert(not WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'e'))
report.items={}; assert(not WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'e'))
assert(#WeaponCharacterLifecycleWear.Plan({},report,WeaponDefinitionCatalog,'e')==0)
-- Alive released-owner policy may detach a broken primary plus dependent offhand.
local function copy(v) if type(v)~='table' then return v end; local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out end
local offhand=copy(rows.primary); offhand.id=129
rows.offhand=offhand
report.items={{itemInstanceId=128,itemRevision=2,maintenance={degradation=1,permanentDegradation=0.1,damage=1,dirt=0,soot=0}},
 {itemInstanceId=129,itemRevision=2,maintenance=copy(metadata.maintenance)}}
local worn,why,detached=WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'e',true)
assert(worn and #worn==1 and worn[1].after.condition==0 and detached.weapon.itemId==128
 and detached.weapon_offhand.itemId==129 and detached.weapon_offhand.reason=='primary_broken')
assert(metadata.condition==90 and rows.offhand.metadata.condition==90,'policy must not mutate saved items')
assert(detached.weapon_offhand.promote==true)
local projected=WeaponCharacterLifecycleWear.ProjectBroken(rows,detached)
assert(projected.primary.id==129 and projected.offhand==nil and rows.primary.id==128)
local catalog=copy(WeaponDefinitionCatalog)
catalog.weapons[definition.id].slot='longgun'
local incompatible=assert(WeaponCharacterLifecycleWear.BrokenEquipment({primary=worn[1] and
 {id=128,itemName=definition.itemName,metadata=worn[1].after},offhand=rows.offhand},catalog))
assert(not incompatible.weapon_offhand.promote,'non-sidearm cannot be promoted')
assert(not WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'e'),'death path remains fail-closed until separately authorized')
report.items[1].maintenance=copy(metadata.maintenance)
report.items[2].maintenance.damage=1
worn,why,detached=WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'e',true)
assert(worn and detached.weapon==nil and detached.weapon_offhand.reason=='broken','broken offhand leaves healthy primary equipped')
report.items[1].maintenance.damage=1
worn,why,detached=WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'e',true)
assert(worn and detached.weapon and detached.weapon_offhand.reason=='broken' and not detached.weapon_offhand.promote,'both broken means no promotion')
print('character_lifecycle_wear_spec PASS (complete exact copy/revision snapshot, monotonic wear/noise, missing/duplicate/stale rejection)')
