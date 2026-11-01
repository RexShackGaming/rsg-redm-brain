# vorp_crawfish

Version 2.0. A script to catch crawfish for vorp core framework

RedM resource allowing players to search Crawfish Holes to obtain live Crawfish and then harvest them from their inventory. - VORP Core: [vorp-core-lua](https://github.com/VORPCORE/vorp-core-lua) (lua, recommended) OR [VORP-Core](https://github.com/VORPCORE/VORP-Core) (c#) - VORP Inventory: [vorp_inventory-lua](https://github.com/VORPCORE/vorp_inventory-lua) (lua, recommended) OR [VORP-Inventory](

Source: https://github.com/VORPCORE/vorp_crawfish

## Net events registered

**client:** `vorp_crawfish:Client:tryHarvest`

## Event handlers

**server:** `onServerResourceStart`

## Callbacks (VORP Core.Callback.Register)

**server:** `vorp_crawfish:ServerCB:doHarvest`, `vorp_crawfish:ServerCB:doSearch`, `vorp_crawfish:ServerCB:tryHarvest`, `vorp_crawfish:ServerCB:trySearch`
