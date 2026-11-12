# rsg-weather

Time, weather and wind sync for **RSG Framework** (RedM), with no ox_lib dependency (locales, notify, callbacks and commands all use rsg-core).
A drop-in replacement for `weathersync` — every old export and event keeps working.

## Features
- Server-authoritative time, weather and wind synced to all players through `GlobalState` (late joiners are in sync instantly)
- Regional weather (snow in the north, sandstorms in the desert, no snow on Guarma), snow on the ground, wind that changes with altitude
- Weather patterns: chance-based weather chains, plus a **pattern builder** in the admin panel (named patterns, saved to `patterns.json`)
- **Seasonal events** switched by the real date: Halloween (fog/mist + blood-moon weather variations at night) and Christmas (snow + snow on the ground)
- NUI admin panel (`/weatherui`) and a player forecast overlay (`/forecast`) in the RDR2 leather & gold theme
- **Discord webhooks**: admin actions, security alerts, patterns, seasons, a scheduled "Weather Bulletin"
- **10 languages**: en, de, el, es, fr, ja, nl, pl, pt-br, ro
- Full backward compatibility with `weathersync` exports/events (old client→server events are now admin-checked)

## Requirements
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [oxmysql](https://github.com/overextended/oxmysql) (stores the season mode in a small `rsg_weather_state` table, created automatically, no SQL to import)

## Installation
1. **Stop and remove the old `weathersync` resource** (this resource `provide`s that name).
2. Put `rsg-weather` in your resources folder.
3. Add to `server.cfg` (after oxmysql and rsg-core):
   ```
   ensure oxmysql
   ensure rsg-core
   ensure rsg-weather
   ```
4. Optional — language and Discord (see below):
   ```
   setr rsg:locale "en"
   set rsg_weather_webhook "https://discord.com/api/webhooks/..."
   ```
After changing `fxmanifest.lua` always run `refresh` before `ensure rsg-weather`.

## Commands
| Command | Who | Description |
|---|---|---|
| `/forecast` | everyone | Toggle the forecast overlay (doesn't take mouse focus, hides in the pause menu) |
| `/weatherui` | admin | Open the admin panel (weather, time, wind, season, patterns) |
| `/weather <type> [transition] [freeze 0/1] [snow 0/1]` | admin | Set the weather |
| `/time [day hour minute second transitionMs freeze]` | admin | Set or show the time (day 0 = Sunday) |
| `/timescale [scale]` | admin | In-game seconds per real second (0 = real clock) |
| `/wind <direction> [speed] [freeze]` | admin | Set wind |
| `/syncdelay [ms]` | admin | How often the server syncs clients |
| `/season [auto\|off\|halloween\|christmas]` | admin | Seasonal event mode (remembered across restarts) |
| `/bloodmoon` | admin | Force the blood moon on/off for testing and print diagnostics |
| `/weathersync` | admin | Toggle sync for yourself |
| `/mytime <h> [m s ms]`, `/myweather <type> [transition snow]` | admin | Local override (turns your sync off) |
| `/weatherwebhook test\|forecast` | admin | Send Discord test messages / post the bulletin now |

Admin = any RSG permission level in `Config.AdminPermissions` (default `god`, `admin`).

## Timescale examples
The timescale is **how many in-game seconds pass per real second**. Set it in the admin panel: `/weatherui` → **Time** tab → **Timescale (0 = real clock)** → **Set Timescale**. It applies to everyone instantly.

Quick maths: `real minutes per in-game day = 1440 / timescale`, so `timescale = 1440 / the day length you want in minutes`.

| Timescale | In-game day lasts | In-game hour lasts | Weather changes every* | Good for |
|---|---|---|---|---|
| `0` | 24 h | 60 min | 60 min | Real clock: in-game time and weekday follow the server machine's clock (shift it with `Config.RealTimeOffset`) |
| `1` | 24 h | 60 min | 60 min | Real speed, but you choose the starting time (not tied to the real clock) |
| `2` | 12 h | 30 min | 30 min | Slow, immersive RP: a long session sees one sunrise or sunset |
| `4` | 6 h | 15 min | 15 min | **Default.** Four in-game days per real day |
| `6` | 4 h | 10 min | 10 min | A full day/night cycle in one evening session |
| `8` | 3 h | 7 min 30 s | 7 min 30 s | Shorter sessions, still relaxed |
| `12` | 2 h | 5 min | 5 min | Busy servers where everyone should see day and night |
| `24` | 1 h | 2 min 30 s | 2 min 30 s | One in-game day per real hour |
| `30` | 48 min | 2 min | 2 min | Same speed as RDR2 story mode |
| `60` | 24 min | 1 min | 1 min | Events, quick showcase of day/night |
| `360` | 4 min | 10 s | 10 s | Testing night-only features, seasons, blood moon |
| `1000` | ~1 min 26 s | 3.6 s | 3.6 s | Maximum. Stress testing only |

\* With the default `Config.WeatherInterval` of 1 in-game hour. Weather follows in-game time, so a faster clock also means faster weather changes. To keep slow weather on a fast clock, raise `WeatherInterval` (e.g. `DHMSToTime(0, 6, 0, 0)` at timescale `24` = a change every 15 real minutes).

### Other ways to set it
```
/timescale 30                                  -- command (admin)
/timescale                                     -- show the current value
```
```lua
Config.Timescale = 30                          -- shared/config.lua (value used on every restart)
exports['rsg-weather']:setTimescale(30)        -- from another server script
exports['rsg-weather']:resetTimescale()        -- back to Config.Timescale
```

### Good to know
- A timescale set in the panel, by command or by export **lasts until the resource restarts**. For a permanent change, edit `Config.Timescale`.
- Allowed range is `0`–`1000`. To stop the clock completely, tick **Freeze time** instead (timescale `0` means real clock, not paused).
- At timescale `0` the Day / Hour / Minute fields are overwritten by the real clock on the next sync, unless time is frozen.
- Time only moves in whole in-game seconds per sync, so `timescale × sync delay (in seconds)` should be a whole number. At the default 5000 ms sync delay, whole numbers are always fine; `0.5` actually runs at `0.4` and anything below `0.2` stops the clock.

## Configuration
### `shared/config.lua`
| Option | Default | Description |
|---|---|---|
| `AdminPermissions` | `{ 'god', 'admin' }` | RSG permission levels allowed to use admin features |
| `SyncDelay` | `5000` | ms between syncs |
| `Time` / `Timescale` / `TimeIsFrozen` | Sun 06:00 / `4` / `false` | Start time, speed, frozen |
| `RealTimeOffset` | `0` | Seconds offset when `Timescale = 0` |
| `Weather` / `WeatherInterval` / `WeatherIsFrozen` | `sunny` / 1 in-game hour / `false` | Start weather and how often it changes |
| `PermanentSnow` / `DynamicSnow` | `false` / `true` | Snow on the ground always / in snowy areas and weather |
| `MaxForecast` | `23` | Forecast length (in weather intervals) |
| `RegionalWeather` | `true` | Translate weather per region |
| `Wind*` | | Start wind, freezing and altitude shear |
| `WeatherPattern` | | Default pattern (each block must total 100) |
| `EnableLegacyNetEvents` | `true` | Accept old `weathersync:*` net events from clients (admin-checked) |
| `Seasonal` | | Seasonal events (see below) |

### Seasonal events
Defined in `Config.Seasonal.Events`. Date ranges are inclusive and may wrap the year.

| Event | Dates (current config) | Behaviour |
|---|---|---|
| Halloween 🎃 | 15 Oct – 1 Nov | Fog / misty / shower / thunderstorm pattern; between `night.fromHour` and `night.toHour` (20:00–05:00) weather uses the game's `_MP_Pred` blood-moon variations |
| Christmas ❄ | 1 Dec – 27 Dec | Snow / light snow / blizzard pattern, permanent snow on the ground |

- Only fog, misty, shower and thunderstorm have a blood-moon variation, so the Halloween pattern uses just those.
- For blood-moon weather all day set `fromHour = 0, toHour = 24`.
- When an event ends, the weather returns to `Config.Weather` and the admin's active saved pattern.
- Add your own events with the same fields (`start`, `finish`, `startWeather`, `permanentSnow`, `pattern`, optional `night`).

### Weather patterns (admin panel → Patterns)
- `default` is `Config.WeatherPattern` (can be copied, not edited).
- Build a pattern: name it, add a block per weather, set what can follow and the % chance (each block must total 100; bars turn green). Every weather used as a "next" needs its own block — the editor flags missing ones.
- **Save** / **Save & Apply**, **Apply** switches instantly. Saved to `patterns.json` in the resource folder and restored on restart.

## Discord webhooks
Configure in `server/sv_webhooks_config.lua` (server-only, never sent to clients) or in `server.cfg` (takes priority):
```
set rsg_weather_webhook          "https://discord.com/api/webhooks/..."   # default for every category
set rsg_weather_webhook_security "https://discord.com/api/webhooks/..."   # optional, per category
```
Use `set`, **not** `setr` (`setr` sends the value to every player).

| Category | Logs | Default |
|---|---|---|
| `admin` | Weather/time/timescale/wind/sync/season/reset changes from commands, the panel, legacy events and other resources' exports | on |
| `security` | Unauthorised attempts to use admin features | on |
| `patterns` | Pattern saved (with full table), deleted, applied | on |
| `season` | Seasonal event start / end | on |
| `weather` | Every natural weather change | off (noisy) |
| `forecast` | Scheduled "Weather Bulletin" | on, every 180 min |
| `system` | Resource start / stop | on |

- Each category can have its own webhook, colour and `ping` (e.g. `<@&roleId>`). Only that ping notifies anyone — player mentions inside logs never ping.
- Logs show the player's name, server ID, character name, CitizenID and Discord (license optional, off by default).
- Messages are queued and batched (max 10 embeds / 6000 characters), respect Discord rate limits and retry on HTTP 429.
- The footer uses `sv_projectName` unless `ServerName` is set.

## Languages
Set with `setr rsg:locale "<code>"` (falls back to `ox:locale`): `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.
Everything is translated: notifications, command help, admin panel, forecast, weather/day/compass names, pattern errors and Discord logs. Missing keys fall back to English.
To add a language, copy `locales/en.json` to `locales/<code>.json` and translate the values, keeping `%s` / `%d` placeholders in the same order.

## Exports
### Server
Same names as `weathersync` — callable as `exports['rsg-weather']:x()` **or** `exports.weathersync:x()`:

`getTime()`, `setTime(day, hour, minute, second, transitionMs, freeze)`, `resetTime()`,
`getTimescale()`, `setTimescale(scale)`, `resetTimescale()`,
`getWeather()`, `setWeather(weather, transition, freeze, permanentSnow)`, `resetWeather()`,
`setWeatherPattern(pattern)` (returns `false` if invalid), `resetWeatherPattern()`,
`getWind()`, `setWind(direction, speed, freeze)`, `resetWind()`,
`getSyncDelay()`, `setSyncDelay(ms)`, `resetSyncDelay()`,
`getForecast()`, `getState()`, `resetAll()`,
`getSeason()` → name, mode · `setSeasonMode(mode)`,
`getActivePatternName()`, `getSavedPatterns()`

### Client
`toggleSync()`, `setSyncEnabled(bool)`, `isSyncEnabled()`, `setMyWeather(weather, transition, permanentSnow)`, `setMyTime(h, m, s, transitionMs)`,
`isSnowOnGround()`, `getWeather()` (local, region-translated), `getServerWeather()`, `getWindDirection()`,
`toggleForecast()`, `isForecastOpen()`, `getSeason()`, `isBloodMoon()`

## Events
| Side | Event | Args |
|---|---|---|
| server | `rsg-weather:server:weatherChanged` | weather |
| server | `rsg-weather:server:seasonStarted` / `seasonEnded` | name |
| client | `rsg-weather:client:weatherChanged` | localWeather, serverWeather |
| client | `rsg-weather:client:seasonChanged` | name |
| client | `rsg-weather:client:bloodMoon` | active |

Legacy `weathersync:*` events (`setWeather`, `setTime`, `setWind`, `setSyncEnabled`, `toggleForecast`, `changeWeather` …) are still handled.

## Security
- All changes happen on the server; client→server admin requests are permission-checked and logged.
- Inputs are validated and clamped (weather types, patterns, time, timescale 0–1000, wind 0–50, sync 0.5–60 s, transitions).
- Forecast requests are rate-limited per player.
- Unauthorised attempts are logged at most once per 30 s per player, so spamming admin requests can't flood Discord.
- Non-finite numbers (NaN / infinity) are rejected before they reach the weather state.
- Webhook URLs never leave the server.

## File overview
```
fxmanifest.lua
shared/  utils.lua (helpers, translations)  config.lua
server/  sv_webhooks_config.lua  webhooks.lua  server.lua  patterns.lua  seasonal.lua  legacy.lua  commands.lua  versionchecker.lua
client/  client.lua  legacy.lua  menu.lua  seasonal.lua
html/    index.html  style.css  script.js  dropdown.js (custom dropdowns: native <select> crashes RedM)
locales/ en de el es fr ja nl pl pt-br ro (.json)
```

---
Support: https://buymeacoffee.com/rexshack

## Troubleshooting

- `/weatherdebug` prints this client's sync state, the server weather, the weather actually applied, the regional translation and your coords/temperature, then forces a re-apply. If `sync=false`, run the sync toggle command (or another script turned sync off).
- Weather is applied after clearing any weather override, so scripts that leave an override behind (e.g. older rsg-adminmenu world settings) no longer block it.
- If `/weatherdebug` shows `applied=rain` but no rain falls, another script has forced the rain level (`_SET_RAIN`). rsg-weather now resets it to -1 on every weather change.
