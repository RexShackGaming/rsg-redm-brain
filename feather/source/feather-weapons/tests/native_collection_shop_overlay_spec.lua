-- Historical research regression; manifest assertions use the archived snapshot.
local f=assert(io.open('tests/archive/throwable-research/fxmanifest.lua'));local manifest=f:read('*a');f:close()
local config=assert(manifest:find("'shop_config.lua'",1,true))
local overlay=assert(manifest:find("'paid_throwable_shop_test.lua'",1,true))
local catalog=assert(manifest:find("'/server/services/gun_store_catalog.lua'",1,true))
assert(config<overlay and overlay<catalog,'paid shop overlay must load after prices and before catalog startup')
WeaponStoreConfig={weapons={throwable_tomahawk=false}}
GetConvarInt=function() return 0 end;dofile('paid_throwable_shop_test.lua');assert(WeaponStoreConfig.weapons.throwable_tomahawk==false)
GetConvarInt=function() return 1 end;dofile('paid_throwable_shop_test.lua');assert(WeaponStoreConfig.weapons.throwable_tomahawk==1.50)
print('PASS native collection shop overlay: manifest order, default hidden and explicit paid one-unit price')
