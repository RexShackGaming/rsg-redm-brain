# rsg-beekeeper

Version 3.0.1. Beekeeper script for RSG Framework

A beekeeping script for RedM, built on the RSG Framework. Players place beehives, start a colony with a queen bee, keep it fed and watered, calm it with a smoker, and harvest honey and beeswax once the colony is fully grown. - **Placeable beehives** -- 6 prop styles (`bee_house_gk_1` to `bee_house_gk_6`), each with its own inventory item. Placement uses the same gizmo as rsg-farming: a ghost prop 

Source: https://github.com/Rexshack-RedM/rsg-beekeeper

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`, `ox_target`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-beekeeper:server:addHiveResource`, `rsg-beekeeper:server:addQueenBee`, `rsg-beekeeper:server:getHiveInfo`, `rsg-beekeeper:server:harvestHoney`, `rsg-beekeeper:server:pickupBeehive`, `rsg-beekeeper:server:placeBeehive`, `rsg-beekeeper:server:requestBeehives`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-beekeeper:client:actionResult`, `rsg-beekeeper:client:beehiveActivated`, `rsg-beekeeper:client:beehiveFull`, `rsg-beekeeper:client:colonyDied`, `rsg-beekeeper:client:hiveCalmExpired`, `rsg-beekeeper:client:hiveGone`, `rsg-beekeeper:client:hiveSmoked`, `rsg-beekeeper:client:loadBeehives`, `rsg-beekeeper:client:openHiveUI`, `rsg-beekeeper:client:removeBeehive`, `rsg-beekeeper:client:spawnBeehive`, `rsg-beekeeper:client:startPlacement`, `rsg-beekeeper:client:updateHiveUI`

## Commands (RegisterCommand)

**server:** `/beehivewebhook`

## Public (table) functions

**client/placement.lua:** `Placement.Start(model, checkFn, invalidMsg)`, `Placement.Cancel()`

**server/webhook.lua:** `BeekeeperWebhook.Send(eventName, title, description, fields)`

## Database tables

`rsg_beehives`
