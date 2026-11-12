local root=arg[1]
local registered={}
exports=function(name,fn) registered[name]=fn end
local caller='feather-shops'
GetInvokingResource=function() return caller end
DefinitionRegistry={IsReady=function() return true end}
IssuanceService={PurchaseAvailable=function() return true end}
dofile(root..'/shop_config.lua')
vector3=function(x,y,z) return {x=x,y=y,z=z} end
dofile(root..'/config.lua')
for _,name in ipairs({'weapons','ammunition','attachments'}) do dofile(root..'/shared/definitions/'..name..'.lua') end
dofile(root..'/server/services/gun_store_catalog.lua')
local function copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
local baseline=copy(WeaponStoreConfig)
local function build(c) return WeaponGunStore.Build(c or copy(baseline),WeaponDefinitionCatalog) end
local result=build();assert(result.ok,result.message)
local shop=result.value.stores[1];assert(#shop.offers==106)
local ids,items={},{}
for _,offer in ipairs(shop.offers) do
    assert(not ids[offer.id] and #offer.id==36 and not items[offer.itemName])
    ids[offer.id]=true;items[offer.itemName]=offer
    assert(offer.maximumQuantity*offer.packSize<=100 and offer.unitPrice%1==0)
end
assert(items.weapon_revolver_cattleman.unitPrice==1200)
assert(items.weapon_shotgun_pump.unitPrice==1688)
assert(items.ammo_revolver_regular.packSize==50 and items.ammo_rifle_regular.packSize==20)
assert(items.ammo_repeater_regular.packSize==50 and items.ammo_shotgun_regular.packSize==25)
assert(items.ammo_varmint.packSize==50 and items.gun_oil.unitPrice==25)
local config=copy(baseline);config.ammunition.ammo_revolver_regular.price=.62
local changed=build(config);assert(changed.ok)
for _,offer in ipairs(changed.value.stores[1].offers) do
    assert(offer.id==items[offer.itemName].id,'price edits must not replace offer identities')
    if offer.itemName=='ammo_revolver_regular' then assert(offer.unitPrice==62) end
end
config.weapons.revolver_cattleman=false;assert(#build(config).value.stores[1].offers==105)
config=copy(baseline);config.ammunition.ammo_revolver_regular.price=false
assert(#build(config).value.stores[1].offers==105)
for _,bad in ipairs({0,-1,0/0,math.huge,.001,'12'}) do
    config=copy(baseline);config.gunOil=bad;assert(not build(config).ok)
end
config=copy(baseline);config.ammunition.ammo_revolver_regular.rounds=101;assert(not build(config).ok)
config=copy(baseline);config.ammunition.ammo_revolver_regular.rounds=0;assert(not build(config).ok)
config=copy(baseline);config.weapons.melee_knife=5;assert(not build(config).ok)
config=copy(baseline);config.weapons.bow=5;assert(not build(config).ok)
config=copy(baseline);config.weapons.typo=5;assert(not build(config).ok)
config=copy(baseline);config.attachments.cattleman_wide_sight=nil;assert(not build(config).ok)
config=copy(baseline);config.enabled=false;assert(#build(config).value.stores==0)
config=copy(baseline);config.stores[2]=copy(config.stores[1]);assert(not build(config).ok)
assert(registered.GetGunStoreCatalog().ok)
caller='untrusted';assert(not registered.GetGunStoreCatalog().ok)
print('PASS gun-store full catalog, stable identities, exact box prices, disabled offers and configuration refusal')
