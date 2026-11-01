# rsg-farming

Version 3.0.4. rsg-farming

Plant, water, fertilise and harvest crops anywhere in the world, with portable well pumps to fill your water buckets. Built for **RSG-Core (RedM)** with rsg-target and oxmysql. No ox_lib required. - **Plant anywhere**: use a seed item to place a ghost crop with a placement gizmo (rotate, raise or lower, valid/invalid ring). - **Live growth simulation on the server**: water and fertiliser drain ove

Source: https://github.com/Rexshack-RedM/rsg-farming

**Dependencies:** `rsg-core`, `rsg-inventory`, `oxmysql`, `rsg-target`

Has NUI (`ui_page`).

## Net events registered

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-farming:client:placePump`, `rsg-farming:client:startPlacing`, `rsg-farming:client:sync`, `rsg-farming:client:syncPumps`

## Event handlers

**server:** `txAdmin:events:serverShuttingDown`

## Commands (RegisterCommand)

**client:** `/myplants`

## Public (table) functions

**client/placement.lua:** `Placement.Start(model, checkFn, invalidMsg)`

**client/utils.lua:** `Utils.notify(desc, ntype)`, `Utils.canAct()`, `Utils.face(x, y)`, `Utils.playScenario(scenario, duration, label)`, `Utils.spawnProp(model, x, y, z, heading)`, `Utils.deleteProp(obj)`

**server/utils.lua:** `Utils.callback(name, fn)`, `Utils.notify(src, desc, ntype)`, `Utils.getPlayer(src)`, `Utils.distanceTo(src, x, y, z)`, `Utils.toCoords(c)`, `Utils.toHeading(h)`, `Utils.hasItem(src, item)`, `Utils.canAdd(src, item, amount)`, `Utils.canAddAll(src, list)`, `Utils.removeItem(src, item, amount, slot, reason)`, `Utils.addItem(src, item, amount, info, reason, slot)`, `Utils.startAction(src, key, durationMs)`, `Utils.finishAction(src, key)`
