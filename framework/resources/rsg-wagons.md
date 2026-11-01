# rsg-wagons

Version 2.0.3. rsg-wagons

A wagon ownership, customisation and storage system for **RedM** servers running the **RSG-Core** framework. Players buy wagons from NPC-staffed wagon shops, customise them with liveries, tints, extras, props and lanterns, call them out anywhere with road-aware spawning, store items and animal carcasses in them, sell them back, or scrap them at a chop shop for materials and cash. - **Wagon shops.*

Source: https://github.com/Rexshack-RedM/rsg-wagons

**Dependencies:** `ox_lib`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-wagons:getOwnerPermission`, `rsg-wagons:getWagonDataByCitizenID`, `rsg-wagons:giveOwnerPermission`, `rsg-wagons:openWagonStash`, `rsg-wagons:registerWagon`, `rsg-wagons:removeAnimalFromWagon`, `rsg-wagons:removeWagon`, `rsg-wagons:saveCustomization`, `rsg-wagons:saveWagonToDatabase`, `rsg-wagons:sellWagon`, `rsg-wagons:server:chopDeleteFallback`, `rsg-wagons:server:processChop`, `rsg-wagons:storeAnimalInWagon`, `rsg-wagons:toggleWagonActive`, `rsg-wagons:updateWagonAuth`

**client:** `btc-wagon:askOwnerPermission`, `rsg-wagons:client:callwagon`, `rsg-wagons:client:chopDeleteOwnedWagon`, `rsg-wagons:client:chopForceDelete`, `rsg-wagons:client:chopNotify`, `rsg-wagons:client:dellwagon`, `rsg-wagons:client:notify`, `rsg-wagons:client:openStore`, `rsg-wagons:client:success`, `rsg-wagons:receiveWagonData`, `rsg-wagons:saveWagonToDatabase`, `rsg-wagons:spawnAnimal`, `rsg-wagons:stashPermission`

## Callbacks (lib.callback)

**server:** `rsg-wagons:checkMyWagons`, `rsg-wagons:getAnimalStorage`, `rsg-wagons:isWagonRegistered`, `rsg-wagons:server:getChopInfo`

## Commands (RegisterCommand)

**client:** `/callwagon`, `/chopdebug`

## Database tables

`rsg_wagons`
