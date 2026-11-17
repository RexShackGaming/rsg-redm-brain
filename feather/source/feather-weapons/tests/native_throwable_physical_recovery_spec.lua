Config={AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/definitions/ammunition.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','shared/native_throwable_recovery.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
local limits=copy(registry.limits);limits.ammo_tomahawk_regular=3
local before={characterId='john',sessionId='session',epoch='epoch',revision=10,phase='active',pools={}}
for id in pairs(limits) do before.pools[id]=0 end
before.pools.ammo_tomahawk_regular=3;before.pools.ammo_repeater_regular=2
local snapshot={contract=2,kind='physical_throwable_units',characterId='john',
 identity={characterId='john',sessionId='session',epoch='epoch'},revision=10,pools=copy(before.pools),units={}}
for id=1,3 do snapshot.units[id]={id=id,revision=4,itemName='weapon_thrown_tomahawk',
 metadata=assert(WeaponNativeThrowableItem.Build(WeaponDefinitionCatalog,{serialNumber='T-'..id}))} end
local function scenario(remaining)
 local after=copy(before);after.revision=11;after.pools.ammo_tomahawk_regular=remaining
 local spent={};for id=remaining+1,3 do local r=copy(snapshot.units[id]);r.revision=5;spent[#spent+1]=r end
 return after,spent
end
local function plan(after,spent,snap) return WeaponNativeThrowableRecovery.PhysicalSpendCandidates(
 before,after,snap or snapshot,spent,WeaponDefinitionCatalog,limits) end
for remaining=0,2 do
 local after,spent=scenario(remaining)
 local candidates=assert(plan(after,spent))
 assert(#candidates==3-remaining)
 for i,c in ipairs(candidates) do
  assert(c.itemId==remaining+i and c.key.itemId==c.itemId and c.itemRevision==5)
  assert(c.requiresProjectileBinding and c.requiresDurableSingleClaim and c.pickupCredits==false)
  assert(c.physicalUnitContract==2 and c.identity.characterId=='john')
 end
 candidates[1].identity.epoch='changed';assert(before.epoch=='epoch')
end
local after,spent=scenario(1)
after.pools.ammo_repeater_regular=1;assert(plan(after,spent),'other confirmed decreases may share the commit')
for _,mutate in ipairs({
 function(a) a.revision=12 end,function(a) a.characterId='jane' end,function(a) a.sessionId='new' end,
 function(a) a.epoch='new' end,function(a) a.phase='frozen' end,
 function(a) a.pools.ammo_repeater_regular=3 end,function(a) a.pools.ammo_repeater_regular=nil end,
 function(a) a.pools.ammo_tomahawk_regular=3 end}) do
 local a,s=scenario(1);mutate(a);assert(not plan(a,s),"bad after case ".._)
end
for _,mutate in ipairs({
 function(s) s[1].id=1 end,function(s) s[2]=copy(s[1]) end,function(s) s[1].revision=4 end,
 function(s) s[1].metadata.serialNumber='forged' end,function(s) s[3]=copy(s[1]) end,
 function(s) s.extra=true end,function(s) s[1]=nil end}) do
 local a,s=scenario(1);mutate(s);assert(not plan(a,s))
end
local stale=copy(snapshot);stale.revision=9;after,spent=scenario(1);assert(not plan(after,spent,stale))
local candidates=assert(plan(after,spent))
local candidate=candidates[1]
local durable={phase='committed_unclaimed',receiptId='receipt',candidate=copy(candidate),windowStartMs=100,windowEndMs=200}
local observed={phase='observed_unclaimed',instanceId='boot:1',originEventId='throw:1',networkId=10,
 model='WEAPON_THROWN_TOMAHAWK',spawnedAtMs=150,origin={identity=copy(candidate.identity),
 itemId=candidate.itemId,itemRevision=candidate.itemRevision,serialNumber=candidate.serialNumber,
 ammunitionId='ammo_tomahawk_regular',units=1}}
assert(WeaponNativeThrowableRecovery.BindingPlan(candidate,durable,observed))
assert(not WeaponNativeThrowableRecovery.BindingPlan(candidates[2],durable,observed),'one projectile cannot bind a different spent unit')
candidate.key.itemId=999;durable.candidate=copy(candidate)
assert(not WeaponNativeThrowableRecovery.BindingPlan(candidate,durable,observed),'physical binding requires item-specific spend key')
print('Physical throwable spend evidence PASS: distinct paid units, atomic decrease, revision/session/metadata fences; no pickup authority')
