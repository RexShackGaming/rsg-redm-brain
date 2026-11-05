dofile('tests/native_utility_item_spec.lua')
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local U=WeaponNativeUtilityItem
local def=WeaponDefinitionCatalog.weapons.utility_lasso
local bound={characterId='john',sessionId='s',epoch='e'}
local row={id=200,revision=0,itemName='weapon_lasso',metadata={schemaVersion=2,weaponDefinitionId='utility_lasso',
 serialNumber='L',condition=100,quality=100,flags={stolen=false,evidence=false,disabled=false},attachments={},cosmetics={},provenance={}}}
local snapshot={characterId='john',expected={weapon={itemId=155,revision=3}},equipment={primary={id=155}},candidate=copy(row),
 utilityEquipment={characterId='john',expected={weapon={itemId=155,revision=3}},equipment={}}}
local intent={action='equip',slot='weapon_utility',itemId=200}
local plan=assert(U.Prepare(snapshot,def,bound,intent))
assert(plan.utility and plan.utilityId==200 and plan.utilityRevision==0 and plan.before.serialNumber=='L')
plan.before.serialNumber='changed'; assert(snapshot.candidate.metadata.serialNumber=='L')
for _,mutate in ipairs({function(s) s.utilityEquipment.expected.weapon.revision=4 end,
 function(s) s.expected.weapon=nil end,function(s) s.characterId='jane' end,
 function(s) s.candidate.metadata.flags.disabled=true end,
 function(s) s.expected.weapon_melee={itemId=200,revision=0}; s.utilityEquipment.expected.weapon_melee={itemId=200,revision=0} end}) do
 local s=copy(snapshot); mutate(s); assert(not U.Prepare(s,def,bound,intent))
end
local evil=copy(intent); evil.nativeWeaponName='WEAPON_MELEE_KNIFE'; assert(not U.Prepare(snapshot,def,bound,evil))
snapshot.expected.weapon_utility={itemId=200,revision=0}
snapshot.utilityEquipment.expected=copy(snapshot.expected); snapshot.utilityEquipment.equipment.utility=copy(row)
intent={action='unequip',slot='weapon_utility',selectedItemId=200}
assert(U.Prepare(snapshot,def,bound,intent))
intent.selectedItemId=201; assert(not U.Prepare(snapshot,def,bound,intent))
print('staged utility transition plan PASS: coherent full snapshots, exact candidate/assignment, immutable before-image, no reservation or writes')
