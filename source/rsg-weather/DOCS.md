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
