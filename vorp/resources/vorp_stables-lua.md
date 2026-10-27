# vorp_stables-lua

Version 1.3. A Stables script for vorp core framework

**based on stables from C# version** It is with great pleasure that I will introduce you to this plugin. The goal of it's making was to allow an easier workflow on vorp_stables, and to add a few features. - [For tips on how to use this plugin in-game](#Usage)

Source: https://github.com/VORPCORE/vorp_stables-lua

Has NUI (`ui_page`).

## Net events registered

**client:** `charsLoaded`, `vorp:SelectedCharacter`

## Public (table) functions

**Client/PlayerStable.lua:** `Ride:new(rideFromDB)`, `PlayerStable:new(ridesAsDBList, charId, availableComps, waitingRides)`, `PlayerStable:horseCount(stable)`, `PlayerStable:cartCount(stable)`, `PlayerStable:isFull(stable, rideType)`

## Database tables

`horse_complements`, `stables`
