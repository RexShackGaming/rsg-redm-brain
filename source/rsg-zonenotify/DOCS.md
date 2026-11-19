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
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

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

`Config.ZoneMessages` maps a label key to a locale key. Add the locale key to all 11 locale files:
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

Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-zonenotify 3.2.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `oxmysql`

### Database

Tables: `zonenotify_discoveries`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `install.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.CheckInterval` | `500` | ms between zone checks |
| `Config.DisplayTime` | `5000` | ms the banner stays on screen |
| `Config.DisplayMode` | `'nui'` | 'nui' = custom banner (works while riding), 'native' = RDR2 location banner, 'notify' = rsg-core notify |
| `Config.WhileMoving` | `'native'` | 'notify' = rsg-core notify when moving, 'wait' = banner once the player slows down, 'native' = always try the  |
| `Config.MovingSpeed` | `1.5` | m/s; above this the player counts as moving |
| `Config.MaxFeedWait` | `3000` | native only: ms to wait for a busy feed before showing the banner anyway |
| `Config.Debug` | `false` | print zone hashes to F8 when they change and enable /zonetest |
| `Config.Notify` | `table` | which zone changes show a banner automatically |
| `Config.State` | `true` |  |
| `Config.District` | `true` |  |
| `Config.Town` | `true` |  |
| `Config.LeaveTown` | `true` |  |
| `Config.ShowTime` | `true` |  |
| `Config.NightStart` | `22` | hour the night colour starts |
| `Config.NightEnd` | `6` | hour the night colour ends |
| `Config.TimeDayColor` | `'~COLOR_WHITE~'` |  |
| `Config.TimeNightColor` | `'~COLOR_BLUEDARK~'` |  |
| `Config.ShowTemperature` | `true` |  |
| `Config.TemperatureUnit` | `'celsius'` | 'celsius', 'fahrenheit' or 'auto' (follows the player's game metric setting) |
| `Config.TemperatureColdDegree` | `15` | celsius; below this uses the cold colour |
| `Config.TemperatureHotColor` | `'~COLOR_YELLOWSTRONG~'` |  |
| `Config.TemperatureColdColor` | `'~COLOR_BLUE~'` |  |
| `Config.ShowWind` | `true` |  |
| `Config.SpeedUnit` | `'mph'` | 'mph', 'kmh' or 'auto' (follows the player's game metric setting) |
| `Config.WindColor` | `'~COLOR_RADAR_CENTER_BLIP~'` |  |
| `Config.Key` | `false` | e.g. 0x80F28E95 (L); false = no keybind |
| `Config.Command` | `'location'` | false to disable |
| `Config.ToggleCommand` | `'zonenotify'` | players turn auto banners on/off (saved per player); false to disable |
| `Config.ManualCooldown` | `3000` | ms between manual checks |
| `Config.NuiColors` | `table` |  |
| `Config.COLOR_WHITE` | `'#f2f2f2'` |  |
| `Config.COLOR_BLUEDARK` | `'#6f8fc9'` |  |
| `Config.COLOR_BLUE` | `'#8fb8e8'` |  |
| `Config.COLOR_YELLOWSTRONG` | `'#d9a441'` |  |
| `Config.COLOR_RADAR_CENTER_BLIP` | `'#9a9a9a'` |  |
| `Config.LabelNames` | `table` |  |
| `Config.HOMESTEAD_MACLEANS_HOUSE` | `"MacLean's House"` |  |
| `Config.HOMESTEAD_WATSONS_CABIN` | `"Watson's Cabin"` |  |
| `Config.LANDMARK_BERYLS_DREAM` | `"Beryl's Dream"` |  |
| `Config.LANDMARK_RILEYS_CHARGE` | `"Riley's Charge"` |  |
| `Config.LANDMARK_LUCKYS_CABIN` | `"Lucky's Cabin"` |  |
| `Config.LANDMARK_RADLEYS_PASTURE` | `"Radley's Pasture"` |  |
| `Config.LANDMARK_GRANGERS_HOGGERY` | `"Granger's Hoggery"` |  |
| `Config.LANDMARK_MONTOS_REST` | `"Monto's Rest"` |  |
| `Config.LANDMARK_QUAKERS_COVE` | `"Quaker's Cove"` |  |
| `Config.LANDMARK_MILLESANI_CLAIM` | `"Millesani Claim"` |  |
| `Config.LANDMARK_JORGES_GAP` | `"Jorge's Gap"` |  |
| `Config.LANDMARK_BARDS_CROSSING` | `"Bard's Crossing"` |  |
| `Config.LANDMARK_CALIBANS_SEAT` | `"Caliban's Seat"` |  |
| `Config.LANDMARK_SOLOMONS_FOLLY` | `"Solomon's Folly"` |  |
| `Config.HIDEOUT_SOLOMONS_FOLLY` | `"Solomon's Folly"` |  |
| `Config.HOMESTEAD_LONNIES_SHACK` | `"Lonnie's Shack"` |  |
| `Config.HOMESTEAD_WILLARDS_REST` | `"Willard's Rest"` |  |
| `Config.HOMESTEAD_CATFISH_JACKSONS` | `"Catfish Jackson's"` |  |
| `Config.HOMESTEAD_COMPSONS_STEAD` | `"Compson's Stead"` |  |
| `Config.HOMESTEAD_SHEPHERDS_RISE` | `"Shepherd's Rise"` |  |
| `Config.HOMESTEAD_CHEZ_PORTER` | `'Chez Porter'` |  |
| `Config.SETTLEMENT_COOTS_CHAPEL` | `"Coot's Chapel"` |  |
| `Config.SETTLEMENT_THIEVES_LANDING` | `"Thieves' Landing"` |  |
| `Config.SETTLEMENT_AGUASDULCES` | `'Aguasdulces'` |  |
| `Config.SETTLEMENT_SISIKA_PENITENTIARY` | `'Sisika Penitentiary'` |  |
| `Config.TOWN_SAINTDENIS` | `'Saint Denis'` |  |
| `Config.TOWN_VANHORN` | `'Van Horn'` |  |
| `Config.TOWN_MACFARLANES_RANCH` | `"MacFarlane's Ranch"` |  |
| `Config.WATER_OCREAGHS_RUN` | `"O'Creagh's Run"` |  |
| `Config.WATER_FLAT_IRON_LAKE` | `'Flat Iron Lake'` |  |
| `Config.WATER_KAMASSA_RIVER_BLUEWATER_MARSH` | `'Kamassa River'` |  |
| `Config.WATER_KAMASSA_RIVER_BAYOU_NWA` | `'Kamassa River'` |  |
| `Config.WATER_SAN_LUIS_RIVER_NEW_AUSTIN` | `'San Luis River'` |  |
| `Config.WATER_SEA_OF_CORONADO` | `'Sea of Coronado'` |  |
| `Config.WATER_BAHIA_DE_LA_PAZ` | `'Bahía de la Paz'` |  |
| `Config.LANDMARK_HEARTLAND_OVERFLOW` | `'Heartland Overflow'` |  |
| `Config.LANDMARK_BRITTLEBUSH_TRAWL` | `'Brittlebrush Trawl'` |  |
| `Config.STATE_AMBARINO` | `'Ambarino'` |  |
| `Config.AutoDatabase` | `true` | create the table automatically; set false to import install.sql manually |
| `Config.Discovery` | `table` |  |
| `Config.Enabled` | `true` |  |
| `Config.ShowStamp` | `true` |  |
| `Config.Landmarks` | `true` |  |
| `Config.MaxPerPlayer` | `1000` |  |
| `Config.Sound` | `table` |  |
| `Config.Volume` | `0.25` |  |
| `Config.Files` | `table` |  |
| `Config.ZoneMessages` | `table` |  |
| `Config.HideWhileScriptedCam` | `true` |  |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `ShowBanner` | `target, title, subtitle, duration` | `server/server.lua` |
| `GetDiscoveryCount` | `citizenid` | `server/server.lua` |
| `HasDiscovered` | `citizenid, zone` | `server/server.lua` |

**Client**

| Export | Arguments | File |
|---|---|---|
| `ShowCurrentLocation` | `` | `client/client.lua` |
| `ShowBanner` | `` | `client/client.lua` |
| `SetSuppressed` | `` | `client/client.lua` |
| `IsDiscovered` | `key` | `client/client.lua` |
| `GetDiscoveryCount` | `` | `client/client.lua` |

```lua
-- example
local result = exports['rsg-zonenotify']:ShowBanner(target, title, subtitle, duration)
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-zonenotify:server:getDiscoveries` | server | `source, cb` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-zonenotify:server:getDiscoveries', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |
| `rsg-zonenotify:client:showBanner` | client | `data` | `client/client.lua` |
| `rsg-zonenotify:server:discover` | server | `zone` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-zonenotify:server:discover', zone)
-- from a server script
TriggerClientEvent('RSGCore:Client:OnPlayerLoaded', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/zonetest` |  | `client/client.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
