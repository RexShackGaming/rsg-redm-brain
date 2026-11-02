# rsg-zonenotify

Version 3.2.0. rsg-zonenotify - location banner when entering states, districts and towns

**Version 3.3.0** · Dependencies: rsg-core, oxmysql · Full reference: [DOCS.md](DOCS.md) Shows a Red Dead style location banner when a player rides into a new state, district or town, with the in-game time, temperature and wind underneath. Built for the RSG Framework, based on [vorp_zonenotify](https://github.com/VORPCORE/vorp_zonenotify). - **New Discovery** stamp the first time each character vi

Source: https://github.com/Rexshack-RedM/rsg-zonenotify

**Dependencies:** `rsg-core`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-zonenotify']:Name)

**server:** `GetDiscoveryCount(citizenid)`, `HasDiscovered(citizenid, zone)`, `ShowBanner(target, title, subtitle, duration)`

**client:** `GetDiscoveryCount()`, `IsDiscovered(key)`, `SetSuppressed(reason, state)`, `ShowBanner(title, subtitle, duration)`, `ShowCurrentLocation()`

## Net events registered

**server:** `rsg-zonenotify:server:discover`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-zonenotify:client:showBanner`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-zonenotify:server:getDiscoveries`

## Commands (RegisterCommand)

**client:** `/zonetest`

## Public (table) functions

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`

## Database tables

`zonenotify_discoveries`
