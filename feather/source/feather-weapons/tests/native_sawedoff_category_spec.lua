Config={}
for _,file in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/attachments.lua',
 'shared/definitions/weapons.lua','shared/validation.lua','shared/character_ammunition_catalog.lua',
 'shared/character_ammunition_policy.lua','shared/character_ammunition_item.lua',
 'shared/character_ammunition_materialization.lua'}) do dofile(file) end
local catalog=WeaponDefinitionCatalog
local registry=assert(WeaponCharacterAmmoPolicy.Build(catalog))
local function row(id,definitionId)
 local weapon=catalog.weapons[definitionId]
 return {id=id,revision=0,itemName=weapon.itemName,metadata={schemaVersion=2,weaponDefinitionId=definitionId,
  serialNumber='ordinary-'..id,condition=100,quality=100,
  maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},
  ammo={ownership='character',type=weapon.ammunitionType},attachments={},cosmetics={},
  flags={stolen=false,evidence=false,disabled=false},provenance={}}}
end
local identity={characterId='Jane',sessionId='s',epoch='e'}
local sawedoff=row(901,'shotgun_sawedoff')
local build=WeaponCharacterAmmoMaterialization.Build
local validate=WeaponCharacterAmmoMaterialization.Validate
local plan=assert(build({primary=sawedoff},catalog,registry,identity))
assert(validate(plan,registry,identity) and plan.items[1].point==2 and plan.items[1].preferredAmmoType=='ammo_shotgun_regular')
local pair=assert(build({primary=row(902,'revolver_cattleman'),offhand=sawedoff},catalog,registry,identity))
assert(validate(pair,registry,identity) and pair.dual and not pair.sameModel and pair.items[2].point==3)
assert(not build({shoulder=sawedoff},catalog,registry,identity))
assert(not build({back=sawedoff},catalog,registry,identity))
assert(not build({offhand=sawedoff},catalog,registry,identity),'primary required')
assert(not build({primary=row(903,'shotgun_pump')},catalog,registry,identity),'not all shotguns are sidearms')
plan.items[1].slot='shoulder'; plan.items[1].point=10; plan.items[1].copyKey='shoulder:901:0'
assert(not validate(plan,registry,identity),'forged carry category refused independently')
assert(not build({primary=row(904,'revolver_lemat')},catalog,registry,identity),'LeMat exclusion unchanged')
assert(sawedoff.metadata.ammo.ownership=='character' and sawedoff.metadata.ammo.loaded==nil)
print('Sawed-off category PASS (catalog primary/offhand, shotgun pool retained, wrong slots/pump/LeMat refusal, no economy/native writes)')
