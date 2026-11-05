dofile('tests/native_improved_binoculars_collection_spec.lua')
dofile('shared/native_metal_detector_policy.lua'); dofile('shared/native_fishing_rod_policy.lua')
local gates={feather_native_metal_detector=1,feather_native_fishing_rod=1}
GetConvarInt=function(name) if gates[name]~=nil then return gates[name] end; return 1 end
local U=WeaponNativeUtilityItem
local function copy(v) if type(v)~='table' then return v end; local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local bound={characterId='john',sessionId='s',epoch='e'}
local snapshot={characterId='john',equipment={},expected={}}
local definitions={'utility_lasso_reinforced','utility_davy_lantern','utility_binoculars','utility_camera','utility_camera_advanced','utility_binoculars_improved','utility_metal_detector','utility_fishing_rod'}
local slots={'utility','utility_secondary','utility_tertiary','utility_quaternary','utility_quinary','utility_senary','utility_septenary','utility_octonary'}
for n,key in ipairs(definitions) do
 local def=WeaponDefinitionCatalog.weapons[key]
 snapshot.equipment[slots[n]]={id=171+n,revision=0,itemName=def.itemName,metadata=assert(U.Build(def,{serialNumber='T'..n}))}
 snapshot.expected['weapon_'..slots[n]]={itemId=171+n,revision=0}
end
assert(#assert(U.AssignedSnapshot(snapshot,WeaponDefinitionCatalog,bound)).items==8)
local plan={identity=bound,items={}}
WeaponCharacterAmmoMaterialization={Build=function() return copy(plan) end}
local lease=WeaponCharacterAmmoLoadoutLease.New(plan,nil,nil,nil,{},snapshot)
assert(lease.Contains(178) and lease.Contains(179))
for n=7,8 do
 local slot='weapon_'..slots[n];local def=WeaponDefinitionCatalog.weapons[definitions[n]]
 local outer={characterId='john',equipment={},expected=copy(snapshot.expected),utilityEquipment=copy(snapshot)}
 local spec=assert(U.Prepare(outer,def,bound,{action='unequip',slot=slot,selectedItemId=171+n}))
 assert(spec.expected.weapon_utility_senary.itemId==177)
 outer.candidate=copy(snapshot.equipment[slots[n]])
 outer.expected[slot]=nil;outer.utilityEquipment.expected[slot]=nil;outer.utilityEquipment.equipment[slots[n]]=nil
 assert(U.Prepare(outer,def,bound,{action='equip',slot=slot,itemId=171+n}))
 local bad=copy(snapshot);bad.equipment[slots[n]].metadata.serialNumber='changed'
 assert(not lease.Validate({characterId='john',equipment={},utilityEquipment=bad},WeaponDefinitionCatalog,{}))
 bad=copy(snapshot);bad.expected[slot].revision=1;assert(not U.AssignedSnapshot(bad,WeaponDefinitionCatalog,bound))
 assert(not U.Prepare(outer,def,bound,{action='equip',slot='weapon_'..slots[n==7 and 8 or 7],itemId=171+n}))
 local flag=n==7 and 'feather_native_metal_detector' or 'feather_native_fishing_rod'
 gates[flag]=0
 assert(not U.AssignedSnapshot(snapshot,WeaponDefinitionCatalog,bound))
 assert(not WeaponNativeUtilityCatalog.Resolve(def))
 gates[flag]=1
end
-- Either new carrier can be enabled alone; missing seventh is not a missing eighth.
gates.feather_native_metal_detector=0
local onlyRod=copy(snapshot);onlyRod.equipment.utility_septenary=nil;onlyRod.expected.weapon_utility_septenary=nil
assert(#assert(U.AssignedSnapshot(onlyRod,WeaponDefinitionCatalog,bound)).items==7)
gates.feather_native_metal_detector=1;gates.feather_native_fishing_rod=0
local onlyDetector=copy(snapshot);onlyDetector.equipment.utility_octonary=nil;onlyDetector.expected.weapon_utility_octonary=nil
assert(#assert(U.AssignedSnapshot(onlyDetector,WeaponDefinitionCatalog,bound)).items==7)
