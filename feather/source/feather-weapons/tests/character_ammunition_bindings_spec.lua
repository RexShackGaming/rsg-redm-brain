dofile('shared/character_ammunition_transport.lua')
dofile('client/character_ammunition_checkpoint.lua')
Config={CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
local events,handlers={},{}
RegisterNetEvent=function(name,fn) events[name]=fn end
AddEventHandler=function(name,fn) handlers[name]=fn end
GetCurrentResourceName=function() return 'feather-weapons' end
SetTimeout=function() end
local registered,threads,blocks,steps,enforced=0,{},0,0,0
local callbacks={}
exports=setmetatable({['feather-character']={RegisterLogoutCheckpoint=function(_,name,exportName)
    assert(name=='feather-weapons:character-ammunition')
    assert(exportName=='CheckpointCharacterAmmunitionBeforeLogout')
    registered=registered+1; return {ok=true}
end}}, {__call=function(_,name,fn) callbacks[name]=fn end})
local caller='feather-character'
GetInvokingResource=function() return caller end
CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
Wait=function() coroutine.yield() end
PlayerId=function() return 1 end
DisablePlayerFiring=function(id,value) assert(id==1 and value); blocks=blocks+1 end
PlayerPedId=function() return 42 end
joaat=function(value) return value end
GetPedAmmoByType=function() return 8 end
SetPedAmmoByType=function() error('no automatic writes') end
GetGameTimer=function() return 0 end
local dead=false
IsEntityDead=function(ped) assert(ped==42); return dead end
local removed
Citizen={InvokeNative=function(...) removed={...} end}
dofile('client/character_ammunition_client_runtime.lua')
dofile('client/character_ammunition_routes.lua')
assert(not WeaponCharacterAmmoClientBindings.NativeAdapters(nil,function() end))
local api,enforce=WeaponCharacterAmmoClientBindings.NativeAdapters(function() end,function() end)
assert(not removed and blocks==0,'factory must perform no native writes')
assert(api.life()=='alive'); dead=1; assert(api.life()=='dead'); dead=false
enforce(); assert(blocks==1,'new adapter starts firing blocked')
api.block(false); enforce(); assert(blocks==1)
api.block(nil); enforce(); assert(blocks==2,'only explicit false releases input block')
api.remove(42,123,2)
assert(removed[1]==0xB6CFEC32E3742779 and removed[2]==42 and removed[3]==123 and removed[4]==2 and removed[5]==0xA07362E6)
blocks=0
local bindings=assert(WeaponCharacterAmmoClientBindings.New(function() enforced=enforced+1 end))
local handler=function() return {ok=true} end
assert(not bindings.checkpoint(handler) and not bindings.frame(handler))
assert(registered==0 and #threads==0)
Config.CharacterAmmunitionEnabled=true; Config.CharacterAmmoTransportEnabled=true
assert(bindings.checkpoint(handler)); assert(not bindings.checkpoint(handler))
caller='untrusted'; assert(callbacks.CheckpointCharacterAmmunitionBeforeLogout({}).error.code=='checkpoint_caller_denied')
caller='feather-character'; assert(callbacks.CheckpointCharacterAmmunitionBeforeLogout({}).ok)
assert(bindings.frame(function() steps=steps+1; if steps==2 then error('fault') end end))
assert(not bindings.frame(handler))
assert(coroutine.resume(threads[1])); assert(steps==1 and enforced==1 and blocks==0)
assert(coroutine.resume(threads[1])); assert(steps==2 and blocks==1)
assert(coroutine.resume(threads[1])); assert(steps==2 and blocks==2,'frame fault must remain latched')
local cleanSteps=0
local second=assert(WeaponCharacterAmmoClientBindings.New(function() end))
assert(second.frame(function() cleanSteps=cleanSteps+1 end))
assert(coroutine.resume(threads[2])); assert(cleanSteps==1)
Config.CharacterAmmoTransportEnabled=false
assert(callbacks.CheckpointCharacterAmmunitionBeforeLogout({}).error.code=='character_ammunition_disabled')
assert(coroutine.resume(threads[2])); assert(cleanSteps==1)
Config.CharacterAmmoTransportEnabled=true
assert(coroutine.resume(threads[2])); assert(cleanSteps==1,'disablement cannot silently resume frame ownership')
-- Use the actual bootstrap with the actual registration adapters, replacing
-- only runtime/native/network boundaries. Disabled assembly cannot activate.
dofile('client/character_ammunition_client_runtime.lua')
local constructed=0
WeaponCharacterAmmoClientRuntime.New=function(adapters)
    constructed=constructed+1
    return {Receive=function() return true end,Suspend=function() end,
        Checkpoint=function() return {ok=true} end,
        Step=function() adapters.block(false); return true end,
        Status=function() return {} end}
end
Config.CharacterAmmoTransportEnabled=false
local bootstrap=assert(WeaponCharacterAmmoClientBindings.Bootstrap(function() end,function() end))
assert(constructed==0)
assert(not bootstrap.Start() and constructed==0)
Config.CharacterAmmoTransportEnabled=true
assert(bootstrap.Start() and constructed==1 and bootstrap.Status().phase=='started')
assert(not bootstrap.Start() and constructed==1)
assert(coroutine.resume(threads[3]))
Config.CharacterAmmoTransportEnabled=false
assert(coroutine.resume(threads[3]))
Config.CharacterAmmoTransportEnabled=true
assert(coroutine.resume(threads[3]))
-- A rejected Character registration prevents scheduling and cannot retry a
-- partially registered startup. The bootstrap keeps its input block retained.
local priorThreads=#threads
exports['feather-character'].RegisterLogoutCheckpoint=function() return {ok=false} end
dofile('client/character_ammunition_routes.lua') -- isolated resource reload
local failed=assert(WeaponCharacterAmmoClientBindings.Bootstrap(function() end,function() end))
assert(not failed.Start() and failed.Status().phase=='failed')
assert(#threads==priorThreads and not failed.Start())
assert(failed.Frame()==nil)
local suspended=0
-- Isolated resource load: shutdown blocks the owner even when suspension
-- itself throws, and still permanently closes the transport and ingress.
dofile('client/character_ammunition_routes.lua')
local received=0
assert(WeaponCharacterAmmoClientIngress.Install({
    Receive=function() received=received+1; return true end,
    Suspend=function(reason)
        assert(reason=='resource_stopping'); suspended=suspended+1; error('injected stop fault')
    end,
}))
source=65535
events['feather-weapons:client:character-ammo-loadout']({})
assert(received==1)
handlers.onResourceStop('other'); assert(suspended==0)
handlers.onResourceStop('feather-weapons'); assert(suspended==1)
handlers.onResourceStop('feather-weapons'); assert(suspended==1,'shutdown is idempotent')
events['feather-weapons:client:character-ammo-loadout']({})
assert(received==1,'shutdown must stop late ingress')
assert(not WeaponCharacterAmmoClientIngress.Install({}))
local stoppedReply
WeaponCharacterAmmoClientTransport.Send('observe',1,{},function(result) stoppedReply=result.error.code end)
assert(stoppedReply=='transport_closed','suspension fault must not leave transport open')
print('concrete client bindings PASS (gated, caller-bound, one-shot hooks, latched frame failure)')
