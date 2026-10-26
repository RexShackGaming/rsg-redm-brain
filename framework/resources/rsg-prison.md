# rsg-prison

Version 3.2.0. rsg-prison

**Prison system for RedM servers using RSG Core.** - [rsg-core](https://github.com/Rexshack-RedM/rsg-core) - [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)

Source: https://github.com/Rexshack-RedM/rsg-prison

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-character`, `ox_lib`, `ox_target`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-prison']:Name)

**server:** `DiscordLog(category, title, src, fields, description)`

## Net events registered

**server:** `rsg-prison:server:checkRelease`, `rsg-prison:server:escapeAttempt`, `rsg-prison:server:requestRation`, `rsg-prison:server:startSentence`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-prison:client:Enter`, `rsg-prison:client:disarm`, `rsg-prison:client:freedom`, `rsg-prison:client:menu`, `rsg-prison:client:reequip`, `rsg-prison:client:updateTime`

## Event handlers

**client:** `rsg-medic:client:revive`

## Public (table) functions

**client/npcs.lua:** `point:onEnter()`, `point:onExit()`
