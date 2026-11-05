dofile('shared/character_ammunition.lua')
dofile('shared/character_ammunition_runtime.lua')
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local live=true
local R=WeaponCharacterAmmoRuntime.New(function() return live end)
local limits={ammo_tomahawk_regular=1,ammo_repeater_regular=10}
local report={characterId='john',sessionId='s',epoch='e',revision=11,pools={ammo_tomahawk_regular=0,ammo_repeater_regular=3}}
local function start(epoch)
 report.epoch=epoch or 'e'
 assert(R.Open({source=2,characterId='john',sessionId='s'},report,limits,report.epoch))
 assert(R.ConfirmRestore(2,report))
end
start()
local observed=copy(report); observed.pools.ammo_tomahawk_regular=1
local plan={version=1,kind='native_pickup_ledger_plan',policy='same_session_native_spend_credit_v1',units=1,
 identity={characterId='john',sessionId='s',epoch='e'},expectedRevision=11,revision=12,
 requiresAtomicSpendClaim=true,requiresLedgerCAS=true,looseInventoryDelta=0,nativeAmmoDelta=0,
 pickupCredits=false,originConfirmed=false,pools=copy(observed.pools),spendReceiptId='spend:165:11'}
assert(not R.PrepareObservation(2,observed),'generic increase still forbidden')
for _,mutate in ipairs({function(p) p.identity.epoch='foreign' end,function(p) p.revision=13 end,
 function(p) p.units=2 end,function(p) p.nativeAmmoDelta=1 end,function(p) p.pools.ammo_repeater_regular=4 end}) do
 local p=copy(plan); mutate(p); assert(not R.PrepareNativePickup(2,observed,p))
end
local request=assert(R.PrepareNativePickup(2,observed,plan))
assert(R.IsOperationCurrent(request.context,'pickup',request.spec))
assert(not R.IsOperationCurrent(request.context,'observe',request.spec))
local altered=copy(request.spec); altered.nativePickupPlan.spendReceiptId='other'
assert(not R.IsOperationCurrent(request.context,'pickup',altered),'receipt plan is reserved exactly')
assert(not R.PrepareNativePickup(2,observed,plan),'concurrent request denied')
local ack=assert(R.Complete(request.context,{ok=true,value={characterId='john',revision=12,pools=observed.pools}}))
assert(ack.phase=='active' and ack.revision==12 and ack.pools.ammo_tomahawk_regular==1,
 'already-native pickup needs no restoring transition or setter')
assert(not R.Complete(request.context,{ok=true,value=ack}),'duplicate ack cannot credit twice')
assert(not R.PrepareNativePickup(2,observed,plan),'stale revision denied')
R.Revoke(2); start('new'); plan.identity.epoch='new'; observed.epoch='new'
request=assert(R.PrepareNativePickup(2,observed,plan))
assert(not R.Complete(request.context,{ok=false}) and R.Get(2).phase=='frozen','uncertain commit is not retried')
R.Revoke(2); start('third'); plan.identity.epoch='third'; observed.epoch='third'
request=assert(R.PrepareNativePickup(2,observed,plan)); live=false
assert(not R.IsOperationCurrent(request.context) and not R.Complete(request.context,{ok=true,value=ack}))
-- Inventory exact replay may legitimately return a historical result without
-- touching its newer ledger. That historical result cannot satisfy a new ticket.
live=true; R.Revoke(2); report.revision=13; start('fourth')
observed=copy(report); observed.pools.ammo_tomahawk_regular=1
plan.identity.epoch='fourth'; plan.expectedRevision=13; plan.revision=14
plan.pools=copy(observed.pools); plan.spendReceiptId='spend:165:13'
request=assert(R.PrepareNativePickup(2,observed,plan))
assert(not R.Complete(request.context,{ok=true,value={characterId='john',revision=12,
 pools=copy(observed.pools),replayed=true}}),'historical success cannot acknowledge a newer reservation')
local frozen=R.Get(2)
assert(frozen.phase=='frozen' and frozen.revision==13 and frozen.pools.ammo_tomahawk_regular==0,
 'stale receipt result must not advance or replenish the runtime baseline')
assert(not R.IsOperationCurrent(request.context,'pickup',request.spec))
print('native pickup server runtime PASS: exact reserved plan, same epoch/revision/full pools, one ack, no restore or generic increase')
