# rsg-stores

Version 3.0.0. rsg-stores

**Version 3.0.0** · requires rsg-core, rsg-inventory, rsg-target, oxmysql (no ox_lib) Create NPC shopkeepers, **player-owned stores**, shops and map blips in-game for **RSG-Core (RedM)**, all from an admin menu with no config editing. Players buy with a cart or sell straight back to the shop through a themed NUI. Every transaction is checked on the server and can be logged to Discord. Full develop

Source: https://github.com/Rexshack-RedM/rsg-stores

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-stores']:Name)

**server:** `SendWebhook(channel, title, description, src, fields)`

## Net events registered

**server:** `rsg-blipmenu:server:deleteBlip`, `rsg-blipmenu:server:deleteNPC`, `rsg-blipmenu:server:evictOwner`, `rsg-blipmenu:server:requestBlips`, `rsg-blipmenu:server:requestNPCs`, `rsg-blipmenu:server:saveBlip`, `rsg-blipmenu:server:updateBlip`, `rsg-blipmenu:server:updateNPC`, `rsg-stores:server:purchaseCart`, `rsg-stores:server:requestShopStock`, `rsg-stores:server:sellItem`

**client:** `RSGCore:Player:SetPlayerData`, `rsg-blipmenu:client:refreshBlips`, `rsg-blipmenu:client:refreshNPCs`, `rsg-stores:client:purchaseFailed`, `rsg-stores:client:purchaseSuccess`, `rsg-stores:client:shopStock`, `rsg-stores:client:startSignPlacement`, `rsg-stores:client:transactionResult`, `rsg-stores:client:updateShop`

## Event handlers

**client:** `RSGCore:Client:OnPlayerLoaded`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-stores:server:ownerAddStock`, `rsg-stores:server:ownerGetState`, `rsg-stores:server:ownerPayUpkeep`, `rsg-stores:server:ownerRemoveListing`, `rsg-stores:server:ownerSetPrice`, `rsg-stores:server:ownerSetSettings`, `rsg-stores:server:ownerTakeStock`, `rsg-stores:server:ownerWholesale`, `rsg-stores:server:ownerWithdraw`

## Commands (RegisterCommand)

**server:** `/storeswebhooktest`

**client:** `/createshop`

## Server events it triggers in other resources

**client:** `rsg-blipmenu:server:deleteBlip`, `rsg-blipmenu:server:deleteNPC`, `rsg-blipmenu:server:evictOwner`, `rsg-blipmenu:server:requestBlips`, `rsg-blipmenu:server:requestNPCs`, `rsg-blipmenu:server:saveBlip`, `rsg-blipmenu:server:updateBlip`, `rsg-blipmenu:server:updateNPC`

## Public (table) functions

**server/sv_database.lua:** `Database.Install()`

**server/sv_webhooks.lua:** `Webhook.Send(channel, title, description, src, fields, opts)`, `Webhook.Security(src, reason, fields)`, `Webhook.IsLarge(amount)`

## Database tables

`rsg_shops_blips`, `rsg_shops_items`, `rsg_shops_ledger`, `rsg_shops_npcs`, `rsg_shops_presets`
