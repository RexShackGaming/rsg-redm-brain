# rsg-zonenotify

**Version 3.3.0** · Dependencies: rsg-core, oxmysql · Full reference: [DOCS.md](DOCS.md)

Shows a Red Dead style location banner when a player rides into a new state, district or town, with the in-game time, temperature and wind underneath. Built for the RSG Framework, based on [vorp_zonenotify](https://github.com/VORPCORE/vorp_zonenotify).

## Features
- **New Discovery** stamp the first time each character visits a state, district, town, landmark, lake or river (saved in the database); `/places` shows how many you've found
- Optional one-time banners for landmarks, lakes and rivers you ride past
- Soft chime per zone type (built-in, no files needed) or your own .ogg/.mp3 sounds
- Flavour lines under the title per place (e.g. New Austin: *Lawless territory*)
- Banner hides itself while a scripted camera runs (rsg-moviemaker, cutscenes); other scripts can hide it too
- Export so other scripts (rsg-ferry, rsg-trams, rsg-guarma...) can show their own arrival banner
- Custom NUI banner styled like the game's own (works while riding); native banner or rsg-core notify still available via `DisplayMode`
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
en, de, el, es, fr, ja, nl, pl, pt-br, ro (`locales/`). Set your server language with `setr rsg:locale "de"` in server.cfg. Zone names are the game's own place labels, so they aren't in these files.

No items are needed. The `zonenotify_discoveries` table is created automatically on first start; to install it manually set `Config.AutoDatabase = false` and import `install.sql`.

## Install
1. Put `rsg-zonenotify` in your resources folder
2. Add `ensure rsg-zonenotify` after `rsg-core` and `oxmysql` (ox_lib is no longer needed)
3. Adjust `shared/config.lua`

## Config
| Option | Default | What it does |
|---|---|---|
| `CheckInterval` | `500` | ms between zone checks |
| `DisplayTime` | `5000` | ms the banner stays on screen |
| `DisplayMode` | `'nui'` | `'nui'` custom banner, `'native'` game banner, `'notify'` rsg-core notify |
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
| `AutoDatabase` | `true` | create the table on start |
| `Discovery.Enabled` / `ShowStamp` / `Landmarks` | `true` | discovery tracking, stamp, landmark banners |
| `Discovery.Command` | `'places'` | discovery count command, `false` to disable |
| `Discovery.MaxPerPlayer` | `1000` | server cap per character |
| `Sound.Enabled` / `Volume` | `true` / `0.25` | banner sounds |
| `Sound.Files` | | per kind: `nil` = chime, `'sounds/x.ogg'` = file, `false` = silent |
| `ZoneMessages` | | label key = locale key for a flavour line |
| `HideWhileScriptedCam` | `true` | hide the banner while a scripted camera renders |

## Exports (short)
```lua
-- server: arrival banner for a player (-1 = everyone)
exports['rsg-zonenotify']:ShowBanner(src, 'Guarma', 'You step off the boat', 6000)
-- client
exports['rsg-zonenotify']:ShowCurrentLocation()
exports['rsg-zonenotify']:SetSuppressed(GetCurrentResourceName(), true) -- hide while your camera runs
```
All exports are listed in [DOCS.md](DOCS.md).

## Dependencies
- rsg-core
- oxmysql

## Credits
- Zone data and banner code: freedy69 / Bytesized

Support: https://buymeacoffee.com/rexshack
