Config={AmmunitionPools={enabled=false}}
dofile('shared/definitions/weapons.lua')
dofile('shared/native_binoculars_policy.lua')
local function copy(v)
    if type(v)~='table' then return v end
    local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local def=WeaponDefinitionCatalog.weapons.utility_binoculars
local profile=assert(WeaponNativeBinocularsPolicy.Resolve(def))
assert(profile.itemName=='weapon_kit_binoculars' and profile.nativeGrantAmount==0
    and profile.equipmentSlot=='weapon_utility_tertiary')
profile.itemName='changed'
assert(WeaponNativeBinocularsPolicy.Resolve(def).itemName==def.itemName)
for _,mutate in ipairs({
    function(d) d.id='utility_binoculars_improved' end,
    function(d) d.itemName='weapon_kit_binoculars_improved' end,
    function(d) d.nativeWeaponName='WEAPON_KIT_BINOCULARS_IMPROVED' end,
    function(d) d.family='lantern' end,
    function(d) d.slot='melee' end,
    function(d) d.usesAmmunition=true end,
    function(d) d.capacity=1 end,
    function(d) d.ammunitionType='ammo_tomahawk_regular' end,
    function(d) d.ammunitionTypes={'ammo_tomahawk_regular'} end,
    function(d) d.multiTypeAmmunition=true end,
    function(d) d.nativeGrantAmount=1 end,
    function(d) d.condition.equipMinimum=0 end,
    function(d) d.policies.serialRequired=false end,
    function(d) d.attachmentSlots={'sight'} end,
    function(d) d.attachmentDefaults={sight='x'} end,
}) do
    local bad=copy(def); mutate(bad); assert(not WeaponNativeBinocularsPolicy.Resolve(bad))
end
for id,d in pairs(WeaponDefinitionCatalog.weapons) do
    if id~='utility_binoculars' then assert(not WeaponNativeBinocularsPolicy.Resolve(d)) end
end
assert(not WeaponNativeBinocularsPolicy.Resolve(nil))
print('Staged standard Binoculars-only profile PASS; no runtime admission or viewing controls')
