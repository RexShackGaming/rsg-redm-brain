Config={CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true}
dofile('client/character_ammunition_native_owner.lua')
local function scenario(funded,pending,replaced,nativeOnly,worldChanged,readFailure)
 local create,track
 local removed=0
 local world={characterId='c',sessionId='s',ped=7}
 local ammo={phase='active',pending=pending,baseline={epoch='e',pools={regular=funded and 1 or 0}}}
 local records={{entity=11}}
 local owner=assert(WeaponCharacterAmmoNativeOwner.New({
  context=function() return {ok=true,value=world} end,ped=function() return 7 end,
  readPools=function() if readFailure then error('native read failed') end; return {regular=(funded or nativeOnly) and 1 or 0} end,
  dual=function() error('primary-only stop cannot provision appearance') end,
  creation=function(_,_,_,cleanup) return {remove=function(record)
   assert(record.entity==11); if replaced then return false end
   removed=removed+1; return true
  end,readMaintenance=function() return {degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0} end,
   cleanupSetup=cleanup} end,
  bootstrap=function(c,t) create,track=c,t; return {Start=function() return true end,
   Status=function() return {phase='started',runtime={phase='active',session={ammo=ammo}}} end} end
 }))
 assert(owner.Start())
 local adapter=assert(create(7,{characterId='c',sessionId='s',epoch='e'})); track(adapter,records)
 if worldChanged then world.sessionId='other' end
 local maintenance=owner.MaintenanceStatus()
 if pending or worldChanged then assert(not maintenance)
 else assert(maintenance and maintenance.epoch=='e' and #maintenance.items==1) end
 local ok=owner.StopZeroAmmo()
 if funded or pending or replaced or nativeOnly or worldChanged or readFailure then assert(not ok and removed==0 and #records==1)
 else assert(ok and removed==1 and #records==0 and owner.Status().cleanupComplete and not owner.StopZeroAmmo()) end
end
scenario(false,false,false)
scenario(true,false,false)
scenario(false,true,false)
scenario(false,false,true)
scenario(false,false,false,true)
scenario(false,false,false,false,true)
scenario(false,false,false,false,false,true)
print('Native zero-ammo stop cleanup PASS (owned copy only, empty/settled gate, pending/funded/replacement refusal, idempotence)')
