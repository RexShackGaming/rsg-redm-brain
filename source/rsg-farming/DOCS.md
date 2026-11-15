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

Support the Project : https://rexshack.tebex.store/
