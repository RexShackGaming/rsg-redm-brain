# Changelog

All notable changes to rsg-hunting. Newest first.

## 3.3.2

### Changed
- The "last paid week" marker for weekly rewards is now stored in a new `hunting_weekly_state` table (created automatically, also in `install.sql`) instead of resource KVP, so the server no longer creates a `db` folder. After updating, the first start re-seeds the marker, so a weekly payout that was still pending at that moment is skipped once.

## 3.3.1

### Added
- `Config.AutoDatabase` (default `true`): the database tables are built automatically on start. Set it to `false` to skip the auto-build and import the bundled SQL file manually instead.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
