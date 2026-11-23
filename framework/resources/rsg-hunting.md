# rsg-hunting

Version 3.5.0. Hunting, trapper and butcher script for RSG Framework

Hunting, trapper and butcher script for the RSG Framework (RedM). Players skin animals for materials, sell those materials to trappers, sell whole carcasses to butchers, and earn **hunting XP** that unlocks level perks and ranks them on a server **leaderboard**. - Hooks into the game's native skinning event (no minigame) - Up to 5 reward items per animal, 90+ animals preconfigured (`Config.Animals

Source: https://github.com/Rexshack-RedM/rsg-hunting

**Dependencies:** `oxmysql`, `rsg-core`, `rsg-target`, `rsg-inventory`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-hunting']:Name)

**server:** `AwardHuntingXP(src, amount)`, `GetBulkBonus(count)`, `GetDailyBounties(region)`, `GetHuntingLevel(src)`, `GetHuntingXP(src)`, `SendWebhook(channel, data)`

## Net events registered

**server:** `rsg-hunting:server:contract`, `rsg-hunting:server:giverewards`

## Event handlers

**client:** `rsg-hunting:client:butcher:mainmenu`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-hunting:server:claimWeekly`, `rsg-hunting:server:getBounties`, `rsg-hunting:server:getLeaderboard`, `rsg-hunting:server:getSellData`, `rsg-hunting:server:sellBasket`, `rsg-hunting:server:sellCarcass`

## Commands (RSGCore.Commands.Add)

**server:** `/huntingwebhooktest`

## Commands (RegisterCommand)

**server:** `/resetvendorstock`

## Public (table) functions

**client/nui.lua:** `HuntingNui.Focus(owner, enable)`

**server/bounty.lua:** `HuntingBounty.RegionAt(coords)`, `HuntingBounty.Get(model, region)`, `HuntingBounty.List(region)`, `HuntingBounty.XPMultiplier(model, region)`, `HuntingBounty.ButcherBonus(model, region)`

**server/contracts.lua:** `HuntingContracts.OnSkin(src, model, quality)`, `HuntingContracts.Interact(src)`

**server/demand.lua:** `HuntingDemand.Multiplier(itemName)`, `HuntingDemand.Active()`

**server/gates.lua:** `HuntingGates.Check(src, model)`, `HuntingGates.Notify(src, why, need)`

**server/journal.lua:** `HuntingJournal.Name(model)`, `HuntingJournal.RecordSkin(src, model, quality)`, `HuntingJournal.RecordSale(src, model, cash)`, `HuntingJournal.Board(src, maxRows)`

**server/webhooks.lua:** `HuntingWebhook.PlayerFields(src)`, `HuntingWebhook.Send(channel, data)`, `HuntingWebhook.Skin(src, animalName, items, xp)`, `HuntingWebhook.FlushSkins(src)`, `HuntingWebhook.Sale(channel, src, title, fields, cash)`, `HuntingWebhook.Security(src, source_, reason)`

**server/xp.lua:** `HuntingXP.GetLevelData(xp)`, `HuntingXP.GetXP(src)`, `HuntingXP.GetPerks(src)`, `HuntingXP.GetAnimalXP(model)`, `HuntingXP.Award(src, amount)`

## Database tables

`hunting_contracts`, `hunting_journal`, `hunting_weekly`, `hunting_weekly_rewards`, `hunting_weekly_state`
