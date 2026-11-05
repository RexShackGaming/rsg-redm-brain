Config={AmmunitionPools={enabled=false}}
dofile('shared/definitions/weapons.lua')
dofile('shared/native_camera_policy.lua')
dofile('shared/native_advanced_camera_policy.lua')
local function copy(v)
    if type(v)~='table' then return v end
    local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local def=WeaponDefinitionCatalog.weapons.utility_camera_advanced
local profile=assert(WeaponNativeAdvancedCameraPolicy.Resolve(def))
assert(profile.equipmentSlot=='weapon_utility_quinary' and profile.nativeGrantAmount==0)
assert(profile.family==def.family and profile.ownershipGroup=='camera_advanced')
local standard=assert(WeaponNativeCameraPolicy.Resolve(WeaponDefinitionCatalog.weapons.utility_camera))
assert((standard.ownershipGroup or standard.family)~=profile.ownershipGroup,'coexistence must not change canonical camera family')
profile.itemName='changed'
assert(WeaponNativeAdvancedCameraPolicy.Resolve(def).itemName==def.itemName)
for _,mutate in ipairs({
    function(d) d.id='utility_camera' end,
    function(d) d.itemName='weapon_kit_camera' end,
    function(d) d.nativeWeaponName='WEAPON_KIT_CAMERA' end,
    function(d) d.kind='item' end,
    function(d) d.family='binoculars' end,
    function(d) d.slot='melee' end,
    function(d) d.usesAmmunition=true end,
    function(d) d.capacity=1 end,
    function(d) d.ammunitionType='film' end,
    function(d) d.ammunitionTypes={'film'} end,
    function(d) d.multiTypeAmmunition=true end,
    function(d) d.nativeGrantAmount=1 end,
    function(d) d.condition.minimum=-1 end,
    function(d) d.condition.maximum=101 end,
    function(d) d.condition.equipMinimum=0 end,
    function(d) d.policies.serialRequired=false end,
    function(d) d.attachmentSlots={'sight'} end,
    function(d) d.attachmentDefaults={sight='x'} end,
}) do local bad=copy(def); mutate(bad); assert(not WeaponNativeAdvancedCameraPolicy.Resolve(bad)) end
for id,d in pairs(WeaponDefinitionCatalog.weapons) do
    if id~='utility_camera_advanced' then assert(not WeaponNativeAdvancedCameraPolicy.Resolve(d)) end
end
assert(not WeaponNativeAdvancedCameraPolicy.Resolve(nil))
local file=assert(io.open('fxmanifest.lua','r')); local manifest=file:read('*a'); file:close()
assert(manifest:find('native_advanced_camera_policy.lua',1,true),'strict policy must load before collection admission')
print('Staged Advanced Camera-only profile PASS: distinct carrier group, original fifth slot, no runtime admission or photography')
