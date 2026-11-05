local state,context,ready,calls,accept
WeaponCharacterAmmoOwner={New=function() return {
    Status=function() return state end,
    Receive=function() calls=calls+1; return accept end,
    FinalizeDeath=function() state.session.ammo.deathClosing=true; return true end,
} end}
dofile('client/character_ammunition_receiver.lua')
local function setup()
    state={phase='active',session={ammo={baseline={characterId='Jane',sessionId='old',epoch='old-epoch'}}}}
    context={characterId='Jane',sessionId='old'}; ready=true; calls=0; accept=true
    return WeaponCharacterAmmoReceiver.New({identity=function() return context end,
        ready=function() return ready end,block=function() end},{})
end
local function bundle(session,epoch)
    return {runtime={characterId='Jane',sessionId=session,epoch=epoch}}
end
local receiver=setup(); receiver.Quiesce()
assert(not receiver.Receive(bundle('new','new-epoch'),true) and calls==0,'closed/server release barrier')
state.phase='closed'
assert(not receiver.Receive(bundle('old','new-epoch'),true) and calls==0,'logout cannot reopen same session')
context.sessionId='new'; ready=false
assert(not receiver.Receive(bundle('new','new-epoch'),true) and calls==0)
ready=true; assert(not receiver.Receive(bundle('new','new-epoch'),false) and calls==0)
assert(not receiver.Receive(bundle('old','new-epoch'),true) and calls==0,'current identity independent of bundle')
assert(not receiver.Receive(bundle('new','old-epoch'),true) and calls==0)
accept=false; assert(not receiver.Receive(bundle('new','new-epoch'),true) and receiver.Status().quiescing)
accept=true; assert(receiver.Receive(bundle('new','new-epoch'),true) and not receiver.Status().quiescing)
receiver=setup(); assert(receiver.FinalizeDeath()); state.phase='closed'
assert(receiver.Receive(bundle('old','next-death-epoch'),true) and not receiver.Status().quiescing)
receiver=setup()
local old={characterId='Jane',sessionId='old',epoch='old-epoch'}
assert(not receiver.PrepareEquipmentRelease({characterId='Jane',sessionId='old',epoch='foreign'},'ticket'))
assert(receiver.PrepareEquipmentRelease(old,'ticket'))
state.phase='closed'
local next=bundle('old','equipment-epoch')
assert(not receiver.Receive(next,true) and calls==0,'same-session equipment resume requires bound release ticket')
next.equipmentTransition={ticket='wrong',oldEpoch='old-epoch'}
assert(not receiver.Receive(next,true) and calls==0)
next.equipmentTransition.ticket='ticket'; next.equipmentTransition.oldEpoch='wrong'
assert(not receiver.Receive(next,true) and calls==0)
next.equipmentTransition.oldEpoch='old-epoch'
assert(not receiver.Receive(next,false) and calls==0)
assert(receiver.Receive(next,true) and not receiver.Status().quiescing)
print('equipment receiver rearm PASS (closed barrier, server origin, old epoch and exact release ticket)')
print('character_ammunition_receiver_rearm_spec PASS (released/new-session logout resume, death fresh epoch, independent context/origin/failure barriers)')
