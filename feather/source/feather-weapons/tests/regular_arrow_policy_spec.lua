Config={NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaLifecycleWearEnabled=true,AmmunitionPools={enabled=false}}
local enabled=false
GetConvarInt=function(name,default) return name=='feather_regular_arrows' and enabled and 1 or default end
exports=function() end
for _,path in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/weapons.lua',
 'shared/definitions/attachments.lua','shared/validation.lua','shared/character_ammunition_catalog.lua',
 'shared/character_ammunition_policy.lua','shared/character_ammunition_item.lua','shared/character_ammunition_materialization.lua','shared/native_melee_catalog.lua',
 'shop_config.lua','server/services/gun_store_catalog.lua'}) do dofile(path) end
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
assert(not registry.weapons.bow and not registry.limits.ammo_arrow_regular)
enabled=true
registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
assert(registry.names.ammo_arrow_regular=='AMMO_ARROW' and registry.limits.ammo_arrow_regular==40)
assert(registry.weapons.bow.compatible.ammo_arrow_regular and not registry.weapons.bow.compatible.ammo_arrow_poison)
for id in pairs(registry.limits) do if id:match('^ammo_arrow_') then assert(id=='ammo_arrow_regular') end end
local row={id=901,revision=0,itemName='weapon_bow',metadata={schemaVersion=2,weaponDefinitionId='bow',serialNumber='BOW-TEST',
 quality=100,condition=100,maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},
 ammo={ownership='character',type='ammo_arrow_regular'},attachments={},cosmetics={},
 flags={stolen=false,evidence=false,disabled=false},provenance={}}}
local identity={characterId='jane',sessionId='session',epoch='epoch'}
for _,slot in ipairs({'shoulder','back'}) do
 local plan=assert(WeaponCharacterAmmoMaterialization.Build({[slot]=row},WeaponDefinitionCatalog,registry,identity))
 assert(WeaponCharacterAmmoMaterialization.Validate(plan,registry,identity))
 assert(plan.items[1].nativeWeaponName=='WEAPON_BOW' and plan.items[1].creation=='native_inventory_guid')
 assert(plan.items[1].point==(slot=='shoulder' and 8 or 7),'bow uses its model-specific native carry points')
 plan.items[1].point=slot=='shoulder' and 10 or 9
 assert(not WeaponCharacterAmmoMaterialization.Validate(plan,registry,identity),'rifle carry points are not valid bow positions')
end
assert(not WeaponCharacterAmmoItem.Loadout({primary=row},WeaponDefinitionCatalog,registry))
row.metadata.ammo.type='ammo_arrow_poison';assert(not WeaponCharacterAmmoItem.Validate(row.metadata,WeaponDefinitionCatalog.weapons.bow))
row.metadata.ammo.type='ammo_arrow_regular';row.metadata.ammo.loaded=1
assert(not WeaponCharacterAmmoItem.Validate(row.metadata,WeaponDefinitionCatalog.weapons.bow))
row.metadata.ammo.loaded=nil
local catalog=assert(WeaponGunStore.Build(WeaponStoreConfig,WeaponDefinitionCatalog).value)
local bow,arrows
for _,offer in ipairs(catalog.stores[1].offers) do
 if offer.itemName=='weapon_bow' then bow=offer end
 if offer.itemName=='ammo_arrow_regular' then arrows=offer end
 if offer.itemName:match('^ammo_arrow_') then assert(offer.itemName=='ammo_arrow_regular') end
end
assert(bow and bow.unitPrice==500 and bow.maximumQuantity==1 and bow.category=='bow')
assert(arrows and arrows.packSize==5 and arrows.unitPrice==50 and arrows.maximumQuantity==2)
enabled=false
assert(not WeaponCharacterAmmoItem.Validate(row.metadata,WeaponDefinitionCatalog.weapons.bow))
print('PASS regular-arrow policy: default-off, owned bow in either longgun slot, regular-only character ammunition, shop price/pack and specialty exclusion')
