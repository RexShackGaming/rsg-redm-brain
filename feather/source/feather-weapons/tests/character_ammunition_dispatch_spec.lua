dofile('shared/character_ammunition_dispatch.lua')
local enabled,held,seq=true,false,0
local timers={}; local dispatcher
local function bundle()
    seq=seq+1
    return {runtime={characterId='c',sessionId='s',epoch='e'..seq,revision=0,phase='restoring',pools={regular=8}},
        creation={identity={characterId='c',sessionId='s',epoch='e'..seq},items={}}}
end
local api={enabled=function() return enabled end,timeout=function(fn) timers[#timers+1]=fn end,
    dispatch=function(_,value) assert(held and value.runtime.phase=='restoring') end,service={}}
api.service.OpenLoadout=function() held=true; return {ok=true,value=bundle()} end
api.service.ValidateLoadout=function() return {ok=true,value=true} end
api.service.FreezeLoadout=function() assert(held); return {ok=true} end
for method,phase in pairs({ConfirmRestore='active',Observe='active',CheckpointAndSeal='sealed',ConfirmCleanup='released'}) do
    api.service[method]=function(_,report)
        local value={}; for k,v in pairs(report) do value[k]=v end; value.phase=phase
        if phase=='released' then held=false end
        return {ok=true,value=value}
    end
end
dispatcher=WeaponCharacterAmmoDispatch.New(api)
enabled=false; assert(not dispatcher.Start(1).ok and not held); enabled=true
local opened=dispatcher.Start(1); assert(opened.ok and held)
assert(not dispatcher.Start(1).ok,'hold prevents replacement')
local report=opened.value; report.revision=0; report.pools={regular=8}
local stale={characterId='c',sessionId='s',epoch='old'}
assert(not dispatcher.ConfirmRestore(1,stale).ok and dispatcher.Status(1).phase=='restoring')
assert(not dispatcher.Observe(1,report).ok,'restore ack barrier')
assert(dispatcher.ConfirmRestore(1,report).ok)
timers[1](); assert(dispatcher.Status(1).phase=='active','old timer cannot freeze active state')
assert(dispatcher.Observe(1,report).ok)
assert(dispatcher.CheckpointAndSeal(1,report).ok and held)
assert(not dispatcher.Start(1).ok,'seal does not release')
assert(dispatcher.ConfirmCleanup(1,report).ok and not held)
assert(dispatcher.ConfirmCleanup(1,report).ok,'exact duplicate release safe')
opened=dispatcher.Start(1); report=opened.value
timers[2](); assert(dispatcher.Status(1).phase=='frozen' and held)
assert(not dispatcher.ConfirmRestore(1,report).ok and not dispatcher.Start(1).ok,'timeout cannot resurrect')
assert(not dispatcher.Forget(1,'old') and dispatcher.Forget(1,'s'))
api.dispatch=function() error('send unavailable') end
assert(not dispatcher.Start(1).ok and dispatcher.Status(1).phase=='frozen' and held)
dispatcher.Forget(1); api.dispatch=function() end
opened=dispatcher.Start(1); report=opened.value
api.service.ConfirmRestore=function()
    assert(not dispatcher.ConfirmRestore(1,report).ok,'concurrent request refused')
    timers[#timers]()
    return {ok=true,value={characterId='c',sessionId='s',epoch=report.epoch,phase='active'}}
end
assert(not dispatcher.ConfirmRestore(1,report).ok and dispatcher.Status(1).phase=='frozen','late success cannot revive timeout')
local status=dispatcher.Status(1); status.phase='released'
assert(dispatcher.Status(1).phase=='frozen','defensive status copy')
print('character_ammunition_dispatch_spec PASS (hold-first dispatch, ack barriers, seal/release, timeout, stale/overlapping replies)')
dispatcher.Forget(1); timers={}
api.service.ConfirmRestore=function(_,report)
    local value={}; for k,v in pairs(report) do value[k]=v end; value.phase='active'
    return {ok=true,value=value}
end
api.service.Transfer=function(_,report)
    local value={}; for k,v in pairs(report) do value[k]=v end; value.phase='restoring'
    return {ok=true,value=value}
end
opened=dispatcher.Start(1); report=opened.value
assert(dispatcher.ConfirmRestore(1,report).ok)
report.transfer={ammunitionId='regular',amount=1,operationId='load'}
assert(dispatcher.Transfer(1,report).ok and #timers==2)
timers[1](); assert(dispatcher.Status(1).phase=='restoring','initial timer cannot freeze economic restore')
assert(dispatcher.ConfirmRestore(1,report).ok)
assert(dispatcher.Transfer(1,report).ok and #timers==3)
timers[2](); assert(dispatcher.Status(1).phase=='restoring','older transfer timer cannot freeze later restore')
timers[3](); assert(dispatcher.Status(1).phase=='frozen' and held,'current economic restore timeout keeps hold')
assert(not dispatcher.ConfirmRestore(1,report).ok,'late economic restore ack cannot revive timeout')

-- Validation can yield across a lifecycle cancellation or feature shutdown.
for _,cancel in ipairs({true,false}) do
    dispatcher.Forget(1); enabled=true
    local sends=0
    api.dispatch=function() sends=sends+1 end
    api.service.ValidateLoadout=function() coroutine.yield(); return {ok=true,value=true} end
    local result
    local thread=coroutine.create(function() result=dispatcher.Start(1) end)
    assert(coroutine.resume(thread))
    if cancel then dispatcher.Forget(1) else enabled=false end
    assert(coroutine.resume(thread))
    assert(not result.ok and sends==0,'late validation must not dispatch native creation')
    if not cancel then assert(dispatcher.Status(1).phase=='frozen' and held) end
end
enabled=true
print('character_ammunition_dispatch_spec PASS (yielded validation cancellation and disable barriers)')

dispatcher.Forget(1)
local sends=0
api.dispatch=function() sends=sends+1 end
api.service.ValidateLoadout=function() coroutine.yield(); return {ok=true,value=true} end
local started
local thread=coroutine.create(function() started=dispatcher.Start(1) end)
assert(coroutine.resume(thread))
local identity=dispatcher.Status(1).identity
assert(dispatcher.Status(1).phase=='validating')
assert(not dispatcher.ConfirmRestore(1,identity).ok,'no restore ack before creation dispatch')
assert(not dispatcher.Observe(1,identity).ok,'no observations during validation')
assert(coroutine.resume(thread) and started.ok and sends==1)
assert(dispatcher.ConfirmRestore(1,identity).ok)
api.service.Observe=function(_,value)
    coroutine.yield()
    return {ok=true,value={characterId=value.characterId,sessionId=value.sessionId,epoch=value.epoch,phase='active'}}
end
local observed
thread=coroutine.create(function() observed=dispatcher.Observe(1,identity) end)
assert(coroutine.resume(thread))
enabled=false
assert(coroutine.resume(thread) and not observed.ok)
assert(observed.error.code=='dispatch_disabled' and dispatcher.Status(1).phase=='frozen' and held,
    'shutdown across persistence wait must retain hold and refuse success ack')
enabled=true
print('dispatch validation phase and post-service shutdown PASS')

-- A trusted provider still must bind creation to the exact runtime identity.
for _,mutate in ipairs({
    function(value) value.runtime.epoch='' end,
    function(value) value.runtime.sessionId=1 end,
    function(value) value.creation.identity=nil end,
    function(value) value.creation.identity.characterId='other' end,
    function(value) value.creation.identity.sessionId='other' end,
    function(value) value.creation.identity.epoch='other' end,
}) do
    dispatcher.Forget(1); sends=0
    api.service.OpenLoadout=function()
        held=true; local value=bundle(); mutate(value); return {ok=true,value=value}
    end
    local result=dispatcher.Start(1)
    assert(not result.ok and result.error.code=='invalid_dispatch_bundle')
    assert(sends==0 and held and dispatcher.Status(1).phase=='frozen',
        'malformed identity must retain hold without native dispatch')
end
print('dispatch exact creation/runtime identity barrier PASS')
