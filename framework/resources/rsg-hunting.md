# rsg-hunting

Version 3.2.2. Hunting, trapper and butcher script for RSG Framework

Hunting, trapper and butcher script for the RSG Framework (RedM). Players skin animals for materials, sell those materials to trappers, sell whole carcasses to butchers, and earn **hunting XP** that unlocks level perks and ranks them on a server **leaderboard**. - Hooks into the game's native skinning event (no minigame) - Up to 5 reward items per animal, 90+ animals preconfigured (`Config.Animals

Source: https://github.com/Rexshack-RedM/rsg-hunting

**Dependencies:** `oxmysql`, `rsg-core`, `rsg-target`, `rsg-inventory`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-hunting']:Name)

**server:** `AwardHuntingXP(src, amount)`, `GetDailyBounties()`, `GetHuntingLevel(src)`, `GetHuntingXP(src)`, `SendWebhook(channel, data)`

## Net events registered

**server:** `rsg-hunting:server:giverewards`

## Event handlers

**client:** `rsg-hunting:client:butcher:mainmenu`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-hunting:server:claimWeekly`, `rsg-hunting:server:getBounties`, `rsg-hunting:server:getLeaderboard`, `rsg-hunting:server:getSellData`, `rsg-hunting:server:sellBasket`, `rsg-hunting:server:sellCarcass`

## Commands (RSGCore.Commands.Add)

**server:** `/huntingwebhooktest`

## Commands (RegisterCommand)

**server:** `/resetvendorstock`

## Public (table) functions

**server/bounty.lua:** `HuntingBounty.Get(model)`, `HuntingBounty.List()`, `HuntingBounty.XPMultiplier(model)`, `HuntingBounty.ButcherBonus(model)`

**server/webhooks.lua:** `HuntingWebhook.PlayerFields(src)`, `HuntingWebhook.Send(channel, data)`, `HuntingWebhook.Skin(src, animalName, items, xp)`, `HuntingWebhook.FlushSkins(src)`, `HuntingWebhook.Sale(channel, src, title, fields, cash)`, `HuntingWebhook.Security(src, source_, reason)`

**server/xp.lua:** `HuntingXP.GetLevelData(xp)`, `HuntingXP.GetXP(src)`, `HuntingXP.GetPerks(src)`, `HuntingXP.GetAnimalXP(model)`, `HuntingXP.Award(src, amount)`

## Database tables

`hunting_weekly`, `hunting_weekly_rewards`
