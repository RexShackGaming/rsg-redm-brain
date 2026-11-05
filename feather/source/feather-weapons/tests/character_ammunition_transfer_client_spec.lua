for _,file in ipairs({'shared/character_ammunition.lua','shared/character_ammunition_runtime.lua',
    'shared/character_ammunition_client.lua'}) do dofile(file) end
local R=WeaponCharacterAmmoRuntime.New(function() return true end)
local C=WeaponCharacterAmmoClient.New()
local caps={regular=100,express=100}
local opened=assert(R.Open({source=1,characterId='c',sessionId='s'},
    {characterId='c',revision=0,pools={regular=8,express=4}},caps,'transfer'))
assert(C.Begin(opened,caps,10))
local request=assert(C.Prepare(10,opened.pools,true))
assert(C.Accept(request.id,{ok=true,value=assert(R.ConfirmRestore(1,request.report))},10))
assert(not C.PrepareTransfer(10,{regular=7,express=4},true,'regular',2,'load'),
    'uncheckpointed shot must be saved before economic transfer')
for _,id in ipairs({'',string.rep('x',65)}) do
    assert(not C.PrepareTransfer(10,opened.pools,true,'regular',2,id))
end
local function transfer(amount,operationId)
    local before=C.Status().baseline
    local req=assert(C.PrepareTransfer(10,before.pools,true,'regular',amount,operationId))
    assert(not C.Prepare(10,before.pools,true) and not C.PrepareFinal(10,before.pools,true),
        'transfer reserves all checkpoint work')
    local tx=assert(R.PrepareTransfer(1,req.report,req.ammunitionId,req.amount,req.operationId))
    assert(R.IsOperationCurrent(tx.context,'transfer',tx.spec))
    local expected=assert(WeaponCharacterAmmunition.Transfer(before,'regular',amount,caps))
    local committed=assert(R.Complete(tx.context,{ok=true,value=expected}))
    assert(committed.phase=='restoring')
    assert(C.Accept(req.id,{ok=true,value=committed},10).phase=='restoring')
    assert(not C.PrepareTransfer(10,committed.pools,true,'regular',1,'duplicate'),
        'another economic transfer requires exact native restore acknowledgment')
    assert(not C.Accept(req.id,{ok=true,value=committed},10),'duplicate reply cannot apply twice')
    local ack=assert(C.Prepare(10,committed.pools,true))
    assert(ack.kind=='restore')
    assert(C.Accept(ack.id,{ok=true,value=assert(R.ConfirmRestore(1,ack.report))},10).phase=='active')
end
transfer(2,'load'); assert(C.Status().baseline.pools.regular==10)
transfer(-3,'unload'); assert(C.Status().baseline.pools.regular==7)
assert(not C.PrepareTransfer(10,C.Status().baseline.pools,true,'regular',-8,'too-much'))
assert(not C.PrepareTransfer(10,C.Status().baseline.pools,true,'regular',100,'overflow'))
request=assert(C.PrepareTransfer(10,C.Status().baseline.pools,true,'regular',1,'bad-ack'))
local forged=C.Status().baseline; forged.revision=forged.revision+1; forged.phase='restoring'
forged.pools.regular=forged.pools.regular+2
assert(not C.Accept(request.id,{ok=true,value=forged},10) and C.Status().phase=='frozen',
    'server reply must equal the exact proposed economic delta')
print('client/server transfer barrier PASS (pure modules; no natives or SQL)')
