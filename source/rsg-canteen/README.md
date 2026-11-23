# rsg-canteen (v3.1.0)

Fill a canteen at water pumps with **rsg-target**, or straight from rivers and lakes, and drink from it to restore thirst. Full technical reference in [DOCS.md](DOCS.md).

## Features
- Target `p_waterpump01x` and `p_wellpumpnbx01x` to fill your canteen (option only shows if you carry one).
- Stand in shallow river/lake water and hold **G** to fill (optional zone whitelist).
- **Canteen tiers:** `canteen` (10 uses) and `canteen_large` (20 uses). Add more tiers in `Config.Canteens`.
- Each drink restores thirst (default 25, capped at 100). Thirst is applied on the server through `rsg-hud`. Drinking at full thirst is refused so no use is wasted.
- **Water level in the inventory:** each canteen shows its remaining uses as a bar.
- **Dirty water:** river and lake water is unsafe. Drinking it restores less and may make you sick. Purify it by targeting a fire (the rsg-cooking campfire).
- **Give a drink:** target another player to share a drink from your canteen.
- **Water your horse:** with `rsg-stables`, *Water Horse* can use a canteen when you have no bucket.
- **Weather:** hot, high-pressure and sandstorm weather restore less thirst per drink (configurable).
- **Pump verification (optional):** the server only accepts pump fills at registered pumps (admin command, plus rsg-wellpump pumps).
- **Pump fee (optional):** charge a price per pump fill (needs pump verification).
- Fill and drink animations, with a canteen prop in hand while drinking.
- Progress bars can be cancelled; nothing is used or filled if cancelled. Actions are blocked while mounted, swimming, in a vehicle or dead.
- Server-side checks on every action: distance, minimum action time, pending-action state, so net events cannot be spammed or triggered remotely.
- No ox_lib: uses rsg-core locales, notify, callbacks and progress bar. 11 languages.

## Requirements
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [rsg-target](https://github.com/Rexshack-RedM/rsg-target)
- [oxmysql](https://github.com/overextended/oxmysql)
- Recommended: [rsg-hud](https://github.com/Rexshack-RedM/rsg-hud) (thirst is written through it), [rsg-weather](https://github.com/Rexshack-RedM/rsg-weather)
- Optional: [rsg-cooking](https://github.com/Rexshack-RedM/rsg-cooking) (campfire for purifying), [rsg-wellpump](https://github.com/Rexshack-RedM/rsg-wellpump), [rsg-stables](https://github.com/Rexshack-RedM/rsg-stables)

## Installation
1. Place `rsg-canteen` in your resources folder.
2. Add the items to `rsg-core/shared/items.lua`. They **must** be `unique = true` so each canteen keeps its own water:
```lua
canteen       = { name = 'canteen',       label = 'Canteen',       weight = 100, type = 'item', image = 'canteen.png',       unique = true, useable = true, shouldClose = true, description = 'Water Canteen',       category = 'tools' },
canteen_large = { name = 'canteen_large', label = 'Large Canteen', weight = 150, type = 'item', image = 'canteen_large.png', unique = true, useable = true, shouldClose = true, description = 'Large Water Canteen', category = 'tools' },
```
3. Add `canteen.png` and `canteen_large.png` to `rsg-inventory/html/images/`.
4. Add `ensure rsg-canteen` to your server.cfg after its dependencies.
5. The database table is created automatically on first start. To install manually, set `Config.AutoDatabase = false` and import `install.sql`.

## Configuration
All settings are in `shared/config.lua`.

| Option | Default | Description |
|---|---|---|
| `AutoDatabase` | `true` | Create the table on start; `false` to import `install.sql` |
| `Canteens` | 2 tiers | Item name -> `maxUses`, `thirst` per drink |
| `MaxThirst` | `100` | Thirst cap |
| `FillTime` / `DrinkTime` | `5000` / `3000` | Progress bar ms |
| `TargetDistance`, `PumpModels` | `2.0`, 2 models | Pump targeting |
| `WaterFill` | table | River/lake fill: `Enabled`, `Key` (G), `CheckEvery`, `AllowedZones` |
| `DirtyWater` | table | `Enabled`, `SickChance`, `Damage`, `MinHealth`, `ThirstFactor` |
| `Purify` | table | `Enabled`, `Time`, `Models` (fire props) |
| `Share` | table | `Enabled`, `Distance`, `Time` |
| `WeatherThirst` | table | `Enabled`, `Multipliers` per rsg-weather type |
| `PumpVerify` | table | `Enabled`, `Radius`, `UseWellpump`, `Permission` |
| `PumpFee` | table | `Enabled`, `Price`, `Account` (needs `PumpVerify.Enabled`) |
| `FillAnim`, `DrinkAnim` | tables | `dict`, `clip` |
| `CanteenProp`, `PropBone`, `PropOffset`, `PropRotation` | | Held prop |

## How to use
- **Fill:** target a pump, or hold **G** in shallow river/lake water. Pump water is clean, river water is dirty.
- **Drink:** use the canteen from your inventory.
- **Purify:** target a fire (rsg-cooking campfire) while carrying a dirty canteen.
- **Give a drink:** target another player nearby.
- **Admin, pump verification:** stand at a map pump and run `/canteenaddpump`; `/canteenremovepump` removes the nearest saved one. Both need `Config.PumpVerify.Permission`. Then set `PumpVerify.Enabled = true`.

## Languages
Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`.
rsg-core picks the language from your server convar, e.g. in server.cfg:
```
setr rsg:locale en
```
To add a language, copy `locales/en.json` to `locales/<code>.json` and translate the values (keep the `%s` placeholders in the same order).

## Support
If you enjoy this script, consider supporting development: https://buymeacoffee.com/rexshack
