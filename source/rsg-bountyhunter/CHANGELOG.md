# Changelog

All notable changes to rsg-bountyhunter. Newest first.

## 3.4.0

### Added
- `PostBounty` accepts `targetCitizenid` (a bounty on one player) or `targetGang` (a bounty on any online member of an rsg-gangs gang), plus `targetName` and `sponsorGang`. Used by rsg-gangs so a gang can post a bounty on a player or a rival gang.
- Sponsored player and gang bounties use the same moving search area and dead / hogtied / cuffed turn-in as reputation bounties, and no longer need `Config.ReputationBounty.Enabled`.
- A gang cannot take its own bounty; hunters cannot take a bounty on their own gang.
- New locale keys `crime_sponsored_bounty` and `gang_own_bounty` in all 11 languages.

## 3.3.0

### Added
- Reputation bounties (optional, needs rsg-reputation): a player whose honor falls to `Config.ReputationBounty.Threshold` is posted on the board automatically. A hunter takes the poster, follows a moving search area on the map and brings the player to a sheriff's office dead, hogtied or cuffed to collect. The reward scales with how far honor is below the threshold. The poster is removed when honor recovers, the player is jailed or leaves, or the bounty is collected (with a repost cooldown).
- `IsReputationWanted(citizenid)` server export.
- New locale keys (`crime_reputation`, `rep_*`) in all 11 languages.

## 3.2.0

### Added
- `PostBounty` server export and the `rsg-bountyhunter:server:posterClosed` event for sponsored posters (used by rsg-gangs gang bounties). Sponsored posters survive board re-rolls, return to the board when abandoned and expire on their own.

## 3.1.1

### Added
- `Config.AutoDatabase` (default `true`): the database tables are built automatically on start. Set it to `false` to skip the auto-build and import the bundled SQL file manually instead.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
