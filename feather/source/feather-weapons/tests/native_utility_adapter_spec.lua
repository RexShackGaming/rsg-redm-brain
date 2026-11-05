dofile('tests/native_utility_item_spec.lua'); dofile('client/native_utility_owner.lua')
dofile('client/native_utility_adapter.lua')
dofile('shared/native_lasso_policy.lua')
dofile('shared/native_davy_lantern_policy.lua')
dofile('shared/native_binoculars_policy.lua')
dofile('shared/native_camera_policy.lua')
dofile('shared/native_advanced_camera_policy.lua')
dofile('shared/native_improved_binoculars_policy.lua')
dofile('shared/native_fishing_rod_policy.lua')
dofile('shared/native_metal_detector_policy.lua')
Config.DevMode=true; Config.NativeAlphaRuntime=true; Config.CharacterAmmunitionEnabled=true
Config.CharacterAmmoTransportEnabled=true; Config.NativeAlphaLifecycleWearEnabled=true
GetConvarInt=function(name) return (name=='feather_native_utility' or name=='feather_native_lasso_reinforced' or name=='feather_native_davy_lantern' or name=='feather_native_binoculars' or name=='feather_native_camera' or name=='feather_native_camera_advanced' or name=='feather_native_metal_detector' or name=='feather_native_fishing_rod' or name=='feather_native_binoculars_improved') and 1 or 0 end
local def=WeaponDefinitionCatalog.weapons.utility_lasso
local identity={characterId='john',sessionId='s',epoch='e'}
local approval={identity=identity,equipmentSlot='weapon_utility',row={id=200,revision=0,itemName='weapon_lasso',
 metadata={schemaVersion=2,weaponDefinitionId='utility_lasso',serialNumber='L',condition=100,quality=100,
 flags={stolen=false,evidence=false,disabled=false},attachments={},cosmetics={},provenance={}}}}
for _,mode in ipairs({'success','wrong_model','remove_failure','replacement_guid','stale_world','unreadable_presence','reinforced_success','davy_success','binoculars_success','camera_success','advanced_camera_success','metal_detector_success','fishing_rod_success','improved_binoculars_success'}) do
 local definition=mode=='fishing_rod_success' and WeaponDefinitionCatalog.weapons.utility_fishing_rod or mode=='metal_detector_success' and WeaponDefinitionCatalog.weapons.utility_metal_detector or mode=='improved_binoculars_success' and WeaponDefinitionCatalog.weapons.utility_binoculars_improved or mode=='advanced_camera_success' and WeaponDefinitionCatalog.weapons.utility_camera_advanced or mode=='camera_success' and WeaponDefinitionCatalog.weapons.utility_camera or mode=='binoculars_success' and WeaponDefinitionCatalog.weapons.utility_binoculars or mode=='davy_success' and WeaponDefinitionCatalog.weapons.utility_davy_lantern or mode=='reinforced_success' and WeaponDefinitionCatalog.weapons.utility_lasso_reinforced or def
 local approved=approval
 if mode=='reinforced_success' or mode=='davy_success' or mode=='binoculars_success' or mode=='camera_success' or mode=='advanced_camera_success' or mode=='metal_detector_success' or mode=='fishing_rod_success' or mode=='improved_binoculars_success' then
  approved={identity=identity,equipmentSlot=mode=='fishing_rod_success' and 'weapon_utility_octonary' or mode=='metal_detector_success' and 'weapon_utility_septenary' or mode=='improved_binoculars_success' and 'weapon_utility_senary' or mode=='advanced_camera_success' and 'weapon_utility_quinary' or mode=='camera_success' and 'weapon_utility_quaternary' or mode=='binoculars_success' and 'weapon_utility_tertiary' or 'weapon_utility_secondary',row={id=201,revision=0,itemName=definition.itemName,
   metadata=assert(WeaponNativeUtilityItem.Build(definition,{serialNumber='R'}))}}
 end
 local has,removed,grants,removals,world,swapped=false,false,0,0,true,false
 joaat=function(v) return v==definition.nativeWeaponName and 123 or 456 end
 PlayerPedId=function() return 7 end; DoesEntityExist=function() return 1 end
 IsEntityDead=function() return false end; HasPedGotWeapon=function()
  if mode=='unreadable_presence' then return nil end
  return has and 1 or 0
 end
 GetGameTimer=function() return 0 end; Wait=function() error('unexpected wait') end
 GetCurrentPedWeapon=function(_,_,point) return point==0 and has,123 end
 GetCurrentPedWeaponEntityIndex=function() return 70 end
 GiveWeaponToPed=function(ped,hash,amount)
  assert(ped==7 and hash==123 and amount==0); grants=grants+1; has=true
 end
 WeaponCharacterAmmoCreationNative={
  DecodeDiagnosticGuid=function() return {scriptSlotWords={swapped and 9 or 1,2,3,4}} end,
  DecodeEquippedChild=function(_,result) if result==1 then return {itemHash=mode=='wrong_model' and 999 or 123} end end}
 Citizen={InvokeNative=function(hash)
  if hash==0x6929E22158E52265 then return 1 end
  if hash==0x9700E8EFC4AB9089 then return removed and 0 or 1 end
  assert(hash==0x3E4E811480B3AE79,'no ammo setters or model-wide removal')
  removals=removals+1
  if mode=='remove_failure' then return false end
  removed=true; has=false; return 1
 end}
 local owner=assert(WeaponNativeUtilityAdapter.Scoped(7,identity,function() return world end,function() return true end,definition))
 assert(grants==0 and removals==0)
 local made=owner.Create(approved)
 if mode=='wrong_model' or mode=='unreadable_presence' then assert(not made and removals==0)
 else
  assert(made)
  if mode=='stale_world' then world=false end
  if mode=='replacement_guid' then swapped=true end
  local released=owner.Release()
  if mode=='remove_failure' or mode=='stale_world' or mode=='replacement_guid' then assert(not released)
  else assert(released and owner.Release() and removals==1) end
  if mode=='replacement_guid' then assert(removals==0,'replacement GUID cannot be removed') end
 end
 assert(grants==(mode=='unreadable_presence' and 0 or 1))
end
print('staged lasso concrete adapter PASS: zero-ammo native grant, GUID/model readback, targeted inventory purge, current/sealed cleanup; mocked natives')
