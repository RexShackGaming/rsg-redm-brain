dofile('tests/native_davy_collection_spec.lua')
dofile('shared/native_binoculars_policy.lua'); dofile('shared/native_camera_policy.lua')
dofile('shared/native_advanced_camera_policy.lua'); dofile('shared/native_improved_binoculars_policy.lua')
dofile('shared/character_ammunition_loadout_lease.lua')
local gate=1
GetConvarInt=function(name)
    if name=='feather_native_binoculars_improved' then return gate end
    return (name=='feather_native_utility' or name=='feather_native_lasso_reinforced'
        or name=='feather_native_davy_lantern' or name=='feather_native_binoculars'
        or name=='feather_native_camera' or name=='feather_native_camera_advanced') and 1 or 0
end
local U=WeaponNativeUtilityItem
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local id={characterId='john',sessionId='s',epoch='e'}
local snapshot={characterId='john',equipment={},expected={}}
local slots={'utility','utility_secondary','utility_tertiary','utility_quaternary','utility_quinary','utility_senary'}
for n,definition in ipairs({'utility_lasso_reinforced','utility_davy_lantern','utility_binoculars','utility_camera','utility_camera_advanced','utility_binoculars_improved'}) do
    local def=WeaponDefinitionCatalog.weapons[definition]
    snapshot.equipment[slots[n]]={id=171+n,revision=0,itemName=def.itemName,metadata=assert(U.Build(def,{serialNumber='S'..n}))}
    snapshot.expected['weapon_'..slots[n]]={itemId=171+n,revision=0}
end
assert(#assert(U.AssignedSnapshot(snapshot,WeaponDefinitionCatalog,id)).items==6)
local plan={identity=id,items={}}
WeaponCharacterAmmoMaterialization={Build=function() return copy(plan) end}
local lease=WeaponCharacterAmmoLoadoutLease.New(plan,nil,nil,nil,{},snapshot)
assert(lease.Contains(174) and lease.Contains(177),'both Binoculars independently held')
for _,mutate in ipairs({
    function(s) s.characterId='jane' end,
    function(s) s.equipment.utility_senary.metadata.serialNumber='changed' end,
    function(s) s.equipment.utility_senary.metadata.ammo={} end,
    function(s) s.expected.weapon_utility_senary.revision=1 end,
    function(s) s.expected.weapon_shoulder={itemId=177,revision=0} end,
    function(s) s.equipment.utility_senary.metadata.weaponDefinitionId='utility_binoculars' end,
    function(s) s.equipment.utility_senary,s.equipment.utility_tertiary=s.equipment.utility_tertiary,s.equipment.utility_senary
        s.expected.weapon_utility_senary,s.expected.weapon_utility_tertiary=s.expected.weapon_utility_tertiary,s.expected.weapon_utility_senary end,
    function(s) s.equipment.utility_septenary=s.equipment.utility_senary end,
}) do local s=copy(snapshot); mutate(s); assert(not lease.Validate({characterId='john',equipment={},utilityEquipment=s},WeaponDefinitionCatalog,{})) end
local outer={characterId='john',equipment={},expected=copy(snapshot.expected),utilityEquipment=copy(snapshot)}
local def=WeaponDefinitionCatalog.weapons.utility_binoculars_improved
local spec=assert(U.Prepare(outer,def,id,{action='unequip',slot='weapon_utility_senary',selectedItemId=177}))
assert(spec.improvedBinocularsFamily and spec.utilityId==177 and spec.expected.weapon_utility_tertiary.itemId==174)
outer.candidate=copy(snapshot.equipment.utility_senary)
outer.expected.weapon_utility_senary=nil; outer.utilityEquipment.expected.weapon_utility_senary=nil
outer.utilityEquipment.equipment.utility_senary=nil
assert(U.Prepare(outer,def,id,{action='equip',slot='weapon_utility_senary',itemId=177}))
assert(not U.Prepare(outer,def,id,{action='equip',slot='weapon_utility_tertiary',itemId=177}))
gate=0
assert(not U.AssignedSnapshot(snapshot,WeaponDefinitionCatalog,id))
assert(not U.Prepare(outer,def,id,{action='equip',slot='weapon_utility_senary',itemId=177}))
assert(not WeaponNativeUtilityCatalog.Resolve(def))
print('Improved Binoculars staged collection/lease PASS: both binocular identities, sixth slot, gate/alias/metadata/CAS refusal')
