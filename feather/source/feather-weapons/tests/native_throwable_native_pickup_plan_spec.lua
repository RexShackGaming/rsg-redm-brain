Config={AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/definitions/ammunition.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','shared/native_throwable_recovery.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local catalog=WeaponDefinitionCatalog
local limits=assert(WeaponNativeThrowablePolicy.Preview(catalog,assert(WeaponCharacterAmmoPolicy.Build(catalog)))).registry.limits
local before={characterId='john',sessionId='s',epoch='e',revision=10,phase='active',pools={}}
for id in pairs(limits) do before.pools[id]=0 end
before.pools.ammo_tomahawk_regular=1; before.pools.ammo_repeater_regular=1
local after=copy(before); after.revision=11; after.pools.ammo_tomahawk_regular=0
local original={characterId='john',revision=10,pools=copy(before.pools),
 expected={weapon_throwable={itemId=165,revision=0}},equipment={throwable={id=165,revision=0,
 itemName='weapon_thrown_tomahawk',metadata=assert(WeaponNativeThrowableItem.Build(catalog,{serialNumber='T'}))}}}
local credit={policy='same_session_native_spend_credit_v1',phase='committed_unclaimed',receiptId='spend11',
 before=copy(before),after=copy(after),snapshot=copy(original)}
local current=copy(after)
local snapshot=copy(original); snapshot.revision=11; snapshot.pools=copy(current.pools)
local report=copy(current); report.pools.ammo_tomahawk_regular=1
local function plan(c,b,s,r) return WeaponNativeThrowableRecovery.NativePickupPlan(c,b,s,r,catalog,limits) end
local p=assert(plan(credit,current,snapshot,report))
assert(p.kind=='native_pickup_ledger_plan' and p.units==1 and p.expectedRevision==11 and p.revision==12
 and p.pools.ammo_tomahawk_regular==1 and p.pools.ammo_repeater_regular==1
 and p.spendReceiptId=='spend11' and p.spendKey.revisionAfter==11 and p.requiresAtomicSpendClaim
 and p.requiresLedgerCAS and p.looseInventoryDelta==0 and p.nativeAmmoDelta==0
 and p.originConfirmed==false and p.pickupCredits==false)
assert(current.pools.ammo_tomahawk_regular==0 and credit.phase=='committed_unclaimed')
local again=assert(plan(credit,current,snapshot,report))
assert(again.spendReceiptId==p.spendReceiptId and again.revision==p.revision,'planning is not claim/replenishment')
p.identity.epoch='mutated'; p.pools.ammo_repeater_regular=0
assert(current.epoch=='e' and current.pools.ammo_repeater_regular==1)
for _,mutate in ipairs({function(c) c.phase='claimed' end,function(c) c.policy=nil end,
 function(c) c.receiptId=nil end,function(c) c.after.revision=12 end,
 function(c) c.before.pools.ammo_tomahawk_regular=0 end}) do
 local c=copy(credit); mutate(c); assert(not plan(c,current,snapshot,report))
end
for _,mutate in ipairs({function(r) r.epoch='new' end,function(r) r.characterId='jane' end,
 function(r) r.sessionId='new' end,function(r) r.revision=10 end,function(r) r.phase='sealed' end,
 function(r) r.pools.ammo_tomahawk_regular=0 end,function(r) r.pools.ammo_tomahawk_regular=2 end,
 function(r) r.pools.ammo_repeater_regular=0 end,function(r) r.pools.ammo_rifle_regular=nil end}) do
 local r=copy(report); mutate(r); assert(not plan(credit,current,snapshot,r))
end
for _,mutate in ipairs({function(s) s.revision=10 end,function(s) s.equipment.throwable.id=166 end,
 function(s) s.equipment.throwable.revision=1 end,function(s) s.equipment.throwable.metadata.serialNumber='other' end,
 function(s) s.pools.ammo_tomahawk_regular=1 end,function(s) s.equipment.throwable=nil end}) do
 local s=copy(snapshot); mutate(s); assert(not plan(credit,current,s,report))
end
local changed=copy(current); changed.epoch='new'
local r=copy(report); r.epoch='new'
assert(not plan(credit,changed,snapshot,r),'old-epoch credit cannot fund a fresh owner')
changed=copy(current); changed.phase='sealed'; assert(not plan(credit,changed,snapshot,report))
changed=copy(current); changed.pools.ammo_tomahawk_regular=1
assert(not plan(credit,changed,snapshot,report),'already credited ledger cannot gain again')
print('inert native pickup plan PASS: committed spend cap, exact carrier/epoch/full pools/CAS, no double balances or native writes')
