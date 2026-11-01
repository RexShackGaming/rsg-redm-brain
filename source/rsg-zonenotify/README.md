# rsg-zonenotify

Shows a Red Dead style location banner when a player rides into a new state, district or town, with the in-game time, temperature and wind underneath. Built for the RSG Framework, based on [vorp_zonenotify](https://github.com/VORPCORE/vorp_zonenotify).

## Features
- Custom NUI banner styled like the game's own (works while riding); native banner or ox_lib notify still available via `DisplayMode`
- Separate toggles for state, district and town banners
- Time (12/24h), temperature (°C/°F) and wind follow the player's game settings
- If two zones change at once, only the most specific one is shown (town > district > state)
- A banner that can't show yet (another banner on screen, pause menu, screen faded) waits and shows once it can, as long as you're still in that zone
- No banner on spawn or character load, while dead, or in the pause menu
- `/location` (or an optional keybind) shows exactly where you are, including landmarks, lakes, rivers and caves
- `/zonenotify` lets each player turn the automatic banners off or on; the choice is saved on their PC
- Client-only and lightweight: one check every 500 ms (no per-frame loop), lookup tables built once
- Place names come from the game's labels, with a readable fallback and `Config.LabelNames` overrides for anything that looks wrong

## Languages
en, de, el, es, fr, ja, nl, pl, pt-br, ro (`locales/`). Set your server language with `setr ox:locale "de"` in server.cfg. Zone names are the game's own place labels, so they aren't in these files.

## Install
1. Put `rsg-zonenotify` in your resources folder
2. Add `ensure rsg-zonenotify` after `rsg-core` and `ox_lib`
3. Adjust `shared/config.lua`

## Config
| Option | Default | What it does |
|---|---|---|
| `CheckInterval` | `500` | ms between zone checks |
| `DisplayTime` | `5000` | ms the banner stays on screen |
| `DisplayMode` | `'nui'` | `'nui'` custom banner, `'native'` game banner, `'notify'` ox_lib notify |
| `NuiColors` | | colours used for the bottom line in the custom banner |
| `Notify.State/District/Town` | `true` | which zone changes show a banner |
| `Notify.LeaveTown` | `true` | show the district banner again when leaving a town |
| `WhileMoving` | `'native'` | native mode only: `'notify'`, `'wait'` or `'native'` while riding |
| `LabelNames` | | fix how a place name is displayed |
| `Debug` | `false` | print zone hashes to F8 and enable `/zonetest` |
| `ShowTime` / `ShowTemperature` / `ShowWind` | `true` | bottom line info |
| `Key` | `false` | keybind for "where am I", e.g. `0x80F28E95` (L) |
| `Command` | `'location'` | "where am I" command, `false` to disable |
| `ToggleCommand` | `'zonenotify'` | per-player on/off command, `false` to disable |
| `ManualCooldown` | `3000` | ms between manual checks |

## Export (client)
```lua
exports['rsg-zonenotify']:ShowCurrentLocation()
```

## Dependencies
- rsg-core
- ox_lib

## Credits
- Zone data and banner code: freedy69 / Bytesized

Support: https://buymeacoffee.com/rexshack
