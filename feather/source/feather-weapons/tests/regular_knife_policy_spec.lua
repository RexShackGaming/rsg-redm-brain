Config={NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaLifecycleWearEnabled=true,AmmunitionPools={enabled=false}}
local knives=false
GetConvar=function(name,default) return name=='feather_throwable_quantities' and '1' or default end
GetConvarInt=function(name,default)
 if name=='feather_throwing_knife_quantities' then return knives and 1 or 0 end
 return name=='feather_throwable_quantities' and 1 or default
end
exports=function() end
for _,p in ipairs({'shared/throwable_mode.lua','shared/constants.lua','shared/definitions/ammunition.lua',
 'shared/definitions/weapons.lua','shared/definitions/attachments.lua','shared/character_ammunition.lua',
 'shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua','shared/native_throwable_policy.lua',
 'shared/native_throwable_item.lua','shared/native_melee_catalog.lua','shop_config.lua','server/services/gun_store_catalog.lua'}) do dofile(p) end
assert(not WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog).limits.ammo_throwing_knives_regular)
knives=true;dofile('shared/throwable_mode.lua')
local r=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
assert(r.limits.ammo_throwing_knives_regular==8 and r.names.ammo_throwing_knives_regular=='AMMO_THROWING_KNIVES')
assert(r.quantityKnifeContract==1 and r.limits.ammo_tomahawk_regular==3)
assert(not r.limits.ammo_throwing_knives_poison and not r.weapons.throwable_throwing_knives,'no specialty pool or serialized carrier issuance')
local identity={characterId='jane',sessionId='s',epoch='e'}
local snapshot={contract=3,kind='throwable_quantity',characterId='jane',identity=identity,revision=1,pools={}}
for id in pairs(r.limits) do snapshot.pools[id]=0 end
snapshot.pools.ammo_throwing_knives_regular=8;snapshot.pools.ammo_tomahawk_regular=3
local q=assert(WeaponNativeThrowableItem.AssignedQuantity(snapshot,WeaponDefinitionCatalog,identity,r.limits,'throwable_throwing_knives'))
assert(q.ammunitionId=='ammo_throwing_knives_regular' and q.fundedQuantity==8)
local offers=assert(WeaponGunStore.Build(WeaponStoreConfig,WeaponDefinitionCatalog).value).stores[1].offers
local found
for _,offer in ipairs(offers) do
 if offer.itemName=='ammo_throwing_knives_regular' then found=offer end
 assert(offer.itemName~='ammo_throwing_knives_poison' and offer.itemName~='weapon_thrown_throwing_knives')
end
assert(found and found.unitPrice==100 and found.packSize==1 and found.maximumQuantity==10)
snapshot.pools.ammo_throwing_knives_regular=9
assert(not WeaponNativeThrowableItem.AssignedQuantity(snapshot,WeaponDefinitionCatalog,identity,r.limits,'throwable_throwing_knives'))
knives=false
assert(not WeaponNativeThrowablePolicy.KnivesEnabled())
print('PASS regular knife policy: default-off, eight-unit separate pool, no serialized weapon/specialty admission, existing price and strict snapshot')
