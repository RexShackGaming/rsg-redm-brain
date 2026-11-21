# Changelog

All notable changes to rsg-weather. Newest first.

## 3.1.3

### Changed
- Removed the one-time migration of the old `season_mode` resource KVP value. Reading it made FXServer create a `db` folder on every start. A forced season setting saved in KVP by a much older version is not carried over; set it again with the admin command if needed.

## 3.1.2

### Added
- `Config.AutoDatabase` (default `true`) and `installation/rsg-weather.sql` so the `rsg_weather_state` table can be built automatically or imported manually.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
