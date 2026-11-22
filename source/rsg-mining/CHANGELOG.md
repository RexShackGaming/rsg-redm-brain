# Changelog

All notable changes to rsg-mining. Newest first.

## 3.2.0

### Added
- The rsg-skills `extra_yield` perk now works: each ore type collected has that % chance of one extra item (not taken from the mine's storage). Switch off with `Config.Skills.ExtraYield = false`.
- Optional rsg-reputation integration (`Config.Reputation`): collecting ore earns standing in the mine's region (`region` on each `Config.Mines` entry), at most once per cooldown per player and region.

### Documentation
- README and DOCS describe both features.

## 3.1.1

### Added
- `Config.AutoDatabase` (default `true`): the database tables are built automatically on start. Set it to `false` to skip the auto-build and import the bundled SQL file manually instead.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
