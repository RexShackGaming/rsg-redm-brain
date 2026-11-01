# vorp_stores

Version 2.4. A store script for vorp core framework

VORP Stores in LUA (It is not a conversion from C#. Made completely from scratch) - `ensure vorp_menu` on the top of `server.cfg` / `resources.cfg` - `ensure vorp_stores` in your `server.cfg` / `resources.cfg`

Source: https://github.com/VORPCORE/vorp_stores

## Net events registered

**client:** `vorp_stores:RefreshStorePrices`, `vorp_stores:Server:ChangeStoreStatus`

## Event handlers

**client:** `vorp_stores:Client:OpenShop`

## Callbacks (VORP Core.Callback.Register)

**server:** `vorp_stores:callback:CloseStore`, `vorp_stores:callback:ShopStock`, `vorp_stores:callback:canOpenStore`, `vorp_stores:callback:getShopStock`
