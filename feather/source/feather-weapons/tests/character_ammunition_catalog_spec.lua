Config={AmmunitionPools={enabled=false}}
dofile('shared/definitions/ammunition.lua'); dofile('shared/definitions/weapons.lua')
dofile('shared/character_ammunition_catalog.lua')
local policy={}
local families={pistol=true,revolver=true,repeater=true,rifle=true,shotgun=true}
for _,w in pairs(WeaponDefinitionCatalog.weapons) do
    if families[w.family] and w.nativeWeaponName~='WEAPON_REVOLVER_LEMAT' then
        for _,id in ipairs(w.ammunitionTypes) do policy[id]=WeaponDefinitionCatalog.ammunition[id].maxTotal or 200 end
    end
end
local catalog=assert(WeaponCharacterAmmoCatalog.Build(WeaponDefinitionCatalog,policy))
assert(catalog.blocked.revolver_lemat and not catalog.weapons.revolver_lemat)
assert(catalog.weapons.pistol_m1899 and catalog.weapons.rifle_varmint and catalog.weapons.rifle_elephant)
assert(catalog.excluded.bow and not catalog.names.ammo_arrow_regular)
assert(catalog.names.ammo_pistol_express=='AMMO_PISTOL_EXPRESS')
policy.ammo_pistol_express=nil; assert(not WeaponCharacterAmmoCatalog.Build(WeaponDefinitionCatalog,policy))
policy.ammo_pistol_express=200; policy.ammo_pistol_explosive=11
assert(not WeaponCharacterAmmoCatalog.Build(WeaponDefinitionCatalog,policy))
policy.ammo_pistol_explosive=10; policy.ammo_arrow_regular=10
assert(not WeaponCharacterAmmoCatalog.Build(WeaponDefinitionCatalog,policy))
policy.ammo_arrow_regular=nil
WeaponDefinitionCatalog.ammunition.ammo_pistol_express.nativeAmmoName='AMMO_PISTOL'
assert(not WeaponCharacterAmmoCatalog.Build(WeaponDefinitionCatalog,policy),'aliases must not produce duplicate credits')
print('character_ammunition_catalog_spec PASS (policy validation, not native caps)')
