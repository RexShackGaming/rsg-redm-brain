# rsg-lawman

Version 3.0.1. rsg-lawman

**Law enforcement and sheriff management system for RedM using RSG Core.** > Full-featured law enforcement framework for RedM built on RSG Core. > Provides arrest, search, alerts, and law office management systems with ox_lib menus and configurable prompts.

Source: https://github.com/Rexshack-RedM/rsg-lawman

**Dependencies:** `rsg-core`, `ox_lib`

## Net events registered

**server:** `rsg-lawman:server:SearchPlayer`, `rsg-lawman:server:cuffplayer`, `rsg-lawman:server:escortplayer`, `rsg-lawman:server:jailplayer`, `rsg-lawman:server:lawmanAlert`, `rsg-lawman:server:setescortstatus`, `rsg-lawman:server:sethandcuffstatus`

**client:** `rsg-lawman:client:cuffplayer`, `rsg-lawman:client:escortplayer`, `rsg-lawman:client:getcuffed`, `rsg-lawman:client:getescorted`, `rsg-lawman:client:jailplayer`, `rsg-lawman:client:lawbadge`, `rsg-lawman:client:lawmanAlert`, `rsg-lawman:client:mainmenu`, `rsg-lawman:client:openarmoury`, `rsg-lawman:client:openstorage`, `rsg-lawman:client:searchplayer`, `rsg-lawman:client:sendtojail`

## Event handlers

**client:** `rsg-lawman:client:ToggleDuty`, `rsg-lawman:client:openarmoury`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-lawman:server:getlaw`

## Usable items

**server:** `handcuffs`

## Commands (RSGCore.Commands.Add)

**server:** `/cuff`, `/escort`, `/jail`, `/lawbadge`, `/searchplayer`, `/testalert`, `/unjail`

## Server events it triggers in other resources

**client:** `InteractSound_SV:PlayWithinDistance`, `RSGCore:ToggleDuty`, `rsg-shops:server:openstore`
