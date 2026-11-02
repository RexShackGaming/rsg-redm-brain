# rsg-zonenotify – Docs (v3.3.0)

## Contents
1. Files
2. How it works
3. Display modes
4. Discoveries
5. Sounds and flavour lines
6. Hiding the banner
7. Exports and events
8. Commands
9. Database
10. Security
11. Server owner how-tos
12. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; locales via `@rsg-core/shared/locale.lua` |
| `shared/config.lua` | All settings |
| `client/client.lua` | Zone tables, zone checks, banners, discoveries, commands, client exports |
| `client/dataview.lua` | Buffer helper, only used by the native banner |
| `server/server.lua` | Discovery storage, auto database, server exports |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI banner, stamp, flavour line, sounds (`html/sounds/` for your own files) |
| `install.sql` | Manual database install |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## 2. How it works
Every `Config.CheckInterval` ms the client reads the map zone hashes for state, district and town (`_GET_MAP_ZONE_AT_COORDS`, 0x43AD8FC02B429D33). When one changes it queues the most specific mapped zone (town > district > state). With `Discovery.Landmarks` it also checks water and landmark zones and queues a banner for any the character hasn't found yet. A queued banner waits while something blocks it (pause menu, faded screen, dead, disabled, suppressed) and is dropped if the player leaves that zone (or rides 150 m away from a landmark).

Names come from `GetLabelText`, a readable fallback, or `Config.LabelNames`.

## 3. Display modes
| `DisplayMode` | Result |
|---|---|
| `nui` | Custom banner with stamp and flavour line |
| `native` | RDR2 location shard; stamp/flavour are added to the bottom line. The game skips it while moving (`WhileMoving`) |
| `notify` | rsg-core notification |

## 4. Discoveries
- Stored per character (citizenid) as lower-case label keys, e.g. `town_valentine`, `water_flat_iron_lake`.
- Loaded on character load; the first banner for an unknown key shows the **New Discovery** stamp and plays the `discovery` sound.
- `/places` shows the count.

## 5. Sounds and flavour lines
Sound kinds: `state`, `district`, `town`, `landmark`, `discovery`, `manual`, `custom`. Each `Config.Sound.Files[kind]` is `nil` (built-in WebAudio chime), a path like `'sounds/town.ogg'` (put the file in `html/sounds/`), or `false` (silent).

`Config.ZoneMessages` maps a label key to a locale key. Add the locale key to all 10 locale files:
```lua
Config.ZoneMessages = { town_valentine = 'zone_msg_valentine' }
```

## 6. Hiding the banner
The banner is hidden and nothing new is shown while any of these is true:
- `Config.HideWhileScriptedCam` and a scripted camera is rendering (`GET_RENDERING_CAM` 0x03A8931ECC8015D6)
- a resource called `SetSuppressed(reason, true)` (cleared automatically when a resource named `reason` stops)
- `LocalPlayer.state.hideZoneBanner` is true

## 7. Exports and events
### Server
| Export | Returns | Notes |
|---|---|---|
| `ShowBanner(target, title, subtitle?, duration?)` | bool | `target` = server id or `-1`; duration clamped 1000–15000 ms |
| `GetDiscoveryCount(citizenid)` | number | |
| `HasDiscovered(citizenid, zoneKey)` | bool | key is case-insensitive |

### Client
| Export | Returns |
|---|---|
| `ShowCurrentLocation()` | – |
| `ShowBanner(title, subtitle?, duration?)` | bool (false if disabled/suppressed) |
| `SetSuppressed(reason, state)` | – |
| `IsDiscovered(zoneKey)` | bool |
| `GetDiscoveryCount()` | number |

### Events and callbacks
| Name | Side | Notes |
|---|---|---|
| `rsg-zonenotify:client:showBanner` | client net event | `{ title, subtitle, duration }`; server only |
| `rsg-zonenotify:server:discover` | server net event | `(zoneKey)`; validated and rate-limited |
| `rsg-zonenotify:server:getDiscoveries` | callback | returns the character's keys |

Example (rsg-ferry arrival):
```lua
exports['rsg-zonenotify']:ShowBanner(src, 'Saint Denis', 'Ferry landing', 6000)
```

## 8. Commands
| Command | Who | What |
|---|---|---|
| `/location` | everyone | show current place incl. landmarks, water and caves |
| `/zonenotify` | everyone | turn auto banners on/off (client KVP) |
| `/places` | everyone | number of places discovered |
| `/zonetest [sec]` | only with `Config.Debug` | test banner |

## 9. Database
```sql
CREATE TABLE IF NOT EXISTS `zonenotify_discoveries` (
    `citizenid` VARCHAR(50) NOT NULL,
    `zone` VARCHAR(64) NOT NULL,
    `discovered_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `zone`)
);
```
Created on start when `Config.AutoDatabase = true`; otherwise import `install.sql`. Discoveries are cached per character and cleared when the player drops.

## 10. Security
Discoveries are cosmetic (no money or items). The server still checks: player exists, key is a string of max 64 chars `[A-Za-z0-9_]`, one discovery per second per player, `Discovery.MaxPerPlayer` cap, `INSERT IGNORE` with `?` params. Custom banners can only be sent by the server. If you ever reward players for discoveries, validate the zone server-side (e.g. check the player's coords) before paying out.

## 11. How-tos
- Wrong name: turn on `Config.Debug`, read the label key, add it to `Config.LabelNames`.
- Reset a character's discoveries: `DELETE FROM zonenotify_discoveries WHERE citizenid = 'ABC12345';`
- Language: `setr rsg:locale "de"` in server.cfg.
- Hide during your own camera script: `exports['rsg-zonenotify']:SetSuppressed(GetCurrentResourceName(), true)` / `false` when done.

## 12. Troubleshooting
| Problem | Fix |
|---|---|
| No banner at all | Player may have used `/zonenotify`; run it again |
| No stamp ever | Check the console for "database tables ready"; `Discovery.Enabled` |
| Banner never shows during a scene | Expected: a scripted camera is rendering; set `HideWhileScriptedCam = false` to allow it |
| Custom sound silent | File must be in `html/sounds/` and the path in config must start with `sounds/` |
| Locale keys shown as text | Start rsg-core first; add new `ZoneMessages` keys to every locale file |

Support: https://buymeacoffee.com/rexshack
