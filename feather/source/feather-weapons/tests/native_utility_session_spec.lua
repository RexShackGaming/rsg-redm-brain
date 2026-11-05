dofile('tests/native_utility_item_spec.lua'); dofile('client/native_utility_owner.lua')
dofile('client/character_ammunition_session.lua')
dofile('shared/native_lasso_policy.lua')
Config.DevMode=true; Config.NativeAlphaRuntime=true; Config.CharacterAmmunitionEnabled=true
Config.CharacterAmmoTransportEnabled=true; Config.NativeAlphaLifecycleWearEnabled=true
GetConvarInt=function(name) return (name=='feather_native_utility' or name=='feather_native_lasso_reinforced') and 1 or 0 end
local id={characterId='john',sessionId='s',epoch='e'}
local approval={identity=id,equipmentSlot='weapon_utility',row={id=200,revision=0,itemName='weapon_lasso',
 metadata={schemaVersion=2,weaponDefinitionId='utility_lasso',serialNumber='L',condition=100,quality=100,
 flags={stolen=false,evidence=false,disabled=false},attachments={},cosmetics={},provenance={}}}}
WeaponCharacterAmmoMaterialization={Validate=function() return true end}
WeaponCharacterAmmoClient={New=function() return {Begin=function() return {} end} end}
WeaponCharacterAmmoNative={New=function() return {Read=function() return {ammo=0} end} end}
WeaponCharacterAmmoLoadout={New=function() return {Create=function() return {handles={}} end} end}
for _,mode in ipairs({'success','factory','create','cleanup','death','reinforced'}) do
 local approved=approval
 if mode=='reinforced' then
  approved={identity=id,equipmentSlot='weapon_utility_secondary',row={id=201,revision=0,itemName='weapon_lasso_reinforced',
   metadata=assert(WeaponNativeUtilityItem.Build(WeaponDefinitionCatalog.weapons.utility_lasso_reinforced,{serialNumber='R'}))}}
 end
 local state={phase='active',baseline=id}
 local grants,removes,acks,setup,restores=0,0,0,0,0
 WeaponCharacterAmmoController={New=function() return {
  Status=function() return state end,Begin=function() restores=restores+1; return true end,
  Finalize=function() state.phase='sealed'; return true end,
  FinalizeDeath=function() state.phase='sealed'; state.deathClosing=true; return true end,
  AllowDeathCleanup=function() state.deathClosing=false; return true end,
  ConfirmCleanup=function() acks=acks+1; return true end} end}
 local api={ped=function() return 7 end,ready=function() return true end,block=function() end,
  creation=function() return {cleanupSetup=function() setup=setup+1; return true end} end,
  utility=function(_,identity,sealed,definition)
   assert(definition.id==(mode=='reinforced' and 'utility_lasso_reinforced' or 'utility_lasso'))
   if mode=='factory' then error('uncertain factory') end
   return assert(WeaponNativeUtilityOwner.New({current=function() return true end,present=function() return false end,
    create=function() grants=grants+1; if mode=='create' then error('uncertain creation') end; return true end,
    capture=function() return {guid=string.rep('a',32)} end,sealed=sealed,
    removeCaptured=function() removes=removes+1; return mode~='cleanup' end,
    absent=function() return true end},definition,identity))
  end}
 local session=WeaponCharacterAmmoSession.New(api,{limits={},names={}})
 local began=session.Begin({runtime=id,creation={identity=id},utility=approved})
 if mode=='factory' or mode=='create' then
  assert(not began and restores==0 and session.Status().phase=='frozen')
  assert(not session.Cleanup() and acks==0 and setup==0)
 else
  assert(began and grants==1 and restores==1 and session.Status().utility.phase=='active')
  if mode=='death' then
   assert(session.FinalizeDeath()); assert(not session.Cleanup()); assert(session.RecoverDeath())
  else
   assert(session.Finalize()); local result=session.Cleanup()
   if mode=='cleanup' then assert(not result and acks==0 and setup==0)
   else assert(result) end
  end
  if mode~='cleanup' then assert(removes==1 and acks==1 and setup==1) end
 end
end
print('staged utility session PASS: creation before restore, sealed release/death barrier, uncertain child prevents parent acknowledgement; mocked controller/natives')
