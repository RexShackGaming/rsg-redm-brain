Config={AmmunitionPools={enabled=false}}
dofile('shared/definitions/weapons.lua')
dofile('shared/native_davy_lantern_policy.lua')
local function copy(v)
    if type(v)~='table' then return v end
    local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local def=WeaponDefinitionCatalog.weapons.utility_davy_lantern
local profile=assert(WeaponNativeDavyLanternPolicy.Resolve(def))
assert(profile.itemName=='weapon_melee_davy_lantern' and profile.nativeGrantAmount==0)
profile.itemName='changed'
assert(WeaponNativeDavyLanternPolicy.Resolve(def).itemName==def.itemName)
for _,mutate in ipairs({
    function(d) d.id='utility_lantern' end,
    function(d) d.itemName='weapon_melee_lantern' end,
    function(d) d.nativeWeaponName='WEAPON_MELEE_LANTERN' end,
    function(d) d.family='lasso' end,
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
    local bad=copy(def); mutate(bad); assert(not WeaponNativeDavyLanternPolicy.Resolve(bad))
end
for id,d in pairs(WeaponDefinitionCatalog.weapons) do
    if id~='utility_davy_lantern' then assert(not WeaponNativeDavyLanternPolicy.Resolve(d)) end
end
assert(not WeaponNativeDavyLanternPolicy.Resolve(nil))
print('Staged Davy-only policy PASS; no runtime admission')
