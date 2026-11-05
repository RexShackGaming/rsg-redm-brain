dofile('tests/character_ammunition_item_spec.lua')
dofile('shared/character_ammunition_materialization.lua')
local catalog=WeaponDefinitionCatalog
local policy={}
for _,w in pairs(catalog.weapons) do
    if ({pistol=true,revolver=true,repeater=true,rifle=true,shotgun=true})[w.family] and w.nativeWeaponName~='WEAPON_REVOLVER_LEMAT' then
        for _,id in ipairs(w.ammunitionTypes) do policy[id]=catalog.ammunition[id].maxTotal or 200 end
    end
end
local registry=assert(WeaponCharacterAmmoCatalog.Build(catalog,policy))
local function row(id)
    return {id=id,revision=2,itemName='weapon_pistol_m1899',metadata={schemaVersion=2,weaponDefinitionId='pistol_m1899',
        serialNumber='copy-'..id,condition=100,quality=100,
        maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},
        ammo={ownership='character',type='ammo_pistol_regular'},attachments={},cosmetics={},
        flags={stolen=false,evidence=false,disabled=false},provenance={}}}
end
local rows={primary=row(1),offhand=row(2)}
local identity={characterId='character',sessionId='session',epoch='epoch'}
local plan=assert(WeaponCharacterAmmoMaterialization.Build(rows,catalog,registry,identity))
assert(plan.dual and plan.sameModel and #plan.items==2)
assert(plan.items[1].copyKey~=plan.items[2].copyKey and plan.items[1].point==2 and plan.items[2].point==3)
assert(plan.items[1].creation=='inventory_guid_pair' and plan.items[1].ammo==nil and plan.items[1].loaded==nil)
plan.items[1].maintenance.dirt=1; plan.identity.epoch='changed'
assert(rows.primary.metadata.maintenance.dirt==0 and identity.epoch=='epoch')
assert(not WeaponCharacterAmmoMaterialization.Build(rows,catalog,registry,{}))
rows.offhand=rows.primary; assert(not WeaponCharacterAmmoMaterialization.Build(rows,catalog,registry,identity))
print('character_ammunition_materialization_spec PASS (data only, distinct copy keys, identity binding, no ammo instructions)')
