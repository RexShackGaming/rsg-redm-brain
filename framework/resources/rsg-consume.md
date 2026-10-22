# rsg-consume

Version 3.0.0. rsg-consume

**Universal consumption system for RedM using RSG Core.** > Immersive eating and drinking system for RedM servers built on RSG Core. > Adds configurable hunger, thirst, alcohol and stress effects with synchronized animations and props.

Source: https://github.com/Rexshack-RedM/rsg-consume

**Dependencies:** `rsg-core`, `ox_lib`, `rsg-inventory`

## Net events registered

**server:** `rsg-consume:server:finish`

**client:** `rsg-consume:client:consume`

## Server events it triggers in other resources

**client:** `hud:server:GainStress`

## Public (table) functions

**client/client.lua:** `animations.Eat(ped, data)`, `animations.Drink(ped, data)`, `animations.Stew(ped)`, `animations.Hotdrinks(ped)`, `animations.Eatcanned(ped, data)`
