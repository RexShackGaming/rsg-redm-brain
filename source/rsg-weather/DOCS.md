# rsg-weather – Developer Docs

## Flow
Server (`server/server.lua`) owns weather/time/wind and publishes `GlobalState.rsgWeather`, `rsgTime`, `rsgWind`. Each client (`client/client.lua`) reads them, translates weather per region (`translateWeather`) and applies it.

## Applying weather (client)
`applyWeather` calls `CLEAR_OVERRIDE_WEATHER` (0x80A398F16FFE3CC3) then `_SET_WEATHER_TYPE` (0x59174F1AFE095B5A, hash, true, true, true, transition, false). It also calls `_SET_RAIN` (0x193DFC0526830FD6) with `-1.0` so a rain level forced by another script (e.g. 0.0 during character select) can't block rain. Clearing first stops overrides left by other scripts from blocking the change.

## Debugging
`/weatherdebug` – prints `sync | server | applied | local | region | x y | temp` and forces a re-apply.
- `sync=false`: client sync is off (`/myweather`, `/mytime`, sync toggle, or a legacy `weathersync:*` event from another resource).
- `server` ≠ `region`: regional translation changed it (snow north, desert variants).

## Other resources
Resources should change weather via `exports['rsg-weather']:setWeather(type, transition, freeze, permanentSnow)` / `setTime` / `setWind`, never by calling the weather natives directly. rsg-adminmenu does this when rsg-weather is started.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-weather 3.1.1**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `oxmysql`

### Database

Tables: `rsg_weather_state`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/rsg-weather.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.Debug` | `false` |  |
| `Config.AdminPermissions` | `{ 'god', 'admin' }` | RSGCore permission levels allowed to use admin commands / menu |
| `Config.SyncDelay` | `5000` | ms between server -> client syncs |
| `Config.EnableLegacyNetEvents` | `true` | accept old weathersync:* net events from clients (admin-checked) |
| `Config.Time` | `DHMSToTime(0, 6, 0, 0)` | seconds of a week (0-604799) or DHMSToTime(day, hour, minute, second), day 0 = Sunday |
| `Config.Timescale` | `4` | in-game seconds per real second (30 = vanilla). 0 = use real server clock |
| `Config.RealTimeOffset` | `0` | seconds, only used when Timescale = 0 |
| `Config.TimeIsFrozen` | `false` |  |
| `Config.Weather` | `'sunny'` |  |
| `Config.WeatherInterval` | `DHMSToTime(0, 1, 0, 0)` | in-game time between changes |
| `Config.WeatherIsFrozen` | `false` |  |
| `Config.PermanentSnow` | `false` |  |
| `Config.DynamicSnow` | `true` | snow on ground in snowy regions / snowy weather |
| `Config.MaxForecast` | `23` | number of intervals queued (23 = 24h forecast) |
| `Config.RegionalWeather` | `true` | translate weather per region (snow in north, sandstorm in desert...) |
| `Config.WindDirection` | `0.0` |  |
| `Config.WindSpeed` | `0.0` |  |
| `Config.WindIsFrozen` | `false` |  |
| `Config.WindShearDirection` | `45` | degrees per interval of altitude |
| `Config.WindShearSpeed` | `2.0` | speed added per interval of height above ground |
| `Config.WindShearInterval` | `50.0` | metres |
| `Config.MeanSeaLevel` | `40.0` |  |
| `Config.WeatherPattern` | `table` |  |
| `Config.isRDR` | `true` |  |
| `Config.weatherTypes` | `WeatherTypes` |  |
| `Config.weatherPattern` | `Config.WeatherPattern` |  |
| `Config.timescale` | `Config.Timescale` |  |
| `Config.syncDelay` | `Config.SyncDelay` |  |
| `Config.Seasonal` | `table` |  |
| `Config.Enabled` | `true` |  |
| `Config.CheckInterval` | `60` |  |
| `Config.Events` | `table` | date ranges are inclusive and may wrap the year (e.g. Dec 28 -> Jan 2) |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `getActivePatternName` | `` | `server/patterns.lua` |
| `getSavedPatterns` | `` | `server/patterns.lua` |
| `getSeason` | `` | `server/seasonal.lua` |
| `setSeasonMode` | `` | `server/seasonal.lua` |

**Client**

| Export | Arguments | File |
|---|---|---|
| `toggleSync` | `` | `client/client.lua` |
| `setSyncEnabled` | `` | `client/client.lua` |
| `isSyncEnabled` | `` | `client/client.lua` |
| `setMyWeather` | `` | `client/client.lua` |
| `setMyTime` | `` | `client/client.lua` |
| `isSnowOnGround` | `` | `client/client.lua` |
| `getWeather` | `` | `client/client.lua` |
| `getServerWeather` | `` | `client/client.lua` |
| `getWindDirection` | `` | `client/client.lua` |
| `toggleForecast` | `` | `client/menu.lua` |
| `isForecastOpen` | `` | `client/menu.lua` |
| `getSeason` | `` | `client/seasonal.lua` |
| `isBloodMoon` | `` | `client/seasonal.lua` |

```lua
-- example
local result = exports['rsg-weather']:getActivePatternName()
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-weather:server:getPatterns` | server | `src, cb` | `server/patterns.lua` |
| `rsg-weather:server:savePattern` | server | `src, cb, name, pattern, apply` | `server/patterns.lua` |
| `rsg-weather:server:deletePattern` | server | `src, cb, name` | `server/patterns.lua` |
| `rsg-weather:server:applyPattern` | server | `src, cb, name` | `server/patterns.lua` |
| `rsg-weather:server:getForecast` | server | `src, cb` | `server/server.lua` |
| `rsg-weather:server:getAdminState` | server | `src, cb` | `server/server.lua` |
| `rsg-weather:server:adminAction` | server | `src, cb, action, data` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-weather:server:getPatterns', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-weather:client:toggleSync` | client | `` | `client/client.lua` |
| `rsg-weather:client:setMyTime` | client | `` | `client/client.lua` |
| `rsg-weather:client:setMyWeather` | client | `` | `client/client.lua` |
| `weathersync:toggleSync` | client | `` | `client/legacy.lua` |
| `weathersync:setSyncEnabled` | client | `` | `client/legacy.lua` |
| `weathersync:setMyWeather` | client | `` | `client/legacy.lua` |
| `weathersync:setMyTime` | client | `` | `client/legacy.lua` |
| `weathersync:toggleForecast` | client | `` | `client/legacy.lua` |
| `weathersync:openAdminUi` | client | `` | `client/legacy.lua` |
| `rsg-weather:client:showForecast` | client | `` | `client/menu.lua` |
| `rsg-weather:client:openAdminMenu` | client | `` | `client/menu.lua` |
| `rsg-weather:client:bloodmoonDebug` | client | `` | `client/seasonal.lua` |
| `weathersync:init` | server | `` | `server/legacy.lua` |
| `weathersync:requestUpdatedForecast` | server | `` | `server/legacy.lua` |
| `weathersync:requestUpdatedAdminUi` | server | `` | `server/legacy.lua` |

```lua
-- from a client script
TriggerServerEvent('weathersync:init')
-- from a server script
TriggerClientEvent('rsg-weather:client:toggleSync', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/weatherdebug` |  | `client/client.lua` |
| `/forecast` | locale('cmd_forecast') | `server/commands.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
