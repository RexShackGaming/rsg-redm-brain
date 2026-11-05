Config={AmmunitionPools={enabled=false}}
dofile('shared/definitions/ammunition.lua'); dofile('shared/definitions/weapons.lua')
dofile('shared/character_ammunition_catalog.lua'); dofile('shared/character_ammunition_policy.lua')
local policy=WeaponCharacterAmmoPolicy.Limits()
local count=0; for _ in pairs(policy) do count=count+1 end
assert(count==27 and policy.ammo_pistol_regular==100 and policy.ammo_repeater_express==200)
assert(policy.ammo_pistol_express==100 and policy.ammo_pistol_high_velocity==100
    and policy.ammo_pistol_split_point==50 and policy.ammo_rifle_regular==100
    and policy.ammo_rifle_express==100 and policy.ammo_rifle_high_velocity==100
    and policy.ammo_rifle_split_point==50 and policy.ammo_repeater_split_point==100
    and policy.ammo_revolver_split_point==100 and policy.ammo_shotgun_regular==60
    and policy.ammo_shotgun_slug==60 and policy.ammo_varmint==100
    and policy.ammo_varmint_tranquilizer==200)
assert(policy.ammo_pistol_explosive==10 and policy.ammo_shotgun_buckshot_incendiary==14
    and policy.ammo_rifle_elephant==20)
policy.ammo_pistol_regular=999
assert(WeaponCharacterAmmoPolicy.Limits().ammo_pistol_regular==100,'caller cannot change canonical policy')
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
assert(registry.limits.ammo_revolver_regular==200 and registry.blocked.revolver_lemat)
assert(registry.names.ammo_arrow_regular==nil and registry.names.ammo_tomahawk_regular==nil)
registry.limits.ammo_pistol_regular=999
assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog).limits.ammo_pistol_regular==100)
WeaponDefinitionCatalog.ammunition.ammo_new={id='ammo_new',nativeAmmoName='AMMO_NEW'}
local weapon=WeaponDefinitionCatalog.weapons.pistol_m1899
weapon.ammunitionTypes[#weapon.ammunitionTypes+1]='ammo_new'
local result,why=WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)
assert(not result and why=='missing_or_invalid_policy_limit','new type cannot inherit 200 silently')
print('character_ammunition_policy_spec PASS (27 explicit caps, defensive copies, catalog binding, no future defaults)')
