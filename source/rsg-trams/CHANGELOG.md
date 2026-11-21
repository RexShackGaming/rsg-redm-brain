# Changelog

All notable changes to rsg-trams. Newest first.

## 3.1.2

### Changed
- The `/trams` on/off setting is now saved in a new `rsg_trams_state` table (created automatically, also in `install.sql`) instead of resource KVP, so the server no longer creates a `db` folder. Adds the `oxmysql` dependency and `Config.AutoDatabase`. A previous KVP setting is not migrated: tracks start at their `Config.Tracks` default until toggled again.

## 3.1.1

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
