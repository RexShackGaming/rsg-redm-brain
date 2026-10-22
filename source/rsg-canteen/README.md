# rsg-canteen

Fill a canteen at water pumps with **ox_target** and drink from it to restore thirst.

## Features
- Target `p_waterpump01x` and `p_wellpumpnbx01x` to fill your canteen (option only shows if you carry one).
- A full canteen has **10 uses**; each drink restores **25 thirst** (capped at 100).
- Uses are stored per canteen in the item's metadata. Filling tops up your emptiest canteen first.
- Fill and drink animations, with a canteen prop held in hand while drinking.
- Progress bars can be cancelled; nothing is used or filled if cancelled.
- Server-side checks: pump distance, minimum fill/drink time, and drinking only after using the item, so the net events can't be spammed or triggered remotely.
- Translated into 10 languages using ox_lib locales, with a fully configurable `shared/config.lua`.

## Requirements
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)

## Installation
1. Place `rsg-canteen` in your resources folder.
2. Add the item to `rsg-core/shared/items.lua`. It **must** be `unique = true` so each canteen keeps its own uses:
```lua
canteen = { name = 'canteen', label = 'Canteen', weight = 500, type = 'item', image = 'canteen.png', unique = true, useable = true, shouldClose = true, description = 'A metal canteen for carrying water' },
```
3. Add a `canteen.png` image to `rsg-inventory/html/images/`.
4. Add `ensure rsg-canteen` to your server.cfg after its dependencies.

## Configuration
All settings are in `shared/config.lua`: item name, uses, thirst amount, timings, pump models, animations, and the prop model/offset/rotation.

## Languages
Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.
ox_lib picks the language from your server convar, e.g. in server.cfg:
```
setr ox:locale en
```
To add a language, copy `locales/en.json` to `locales/<code>.json` and translate the values (keep the `%s` placeholders).

## Support
If you enjoy this script, consider supporting development: https://buymeacoffee.com/rexshack
