dofile('client/character_ammunition_lifecycle.lua')
dofile('client/character_ammunition_driver.lua')
dofile('client/character_ammunition_client_runtime.lua')
local state={phase='closed'}
local blocked,ticks,operations=false,0,0
WeaponCharacterAmmoWorldContext={Identity=function() return {characterId='c',sessionId='s'} end}
WeaponCharacterAmmoHost={New=function()
    local host={Status=function() return {phase=state.phase,session={ammo={}},reason=state.reason} end,
        Receive=function() state.phase='active'; return true end,
        Tick=function() ticks=ticks+1; return true end,
        Suspend=function(reason) state.phase='frozen'; state.reason=reason end,
        FinalizeDeath=function() return true end,RecoverDeath=function() return true end,
        ReadDeathObservation=function() return {readOnly=true} end}
    for _,name in ipairs({'Transfer','Finalize','Cleanup','Quiesce'}) do host[name]=function()
        operations=operations+1; coroutine.yield('operation_wait'); return true
    end end
    host.Checkpoint=function() operations=operations+1; coroutine.yield('checkpoint_wait'); return {ok=true} end
    return host
end}
local runtime=assert(WeaponCharacterAmmoClientRuntime.New({ped=function() return 1 end,
    now=function() return 0 end,life=function() return 'alive' end,block=function(value) blocked=value end}))
assert(runtime.Receive({runtime={characterId='c',sessionId='s'}},true))
assert(runtime.Step() and ticks==1)
local transfer=coroutine.create(function() return runtime.Transfer('ammo',1,'op') end)
local resumed,why=coroutine.resume(transfer)
assert(resumed and why=='operation_wait' and runtime.Status().runtimeBusy)
assert(not runtime.Step() and blocked and ticks==1)
assert(not runtime.Receive({runtime={characterId='c',sessionId='s'}},true))
assert(not runtime.Transfer('ammo',1,'other') and operations==1)
assert(not runtime.Checkpoint({}).ok and operations==1)
assert(coroutine.resume(transfer)); assert(not runtime.Status().runtimeBusy)
local checkpoint=coroutine.create(function() return runtime.Checkpoint({}) end)
assert(coroutine.resume(checkpoint)); assert(not runtime.Step() and ticks==1)
assert(not runtime.Transfer('ammo',1,'overlap') and operations==2)
assert(coroutine.resume(checkpoint)); assert(not runtime.Status().runtimeBusy)
assert(runtime.ReadDeathObservation().readOnly)
assert(not WeaponCharacterAmmoClientRuntime.New({}))
print('unified client runtime PASS (yielded transfer/checkpoint serialize ingress/frame/operations; factory only)')
