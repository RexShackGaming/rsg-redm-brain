Config={AmmunitionPools={enabled=false}}
dofile('shared/definitions/weapons.lua')
dofile('shared/native_camera_policy.lua')
local function copy(v)
    if type(v)~='table' then return v end
    local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local def=WeaponDefinitionCatalog.weapons.utility_camera
local profile=assert(WeaponNativeCameraPolicy.Resolve(def))
assert(profile.equipmentSlot=='weapon_utility_quaternary' and profile.nativeGrantAmount==0)
profile.itemName='changed'; assert(WeaponNativeCameraPolicy.Resolve(def).itemName==def.itemName)
for _,mutate in ipairs({
    function(d) d.id='utility_camera_advanced' end,
    function(d) d.itemName='weapon_kit_camera_advanced' end,
    function(d) d.nativeWeaponName='WEAPON_KIT_CAMERA_ADVANCED' end,
    function(d) d.family='binoculars' end,
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
}) do local bad=copy(def); mutate(bad); assert(not WeaponNativeCameraPolicy.Resolve(bad)) end
for id,d in pairs(WeaponDefinitionCatalog.weapons) do
    if id~='utility_camera' then assert(not WeaponNativeCameraPolicy.Resolve(d)) end
end
assert(not WeaponNativeCameraPolicy.Resolve(nil))
print('Staged Standard Camera-only equipment profile PASS; no admission or photography')
