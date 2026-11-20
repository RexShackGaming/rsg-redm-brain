# Changelog

All notable changes to rsg-farming. Newest first.

## 3.3.0

### Changed
- Well pumps moved to the new standalone **rsg-wellpump** resource (now a required dependency). rsg-farming no longer places pumps, fills buckets or stores pumps; watering calls `exports['rsg-wellpump']:UseBucket(src)`.
- Removed `Config.WellPump`, `Config.WaterReturnItem`, the `pump_*` and `bucket_uses` locale keys, and the `rsg_farming_wellpumps` table from the schema and `install.sql`. Existing pumps are imported by rsg-wellpump on its first start; the old table is left untouched.

## 3.2.0

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
