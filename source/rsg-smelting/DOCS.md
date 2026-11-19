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
Add an entry to `Config.Recipes` (`output`, `label` locale key, `time` ms per bar, `inputs` per bar) and the label key to all 11 locale files.

## Files
- `shared/config.lua` – smelters, props, recipes
- `server/sv_config.lua` – webhooks (server-only)
- `server/main.lua` – validation, inventory, persistence
- `server/webhook.lua` – Discord queue
- `client/main.lua` – peds, targets, NUI, timer
- `html/` – NUI (RDR2 leather & gold theme)

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-smelting 3.0.4**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `oxmysql`, `rsg-inventory`, `rsg-target`

### Database

Tables: `rsg_smelting_state`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/rsg-smelting.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.Smelters` | `table` | Smelter NPCs |
| `Config.SpawnDistance` | `50.0` | NPC spawns when player is within this range |
| `Config.TargetDistance` | `2.5` | rsg-target interaction range |
| `Config.SmeltProps` | `table` | Props that can be targeted to open the smelter (rsg-target addModel) |
| `Config.MaxUseDistance` | `5.0` | server-side anti-exploit distance check |
| `Config.MaxBatch` | `20` | max bars per smelt |
| `Config.ImagePath` | `'nui://rsg-inventory/html/images/'` | Inventory image folder used for item icons in the UI |
| `Config.Recipes` | `table` | label is a locale key (falls back to the text itself if no key exists) |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `SendWebhook` | `` | `server/webhook.lua` |

```lua
-- example
local result = exports['rsg-smelting']:SendWebhook()
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-smelting:server:getOreCounts` | server | `src, cb` | `server/main.lua` |
| `rsg-smelting:server:startSmelt` | server | `src, cb, ...` | `server/main.lua` |
| `rsg-smelting:server:finishSmelt` | server | `src, cb, cancelled` | `server/main.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-smelting:server:getOreCounts', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `RSGCore:Server:OnPlayerLoaded` | server | `` | `server/main.lua` |

```lua
-- from a client script
TriggerServerEvent('RSGCore:Server:OnPlayerLoaded')
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
