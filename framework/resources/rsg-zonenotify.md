# rsg-zonenotify

Version 3.1.1. rsg-zonenotify - location banner when entering states, districts and towns

Shows a Red Dead style location banner when a player rides into a new state, district or town, with the in-game time, temperature and wind underneath. Built for the RSG Framework, based on [vorp_zonenotify](https://github.com/VORPCORE/vorp_zonenotify). - Custom NUI banner styled like the game's own (works while riding); native banner or ox_lib notify still available via `DisplayMode` - Separate to

Source: https://github.com/Rexshack-RedM/rsg-zonenotify

**Dependencies:** `rsg-core`, `ox_lib`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-zonenotify']:Name)

**client:** `ShowCurrentLocation()`

## Net events registered

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`

## Commands (RegisterCommand)

**client:** `/zonetest`

## Public (table) functions

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`
