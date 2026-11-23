# Changelog

All notable changes to rsg-doorlock. Newest first.

## 3.4.0

### Added
- **Gang and key-item access:** a lock can now list gangs (PlayerData.gang and rsg-society) and a key item next to jobs. Any one grants access.
- **"No key" prompt:** the server tells the client whether the nearest lock is usable (`rsg-doorlock:server:canUse`), so players without access see **No key** and the use prompt is disabled. The lockpick prompt now follows the same answer (admins and key holders no longer see it).
- **Lock groups:** locks that share a group name lock and unlock together.
- **Opening hours:** `open_from` / `open_to` in-game hours open and close a lock automatically (`Config.Schedule`).
- **Server exports** `GetDoors`, `GetDoor`, `GetDoorIdByName`, `IsLocked`, `SetLocked`, `LockDoor`, `UnlockDoor`, `SetGroupLocked`, `HasAccess`, and the `rsg-doorlock:server:stateChanged` event.
- **Editor:** gang, key item, group and hours fields, a **Duplicate** button, and map blips for every lock while the editor is open (`Config.EditorBlips`).
- `Config.Lockpick.Alert` passes a lawman alert chance to rsg-lockpick.
- Five new columns on `rsg_doorlocks` (`key_item`, `gangs`, `group_name`, `open_from`, `open_to`), added automatically while `Config.AutoDatabase = true`; manual upgrade lines are at the top of `installation/rsg_doorlocks.sql`. 19 new locale keys in all 13 languages (`ui_jobs_hint` was replaced by `ui_access_hint`).

### Fixed
- Saving a lock with an empty lockpick or region could shift the SQL parameters. Optional values are now sent as `NULLIF` placeholders, so every save has a fixed parameter list.

## 3.3.1

### Fixed
- A lockpick attempt that never reported back (client crash, expired ticket) no longer blocks that player from picking again; it times out after 2 minutes.
- `getDoors` callback no longer piles up waiting threads when spammed before the database has loaded.
- Discord webhook mentions are limited to roles, and only when a Security ping is set.
- Push-to-talk now works while the `/doorlock` editor is open (`Config.AllowPushToTalkWhileOpen`, `Config.PushToTalkControls`).

### Changed
- Optimisation: the prompt title is built once per state instead of every frame, and the editor's pick HUD no longer JSON-encodes every frame.
- Cleanup: shared the duplicated distance / incapacitated checks in `server/main.lua` and the duplicated key-release wait in `client/main.lua`.

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
