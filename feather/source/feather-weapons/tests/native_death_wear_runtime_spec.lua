dofile('shared/character_ammunition.lua'); dofile('shared/character_ammunition_runtime.lua')
local R=WeaponCharacterAmmoRuntime.New(function() return true end)
local baseline={characterId='c',revision=25,pools={ammo=0}}
local report={characterId='c',sessionId='s',epoch='e',revision=25,pools={ammo=0}}
assert(R.Open({source=1,characterId='c',sessionId='s'},baseline,{ammo=10},'e'))
assert(R.ConfirmRestore(1,report))
local final={characterId='c',medicalRevision=7,expected={weapon={itemId=128,revision=4}},
 lifecycleWear={{itemId=128,itemRevision=4,after={maintenance={dirt=0.5}}}}}
local request=assert(R.PrepareFinalObservation(1,report,final))
assert(not request.unchanged and R.Get(1).phase=='active','unchanged ammo must not acknowledge death before wear commit')
assert(R.IsOperationCurrent(request.context,'observe',request.spec))
final.medicalRevision=8; assert(R.IsOperationCurrent(request.context,'observe',request.spec),'defensive reservation copy')
request.spec.finalWear.lifecycleWear[1].itemId=112
assert(not R.IsOperationCurrent(request.context,'observe',request.spec),'forged wear intent refused')
request.spec.finalWear.lifecycleWear[1].itemId=128
assert(not R.PrepareFinalObservation(1,report,final),'serialize death intent')
local sealed=assert(R.Complete(request.context,{ok=true,value=baseline}))
assert(sealed.phase=='sealed' and sealed.revision==25,'no ammo revision churn')
assert(not R.IsOperationCurrent(request.context,'observe',request.spec))
assert(not R.Complete(request.context,{ok=true,value=baseline}),'ticket consumed once')
print('Death final runtime PASS (unchanged belt reserves DB barrier, exact immutable wear intent, seal only after commit, no belt churn)')
