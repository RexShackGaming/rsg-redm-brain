# rsg-hunting

Version 3.1.0. Hunting, trapper and butcher script for RSG Framework

Hunting, trapper and butcher script for the RSG Framework (RedM). Players skin animals for materials, sell those materials to trappers, sell whole carcasses to butchers, and earn **hunting XP** that unlocks level perks and ranks them on a server **leaderboard**. - Hooks into the game's native skinning event (no minigame) - Up to 5 reward items per animal, 90+ animals preconfigured (`Config.Animals

Source: https://github.com/Rexshack-RedM/rsg-hunting

**Dependencies:** `oxmysql`, `rsg-core`, `ox_lib`, `ox_target`, `rsg-inventory`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-hunting']:Name)

**server:** `AwardHuntingXP(src, amount)`, `GetHuntingLevel(src)`, `GetHuntingXP(src)`, `SendWebhook(channel, data)`

## Net events registered

**server:** `rsg-hunting:server:giverewards`

## Event handlers

**client:** `rsg-hunting:client:butcher:mainmenu`

## Callbacks (lib.callback)

**server:** `rsg-hunting:server:getLeaderboard`, `rsg-hunting:server:getSellData`, `rsg-hunting:server:sellBasket`, `rsg-hunting:server:sellCarcass`

## Commands (RSGCore.Commands.Add)

**server:** `/huntingwebhooktest`

## Commands (RegisterCommand)

**server:** `/resetvendorstock`

## Public (table) functions

**server/webhooks.lua:** `HuntingWebhook.PlayerFields(src)`, `HuntingWebhook.Send(channel, data)`, `HuntingWebhook.Skin(src, animalName, items, xp)`, `HuntingWebhook.FlushSkins(src)`, `HuntingWebhook.Sale(channel, src, title, fields, cash)`, `HuntingWebhook.Security(src, source_, reason)`

**server/xp.lua:** `HuntingXP.GetLevelData(xp)`, `HuntingXP.GetXP(src)`, `HuntingXP.GetPerks(src)`, `HuntingXP.GetAnimalXP(model)`, `HuntingXP.Award(src, amount)`
