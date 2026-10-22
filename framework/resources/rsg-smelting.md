# rsg-smelting

Version 3.0.3. rsg-smelting

Turn ores into metal bars at smelter NPCs or ore-bucket props. Built for **RSG-Core** (RedM) with ox_lib, ox_target and rsg-inventory. - Smelter NPCs with blips, spawned/despawned by proximity (`lib.points`) - Optional world-prop smelters via ox_target (`p_bucketore03x`, `p_horseprops03x` by default)

Source: https://github.com/Rexshack-RedM/rsg-smelting

**Dependencies:** `rsg-core`, `oxmysql`, `rsg-inventory`, `ox_lib`, `ox_target`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-smelting']:Name)

**server:** `SendWebhook(event, srcOrInfo, fields, description)`

## Net events registered

**server:** `RSGCore:Server:OnPlayerLoaded`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`

## Callbacks (lib.callback)

**server:** `rsg-smelting:server:finishSmelt`, `rsg-smelting:server:getOreCounts`, `rsg-smelting:server:startSmelt`

## Public (table) functions

**server/webhook.lua:** `Webhook.PlayerInfo(src)`, `Webhook.Send(event, srcOrInfo, fields, description)`, `Webhook.Inputs(recipe, amount)`, `Webhook.SmelterName(smelter)`, `Webhook.Flush()`
