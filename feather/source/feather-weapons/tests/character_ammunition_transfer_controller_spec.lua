for _,file in ipairs({'shared/character_ammunition.lua','shared/character_ammunition_runtime.lua',
    'shared/character_ammunition_client.lua','client/character_ammunition_native.lua',
    'client/character_ammunition_controller.lua'}) do dofile(file) end
local R=WeaponCharacterAmmoRuntime.New(function() return true end)
local caps,names={regular=100},{regular='AMMO_PISTOL'}
local ped,ready,writes,blocked=10,true,0,false
local native,queue=0,{}
local api={ped=function() return ped end,ready=function() return ready end,
    block=function(value) blocked=value end,hash=function(value) return value end,
    read=function() return native end,write=function(_,_,value) writes=writes+1; native=math.max(native,value) end,
    remove=function(_,_,amount) writes=writes+1; native=native-amount end,
    send=function(kind,id,report,callback) queue[#queue+1]={kind=kind,report=report,callback=callback} end}
local T=WeaponCharacterAmmoController.New(api)
local function begin(epoch)
    R.Revoke(1); T.Close(); native=0; queue={}; ready=true; ped=10
    local value=assert(R.Open({source=1,characterId='c',sessionId='s'},
        {characterId='c',revision=0,pools={regular=8}},caps,epoch))
    assert(T.Begin(value,names,caps))
    local q=table.remove(queue,1)
    q.callback({ok=true,value=assert(R.ConfirmRestore(1,q.report))})
end
local function commit()
    local q=table.remove(queue,1); assert(q.kind=='transfer')
    local spec=q.report.transfer
    local tx=assert(R.PrepareTransfer(1,q.report,spec.ammunitionId,spec.amount,spec.operationId))
    local expected=assert(WeaponCharacterAmmunition.Transfer(R.Get(1),spec.ammunitionId,spec.amount,caps))
    local result={ok=true,value=assert(R.Complete(tx.context,{ok=true,value=expected}))}
    return q,result
end
begin('economic')
local before=writes
assert(T.Transfer('regular',2,'load') and blocked and native==8 and writes==before)
assert(not T.Transfer('regular',2,'load') and #queue==1,'pending transfer cannot be repeated')
local q,result=commit()
assert(native==8 and writes==before,'DB result alone does not mutate native before bound callback')
q.callback(result)
assert(native==10 and writes==before+1 and T.Status().phase=='restoring' and blocked)
assert(queue[1].kind=='restore' and not T.Transfer('regular',1,'too-soon'))
q.callback(result); assert(writes==before+1,'duplicate committed reply cannot write twice')
local ack=table.remove(queue,1); ack.callback({ok=true,value=assert(R.ConfirmRestore(1,ack.report))})
assert(T.Status().phase=='active')
assert(T.Transfer('regular',-3,'unload')); q,result=commit(); q.callback(result)
assert(native==7 and T.Status().phase=='restoring')
ack=table.remove(queue,1); ack.callback({ok=true,value=assert(R.ConfirmRestore(1,ack.report))})
begin('lost-world'); before=writes
assert(T.Transfer('regular',2,'load')); q,result=commit(); ready=false; q.callback(result)
assert(T.Status().phase=='frozen' and writes==before and native==8 and blocked,
    'lost world after commit cannot apply economic native baseline')
begin('lost-ped'); before=writes
assert(T.Transfer('regular',2,'load')); q,result=commit(); ped=11; q.callback(result)
assert(T.Status().phase=='suspended' and writes==before,'new ped cannot receive old economic grant')
begin('failed-save'); before=writes
assert(T.Transfer('regular',2,'load')); q=table.remove(queue,1); q.callback({ok=false})
assert(T.Status().phase=='frozen' and writes==before and blocked)
print('economic native controller barrier PASS (real pure runtime, mocked persistence/native/network)')
