local called,blocked=0,false
WeaponCharacterAmmoOwner={New=function() return {
    Receive=function() called=called+1; coroutine.yield(); return true end,
    Tick=function() return true end,Finalize=function() return true end,Cleanup=function() return true end,
    Status=function() return {phase='closed'} end}
end}
dofile('client/character_ammunition_receiver.lua')
local receiver=WeaponCharacterAmmoReceiver.New({block=function(on) blocked=on end},{})
assert(not receiver.Receive({},false) and called==0)
local thread=coroutine.create(function() assert(receiver.Receive({},true)) end)
assert(coroutine.resume(thread)); assert(called==1 and receiver.Status().receiving)
local ok,reason=receiver.Receive({},true); assert(not ok and reason=='receiver_busy')
assert(not receiver.Tick() and not receiver.Finalize() and not receiver.Cleanup())
assert(coroutine.resume(thread)); assert(not receiver.Status().receiving and receiver.Tick())
receiver.Quiesce()
assert(not receiver.Receive({},true) and receiver.Status().quiescing,'retiring receiver cannot accept next epoch')
WeaponCharacterAmmoOwner.New=function() return {Receive=function() error('injected') end,
    Status=function() return {phase='closed'} end} end
receiver=WeaponCharacterAmmoReceiver.New({block=function(on) blocked=on end},{})
assert(not receiver.Receive({},true) and blocked and receiver.Status().phase=='frozen')
assert(not receiver.Receive({},true) and not receiver.Tick())
print('character_ammunition_receiver_spec PASS (server ingress, pre-yield reservation, fault freeze)')
