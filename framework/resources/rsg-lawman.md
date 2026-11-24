# rsg-lawman

Version 3.4.0. rsg-lawman

**Law enforcement and sheriff management system for RedM using RSG Core.** > Full-featured law enforcement framework for RedM built on RSG Core. > Provides arrest, search, alerts, and law office management systems with rsg-core notifications/locales and configurable prompts.

Source: https://github.com/Rexshack-RedM/rsg-lawman

**Dependencies:** `rsg-core`, `rsg-inventory`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-lawman']:Name)

**server:** `AddOutlawStatus(src, amount)`, `SendAlert(coords, text, alertType)`

## Net events registered

**server:** `rsg-lawman:server:SearchPlayer`, `rsg-lawman:server:cuffplayer`, `rsg-lawman:server:escortplayer`, `rsg-lawman:server:frisk`, `rsg-lawman:server:jailplayer`, `rsg-lawman:server:lawmanAlert`, `rsg-lawman:server:seize`, `rsg-lawman:server:setescortstatus`, `rsg-lawman:server:sethandcuffstatus`, `rsg-lawman:server:storage`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-lawman:client:cuffplayer`, `rsg-lawman:client:escortplayer`, `rsg-lawman:client:frisk`, `rsg-lawman:client:friskResult`, `rsg-lawman:client:getcuffed`, `rsg-lawman:client:getescorted`, `rsg-lawman:client:heldInCell`, `rsg-lawman:client:jailplayer`, `rsg-lawman:client:lawbadge`, `rsg-lawman:client:lawmanAlert`, `rsg-lawman:client:mainmenu`, `rsg-lawman:client:openarmoury`, `rsg-lawman:client:openstorage`, `rsg-lawman:client:releasedFromCell`, `rsg-lawman:client:searchplayer`, `rsg-lawman:client:sendtojail`

## Event handlers

**server:** `RSGCore:Server:PlayerLoaded`

**client:** `rsg-lawman:client:ToggleDuty`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-lawman:server:getlaw`

## Usable items

**server:** `handcuffs`

## Commands (RSGCore.Commands.Add)

**server:** `/911`, `/cuff`, `/escort`, `/fine`, `/frisk`, `/holdcell`, `/jail`, `/jailnear`, `/lawbadge`, `/releasecell`, `/searchplayer`, `/testalert`, `/unjail`

## Server events it triggers in other resources

**client:** `RSGCore:ToggleDuty`, `rsg-shops:server:openstore`
