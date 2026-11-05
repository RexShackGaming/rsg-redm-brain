Config={AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/definitions/ammunition.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','shared/native_throwable_recovery.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local registry=assert(WeaponNativeThrowablePolicy.Preview(WeaponDefinitionCatalog,
 assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)))).registry
local limits=registry.limits
local before={characterId='john',sessionId='session',epoch='epoch',revision=10,phase='active',pools={}}
for id in pairs(limits) do before.pools[id]=0 end
before.pools.ammo_tomahawk_regular=1; before.pools.ammo_repeater_regular=1
local after=copy(before); after.revision=11; after.pools.ammo_tomahawk_regular=0
local snapshot={characterId='john',revision=10,pools=copy(before.pools),
 expected={weapon_throwable={itemId=165,revision=0}},equipment={throwable={id=165,revision=0,
 itemName='weapon_thrown_tomahawk',metadata=assert(WeaponNativeThrowableItem.Build(WeaponDefinitionCatalog,{serialNumber='T'}))}}}
local candidate=assert(WeaponNativeThrowableRecovery.SpendCandidate(before,after,snapshot,WeaponDefinitionCatalog,limits))
assert(candidate.units==1 and candidate.itemId==165 and candidate.itemRevision==0 and candidate.serialNumber=='T'
 and candidate.requiresProjectileBinding and candidate.requiresDurableSingleClaim and candidate.pickupCredits==false)
local again=assert(WeaponNativeThrowableRecovery.SpendCandidate(before,after,snapshot,WeaponDefinitionCatalog,limits))
assert(again.key.epoch==candidate.key.epoch and again.key.revisionAfter==candidate.key.revisionAfter,
 'repeated evidence has same spend key, not a new recoverable unit')
candidate.identity.epoch='mutated'; candidate.key.revisionAfter=99
assert(before.epoch=='epoch' and after.revision==11 and snapshot.revision==10)
for _,mutate in ipairs({function(a) a.characterId='jane' end,function(a) a.sessionId='other' end,
 function(a) a.epoch='other' end,function(a) a.revision=10 end,function(a) a.revision=12 end,
 function(a) a.pools.ammo_tomahawk_regular=1 end,function(a) a.pools.ammo_repeater_regular=2 end,
 function(a) a.pools.ammo_rifle_regular=nil end,function(a) a.phase='sealed' end}) do
 local bad=copy(after); mutate(bad)
 assert(not WeaponNativeThrowableRecovery.SpendCandidate(before,bad,snapshot,WeaponDefinitionCatalog,limits))
end
local missing=copy(snapshot); missing.expected.weapon_throwable=nil; missing.equipment.throwable=nil
assert(not WeaponNativeThrowableRecovery.SpendCandidate(before,after,missing,WeaponDefinitionCatalog,limits))
local stale=copy(snapshot); stale.revision=9
assert(not WeaponNativeThrowableRecovery.SpendCandidate(before,after,stale,WeaponDefinitionCatalog,limits))
candidate=assert(WeaponNativeThrowableRecovery.SpendCandidate(before,after,snapshot,WeaponDefinitionCatalog,limits))
local durable={phase='committed_unclaimed',receiptId='server-spend-11',candidate=copy(candidate),windowStartMs=100,windowEndMs=1100}
local observed={phase='observed_unclaimed',instanceId='server-projectile-lifetime-1',originEventId='server-throw-1',
 networkId=200,model='WEAPON_THROWN_TOMAHAWK',spawnedAtMs=500,origin={identity=copy(candidate.identity),
 itemId=165,itemRevision=0,serialNumber='T',ammunitionId='ammo_tomahawk_regular',units=1}}
local binding=assert(WeaponNativeThrowableRecovery.BindingPlan(candidate,durable,observed))
assert(binding.projectileInstanceId==observed.instanceId and binding.pickupCredits==false
 and binding.requiresAtomicSingleClaim and binding.requiresCurrentProjectile and binding.requiresPickupProximity)
for _,mutate in ipairs({function(o) o.instanceId=nil end,function(o) o.originEventId=nil end,
 function(o) o.origin=nil end,function(o) o.origin.identity.characterId='jane' end,
 function(o) o.origin.identity.epoch='new-epoch' end,function(o) o.origin.serialNumber='other' end,
 function(o) o.origin.itemId=166 end,function(o) o.origin.itemRevision=1 end,
 function(o) o.model='WEAPON_MELEE_HATCHET' end,function(o) o.spawnedAtMs=99 end,
 function(o) o.spawnedAtMs=1101 end,function(o) o.networkId=0 end,
 function(o) o.phase='claimed' end}) do
 local bad=copy(observed); mutate(bad)
 assert(not WeaponNativeThrowableRecovery.BindingPlan(candidate,durable,bad))
end
for _,mutate in ipairs({function(d) d.phase='claimed' end,function(d) d.candidate.key.revisionAfter=12 end,
 function(d) d.receiptId=nil end,function(d) d.windowEndMs=20000 end}) do
 local bad=copy(durable); mutate(bad)
 assert(not WeaponNativeThrowableRecovery.BindingPlan(candidate,bad,observed))
end
local reused=copy(observed); reused.instanceId='server-projectile-lifetime-2'
local second=assert(WeaponNativeThrowableRecovery.BindingPlan(candidate,durable,reused))
assert(second.projectileInstanceId~=binding.projectileInstanceId and second.networkId==binding.networkId,
 'network ID reuse does not identify the same projectile lifetime')
binding.identity.characterId='mutated'; assert(candidate.identity.characterId=='john')
local f=assert(io.open('fxmanifest.lua')); local manifest=f:read('*a'); f:close()
assert(manifest:find('shared/native_throwable_recovery.lua',1,true),'pure planner loaded; admission remains separately gated')
print('inert recovery spend evidence PASS: exact carrier/epoch/durable decrease, stable key, no pickup credit/native/world mutations')
