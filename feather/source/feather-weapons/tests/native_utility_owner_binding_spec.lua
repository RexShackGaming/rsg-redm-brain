Config={CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,DevMode=true,NativeAlphaRuntime=true}
local gate=1
GetConvarInt=function(name) return name=='feather_native_utility' and gate or 0 end
WeaponDefinitionCatalog={weapons={utility_lasso={id='utility_lasso'}}}
local create,track,utility
local state={phase='started',runtime={phase='active'}}
local world={characterId='john',sessionId='s',ped=7}
local utilityState='idle'
dofile('client/character_ammunition_native_owner.lua')
local owner=assert(WeaponCharacterAmmoNativeOwner.New({context=function() return {ok=true,value=world} end,
 ped=function() return 7 end,dual=function() return {} end,
 creation=function(_,_,_,cleanup) return {cleanupSetup=cleanup} end,
 bootstrap=function(c,t,_,_,_,u)
  create,track,utility=c,t,u
  return {Start=function() return true end,Status=function() return state end}
 end,
 utility=function(_,identity,current,sealed,def)
  assert(current(identity) and def.id=='utility_lasso' and type(sealed)=='function')
  return {Create=function() utilityState='active'; return true end,
   Release=function() assert(current(identity)); utilityState='released'; return true end,
   Status=function() return {phase=utilityState} end}
 end}))
assert(owner.Start())
local id={characterId='john',sessionId='s',epoch='e'}
assert(not utility(7,id,function() return true end),'utility cannot create an independent parent lease')
local adapter=assert(create(7,id)); track(adapter,{})
gate=0; assert(not utility(7,id,function() return true end)); gate=1
local child=assert(utility(7,id,function() return true end)); assert(child.Create())
assert(not utility(7,id,function() return true end),'only one child factory per parent lease')
assert(not adapter.cleanupSetup(),'parent cannot release before exact utility cleanup')
assert(child.Release() and adapter.cleanupSetup() and owner.Status().cleanupComplete)
print('utility concrete parent binding PASS: default-off factory, same identity/lease, single attempt and parent cleanup barrier')
