# rsg-lumberjack

Version 3.1.0. Lumberjack gameplay: grow, chop, carry, and sell wagon loads of logs

Lumberjack gameplay for RSG-Core (RedM): grow trees, chop them, carry logs, process them into wood, and sell full wagon loads of logs for cash. - `rsg-core`

Source: https://github.com/Rexshack-RedM/rsg-lumberjack

**Dependencies:** `rsg-core`, `ox_lib`, `ox_target`, `rsg-inventory`, `oxmysql`

## Net events registered

**server:** `rsg-lumberjack:server:addLogToWagon`, `rsg-lumberjack:server:cancelChop`, `rsg-lumberjack:server:completeChop`, `rsg-lumberjack:server:dropLog`, `rsg-lumberjack:server:pickupLog`, `rsg-lumberjack:server:pickupWood`, `rsg-lumberjack:server:plantTree`, `rsg-lumberjack:server:removeLogFromWagon`, `rsg-lumberjack:server:requestSync`, `rsg-lumberjack:server:sellWagonLoad`, `rsg-lumberjack:server:waterTree`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-lumberjack:client:addGroundLog`, `rsg-lumberjack:client:addWoodPiece`, `rsg-lumberjack:client:removeGroundLog`, `rsg-lumberjack:client:removeTree`, `rsg-lumberjack:client:removeWoodPiece`, `rsg-lumberjack:client:setTrees`, `rsg-lumberjack:client:startCarrying`, `rsg-lumberjack:client:stopCarrying`, `rsg-lumberjack:client:syncGroundLogs`, `rsg-lumberjack:client:syncWoodPieces`, `rsg-lumberjack:client:updateTreeVisual`, `rsg-lumberjack:client:useSeed`, `rsg-lumberjack:client:useWater`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-lumberjack:server:requestChop`

## Commands (RegisterCommand)

**client:** `/spawnwagon`

## Database tables

`rsg_lumberjack_trees`
