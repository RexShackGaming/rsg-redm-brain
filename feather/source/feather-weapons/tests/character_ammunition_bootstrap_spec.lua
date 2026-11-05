dofile('client/character_ammunition_client_runtime.lua')
Config={CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
local created,registered,frames,blocked,suspended=0,0,0,false,nil
WeaponCharacterAmmoClientRuntime.New=function()
    created=created+1
    return {Step=function() frames=frames+1; return true end,Checkpoint=function() return {ok=true} end,
        Suspend=function(reason) suspended=reason end,Status=function() return {phase='closed'} end}
end
local function callable(fn) return setmetatable({__cfx_functionReference='test'}, {__call=function(_,...) return fn(...) end}) end
local scheduled
local bindings={ingress=callable(function(runtime) registered=registered+1; assert(runtime.Step); return true end),
    checkpoint=callable(function(checkpoint) registered=registered+1; assert(checkpoint().ok); return true end),
    frame=function(frame) registered=registered+1; scheduled=frame; return true end}
local bootstrap=assert(WeaponCharacterAmmoClientBootstrap.New({block=function(value) blocked=value end},bindings))
assert(not bootstrap.Start() and created==0 and registered==0)
Config.CharacterAmmunitionEnabled=true
assert(not bootstrap.Start() and created==0)
Config.CharacterAmmoTransportEnabled=true
assert(bootstrap.Start() and created==1 and registered==3)
assert(not bootstrap.Start() and created==1)
assert(scheduled() and frames==1)
Config.CharacterAmmoTransportEnabled=false
assert(not scheduled() and blocked and suspended=='bootstrap_disabled' and frames==1)
Config.CharacterAmmoTransportEnabled=true
assert(not scheduled(),'disabled runtime cannot automatically resume')
local partial=assert(WeaponCharacterAmmoClientBootstrap.New({block=function(value) blocked=value end},
    {ingress=function() coroutine.yield('register_wait'); return true end,
        checkpoint=function() return false end,frame=function() error('must not register frame after refusal') end}))
local thread=coroutine.create(partial.Start)
assert(coroutine.resume(thread))
assert(not partial.Start(),'yielded startup must reserve before registration')
assert(not partial.Frame())
local ok,accepted=coroutine.resume(thread)
assert(ok and not accepted and partial.Status().phase=='failed' and blocked)
print('client bootstrap PASS (disabled no construction/registration, CFX hooks, yielded startup reservation, partial failure and disable latch)')
local priorFactory=WeaponCharacterAmmoClientRuntime.New
WeaponCharacterAmmoClientRuntime.New=function(...)
    coroutine.yield('factory_wait')
    return priorFactory(...)
end
local hooks=0
local delayed=assert(WeaponCharacterAmmoClientBootstrap.New({block=function(value) blocked=value end},
    {ingress=function() hooks=hooks+1; return true end,
        checkpoint=function() hooks=hooks+1; return true end,
        frame=function() hooks=hooks+1; return true end}))
local result,reason
thread=coroutine.create(function() result,reason=delayed.Start() end)
assert(coroutine.resume(thread))
Config.CharacterAmmoTransportEnabled=false
assert(coroutine.resume(thread))
assert(not result and reason=='bootstrap_disabled' and hooks==0 and blocked,
    'feature shutdown across factory wait must not install any hooks')
Config.CharacterAmmoTransportEnabled=true
assert(not delayed.Start(),'cancelled startup cannot silently retry')
WeaponCharacterAmmoClientRuntime.New=priorFactory
print('bootstrap yielded factory shutdown barrier PASS')
