Config={AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/definitions/ammunition.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','shared/character_ammunition_loadout_lease.lua'}) do dofile(p) end
local registry=assert(WeaponNativeThrowablePolicy.Preview(WeaponDefinitionCatalog,assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)))).registry
local identity={characterId='john',sessionId='s',epoch='e'}
local plan={identity=identity,items={}}
WeaponCharacterAmmoMaterialization={Build=function() return plan end}
local pools={}; for id in pairs(registry.limits) do pools[id]=0 end; pools.ammo_tomahawk_regular=1
local row={id=170,revision=0,itemName='weapon_thrown_tomahawk',metadata=assert(WeaponNativeThrowableItem.Build(WeaponDefinitionCatalog,{serialNumber='T'}))}
local child={characterId='john',revision=3,pools=pools,expected={weapon_throwable={itemId=170,revision=0}},equipment={throwable=row}}
local lease=WeaponCharacterAmmoLoadoutLease.New(plan,nil,nil,child,registry.limits)
assert(lease.Contains(170) and not lease.Contains(171))
local snapshot={characterId='john',equipment={},throwableEquipment=child}
assert(lease.Validate(snapshot,WeaponDefinitionCatalog,registry))
-- Normal observation persists quantity/revision without replacing the item hold.
child.pools.ammo_tomahawk_regular=0; child.revision=4
assert(lease.Validate(snapshot,WeaponDefinitionCatalog,registry) and lease.Contains(170))
row.metadata.quality=99
assert(not lease.Validate(snapshot,WeaponDefinitionCatalog,registry),'unchanged revision cannot hide a metadata change')
row.metadata.quality=100; row.revision=1
assert(not lease.Validate(snapshot,WeaponDefinitionCatalog,registry))
row.revision=0; snapshot.throwableEquipment=nil
assert(not lease.Validate(snapshot,WeaponDefinitionCatalog,registry),'partial deployment cannot release hold')
local held=true
local guard=WeaponCharacterAmmoLoadoutLease.Guard(function(id) return held and lease.Contains(id) end)
assert(not guard({id=170})); held=false; assert(guard({id=170}))
print('same server loadout lease throwable binding PASS: exact carrier row, dynamic quantity independent, guarded until parent release, partial snapshot refusal')
