dofile('shared/character_ammunition_transport.lua')
local enabled=false
local serverHandler,clientHandler
local timeouts,sends,replies,methods={},{},{},{}
local service={}
for kind,method in pairs({restore='ConfirmRestore',observe='Observe',seal='CheckpointAndSeal',cleanup='ConfirmCleanup'}) do
    service[method]=function(source,report)
        methods[#methods+1]=method
        assert(source==42 and report.characterId=='character')
        return {ok=true,value={epoch=report.epoch,revision=report.revision,phase=kind=='seal' and 'sealed' or 'active'}}
    end
end
WeaponCharacterAmmoTransport.Server({enabled=function() return enabled end,service=service,
    register=function(fn) serverHandler=fn end,
    reply=function(source,id,epoch,result) replies[#replies+1]={source,id,epoch,result} end})
local T=WeaponCharacterAmmoTransport.Client({register=function(fn) clientHandler=fn end,
    send=function(...) sends[#sends+1]={...} end,
    timeout=function(fn) timeouts[#timeouts+1]=fn end})
local report={characterId='character',sessionId='session',epoch='epoch',revision=0,pools={ammo_pistol_regular=8}}
serverHandler(42,'observe',1,report); assert(#replies==0 and #methods==0,'disabled route inert')
enabled=true
for _,kind in ipairs({'open','transfer','restore_native','unknown'}) do serverHandler(42,kind,1,report) end
assert(#methods==0,'no grant/open/economics endpoint')
serverHandler(42,'observe',0,report); serverHandler(42,'observe',1,{})
assert(#methods==0)
local callbacks=0
T.Send('restore',1,report,function(result) callbacks=callbacks+1; assert(result.ok) end)
serverHandler(42,table.unpack(sends[1]))
assert(replies[1][1]==42 and methods[1]=='ConfirmRestore')
clientHandler(1,'old-epoch',{ok=false}); assert(callbacks==0)
clientHandler(table.unpack(replies[1],2)); assert(callbacks==1)
clientHandler(table.unpack(replies[1],2)); timeouts[1](); assert(callbacks==1,'duplicate reply/late timeout ignored')
T.Send('observe',2,report,function(result) callbacks=callbacks+1; assert(result.error.code=='runtime_request_timeout') end)
timeouts[2](); assert(callbacks==2)
clientHandler(2,'epoch',{ok=true}); assert(callbacks==2,'late success does not revive timed-out request')
T.Send('seal',3,report,function() error('closed reply called') end); T.Close()
clientHandler(3,'epoch',{ok=true}); timeouts[3]()
serverHandler(42,'seal',3,report); assert(methods[#methods]=='CheckpointAndSeal')
service.Observe=function() error('injected failure') end
serverHandler(42,'observe',4,report); assert(replies[#replies][4].error.code=='runtime_request_failed')
local huge={characterId='character',sessionId='session',epoch='epoch',revision=0,pools={}}
for i=1,65 do huge.pools['a'..i]=0 end
local before=#replies; serverHandler(42,'observe',5,huge); assert(#replies==before)
serverHandler(42,'cleanup',6,report); assert(#replies==before,'cleanup needs explicit completion declaration')
report.cleanupComplete=true; report.remainingCopies=0
serverHandler(42,'cleanup',6,report); assert(methods[#methods]=='ConfirmCleanup')
local sentBefore,timeoutBefore=#sends,#timeouts
local closedReplies=0
T.Send('cleanup',7,report,function(result)
    closedReplies=closedReplies+1; assert(result.error.code=='transport_closed')
end)
assert(closedReplies==1 and #sends==sentBefore and #timeouts==timeoutBefore,
    'closed transport must refuse new mutations without sending or scheduling')
T.Close(); clientHandler(7,'epoch',{ok=true})
assert(closedReplies==1,'duplicate close and late replies cannot revive closed transport')
local rejected=WeaponCharacterAmmoTransport.Client({register=function() end,send=function() error('unavailable') end,timeout=function() error('should not schedule') end})
local failure
rejected.Send('observe',1,report,function(result) failure=result.error.code end)
assert(failure=='transport_unavailable')
print('character_ammunition_transport_spec PASS (bounded routes, source, epochs, timeout, no grants)')
local transfers=0
service.Transfer=function(_,value)
    assert(value.transfer.ammunitionId=='ammo_pistol_regular' and value.transfer.amount==2)
    transfers=transfers+1; return {ok=true,value={}}
end
report.transfer={ammunitionId='ammo_pistol_regular',amount=2,operationId='load'}
serverHandler(42,'transfer',8,report); assert(transfers==1)
for _,bad in ipairs({0,1.5,1001,math.huge,0/0}) do
    report.transfer.amount=bad; serverHandler(42,'transfer',9,report)
end
assert(transfers==1,'malformed economic deltas never reach authority')
local pickups=0
service.NativePickup=function(source,value)
    assert(source==42 and value.characterId=='character')
    pickups=pickups+1; return {ok=true,value={}}
end
local pickup={characterId='character',sessionId='session',epoch='epoch',revision=0,pools={ammo_tomahawk_regular=1}}
serverHandler(42,'pickup',10,pickup); assert(pickups==1)
pickup.nativePickupPlan={spendReceiptId='client-selected'}
serverHandler(42,'pickup',11,pickup); assert(pickups==1,'client cannot submit a server pickup plan')
pickup.nativePickupPlan=nil; pickup.transfer={amount=1}
serverHandler(42,'pickup',12,pickup); assert(pickups==1,'pickup cannot smuggle a funding operation')
