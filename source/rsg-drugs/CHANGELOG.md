# Changelog

All notable changes to rsg-drugs. Newest first.

## 3.1.4

### Changed
- Alcohol addiction now hooks the server event `rsg-consume:server:consumed` (rsg-consume 3.3.0+) instead of a client relay (`rsg-drugs:server:consumed` is removed). Items cancelled early or refunded no longer count as a use.

## 3.1.3

### Changed
- The brick export market is now saved in a new `rsg_drugs_state` table (created automatically, also in `installation/install.sql`) instead of resource KVP, so the server no longer creates a `db` folder. The previous KVP market is not migrated: the market starts fresh (empty stock, normal demand) after this update.

## 3.1.2

### Added
- `Config.AutoDatabase` (default `true`): the database tables are built automatically on start. Set it to `false` to skip the auto-build and import the bundled SQL file manually instead.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
