dofile('tests/character_ammunition_materialization_spec.lua')
dofile('shared/character_ammunition_loadout_lease.lua')
local item={id=1,revision=2,itemName='weapon_pistol_m1899',metadata={schemaVersion=2,weaponDefinitionId='pistol_m1899',
    serialNumber='copy1',condition=100,quality=100,maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},
    ammo={ownership='character',type='ammo_pistol_regular'},attachments={},cosmetics={},
    flags={stolen=false,evidence=false,disabled=false},provenance={}}}
local catalog,policy=WeaponDefinitionCatalog,{}
for _,w in pairs(catalog.weapons) do
    if ({pistol=true,revolver=true,repeater=true,rifle=true,shotgun=true})[w.family] and w.nativeWeaponName~='WEAPON_REVOLVER_LEMAT' then
        for _,id in ipairs(w.ammunitionTypes) do policy[id]=catalog.ammunition[id].maxTotal or 200 end
    end
end
local registry=assert(WeaponCharacterAmmoCatalog.Build(catalog,policy))
local snapshot={characterId='c',equipment={primary=item}}
local plan=assert(WeaponCharacterAmmoMaterialization.Build(snapshot.equipment,catalog,registry,{characterId='c',sessionId='s',epoch='e'}))
local lease=WeaponCharacterAmmoLoadoutLease.New(plan)
assert(lease.Contains(1) and not lease.Contains(2) and lease.Validate(snapshot,catalog,registry))
plan.items[1].itemRevision=99; assert(lease.Validate(snapshot,catalog,registry))
item.revision=3; assert(not lease.Validate(snapshot,catalog,registry)); item.revision=2
item.metadata.condition=90; assert(not lease.Validate(snapshot,catalog,registry)); item.metadata.condition=100
snapshot.characterId='other'; assert(not lease.Validate(snapshot,catalog,registry)); snapshot.characterId='c'
snapshot.equipment={}; assert(not lease.Validate(snapshot,catalog,registry),'unequip invalidates binding')
print('character_ammunition_loadout_lease_spec PASS (immutable binding, revision/content/identity/unequip rejection)')
