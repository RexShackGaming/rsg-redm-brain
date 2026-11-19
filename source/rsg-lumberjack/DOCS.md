# rsg-lumberjack — Developer Docs

Version 3.3.0. No ox_lib dependency — uses rsg-core and rsg-target only.

## Dependencies
`rsg-core`, `rsg-target`, `rsg-inventory`, `oxmysql`.

## Framework functions used
| Purpose | Call |
|---|---|
| Locales | `@rsg-core/shared/locale.lua` + `locale('key', ...)` (language from `setr rsg:locale <lang>`) |
| Client notify | `RSGCore.Functions.Notify({ title, description, type, duration })` |
| Server notify | `TriggerClientEvent('RSGCore:Client:Notify', src, data)` |
| Progress bars | `RSGCore.Functions.ProgressBar({ duration, label, canCancel, disable, anim, prop })` |
| Anim loading | `RSGCore.Functions.RequestAnimDict` / `RequestAnimSet` |
| Text UI (sell zone) | `exports['rsg-core']:DrawText(text, 'left')` / `HideText()` |
| Targeting | `exports['rsg-target']:addModel / addLocalEntity / removeLocalEntity` |
| Callbacks | `RSGCore.Functions.CreateCallback('rsg-lumberjack:server:requestChop', ...)` |

## Server events (client → server)
| Event | Args | Notes |
|---|---|---|
| `rsg-lumberjack:server:requestSync` | — | Rate-limited full state sync |
| `rsg-lumberjack:server:cancelChop` | — | Clears pending chop |
| `rsg-lumberjack:server:completeChop` | kind, targetId | Re-validated against pending action + elapsed time |
| `rsg-lumberjack:server:dropLog` | — | Position from server ped |
| `rsg-lumberjack:server:pickupLog` | logId | |
| `rsg-lumberjack:server:pickupWood` | woodId | Claimed before reward |
| `rsg-lumberjack:server:plantTree` | pos, heading | Range-checked |
| `rsg-lumberjack:server:waterTree` | id | |
| `rsg-lumberjack:server:addLogToWagon` | wagonNetId | |
| `rsg-lumberjack:server:removeLogFromWagon` | wagonNetId | |
| `rsg-lumberjack:server:sellWagonLoad` | — | Wagon/price resolved server-side |

## Callback
`rsg-lumberjack:server:requestChop(kind, targetId)` → `{ ok, duration, reason, args }`.

## Database
`rsg_lumberjack_trees` — auto-created on start; `install/database.sql` for manual install.

## Config
See `shared/config.lua`: `Chopping`, `Planting`, `Items`, `Models`, `Carry`, `Wagon`, `WagonSellLocations`, `Trees`.

## Changelog
- **3.3.0** — Optional rsg-skills integration (`Config.Skills`): lumberjack XP and `extra_yield` perk on wood pickup.
- **3.2.0** — Migrated off ox_lib to rsg-core (locale, notify, progress bar, anim loading, text UI); ox_target → rsg-target. Progress `disable.car` → `disable.mount`.

## rsg-skills integration

`Config.Skills = { Enabled, Skill, WoodXP, ExtraYield }`. In `rsg-lumberjack:server:pickupWood`, after the piece is claimed and added, the server calls `AddXP(src, 'lumberjack', WoodXP, ...)`. When `ExtraYield` is on, it rolls `math.random(100) <= GetPerk(src, 'lumberjack', 'extra_yield')` and adds one more piece when `CanAddItem` allows it. Everything runs on the server; skipped when rsg-skills is not started.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-lumberjack 3.3.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-target`, `rsg-inventory`, `oxmysql`

### Database

Tables: `rsg_lumberjack_trees`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `install/database.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.Debug` | `false` | Debug Settings |
| `Config.Chopping` | `table` | ============================================================================ |
| `Config.RequireAxe` | `true` |  |
| `Config.AxeItem` | `'axe'` |  |
| `Config.AxeBreakChance` | `10` |  |
| `Config.TreeChopDuration` | `7000` |  |
| `Config.LogChopDuration` | `5000` |  |
| `Config.ChopCooldownMs` | `10000` |  |
| `Config.InteractDistance` | `1.5` |  |
| `Config.ServerDistance` | `4.0` |  |
| `Config.RaycastDistance` | `3.0` |  |
| `Config.ActionTimeoutMs` | `20000` |  |
| `Config.Planting` | `table` | ============================================================================ |
| `Config.SeedItem` | `'tree_seeds'` |  |
| `Config.WaterItem` | `'fullbucket'` |  |
| `Config.RequireWater` | `true` |  |
| `Config.MaxTreesPerPlayer` | `10` |  |
| `Config.MinPlantDistance` | `3.0` |  |
| `Config.PlantDuration` | `5000` |  |
| `Config.WaterDuration` | `8000` |  |
| `Config.RenderDistance` | `40.0` |  |
| `Config.ProgressBarDistance` | `12.0` |  |
| `Config.GrowthTickSeconds` | `10` |  |
| `Config.GrowthDurations` | `table` |  |
| `Config.StageModels` | `table` |  |
| `Config.Items` | `table` | ============================================================================ |
| `Config.Wood` | `'resource_wood'` |  |
| `Config.WoodAmountFromLog` | `4` |  |
| `Config.SpawnRadius` | `3.0` |  |
| `Config.GroundDespawnMinutes` | `30` |  |
| `Config.Models` | `table` |  |
| `Config.GroundLog` | ``p_cedar_log_06x`` |  |
| `Config.WoodProp` | ``p_cs_woodpile01x`` |  |
| `Config.CarryLog` | ``p_cedar_log_06x`` |  |
| `Config.Carry` | `table` | Carry settings |
| `Config.AnimDict` | `'amb_wander@code_human_hay_bale_wander@male_a@base'` |  |
| `Config.AnimClip` | `'base'` |  |
| `Config.AnimFlag` | `25` |  |
| `Config.MoveClipset` | `''` |  |
| `Config.AttachBox` | `table` |  |
| `Config.Wagon` | `table` | ============================================================================ |
| `Config.Model` | ``LOGWAGON`` |  |
| `Config.MaxLogsOnWagon` | `5` |  |
| `Config.LogStackModel` | ``p_cedar_log_06x`` |  |
| `Config.LoadDistance` | `4.0` |  |
| `Config.LogPositions` | `table` |  |
| `Config.WagonSellLocations` | `table` | ============================================================================ |
| `Config.Trees` | `table` | ============================================================================ |
| `Config.Skills` | `table` | rsg-skills integration (optional). Needs the rsg-skills resource; does nothing when it is not started. |
| `Config.Enabled` | `true` |  |
| `Config.Skill` | `'lumberjack'` |  |
| `Config.WoodXP` | `5` |  |
| `Config.ExtraYield` | `true` |  |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-lumberjack:server:requestChop` | server | `source, cb, kind, targetId` | `server/main.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-lumberjack:server:requestChop', function(result)
    -- use result
end, kind, targetId)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/main.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/main.lua` |
| `rsg-lumberjack:client:startCarrying` | client | `` | `client/main.lua` |
| `rsg-lumberjack:client:stopCarrying` | client | `` | `client/main.lua` |
| `rsg-lumberjack:client:syncGroundLogs` | client | `logs` | `client/main.lua` |
| `rsg-lumberjack:client:addGroundLog` | client | `` | `client/main.lua` |
| `rsg-lumberjack:client:removeGroundLog` | client | `` | `client/main.lua` |
| `rsg-lumberjack:client:syncWoodPieces` | client | `woods` | `client/main.lua` |
| `rsg-lumberjack:client:addWoodPiece` | client | `` | `client/main.lua` |
| `rsg-lumberjack:client:removeWoodPiece` | client | `` | `client/main.lua` |
| `rsg-lumberjack:client:useSeed` | client | `` | `client/main.lua` |
| `rsg-lumberjack:client:useWater` | client | `` | `client/main.lua` |
| `rsg-lumberjack:client:updateTreeVisual` | client | `tree` | `client/main.lua` |
| `rsg-lumberjack:client:setTrees` | client | `list` | `client/main.lua` |
| `rsg-lumberjack:client:removeTree` | client | `id` | `client/main.lua` |
| `rsg-lumberjack:server:requestSync` | server | `` | `server/main.lua` |
| `rsg-lumberjack:server:cancelChop` | server | `` | `server/main.lua` |
| `rsg-lumberjack:server:completeChop` | server | `kind, targetId` | `server/main.lua` |
| `rsg-lumberjack:server:dropLog` | server | `` | `server/main.lua` |
| `rsg-lumberjack:server:pickupLog` | server | `logId` | `server/main.lua` |
| `rsg-lumberjack:server:pickupWood` | server | `woodId` | `server/main.lua` |
| `rsg-lumberjack:server:plantTree` | server | `pos, heading` | `server/main.lua` |
| `rsg-lumberjack:server:waterTree` | server | `id` | `server/main.lua` |
| `rsg-lumberjack:server:addLogToWagon` | server | `wagonNetId` | `server/main.lua` |
| `rsg-lumberjack:server:removeLogFromWagon` | server | `wagonNetId` | `server/main.lua` |
| `rsg-lumberjack:server:sellWagonLoad` | server | `` | `server/main.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-lumberjack:server:requestSync')
-- from a server script
TriggerClientEvent('RSGCore:Client:OnPlayerLoaded', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/spawnwagon` |  | `client/main.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
