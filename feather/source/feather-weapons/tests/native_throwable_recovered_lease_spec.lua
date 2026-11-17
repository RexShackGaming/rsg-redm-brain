Config={AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/definitions/ammunition.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','shared/character_ammunition_loadout_lease.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local catalog=WeaponDefinitionCatalog
local limits=copy(assert(WeaponNativeThrowablePolicy.Preview(catalog,assert(WeaponCharacterAmmoPolicy.Build(catalog)))).registry.limits)
limits.ammo_tomahawk_regular=3
local registry=assert(WeaponNativeThrowablePolicy.RegistryFromLimits(catalog,limits))
local identity={characterId='collector',sessionId='s',epoch='e'}
local function unit(id,revision)
 return {id=id,revision=revision or 0,itemName='weapon_thrown_tomahawk',
 metadata=assert(WeaponNativeThrowableItem.Build(catalog,{serialNumber='PAID-'..id}))}
end
local function setup(count)
 local before={contract=2,kind='physical_throwable_units',characterId=identity.characterId,identity=copy(identity),
 revision=10,pools={},units={}}
 for id in pairs(limits) do before.pools[id]=id=='ammo_tomahawk_regular' and count or 0 end
 for id=1,count do before.units[id]=unit(100+id) end
 local after=copy(before);after.revision=11;after.pools.ammo_tomahawk_regular=count+1
 table.insert(after.units,1,unit(50,4))
 local result={characterId=identity.characterId,collector=copy(identity),origin={characterId='thrower',sessionId='old',epoch='old'},
 itemId=50,itemRevision=4,revision=11,pools=copy(after.pools),throwableUnitsSnapshot=copy(after),
 projectileInstanceId='boot:projectile',nativeAmmoDelta=0,looseInventoryDelta=0,replayed=false}
 local plan={identity=copy(identity),items={}}
 WeaponCharacterAmmoMaterialization={Build=function() return plan end}
 local lease=WeaponCharacterAmmoLoadoutLease.New(plan,nil,nil,before,limits)
 return before,after,result,lease,plan
end
for count=0,2 do
 local before,after,result,lease=setup(count)
 assert(not lease.Contains(50))
 assert(lease.RecoverThrowable(before,after,result,catalog,registry))
 assert(lease.Contains(50) and lease.Validate({characterId=identity.characterId,equipment={},throwableEquipment=after},catalog,registry))
 assert(not lease.RecoverThrowable(before,after,result,catalog,registry),'acknowledgement cannot adopt a unit twice')
 result.itemId=999;after.units[1].metadata.quality=1
 assert(lease.Contains(50) and not lease.Contains(999),'retained lease copies cannot be mutated through caller data')
end
for _,mutate in ipairs({
 function(b,a,r) r.collector.epoch='wrong' end,
 function(b,a,r) r.origin=nil end,
 function(b,a,r) r.itemId=999 end,
 function(b,a,r) r.itemRevision=3 end,
 function(b,a,r) r.nativeAmmoDelta=1 end,
 function(b,a,r) r.looseInventoryDelta=1 end,
 function(b,a,r) a.revision=12;r.revision=12;r.throwableUnitsSnapshot=copy(a) end,
 function(b,a,r) a.pools.ammo_revolver_regular=1;r.pools=copy(a.pools);r.throwableUnitsSnapshot=copy(a) end,
 function(b,a,r) a.units[2].revision=1;r.throwableUnitsSnapshot=copy(a) end,
 function(b,a,r) a.units[2].metadata.quality=99;r.throwableUnitsSnapshot=copy(a) end,
 function(b,a,r) a.units[1].metadata.serialNumber=a.units[2].metadata.serialNumber;r.throwableUnitsSnapshot=copy(a) end,
 function(b,a,r) a.identity.sessionId='wrong';r.throwableUnitsSnapshot=copy(a) end,
 function(b,a,r) b.units[1].metadata.quality=1 end,
 function(b,a,r) b.pools.ammo_revolver_regular=nil;a.pools.ammo_revolver_regular=1;r.pools=copy(a.pools);r.throwableUnitsSnapshot=copy(a) end,
 function(b,a,r) a.units[2]=nil;r.throwableUnitsSnapshot=copy(a) end,
}) do
 local b,a,r,lease=setup(1);mutate(b,a,r)
 assert(not lease.RecoverThrowable(b,a,r,catalog,registry) and not lease.Contains(50) and lease.Contains(101))
end
local b,a,r,lease,plan=setup(0)
plan.items={{itemInstanceId=50}}
lease=WeaponCharacterAmmoLoadoutLease.New(plan,nil,nil,b,limits)
assert(not lease.RecoverThrowable(b,a,r,catalog,registry),'recovered item cannot alias an existing firearm')
local b,a,r,lease=setup(1)
r.replayed=true
assert(lease.RecoverThrowable(b,a,r,catalog,registry),'confirmed historical response can finish its one still-pending adoption')
print('Physical pickup collector lease PASS: empty/partial custody, exact one-unit receipt, unchanged companions/pools, alias/stale/repeated acknowledgement refusal')
