# rsg-essentials

Version 3.2.1. rsg-essentials

**Quality-of-life utilities and fixes for RedM using RSG Core.** > A collection of small but essential features: AFK kick, Discord rich presence, Discord logging, eagle eye access, hands up / pointing, lantern holstering, river wash & drink, map zone colours, door unlocks, restart storm, Christmas weather and more. - [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core) 🤠 *(locales, notify, ca

Source: https://github.com/Rexshack-RedM/rsg-essentials

**Dependencies:** `rsg-core`

## Net events registered

**server:** `rsg-discord:getdata`, `rsg-essentials:server:afkKick`, `rsg-log:server:CreateLog`

**client:** `RSGCore:Client:OnJobUpdate`, `RSGCore:Client:OnPermissionUpdate`, `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-core:client:RemoveWeaponFromTab`, `rsg-discord:receivedata`

## Event handlers

**server:** `txAdmin:events:scheduledRestart`

**client:** `RSGCore:Client:OnPlayerLoaded`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-essentials:server:getPermissions`

## Commands (RSGCore.Commands.Add)

**server:** `/testwebhook`

## Commands (RegisterCommand)

**client:** `/hideui`

## Server events it triggers in other resources

**client:** `rsg-discord:getdata`
