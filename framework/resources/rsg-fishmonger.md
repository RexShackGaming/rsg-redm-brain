# rsg-fishmonger

Version 2.0.0. rsg-fishmonger

A fishmonger system for **RSG-Core (RedM)**. Players visit a fishmonger NPC in any major town to **sell their catch for cash** or **process fish into fillets**, using a cart-based menu styled to match the rest of the RSG UI. - **8 fishmonger NPCs**: Saint Denis, Blackwater, Valentine, Rhodes, Annesburg, Van Horn, Tumbleweed and the river trading post. Each has an optional map blip. - **Sell or pro

Source: https://github.com/Rexshack-RedM/rsg-fishmonger

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`, `ox_target`

Has NUI (`ui_page`).

## Callbacks (lib.callback)

**server:** `rsg-fishmonger:server:checkout`, `rsg-fishmonger:server:getFishCounts`

## Public (table) functions

**server/webhook.lua:** `Webhook.PlayerFields(src)`, `Webhook.Send(logType, data)`
