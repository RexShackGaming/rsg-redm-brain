Config={DevMode=true,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true}
WeaponDefinitionCatalog={weapons={}}
GetConvarInt=function(name) return name=='feather_native_throwable' and 1 or 0 end
dofile('client/character_ammunition_native_owner.lua')
local identity={characterId='john',sessionId='s',epoch='e'}
local cleanup,parentFactory,created,phase,world=nil,nil,0,'active',true
local owner=assert(WeaponCharacterAmmoNativeOwner.New({
 context=function() return {ok=true,value={characterId='john',sessionId='s',ped=7}} end,
 ped=function() return 7 end,dual=function() error('no dual setup') end,
 creation=function(_,_,_,close) cleanup=close; return {cleanupSetup=close} end,
 throwable=function(ped,bound,current,sealed,catalog,registry)
  created=created+1
  assert(ped==7 and bound.epoch=='e' and current(identity) and sealed()=='sealed-proof' and catalog==WeaponDefinitionCatalog)
  assert(not current({characterId='foreign',sessionId='s',epoch='e'}))
  parentFactory=current
  return {Status=function() return {phase=phase} end}
 end,
 bootstrap=function(create,track,knife,melee,throwable)
  return {Start=function()
   assert(not throwable(7,identity,function() return 'sealed-proof' end,{}),'parent must reserve before child factory')
   local adapter=assert(create(7,identity)); track(adapter,{})
   assert(not throwable(7,{characterId='john',sessionId='s',epoch='foreign'},function() end,{}))
   assert(throwable(7,identity,function() return 'sealed-proof' end,{}))
   assert(not throwable(7,identity,function() end,{}),'one factory per parent epoch')
   return true
  end,Status=function() return {} end}
 end}))
assert(owner.Start() and created==1)
assert(not cleanup(),'parent setup cannot close with owned child')
phase='released'; assert(cleanup())
assert(not parentFactory(identity),'closed parent invalidates child authority')
print('throwable concrete parent binding PASS: same parent epoch, single factory, no foreign world or setup cleanup bypass')
