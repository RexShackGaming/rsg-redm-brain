# rsg-weather

Version 3.0.1. rsg-weather - time, weather and wind sync for RSG Framework (weathersync compatible)

Time, weather and wind sync for **RSG Framework** (RedM), built on **ox_lib**. A drop-in replacement for `weathersync` — every old export and event keeps working. - Server-authoritative time, weather and wind synced to all players through `GlobalState` (late joiners are in sync instantly)

Source: https://github.com/Rexshack-RedM/rsg-weather

**Dependencies:** `rsg-core`, `ox_lib`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-weather']:Name)

**server:** `getActivePatternName()`, `getSavedPatterns()`, `getSeason()`, `setSeasonMode(m)`

**client:** `getSeason()`, `getServerWeather()`, `getWeather()`, `getWindDirection()`, `isBloodMoon()`, `isForecastOpen()`, `isSnowOnGround()`, `isSyncEnabled()`, `setMyTime(h, m, s, transition)`, `setMyWeather(weather, transition, permanentSnow)`, `setSyncEnabled(toggle)`, `toggleForecast()`, `toggleSync()`

## Net events registered

**server:** `weathersync:init`, `weathersync:requestUpdatedAdminUi`, `weathersync:requestUpdatedForecast`

**client:** `rsg-weather:client:bloodmoonDebug`, `rsg-weather:client:openAdminMenu`, `rsg-weather:client:setMyTime`, `rsg-weather:client:setMyWeather`, `rsg-weather:client:showForecast`, `rsg-weather:client:toggleSync`, `weathersync:openAdminUi`, `weathersync:setMyTime`, `weathersync:setMyWeather`, `weathersync:setSyncEnabled`, `weathersync:toggleForecast`, `weathersync:toggleSync`

## Event handlers

**server:** `rsg-weather:server:patternsReset`, `rsg-weather:server:restorePattern`

**client:** `rsg-weather:client:weatherChanged`

## Callbacks (lib.callback)

**server:** `rsg-weather:server:adminAction`, `rsg-weather:server:applyPattern`, `rsg-weather:server:deletePattern`, `rsg-weather:server:getAdminState`, `rsg-weather:server:getForecast`, `rsg-weather:server:getPatterns`, `rsg-weather:server:savePattern`

## Server events it triggers in other resources

**server:** `weathersync:xxx`

## Public (table) functions

**server/server.lua:** `API.getWeather()`, `API.setWeather(weather, transition, freeze, permanentSnow)`, `API.resetWeather()`, `API.setWeatherPattern(pattern)`, `API.resetWeatherPattern()`, `API.getTime()`, `API.setTime(d, h, m, s, transition, freeze)`, `API.resetTime()`, `API.getTimescale()`, `API.setTimescale(scale)`, `API.resetTimescale()`, `API.getWind()`, `API.setWind(direction, speed, frozen)`, `API.resetWind()`, `API.getSyncDelay()`, `API.setSyncDelay(delay)`, `API.resetSyncDelay()`, `API.getForecast()`, `API.getState()`, `API.resetAll()`
