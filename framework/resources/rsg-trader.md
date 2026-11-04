# rsg-trader

Version 3.1.0. rsg-trader

Dynamic-price NPC traders for **RSG-Core (RedM)**. Players buy and sell items at prices that move with stock levels. Admins place traders and manage stock in game through a built-in admin panel, with no config edits or restarts. - NPC traders spawn and despawn by distance, with optional fade-in and an rsg-target "Speak with the Trader" option - Buy / Sell UI that shows stock bars, your cash, owned

Source: https://github.com/Rexshack-RedM/rsg-trader

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-trader']:Name)

**server:** `SendWebhook(event, src, title, fields, description, ping)`

## Net events registered

**client:** `rsg-trader:client:openAdmin`

## Event handlers

**server:** `rsg-trader:server:databaseReady`

## Commands (RSGCore.Commands.Add)

**server:** `/traderadmin`, `/traderwebhooktest`

## Public (table) functions

**server/webhooks.lua:** `Webhook.Send(event, src, title, fields, description, ping)`, `Webhook.Suspicious(src, reason, details)`

**shared/config.lua:** `Config.Round2(n)`, `Config.GetBuyPrice(stock, lowstock, highstock, basePrice)`, `Config.GetSellPrice(stock, lowstock, highstock, basePrice)`

## Database tables

`rsg_trader`, `rsg_trader_npcs`
