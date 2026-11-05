Config={AmmunitionPools={enabled=false}}
dofile('shared/constants.lua')
dofile('shared/definitions/weapons.lua')
dofile('shared/native_knife.lua')
local def=WeaponDefinitionCatalog.weapons.melee_knife
local metadata=assert(WeaponNativeKnife.Build(def,{serialNumber='FW-KNIFE-TEST',provenance={type='development_grant'}}))
assert(metadata.ammo==nil and metadata.maintenance==nil,'knife never impersonates a firearm')
local row={id=900,revision=0,itemName='weapon_melee_knife',metadata=metadata}
local identity={characterId='john',sessionId='s',epoch='e'}
local projected=assert(WeaponNativeKnife.Project(row,def,identity))
assert(projected.slot=='melee' and projected.point==nil and projected.ammo==nil and projected.preferredAmmoType==nil)
identity.epoch='changed'; assert(projected.identity.epoch=='e')
local checked=assert(WeaponNativeKnife.Validate(metadata,def))
checked.flags.disabled=true; assert(not metadata.flags.disabled,'private validation copy')
for _,key in ipairs({'ammo','maintenance','loadedAmmo','reserveAmmo','chambered','nativeWeaponName','point'}) do
 metadata[key]={}; assert(not WeaponNativeKnife.Validate(metadata,def)); metadata[key]=nil
 local options={serialNumber='x'}; options[key]={}; assert(not WeaponNativeKnife.Build(def,options))
end
for _,value in ipairs({-1,101,0/0,math.huge,'100',false}) do
 local old=metadata.condition; metadata.condition=value
 assert(not WeaponNativeKnife.Validate(metadata,def)); metadata.condition=old
end
metadata.condition=0; assert(WeaponNativeKnife.Validate(metadata,def))
assert(not WeaponNativeKnife.Project(row,def,identity)); metadata.condition=100
for _,flag in ipairs({'disabled','evidence'}) do
 metadata.flags[flag]=true; assert(not WeaponNativeKnife.Project(row,def,identity)); metadata.flags[flag]=false
end
metadata.provenance.self=metadata; assert(not WeaponNativeKnife.Validate(metadata,def)); metadata.provenance.self=nil
metadata.attachments[1]={definitionId='sight',slot='sight'}
assert(not WeaponNativeKnife.Validate(metadata,def)); metadata.attachments={}
row.revision=0.5; assert(not WeaponNativeKnife.Project(row,def,identity)); row.revision=0
row.itemName='weapon_revolver_cattleman'; assert(not WeaponNativeKnife.Project(row,def,identity)); row.itemName='weapon_melee_knife'
for id,other in pairs(WeaponDefinitionCatalog.weapons) do
 if id~='melee_knife' then assert(not WeaponNativeKnife.Build(other,{serialNumber='x'}),'basic knife allowlist only') end
end
local f=assert(io.open('fxmanifest.lua','r')); local manifest=f:read('*a'); f:close()
assert(manifest:find('shared/native_knife.lua',1,true),'shared knife contract must load before server/client admission')
assert(not WeaponNativeKnife.Enabled(),'manifest loading alone never enables knife gameplay')
print('native knife inert contract PASS (exact allowlist, no ammo/import/customization, private identity projection, no runtime admission)')
local snapshot={characterId='john',expected={weapon_melee={itemId=900,revision=0}},equipment={melee=row}}
local approved=assert(WeaponNativeKnife.Assigned(snapshot,def,identity))
assert(WeaponNativeKnife.ValidateApproval(approved,def,identity))
approved.identity.epoch='foreign'; assert(not WeaponNativeKnife.ValidateApproval(approved,def,identity))
assert(WeaponNativeKnife.Assigned({characterId='john',expected={},equipment={}},def,identity)==false)
snapshot.expected.weapon_melee.revision=1; assert(not WeaponNativeKnife.Assigned(snapshot,def,identity))
snapshot.expected.weapon_melee.revision=0
snapshot.expected.weapon={itemId=900,revision=0}; assert(not WeaponNativeKnife.Assigned(snapshot,def,identity))
snapshot.expected.weapon=nil; snapshot.characterId='foreign'; assert(not WeaponNativeKnife.Assigned(snapshot,def,identity))
print('knife assigned-snapshot approval PASS (exact saved assignment, revision, world and duplicate veto; no candidate grants)')
snapshot.characterId='john'
local preflight={characterId='john',expected={},equipment={},candidate=row,
 knifeEquipment={characterId='john',expected={},equipment={}}}
local spec=assert(WeaponNativeKnife.Prepare(preflight,def,identity,{action='equip',slot='weapon_melee',itemId=900}))
assert(spec.knifeId==900 and spec.knifeRevision==0 and spec.lifecycleSnapshot and spec.slot=='weapon_melee')
assert(not WeaponNativeKnife.Prepare(preflight,def,identity,{action='equip',slot='weapon_melee',itemId=901}))
preflight.expected=snapshot.expected; preflight.knifeEquipment=snapshot
assert(not WeaponNativeKnife.Prepare(preflight,def,identity,{action='equip',slot='weapon_melee',itemId=900}))
assert(WeaponNativeKnife.Prepare(preflight,def,identity,{action='unequip',slot='weapon_melee'}))
assert(not WeaponNativeKnife.Prepare(preflight,def,identity,{action='unequip',slot='weapon_melee',selectedItemId=901}))
print('knife preflight PASS (owned candidate/current assigned selection, exact expected revisions and final firearm-wear snapshot)')
