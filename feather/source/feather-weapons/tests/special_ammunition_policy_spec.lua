Config={NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaLifecycleWearEnabled=true,AmmunitionPools={enabled=false}}
local flags={feather_throwable_quantities=1,feather_regular_arrows=1,feather_throwing_knife_quantities=1}
GetConvarInt=function(n,d) return flags[n] or d end
GetConvar=function(n,d) return flags[n] and tostring(flags[n]) or d end
exports=function() end
for _,p in ipairs({'shared/throwable_mode.lua','shared/constants.lua','shared/definitions/ammunition.lua',
 'shared/definitions/weapons.lua','shared/definitions/attachments.lua','shared/character_ammunition.lua',
 'shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua','shared/native_throwable_policy.lua',
 'shared/native_melee_catalog.lua','shop_config.lua','server/services/gun_store_catalog.lua'}) do dofile(p) end
local catalog=WeaponDefinitionCatalog
local r=assert(WeaponCharacterAmmoPolicy.Build(catalog))
assert(not r.limits.ammo_arrow_poison and not r.limits.ammo_throwing_knives_poison)
flags.feather_special_arrows=1;flags.feather_poison_knives=1
r=assert(WeaponCharacterAmmoPolicy.Build(catalog))
local profiles=assert(WeaponSpecialAmmunitionPolicy.Profiles(catalog))
local n=0
for id,p in pairs(profiles) do
 n=n+1;assert(r.limits[id]==p.capacity and r.names[id]==p.nativeAmmoName)
 if p.family=='bow' then assert(r.weapons.bow.compatible[id] and not p.recoveryType)
 else assert(p.recoveryType=='ammo_throwing_knives_regular' and not r.weapons.throwable_throwing_knives) end
end
assert(n==5 and not r.limits.ammo_arrow_improved and not r.limits.ammo_throwing_knives_improved)
local offers=assert(WeaponGunStore.Build(WeaponStoreConfig,catalog).value).stores[1].offers
local seen={};for _,o in ipairs(offers) do seen[o.itemName]=true end
for id in pairs(profiles) do assert(seen[id],id..' missing shop offer') end
local a=catalog.ammunition.ammo_arrow_poison
a.nativeAmmoName='AMMO_ARROW';assert(not WeaponCharacterAmmoPolicy.Build(catalog));a.nativeAmmoName='AMMO_ARROW_POISON'
a.maxTotal=9;assert(not WeaponCharacterAmmoPolicy.Build(catalog));a.maxTotal=8
profiles.ammo_arrow_poison.capacity=999
assert(WeaponSpecialAmmunitionPolicy.Profile(catalog,'ammo_arrow_poison').capacity==8,'profile results are isolated')
flags.feather_special_arrows=0;flags.feather_poison_knives=0
assert(not WeaponCharacterAmmoPolicy.Build(catalog).limits.ammo_arrow_poison)
print('PASS special policy: explicit opt-ins, five historically validated variants, exact native/cap definitions, no Improved/carrier issue, shop admission, recovery evidence separated')
