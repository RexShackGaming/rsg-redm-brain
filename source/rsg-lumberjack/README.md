# rsg-lumberjack

Lumberjack gameplay for RSG-Core (RedM): grow trees, chop them, carry logs,
process them into wood, and sell full wagon loads of logs for cash.

## Dependencies
- `rsg-core`
- `ox_lib`
- `ox_target`
- `rsg-inventory`
- `oxmysql`

## Installation
1. Drop `rsg-lumberjack` into your resources folder and add `ensure rsg-lumberjack`
   to your server.cfg (after the dependencies).
2. Add the `tree_seeds` item from `install/items.txt` to `rsg-core/shared/items.lua`
   and copy `install/tree_seeds.png` into `rsg-inventory/html/images/`.
3. The `rsg_lumberjack_trees` table is created automatically on first start.
   `install/database.sql` is provided for manual installation.

## Items used
| Item | Config | Purpose |
|------|--------|---------|
| `tree_seeds` | `Config.Planting.SeedItem` | Use to plant a tree |
| `fullbucket` | `Config.Planting.WaterItem` | Use near a tree (or target it) to water it |
| `resource_wood` | `Config.Items.Wood` | Picked up from wood piles after processing a log |
| `axe` | `Config.Chopping.AxeItem` | Required to chop trees and process logs |

Logs themselves are not inventory items - they are carried physically.

## Gameplay loop
1. **Planting** - use `tree_seeds` anywhere. Water the sapling (target it, or use
   `fullbucket` next to it) to start each growth stage. The owner sees a growth bar
   above their trees and gets a notification when a tree needs water again or is
   ready to chop. Set `Config.Planting.RequireWater = false` for trees that grow
   by themselves.
2. **Chopping** - chop wild trees (`Config.Trees`) or your fully-grown planted
   trees with an axe to get a log in your hands. The axe can break
   (`Config.Chopping.AxeBreakChance`).
3. **Carrying** - press **E** to drop a carried log. Anyone can pick it up again
   or process it into `Config.Items.WoodAmountFromLog` wood piles, each giving
   one `resource_wood`. Ground items despawn after
   `Config.Items.GroundDespawnMinutes`.
4. **Wagon** - target a log wagon (`Config.Wagon.Model`) while carrying a log to
   load it (up to `Config.Wagon.MaxLogsOnWagon`). Logs can be taken back off,
   and "Check Wagon" shows the current load.
5. **Selling** - drive a full wagon into any `Config.WagonSellLocations` zone and
   press **E**. Each location has its own price, radius and blip.

## Configuration
Everything lives in `shared/config.lua`:
- `Config.Chopping` - axe, break chance, durations, cooldown, distances.
- `Config.Planting` - items, durations, growth stages/models, max trees per
  player, spacing, render distances.
- `Config.Items` - wood item, wood per log, ground item lifetime.
- `Config.Carry` - carry animation and log attach offsets.
- `Config.Wagon` - wagon model, capacity, log stacking positions.
- `Config.WagonSellLocations` - sell points (`name`, `coords`, `radius`, `price`, `blip`).
- `Config.Trees` - wild tree models that can be chopped.

## Localisation
All player-facing text (notifications, progress bars, target labels, prompts and
blip names) lives in `locales/*.json`, loaded by ox_lib. Included languages:
`en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

Set the language in your server.cfg with:
```
setr ox:locale de
```
To add a language, copy `locales/en.json` to `locales/<code>.json` and translate
the values (keep the keys, `%s` placeholders and `~e~`/`~s~` colour codes).
A sell point's blip name can be overridden per location with `blip.label`.

## Security
- All rewards (logs, wood, cash) are granted server-side only.
- Chopping uses a request -> progress -> complete handshake with server-side
  checks for axe ownership, cooldown, carry state, proximity and elapsed time,
  re-validated on completion.
- Drop positions, sell wagons and sell prices are resolved from the server-side
  ped/config, never from client data. Planting positions are range-checked.
- Wood piles and wagon loads are claimed before rewards are given, so duplicate
  events can't dupe items or cash.
- Wagon log counts are kept server-side; the wagon's state bag is only used to
  draw the logs, so a client editing it can't change what gets sold.

## Sync
- Carried logs and wagon log stacks are driven by replicated state bags, so
  players who join late or stream into range see them correctly.
- Carry state is cleared on disconnect, character logout and resource restart.

## Debug
`Config.Debug = true` enables console logging and `/spawnwagon`.

## Credits
Mack
