# Changelog

All notable changes to rsg-fishmonger. Newest first.

## 3.2.0

### Added
- Optional rsg-economy integration: sales go through `Quote` (town tax + reputation price modifier, no market multiplier) and `Record` after payout. Toggle with `Config.Economy.Enabled`; skipped if rsg-economy is not started.

## 3.1.1

### Changed
- Daily stock is now saved in a new `rsg_fishmonger_stock` table (created automatically, also in `install.sql`) instead of resource KVP, so the server no longer creates a `db` folder. Adds the `oxmysql` dependency and `Config.AutoDatabase`. Today's sold counts from before the update are not migrated.

## 3.1.0

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
