# rsg-weather

Time, weather and wind sync for **RSG Framework** (RedM), built on **ox_lib**.
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
- [ox_lib](https://github.com/Rexshack-RedM/ox_lib)

## Installation
1. **Stop and remove the old `weathersync` resource** (this resource `provide`s that name).
2. Put `rsg-weather` in your resources folder.
3. Add to `server.cfg` (after ox_lib and rsg-core):
   ```
   ensure ox_lib
   ensure rsg-core
   ensure rsg-weather
   ```
4. Optional — language and Discord (see below):
   ```
   setr ox:locale "en"
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
Set with `setr ox:locale "<code>"`: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.
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
- Webhook URLs never leave the server.

## File overview
```
fxmanifest.lua
shared/  utils.lua (helpers, translations)  config.lua
server/  sv_webhooks_config.lua  webhooks.lua  server.lua  patterns.lua  seasonal.lua  legacy.lua  commands.lua  versionchecker.lua
client/  client.lua  legacy.lua  menu.lua  seasonal.lua
html/    index.html  style.css  script.js
locales/ en de el es fr ja nl pl pt-br ro (.json)
```
