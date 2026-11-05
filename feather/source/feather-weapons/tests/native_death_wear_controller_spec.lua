Config={NativeAlphaLifecycleWearEnabled=true}
dofile('shared/character_ammunition.lua'); dofile('shared/character_ammunition_client.lua')
dofile('client/character_ammunition_native.lua'); dofile('client/character_ammunition_controller.lua')
local function scenario(missing)
 local alive=true; local sent
 local wear=not missing and {epoch='e',medicalRevision=7,items={}} or nil
 local controller=WeaponCharacterAmmoController.New({ready=function() return alive end,ped=function() return 1 end,
  hash=function(v) return v end,read=function() return 0 end,write=function() end,
  deathSnapshot=function() return {characterId='c',sessionId='s',ped=1,lifeState='dead',pools={ammo=0},deathWear=wear} end,
  send=function(kind,id,report,callback)
   if kind=='restore' then callback({ok=true,value={characterId='c',sessionId='s',epoch='e',revision=25,pools={ammo=0},phase='active'}})
   else sent={report=report,callback=callback}; assert(kind=='seal') end
  end})
 assert(controller.Begin({characterId='c',sessionId='s',epoch='e',revision=25,pools={ammo=0},phase='restoring'},{ammo='AMMO_REGULAR'},{ammo=10}))
 alive=false
 local started=controller.FinalizeDeath()
 if missing then assert(not started and not sent and controller.Status().phase=='frozen')
 else
  assert(started and sent.report.deathWear==wear and controller.Status().phase=='active','no local seal acknowledgment')
  sent.callback({ok=true,value={characterId='c',sessionId='s',epoch='e',revision=25,pools={ammo=0},phase='sealed'}})
  assert(controller.Status().phase=='sealed' and controller.Status().deathClosing)
 end
end
scenario(false); scenario(true)
print('Death controller PASS (wear travels only on final seal, missing readback freezes, server acknowledgment remains the seal barrier)')
