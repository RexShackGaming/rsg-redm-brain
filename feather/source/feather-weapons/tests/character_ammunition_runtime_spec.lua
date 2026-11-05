dofile('shared/character_ammunition.lua')
dofile('shared/character_ammunition_runtime.lua')
local currentSession='s1'
local R=WeaponCharacterAmmoRuntime.New(function(source,session,char)
    return source==1 and session==currentSession and char=='character'
end)
local limits={ammo_pistol_regular=200,ammo_pistol_express=200}
local baseline={characterId='character',revision=4,pools={ammo_pistol_regular=8,ammo_pistol_express=4}}
local context={source=1,characterId='character',sessionId='s1'}
local function report(regular,express,revision,epoch)
    return {characterId='character',sessionId=currentSession,epoch=epoch or 'epoch1',revision=revision or 4,
        pools={ammo_pistol_regular=regular,ammo_pistol_express=express}}
end
local opened=assert(R.Open(context,baseline,limits,'epoch1')); opened.pools.ammo_pistol_regular=99
assert(R.Get(1).pools.ammo_pistol_regular==8,'defensive snapshot')
assert(not R.PrepareObservation(1,report(0,0)),'no reset accepted before restore ack')
assert(not R.ConfirmRestore(1,report(0,0)),'restore must equal durable baseline')
assert(R.ConfirmRestore(1,report(8,4)))
assert(not R.Open(context,baseline,limits,'epoch2'),'active reset denied')
assert(R.PrepareObservation(1,report(8,4)).unchanged,'idle needs no DB call')
assert(not R.PrepareObservation(1,report(9,4)),'growth denied')
assert(not R.PrepareObservation(1,report(7,nil)),'incomplete report denied')
assert(not R.PrepareObservation(1,report(7,4,3)),'stale revision denied')
assert(not R.PrepareObservation(1,report(7,4,4,'foreign')),'stale epoch denied')
local request=assert(R.PrepareObservation(1,report(7,4)))
assert(R.IsOperationCurrent(request.context))
assert(not R.PrepareObservation(1,report(6,4)),'serialize observations')
assert(not R.Seal(1,'s1','epoch1'),'cannot reset during commit')
assert(not R.IsOperationCurrent({actorSource=1,characterId='character',sessionId='s1',runtimeEpoch='epoch1',runtimeTicket='foreign'}))
local saved={ok=true,value={characterId='character',revision=5,pools=request.spec.pools}}
assert(R.Complete(request.context,saved)); assert(not R.IsOperationCurrent(request.context),'ticket consumed')
assert(not R.Complete(request.context,saved),'duplicate completion denied')
assert(R.Seal(1,'s1','epoch1')); assert(not R.PrepareObservation(1,report(0,0,5)))
baseline.revision=5; baseline.pools.ammo_pistol_regular=7
assert(not R.Open(context,baseline,limits,'epoch1'),'epoch cannot be replayed')
assert(R.Open(context,baseline,limits,'epoch2'))
assert(R.ConfirmRestore(1,report(7,4,5,'epoch2')))
request=assert(R.PrepareObservation(1,report(6,4,5,'epoch2')))
R.Revoke(1); assert(not R.IsOperationCurrent(request.context)); assert(not R.Complete(request.context,saved))
currentSession='s2'; context.sessionId='s2'
assert(R.Open(context,baseline,limits,'epoch3')); assert(R.ConfirmRestore(1,report(7,4,5,'epoch3')))
request=assert(R.PrepareObservation(1,report(6,4,5,'epoch3')))
assert(not R.Complete(request.context,{ok=false})); assert(R.Get(1).phase=='frozen')
assert(not R.PrepareObservation(1,report(0,0,5,'epoch3')),'failed persistence freezes runtime')
R.Revoke(1)
assert(R.Open(context,baseline,limits,'epoch4')); assert(R.ConfirmRestore(1,report(7,4,5,'epoch4')))
assert(not R.PrepareTransfer(1,report(6,4,5,'epoch4'),'ammo_pistol_regular',1,'load'),'checkpoint before economy')
request=assert(R.PrepareTransfer(1,report(7,4,5,'epoch4'),'ammo_pistol_regular',2,'load'))
assert(R.IsOperationCurrent(request.context,'transfer',request.spec))
assert(not R.IsOperationCurrent(request.context,'observe',request.spec),'operation route bound')
request.spec.amount=3; assert(not R.IsOperationCurrent(request.context,'transfer',request.spec)); request.spec.amount=2
request.spec.limits.ammo_pistol_regular=201; assert(not R.IsOperationCurrent(request.context,'transfer',request.spec))
request.spec.limits.ammo_pistol_regular=200
assert(R.Complete(request.context,{ok=true,value={characterId='character',revision=6,
    pools={ammo_pistol_regular=9,ammo_pistol_express=4}}}))
assert(R.Get(1).pools.ammo_pistol_regular==9)
print('character ammunition runtime authorization PASS')
