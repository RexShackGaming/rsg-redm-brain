# rsg-fishmonger

Version 3.3.1. rsg-fishmonger

A fishmonger system for **RSG-Core (RedM)**. Players visit a fishmonger NPC in any major town to **sell their catch for cash** or **process fish into fillets**, using a cart-based menu styled to match the rest of the RSG UI. - **8 fishmonger NPCs**: Saint Denis, Blackwater, Valentine, Rhodes, Annesburg, Van Horn, Tumbleweed and the river trading post. Each has an optional map blip. - **Sell or pro

Source: https://github.com/Rexshack-RedM/rsg-fishmonger

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-fishmonger:server:openShop`

**client:** `RSGCore:Client:OnPlayerUnload`, `rsg-fishmonger:client:hours`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-fishmonger:server:checkout`, `rsg-fishmonger:server:deliverOrder`, `rsg-fishmonger:server:getHours`, `rsg-fishmonger:server:getMenuData`

## Commands (RSGCore.Commands.Add)

**server:** `/fishmonger_webhooktest`

## Public (table) functions

**server/webhook.lua:** `Webhook.PlayerFields(src)`, `Webhook.Send(logType, data)`

## Database tables

`rsg_fishmonger_orders`, `rsg_fishmonger_stock`
