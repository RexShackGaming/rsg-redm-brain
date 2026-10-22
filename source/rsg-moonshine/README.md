# rsg-moonshine

Placeable moonshine stills for **RedM** on the **RSG Framework**. Players set up a still in the wild, load a mash, keep the fire fed and bottle their shine, while the law hunts the stills down.

Brewing runs on the server in real time, so stills keep cooking while the owner is away and carry on through restarts.

<img width="1007" height="1080" alt="20261012200236_1" src="https://github.com/user-attachments/assets/013a1300-c22d-45aa-8547-c928d73c787f" />

---

## Features

- **Placeable stills:** use the still item to get a see-through preview. Rotate it, then left click to place or right click to cancel.
- **Placement rules:** a limit on stills per character, a minimum distance between stills, and towns where stills can't be built (Valentine, Saint Denis, Rhodes and others).
- **12 recipes:** from Corn Moonshine to American Moonshine, each with its own ingredients, brew time, bottle count and unlock level.
- **Ingredient hopper:** load up to 10 batches' worth of ingredients. Batches start one after another on their own.
- **Firebox fuel:** wood and coal burn for different lengths of time. Fuel only burns while a batch is cooking, and the batch pauses if the fire goes out.
- **Output tank with bottling:** collect bottles using empty jugs, one jug per bottle. Brewing stops when the tank is full.
- **Moonshiner XP and levels:** players earn XP for every bottle (stored as RSG rep `moonshiner`), and higher levels unlock better recipes.
- **Law raids:** on-duty lawmen can smash any still for a cash reward. There is no reward for raiding your own still.
- **Owner controls:** only the owner can pack up a still. You can also set it so only the owner can brew.
- **Brewing effects:** smoke and fire appear on the still while it is brewing.
- **In-game menu:** a dark leather-and-gold menu with live timers, progress bars and quantity pickers.
- **Discord webhooks:** detailed logs for every action, with a separate URL per event, rate-limit handling and a channel for suspicious activity.
- **10 languages:** en, de, el, es, fr, ja, nl, pl, pt-br and ro, using ox_lib locales.
- **Security:** every action is checked on the server (distance, ownership, job, amounts), with per-player rate limits on actions, menu refreshes and raids. Stills only spawn near the player.

---

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)

---

## Installation

1. **Add the resource.** Place `rsg-moonshine` in your resources folder, for example `resources/[rsg]/rsg-moonshine`.

2. **Database.** The table `rsg_moonshine_stills` is created automatically on first start. If you prefer, you can run `installation/rsg-moonshine.sql` yourself.
   > On **MySQL 8**, if you are upgrading from an older version, run the commented `ALTER TABLE` lines in that file. MariaDB is upgraded automatically.

3. **Items.** Copy the entries from `installation/shared_items.lua` into `rsg-core/shared/items.lua`.
   Skip any items your server already has (fruit, herbs, water and so on are often already there). Duplicate entries overwrite each other.

4. **Images.** Add a PNG for each new item to `rsg-inventory/html/images/`, named after the item (for example `moonshine_peach.png`).

5. **server.cfg.** Make sure the dependencies start before this resource:
   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure rsg-core
   ensure rsg-inventory
   ensure ox_target
   ensure rsg-moonshine
   ```

6. **Language (optional):**
   ```cfg
   setr ox:locale "en"   # en, de, el, es, fr, ja, nl, pl, pt-br, ro
   ```

7. **Discord logs (optional).** Add your webhook URL in `server/sv_config.lua` (see below).

Restart the server, or run `refresh` and then `ensure rsg-moonshine`.

---

## How to use

### Setting up a still
1. Get a **Moonshine Still** (`moonshine_still`) item, for example from a shop or crafting.
2. Use it from your inventory. A see-through still appears in front of you.
3. **← / →** rotate, **Left mouse** places, **Right mouse** cancels.
4. Stay still through the progress bar and the still is set up.

### Brewing
1. Look at the still (ox_target) and choose **Check Still** to open the menu.
2. **Pick a recipe.** Locked recipes show the level they need.
3. **Load ingredients** into the hopper. Use −/+ (steps of one batch), **Max**, then **Load**.
4. **Add fuel** (wood or coal) to the firebox. Use **Max** to fill it with as much as you're carrying.
5. The still lights up and starts brewing. Batches carry on as long as there are ingredients, fuel and room in the tank.
6. Bring **empty jugs** (`moonshine_jug_empty`) and press **Bottle & Collect**. You get one bottle per jug and earn moonshiner XP.

### Changing recipe or packing up
- **Change Recipe** and **Pack Up Still** only work when the hopper, the current batch and the tank are all empty. Use **Unload** to get ingredients back.
- Only the owner can pack up a still, and it goes back into their inventory.

### Raids (law enforcement)
- On-duty lawmen with a job in `Config.LawJobs` see **Destroy Still** on any still.
- Smashing a still takes `Config.DestroyTime` and pays `Config.DestroyReward`. Everything inside the still is lost.
- The server enforces the same `DestroyTime` between raids, so the progress bar can't be skipped to chain-raid.

### Commands
| Command | Description |
|---|---|
| `/moonshine_unfocus` | Emergency release if the menu ever leaves your cursor stuck |

---

## Configuration

### `shared/config.lua`

| Option | Default | Description |
|---|---|---|
| `StillItem` | `moonshine_still` | Usable item that places a still |
| `StillProp` | `mp001_p_mp_still02x` | Prop model for the still |
| `MaxStills` | `2` | Maximum stills per character |
| `MinStillDist` | `10.0` | Minimum distance between any two stills |
| `InteractDist` | `3.0` | Maximum distance for menu actions (checked on the server) |
| `PlaceDist` | `5.0` | Maximum distance between the player and the still they place |
| `SpawnDist` | `120.0` | Stills only spawn as props within this range of the player |
| `OwnerOnly` | `false` | `true` means only the owner can brew and collect |
| `MaxBatches` | `10` | How many batches' worth of each ingredient the hopper holds |
| `EmptyJug` | `moonshine_jug_empty` | Item used up for each bottle collected |
| `OutputCap` | `50` | Bottles the tank holds before brewing stops |
| `TickInterval` | `15` | Seconds between server brewing updates |
| `ImagePath` | `nui://rsg-inventory/html/images/` | Where the menu loads item images from |
| `Fuels` | wood 300s, coal 900s | Fuel items and their burn time in seconds each |
| `MaxFuel` | `7200` | Maximum seconds of fuel the firebox holds |
| `BrewFx` | smoke and fire | Particle effects while brewing (on/off, offsets, scale) |
| `BlockedZones` | 8 towns | No-build zones: `{ name, coords, radius }` |
| `XpName` | `moonshiner` | RSG rep key used for XP |
| `XpPerBottle` | `2` | Default XP per bottle (each recipe can override it) |
| `Levels` | `{0,100,250,500,1000,2000}` | Total XP needed for each level |
| `LawJobs` | the 5 law jobs | Jobs allowed to destroy stills |
| `LawRequireDuty` | `true` | Lawmen must be on duty |
| `DestroyTime` | `10000` | Time to smash a still, in ms |
| `DestroyReward` | `15` | Cash paid per raid |

### Adding a recipe
```lua
{
    key = 'moonshine_cherry',          -- unique key
    label = 'Cherry Moonshine',        -- fallback name (add recipe_moonshine_cherry to locales to translate it)
    level = 3,                         -- moonshiner level required
    xpPerBottle = 4,
    time = 900,                        -- seconds per batch
    ingredients = {
        { item = 'cherry', amount = 5 },
        { item = 'sugarcane', amount = 2 },
        { item = 'yeast', amount = 1 },
        { item = 'water', amount = 2 },
    },
    output = { item = 'moonshine_cherry', amount = 5 },
},
```
Every ingredient and output item must exist in `rsg-core/shared/items.lua`.

### Discord webhooks: `server/sv_config.lua`
This file is **server only**, so your webhook URLs are never sent to players.

```lua
SvConfig.Webhooks = {
    enabled = true,
    default = 'https://discord.com/api/webhooks/...', -- used by any event without its own url
    mirrorRsgLog = false,                              -- also send to rsg-log
    events = {
        destroy = { enabled = true, url = 'https://...law-channel...', color = 15548997 },
        ...
    },
}
```

| Event | On by default | Logged when |
|---|---|---|
| `place` | Yes | A still is placed |
| `pickup` | Yes | The owner packs up a still |
| `destroy` | Yes | Law raids a still (reward, bottles lost, owner) |
| `collect` | Yes | Moonshine is bottled |
| `recipe` | Yes | A recipe is selected |
| `levelup` | Yes | A player reaches a new moonshiner level |
| `suspicious` | Yes | A non-law destroy attempt, remote placement or out-of-range action |
| `load` / `fuel` / `unload` | No | Hopper and firebox changes (noisy) |

Each log includes the character name, citizen ID, job, server ID, Discord mention, license and location.

### Locales
Text lives in `locales/<lang>.json`, covering notifications, the menu, recipe names and webhook logs. To add a language, copy `en.json`, translate the values (keep the `%s` placeholders) and set `ox:locale`.

---

## Notes

- Brewing is worked out from the time of the last save, so stills progress correctly through server restarts and downtime.
- Ingredients in `Config.Recipes` marked "will need to add ... to farming" (peaches, lemons) need a source on your server before players can make those recipes.

---

## Support

If you enjoy this script, you can support development here:
☕ **[Buy Me a Coffee](https://buymeacoffee.com/rexshack)**

Found a bug or have an idea? Open an issue on [GitHub](https://github.com/Rexshack-RedM/rsg-moonshine).
