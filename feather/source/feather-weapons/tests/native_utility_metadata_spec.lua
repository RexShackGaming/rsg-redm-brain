dofile('tests/native_utility_item_spec.lua')
local gate=0
Config.DevMode=true; Config.NativeAlphaRuntime=true; Config.CharacterAmmunitionEnabled=true
Config.CharacterAmmoTransportEnabled=true; Config.NativeAlphaLifecycleWearEnabled=true
GetConvarInt=function(n) return n=='feather_native_utility' and gate or 0 end
WeaponErrors={ITEM_INVALID='invalid'}
WeaponResult={Ok=function(v) return {ok=true,value=v} end,Error=function(c,m) return {ok=false,error={code=c,message=m}} end}
dofile('server/services/metadata.lua')
local def=WeaponDefinitionCatalog.weapons.utility_lasso
assert(not WeaponMetadata.Build(def,{serialNumber='L'}).ok)
gate=1
local built=assert(WeaponMetadata.Build(def,{serialNumber='L',provenance={type='development_grant'}}).value)
assert(built.ammo==nil and built.maintenance==nil and built.weaponDefinitionId=='utility_lasso')
assert(WeaponMetadata.Validate(built,def).ok)
assert(not WeaponMetadata.Build(def,{serialNumber='L',loadedAmmo=1}).ok)
assert(not WeaponMetadata.Build(def,{serialNumber='L',ammo={}}).ok)
assert(not WeaponMetadata.Build(WeaponDefinitionCatalog.weapons.utility_camera,{serialNumber='C'}).ok)
gate=0; assert(not WeaponMetadata.Validate(built,def).ok)
print('staged utility metadata PASS: default-off exact lasso schema, no ammunition or maintenance, unsupported utilities refused')
