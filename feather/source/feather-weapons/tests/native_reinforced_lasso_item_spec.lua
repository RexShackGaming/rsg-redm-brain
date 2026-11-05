dofile('tests/native_utility_item_spec.lua'); dofile('shared/native_lasso_policy.lua')
local U=WeaponNativeUtilityItem; local catalog=WeaponDefinitionCatalog
Config.DevMode=true; Config.NativeAlphaRuntime=true; Config.CharacterAmmunitionEnabled=true
Config.CharacterAmmoTransportEnabled=true; Config.NativeAlphaLifecycleWearEnabled=true
local reinforced=0
GetConvarInt=function(name) return name=='feather_native_utility' and 1 or name=='feather_native_lasso_reinforced' and reinforced or 0 end
local def=catalog.weapons.utility_lasso_reinforced
assert(not U.Build(def,{serialNumber='R'}),'reinforced has separate default-off gate')
reinforced=1
local metadata=assert(U.Build(def,{serialNumber='R'}))
assert(metadata.ammo==nil and metadata.maintenance==nil and metadata.weaponDefinitionId=='utility_lasso_reinforced')
local bound={characterId='john',sessionId='s',epoch='e'}
local row={id=201,revision=0,itemName='weapon_lasso_reinforced',metadata=metadata}
local snapshot={characterId='john',expected={weapon_utility_secondary={itemId=201,revision=0}},equipment={utility_secondary=row}}
local approval=assert(U.LassoAssigned(snapshot,catalog,bound))
assert(approval.equipmentSlot=='weapon_utility_secondary' and U.ValidateLassoApproval(approval,catalog,bound))
assert(U.ValidateApproval(approval,def,bound),'generic owner validates exact reinforced secondary approval')
assert(U.AssignedSnapshot(snapshot,catalog,bound).row.id==201)
local standard=catalog.weapons.utility_lasso
snapshot.equipment.utility={id=200,revision=0,itemName='weapon_lasso',metadata=assert(U.Build(standard,{serialNumber='S'}))}
snapshot.expected.weapon_utility={itemId=200,revision=0}
assert(not U.LassoAssigned(snapshot,catalog,bound),'both owned items cannot become two assigned lassos')
snapshot.equipment.utility=nil; snapshot.expected.weapon_utility=nil
snapshot.expected.weapon_melee={itemId=201,revision=0}
assert(not U.LassoAssigned(snapshot,catalog,bound),'same item cannot alias a sibling slot')
snapshot.expected.weapon_melee=nil
reinforced=0; assert(not U.ValidateLassoApproval(approval,catalog,bound))
print('staged reinforced lasso metadata/assignment PASS: separate gate, exact existing item/native/secondary slot, family exclusion and immutable approval')
