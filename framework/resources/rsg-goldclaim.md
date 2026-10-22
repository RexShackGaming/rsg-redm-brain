# rsg-goldclaim

Version 3.0.0. rsg-goldclaim

A gold claim system for RedM (RSG-Core). Players place gold rockers, load them with paydirt and water, process the load into gold ore, and manage licensed or unlicensed claims. Every menu and dialog uses a custom RDR2 leather & gold NUI. - **Placeable gold rocker**: placement preview with rotation, which persists across restarts. - **Licensed and unlicensed claims**: if you hold a `resource_gold_c

Source: https://github.com/Rexshack-RedM/rsg-goldclaim

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`, `ox_target`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-goldclaim:rocker:server:addpaydirt`, `rsg-goldclaim:rocker:server:addwater`, `rsg-goldclaim:rocker:server:destroyProp`, `rsg-goldclaim:rocker:server:digpaydirt`, `rsg-goldclaim:rocker:server:fillbucket`, `rsg-goldclaim:rocker:server:leodestroy`, `rsg-goldclaim:rocker:server:newProp`, `rsg-goldclaim:rocker:server:pickupgold`, `rsg-goldclaim:rocker:server:pickuppaydirt`, `rsg-goldclaim:rocker:server:processrocker`, `rsg-goldclaim:rocker:server:renameclaim`, `rsg-goldclaim:rocker:server:repairrocker`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-goldclaim:rocker:client:addpaydirt`, `rsg-goldclaim:rocker:client:addwater`, `rsg-goldclaim:rocker:client:checkrocker`, `rsg-goldclaim:rocker:client:createprop`, `rsg-goldclaim:rocker:client:destroyillegal`, `rsg-goldclaim:rocker:client:goldpickupresult`, `rsg-goldclaim:rocker:client:mainmenu`, `rsg-goldclaim:rocker:client:packuprocker`, `rsg-goldclaim:rocker:client:processingcomplete`, `rsg-goldclaim:rocker:client:refreshclaim`, `rsg-goldclaim:rocker:client:removePropObject`, `rsg-goldclaim:rocker:client:renameclaim`, `rsg-goldclaim:rocker:client:repairrocker`, `rsg-goldclaim:rocker:client:spawnoutputprop`, `rsg-goldclaim:rocker:client:startprocessing`, `rsg-goldclaim:rocker:client:updatePropData`, `rsg-goldclaim:rocker:client:usebucket`, `rsg-goldclaim:rocker:client:useshovel`

## Event handlers

**client:** `rsg-goldclaim:rocker:client:placeNewProp`

## Callbacks (lib.callback)

**server:** `rsg-goldclaim:server:countprops`, `rsg-goldclaim:server:getpending`, `rsg-goldclaim:server:getprops`, `rsg-goldclaim:server:getrockerdata`

## Usable items

**server:** `tool_goldrocker`, `tool_rocker_bucket_empty`, `tool_rocker_shovel`

## Commands (RegisterCommand)

**server:** `/goldclaim_webhooktest`

## Public (table) functions

**server/webhooks.lua:** `Webhook.Log(event, src, title, data, opts)`, `Webhook.Suspicious(src, reason, details)`

## Database tables

`player_goldrockers`
