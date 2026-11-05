dofile('client/character_ammunition_creation_native.lua')
Config={CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true}
local identity={characterId='c',sessionId='s',epoch='e'}
local context={characterId='c',sessionId='s',ped=42}
PlayerPedId=function() return 42 end
WeaponCharacterAmmoWorldContext={Read=function() return {ok=true,value=context} end}
local constructed,cleaned=0,0
WeaponCharacterMaintenanceNative={Scoped=function(ped,current)
    assert(ped==42 and type(current)=='function')
    return {Apply=function() return true end}
end}
WeaponCharacterAmmoCreationNative.New=function(ped,current,prepare,apply)
    assert(type(apply)=='function' and apply({},identity,{})==true)
    assert(ped==42); constructed=constructed+1
    return {current=current,prepareDual=prepare}
end
local adapter=assert(WeaponCharacterAmmoCreationNative.Scoped(42,identity,function() return true end,
    function() cleaned=cleaned+1; return true end))
assert(constructed==1 and cleaned==0,'factory never prepares or cleans appearance')
identity.epoch='mutated'
assert(adapter.current({characterId='c',sessionId='s',epoch='e'}))
assert(not adapter.current(identity),'captured lease cannot be mutated')
assert(adapter.cleanupSetup() and cleaned==1)
context.sessionId='new'
assert(not adapter.current({characterId='c',sessionId='s',epoch='e'}))
assert(not adapter.cleanupSetup() and cleaned==1)
context.sessionId='s'; Config.CharacterAmmoTransportEnabled=false
assert(not WeaponCharacterAmmoCreationNative.Scoped(42,identity,function() end,function() end))
assert(not adapter.cleanupSetup() and cleaned==1)
print('scoped creation PASS (captured lease, actual world context, gated factory, changed-world cleanup refusal)')
