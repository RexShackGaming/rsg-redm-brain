dofile('shared/character_ammunition.lua'); dofile('shared/character_ammunition_runtime.lua')
local registered,handlers={},{}
local caller,current,failObserve='feather-inventory',true,false
local observed,writes=0,0
Config={CharacterAmmunitionEnabled=false}
CoreAdapter={IsSessionCurrent=function() return current end,
    ResolveSession=function() return {ok=true,value={characterId='character',sessionId='session'}} end}
function GetInvokingResource() return caller end
function GetGameTimer() return 100 end
function AddEventHandler(name,fn) handlers[name]=fn end
local inventory={}
local proxy={['feather-inventory']=inventory}
exports=setmetatable(proxy,{__call=function(_,name,fn) registered[name]=fn end})
local function callable(fn) return setmetatable({__cfx_functionReference='mock'},{__call=fn}) end
inventory.GetCharacterAmmunitionSnapshot=callable(function(_,self,context,limits)
    return {ok=true,value={characterId=context.characterId,revision=0,pools={ammo_pistol_regular=8}}}
end)
inventory.ObserveCharacterAmmunition=callable(function(_,self,context,spec)
    assert(registered.ValidateCharacterAmmoRuntimeOperation(context,'observe',spec))
    observed=observed+1
    if failObserve then return {ok=false} end
    return {ok=true,value={characterId=context.characterId,revision=spec.expectedRevision+1,pools=spec.pools}}
end)
inventory.MutateCharacterAmmunition=callable(function(_,self,context,spec)
    assert(registered.ValidateCharacterAmmoRuntimeOperation(context,'transfer',spec))
    writes=writes+1
    return {ok=true,value={characterId=context.characterId,revision=spec.expectedRevision+1,
        pools={ammo_pistol_regular=7+spec.amount}}}
end)
dofile('server/services/character_ammunition_runtime.lua')
local S=WeaponCharacterAmmoService
assert(not S.Open(1,{ammo_pistol_regular=200}).ok,'default disabled')
Config.CharacterAmmunitionEnabled=true
local opened=assert(S.Open(1,{ammo_pistol_regular=200}).value)
local report={characterId='character',sessionId='session',epoch=opened.epoch,revision=0,pools={ammo_pistol_regular=8}}
assert(not S.Observe(1,report).ok,'restore ack required')
assert(S.ConfirmRestore(1,report).ok)
handlers['core.session.left.v1']({source=1,sessionId='old-session'})
assert(S.Observe(1,report).ok and observed==0,'idle avoids export/DB')
report.pools.ammo_pistol_regular=7
local accepted=S.Observe(1,report); assert(accepted.ok and observed==1 and accepted.value.revision==1)
report.revision=1
accepted=S.Transfer(1,report,'ammo_pistol_regular',2,'load')
assert(accepted.ok and writes==1 and accepted.value.phase=='restoring')
report.revision=2; report.pools.ammo_pistol_regular=9
assert(not S.Observe(1,report).ok,'economic grant ack barrier')
assert(S.ConfirmRestore(1,report).ok)
caller='foreign'; assert(not registered.ValidateCharacterAmmoRuntimeOperation({},'observe',{})); caller='feather-inventory'
current=false; assert(not S.Observe(1,report).ok); current=true
failObserve=true; report.pools.ammo_pistol_regular=8
assert(not S.Observe(1,report).ok); assert(not S.Observe(1,report).ok,'failure freezes')
source=1; handlers.playerDropped()
assert(not S.ConfirmRestore(1,report).ok,'drop revokes')
failObserve=false
opened=assert(S.Open(1,{ammo_pistol_regular=200}).value)
report={characterId='character',sessionId='session',epoch=opened.epoch,revision=0,pools={ammo_pistol_regular=8}}
assert(S.ConfirmRestore(1,report).ok)
local before=observed
local sealed=S.CheckpointAndSeal(1,report)
assert(sealed.ok and sealed.value.phase=='sealed' and observed==before,'idle final seal avoids DB')
S.Revoke(1)
opened=assert(S.Open(1,{ammo_pistol_regular=200}).value)
report.epoch=opened.epoch
assert(S.ConfirmRestore(1,report).ok)
report.pools.ammo_pistol_regular=7
sealed=S.CheckpointAndSeal(1,report)
assert(sealed.ok and sealed.value.phase=='sealed' and sealed.value.revision==1 and observed==before+1)
assert(not S.Observe(1,report).ok,'sealed epoch cannot accept late reports')
handlers['core.session.left.v1']({source=1,sessionId='session'})
assert(not S.ConfirmRestore(1,report).ok,'Core leave revokes matching session only')
print('character ammunition server service PASS (callable-table exports, gates, lifecycle)')
local limits={ammo_pistol_regular=200}
inventory.GetCharacterAmmunitionSnapshot=callable(function(_,self,context,exportedLimits)
    coroutine.yield('snapshot_pending')
    assert(exportedLimits.ammo_pistol_regular==200,'caller cannot change exported snapshot policy')
    exportedLimits.ammo_pistol_regular=1
    return {ok=true,value={characterId=context.characterId,revision=0,pools={ammo_pistol_regular=8}}}
end)
local outcome
local worker=coroutine.create(function() outcome=S.Open(1,limits) end)
local ok,why=coroutine.resume(worker); assert(ok and why=='snapshot_pending')
limits.ammo_pistol_regular=1
assert(coroutine.resume(worker) and outcome.ok,'exported hints cannot change retained policy either')
S.Revoke(1)
print('ammo-only open policy isolation PASS (caller mutation across yield, export mutation cannot alter retained caps)')
