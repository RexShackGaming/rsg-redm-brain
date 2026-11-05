dofile('tests/native_davy_collection_spec.lua')
dofile('shared/native_binoculars_policy.lua'); dofile('shared/native_camera_policy.lua')
local gate=1
GetConvarInt=function(name) return name=='feather_native_camera' and gate
    or (name=='feather_native_utility' or name=='feather_native_lasso_reinforced'
        or name=='feather_native_davy_lantern' or name=='feather_native_binoculars') and 1 or 0 end
local U=WeaponNativeUtilityItem
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local id={characterId='john',sessionId='s',epoch='e'}
local snapshot={characterId='john',equipment={},expected={}}
for n,definition in ipairs({'utility_lasso_reinforced','utility_davy_lantern','utility_binoculars','utility_camera'}) do
    local slot=({'utility','utility_secondary','utility_tertiary','utility_quaternary'})[n]
    local def=WeaponDefinitionCatalog.weapons[definition]
    snapshot.equipment[slot]={id=171+n,revision=0,itemName=def.itemName,metadata=assert(U.Build(def,{serialNumber='S'..n}))}
    snapshot.expected['weapon_'..slot]={itemId=171+n,revision=0}
end
assert(#assert(U.AssignedSnapshot(snapshot,WeaponDefinitionCatalog,id)).items==4)
local def=WeaponDefinitionCatalog.weapons.utility_camera
for _,mutate in ipairs({
    function(s) s.equipment.utility_quaternary.metadata.weaponDefinitionId='utility_camera_advanced' end,
    function(s) s.equipment.utility_quaternary.metadata.ammo={} end,
    function(s) s.expected.weapon_utility_quaternary.revision=1 end,
    function(s) s.expected.weapon_shoulder={itemId=175,revision=0} end,
    function(s) s.equipment.utility_quaternary,s.equipment.utility_tertiary=s.equipment.utility_tertiary,s.equipment.utility_quaternary
        s.expected.weapon_utility_quaternary,s.expected.weapon_utility_tertiary=s.expected.weapon_utility_tertiary,s.expected.weapon_utility_quaternary end,
    function(s) s.equipment.utility_quinary=s.equipment.utility_quaternary end,
}) do local changed=copy(snapshot); mutate(changed); assert(not U.AssignedSnapshot(changed,WeaponDefinitionCatalog,id)) end
local outer={characterId='john',equipment={},expected=copy(snapshot.expected),utilityEquipment=copy(snapshot)}
local spec=assert(U.Prepare(outer,def,id,{action='unequip',slot='weapon_utility_quaternary',selectedItemId=175}))
assert(spec.cameraFamily and spec.binocularsFamily and spec.utilityId==175)
outer.candidate=copy(snapshot.equipment.utility_quaternary)
outer.expected.weapon_utility_quaternary=nil
outer.utilityEquipment.expected.weapon_utility_quaternary=nil
outer.utilityEquipment.equipment.utility_quaternary=nil
assert(U.Prepare(outer,def,id,{action='equip',slot='weapon_utility_quaternary',itemId=175}))
assert(not U.Prepare(outer,def,id,{action='equip',slot='weapon_utility_tertiary',itemId=175}))
gate=0
assert(not U.AssignedSnapshot(snapshot,WeaponDefinitionCatalog,id))
assert(not U.Prepare(outer,def,id,{action='equip',slot='weapon_utility_quaternary',itemId=175}))
assert(not WeaponNativeUtilityCatalog.Resolve(def))
assert(not WeaponNativeUtilityCatalog.Resolve(WeaponDefinitionCatalog.weapons.utility_camera_advanced))
print('Camera fourth-slot projection/transition PASS: gate, slot, CAS, alias and Advanced/metadata refusal')
