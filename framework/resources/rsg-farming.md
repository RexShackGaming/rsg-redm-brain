# rsg-farming

Version 3.0.3. rsg-farming

Plant, water, fertilise and harvest crops anywhere in the world, with portable well pumps to fill your water buckets. Built for **RSG-Core (RedM)** with ox_lib, ox_target and oxmysql. - **Plant anywhere**: use a seed item to place a ghost crop with a placement gizmo (rotate, raise or lower, valid/invalid ring). - **Live growth simulation on the server**: water and fertiliser drain over time, healt

Source: https://github.com/Rexshack-RedM/rsg-farming

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`, `oxmysql`, `ox_target`

Has NUI (`ui_page`).

## Net events registered

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-farming:client:placePump`, `rsg-farming:client:startPlacing`, `rsg-farming:client:sync`, `rsg-farming:client:syncPumps`

## Event handlers

**server:** `txAdmin:events:serverShuttingDown`

## Callbacks (lib.callback)

**server:** `rsg-farming:server:destroy`, `rsg-farming:server:fertilize`, `rsg-farming:server:fillBucket`, `rsg-farming:server:getPlants`, `rsg-farming:server:getPumps`, `rsg-farming:server:harvest`, `rsg-farming:server:packPump`, `rsg-farming:server:placePump`, `rsg-farming:server:plant`, `rsg-farming:server:precheck`, `rsg-farming:server:pumpPrecheck`, `rsg-farming:server:water`

## Commands (RegisterCommand)

**client:** `/myplants`

## Public (table) functions

**client/placement.lua:** `Placement.Start(model, checkFn, invalidMsg)`

**client/utils.lua:** `Utils.notify(desc, ntype)`, `Utils.canAct()`, `Utils.face(x, y)`, `Utils.playScenario(scenario, duration, label)`, `Utils.spawnProp(model, x, y, z, heading)`, `Utils.deleteProp(obj)`

**server/utils.lua:** `Utils.notify(src, desc, ntype)`, `Utils.getPlayer(src)`, `Utils.distanceTo(src, x, y, z)`, `Utils.toCoords(c)`, `Utils.toHeading(h)`, `Utils.hasItem(Player, item)`, `Utils.canAdd(src, item, amount)`, `Utils.removeItem(src, item, amount, slot, reason)`, `Utils.addItem(src, item, amount, info, reason)`, `Utils.startAction(src, key, durationMs)`, `Utils.finishAction(src, key)`
