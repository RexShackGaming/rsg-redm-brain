local registered={};exports=function(name,fn) registered[name]=fn end
GetInvokingResource=function() return 'feather-shops' end
DefinitionRegistry={IsReady=function() return true end};IssuanceService={PurchaseAvailable=function() return true end}
vector3=function(x,y,z) return {x=x,y=y,z=z} end
dofile('config.lua');dofile('shop_config.lua')
-- Deployment preserves older operator configs that predate this field.
Config.NativeThrowablePickupPriorPolicy=nil
GetConvar=function(name,default) return name=='feather_throwable_quantities' and '1' or default end
GetConvarInt=function(name,default) return name=='feather_throwable_quantities' and 1 or default end
dofile('shared/throwable_mode.lua')
assert(Config.NativeThrowablePickupPriorPolicy.w_melee_tomahawk01==true
 and Config.NativeThrowablePickupPriorPolicy.w_melee_tomahawk02==true)
for _,group in ipairs({'weapons','ammunition','attachments'}) do dofile('shared/definitions/'..group..'.lua') end
dofile('shared/native_melee_catalog.lua');dofile('shared/native_throwable_policy.lua')
dofile('server/services/gun_store_catalog.lua')
assert(Config.NativeThrowableQuantityContract==1 and Config.NativeThrowableUnitsEnabled==false
 and Config.NativeThrowablePickupContract==0 and Config.NativeThrowableNativeCollectionContract==0)
assert(WeaponNativeThrowablePolicy.QuantityEnabled() and not WeaponNativeThrowablePolicy.UnitsEnabled())
local result=WeaponGunStore.Build(WeaponStoreConfig,WeaponDefinitionCatalog);assert(result.ok,result.message)
local generic,physical
for _,offer in ipairs(result.value.stores[1].offers) do
 if offer.itemName=='ammo_tomahawk_regular' then generic=offer end
 if offer.itemName=='weapon_thrown_tomahawk' then physical=offer end
end
assert(generic and generic.category=='ammunition' and generic.packSize==1 and generic.unitPrice==150 and not physical)
assert(generic.maximumQuantity==10,'single-unit ammunition has a useful purchase limit')
for _,offer in ipairs(result.value.stores[1].offers) do
 if offer.itemName=='ammo_revolver_regular' then assert(offer.packSize==50 and offer.maximumQuantity==2) end
end
WeaponStoreConfig.maximumUnits=7
result=WeaponGunStore.Build(WeaponStoreConfig,WeaponDefinitionCatalog);assert(result.ok)
for _,offer in ipairs(result.value.stores[1].offers) do
 if offer.itemName=='ammo_tomahawk_regular' then assert(offer.maximumQuantity==7) end
end
for _,invalid in ipairs({0,101,1.5,'10',false}) do
 WeaponStoreConfig.maximumUnits=invalid
 assert(not WeaponGunStore.Build(WeaponStoreConfig,WeaponDefinitionCatalog).ok,'invalid unit limit refused')
end
WeaponStoreConfig.maximumUnits=nil
result=WeaponGunStore.Build(WeaponStoreConfig,WeaponDefinitionCatalog);assert(result.ok)
for _,offer in ipairs(result.value.stores[1].offers) do
 if offer.itemName=='ammo_tomahawk_regular' then assert(offer.maximumQuantity==10,'older configs retain fallback') end
end
WeaponStoreConfig.ammunition.ammo_tomahawk_regular={price=2.25,rounds=1}
result=WeaponGunStore.Build(WeaponStoreConfig,WeaponDefinitionCatalog);assert(result.ok)
for _,offer in ipairs(result.value.stores[1].offers) do
 if offer.itemName=='ammo_tomahawk_regular' then assert(offer.unitPrice==225,'operator price comes from shop_config, not a test overlay') end
end
GetConvar=function(_,default) return default end
GetConvarInt=function(_,default) return default end
dofile('shared/throwable_mode.lua')
assert(not WeaponNativeThrowablePolicy.QuantityEnabled() and not WeaponNativeThrowablePolicy.UnitsEnabled())
result=WeaponGunStore.Build(WeaponStoreConfig,WeaponDefinitionCatalog);assert(result.ok)
for _,offer in ipairs(result.value.stores[1].offers) do assert(offer.itemName~='ammo_tomahawk_regular') end
GetConvarInt=function(name,default) return name=='feather_native_paid_throwables' and 1 or default end
assert(not pcall(dofile,'shared/throwable_mode.lua'),'retired mode fails clearly instead of loading missing hosts')
local f=assert(io.open('fxmanifest.lua'));local manifest=f:read('*a');f:close()
assert(manifest:find('/client/throwable_quantity_owner.lua',1,true)<manifest:find('/client/native_throwable_adapter.lua',1,true))
print('PASS quantity shop/bootstrap: explicit opt-in, legacy hosts disabled, existing ammo name/one-unit paid offer, no serialized weapon purchase, carrier manifest order')
