# rsg-farming

Plant, water, fertilise and harvest crops anywhere in the world, with portable well pumps to fill your water buckets. Built for **RSG-Core (RedM)** with ox_lib, ox_target and oxmysql.

---

## Features

- **Plant anywhere**: use a seed item to place a ghost crop with a placement gizmo (rotate, raise or lower, valid/invalid ring).
- **Live growth simulation on the server**: water and fertiliser drain over time, health drops when the plant is dry, and plants die if neglected.
- **Growth stages**: props change as the crop grows (configurable model and height offset per stage).
- **Fertiliser boost**: fertilised plants grow faster.
- **Tending UI**: a styled RDR2 panel showing growth, water, fertiliser and health bars, status, and the estimated time to harvest.
- **`/myplants` overview**: lists all your crops, nearest first, with mini status bars. Click a far-away plant to get a map route to it.
- **Portable well pumps**: place a pump, fill empty buckets, and pack it back up later.
- **Limited-use water buckets**: a full bucket waters a set number of times (default 5) before it becomes an empty bucket again. The uses left show in the item description.
- **Ownership**: only the planter can harvest or remove a living plant (configurable). Anyone can clear dead plants.
- **Saved to the database**: plants and pumps survive restarts, and dead plants are removed automatically.
- **ox_target or key prompt**: tend plants through ox_target zones or a `[G]` prompt.
- **Fully localised**: every player-facing string, including the UI, is in `locales/en.json`.
- **Exploit-hardened**: all item changes happen on the server with distance, ownership and inventory-space checks, plus server-side action timers that stop players skipping animations.
- **Optimised**: props are streamed by distance, and the database saves in batches.

---

## Requirements

| Resource | Notes |
|---|---|
| [rsg-core](https://github.com/Rexshack-RedM/rsg-core) | framework |
| [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) | item handling |
| [ox_lib](https://github.com/Rexshack-RedM/ox_lib) | callbacks, notify, progress bars, locales |
| [ox_target](https://github.com/Rexshack-RedM/ox_target) | interaction (optional if `Config.UseTarget = false`) |
| [oxmysql](https://github.com/Rexshack-RedM/oxmysql) | database |

---

## Installation

1. Put the `rsg-farming` folder in your server's `resources` directory, for example under `resources/[rsg]/`.
2. Add it to `server.cfg` **after** its dependencies:
   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure rsg-core
   ensure rsg-inventory
   ensure ox_target
   ensure rsg-farming
   ```
3. **Database**: nothing to import. The tables `rsg_farming_plants` and `rsg_farming_wellpumps` are created automatically on first start.
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
seedweed    = { name = 'seedweed',    label = 'Weed Seeds',    weight = 10, type = 'item', image = 'seedweed.png',    unique = false, useable = true, shouldClose = true, description = 'Plant to grow weed' },

-- produce
corn    = { name = 'corn',    label = 'Corn',     weight = 100, type = 'item', image = 'corn.png',    unique = false, useable = false, shouldClose = true, description = 'Fresh corn' },
carrot  = { name = 'carrot',  label = 'Carrot',   weight = 100, type = 'item', image = 'carrot.png',  unique = false, useable = false, shouldClose = true, description = 'Fresh carrot' },
tomato  = { name = 'tomato',  label = 'Tomato',   weight = 100, type = 'item', image = 'tomato.png',  unique = false, useable = false, shouldClose = true, description = 'Fresh tomato' },
potato  = { name = 'potato',  label = 'Potato',   weight = 100, type = 'item', image = 'potato.png',  unique = false, useable = false, shouldClose = true, description = 'Fresh potato' },
tobacco = { name = 'tobacco', label = 'Tobacco',  weight = 100, type = 'item', image = 'tobacco.png', unique = false, useable = false, shouldClose = true, description = 'Tobacco leaves' },
weed    = { name = 'weed',    label = 'Weed',     weight = 100, type = 'item', image = 'weed.png',    unique = false, useable = false, shouldClose = true, description = 'Dried weed' },

-- tending
fertilizer    = { name = 'fertilizer',    label = 'Fertiliser',  weight = 500,  type = 'item', image = 'fertilizer.png',    unique = false, useable = false, shouldClose = true, description = 'Makes crops grow faster' },
bucket        = { name = 'bucket',        label = 'Bucket',      weight = 500,  type = 'item', image = 'bucket.png',        unique = false, useable = false, shouldClose = true, description = 'An empty bucket' },
fullbucket    = { name = 'fullbucket',    label = 'Water Bucket',weight = 2000, type = 'item', image = 'fullbucket.png',    unique = true,  useable = false, shouldClose = true, description = 'A bucket full of water' },
tool_wellpump = { name = 'tool_wellpump', label = 'Well Pump',   weight = 5000, type = 'item', image = 'tool_wellpump.png', unique = false, useable = true,  shouldClose = true, description = 'A portable well pump' },
```

> **Important:** `fullbucket` must be `unique = true`. Each bucket stores its own uses left in its item data, and stacked buckets would share a single count.

---

## How to use

### Planting
1. Use a seed item from your satchel.
2. Aim where you want the crop. The ring is **green** when the spot is valid and **red** when it isn't (too far, or too close to another plant).
3. Controls while placing:

| Key | Action |
|---|---|
| Left mouse | Place |
| Q / E | Rotate |
| Arrow Up / Down | Raise / lower |
| Right mouse / Backspace | Cancel |

4. Your character plants the seeds and one seed is used.

### Tending
- Walk up to a plant and use **ox_target** (`Tend <crop>`), or press **[G]** if target is disabled.
- The panel shows growth, water, fertiliser and health, plus the time left until harvest.
- **Water**: needs a `fullbucket`. Each watering uses one charge, and the last charge gives you an empty `bucket` back.
- **Fertilise**: needs `fertilizer`. Speeds up growth while it lasts.
- **Harvest**: available at 100% growth. You get produce and a chance of a seed back. If your satchel is full, the plant stays in the ground.
- **Remove**: digs up your own plant, or clears anyone's dead plant.

A plant only grows while it has water. When it runs dry, it loses health and eventually dies. Dead plants disappear on their own after `Config.DeadPlantRemoveTime` minutes.

### Well pumps
1. Use the `tool_wellpump` item and place it with the same gizmo as crops.
2. Target the pump and choose **Fill Bucket** to turn an empty `bucket` into a `fullbucket` with full charges.
3. Choose **Pack Up Well Pump** to get the item back (owner only by default).

### Commands

| Command | Description |
|---|---|
| `/myplants` | Opens the overview of all your crops. Click a nearby plant to tend it, or a far one to set a map route. |

---

## Configuration

All settings are in `shared/config.lua`.

### General

| Option | Default | Description |
|---|---|---|
| `Config.Debug` | `false` | Shows target zone debug spheres |
| `Config.MaxPlantsPerPlayer` | `20` | Maximum active plants per character |
| `Config.MinPlantDistance` | `1.2` | Minimum distance between plants (m) |
| `Config.PlaceMaxDistance` | `6.0` | How far from the player you can place (m) |
| `Config.InteractDistance` | `1.6` | Distance needed to tend a plant (m) |
| `Config.RenderDistance` | `60.0` | Distance at which props spawn and despawn (m) |
| `Config.OwnerOnlyHarvest` | `true` | Only the planter can harvest |
| `Config.UseTarget` | `true` | `true` = ox_target, `false` = `[G]` prompt |
| `Config.InteractKey` | `0x760A9C6F` | Prompt key (G), used only when `UseTarget = false` |
| `Config.TargetRadius` | `0.8` | Target sphere size around each plant |
| `Config.TargetIcon` | `fa-solid fa-seedling` | ox_target icon |

### Growth simulation

| Option | Default | Description |
|---|---|---|
| `Config.TickInterval` | `30` | Seconds between growth updates |
| `Config.SaveInterval` | `120` | Seconds between database saves |
| `Config.WaterDecay` | `100 / 60` | Water lost per minute (full to empty in 60 min) |
| `Config.FertilizerDecay` | `100 / 90` | Fertiliser lost per minute |
| `Config.MinWaterToGrow` | `1` | The plant only grows above this water level |
| `Config.FertilizerBoost` | `1.5` | Growth multiplier while fertilised |
| `Config.DryDamage` | `5` | Health lost per minute without water |
| `Config.HealthRegen` | `2` | Health gained per minute while watered |
| `Config.DeadPlantRemoveTime` | `30` | Minutes before a dead plant is removed (`0` = never) |

### Tending items and timings

| Option | Default | Description |
|---|---|---|
| `Config.WaterItem` | `fullbucket` | Item used to water |
| `Config.WaterReturnItem` | `bucket` | Item returned when a bucket runs out (`false` = none) |
| `Config.WaterAmount` | `100` | Water added per use |
| `Config.FertilizerItem` | `fertilizer` | Item used to fertilise |
| `Config.FertilizerAmount` | `100` | Fertiliser added per use |
| `Config.PlantTime` / `WaterTime` / `FertilizeTime` / `HarvestTime` | ms | Progress bar durations (also enforced by the server) |
| `Config.Scenarios` | table | Animation scenario for each action |

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

| Option | Default | Description |
|---|---|---|
| `item` | `tool_wellpump` | Usable item that places the pump |
| `prop` | `p_wellpumpnbx01x` | Pump model |
| `emptyItem` | `bucket` | Item needed to fill |
| `fullItem` | `fullbucket` | Item given after filling |
| `bucketUses` | `5` | Waterings per full bucket |
| `fillTime` / `packTime` | `6000` / `4000` | Durations (ms, enforced by the server) |
| `fillScenario` / `packScenario` | scenarios | Animations |
| `maxPerPlayer` | `2` | Maximum pumps per character |
| `minDistance` | `2.0` | Minimum distance between pumps (m) |
| `interactDist` | `2.0` | Target distance (m) |
| `ownerOnlyPackup` | `true` | Only the owner can pack it up |

---

## Localisation

All text, including the UI, is in `locales/en.json`. To translate:

1. Copy `en.json` to, for example, `fr.json` and translate the values. Keep the keys and the `%s` placeholders.
2. Set the language in your server config:
   ```cfg
   setr ox:locale fr
   ```

---

## Custom props

The `stream/` folder contains custom weed models (`prop_weed_01`–`06`), loaded through `prop_weed_ytyp.ytyp`. You can use them in any crop's `stages`.

---

## File structure

```
rsg-farming/
├── client/
│   ├── placement.lua   -- placement gizmo
│   ├── utils.lua       -- shared client helpers (notify, scenarios, props)
│   ├── client.lua      -- plants, UI, tending
│   └── wellpump.lua    -- well pumps
├── server/
│   ├── utils.lua       -- shared server helpers (items, validation, action timers)
│   ├── server.lua      -- plants, growth simulation, database
│   ├── wellpump.lua    -- well pumps
│   └── versionchecker.lua
├── shared/config.lua
├── locales/en.json
├── html/               -- NUI (index.html, style.css, script.js)
├── stream/             -- custom weed props
└── fxmanifest.lua
```

---

## Credits

Rexshack-RedM: RSG Framework (RexShack)
