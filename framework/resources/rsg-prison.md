# rsg-prison

Version 3.1.0. rsg-prison

**Prison system for RedM servers using RSG Core.** - [rsg-core](https://github.com/Rexshack-RedM/rsg-core) - [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)

Source: https://github.com/Rexshack-RedM/rsg-prison

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`, `ox_target`, `oxmysql`

## Net events registered

**server:** `rsg-prison:server:checkRelease`, `rsg-prison:server:requestRation`, `rsg-prison:server:startSentence`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-prison:client:Enter`, `rsg-prison:client:freedom`, `rsg-prison:client:menu`, `rsg-prison:client:updateTime`

## Public (table) functions

**client/npcs.lua:** `point:onEnter()`, `point:onExit()`
