# Changelog

All notable changes to rsg-lawman. Newest first.


## 3.2.0

### Added
- Optional rsg-reputation hook: a lawman who jails a player earns the `arrest` action (`Config.Reputation`: Enabled, Action, MinMinutes, Cooldown per lawman/target). Server-side, only after the existing LEO job check; skipped if rsg-reputation is not started.

## 3.1.1

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
