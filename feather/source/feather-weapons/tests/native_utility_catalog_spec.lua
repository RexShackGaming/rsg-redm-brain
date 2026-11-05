Config={AmmunitionPools={enabled=false}}
dofile('shared/definitions/weapons.lua')
dofile('shared/native_utility_catalog.lua')
local function copy(v)
 if type(v)~='table' then return v end
 local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local def=WeaponDefinitionCatalog.weapons.utility_lasso
local resolved=assert(WeaponNativeUtilityCatalog.Resolve(def))
assert(resolved.itemName=='weapon_lasso' and resolved.equipmentSlot=='weapon_utility'
 and resolved.nativeGrantAmount==0 and resolved.usesAmmunition==false)
resolved.itemName='changed'
assert(WeaponNativeUtilityCatalog.Resolve(def).itemName=='weapon_lasso')
for _,mutate in ipairs({
 function(d) d.id='utility_reinforced_lasso' end,
 function(d) d.itemName='renamed_lasso' end,
 function(d) d.nativeWeaponName='WEAPON_LASSO_REINFORCED' end,
 function(d) d.slot='melee' end,
 function(d) d.usesAmmunition=true end,
 function(d) d.ammunitionTypes={'ammo_tomahawk_regular'} end,
 function(d) d.ammunitionType='ammo_tomahawk_regular' end,
 function(d) d.capacity=1 end,
 function(d) d.nativeGrantAmount=1 end,
 function(d) d.multiTypeAmmunition=true end,
 function(d) d.condition.equipMinimum=0 end,
 function(d) d.attachmentSlots={'barrel'} end,
 function(d) d.policies.serialRequired=false end,
}) do
 local changed=copy(def); mutate(changed)
 assert(not WeaponNativeUtilityCatalog.Resolve(changed))
end
assert(not WeaponNativeUtilityCatalog.Resolve(WeaponDefinitionCatalog.weapons.utility_davy_lantern))
local file=assert(io.open('fxmanifest.lua','r')); local manifest=file:read('*a'); file:close()
assert(manifest:find('native_utility_catalog.lua',1,true),'installed utility policy must be present')
assert(not WeaponNativeUtilityCatalog.Enabled(),'manifest loading alone must not enable utility admission')
print('native utility catalog PASS: exact existing lasso definition, ammo-free profile, foreign/mutated rejection; inert only')
