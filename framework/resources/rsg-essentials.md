# rsg-essentials

Version 3.1.1. rsg-essentials

**Quality-of-life utilities and fixes for RedM using RSG Core.** > A collection of small but essential features: AFK kick, Discord rich presence, eagle eye access, first-person shooting handling, map zone labels, door unlocks, water interactions, and more. Modular client/server files make it easy to enable only what you need. - [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core) 🤠

Source: https://github.com/Rexshack-RedM/rsg-essentials

**Dependencies:** `rsg-core`, `ox_lib`

## Net events registered

**server:** `KickForAFK`, `rsg-discord:getdata`, `rsg-log:server:CreateLog`

**client:** `RSGCore:Client:OnJobUpdate`, `RSGCore:Client:OnPermissionUpdate`, `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-core:client:RemoveWeaponFromTab`, `rsg-discord:receivedata`, `rsg-essentials:client:pvpToggle`

## Event handlers

**server:** `txAdmin:events:scheduledRestart`

**client:** `RSGCore:Client:OnJobUpdate`, `RSGCore:Client:OnPlayerLoaded`, `rsg-river:client:drink`, `rsg-river:client:lavati`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-afkkick:server:GetPermissions`

## Commands (RSGCore.Commands.Add)

**server:** `/testwebhook`

## Commands (RegisterCommand)

**client:** `/hideui`

## Server events it triggers in other resources

**client:** `KickForAFK`, `rsg-discord:getdata`

## Public (table) functions

**client/maxcores.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`, `DataStream.New(view)`
