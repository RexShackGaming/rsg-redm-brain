# rsg-hunting

A hunting, trapper-vending, and butcher system for the RSG Framework (RedM). Players can hunt and skin animals for crafting materials, sell those materials to trapper vendors scattered across the map, or sell whole carcasses directly to butchers for cash and meat.

## Table of Contents

1. [Features](#features)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Events & API](#events--api)
5. [Troubleshooting](#troubleshooting)

---

## Features

### Hunting & Skinning
- Hooks into the game's native skinning animation/event system — no custom minigame required
- Awards up to 5 configurable reward items per animal (pelts, hides, hearts, horns, feathers, etc.) based on skinning outcome
- 90+ preconfigured animal entries, matched by model hash
- Optional automatic carcass deletion after skinning (`Config.DeleteCarcass`)
- Verifies the player who triggered the event is the one who receives rewards

### Trapper Vendors
- 5 preconfigured trapper vendor locations with map blips
- Sell-only trappers with a custom NUI sell screen (RDR2 leather & gold style)
  - Shows every item the trapper buys, with images, current price and how many the player owns
  - Search and "owned only" filter; owned items are listed first
  - Pick a quantity per item (− / + / Max or type it) and add it to a basket
  - **Add All Owned** fills the basket with every accepted item in one click
  - Edit or remove basket lines, then confirm to sell the whole basket in one transaction
  - Pays the exact amount (rounded to the cent) — no whole-dollar rounding
  - Closes automatically if the player walks away or dies; `Esc` closes it
- Stock-based dynamic pricing (`stockBasedPrice`): the trapper pays 1.25x below 50% of `maxStock` and 1.5x below 25%
- Stock builds up as players sell; saved to `vendor_stock.json`
- Server-side validation: distance check, per-vendor accepted items, ownership check, cooldown, and rollback if an item removal fails
- All notifications via `ox_lib` notify
- Per-vendor item catalogs — over 90 sellable resource items (skins, pelts, hides, horns, feathers, beaks, hearts, meat, etc.)

### Butcher Shops
- 12 preconfigured butcher locations across the map with map blips
- Sell whole hunted animals directly for cash, with quality-based reward multipliers (poor / good / perfect)
- 70+ supported animal species in the sellable-animal list, including legendary variants
- Keybind or `ox_target` interaction support (configurable)
- Dynamic NPC spawning/despawning based on player distance, with fade in/out animations
- Anti-spam cooldown protection on both client and server
- Optional webhook/log integration via `rsg-log` for sale transactions
- Debug mode with performance stats (cache hit rate, rewards/minute, active players)

### General
- Locale file for all UI strings (`locales/en.json`) — easy to translate
- Version checker that pings GitHub on resource start to confirm you're running the latest release

---

## Installation

### Prerequisites
- `rsg-core`
- `rsg-inventory`
- `ox_lib`
- `ox_target` (optional — only required if `Config.EnableTarget` is `true`)

### Steps

1. Extract the `rsg-hunting` folder into your server's `resources` directory.
2. Add the item definitions in `installation/shared_items.lua` to your `rsg-core` (or `rsg-inventory`) shared items file, and copy the images from `installation/images/` into your inventory's image folder (see `Config.Image`).
3. Add to your `server.cfg`:
   ```
   ensure rsg-core
   ensure ox_lib
   ensure ox_target
   ensure rsg-inventory
   ensure rsg-hunting
   ```
4. Start (or restart) your server and check the console for:
   - `[rsg-hunting] Butcher server cache initialized with XX animals`
   - No errors from the version checker
5. Visit a trapper or butcher location in-game and confirm the blip, target interaction, and sell screen / menu all appear.

### Database Setup (optional)
If `Config.PersistStock` is enabled, the butcher shop's stock is saved through `rsg-inventory`'s shop system — make sure your database is configured as per `rsg-inventory`'s own setup instructions.

---

## Configuration

All configuration lives in `config.lua`.

### General Hunting Settings
```lua
Config.DeleteCarcass = true                          -- remove the carcass after skinning
Config.Image = 'rsg-inventory/html/images/'          -- where item images are stored
Config.BlipSprite = 'blip_shop_animal_trapper'       -- trapper vendor blip sprite
Config.BlipScale = 0.2
```

### Trapper Vendors (`Config.Vendors`)
Each entry defines a trapper NPC location and the items it buys:
```lua
{
    pedModel = 'u_m_m_sdtrapper_01',
    coords = vector4(-333.9737, 773.49157, 116.22194, 111.8759),
    blipname = 'Valentine Trapper',
    blipcoords = vector3(-333.9737, 773.49157, 116.22194),
    showblip = true,
    items = {
        { name = 'resource_skin_bear', label = 'Bear Skin', sellPrice = 1.25, maxStock = 100, canSell = true, stockBasedPrice = true },
        -- ...
    }
}
```
| Field | Description |
|---|---|
| `name` | Item name (must exist in your shared items) |
| `label` | Name shown in the sell screen |
| `sellPrice` | Base price the trapper pays per item |
| `maxStock` | Used for stock-based pricing ratios |
| `canSell` | `true` to show the item in the sell screen |
| `stockBasedPrice` | Raise the price when the trapper's stock is low |

Add or remove vendors, or edit `items` per vendor, to change what each trapper buys. Item images are loaded from `Config.Image` using the item's `image` from shared items (falls back to `<name>.png`).

**Resetting trapper stock:** run `resetvendorstock` from the server console to reset all trapper stock to 0.

### Huntable Animals (`Config.Animals`)
Each entry maps a ped model hash to up to 5 reward items awarded on a successful skin:
```lua
{
    modelhash = `a_c_bear_01`,
    skinable = true,
    rewarditem1 = 'resource_skin_bear',
    rewarditem2 = 'heart_bear',
    rewarditem3 = 'resource_tooth_bear',
    rewarditem4 = nil,
    rewarditem5 = nil,
},
```

### Butcher Shop Settings
```lua
Config.ButcherShopItems = {
    { name = 'weapon_melee_knife', amount = 100, price = 5 },
}
Config.PersistStock = true   -- persist butcher shop stock to database
```

### Butcher Quality Multipliers
```lua
Config.PoorMultiplier = 1      -- 1x base reward
Config.GoodMultiplier = 2      -- 2x base reward
Config.PerfectMultiplier = 3   -- 3x base reward
```
Quality mapping: `0` → poor, `1` → good, `2` or `-1` → perfect (read from `GetPedQuality`).

### Butcher Gameplay Settings
```lua
Config.Debug = false           -- enable debug logging
Config.SellTime = 10000        -- time to sell an animal (ms)
Config.KeyBind = 'J'           -- interaction key (used when EnableTarget is false)
Config.EnableTarget = true     -- use ox_target instead of a keybind prompt
```

### Butcher Performance Tuning
```lua
Config.Performance = {
    NpcDistanceCheck = 3000,       -- how often to check NPC distances (ms)
    NpcCoordsUpdate = 2000,        -- how often to update player coords (ms)
    NpcSpawnDistance = 20.0,       -- distance to spawn/despawn NPCs
    NpcFadeSpeed = 40,             -- fade animation speed (ms between steps)
    ProcessCooldown = 1000,        -- client-side cooldown between sales (ms)
    BlipUpdateInterval = 5000,
    CacheSize = 500,
    ServerProcessCooldown = 2000,  -- server-side cooldown per player (ms)
    LoggingEnabled = true,         -- enable transaction logging via rsg-log
    CleanupInterval = 300000,      -- memory cleanup interval (ms)
    MaxPlayerCooldowns = 100,
}
```

### Butcher Webhook / Logging
```lua
Config.WebhookName = 'rsghunting'
Config.WebhookTitle = 'RSG Hunting - Butcher'
Config.WebhookColour = 'default'
```
Sale transactions are sent to `rsg-log:server:CreateLog` when `Config.Performance.LoggingEnabled` is `true`. Point these values at whatever webhook name/title your `rsg-log` setup expects.

### Butcher Blip & NPCs
```lua
Config.Blip = {
    blipName = 'Butcher Shop',
    blipSprite = 'blip_shop_butcher',
    blipScale = 0.2
}
Config.DistanceSpawn = 20.0   -- distance before spawning/despawning butcher NPCs
Config.FadeIn = true          -- fade NPCs in/out when spawning/despawning
```

### Butcher Locations (`Config.ButcherLocations`)
12 locations are preconfigured (Valentine, St Denis, Rhodes, Annesburg, Tumbleweed, Blackwater, Strawberry, Van Horn, Spider Gorge, Riggs Station, Elysian, Guarma). Add your own:
```lua
{
    name = 'Custom Butcher',
    prompt = 'custom-butcher',
    coords = vector3(x, y, z),
    npcmodel = `model_hash`,
    npccoords = vector4(x, y, z, heading),
    showblip = true
}
```

### Sellable Animals (`Config.Animal`)
70+ animals are preconfigured with a base cash reward and reward item(s), which are multiplied by the quality multiplier on sale:
```lua
{ name = 'Panther', model = 1654513481, rewardmoney = 30, rewarditem1 = 'raw_meat', rewarditem2 = nil, rewarditem3 = nil },
```

---

## Events & API

### Client Events
| Event | Description |
|---|---|
| `rsg-hunting:server:giverewards` *(server)* | Triggered from the client to award skinning rewards |
| `rsg-hunting:client:butcher:mainmenu` | Opens the butcher shop menu |
| `rsg-hunting:client:butcher:sellanimal` | Starts the sell-animal progress bar and flow |

### Server Events
| Event | Description |
|---|---|
| `rsg-hunting:server:giverewards` | Validates and grants skinning reward items |
| `rsg-hunting:server:butcher:reward` | Validates the animal/quality and pays out the butcher sale |
| `rsg-hunting:server:butcher:openShop` | Opens the butcher's buy shop for the player |

### Callbacks (ox_lib)
| Callback | Description |
|---|---|
| `rsg-hunting:server:getSellData` | Returns the trapper's accepted items with current prices and the player's owned amounts |
| `rsg-hunting:server:sellBasket` | Validates and sells a basket (`{ name, amount }[]`) in one transaction, returns the payout and refreshed items |

### Console Commands
| Command | Description |
|---|---|
| `resetvendorstock` | Resets all trapper stock to 0 |

### Exports
| Export | Description |
|---|---|
| `DataViewNativeGetEventData` | Used internally to read native skinning event data |

---

## Troubleshooting

**Trapper sell screen shows no images**
- Confirm `Config.Image` points at your inventory image folder and the images from `installation/images/` were copied there.

**Trapper says "You are too far from the trapper"**
- The sale must happen within 6m of the trapper. Stand next to the NPC and try again.

**Sell screen stuck open / mouse stuck**
- Press `Esc`, or restart the resource — focus is released on resource stop.

**Butcher NPCs not appearing**
- Confirm you're within `Config.Performance.NpcSpawnDistance` (default 20 units) of a `Config.ButcherLocations` entry.
- Enable `Config.Debug = true` and check the console for model load errors.

**Butcher menu not opening**
- Confirm `ox_lib` is installed and started before `rsg-hunting`.
- If using the keybind, make sure `Config.EnableTarget` is `false`; otherwise use `ox_target` on the NPC.

**Skinning gives no rewards**
- Confirm the animal's model hash is listed in `Config.Animals`.
- Confirm `rsg-inventory:CanAddItem` isn't blocked by a full inventory.

**Butcher shop not working**
- Confirm `Config.ButcherShopItems` is populated and `rsg-inventory` is running.
- Check the console for `[rsg-hunting] Warning: No butcher shop items configured`.

**No webhook/log messages**
- Confirm `Config.Performance.LoggingEnabled` is `true` and `rsg-log` (or your logging resource) is started and listening for `rsg-log:server:CreateLog`.

---

## Credits

- **Author:** RexShack
- **Framework:** RSG Framework
- **Libraries:** ox_lib, ox_target, rsg-inventory
