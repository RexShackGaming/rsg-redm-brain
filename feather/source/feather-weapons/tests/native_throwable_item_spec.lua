Config={AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/definitions/ammunition.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local catalog=WeaponDefinitionCatalog
local candidate=assert(WeaponNativeThrowablePolicy.Preview(catalog,assert(WeaponCharacterAmmoPolicy.Build(catalog))))
local metadata=assert(WeaponNativeThrowableItem.Build(catalog,{serialNumber='TOMAHAWK-1'}))
assert(metadata.ammo.ownership=='character' and metadata.ammo.type=='ammo_tomahawk_regular' and metadata.maintenance==nil)
for _,field in ipairs({'loadedAmmo','reserveAmmo','quantity','chambered','maintenance','nativeGrantAmount','nativeWeaponName'}) do
 local bad=copy(metadata); bad[field]=0
 assert(not WeaponNativeThrowableItem.Validate(bad,catalog))
 local options={serialNumber='T'}; options[field]=0
 assert(not WeaponNativeThrowableItem.Build(catalog,options))
end
for _,field in ipairs({'loaded','reserve','quantity','pools'}) do
 local bad=copy(metadata); bad.ammo[field]=0; assert(not WeaponNativeThrowableItem.Validate(bad,catalog))
end
for _,value in ipairs({-1,101,0/0,math.huge,'100',false}) do
 local bad=copy(metadata); bad.quality=value; assert(not WeaponNativeThrowableItem.Validate(bad,catalog))
end
local bad=copy(metadata); bad.provenance.self=bad; assert(not WeaponNativeThrowableItem.Validate(bad,catalog))
bad=copy(metadata); bad.weaponDefinitionId='throwable_tomahawk_ancient'; assert(not WeaponNativeThrowableItem.Validate(bad,catalog))
local row={id=170,revision=0,itemName='weapon_thrown_tomahawk',metadata=metadata}
local pools={}; for key in pairs(candidate.registry.limits) do pools[key]=0 end
local snapshot={characterId='john',revision=3,pools=pools,expected={weapon_throwable={itemId=170,revision=0}},equipment={throwable=row}}
local identity={characterId='john',sessionId='s',epoch='e'}
local empty=assert(WeaponNativeThrowableItem.Assigned(snapshot,catalog,identity,candidate.registry.limits))
assert(empty.fundedQuantity==0 and not empty.nativeRequired and empty.ledgerRevision==3)
pools.ammo_tomahawk_regular=1
local funded=assert(WeaponNativeThrowableItem.Assigned(snapshot,catalog,identity,candidate.registry.limits))
assert(funded.fundedQuantity==1 and funded.nativeRequired and funded.pickupCredits==false)
funded.row.metadata.serialNumber='mutated'; funded.identity.epoch='mutated'
assert(metadata.serialNumber=='TOMAHAWK-1' and identity.epoch=='e')
for _,mutate in ipairs({function(s) s.expected.weapon_throwable.revision=1 end,
 function(s) s.characterId='jane' end,function(s) s.pools.ammo_tomahawk_regular=2 end,
 function(s) s.equipment.throwable.metadata.ammo.ownership='item' end,
 function(s) s.equipment.throwable.metadata.condition=0 end,
 function(s) s.equipment.throwable.metadata.flags.evidence=true end,
 function(s) s.expected.weapon_melee={itemId=170,revision=0} end,
 function(s) s.equipment.throwable.itemName='weapon_melee_hatchet' end}) do
 local changed=copy(snapshot); mutate(changed)
 assert(not WeaponNativeThrowableItem.Assigned(changed,catalog,identity,candidate.registry.limits))
end
local none=copy(snapshot); none.equipment.throwable=nil; none.expected.weapon_throwable=nil
assert(WeaponNativeThrowableItem.Assigned(none,catalog,identity,candidate.registry.limits)==false)
local f=assert(io.open('fxmanifest.lua')); local manifest=f:read('*a'); f:close()
assert(manifest:find('shared/native_throwable_item.lua',1,true))
print('inert native throwable carrier PASS: character-owned type only/no quantities, exact assignment/revision/identity and independent ledger funding, no grant or write')
