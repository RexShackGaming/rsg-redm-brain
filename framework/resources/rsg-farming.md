# rsg-farming

Version 3.6.0. rsg-farming

Plant, water, fertilise and harvest crops anywhere in the world, using the water buckets from rsg-wellpump. Built for **RSG-Core (RedM)** with rsg-target and oxmysql. No ox_lib required. - **Plant anywhere**: use a seed item to place a ghost crop with the standard **rsg-gizmo** placement tool. - **Live growth simulation on the server**: water and fertiliser drain over time, health drops when the p

Source: https://github.com/Rexshack-RedM/rsg-farming

**Dependencies:** `rsg-core`, `rsg-inventory`, `oxmysql`, `rsg-target`, `rsg-gizmo`, `rsg-wellpump`

Has NUI (`ui_page`).

## Net events registered

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-farming:client:plantMine`, `rsg-farming:client:plantRemove`, `rsg-farming:client:plantUpdate`, `rsg-farming:client:propAdd`, `rsg-farming:client:propMine`, `rsg-farming:client:propRemove`, `rsg-farming:client:startPlacing`, `rsg-farming:client:startPlacingProp`, `rsg-farming:client:sync`

## Event handlers

**server:** `txAdmin:events:serverShuttingDown`

## Commands (RSGCore.Commands.Add)

**server:** `/farmlevel`

## Commands (RegisterCommand)

**client:** `/myplants`

## Public (table) functions

**client/utils.lua:** `Utils.notify(desc, ntype)`, `Utils.canAct()`, `Utils.guard(fn, ...)`, `Utils.face(x, y)`, `Utils.setNuiFocus(enable)`, `Utils.place(model, check)`, `Utils.playScenario(scenario, duration, label)`, `Utils.loadModel(model)`, `Utils.spawnProp(model, x, y, z, heading)`, `Utils.deleteProp(obj)`

**server/utils.lua:** `Utils.callback(name, fn)`, `Utils.notify(src, desc, ntype)`, `Utils.getPlayer(src)`, `Utils.distanceTo(src, x, y, z)`, `Utils.toCoords(c)`, `Utils.toHeading(h)`, `Utils.hasItem(src, item)`, `Utils.canAdd(src, item, amount)`, `Utils.canAddAll(src, list)`, `Utils.removeItem(src, item, amount, slot, reason)`, `Utils.addItem(src, item, amount, info, reason, slot)`, `Utils.giveOrDrop(src, item, amount, info, reason, slot)`, `Utils.startAction(src, key, durationMs)`, `Utils.finishAction(src, key)`

**shared/zones.lua:** `Zones.blocked(coords)`, `Zones.farmland(coords)`

## Database tables

`rsg_farming_plants`, `rsg_farming_props`, `rsg_farming_soil`
