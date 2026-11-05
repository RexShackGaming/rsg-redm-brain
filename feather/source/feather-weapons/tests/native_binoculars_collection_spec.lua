dofile('tests/native_davy_collection_spec.lua')
dofile('shared/native_binoculars_policy.lua')
local gate=1
GetConvarInt=function(name) return name=='feather_native_binoculars' and gate
    or (name=='feather_native_utility' or name=='feather_native_lasso_reinforced' or name=='feather_native_davy_lantern') and 1 or 0 end
local U=WeaponNativeUtilityItem
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local id={characterId='john',sessionId='s',epoch='e'}
local snapshot={characterId='john',equipment={},expected={}}
for n,definition in ipairs({'utility_lasso_reinforced','utility_davy_lantern','utility_binoculars'}) do
    local slot=({'utility','utility_secondary','utility_tertiary'})[n]
    local def=WeaponDefinitionCatalog.weapons[definition]
    snapshot.equipment[slot]={id=171+n,revision=0,itemName=def.itemName,metadata=assert(U.Build(def,{serialNumber='S'..n}))}
    snapshot.expected['weapon_'..slot]={itemId=171+n,revision=0}
end
assert(#assert(U.AssignedSnapshot(snapshot,WeaponDefinitionCatalog,id)).items==3)
local def=WeaponDefinitionCatalog.weapons.utility_binoculars
for _,mutate in ipairs({
    function(s) s.equipment.utility_tertiary.metadata.weaponDefinitionId='utility_binoculars_improved' end,
    function(s) s.equipment.utility_tertiary.metadata.ammo={} end,
    function(s) s.expected.weapon_utility_tertiary.revision=1 end,
    function(s) s.expected.weapon_shoulder={itemId=174,revision=0} end,
    function(s) s.equipment.utility_tertiary,s.equipment.utility_secondary=s.equipment.utility_secondary,s.equipment.utility_tertiary
        s.expected.weapon_utility_tertiary,s.expected.weapon_utility_secondary=s.expected.weapon_utility_secondary,s.expected.weapon_utility_tertiary end,
    function(s) s.equipment.utility_quaternary=s.equipment.utility_tertiary end,
}) do local changed=copy(snapshot); mutate(changed); assert(not U.AssignedSnapshot(changed,WeaponDefinitionCatalog,id)) end
local outer={characterId='john',equipment={},expected=copy(snapshot.expected),utilityEquipment=copy(snapshot)}
local spec=assert(U.Prepare(outer,def,id,{action='unequip',slot='weapon_utility_tertiary',selectedItemId=174}))
assert(spec.binocularsFamily and spec.davyFamily and spec.utilityId==174)
outer.candidate=copy(snapshot.equipment.utility_tertiary)
outer.expected.weapon_utility_tertiary=nil
outer.utilityEquipment.expected.weapon_utility_tertiary=nil
outer.utilityEquipment.equipment.utility_tertiary=nil
assert(U.Prepare(outer,def,id,{action='equip',slot='weapon_utility_tertiary',itemId=174}))
assert(not U.Prepare(outer,def,id,{action='equip',slot='weapon_utility_secondary',itemId=174}))
gate=0
assert(not U.AssignedSnapshot(snapshot,WeaponDefinitionCatalog,id),'disabled third assignment cannot be silently omitted')
assert(not U.Prepare(outer,def,id,{action='equip',slot='weapon_utility_tertiary',itemId=174}))
assert(not WeaponNativeUtilityCatalog.Resolve(def))
assert(not WeaponNativeUtilityCatalog.Resolve(WeaponDefinitionCatalog.weapons.utility_binoculars_improved))
print('Binoculars third-slot projection/transition PASS: gate, slot, identity, family, alias and metadata guards')
