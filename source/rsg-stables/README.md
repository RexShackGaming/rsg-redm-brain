# rsg-stables

Horse and stables system for the **RSG Framework** (RedM). Buy, stable, customise, care for and breed horses across multiple stable locations, all through a custom NUI.

---

## Features

- **Multiple stables** – Valentine, Blackwater, Rhodes, Saint Denis and Strawberry out of the box, each with a stablehand NPC, map blip and horse preview spot. Add your own in config.
- **Buy menu** – 100+ horse breeds/coats with health, stamina, speed and acceleration ratings, class, handling, descriptions and price-band filters.
- **Ownership limits** – max horses per player, and max horses each player can keep at one stable.
- **Stallions & mares** – choose the gender when buying; foals get a random one.
- **Rename & insure** – rename horses for a fee; insure them so a dead horse can be revived/replaced.
- **Release dead horses** – lay a deceased horse to rest from the stable menu to free up its slot; its saddlebags must be emptied first with **Empty Saddlebags** (the only option for horses that died of old age).
- **Give or sell to a player** – hand a stabled horse to someone standing next to you, free or for an asking price they must accept (and be able to afford).
- **Tack customisation** – blankets, saddles, saddlebags, horns, stirrups, bedrolls, manes, tails, masks, mustaches, holsters, bridles, each item individually priced. Styles swap on the preview horse instantly (no respawn) with a menu sound while cycling. The holster is optional: without one, long guns stay on the player's back instead of going onto the horse (`Config.HolsterStoresLongarms`). Categories can be marked `required`.
- **Horseshoes** – a horse without shoes is noticeably slower and tires faster. While riding at speed a shoe can be thrown, and the horse stays degraded until new shoes are fitted at a stable (`Config.Horseshoes`). Bought horses and foals come shod; claimed wild horses don't.
- **Coat customisation** – custom tint system (main coat, markings, nose, mane, tail) with quick-pick presets and a flat colour-change fee.
- **Horse needs** – hunger and thirst decay over time; starving/dehydrated horses lose health, well-fed horses slowly regenerate.
- **Feeding, watering & brushing** – via ox_target on your active horse, or by using the feed items / brush straight from the inventory (with the hand-feed and brushing animations). The brush also works from the saddle (`Config.HorseBrushMounted`).
- **Horse actions** – a movable NUI panel (and one command per action) to make your horse **Rest**, **Sleep**, **Graze**, **Roll**, **Rear Up**, **Stay** or **Follow** you. Resting and sleeping slowly restore stamina and health. Uses Rockstar's own horse animations.
- **Rear up on command** – press **Q** while riding to rear your horse up without being thrown.
- **Saddlebags** – each horse has its own rsg-inventory stash (weight and slots set in config), opened from the horse's target menu or the game's own **Horse Cargo (B)** prompt. Optionally (`requireSaddlebags`) the stash only opens when saddlebags are fitted as tack.
- **Native prompts tidy-up** – the game's own Brush / Feed horse prompts can be hidden so only the ox_target options are used.
- **Natural drinking** – horses drink on their own at rivers, lakes and water troughs when thirsty.
- **Natural grazing** – a hungry horse wanders to hay near you (configurable hay props) and eats.
- **Hitching posts** – a horse tied at a hitching post doesn't wander off to drink or graze (`Config.HorseHitch`).
- **Horse lantern** – fit or remove a saddle lantern with the `horse_lantern` item; it's saved with the horse's tack.
- **Aging & lifespan** – horses are Young, Adult or Old by real-life days owned. Old horses hold less stamina each day and eventually die of natural causes (no revive).
- **Bonding** – grows when you feed, water and brush your horse.
- **Horse medicine** – usable item that restores health and refills the health core.
- **Field revive** – when your horse goes down you have a short window to use a horse reviver before it dies (logging out counts as letting it die).
- **Tack stat bonuses** – saddles, stirrups, horseshoes and blankets add bonus ranks to health, stamina, speed or acceleration (per category or per item).
- **Sell horses** – sell a stabled horse back to the stablehand (price based on breed and training).
- **Horse fence** – sell wild or stolen (unowned) horses to a fence NPC for blood money; add fence locations in `Config.HorseFence`.
- **Courage** – trainable, and raised by bonding, so your horse spooks less.
- **Horse training** – ride your horse or pay for training sessions at a stable to level up health, stamina, speed and acceleration.
- **Horse stimulant** – usable item giving a timed stamina fortify and optional speed boost.
- **Whistle recall** – whistle (H) to call your horse; it walks up and stops just in front of you, facing you. Teleports closer first if it's too far away, and respawns it if the game has removed it.
- **Persistent active horse** – position is saved to the database while out, so it survives logouts and resource restarts.
- **Flee horse** – send your horse away; optionally return it to the stable automatically.
- **Wild horses** – break a wild horse with the game's taming minigame, ride it to any stable and choose **Claim Wild Horse** at the stablehand to name it and register it. Validated server-side (breed must be in `Config.Breeds`, you must have broken it, claim window, distance and ownership limits).
- **Breeding** – breed a stallion and a mare (adults only) to produce a foal after one real-life day. Foals inherit the parents' averaged stats with a chance to take the better parent's. Parents are locked while breeding and rest afterwards.
- **Horse info card** – native animal info card showing horse stats.
- **Horse stats panel** – live health, stamina, hunger, thirst, bonding, cleanliness, tack and training bonuses from the **Horse Stats** target option or `/horseinfo`.
- **Store anywhere** – store your active horse at whichever stable you're at (or with `/storehorse`); it's kept there from then on (falls back to its previous stable if that stable is full for you).
- **Localisation** – en, de, el, es, fr, ja, nl, pl, pt-br, ro.
- **Auto database setup** – tables are created automatically on resource start.
- **Version checker** – notifies you in the server console when an update is available.

---

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/Rexshack-RedM/ox_lib)
- [ox_target](https://github.com/Rexshack-RedM/ox_target)
- [oxmysql](https://github.com/Rexshack-RedM/oxmysql)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) (saddlebag stashes)

> **Upgrading from 3.0.x:** new columns (`gender`, `breed_cooldown`, `died_of_age`) are added automatically on start and existing horses are given a random gender. Aging counts from each horse's original purchase date, so long-owned horses will be Old (or reach their lifespan) straight away – raise `Config.HorseAging.lifespanDays` first if you don't want that.

---

## Installation

1. Download and place the `rsg-stables` folder in your server's `resources` directory (e.g. `resources/[rsg]/rsg-stables`).
2. **Database** – the tables `rsg_stables_horses` and `rsg_stables_breeding` are created automatically on first start. If you prefer manual setup, import `installation/install.sql` with HeidiSQL/phpMyAdmin.
3. **Items** – make sure the following items exist in `rsg-core/shared/items.lua` (names are configurable):
   - `horse_apple`, `horse_carrot` – feed items (**set `useable = true`**)
   - `fullbucket` – water item
   - `horse_brush` – brushing tool, not consumed (**set `useable = true`**)
   - `horse_stimulant` – stimulant (**set `useable = true`**)
   - `horse_medicine` – restores horse health (**set `useable = true`**)
   - `horse_reviver` – revives a downed horse in the field (**set `useable = true`**)
   - `horse_lantern` – saddle lantern, not consumed (**set `useable = true`**)
4. Ensure the resource in your `server.cfg` **after** its dependencies:
   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure rsg-core
   ensure ox_target
   ensure rsg-inventory
   ensure rsg-stables
   ```
5. Restart the server.

---

## Configuration

All settings live in `shared/config.lua`.

### General

| Option | Default | Description |
|---|---|---|
| `Config.MaxOwnedHorses` | `8` | Max horses one player can own |
| `Config.MaxHorsesPerStable` | `20` | Max horses one player can keep at one stable |
| `Config.RenameCost` | `15` | Cost to rename a horse |
| `Config.InsuranceCost` | `25` | Cost to insure a horse |
| `Config.ReviveCost` | `40` | Cost to revive a dead insured horse |
| `Config.StoreDistance` | `8.0` | Max distance of your mount from the stable to store it |
| `Config.PaymentAccount` | `'cash'` | `'cash'` or `'bank'` |
| `Config.WhistleStopDistance` | `1.0` | How far in front of you (to the horse's nose) a whistled horse stops |
| `Config.WhistleAnim` | `'WHISTLEHORSESHORT'` | Whistle sound + animation (`'WHISTLEHORSELONG'`, `'WHISTLEHORSEDOUBLE'`, or `false` to disable) |
| `Config.WhistleTeleportDistance` | `60.0` | Beyond this distance a whistled horse is moved near you |
| `Config.HorseBrushDistance` | `4.0` | How close you must be to use the brush or a feed item from the inventory |
| `Config.HorseBrushMounted` | `true` | Allow brushing while riding |
| `Config.DebugHorseChecks` | `false` | Print why a feed/water/brush server check failed to the server console |
| `Config.HideNativeBrushFeed` | `true` | Hide the game's own Brush / Feed horse prompts |
| `Config.AllowTwoPlayersRide` | `false` | Allow a passenger on the horse |
| `Config.HolsterStoresLongarms` | `true` | Long guns are only stored on the horse when a holster is fitted. `false` = game default (any owned horse stores them) |

### Feature blocks

| Block | What it controls |
|---|---|
| `Config.ActiveHorse` | Position save interval, recall distances and login reminder for horses left out |
| `Config.HorseFeedItems` / `Config.HorseDrinkItems` | Items and how much health/stamina/hunger/thirst they restore |
| `Config.HorseStimulant` | Item, duration, stamina floor, fortify amount, speed multiplier, reuse |
| `Config.HorseNeeds` | Hunger/thirst decay rates, critical threshold, health drain and regen |
| `Config.HorseNaturalDrink` | Thirst threshold, timings, water/trough radius, trough models and max distance from the owner (`maxPlayerDistance`) |
| `Config.HorseNaturalGraze` | Hunger threshold, search radius around the player, eat time, cooldown, animation, hay prop models and max distance from the owner (`maxPlayerDistance`) |
| `Config.HorseHitch` | Stop natural drinking/grazing while hitched, hitch detection radius and hitching post models |
| `Config.HorseBrushItem` | Item required to brush (also usable from the inventory) |
| `Config.HorseLantern` | Horse lantern on/off, item name, lantern shop-item hash and how close you must be to your horse |
| `Config.HorseInventory` | Saddlebag stash on/off, max weight, slots, target distance, `nativeCargoPrompt` (B opens the stash) and `requireSaddlebags` (stash only opens with saddlebags fitted) |
| `Config.HorseBonding` | Bonding gained per feed / water / brush |
| `Config.HorseActions` | Horse actions panel on/off, `/horseaction` command, per-action commands, `/horsestop`, rest/sleep regen, the action list (animations, follow offset/speed) and the rear-up key (`rearKey`) |
| `Config.HorseFlee` | Flee delay, whether fled horses are stored, respawn distance |
| `Config.WildHorse` | Wild horse claiming on/off, registration fee, claim window after breaking, max horse distance |
| `Config.Breeding` | Cost, foal timer, same-stable, stallion + mare requirement, parent lock and cooldown, stat variance, better-parent chance |
| `Config.HorseAging` | Young/Old thresholds, lifespan, "days left" warning, minimum stamina for the oldest horses |
| `Config.HorseGive` | Give/sell to player on/off, distance, giver fee, accept timeout, max asking price |
| `Config.TackSounds` | Frontend sound played while cycling tack styles (`enabled`, `soundset`, `left`, `right`) |
| `Config.Horseshoes` | Unshod slow-down and stamina drain, chance and interval for a shoe to be thrown while riding, whether new horses come shod, mount reminder |
| `Config.Tack` / `Config.TackCategories` / `Config.TackItems` | Enable tack, categories (add `required = true` to force one) and individual tack items with prices |
| `Config.Coat` | Enable coat editor, colour-change fee and presets |
| `Config.HorseCard` | `/horseinfo` command name (`false` to disable) and max distance to your horse |
| `Config.HorseMedicine` | Item, heal %, refill health core, use distance, cooldown |
| `Config.HorseReviver` | Item, revive window, use distance, health after revive, bonding lost when the horse goes down |
| `Config.TackBonuses` | Bonus ranks per tack category (saddle, stirrups, horseshoes, blanket); items can set their own `bonus` |
| `Config.HorseSell` | Sell back to the stablehand on/off, % of breed price, extra per trained level, minimum price |
| `Config.HorseFence` | Fence on/off, payout account (`bloodmoney`), % of breed price, cooldown, sell distance, NPC model, blip and `locations` |
| `Config.Training` | Trainable stats and attributes, XP per level, bonus per level, courage from bonding, ride XP settings and paid stable sessions (price, cooldown, rounds) |
| `Config.BuyPriceBands` | Price filters in the buy menu |
| `Config.BreedStatMax` | Max value of breed stat bars |

### Adding a stable

```lua
{
    name          = 'mystable',                -- unique id (stored in DB)
    label         = 'My Stable',
    pedModel      = `u_m_m_bwmstablehand_01`,
    pedCoords     = vector4(x, y, z, heading), -- stablehand NPC
    storeCoords   = vector4(x, y, z, heading), -- where horses are stored
    previewCoords = vector4(x, y, z, heading), -- horse preview spot
    blip = { sprite = 'blip_shop_horse', color = 'BLIP_MODIFIER_MP_COLOR_6', scale = 0.2 },
},
```

### Adding a horse breed

```lua
{
    model = `a_c_horse_arabian_white`,
    label = 'Arabian (White)',
    class = 'Race Horse',
    breed = 'arabian',
    price = 1200,
    handling = 'Elite',
    health = 4, stamina = 4, speed = 5, acceleration = 5, -- out of Config.BreedStatMax
    description = 'Short description shown in the buy menu.'
},
```

### Translations

Edit or add a JSON file in `locales/`. The language is chosen by ox_lib, set it in your `server.cfg`:

```cfg
setr ox:locale "en"
```

---

## Usage

### At the stable
Walk up to the stablehand and use **ox_target → Manage Stable** to open the menu, where you can:
- **Buy** a horse (filter by class, breed and price).
- **Take out / store** your horses.
- **Rename**, **insure**, **revive**, **empty the saddlebags of** or **release** (dead) horses.
- **Customise tack** and **coat** (including fitting new **horseshoes** after one is thrown).
- **Sell Horse** – sell a stabled horse back to the stablehand.
- **Breed** a stallion and a mare and collect the foal when ready.
- **Give to Player** – give or sell a horse to someone standing next to you.
- **Claim Wild Horse** – shown when you've just broken a wild horse and it's with you; name it and it's added to that stable.

Each horse in the list shows its gender, stage (Young / Adult / Old, with days left near the end of its life) and health/stamina.

### With your active horse
Target your horse (ox_target) for:
- **Feed Horse** – uses a feed item.
- **Water Horse** – uses a water item.
- **Brush Horse** – requires the brush item.
- **Horse Stats** – health, stamina, hunger, thirst, bonding and cleanliness.
- **Store Horse** – when near a stable.
- **Train Horse** – paid training session (dismounted, at a stable).
- **Flee Horse** – sends the horse away.
- **Horse Actions** – opens the actions panel (drag it by its title to move it; double-click the title to reset).
- **Open Saddlebags** – opens the horse's own stash (you must be standing next to it; with `requireSaddlebags` the horse must have saddlebags fitted).

### At a horse fence
Ride an unowned (wild or stolen) horse to a fence NPC from `Config.HorseFence.locations`, dismount and choose **Sell Horse** to get blood money. Your own stable horses are refused.

### Controls & commands
| Input | Action |
|---|---|
| Whistle key (`INPUT_WHISTLE`, default **H**) | Call your active horse |
| Focus horse + prompt | Show horse info card |
| Horse Cargo (**B**) next to your horse | Open its saddlebags |
| `/storehorse` | Store your active horse at the nearest stable |
| `/horseinfo` | Open the horse stats panel (`Config.HorseCard.command`) |
| **Q** while riding (`Config.HorseActions.rearKey`) | Rear up |
| `/horseaction` | Open the horse actions panel |
| `/horserest`, `/horsesleep`, `/horsegraze`, `/horsewallow`, `/horserear`, `/horsestay`, `/horsefollow` | Run a horse action directly (on foot, near your horse) |
| `/horsestop` | Stop the current horse action |

### Items
| Item | Use |
|---|---|
| `horse_stimulant` | Use from inventory while mounted or near your horse for a stamina/speed boost |
| `horse_apple`, `horse_carrot` | Use from inventory next to your horse (dismounted), or via **Feed Horse** |
| `horse_brush` | Use from inventory next to or riding your horse, or via **Brush Horse** |
| `fullbucket` | Used through **Water Horse** |
| `horse_medicine` | Use from inventory near your horse to restore health |
| `horse_reviver` | Use next to your downed horse within the revive window |
| `horse_lantern` | Use from inventory next to or riding your horse to fit / remove a saddle lantern (not consumed). It's saved with the horse's tack, so it stays on until removed |

---

## Support

Issues and updates: [Rexshack-RedM on GitHub](https://github.com/Rexshack-RedM/rsg-stables)

If you find this useful, you can support development here: [Buy Me a Coffee](https://buymeacoffee.com/rexshack)
