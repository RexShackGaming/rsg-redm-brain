Config={AmmunitionPools={enabled=false}}
dofile('shared/definitions/weapons.lua')
dofile('shared/native_binoculars_policy.lua')
dofile('shared/native_metal_detector_policy.lua')
local function copy(v)
    if type(v)~='table' then return v end
    local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local def=WeaponDefinitionCatalog.weapons.utility_metal_detector
local profile=assert(WeaponNativeMetalDetectorPolicy.Resolve(def))
assert(profile.equipmentSlot=='weapon_utility_septenary' and profile.nativeGrantAmount==0)
assert(profile.family==def.family and profile.ownershipGroup=='metal_detector')
local standard=assert(WeaponNativeBinocularsPolicy.Resolve(WeaponDefinitionCatalog.weapons.utility_binoculars))
assert((standard.ownershipGroup or standard.family)~=profile.ownershipGroup)
profile.itemName='changed'
assert(WeaponNativeMetalDetectorPolicy.Resolve(def).itemName==def.itemName)
for _,mutate in ipairs({
    function(d) d.id='utility_binoculars' end,
    function(d) d.itemName='weapon_kit_binoculars' end,
    function(d) d.nativeWeaponName='WEAPON_KIT_BINOCULARS' end,
    function(d) d.kind='item' end,
    function(d) d.family='camera' end,
    function(d) d.slot='melee' end,
    function(d) d.usesAmmunition=true end,
    function(d) d.capacity=1 end,
    function(d) d.ammunitionType='ammo_rifle_regular' end,
    function(d) d.ammunitionTypes={'ammo_rifle_regular'} end,
    function(d) d.multiTypeAmmunition=true end,
    function(d) d.nativeGrantAmount=1 end,
    function(d) d.condition.minimum=-1 end,
    function(d) d.condition.maximum=101 end,
    function(d) d.condition.equipMinimum=0 end,
    function(d) d.policies.serialRequired=false end,
    function(d) d.attachmentSlots={'sight'} end,
    function(d) d.attachmentDefaults={sight='x'} end,
}) do local bad=copy(def); mutate(bad); assert(not WeaponNativeMetalDetectorPolicy.Resolve(bad)) end
for id,d in pairs(WeaponDefinitionCatalog.weapons) do
    if id~='utility_metal_detector' then assert(not WeaponNativeMetalDetectorPolicy.Resolve(d)) end
end
assert(not WeaponNativeMetalDetectorPolicy.Resolve(nil))
local file=assert(io.open('fxmanifest.lua','r')); local manifest=file:read('*a'); file:close()
assert(manifest:find('native_metal_detector_policy.lua',1,true),'strict profile must load before collection admission')
print('Staged Improved Binoculars-only profile PASS: original sixth slot, separate carrier group, no admission or custom viewing')

