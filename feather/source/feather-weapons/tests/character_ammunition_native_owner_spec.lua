Config={CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
dofile('client/character_ammunition_native_owner.lua')
local factories,dualCalls,create,track=0,0
local transfers=0
local world={characterId='Jane',sessionId='current',ped=7}
local state={phase='started',runtime={phase='closed'}}
local dualReady=true
local deps={context=function() return {ok=true,value=world} end,ped=function() return 7 end,
    dual=function(_,current)
        dualCalls=dualCalls+1
        return {Ensure=function() return current() end,Cleanup=function() return current() and dualReady end}
    end,
    creation=function(_,_,prepare,cleanup)
        return {prepareDual=prepare,cleanupSetup=cleanup}
    end,
    bootstrap=function(c,o)
        factories=factories+1; create,track=c,o
        return {Start=function() return true end,Status=function() return state end,
            Transfer=function(id,amount,operationId)
                assert(id=='regular' and amount==1 and operationId=='ui-test')
                transfers=transfers+1; return true
            end}
    end}
local owner=assert(WeaponCharacterAmmoNativeOwner.New(deps))
assert(factories==0 and dualCalls==0 and not owner.Start())
Config.CharacterAmmunitionEnabled=true; Config.CharacterAmmoTransportEnabled=true
assert(owner.Start() and factories==1 and dualCalls==0)
assert(not owner.Start() and factories==1)
local hint=assert(owner.Readiness()); assert(hint.characterId=='Jane' and hint.epoch==nil and hint.pools==nil)
local identity={characterId='Jane',sessionId='current',epoch='e'}
local adapter=assert(create(7,identity)); assert(dualCalls==0 and adapter.prepareDual() and dualCalls==1)
identity.sessionId='mutated'; assert(adapter.prepareDual(),'lease identity is copied')
local records={{entity=1},{entity=2}}; track(adapter,records)
assert(owner.Status().ownedCopies==2 and not owner.Readiness())
assert(not owner.Transfer('regular',1,'ui-test',{characterId='Jane',sessionId='current',epoch='old'}))
assert(not owner.Transfer('regular',1,'ui-test',{characterId='Jane',sessionId='old',epoch='e'}))
assert(transfers==0)
assert(owner.Transfer('regular',1,'ui-test',{characterId='Jane',sessionId='current',epoch='e'}) and transfers==1)
assert(not create(7,{characterId='Jane',sessionId='current',epoch='new'}))
world.sessionId='foreign'; assert(not adapter.prepareDual() and not adapter.cleanupSetup())
world.sessionId='current'; assert(not adapter.cleanupSetup(),'cannot release setup while copies remain')
table.remove(records); table.remove(records)
dualReady=false; assert(not adapter.cleanupSetup() and not owner.Readiness())
dualReady=true; assert(adapter.cleanupSetup())
state.runtime.phase='cleanup_pending'; assert(not owner.Readiness(),'server cleanup ack remains a barrier')
state.runtime.phase='closed'; assert(owner.Readiness())
state.runtime.deathRecovery={characterId='Jane',sessionId='current',epoch='wrong',ped=7}
assert(not owner.Recovery(),'recovery must match the owned creation epoch')
state.runtime.deathRecovery.epoch='e'
assert(owner.Recovery().epoch=='e')
state.runtime.deathRecovery.ped=8; assert(not owner.Recovery())
state.runtime.deathRecovery.ped=7
state.runtime.fault='frozen'; assert(not owner.Readiness()); state.runtime.fault=nil
local single=assert(create(7,{characterId='Jane',sessionId='current',epoch='single'}))
track(single,{})
assert(single.cleanupSetup() and dualCalls==1,'primary-only cleanup never initializes dual setup')
Config.CharacterAmmoTransportEnabled=false; assert(not owner.Readiness())
Config.CharacterAmmoTransportEnabled=true
local originalBootstrap=deps.bootstrap
local overlap
deps.bootstrap=function(...)
    assert(not overlap.Start(),'reserve owner startup before yielding factory')
    return originalBootstrap(...)
end
overlap=assert(WeaponCharacterAmmoNativeOwner.New(deps)); assert(overlap.Start())
local started=0
deps.bootstrap=function()
    Config.CharacterAmmoTransportEnabled=false
    return {Start=function() started=started+1; return true end,Status=function() return state end}
end
local shutdown=assert(WeaponCharacterAmmoNativeOwner.New(deps))
assert(not shutdown.Start() and started==0 and shutdown.Status().phase=='failed')
Config.CharacterAmmoTransportEnabled=true
assert(not shutdown.Start(),'failed owning startup is latched')
print('character_ammunition_native_owner_spec PASS (inert composition, scoped setup/cleanup, readiness ack barrier)')
