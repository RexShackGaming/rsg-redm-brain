# Changelog

All notable changes to rsg-queue. Newest first.

## 3.0.3

### Changed
- Maintenance mode is now saved in a new `rsg_queue_state` table (created automatically, also in `install.sql`) instead of resource KVP, so the server no longer creates a `db` folder. The previous KVP value is not migrated: maintenance starts off after this update.

## 3.0.2

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
