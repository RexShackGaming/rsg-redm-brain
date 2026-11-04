# rsg-smelting – Developer Docs

## Flow
1. Player targets a smelter NPC or prop (rsg-target) → client calls `rsg-smelting:server:getOreCounts` (also pays out any owed refunds) and opens the NUI.
2. Player picks recipe + quantity → `rsg-smelting:server:startSmelt(smelter, recipeIndex, amount, propCoords)`.
   Server validates player, 2s cooldown, busy/stale job, recipe, batch size (`Config.MaxBatch`), distance, item counts, then **removes the inputs up front** (rolled back if any removal fails) and stores the job in `pending[src]`.
3. Client runs the timer (Backspace cancels, death cancels) → `rsg-smelting:server:finishSmelt(cancelled)`.
   Server checks the character, elapsed time (≥ duration − 1s) and distance again, then gives the output (`CanAddItem` first) or refunds the inputs.

## Callbacks (rsg-core)
| Name | Args | Returns |
|---|---|---|
| `rsg-smelting:server:getOreCounts` | – | `{ [item] = count }` |
| `rsg-smelting:server:startSmelt` | smelter (`index` or `'prop'`), recipeIndex, amount, propCoords | `ok, errorMessage` |
| `rsg-smelting:server:finishSmelt` | cancelled (bool) | `success, message` |

The client never decides items, amounts or rewards: all inputs/outputs come from `Config.Recipes` on the server.

## Refunds & persistence
- Cancel, failed validation, full inventory, stale job (client crash), resource stop → inputs refunded.
- Disconnect / character logout mid-smelt → inputs owed to that citizenid.
- Refunds that don't fit are owed. Owed items are paid on `RSGCore:Server:OnPlayerLoaded` or when the character next opens a smelter.
- State (owed + live jobs) is saved to MySQL table `rsg_smelting_state` (auto-created, single row `id = 1`, JSON). Live jobs found at start (server crash) become owed.

## Exports
```lua
exports['rsg-smelting']:SendWebhook(event, srcOrInfo, fields, description)
```
`event` is a key from `SVConfig.Webhooks.Events`.

## Adding a recipe
Add an entry to `Config.Recipes` (`output`, `label` locale key, `time` ms per bar, `inputs` per bar) and the label key to all 10 locale files.

## Files
- `shared/config.lua` – smelters, props, recipes
- `server/sv_config.lua` – webhooks (server-only)
- `server/main.lua` – validation, inventory, persistence
- `server/webhook.lua` – Discord queue
- `client/main.lua` – peds, targets, NUI, timer
- `html/` – NUI (RDR2 leather & gold theme)
