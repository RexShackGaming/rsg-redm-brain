# rsg-farming (v3.6.0)

Plant, water, fertilise and harvest crops anywhere in the world, using the water buckets from rsg-wellpump. Built for **RSG-Core (RedM)** with rsg-target and oxmysql. No ox_lib required.

---

## Features

- **Plant anywhere**: use a seed item to place a ghost crop with the standard **rsg-gizmo** placement tool.
- **Live growth simulation on the server**: water and fertiliser drain over time, health drops when the plant is dry, and plants die if neglected.
- **Growth stages**: props change as the crop grows (configurable model and height offset per stage).
- **Fertiliser tiers**: fertilised plants grow faster; `Config.Fertilizers` lets you add better fertilisers or compost that also heals worn-out soil.
- **Tending UI**: a styled RDR2 panel showing growth, water, fertiliser and health bars, status, and the estimated time to harvest.
- **`/myplants` overview**: lists all your crops, nearest first, with mini status bars. Click a far-away plant to get a map route to it.
- **Scarecrow** (`p_scarecrow05x`) cuts the pest chance of plants around it, and **sprinklers** water nearby plants from an rsg-wellpump pump (rsg-wellpump 3.1.0+). Both are placed with rsg-gizmo and packed up again with rsg-target.
- **Well pumps via rsg-wellpump**: place a pump, fill empty buckets and pack it up with the standalone [rsg-wellpump](https://github.com/Rexshack-RedM/rsg-wellpump) resource, shared with other scripts.
- **Limited-use water buckets**: a full bucket waters a set number of times (default 5) before it becomes an empty bucket again. The uses left show in the item description.
- **Ownership**: only the planter can harvest or remove a living plant (configurable). Anyone can clear dead plants.
- **Saved to the database**: plants survive restarts, and dead plants are removed automatically.
- **rsg-target or key prompt**: tend plants through rsg-target zones or a `[G]` prompt.
- **Fully localised**: every player-facing string, including the UI, ships in 11 languages (en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru).
- **Exploit-hardened**: all item changes happen on the server with distance, ownership and inventory-space checks, plus server-side action timers that stop players skipping animations.
- **Optimised**: props are streamed by distance, the database saves in batches (and retries on failure), and player actions send single-plant updates instead of the whole list.
- **Farming XP and levels**: every character earns XP for planting, tending and harvesting. Higher levels bring a bonus-yield chance and more plant slots. Check progress with `/farmlevel`.
- **Harvest quality**: plants harvested at high health give extra produce (seeds are never boosted).
- **Seasons**: growth speed follows the server's real calendar month (slow winters, fast summers), configurable per month and per crop (warm-season crops, hardy crops).
- **Weather effects**: snow, blizzards, hail, sandstorms and heat slow growth, hurt plants or dry them out (rsg-weather). Hardy crops ignore the cold.
- **Soil and crop rotation**: ground tires when the same crop keeps being harvested from it; rotate crops or use compost to heal it. A Soil bar shows in the panel.
- **Owner alerts and map blips**: get told when crops are ready, dry, infested or withered, and see your plants on the map.
- **Farmland and tools (optional)**: restrict planting to farm zones and require a tool such as a hoe.
- **Shared farms (optional)**: gang or job members can tend each other's plants.
- **Crop theft (optional)**: non-owners can steal a share of the harvest; the owner is told, lawmen can be alerted (rsg-lawman) and rsg-reputation is applied.
- **rsg-drugs integration**: weed is an `illegal` crop here. rsg-drugs finds `seedweed` while drying and dries the harvested `weed`, so the two scripts form one loop.
- **Rain**: while rsg-weather reports drizzle, rain, showers or storms, every plant is watered automatically.
- **Pests (optional)**: infestations slow growth and drain health until treated with pesticide. Disabled by default.
- **Private ownership**: citizenids are never sent to clients; each player only receives the ids of the plants they own.
- **Push-to-talk friendly**: voice keeps working while the tending UI is open.
- **No-plant zones**: optionally block planting in areas such as towns (`Config.NoPlantZones`).

---

## Requirements

| Resource | Notes |
|---|---|
| [rsg-core](https://github.com/Rexshack-RedM/rsg-core) | framework |
| [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) | item handling |
| [rsg-target](https://github.com/Rexshack-RedM/rsg-target) | interaction (plant zones) |
| [rsg-gizmo](https://github.com/Rexshack-RedM/rsg-gizmo) | prop placement (crops) |
| [rsg-wellpump](https://github.com/Rexshack-RedM/rsg-wellpump) | well pumps and the water bucket (uses) |
| [oxmysql](https://github.com/Rexshack-RedM/oxmysql) | database |

---

## Installation

1. Put the `rsg-farming` folder in your server's `resources` directory, for example under `resources/[rsg]/`.
2. Add it to `server.cfg` **after** its dependencies:
   ```cfg
   ensure oxmysql
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-target
   ensure rsg-gizmo
   ensure rsg-wellpump
   ensure rsg-farming
   ```
3. **Database**: nothing to import. The tables `rsg_farming_plants`, `rsg_farming_soil` and `rsg_farming_props` are created automatically on first start (a missing `share_key` column is added to older installs). Pumps placed with the old farming pump are imported by rsg-wellpump the first time it starts. To install manually, set `Config.AutoDatabase = false` and import `install.sql`.
4. **Items**: add the items below to `rsg-core/shared/items.lua`. Skip any you already have.
5. Add the item images (`seedcorn.png`, `fullbucket.png` and so on) to `rsg-inventory/html/images/`.
6. Restart the server.

### Items

```lua
-- seeds (usable)
seedcorn    = { name = 'seedcorn',    label = 'Corn Seeds',    weight = 10, type = 'item', image = 'seedcorn.png',    unique = false, useable = true, shouldClose = true, description = 'Plant to grow corn' },
seedcarrot  = { name = 'seedcarrot',  label = 'Carrot Seeds',  weight = 10, type = 'item', image = 'seedcarrot.png',  unique = false, useable = true, shouldClose = true, description = 'Plant to grow carrots' },
seedtomato  = { name = 'seedtomato',  label = 'Tomato Seeds',  weight = 10, type = 'item', image = 'seedtomato.png',  unique = false, useable = true, shouldClose = true, description = 'Plant to grow tomatoes' },
seedpotato  = { name = 'seedpotato',  label = 'Potato Seeds',  weight = 10, type = 'item', image = 'seedpotato.png',  unique = false, useable = true, shouldClose = true, description = 'Plant to grow potatoes' },
seedtobacco = { name = 'seedtobacco', label = 'Tobacco Seeds', weight = 10, type = 'item', image = 'seedtobacco.png', unique = false, useable = true, shouldClose = true, description = 'Plant to grow tobacco' },
seedcotton    = { name = 'seedcotton',    label = 'Cotton Seeds',    weight = 10, type = 'item', image = 'seedcotton.png',    unique = false, useable = true, shouldClose = true, description = 'Plant to grow cotton' },
seedsugarcane = { name = 'seedsugarcane', label = 'Sugarcane Seeds', weight = 10, type = 'item', image = 'seedsugarcane.png', unique = false, useable = true, shouldClose = true, description = 'Plant to grow sugarcane' },
seedwheat     = { name = 'seedwheat',     label = 'Wheat Seeds',     weight = 10, type = 'item', image = 'seedwheat.png',     unique = false, useable = true, shouldClose = true, description = 'Plant to grow wheat' },
seedweed    = { name = 'seedweed',    label = 'Weed Seeds',    weight = 10, type = 'item', image = 'seedweed.png',    unique = false, useable = true, shouldClose = true, description = 'Plant to grow weed' },

-- produce
corn    = { name = 'corn',    label = 'Corn',     weight = 100, type = 'item', image = 'corn.png',    unique = false, useable = false, shouldClose = true, description = 'Fresh corn' },
carrot  = { name = 'carrot',  label = 'Carrot',   weight = 100, type = 'item', image = 'carrot.png',  unique = false, useable = false, shouldClose = true, description = 'Fresh carrot' },
tomato  = { name = 'tomato',  label = 'Tomato',   weight = 100, type = 'item', image = 'tomato.png',  unique = false, useable = false, shouldClose = true, description = 'Fresh tomato' },
potato  = { name = 'potato',  label = 'Potato',   weight = 100, type = 'item', image = 'potato.png',  unique = false, useable = false, shouldClose = true, description = 'Fresh potato' },
tobacco = { name = 'tobacco', label = 'Tobacco',  weight = 100, type = 'item', image = 'tobacco.png', unique = false, useable = false, shouldClose = true, description = 'Tobacco leaves' },
cotton    = { name = 'cotton',    label = 'Cotton',    weight = 100, type = 'item', image = 'cotton.png',    unique = false, useable = false, shouldClose = true, description = 'Raw cotton' },
sugarcane = { name = 'sugarcane', label = 'Sugarcane', weight = 100, type = 'item', image = 'sugarcane.png', unique = false, useable = false, shouldClose = true, description = 'Fresh sugarcane' },
wheat     = { name = 'wheat',     label = 'Wheat',     weight = 100, type = 'item', image = 'wheat.png',     unique = false, useable = false, shouldClose = true, description = 'Harvested wheat' },
weed    = { name = 'weed',    label = 'Weed',     weight = 100, type = 'item', image = 'weed.png',    unique = false, useable = false, shouldClose = true, description = 'Dried weed' },

-- tending
fertilizer    = { name = 'fertilizer',    label = 'Fertiliser',  weight = 500,  type = 'item', image = 'fertilizer.png',    unique = false, useable = false, shouldClose = true, description = 'Makes crops grow faster' },
bucket        = { name = 'bucket',        label = 'Bucket',      weight = 500,  type = 'item', image = 'bucket.png',        unique = false, useable = false, shouldClose = true, description = 'An empty bucket' },
fullbucket    = { name = 'fullbucket',    label = 'Water Bucket',weight = 2000, type = 'item', image = 'fullbucket.png',    unique = true,  useable = false, shouldClose = true, description = 'A bucket full of water' },
```

The `tool_wellpump` item is added with rsg-wellpump.

Optional placeables (not in rsg-core by default; add them to `rsg-core/shared/items.lua`):
```lua
scarecrow = { name = 'scarecrow', label = 'Scarecrow', weight = 3000, type = 'item', image = 'scarecrow.png', unique = false, useable = true, shouldClose = true, description = 'Keeps pests away from nearby crops' },
sprinkler = { name = 'sprinkler', label = 'Sprinkler', weight = 3000, type = 'item', image = 'sprinkler.png', unique = false, useable = true, shouldClose = true, description = 'Waters nearby crops from a well pump' },
```

> **Important:** `fullbucket` must be `unique = true`. Each bucket stores its own uses left in its item data, and stacked buckets would share a single count.

---

## How to use

### Planting
1. Use a seed item from your satchel.
2. Aim where you want the crop. The box is **green** when the spot is valid and **red** when it isn't (too far, too close to another plant, in water, or inside a no-plant zone).
3. Placement uses the standard rsg-gizmo controls (left mouse / Enter to place, right mouse / Backspace to cancel, R to switch mode, mouse wheel / arrows to rotate). See the [rsg-gizmo](https://github.com/Rexshack-RedM/rsg-gizmo) README for the full key list.
4. Your character plants the seeds and one seed is used.

### Tending
- Walk up to a plant and use **rsg-target** (`Tend <crop>`), or press **[G]** if target is disabled.
- The panel shows growth, water, fertiliser and health, plus the time left until harvest.
- **Water**: needs a `fullbucket`. Each watering uses one charge (rsg-wellpump handles this), and the last charge gives you an empty `bucket` back.
- **Fertilise**: needs `fertilizer`. Speeds up growth while it lasts.
- **Harvest**: available at 100% growth. You get produce and a chance of a seed back. If your satchel is full, the plant stays in the ground (anything that no longer fits mid-harvest is dropped at your feet rather than lost).
- **Remove**: digs up your own plant, or clears anyone's dead plant.

A plant only grows while it has water. When it runs dry, it loses health and eventually dies. Dead plants disappear on their own after `Config.DeadPlantRemoveTime` minutes.

### Well pumps
Pumps, filling buckets and packing them up are now handled by rsg-wellpump. See its README.

### Commands

| Command | Description |
|---|---|
| `/farmlevel` | Shows your farming level, rank and XP. |
| `/myplants` | Opens the overview of all your crops (not while mounted, in a vehicle or busy). Click a nearby plant to tend it, or a far one to set a map route. |

---

## Configuration

All settings are in `shared/config.lua`.

### General

| Option | Default | Description |
|---|---|---|
| `Config.Debug` | `false` | Shows target zone debug spheres |
| `Config.Seasons` | enabled | Growth multiplier per real calendar month (`months[1..12]`, 1.0 = normal) |
| `Config.RainWater` | see config | Water per minute added to every plant per rsg-weather weather name; `{}` disables |
| `Config.Pests` | disabled | `enabled`, `item` (`pesticide`), `chancePerTick`, `healthLoss`, `growthPenalty` |
| `Config.TreatTime` | `5000` | Duration of treating pests (ms) |
| `Config.Harvest` | `90` / `1` | `qualityHealth` needed for bonus produce, `qualityBonus` extra amount |
| `Config.XP` | enabled | XP per action: `plant`, `water`, `fertilize`, `treat`, `harvest` (own plants only) |
| `Config.Levels` | 6 ranks | `xp` needed, `label`, `bonusYieldChance` (%), `extraPlants` |
| `Config.AutoDatabase` | `true` | Create the tables on start. Set `false` and import `install.sql` to install manually |
| `Config.MaxPlantsPerPlayer` | `20` | Maximum active plants per character |
| `Config.MinPlantDistance` | `1.2` | Minimum distance between plants (m) |
| `Config.PlaceMaxDistance` | `6.0` | How far from the player you can place (m) |
| `Config.NoPlantZones` | `{}` | Areas where planting is blocked: `{ coords = vector3(...), radius = 150.0 }` (checked on the server too) |
| `Config.AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk working while the tending UI is open (other game controls are blocked) |
| `Config.PushToTalkControls` | `{ 0x4BC9DABB }` | Controls left enabled while the UI is open |
| `Config.InteractDistance` | `1.6` | Distance needed to tend a plant (m) |
| `Config.RenderDistance` | `60.0` | Distance at which props spawn and despawn (m) |
| `Config.SyncDistance` | `250.0` | The server only sends other players' plants within this range (yours are always sent). Keep it well above `RenderDistance` |
| `Config.OwnerOnlyHarvest` | `true` | Only the planter can harvest |
| `Config.UseTarget` | `true` | `true` = rsg-target, `false` = `[G]` prompt |
| `Config.UseKeyMapping` | `true` | `UseTarget = false` only: the prompt key is registered through rsg-core `RegisterKey`, so players can rebind it in the game's key settings. `false` = poll `InteractKey` |
| `Config.InteractKeyName` | `'G'` | Default key name when `UseKeyMapping = true` |
| `Config.InteractKey` | `0x760A9C6F` | Prompt control hash (G), used only when `UseTarget = false` and `UseKeyMapping = false` |
| `Config.ReopenAfterAction` | `true` | Reopen the plant panel after watering, fertilising or treating |
| `Config.TargetRadius` | `0.8` | Target sphere size around each plant |
| `Config.TargetIcon` | `fa-solid fa-seedling` | rsg-target icon |

### Growth simulation

| Option | Default | Description |
|---|---|---|
| `Config.TickInterval` | `30` | Seconds between growth updates |
| `Config.SaveInterval` | `120` | Seconds between database saves |
| `Config.WaterDecay` | `100 / 60` | Water lost per minute (full to empty in 60 min) |
| `Config.FertilizerDecay` | `100 / 90` | Fertiliser lost per minute |
| `Config.MinWaterToGrow` | `1` | The plant only grows above this water level |
| `Config.DryDamage` | `5` | Health lost per minute without water |
| `Config.HealthRegen` | `2` | Health gained per minute while watered |
| `Config.DeadPlantRemoveTime` | `30` | Minutes before a dead plant is removed (`0` = never) |

### Tending items and timings

| Option | Default | Description |
|---|---|---|
| `Config.WaterItem` | `fullbucket` | Item used to water |
| `Config.WaterAmount` | `100` | Water added per use |
| `Config.Fertilizers` | `{ { item = 'fertilizer', amount = 100, boost = 1.5, soil = 0 } }` | Fertilisers, first one the player carries is used. `amount` fertiliser added, `boost` growth multiplier, `soil` fatigue healed (compost). A plant keeps the boost of the last fertiliser applied until the server restarts |
| `Config.PlantTool` | `false` | Item the planter must carry (not consumed), e.g. a hoe. `false` = none |
| `Config.ScenarioCleanup` | `'tracked'` | `'tracked'` removes only props that attached to the player during the action, `'sweep'` is the old "delete any new object nearby" behaviour |
| `Config.ScenarioExitWait` | `1000` | ms to let the exit animation finish before removing props |
| `Config.PlantTime` / `WaterTime` / `FertilizeTime` / `HarvestTime` | ms | Progress bar durations (also enforced by the server) |
| `Config.Scenarios` | table | Animation scenario for each action |

### Farmland, soil, weather and extras

| Option | Default | Description |
|---|---|---|
| `Config.RequirePlantZone` / `Config.PlantZones` | `false` / `{}` | Only allow planting inside these `{ coords, radius }` areas (checked on the server too) |
| `Config.WeatherEffects` | table | Per rsg-weather weather name: `waterDecay`, `growth`, `healthLoss`, `cold` (hardy crops ignore cold effects). `{}` = off |
| `Config.Soil` | table | `enabled`, `cell` (patch size m), `depletion`, `rotateRecovery`, `recoverPerHour`, `maxYieldPenalty`, `warnAt` |
| `Config.Alerts` | all `true` | Owner notifications: `ready`, `thirsty`, `pests`, `dead` (`enabled` = master switch) |
| `Config.Blips` | `enabled`, `blip_ambient_companion`, `0.4` | Map blips for the plants you can tend. Use a sprite name that exists in the game |
| `Config.Sharing` | `enabled = false`, `mode = 'gang'` | Members of the planter's gang (or job) can tend, harvest and remove that plant |
| `Config.Scarecrow` | enabled | `item`, `model` (`p_scarecrow05x`), `radius` (15), `pestMultiplier` (0.25, only matters with `Config.Pests.enabled`), `maxPerPlayer` |
| `Config.Sprinkler` | enabled | `item`, `model` (placeholder prop, change it), `radius` (8), `startBelow`, `waterAdded`, `pumpCost`, `linkDistance`, `maxPerPlayer`. Draws water from rsg-wellpump's `DrawWater` export |
| `Config.Theft` | `enabled = false` | Non-owners may harvest for `yield` of the produce; `notifyOwner`, `lawAlert` (chance, rsg-lawman), `alertGap`, `lawJobType`, `reputation` (rsg-reputation action) |

Crop options: `seasons = { [month] = multiplier }` overrides `Config.Seasons` for that crop, `hardy = true` ignores cold weather effects, `illegal = true` never raises a law alert when stolen.

### Crops

Add or edit crops in `Config.Crops`:

```lua
corn = {
    label = 'Corn',
    seed = 'seedcorn',         -- usable item that plants this crop
    growTime = 45,             -- minutes from 0% to 100% (watered, unfertilised)
    stages = {                 -- prop per growth stage; 'from' = growth % it starts at
        { from = 0,   prop = 'crp_cornstalks_bc_sim', zOffset = -1.4 },
        { from = 35,  prop = 'crp_cornstalks_bc_sim', zOffset = -0.8 },
        { from = 70,  prop = 'crp_cornstalks_bc_sim', zOffset = -0.3 },
        { from = 100, prop = 'crp_cornstalks_bc_sim', zOffset = 0.0 },
    },
    harvest = {                -- items given on harvest (random min to max)
        { item = 'corn',     min = 2, max = 4 },
        { item = 'seedcorn', min = 0, max = 1 },
    },
},
```

Seed items are registered as usable automatically, so there's no extra code to write. Remember to add any new items to `rsg-core/shared/items.lua`.

### Well pump

The pump options (items, uses, fill time, limits) moved to rsg-wellpump's `shared/config.lua`.

---

## Localisation

All text, including the UI, is in `locales/`. Included languages: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Locales are loaded by rsg-core.

Set the language in your server config:
```cfg
setr rsg:locale fr
```
To add a language, copy `en.json`, translate the values and keep the keys and `%s` placeholders.

---

## Custom props

The `stream/` folder contains custom weed models (`prop_weed_01`–`06`), loaded through `prop_weed_ytyp.ytyp`. You can use them in any crop's `stages`.

---

## File structure

```
rsg-farming/
├── client/
│   ├── utils.lua       -- shared client helpers (notify, scenarios, props)
│   └── client.lua      -- plants, UI, tending
├── server/
│   ├── utils.lua       -- shared server helpers (items, validation, action timers)
│   ├── server.lua      -- plants, growth simulation, database
│   └── versionchecker.lua
├── shared/config.lua
├── shared/zones.lua    -- zone checks used by client and server
├── install.sql         -- manual database install (when AutoDatabase = false)
├── locales/           -- en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru
├── html/               -- NUI (index.html, style.css, script.js)
├── stream/             -- custom weed props
└── fxmanifest.lua
```

---

## Changelog

### 3.6.0
- New: scarecrow and sprinkler placeables (rsg-gizmo placement, rsg-target pack up); sprinklers draw from rsg-wellpump 3.1.0+. New table `rsg_farming_props`.

### 3.5.0
- New: owner alerts, map blips, per-crop seasons, weather effects, farmland zones and tool, shared farms, crop theft (rsg-lawman / rsg-reputation), soil fatigue and compost, fertiliser tiers.
- Changed: batched saves, tracked scenario clean-up, `[G]` prompt shows the configured key, `Config.FertilizerItem` / `FertilizerAmount` / `FertilizerBoost` replaced by `Config.Fertilizers`.
- New table `rsg_farming_soil` and column `rsg_farming_plants.share_key` (created automatically); 11 new locale keys in all 11 languages.

### 3.4.0
- Security: players only receive their own plants plus plants within `Config.SyncDistance`, so plant locations can't be dumped from the client; planting can't be spammed by skipping the animation.
- Performance: smaller, per-player syncs; no per-frame polling for the `[G]` prompt; pests no longer force a save every tick.
- UX: the plant panel reopens after tending (`Config.ReopenAfterAction`); the prompt key is rebindable (`Config.UseKeyMapping`).
- New locale keys `key_tend` and `cmd_farmlevel` in all 11 languages.
**3.2.0**
- Optional rsg-skills integration: rsg-skills replaces the built-in farming XP when started (`Config.Skills`); new locale keys `level_info_skills`, `level_info_skills_next`.

### 3.1.0
- New: farming XP and levels (`/farmlevel`), harvest quality bonus, seasonal growth, rain auto-watering (rsg-weather), optional pests with a Treat button (needs a `pesticide` item).
- The "time to harvest" estimate is now worked out by the server so it includes season, fertiliser and pests.
- Placement now uses **rsg-gizmo** (new dependency); the built-in placement code was removed.
- Security: citizenids are no longer broadcast to every client (ownership is sent per player); server checks placement with `IsPlacementValid`; plant / pump inserts are guarded so a database error can no longer lock a player out or lose a seed; the pump item and empty buckets are dropped at your feet instead of being lost if your satchel is full.
- Performance: watering, fertilising, planting and removing now send a single-plant update instead of re-sending every plant to every player; unchanged plants are no longer re-saved; failed saves are retried.
- UX/stability: the busy state can no longer get stuck after an error; the NUI cursor can no longer get stuck when a listed plant disappears; push-to-talk works while the tending UI is open.
- Added `Config.AutoDatabase` with `install.sql`, `Config.NoPlantZones`, `Config.AllowPushToTalkWhileOpen` / `Config.PushToTalkControls`, and a start-up warning for items missing from rsg-core.
- Removed the unused `place_help` locale key and added `place_blocked_zone` in all 10 languages.

### 3.0.4
- Removed the ox_lib dependency: locales, notify, callbacks, progress bars and text UI now use rsg-core.
- Switched from ox_target to rsg-target.
- Fixed duplicate item pop-ups (rsg-inventory already shows them).
- Fixed refilled water buckets using the legacy `AddItem` argument order.
- Harvest now checks that all rewards fit together (combined weight and free slots) before the plant is removed.
- Harvest / empty-bucket items that no longer fit are dropped instead of lost.
- Plants and pumps are despawned on character logout; `/myplants` blocked while mounted or busy.
- Added de, el, es, fr, ja, nl, pl, pt-br, ro and ru locales.

---

## Credits

Rexshack-RedM: RSG Framework (RexShack)

## rsg-skills integration

Optional. With `rsg-skills` started, it becomes the farming XP source (`Config.Skills`):
- XP for planting, watering, fertilising, treating and harvesting goes to the shared `farming` skill;
- the skill's `extra_yield` perk is the chance of bonus produce on harvest;
- every `LevelsPerExtraPlant` levels above 1 adds one plant slot;
- `/farmlevel` shows the rsg-skills level and XP.

Without rsg-skills (or with `Config.Skills.Enabled = false`) the built-in `Config.XP` and `Config.Levels` are used as before. Existing farming XP in character metadata is not carried over to rsg-skills.


Support the Project : https://rexshack.tebex.store/
