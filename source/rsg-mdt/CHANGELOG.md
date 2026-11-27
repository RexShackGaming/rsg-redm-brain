# Changelog

All notable changes to rsg-mdt. Newest first.

## 3.1.2

### Security
- `RSGCore:Server:PlayerLoaded` and `RSGCore:Server:OnJobUpdate` were registered as net events, which let any client trigger those core events for every resource. They are now server-only handlers.

### Fixed
- Law roles now refresh when a player's job changes (the job update handler read the wrong player id).

## 3.1.1

### Added
- Automatic database setup: `server/database.lua` runs `sql/mdt.sql` on start (tables plus default roles and charge templates, all `IF NOT EXISTS` / `INSERT IGNORE`). `Config.AutoDatabase = false` keeps the manual import.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
