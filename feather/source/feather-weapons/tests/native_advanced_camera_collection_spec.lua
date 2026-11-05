dofile('tests/native_davy_collection_spec.lua')
dofile('shared/native_binoculars_policy.lua'); dofile('shared/native_camera_policy.lua')
dofile('shared/native_advanced_camera_policy.lua')
dofile('shared/character_ammunition_loadout_lease.lua')
local gate=1
GetConvarInt=function(name)
    if name=='feather_native_camera_advanced' then return gate end
    return (name=='feather_native_utility' or name=='feather_native_lasso_reinforced'
        or name=='feather_native_davy_lantern' or name=='feather_native_binoculars'
        or name=='feather_native_camera') and 1 or 0
end
local U=WeaponNativeUtilityItem
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local id={characterId='john',sessionId='s',epoch='e'}
local snapshot={characterId='john',equipment={},expected={}}
local slots={'utility','utility_secondary','utility_tertiary','utility_quaternary','utility_quinary'}
for n,definition in ipairs({'utility_lasso_reinforced','utility_davy_lantern','utility_binoculars','utility_camera','utility_camera_advanced'}) do
    local def=WeaponDefinitionCatalog.weapons[definition]
    snapshot.equipment[slots[n]]={id=171+n,revision=0,itemName=def.itemName,metadata=assert(U.Build(def,{serialNumber='S'..n}))}
    snapshot.expected['weapon_'..slots[n]]={itemId=171+n,revision=0}
end
local approval=assert(U.AssignedSnapshot(snapshot,WeaponDefinitionCatalog,id))
assert(#approval.items==5)
local plan={identity=id,items={{itemInstanceId=155,itemRevision=4}}}
WeaponCharacterAmmoMaterialization={Build=function() return copy(plan) end}
local lease=WeaponCharacterAmmoLoadoutLease.New(plan,nil,nil,nil,{},snapshot)
assert(lease.Contains(175) and lease.Contains(176) and lease.Contains(155))
assert(lease.Validate({characterId='john',equipment={},utilityEquipment=snapshot},WeaponDefinitionCatalog,{}))
for _,mutate in ipairs({
    function(s) s.characterId='jane' end,
    function(s) s.equipment.utility_quinary.metadata.serialNumber='changed' end,
    function(s) s.equipment.utility_quinary.metadata.ammo={} end,
    function(s) s.expected.weapon_utility_quinary.revision=1 end,
    function(s) s.expected.weapon_shoulder={itemId=176,revision=0} end,
    function(s) s.equipment.utility_quinary.metadata.weaponDefinitionId='utility_camera' end,
    function(s) s.equipment.utility_quinary,s.equipment.utility_quaternary=s.equipment.utility_quaternary,s.equipment.utility_quinary
        s.expected.weapon_utility_quinary,s.expected.weapon_utility_quaternary=s.expected.weapon_utility_quaternary,s.expected.weapon_utility_quinary end,
    function(s) s.equipment.utility_senary=s.equipment.utility_quinary end,
}) do
    local changed=copy(snapshot); mutate(changed)
    assert(not lease.Validate({characterId='john',equipment={},utilityEquipment=changed},WeaponDefinitionCatalog,{}))
end
local bad=copy(approval); bad.items[1].identity.epoch='stale'
assert(not U.ValidateCollection(bad,WeaponDefinitionCatalog,id))
bad=copy(approval); bad.items[6]=copy(bad.items[1])
assert(not U.ValidateCollection(bad,WeaponDefinitionCatalog,id))
bad=copy(approval); bad.items[1].row.id=176
assert(not U.ValidateCollection(bad,WeaponDefinitionCatalog,id))
local def=WeaponDefinitionCatalog.weapons.utility_camera_advanced
local outer={characterId='john',equipment={},expected=copy(snapshot.expected),utilityEquipment=copy(snapshot)}
local spec=assert(U.Prepare(outer,def,id,{action='unequip',slot='weapon_utility_quinary',selectedItemId=176}))
assert(spec.advancedCameraFamily and spec.utilityId==176 and spec.expected.weapon_utility_quaternary.itemId==175)
outer.candidate=copy(snapshot.equipment.utility_quinary)
outer.expected.weapon_utility_quinary=nil
outer.utilityEquipment.expected.weapon_utility_quinary=nil
outer.utilityEquipment.equipment.utility_quinary=nil
assert(U.Prepare(outer,def,id,{action='equip',slot='weapon_utility_quinary',itemId=176}))
assert(not U.Prepare(outer,def,id,{action='equip',slot='weapon_utility_quaternary',itemId=176}))
local before=copy(outer)
outer.expected.weapon_utility_quaternary.revision=9
assert(not U.Prepare(outer,def,id,{action='equip',slot='weapon_utility_quinary',itemId=176}))
outer=before
gate=0
assert(not U.AssignedSnapshot(snapshot,WeaponDefinitionCatalog,id))
assert(not U.Prepare(outer,def,id,{action='equip',slot='weapon_utility_quinary',itemId=176}))
assert(not WeaponNativeUtilityCatalog.Resolve(def))
assert(not lease.Validate({characterId='john',equipment={},utilityEquipment=snapshot},WeaponDefinitionCatalog,{}))
print('Advanced Camera staged projection/lease PASS: paired cameras, fifth hold, slot/CAS/identity/metadata/gate refusal; no runtime admission')
