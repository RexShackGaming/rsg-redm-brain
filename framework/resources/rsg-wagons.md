# rsg-wagons

Version 3.0.1. rsg-wagons - wagon store with full NUI catalogue, 3D preview and wagon ownership

**Version 3.0.1** · Wagon yards for RSG Framework (RedM). Walk up to a yard keeper, open a full-screen catalogue, preview any wagon in 3D with an orbit camera (the same controls as rsg-stables), buy it, name it, take it out, use its storage and trade it back in. Dependencies: `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`. No ox_lib.

Source: https://github.com/Rexshack-RedM/rsg-wagons

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-wagons']:Name)

**server:** `GetActiveWagon(src)`, `GetPlayerWagons(citizenid)`

## Net events registered

**server:** `rsg-wagons:server:condition`, `rsg-wagons:server:openStorage`, `rsg-wagons:server:registerSpawned`, `rsg-wagons:server:restore`, `rsg-wagons:server:spawnFailed`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-wagons:client:restore`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-wagons:server:buy`, `rsg-wagons:server:callWagon`, `rsg-wagons:server:fieldRepair`, `rsg-wagons:server:fleeWagon`, `rsg-wagons:server:getOwned`, `rsg-wagons:server:rename`, `rsg-wagons:server:sell`, `rsg-wagons:server:sellCargo`, `rsg-wagons:server:setLook`, `rsg-wagons:server:store`, `rsg-wagons:server:storeNearest`, `rsg-wagons:server:stowCarcass`, `rsg-wagons:server:takeOut`, `rsg-wagons:server:yardRepair`

## Database tables

`player_wagons`
