# rsg-consume

Version 3.3.0. rsg-consume

**Universal consumption system for RedM using RSG Core.** > Immersive eating and drinking system for RedM servers built on RSG Core. > Adds configurable hunger, thirst, alcohol and stress effects with synchronized animations and props.

Source: https://github.com/Rexshack-RedM/rsg-consume

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`

## Exports (call as exports['rsg-consume']:Name)

**server:** `GetTolerance(src)`

## Net events registered

**server:** `rsg-consume:server:bar`, `rsg-consume:server:finish`, `rsg-consume:server:passedOut`, `rsg-consume:server:share`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-consume:client:buff`, `rsg-consume:client:consume`, `rsg-consume:client:sick`, `rsg-consume:client:tolerance`, `rsg-consume:client:warmth`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-consume:server:getTolerance`

## Public (table) functions

**client/client.lua:** `animations.Eat(ped, data)`, `animations.Drink(ped, data)`, `animations.Stew(ped)`, `animations.Hotdrinks(ped)`, `animations.Eatcanned(ped, data)`
