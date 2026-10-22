# rsg-wagons

A wagon ownership, customisation and storage system for **RedM** servers running the **RSG-Core** framework.

Players buy wagons from NPC-staffed wagon shops, customise them with liveries, tints, extras, props and lanterns, call them out anywhere with road-aware spawning, store items and animal carcasses in them, sell them back, or scrap them at a chop shop for materials and cash.

---

## Features

- **Wagon shops.** Six locations out of the box (Valentine, Saint Denis, Strawberry, Blackwater, Tumbleweed and Caliga), each with an NPC, a map blip, and a live wagon preview with its own camera.
- **Large wagon catalogue.** Over 50 wagons in three categories:
  - **Work:** camp wagons, carts, a chuckwagon, a coal wagon, oil tankers, a hunter's cart, supply wagons and more.
  - **Special:** police, prison, armoured, circus, milkman, apothecary and war wagons.
  - **Coach:** buggies, carriages and stagecoaches.
- **Per-wagon stats.** Every wagon has its own price, max weight, stash slots and animal capacity.
- **Cash or gold pricing.** Set `priceGold` on a wagon to let players pay in gold as well.
- **Full customisation.** Liveries, paint tints, extras, propsets and lantern tiers, each with its own price. Includes the extended `mack-wagonextras` data (labels, liveries, categorised propsets).
- **Wagon storage.** Every wagon gets a personal stash (through `rsg-inventory`) sized by its weight and slot limits.
- **Carcass and pelt storage.** Wagons with `maxAnimals` can hold hunted animals and pelts, which you can view and take back out later. More than 250 animal and pelt models are supported.
- **Owner permissions.** Another player trying to open your wagon's stash has to get your approval first.
- **Smart spawning.** Your wagon spawns on the nearest road within a set radius. If there's no road nearby, it spawns a set distance from you instead.
- **Several ways to call your wagon.** Use the menu, an optional hotkey, or an optional `/callwagon` command.
- **Selling.** Sell wagons back for a percentage of what you paid.
- **Chop shop.** Scrap wagons (your own, or unlisted ones if you allow it) for random item rewards and cash. Payouts are scaled by a multiplier, and there's a per-player cooldown.
- **ox_target or prompts.** Works with `ox_target` or with native RSG prompts.
- **Themed NUI menu** with a configurable position and theme.
- **Localisation.** Ships with English, Dutch and Brazilian Portuguese (ox_lib locales).
- **Wagon limit.** Set a maximum number of wagons each player can own.

---

## Dependencies

| Resource | Required |
|---|---|
| [rsg-core](https://github.com/Rexshack-RedM/rsg-core) | Yes |
| [ox_lib](https://github.com/overextended/ox_lib) | Yes |
| [oxmysql](https://github.com/overextended/oxmysql) | Yes |
| [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) | Yes (wagon stashes) |
| [ox_target](https://github.com/overextended/ox_target) | Only when `Config.Target = true` |

---

## Installation

1. **Download** the resource and put it in your server's `resources` folder (for example `resources/[rsg]/rsg-wagons`). Keep the folder name as `rsg-wagons`.
2. **Import the database.** Run `installation/rsg-wagons.sql` against your database. It creates the `rsg_wagons` table:

   | Column | Purpose |
   |---|---|
   | `id` | Unique wagon ID |
   | `citizenid` | Owner |
   | `wagon` | Wagon model |
   | `custom` | Customisation data (JSON) |
   | `animals` | Stored carcasses and pelts (JSON) |
   | `active` | Whether this is the player's active wagon |

3. **Add the images (optional).** Copy the images in `installation/images/` into your inventory's image folder if you want menu or item icons there. The NUI already uses the copies in `images/`.
4. **Add it to `server.cfg`** so it starts after its dependencies:

   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure rsg-core
   ensure rsg-inventory
   ensure ox_target   # only if Config.Target = true
   ensure rsg-wagons
   ```

5. **Make sure your reward items exist.** The default chop shop reward is `wood`. Any item you add under `Config.Chop.RewardItems` must exist in your `rsg-core` shared items.
6. **Restart the server.**

---

## Configuration

All settings are in `config.lua`.

### General

| Option | Default | Description |
|---|---|---|
| `Config.Target` | `true` | `true` uses ox_target. `false` uses native prompts. |
| `Config.PositionMenu` | `'top-right'` | Where the menu appears on screen. |
| `Config.UITheme` | `'bw'` | NUI theme (`'bw'` or `'color'`). |
| `Config.usecommand` | `false` | Turns on the `/callwagon` command. |
| `Config.SpawnKey` | `false` | Hotkey for calling your wagon, for example `"INPUT_..."`. `false` turns it off. |
| `Config.SpawnRadius` | `100` | How far to search for a road to spawn the wagon on. |
| `Config.FallbackSpawnDistance` | `10` | How far from the player the wagon spawns when there's no road nearby (metres). |
| `Config.MoneyType.money` | `"cash"` | Money type charged for cash purchases. |
| `Config.maxWagonsPerPlayer` | `5` | Most wagons a player can own. |
| `Config.Sell` | `0.1` | Share of the purchase price paid back on sale (0.1 = 10%). |

> **Gold purchases:** the server reads `Config.MoneyType.gold` when a player pays in gold. Add it if you use `priceGold`:
> ```lua
> Config.MoneyType = { money = "cash", gold = "bloodmoney" } -- or your gold money type
> ```

> **Note:** `Config.usecommand` is set twice in `config.lua`. The second line is the one that takes effect.

### Keys

```lua
Config.Keys = {
    OpenWagonStash = "INPUT_JUMP",               -- Spacebar
    OpenStore      = "INPUT_SPRINT",             -- Left Shift (shop prompt)
    FleeWagon      = "INPUT_FRONTEND_CANCEL",    -- Escape
    CarcassMenu    = "INPUT_DOCUMENT_PAGE_PREV", -- Q
    SeeCarcass     = "INPUT_DOCUMENT_PAGE_NEXT", -- E
}
```

### Shop blip

```lua
Config.Blip = { showBlip = true, blipModel = "caravan", blipName = "Wagon Shop" }
```

### Stores

Every store needs the menu coordinates, an NPC, and a spot to preview wagons with a camera:

```lua
Config.Stores = {
    Valentine = {
        coords             = vector3(-355.11, 775.18, 116.22),
        npcmodel           = `s_m_m_cghworker_01`,
        npccoords          = vector4(-355.11, 775.18, 116.22, 321.41),
        previewWagon       = vec4(-353.43, 788.54, 116.15, 274.7),
        cameraPreviewWagon = vec4(-345.43, 788.54, 118.15, 274.7),
    },
    -- ...
}
```

### Wagons

Wagons are grouped under `work`, `special` and `coach`. The table key is the wagon model name.

```lua
huntercart01 = {
    name       = "Hunter's Cart",
    maxWeight  = 250,   -- stash weight limit (kg)
    slots      = 20,    -- stash slots
    price      = 75,    -- cash price
    priceGold  = 3,     -- optional gold price
    maxAnimals = 20,    -- carcass capacity, or false to disable
},
```

### Customisation prices

```lua
Config.CustomPrice = { livery = 15, extra = 25, tint = 38, props = 15, lantern = 15 }
```

The available liveries, extras, props and lanterns for each model are defined in `client/list.lua`. `client/mackmerge.lua` then extends them. To go back to the stock options, delete `mackmerge.lua`.

### Animal storage

`Config.AnimalsStorage` lists every animal and pelt model (by hash) that can be stored in a wagon, along with its display label. Add entries to support more models.

### Chop shop

| Option | Default | Description |
|---|---|---|
| `Locations` | 1 location | A list of `{ name, coords, blip }` entries. |
| `InteractDistance` | `10.0` | How close you need to be to see the prompt. |
| `WagonSearchDistance` | `30.0` | How far to search for a wagon to scrap. |
| `AllowUnknownWagons` | `true` | Allows scrapping vehicles that aren't in `Config.Wagons`. |
| `PromptKey` | `0x760A9C6F` (G) | Control hash for the prompt. |
| `PromptText` | `'Scrap Wagon'` | Prompt label. |
| `ChopCooldown` | `300` | Seconds each player has to wait between scraps. |
| `RewardItems` | `wood = 5–15` | Items given, with a min and max for each. |
| `CashPayout` | `5–20` | Cash range paid out. |
| `DefaultMultiplier` / `MinMultiplier` / `MaxMultiplier` | `1.0 / 0.5 / 2.5` | Payout multiplier and its limits. |
| `ChopBlip` | shown | Blip sprite, name and scale. |
| `Debug` | `false` | Turns on debug prints and the `/chopdebug` command. |

### Locales

Text strings live in `locales/*.json` (`en`, `nl`, `pt-br`). Set your language with ox_lib's convar, for example `setr ox:locale en`.

---

## Usage

### Buying a wagon
1. Go to a **Wagon Shop** (look for the blip on your map).
2. Talk to the NPC using ox_target, or press **Left Shift** at the prompt.
3. Pick a category, preview the wagons, and buy one with cash (or gold, if it has a gold price).

### Customising
Open the shop menu and choose one of your wagons. Pick liveries, tints, extras, props or lanterns. Changes show on the preview straight away, and each one is charged at the `Config.CustomPrice` rate.

### Calling and putting away your wagon
- Call it from the shop menu, with the hotkey (`Config.SpawnKey`), or with `/callwagon` (`Config.usecommand = true`).
- The wagon spawns on a nearby road and gets a blip. Use the target or prompt option to send it away again.

### Stash
Target the wagon (or press **Space** at the prompt) to open its storage. If someone else tries to open it, you'll get a request to approve or deny.

### Carcasses and pelts
While carrying an animal or pelt, target the wagon and choose **Stock carcass**, or press **Q**. Choose **See carcasses** (or press **E**) to view what's stored and take items back out. How many you can store depends on the wagon's `maxAnimals`.

### Selling
In the shop menu, select a wagon you own and sell it. You get back `price × Config.Sell`.

### Chop shop
Drive a wagon to a **Wagon Chop** location and press **G** at the **Scrap Wagon** prompt. The wagon is removed and you get the reward items and cash. After that, you have to wait out the cooldown before scrapping another.

### Commands

| Command | Requirement |
|---|---|
| `/callwagon` | `Config.usecommand = true` |
| `/chopdebug` | `Config.Chop.Debug = true` |

---

## Credits

Phil and mack
