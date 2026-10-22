# rsg-looting

Version 3.0.2. rsg-looting

Secure NPC looting and player robbery for **RSG Framework (RedM)**, with ox_lib notifications, multi-language support and Discord webhook logging. - Loot dead NPCs with **ox_target** (third-eye a body → *Loot Body*), with a search animation and progress bar. - Looted bodies are flagged server side (entity state bag) so the prompt disappears for everyone.

Source: https://github.com/Rexshack-RedM/rsg-looting

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-lawman`, `ox_lib`, `ox_target`, `oxmysql`

## Exports (call as exports['rsg-looting']:Name)

**server:** `SendWebhook(channel, embed)`

## Net events registered

**server:** `rsg-looting:server:robPlayer`

**client:** `rsg-looting:client:RobPlayer`

## Event handlers

**server:** `entityRemoved`

## Callbacks (lib.callback)

**server:** `rsg-looting:server:canRob`, `rsg-looting:server:lootReward`

**client:** `rsg-looting:client:isHandsUp`

## Server events it triggers in other resources

**client:** `rsg-lawman:server:lawmanAlert`

## Public (table) functions

**server/sv_webhooks.lua:** `Webhooks.Loot(src, itemLabel, amount, cash, rare)`, `Webhooks.Rob(src, targetId, reason, cash, bloodmoney)`, `Webhooks.Exploit(src, event, reason)`
