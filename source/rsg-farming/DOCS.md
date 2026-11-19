# rsg-farming – Docs (v3.1.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Events and commands
5. Database
6. Security
7. Server owner how-tos
8. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `oxmysql`, `rsg-target`, `rsg-gizmo` |
| `shared/config.lua` | Limits, growth, items, crops, well pump |
| `client/client.lua` | Plant props, targets, tending UI, `/myplants` |
| `client/wellpump.lua` | Well pump placement and targets |
| `client/utils.lua` | Client helpers (notify, busy guard, NUI focus + push-to-talk, rsg-gizmo wrapper, props) |
| `server/server.lua` | Plants, growth simulation, tending, harvest |
| `server/wellpump.lua` | Pump storage and filling buckets |
| `server/utils.lua` | Server helpers (items, ownership sync, action timers, database setup, item check) |
| `server/versionchecker.lua` | GitHub version check |
| `install.sql` | Manual database install (only when `AutoDatabase = false`) |
| `html/` | NUI tending panel and plant list |
| `stream/` | Custom weed props (`prop_weed_01`–`06`, textures, ytyp) |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## 2. How it works
- Use a seed item to place a ghost crop with rsg-gizmo (the server re-validates the result with `IsPlacementValid`).
- The server simulates growth: water and fertiliser drain over time, health drops when dry, plants die if neglected.
- Props change by growth stage (model and height offset per stage). Fertilised plants grow faster.
- Tend a plant (rsg-target sphere zone, or `G` when `UseTarget = false`) to water, fertilise, harvest or remove it. The panel shows growth, water, fertiliser, health, status and time to harvest.
- `/myplants` lists your crops nearest first with mini bars; click a far plant for a map route.
- Portable well pumps fill buckets. A full bucket waters `bucketUses` times (default 5) before returning to an empty bucket.
- Seasons: the growth tick multiplies growth by `Config.Seasons.months[os.date('%m')]` (server real time). The server also sends each plant's `eta` (minutes to harvest) so the UI matches.
- Rain: each growth tick reads `GlobalState.rsgWeather.weather` (set by rsg-weather) and adds `Config.RainWater[weather] * minutes` water to every plant. Regional weather translation on clients (snow, sandstorm) is not considered.
- Pests (`Config.Pests.enabled`): infestations are in-memory only (cleared on restart). They slow growth, drain health and are cured with the **Treat** action (consumes `Config.Pests.item`).
- XP: stored in player metadata `farmingxp`; XP is only awarded for actions on your own plants. Levels in `Config.Levels` give `bonusYieldChance` and `extraPlants`. Harvest bonus: plants at or above `Config.Harvest.qualityHealth` add `qualityBonus` to each produce reward (seeds excluded).
- Only the planter can harvest or remove a living plant (`OwnerOnlyHarvest`); anyone can clear dead plants.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `Debug` | `false` | Debug prints |
| `Seasons`, `RainWater`, `Pests`, `TreatTime`, `Harvest`, `XP`, `Levels` | see config | Seasons, rain, pests, harvest quality and farming levels (see README configuration table) |
| `AutoDatabase` | `true` | Create tables on start; `false` = import `install.sql` manually |
| `NoPlantZones` | `{}` | `{ coords = vector3, radius }` areas where planting is blocked (client preview + server check) |
| `AllowPushToTalkWhileOpen` / `PushToTalkControls` | `true` / `{ 0x4BC9DABB }` | Keep push-to-talk working while the tending UI is open |
| `MaxPlantsPerPlayer` | `20` | Active plants per character |
| `MinPlantDistance` | `1.2` | Distance between plants |
| `PlaceMaxDistance` | `6.0` | Gizmo placement range |
| `CollisionModel`, `CollisionProps` | | Invisible blocker for props without collision |
| `InteractDistance` | `1.6` | Tend range |
| `RenderDistance` | `60.0` | Prop spawn/despawn range |
| `OwnerOnlyHarvest` | `true` | Only the planter can harvest/destroy |
| `InteractKey`, `UseTarget`, `TargetRadius`, `TargetIcon` | `G`, `true`, `0.8` | Interaction |
| `TickInterval` / `SaveInterval` | `30` / `120` | Seconds between growth ticks / saves |
| `WaterDecay` / `FertilizerDecay` | `100/60` / `100/90` | Loss per minute |
| `MinWaterToGrow` | `1` | Water needed to grow |
| `FertilizerBoost` | `1.5` | Growth multiplier when fertilised |
| `DryDamage` / `HealthRegen` | `5` / `2` | Health per minute |
| `DeadPlantRemoveTime` | `30` | Minutes before dead plants are removed |
| `WaterItem` / `WaterReturnItem` / `WaterAmount` | `fullbucket` / `bucket` / `100` | Watering |
| `FertilizerItem` / `FertilizerAmount` | `fertilizer` / `100` | Fertilising |
| `PlantTime`, `WaterTime`, `FertilizeTime`, `HarvestTime` | ms | Action durations |
| `Scenarios` | table | Animations per action |
| `Crops` | table | corn, carrot, tomato, potato, tobacco, cotton, sugarcane, wheat, weed |
| `WellPump` | table | `item` (`tool_wellpump`), `prop`, `emptyItem`, `fullItem`, `bucketUses`, `fillTime`, `packTime`, `maxPerPlayer` (2), `minDistance`, `interactDist`, `ownerOnlyPackup` |

Crop entry:
```lua
corn = {
    label = 'Corn', seed = 'seedcorn', growTime = 45, -- minutes to 100%
    stages = { { from = 0, prop = 'crp_cornstalks_bc_sim', zOffset = -1.4 }, { from = 100, prop = 'crp_cornstalks_bc_sim', zOffset = 0.0 } },
    harvest = { { item = 'corn', min = 2, max = 4 }, { item = 'seedcorn', min = 0, max = 1 } },
},
```

## 4. Events and commands
| Name | Side | Notes |
|---|---|---|
| `rsg-farming:client:sync` | client event | `(plants, mineIds)` full plant sync (every growth tick and on login) |
| `rsg-farming:client:plantUpdate` | client event | `(plant)` one plant changed (planted, watered, fertilised) |
| `rsg-farming:client:plantRemove` | client event | `(id)` a plant was harvested, removed or died off |
| `rsg-farming:server:treat` | callback | `(plantId)` treat pests (validated + action timer) |
| `rsg-farming:client:plantMine` | client event | `(id)` sent to the planter so they know they own the new plant |
| `rsg-farming:client:syncPumps` | client event | `(pumps, mineIds)` pump sync |
| `rsg-farming:client:startPlacing` | client event | `(cropKey)` start the placement gizmo |
| `rsg-farming:client:placePump` | client event | Start pump placement |

| Command | Who | What |
|---|---|---|
| `/myplants` | everyone | List your crops |
| `/farmlevel` | everyone | Show your farming level and XP |

Seed items and the pump item are registered as useable items automatically.

## 5. Database
Created automatically on start while `Config.AutoDatabase = true`. To install manually set it to `false` and import `install.sql` (same schema):
- `rsg_farming_plants`: `id`, `citizenid`, `crop`, `x`, `y`, `z`, `h`, `growth`, `water`, `fertilizer`, `health`, `dead`, `dead_time`, `planted_at`.
- `rsg_farming_wellpumps`: `id`, `citizenid`, `x`, `y`, `z`, `h`, `placed_at`.

Plants and pumps survive restarts; dead plants are removed automatically.

## 6. Security
The server owns growth, water, fertiliser and health, checks ownership, distance, item possession and plant limits, and handles harvest rewards (dropping overflow if the inventory is full). Clients only request actions.

- Placement: the client result from rsg-gizmo is untrusted; the server runs `IsPlacementValid`, spacing, per-player limit and `NoPlantZones` checks before taking the seed or pump item.
- Ownership: clients never receive citizenids. Each player is sent the list of plant / pump ids they own and nothing else.
- Timed actions: the server starts a timer at the pre-check and only accepts the action after about 80% of the duration has passed.
- Items: seeds, buckets and pump items are only removed after validation; if a refund or reward no longer fits it is dropped at the player's feet, never lost.
- Other scripts should not write to the `rsg_farming_*` tables directly.

## 7. How-tos
- New crop: add an entry to `Config.Crops`, then add the seed and harvest items.
- Items needed: seeds, `fullbucket`, `bucket`, `fertilizer`, `tool_wellpump` (plus `pesticide` if `Config.Pests.enabled = true`).
- Language: `setr rsg:locale "de"` in server.cfg.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| Plant won't grow | Needs water above `MinWaterToGrow` |
| Plant died | It dried out; dead plants clear after `DeadPlantRemoveTime` |
| Can't harvest | Not your plant while `OwnerOnlyHarvest = true`, or not fully grown |
| Weed props invisible | Keep the `stream/` folder with the resource |
| Pests never go away | Enable `Config.Pests`, add the `pesticide` item, and use the Treat button on the plant |
| Rain doesn't water plants | rsg-weather must be running and report a weather name listed in `Config.RainWater` |
| Pump won't place | Check `maxPerPlayer` and `minDistance` |
| `rsg-gizmo` errors on start | Ensure `rsg-gizmo` starts before `rsg-farming` |
| Console warns about missing items | Add the listed items to `rsg-core/shared/items.lua` |
| Can't plant in a town | A `Config.NoPlantZones` entry covers it |
| Water bucket always has 5 uses | Make `fullbucket` a `unique = true` item so its remaining uses are kept per bucket |

## rsg-skills integration

`Config.Skills = { Enabled, Skill, XPScale, LevelsPerExtraPlant }`. A local `useSkills()` is true when enabled and `GetResourceState('rsg-skills') == 'started'`; the check is made on each call, so a restart of rsg-skills switches modes live.
- `addXP` calls `exports['rsg-skills']:AddXP(src, 'farming', amount * XPScale, 'farming')` and returns early (no metadata XP, no built-in level-up notification).
- `perkOf` returns `bonusYieldChance = GetPerk(src, 'farming', 'extra_yield')` and `extraPlants = floor((level - 1) / LevelsPerExtraPlant)`, which feed the harvest roll and `maxPlantsFor`.
- `/farmlevel` uses `GetProgress` and the locale keys `level_info_skills` and `level_info_skills_next` (added to all locale files).
- The `speed_bonus` perk is not used by this script.


Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-farming 3.2.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `oxmysql`, `rsg-target`, `rsg-gizmo`

### Database

Tables: `rsg_farming_plants`, `rsg_farming_wellpumps`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `install.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Debug` | `false` |  |
| `Config.AutoDatabase` | `true` | create the tables on start; set false and import install.sql manually |
| `Config.MaxPlantsPerPlayer` | `20` | max active plants per character |
| `Config.MinPlantDistance` | `1.2` | min distance between two plants |
| `Config.PlaceMaxDistance` | `6.0` | how far from the player the gizmo can place |
| `Config.NoPlantZones` | `{}` | Config.NoPlantZones = { { coords = vector3(0.0, 0.0, 0.0), radius = 150.0 } } |
| `Config.AllowPushToTalkWhileOpen` | `true` | while the tending UI is open, block game controls but keep push-to-talk working |
| `Config.PushToTalkControls` | `table` |  |
| `Config.CollisionModel` | `'p_emrfencepost02x'` | custom props with no collision: an invisible blocker is spawned with them (and removed with them) |
| `Config.CollisionProps` | `table` |  |
| `Config.InteractDistance` | `1.6` | distance to tend a plant |
| `Config.RenderDistance` | `60.0` | props spawn / despawn distance |
| `Config.OwnerOnlyHarvest` | `true` | only the planter can harvest / destroy |
| `Config.InteractKey` | `0x760A9C6F` | [G] (only used when UseTarget = false) |
| `Config.UseTarget` | `true` | use rsg-target zones on plants instead of the [G] prompt |
| `Config.TargetRadius` | `0.8` | sphere zone radius around each plant |
| `Config.TargetIcon` | `'fa-solid fa-seedling'` |  |
| `Config.TickInterval` | `30` | seconds between growth ticks |
| `Config.SaveInterval` | `120` | seconds between DB saves |
| `Config.WaterDecay` | `100 / 60` | water lost per minute (100 -> 0 in 60 min) |
| `Config.FertilizerDecay` | `100 / 90` | fertiliser lost per minute |
| `Config.MinWaterToGrow` | `1` | plant only grows if water above this |
| `Config.FertilizerBoost` | `1.5` | growth multiplier while fertilised |
| `Config.DryDamage` | `5` | health lost per minute with no water |
| `Config.HealthRegen` | `2` | health gained per minute while watered |
| `Config.DeadPlantRemoveTime` | `30` | minutes before a dead plant is auto-removed |
| `Config.WaterItem` | `'fullbucket'` | consumed when watering |
| `Config.WaterReturnItem` | `'bucket'` | given back after watering (false to disable) |
| `Config.WaterAmount` | `100` | water added (capped at 100) |
| `Config.FertilizerItem` | `'fertilizer'` |  |
| `Config.FertilizerAmount` | `100` |  |
| `Config.Seasons` | `table` |  |
| `Config.RainWater` | `table` |  |
| `Config.Pests` | `table` |  |
| `Config.Harvest` | `table` |  |
| `Config.XP` | `{ enabled = true, plant = 2, water = 1, fertilize = 1, treat = 1, harv` |  |
| `Config.Levels` | `table` |  |
| `Config.PlantTime` | `6000` |  |
| `Config.WaterTime` | `5000` |  |
| `Config.FertilizeTime` | `5000` |  |
| `Config.TreatTime` | `5000` |  |
| `Config.HarvestTime` | `7000` |  |
| `Config.Scenarios` | `table` |  |
| `Config.Crops` | `table` |  |
| `Config.WellPump` | `table` |  |
| `Config.Skills` | `table` | slot. The Config.XP / Config.Levels above are used when rsg-skills is missing or Enabled = false. |
| `Config.Enabled` | `true` |  |
| `Config.Skill` | `'farming'` |  |
| `Config.XPScale` | `1` |  |
| `Config.LevelsPerExtraPlant` | `3` |  |

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-farming:client:sync` | client | `` | `client/client.lua` |
| `rsg-farming:client:plantUpdate` | client | `p` | `client/client.lua` |
| `rsg-farming:client:plantRemove` | client | `id` | `client/client.lua` |
| `rsg-farming:client:plantMine` | client | `id` | `client/client.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |
| `rsg-farming:client:startPlacing` | client | `cropKey` | `client/client.lua` |
| `rsg-farming:client:syncPumps` | client | `` | `client/wellpump.lua` |
| `rsg-farming:client:placePump` | client | `` | `client/wellpump.lua` |

```lua
-- from a server script
TriggerClientEvent('rsg-farming:client:sync', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/myplants` |  | `client/client.lua` |
| `/farmlevel` | Show your farming level | `server/server.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
