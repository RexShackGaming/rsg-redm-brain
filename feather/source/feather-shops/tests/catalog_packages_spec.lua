local shopRoot,weaponsRoot=arg[2],arg[4]
local function copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
local function ok(v) return {ok=true,value=v} end
local function err(c,m) return {ok=false,code=c,message=m} end
ShopService={Ok=ok,Err=err,Copy=copy,RegisterDevCommand=function() end}
exports=setmetatable({},{__call=function() end})
local now=0;GetGameTimer=function() return now end;Wait=function(ms) now=now+ms end
local events={};AddEventHandler=function(name,fn) events[#events+1]=fn end
dofile(weaponsRoot..'/shop_config.lua')
vector3=function(x,y,z) return {x=x,y=y,z=z} end
dofile(weaponsRoot..'/config.lua')
for _,name in ipairs({'weapons','ammunition','attachments'}) do dofile(weaponsRoot..'/shared/definitions/'..name..'.lua') end
dofile(weaponsRoot..'/server/services/gun_store_catalog.lua')
local generated=WeaponGunStore.Build(WeaponStoreConfig,WeaponDefinitionCatalog);assert(generated.ok,generated.message)
exports['feather-weapons']={GetGunStoreCatalog=function() return WeaponGunStore.Build(WeaponStoreConfig,WeaponDefinitionCatalog) end}
dofile(shopRoot..'/config.lua');dofile(shopRoot..'/server/catalog_sources.lua')
local imported=ShopCatalogSources.Load();assert(imported.ok,imported.message)
assert(#Config.Shops==2 and #Config.Shops[2].offers==106,tostring(#Config.Shops[2].offers))
assert(ShopCatalogSources.Owns('feather-weapons') and ShopCatalogSources.IsCurrent())
events[1]('feather-weapons');assert(not ShopCatalogSources.IsCurrent())
-- Disabled provider keeps standalone ordinary Shops available.
Config.WeaponStoresEnabled=false;assert(ShopCatalogSources.Load().ok)
Config.WeaponStoresEnabled=true;exports['feather-weapons'].GetGunStoreCatalog=function() return {ok=false,code='invalid_config'} end
assert(not ShopCatalogSources.Load().ok)
-- Exercise the production additive schema upgrade; old immutable quantities and
-- original checksummed migrations must not be rewritten.
local column,alters=nil,0
local migrations={};local prior={quantity=3,unit_price=25,total_amount=75}
DB={value=function(_,id) return migrations[id] end,
    insert=function(_,id,hash) migrations[id]=hash end,
    one=function() return copy(column) end,
    exec=function(sql)
        if sql:find('ALTER TABLE',1,true) then
            assert(sql=='ALTER TABLE shop_orders ADD COLUMN pack_size INT UNSIGNED NOT NULL DEFAULT 1')
            alters=alters+1;column={kind='int',storage='int(10) unsigned',nullable='NO',initial='1'};prior.pack_size=1
        end
    end}
dofile(shopRoot..'/server/orders.lua')
assert(ShopOrders.Start().ok and alters==1 and prior.quantity==3 and prior.total_amount==75 and prior.pack_size==1)
assert(ShopOrders.Start().ok and alters==1)
column.initial='50';assert(not ShopOrders.Start().ok and alters==1)
column.initial='1';column.storage='int(10)';assert(not ShopOrders.Start().ok and alters==1)
print('PASS catalog provider import/refusal/stop fence and additive package-schema preservation/idempotence')
