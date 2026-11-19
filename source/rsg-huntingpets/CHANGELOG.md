# Changelog

All notable changes to rsg-huntingpets. Newest first.

## 3.1.2

### Added
- `Config.AutoDatabase` (default `true`): the database tables are built automatically on start. Set it to `false` to skip the auto-build and import the bundled SQL file manually instead.

### Fixed
- `installation/rsg_huntingpets.sql` no longer `DROP`s the pet tables (it would have wiped player pets if imported on a live database); it now uses `CREATE TABLE IF NOT EXISTS` and includes the missing `player_selected_pets` table.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
