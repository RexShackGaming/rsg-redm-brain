# rsg-canteen

Fill a canteen at water pumps with **rsg-target**, or straight from rivers and lakes, and drink from it to restore thirst.

## Features
- Target `p_waterpump01x` and `p_wellpumpnbx01x` to fill your canteen (option only shows if you carry one).
- Stand in shallow river/lake water and hold **G** to fill (optional zone whitelist).
- A full canteen has **10 uses**; each drink restores **25 thirst** (capped at 100).
- Uses are stored per canteen in the item's metadata. Filling tops up your emptiest canteen first.
- Fill and drink animations, with a canteen prop held in hand while drinking.
- Progress bars can be cancelled; nothing is used or filled if cancelled.
- Server-side checks: fill distance, minimum fill/drink time, and drinking only after using the item, so the net events can't be spammed or triggered remotely. Stale actions expire so a crash mid-drink never locks a player out.
- No ox_lib: uses rsg-core locales, notify, callbacks and progress bar.
- Translated into 10 languages, with a fully configurable `shared/config.lua`.

## Requirements
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [rsg-target](https://github.com/Rexshack-RedM/rsg-target)

## Installation
1. Place `rsg-canteen` in your resources folder.
2. Add the item to `rsg-core/shared/items.lua`. It **must** be `unique = true` so each canteen keeps its own uses:
```lua
canteen = { name = 'canteen', label = 'Canteen', weight = 500, type = 'item', image = 'canteen.png', unique = true, useable = true, shouldClose = true, description = 'A metal canteen for carrying water' },
```
3. Add a `canteen.png` image to `rsg-inventory/html/images/`.
4. Add `ensure rsg-canteen` to your server.cfg after its dependencies.

## Configuration
All settings are in `shared/config.lua`: item name, uses, thirst amount, timings, pump models, water filling, animations, and the prop model/offset/rotation.

## Languages
Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.
rsg-core picks the language from your server convar, e.g. in server.cfg:
```
setr rsg:locale en
```
To add a language, copy `locales/en.json` to `locales/<code>.json` and translate the values (keep the `%s` placeholders).

## Support
If you enjoy this script, consider supporting development: https://buymeacoffee.com/rexshack
