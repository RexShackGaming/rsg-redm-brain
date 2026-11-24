# rsg-moonshine

Version 3.7.1

Placeable moonshine stills for **RedM** on the **RSG Framework**. Players set up a still in the wild, load a mash, keep the fire fed and bottle their shine, while the law hunts the stills down.

Brewing runs on the server in real time, so stills keep cooking while the owner is away and carry on through restarts.

<img width="1007" height="1080" alt="20261012200236_1" src="https://github.com/user-attachments/assets/013a1300-c22d-45aa-8547-c928d73c787f" />

---

## Features

- **Trusted friends:** owners can give up to 5 people access to a still from the menu. Strangers can no longer take your bottles.
- **Bottle labels:** name your moonshine from the menu; the name is stored on every bottle you collect.
- **Server exports:** other scripts can read bottle quality and label, get bootlegger prices, look up or remove stills and read the moonshiner level (see DOCS.md).
- **Realistic distilling (3.4.0):** mash ferments first (slower in the cold), distilling speed and fuel use follow the fire heat, a second run raises the proof, you choose how much heads and tails to cut (loose cuts can poison a batch), spirit can age in an oak cask, and rain, cold and night change how far the smoke and smell carry.
- **Materials, ingredient quality and inspections (3.7.0):** a cheap tin still (`moonshine_still_tin`) makes rougher spirit, gets dirty faster and blows up more often than copper; ingredients with `info.quality` raise or lower the batch; on duty law can inspect a still to read its grime, fire and tank.
- **Upkeep (3.6.0):** every run leaves grime that lowers quality and raises explosion risk until you scrub the still (bucket of water), the condenser needs cooling water while distilling (no water = lost spirit and harsh quality), and you can test a sample of the tank with a cut to learn whether it is poisonous before you bottle.
- **Fermenting barrels (3.5.0):** place oak barrels (`moonshine_barrel`) that ferment mash on their own, draw the wash off as `moonshine_wash` items and carry it to any still.
- **Quality & price:** better moonshiners make better moonshine, shown in the tank and paid for by bootleggers.
- **Bootlegger buyers:** sell bottles for cash in every speakeasy cellar. A sale can tip off the law.
- **Risk & raids:** a finished batch can blow up an inexperienced moonshiner's still, and law on duty can smell mash nearby.
- **Skills & reputation:** uses rsg-skills (moonshining skill and sell perk) and rsg-reputation when they are running.
- **Placeable stills:** use the still item to open the rsg-gizmo placement preview (rotate, confirm or cancel with the gizmo keys).
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
- **11 languages:** en, de, el, es, fr, ja, nl, pl, pt-br, ro and ru, using rsg-core locales.
- **Security:** every action is checked on the server (distance, ownership, job, amounts), with per-player rate limits on actions, menu refreshes and raids. Stills only spawn near the player.

---

## Dependencies

> No ox_lib required — locales, notifications, callbacks, progress bars and text UI all come from rsg-core.

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [rsg-target](https://github.com/Rexshack-RedM/rsg-target)
- [rsg-gizmo](https://github.com/Rexshack-RedM/rsg-gizmo)
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
   ensure oxmysql
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-target
   ensure rsg-gizmo
   ensure rsg-moonshine
   ```

6. **Language (optional):**
   ```cfg
   setr rsg:locale "en"   # en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru
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
1. Look at the still (rsg-target) and choose **Check Still** to open the menu.
2. **Pick a recipe.** Locked recipes show the level they need.
3. **Load ingredients** into the hopper. Use −/+ (steps of one batch), **Max**, then **Load**.
4. **Add fuel** (wood or coal) to the firebox. Use **Max** to fill it with as much as you're carrying.
5. Each full batch of ingredients **ferments** into wash first (no fuel needed, up to `Ferment.maxWash` batches wait for the still). Cold weather slows fermenting.
6. With wash and fuel the still **distils**. Pick the **fire heat**: low is slow, cheap, cleaner and quieter; high is fast but burns fuel, lowers quality and risks an explosion.
7. The first run comes off weak (low **proof**). Press **Run it again** for a second run: stronger spirit, less volume. Proof raises the sale price.
8. Choose a **cut** (tight, normal or loose) and press **Bottle & Collect** with **empty jugs** (`moonshine_jug_empty`). Tight cuts keep less but better spirit; loose cuts keep everything but can poison the batch, and bootleggers refuse poisoned bottles.
9. **Oak cask** (optional): fit a `moonshine_cask`, move the tank into it and bottle later. Quality rises with time, a little evaporates, and opening the cask stops the ageing.
10. Rain, cold and night hide the smoke; heat changes how big the smoke is and how far law can smell the mash.

### Tin vs copper, ingredient quality, inspections
- Use **Tin Moonshine Still** (`moonshine_still_tin`) to place a tin still (counts toward `MaxStills`). Tin: -8 quality, 1.6x grime, 1.5x explosion risk. Existing stills stay copper.
- Ingredients you load that carry `info.quality` are averaged into the mash. The batch gets `(quality - 50) * 0.3` quality (items without quality count as 50). The menu shows the mash quality; wash from barrels keeps it.
- On duty law see **Inspect Still** on the target (5 s). It reports the material, grime, fire, whether it is running and what the tank holds, without changing anything.

### Upkeep and testing
- **Cooling water:** press **Add water** to pour a `fullbucket` into the cooling tank (600 s per bucket, 2400 s max). Distilling uses 0.5 s per second. With the tank dry the batch loses spirit and quality and the explosion risk goes up.
- **Grime:** each batch adds 8 grime, each second run 4. Grime costs up to 20 quality and doubles the explosion risk at 100. **Scrub still** uses a `fullbucket` and only works when nothing is running.
- **Test a sample:** choose a cut, press **Test a sample** (costs 1 spirit, needs 2). It tells you if that cut is clean or foul, and bottling with the same cut keeps that result. Any change to the tank clears it.

### Fermenting barrels
1. Use a **Fermenting Barrel** (`moonshine_barrel`) item to place a barrel the same way as a still (up to `Barrel.max` per character).
2. Check the barrel, pick a recipe and load ingredients. A full batch ferments by itself (no fuel) and waits as wash, up to `Barrel.maxWash` batches.
3. Press **Draw off wash** to take the wash as `moonshine_wash` items (one per batch).
4. At a still with the **same recipe selected**, press **Pour in wash**. The still distils it like its own wash.
Barrels can be packed up when empty and give the barrel item back.

### Changing recipe or packing up
- **Change Recipe** and **Pack Up Still** only work when the hopper, mash tub, wash, pot, tank and cask are all empty (packing up returns the cask). Use **Unload** to get ingredients back.
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
| `OwnerOnly` | `true` | `true` means only the owner can brew and collect |
| `MaxBatches` | `10` | How many batches' worth of each ingredient the hopper holds |
| `EmptyJug` | `moonshine_jug_empty` | Item used up for each bottle collected |
| `OutputCap` | `50` | Bottles the tank holds before brewing stops |
| `TickInterval` | `15` | Seconds between server brewing updates |
| `TrustedMax` / `TrustDist` | `5` / `6.0` | People an owner can trust, and how close they must stand |
| `SyncDist` | `200.0` | Stills farther than this are never sent to a player |
| `Label` | 24 chars | Custom bottle label (`enabled`, `maxLength`, `blocked` words) |
| `Quality` | see config | Batch quality, price multipliers |
| `Materials` / `Ingredients` / `Inspect` | see config | Tin and copper stills, ingredient quality weight, law inspection |
| `Wear` / `Cooling` / `Taste` | see config | Grime, cooling water and sample testing |
| `Barrel` | 3 per character, holds 4 batches | Fermenting barrels (item, wash item, prop, limits) |
| `Ferment` / `Heat` / `Proof` / `Rerun` | see config | Fermentation time and wash limit, fire heat levels, proof and the second run |
| `Cuts` / `Cask` / `Environment` | see config | Heads and tails cuts and poison chance, oak cask ageing, weather and night effects |
| `Risk` | `3%` base, safe at level 6 | Explosion chance per finished batch (`enabled = false` turns it off) |
| `Smell` | `80.0` m, 120 s | Law on duty near a brewing still get a hint |
| `Buyers` | speakeasies | Bootlegger spots, bottles per sale, law tip-off chance |
| `UseSkills` / `SkillName` | `true` / `moonshining` | Use rsg-skills for level and xp |
| `Reputation` | sell `-1`, raid `2` | rsg-reputation honor changes |
| `AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk working while the still menu is open (`PushToTalkControls` lists the keys) |
| `WorldStills.maxTotal` | `150` | Max saved map stills (stops database flooding) |
| `WorldStills.locations` | `{}` | Optional allow-list of map still coords |
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

## Database

Tables (`rsg_moonshine_stills`) are created automatically on first start while `Config.AutoDatabase = true` (default); the database user needs `CREATE` permission. To install manually, set `Config.AutoDatabase = false` in the config and import `installation/rsg-moonshine.sql` once.
