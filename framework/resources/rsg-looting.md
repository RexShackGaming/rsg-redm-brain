# rsg-looting

Version 3.0.4. rsg-looting

Secure NPC looting and player robbery for **RSG Framework (RedM)**, with rsg-core notifications, progress bars and callbacks (no ox_lib), multi-language support and Discord webhook logging. - Loot dead NPCs with the **native RDR2 loot prompt** (default) or **rsg-target** (target a body → *Loot Body*, with a search animation and progress bar) — set by `Config.LootMethod`. - Looted bodies are flagge

Source: https://github.com/Rexshack-RedM/rsg-looting

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-lawman`, `rsg-target`, `oxmysql`

## Exports (call as exports['rsg-looting']:Name)

**server:** `SendWebhook(channel, embed)`

## Net events registered

**server:** `rsg-looting:server:robPlayer`

**client:** `rsg-looting:client:RobPlayer`

## Event handlers

**server:** `entityRemoved`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-looting:server:canRob`, `rsg-looting:server:lootReward`

## Server events it triggers in other resources

**client:** `rsg-lawman:server:lawmanAlert`

## Public (table) functions

**server/sv_webhooks.lua:** `Webhooks.Loot(src, itemLabel, amount, cash, rare)`, `Webhooks.Rob(src, targetId, reason, cash, bloodmoney)`, `Webhooks.Exploit(src, event, reason)`
