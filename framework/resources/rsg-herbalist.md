# rsg-herbalist

Version 3.5.5. Herbalist script for RSG Framework

A herb gathering, tonic crafting, and mystery box script for **RSG-Core** RedM servers, by RexShack. **Version 3.5.5** · No ox_lib required · Full developer/server-owner reference: [DOCS.md](DOCS.md) Players gather herbs from world-placed nodes, brew them into tonics at a mortar & pestle, and can stumble on a roaming mystery box that relocates around the map every so often. Every gather, craft, an

Source: https://github.com/Rexshack-RedM/rsg-herbalist

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-herbalist:server:cancelCraft`, `rsg-herbalist:server:finishCraft`, `rsg-herbalist:server:gathered`, `rsg-herbalist:server:openMysteryBox`, `rsg-herbalist:server:requestBuyers`, `rsg-herbalist:server:requestCraft`, `rsg-herbalist:server:requestMysteryBox`, `rsg-herbalist:server:requestSync`, `rsg-herbalist:server:sell`

**client:** `RSGCore:Player:SetPlayerData`, `rsg-herbalist:client:ApplyTonicEffect`, `rsg-herbalist:client:BuyerStock`, `rsg-herbalist:client:ForceReload`, `rsg-herbalist:client:OpenTonicCrafting`, `rsg-herbalist:client:SetBuyers`, `rsg-herbalist:client:SetMysteryBox`, `rsg-herbalist:client:SetSuppressed`, `rsg-herbalist:client:StartCraftProgress`, `rsg-herbalist:client:SyncState`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-herbalist:server:getBuyerStock`, `rsg-herbalist:server:getGuide`

## Usable items

**server:** `mortarpestle`

## Commands (RegisterCommand)

**server:** `/addherbbuyer`, `/removeherbbuyer`

## Public (table) functions

**server/database.lua:** `Herbalist.LoadState(key, cb)`, `Herbalist.SaveState(key, data)`

**server/server.lua:** `Herbalist.RecordFound(src, Player, item, amount)`

**server/utils.lua:** `Herbalist.Notify(src, title, description, nType)`, `Herbalist.IsDead(Player)`

**server/webhook.lua:** `Webhook.LogGather(src, itemLabel, coordKey)`, `Webhook.LogCraft(src, tonic, outcome)`, `Webhook.LogSale(src, itemLabel, amount, total)`, `Webhook.LogMysteryBox(src, lootItems)`, `Webhook.LogResourceEvent(state)`, `Webhook.LogVersionCheck(status, message)`, `Webhook.FlagSuspicious(src, reason, details)`

## Database tables

`rsg_herbalist_state`
