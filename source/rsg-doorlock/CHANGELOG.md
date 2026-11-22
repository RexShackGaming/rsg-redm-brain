# Changelog

All notable changes to rsg-doorlock. Newest first.

## 3.3.0

### Added
- **Lockpickable doors** (optional, needs `rsg-lockpick`): each lock can get a lockpick difficulty (`easy`, `medium`, `hard`) in the `/doorlock` editor. Players without a key see a **Pick lock** prompt (default key `G`, `Config.Lockpick`). The server starts a validated rsg-lockpick attempt; on success the door unlocks for everyone and locks itself again after `Config.Lockpick.RelockAfter` seconds. The picked state is not saved, so a restart brings the saved state back.
- Optional rsg-reputation: a successful pick is reported as `theft` (`Config.Lockpick.Reputation`) in the lock's new optional `region` (an rsg-reputation region id), so honor and that town's standing drop. rsg-lockpick's own lawman alerts apply as usual.
- Two new columns, `lockpick` and `region`, on `rsg_doorlocks`. They are added automatically while `Config.AutoDatabase = true`; for a manual upgrade run the two `ALTER TABLE` lines at the top of `installation/rsg_doorlocks.sql`. Without the columns, lockpicking stays off and everything else works as before.
- New `Lockpick` Discord log type (`SvConfig.Webhooks.Urls.Lockpick` / `Log.Lockpick`, falls back to the default URL).
- 20 new locale keys in all 13 languages.

### Changed
- Webhook log types missing from an older `sv_config.lua` are now treated as on instead of off.

### Documentation
- README and DOCS describe lockpicking, the new config, columns and the upgrade step.

## 3.2.1

### Added
- `Config.AutoDatabase` (default `true`): the database tables are built automatically on start. Set it to `false` to skip the auto-build and import the bundled SQL file manually instead.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
