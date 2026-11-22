# Changelog

All notable changes to rsg-stables. Newest first.

## 3.7.0

### Added
- Transfer fee and travel time (`Config.Transfer`); a horse in transit can't be retrieved.
- Boarding fees for horses left stabled too long (`Config.Boarding`).
- Horse brands and ownership history (`rsg_stables_history`), `/horserecord` command and exports `GetHorseRecord`, `GetHorseBrand`, `FindActiveHorseByNetId` (`Config.HorseRecords`).
- Saddlebag weight/slots scale with the saddlebag style (`Config.HorseInventory.weightPerStyle`, `slotsPerStyle`).
- Weekly race leaderboards with automatic prizes (`Config.HorseRaces.weekly`).

### Security
- New `fleeStart` callback: the flee-store is only accepted after a server-recorded flee has run its delay.

### Changed
- 28 new locale keys in all 11 languages; new DB tables and columns are created and migrated automatically.

## 3.6.2

### Security
- Wild horse claims are rate-limited per player (`Config.WildHorse.claimCooldown`, default 15 min). The server can't see the taming minigame, so a modified client could previously register any nearby horse and repeat claim -> sell for money.
- Horses can't be sold until they have been owned for `Config.HorseSell.minOwnedSeconds` (default 30 min), closing the claim/flip loop.
- `wildHorseBroken` ignores calls from players without a ped.

### Fixed
- A server callback that errors now answers the client (`false` + generic error) instead of leaving `AwaitCallback` waiting forever; handled in one shared wrapper used by server, admin and training.
- A race run or paid training session whose client crashed or never finished no longer blocks the player until relog; both expire after their time limit plus a grace period.
- The stable menu no longer errors if the horse or breeding list can't be fetched.
- Field-salvage records are cleared when a player drops.

### Changed
- One `playerDropped` handler in `server/server.lua` instead of two; `admin.lua` and `training.lua` reuse the shared callback wrapper.
- New locale keys `wild_claim_cooldown` and `sell_too_new` in all 11 languages.

### Removed
- Unused `closePanel` function in `client/admin.lua`.

## 3.6.1

### Added
- `Config.AutoDatabase` (default `true`): the database tables are built automatically on start. Set it to `false` to skip the auto-build and import the bundled SQL file manually instead.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
