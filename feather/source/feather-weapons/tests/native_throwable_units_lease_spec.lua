Config={AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/definitions/ammunition.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','shared/character_ammunition_loadout_lease.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local catalog=WeaponDefinitionCatalog
local limits=copy(assert(WeaponNativeThrowablePolicy.Preview(catalog,assert(WeaponCharacterAmmoPolicy.Build(catalog)))).registry.limits)
limits.ammo_tomahawk_regular=3
local registry=assert(WeaponNativeThrowablePolicy.RegistryFromLimits(catalog,limits))
assert(registry.throwableUnitContract==2)
local identity={characterId='john',sessionId='s',epoch='e'}
local child={contract=2,kind='physical_throwable_units',characterId='john',identity=copy(identity),revision=3,pools={},units={}}
for id in pairs(limits) do child.pools[id]=id=='ammo_tomahawk_regular' and 3 or 0 end
for id=170,172 do child.units[#child.units+1]={id=id,revision=0,itemName='weapon_thrown_tomahawk',
 metadata=assert(WeaponNativeThrowableItem.Build(catalog,{serialNumber='T-'..id}))} end
local approval=assert(WeaponNativeThrowableItem.Assigned(child,catalog,identity,limits))
assert(approval.contract==2 and approval.fundedQuantity==3 and approval.row.id==170 and #approval.units==3)
local plan={identity=identity,items={}}
WeaponCharacterAmmoMaterialization={Build=function() return plan end}
local lease=WeaponCharacterAmmoLoadoutLease.New(plan,nil,nil,child,limits)
assert(lease.Contains(170) and lease.Contains(171) and lease.Contains(172) and not lease.Contains(173))
assert(lease.Validate({characterId='john',equipment={},throwableEquipment=child},catalog,registry))
for _,mutate in ipairs({
 function(c) c.identity.epoch='foreign' end,
 function(c) c.units[2].revision=1 end,
 function(c) c.units[2].metadata.quality=99 end,
 function(c) c.units[2].metadata.serialNumber=c.units[1].metadata.serialNumber end,
 function(c) c.units[2].id=170 end,
 function(c) c.pools.ammo_tomahawk_regular=2 end,
 function(c) c.units[4]=copy(c.units[3]);c.units[4].id=174 end,
 function(c) c.equipment={throwable=c.units[1]} end,
}) do
 local changed=copy(child);mutate(changed)
 assert(not lease.Validate({characterId='john',equipment={},throwableEquipment=changed},catalog,registry),'all unit identities bind the lease')
end
local changed=copy(child);changed.pools.ammo_tomahawk_regular=2;table.remove(changed.units);changed.revision=4
assert(WeaponNativeThrowableItem.Assigned(changed,catalog,identity,limits).fundedQuantity==2)
assert(not lease.Validate({characterId='john',equipment={},throwableEquipment=changed},catalog,registry),'spend requires fresh ownership binding')
assert(lease.AdvanceThrowable(changed,catalog,registry))
assert(lease.Contains(170) and lease.Contains(171) and not lease.Contains(172))
assert(lease.Validate({characterId='john',equipment={},throwableEquipment=changed},catalog,registry))
assert(not lease.AdvanceThrowable(child,catalog,registry),'spend rebind cannot add units')
local empty=copy(child);empty.units={};empty.pools.ammo_tomahawk_regular=0
assert(WeaponNativeThrowableItem.Assigned(empty,catalog,identity,limits)==false,'empty custody has no dummy carrier')
assert(lease.AdvanceThrowable(empty,catalog,registry) and not lease.Contains(170) and not lease.Contains(171))
assert(not lease.AdvanceThrowable(empty,catalog,registry),'empty lease cannot be advanced twice')
local parent={characterId='john',expected={},equipment={},throwableEquipment=changed,throwableLimits=limits,
 candidateCustody='inventory',candidate={id=174,revision=0,itemName='weapon_thrown_tomahawk',
 metadata=assert(WeaponNativeThrowableItem.Build(catalog,{serialNumber='T-174'}))}}
local intent={action='equip',slot='weapon_throwable',itemId=174}
local prepared=assert(WeaponNativeThrowableItem.Prepare(parent,catalog,identity,intent))
assert(prepared.throwableUnits and prepared.unitStorage.action=='carry' and prepared.unitStorage.expectedRevision==4)
assert(prepared.unitStorage.items[1].id==174 and #prepared.unitStorage.items==1)
parent.candidate=copy(changed.units[2]);parent.candidateCustody='carried'
intent={action='unequip',slot='weapon_throwable',selectedItemId=171}
prepared=assert(WeaponNativeThrowableItem.Prepare(parent,catalog,identity,intent))
assert(prepared.unitStorage.action=='return' and prepared.unitStorage.items[1].id==171)
parent.candidate.metadata.quality=99
assert(not WeaponNativeThrowableItem.Prepare(parent,catalog,identity,intent),'private candidate must match the whole authoritative row')
parent.candidate=copy(changed.units[2]);parent.characterId='foreign'
assert(not WeaponNativeThrowableItem.Prepare(parent,catalog,identity,intent))
plan.items={{itemInstanceId=172}}
assert(not pcall(WeaponCharacterAmmoLoadoutLease.New,plan,nil,nil,child,limits),'secondary unit cannot alias a firearm')
print('Physical throwable lease PASS: three paid units, all IDs/revisions/content held, empty no-carrier, stale/alias/legacy-shape refusal')
