Config={CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,DevMode=true,NativeAlphaRuntime=true}
GetConvarInt=function() return 1 end
local create,track,knife
local state={phase='started',runtime={phase='active'}}
local world={characterId='john',sessionId='s',ped=7}
local knifeState='idle'
dofile('client/character_ammunition_native_owner.lua')
local owner=assert(WeaponCharacterAmmoNativeOwner.New({context=function() return {ok=true,value=world} end,
 ped=function() return 7 end,dual=function() return {} end,
 creation=function(_,_,_,cleanup) return {cleanupSetup=cleanup} end,
 bootstrap=function(c,t,k) create,track,knife=c,t,k; return {Start=function() return true end,Status=function() return state end} end,
 knife=function(_,identity,current)
  assert(current(identity))
  return {Create=function() knifeState='active'; return true end,
   Release=function() assert(current(identity)); knifeState='released'; return true end,
   Status=function() return {phase=knifeState} end}
 end}))
assert(owner.Start())
local id={characterId='john',sessionId='s',epoch='e'}
assert(not knife(7,id),'factory cannot create an independent owning lease')
local adapter=assert(create(7,id)); track(adapter,{})
local companion=assert(knife(7,id)); assert(companion.Create())
assert(not adapter.cleanupSetup(),'owning lease cannot close before knife release')
assert(not knife(7,id),'one knife factory reservation per owning lease')
assert(companion.Release() and adapter.cleanupSetup())
assert(owner.Status().cleanupComplete)
print('knife concrete owner binding PASS (same lease, parent before companion, cleanup barrier, no duplicate factory)')
