dofile('tests/native_utility_item_spec.lua')
dofile('shared/character_ammunition_loadout_lease.lua')
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local identity={characterId='john',sessionId='s',epoch='e'}
local plan={identity=identity,items={{itemInstanceId=155,itemRevision=3}}}
WeaponCharacterAmmoMaterialization={Build=function() return copy(plan) end}
local row={id=200,revision=0,itemName='weapon_lasso',metadata={schemaVersion=2,weaponDefinitionId='utility_lasso',
 serialNumber='L',condition=100,quality=100,flags={stolen=false,evidence=false,disabled=false},attachments={},cosmetics={},provenance={}}}
local utility={characterId='john',expected={weapon_utility={itemId=200,revision=0}},equipment={utility=row}}
local snapshot={characterId='john',equipment={},utilityEquipment=copy(utility)}
local lease=WeaponCharacterAmmoLoadoutLease.New(plan,nil,nil,nil,{},utility)
assert(lease.Contains(200) and lease.Contains(155) and not lease.Contains(201))
assert(lease.Validate(snapshot,WeaponDefinitionCatalog,{}))
for _,mutate in ipairs({function(s) s.utilityEquipment=nil end,
 function(s) s.utilityEquipment.equipment.utility.metadata.serialNumber='changed' end,
 function(s) s.utilityEquipment.equipment.utility.revision=1 end,
 function(s) s.utilityEquipment.expected.weapon_utility.itemId=201 end}) do
 local s=copy(snapshot); mutate(s); assert(not lease.Validate(s,WeaponDefinitionCatalog,{}))
end
utility.equipment.utility.metadata.serialNumber='caller_mutation'
assert(lease.Validate(snapshot,WeaponDefinitionCatalog,{}),'lease keeps private original approval')
local alias=copy(snapshot.utilityEquipment)
alias.expected.weapon_utility.itemId=155; alias.equipment.utility.id=155
assert(not pcall(WeaponCharacterAmmoLoadoutLease.New,plan,nil,nil,nil,{},alias))
local empty={characterId='john',expected={},equipment={}}
local emptyLease=WeaponCharacterAmmoLoadoutLease.New(plan,nil,nil,nil,{},empty)
assert(emptyLease.Validate({characterId='john',equipment={},utilityEquipment=empty},WeaponDefinitionCatalog,{}))
assert(not emptyLease.Validate(snapshot,WeaponDefinitionCatalog,{}),'empty lease cannot silently acquire a lasso')
print('staged utility lease PASS: exact item lifetime, immutable metadata/revision binding, alias and unsolicited assignment refusal')
