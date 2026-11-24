# Changelog

All notable changes to rsg-lawman. Newest first.


## 3.4.0

### Added
- **Hard cuffs:** `/cuff hard` freezes the player, `/cuff` (and the item / radial menu) stays soft. `Config.CuffFreezePlayer = true` makes every cuff hard. A hard-cuffed player is released while being escorted.
- **Jail the closest player:** `/jailnear` and a rebindable key (`Config.JailNearKey`, unbound by default; `Config.UseKeyMapping`). Opens the minutes dialog.
- **Frisk and seize:** `/frisk` lists weapons and `Config.Frisk.ExtraItems` the target carries; pick an item to seize it (item data such as weapon serials is kept). Same restrained rule as searching.
- **Fines:** `/fine <id> <amount> <reason>` through rsg-society `IssueFine`, to the society named like the lawman's job. The lawman needs the society's `fines` permission.
- **Alert types:** `Config.AlertTypes` (sprite, sizes, timer, notification type per type). `SendAlert(coords, text, alertType)` and the client event take the type. Automatic alerts use `gunshot` and `death`; `/911` uses `report`.
- **/911:** any player can report a crime (cooldown, length cap, refused when no lawman is on duty). The position is the sender's server-side position.
- **Gunshot alerts** (off by default): non-law players firing a weapon inside a town (`Config.GunshotAlerts`).
- **Outlaw cooldown** (off by default): `Config.OutlawDecay` lowers everyone's `outlawstatus` over time.
- **Holding cells** (empty by default): `Config.HoldingCells` per office, `/holdcell <id>` (cuffed player, at your own office), `/releasecell <id>`, automatic release after the configured minutes and on next login.
- **Discord log** (off by default): arrests, fines, seizures and cell holds (`Config.Discord`), batched with rate-limit back-off.
- 26 locale keys in all 13 languages.

### Notes
- rsg-mdt already hands its sentences to `rsg-lawman:client:sendtojail`, so charges feeding jail time work without changes here.

## 3.3.0

### Security
- `rsg-lawman:server:SearchPlayer`: any player could open the nearest player's inventory. Now needs a law officer (on duty) and a restrained target, checked on the server (cuffed, dead or down from metadata; hands up, hogtied or lassoed asked from the target's own client).
- `rsg-lawman:server:storage`: the job came from the client, so anyone could open any law storage from anywhere. The job is now read on the server and the player must be at an office of their own job.
- `rsg-lawman:server:jailplayer` and `/jail`: sentence length, target and distance are validated on the server; on-duty required; `Config.MaxJailTime` cap; an inmate's sentence can no longer be shortened or reset by jailing them again; `/jail` with a missing time no longer errors.
- Cuff, escort, unjail: on-duty check, target validation and server-side distance check (`Config.ActionDistance`); nil-player errors from the console removed.
- Cuffing is decided on the server: the server flips `ishandcuffed` and tells the client the exact state, so the toggle can no longer desync.
- `sethandcuffstatus` / `setescortstatus` only accept booleans.
- **Removed** the client-reachable `rsg-lawman:server:updateoutlawstatus` event (any client could set its own outlaw status; nothing in the framework called it). Replaced by the server-only export `AddOutlawStatus(src, amount)`.

### Fixed
- Alert blips: all alerts shared one countdown, so overlapping alerts expired early; the 60 second timer actually ran about 43 seconds; blips were never cleaned up. Each alert now has its own expiry and a single watcher removes them. GPS route follows the newest alert and clears when none are left.
- Alert blip name now includes the "Police Alert" prefix (it was built but never used).
- NPC death alerts: every nearby player reported the same death. Only the client that owns the ped reports it.
- Cuffed players stayed flagged cuffed in metadata after a relog or resource restart (inventory locked, no cuffs). The cuffed state is restored on load and the escort flag reset.
- Escorted players are released if the lawman disconnects, dies or the ped disappears.
- `DisablePlayerFiring` was called with a ped instead of the player id.
- Hogtied / lassoed detection never returned a value (native result not read).
- The "hard cuff" path was inverted and unreachable; replaced by `Config.CuffFreezePlayer`.
- `/unjail` help text used a missing locale key. Server notifies used the invalid type `info`.
- Prompts and blips are removed on resource stop; cuffs and escort are released on stop.

### Changed
- `Config.SearchTime` now works (progress bar before the inventory opens, `0` = instant).
- `Config.AlertCooldown` now works (it was ignored, a hard-coded 5 seconds was used).
- Law menu: shows duty state, the armoury row is greyed out below the required grade, "Trash Can" renamed to "Storage" (it is a persistent shared locker).
- Jail dialog shows the allowed range and rejects values above `Config.MaxJailTime`.
- Menu rows are built with DOM calls instead of `innerHTML`.
- `Config.LawJobs` removed (the `leo` job type is used everywhere, matching the rest of the script).

### Added
- Server exports `SendAlert(coords, text)` and `AddOutlawStatus(src, amount)`.
- Config: `RequireOnDuty`, `ActionDistance`, `JailDistance`, `MaxJailTime`, `CuffFreezePlayer`, `SearchRequireRestrained`, `AlertTowns`, `AlertWilderness`.
- Locale keys: `cl_on_duty`, `cl_off_duty`, `cl_storage`, `cl_storage_a`, `cl_searching`, `sv_jail_max`, `sv_already_jailed`, `sv_too_far` (all 13 languages).

### Removed
- Dead code: `Config.Debug`, `Config.TrashCollection`, `Config.LawJobs`, the `hospital:client:isEscorted` and `InteractSound_SV` calls (no such resources on the framework), duplicate town helper functions, unused locale keys (`cl_boss`, `cl_boss_a`, `cl_trash`, `cl_trash_a`, `sv_unjail_h`, `sv_unjail_j`).

## 3.2.0

### Added
- Optional rsg-reputation hook: a lawman who jails a player earns the `arrest` action (`Config.Reputation`: Enabled, Action, MinMinutes, Cooldown per lawman/target). Server-side, only after the existing LEO job check; skipped if rsg-reputation is not started.

## 3.1.1

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
