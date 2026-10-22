# rsg-stores

Version 2.1.4. rsg-stores

Create NPC shopkeepers, shops and map blips in-game for **RSG-Core (RedM)**, all from an admin menu with no config editing. Players buy with a cart or sell straight back to the shop through a themed NUI. Every transaction is checked on the server and can be logged to Discord. - **Shop UI**: dark leather-and-gold RDR2-style interface. - **Buy mode**: item grid with search, sort (name / price ↑ / pr

Source: https://github.com/Rexshack-RedM/rsg-stores

**Dependencies:** `rsg-core`, `ox_lib`, `ox_target`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-stores']:Name)

**server:** `SendWebhook(channel, title, description, src, fields)`

## Net events registered

**server:** `rsg-blipmenu:server:deleteBlip`, `rsg-blipmenu:server:deleteNPC`, `rsg-blipmenu:server:requestBlips`, `rsg-blipmenu:server:requestNPCs`, `rsg-blipmenu:server:saveBlip`, `rsg-blipmenu:server:updateBlip`, `rsg-blipmenu:server:updateNPC`, `rsg-stores:server:purchaseCart`, `rsg-stores:server:requestShopStock`, `rsg-stores:server:sellItem`

**client:** `RSGCore:Player:SetPlayerData`, `rsg-blipmenu:client:refreshBlips`, `rsg-blipmenu:client:refreshNPCs`, `rsg-stores:client:purchaseFailed`, `rsg-stores:client:purchaseSuccess`, `rsg-stores:client:shopStock`, `rsg-stores:client:transactionResult`

## Event handlers

**client:** `RSGCore:Client:OnPlayerLoaded`

## Callbacks (lib.callback)

**server:** `rsg-blipmenu:server:hasAdminPerm`, `rsg-blipmenu:server:saveNPC`, `rsg-stores:server:deletePreset`, `rsg-stores:server:getPresets`, `rsg-stores:server:savePreset`

## Commands (RegisterCommand)

**server:** `/storeswebhooktest`

**client:** `/npcshops`

## Server events it triggers in other resources

**client:** `rsg-blipmenu:server:deleteBlip`, `rsg-blipmenu:server:deleteNPC`, `rsg-blipmenu:server:requestBlips`, `rsg-blipmenu:server:requestNPCs`, `rsg-blipmenu:server:saveBlip`, `rsg-blipmenu:server:updateBlip`, `rsg-blipmenu:server:updateNPC`

## Public (table) functions

**server/sv_database.lua:** `Database.Install()`

**server/sv_webhooks.lua:** `Webhook.Send(channel, title, description, src, fields, opts)`, `Webhook.Security(src, reason, fields)`, `Webhook.IsLarge(amount)`

## Database tables

`rsg_shops_blips`, `rsg_shops_items`, `rsg_shops_npcs`, `rsg_shops_presets`
