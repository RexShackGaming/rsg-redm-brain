# Changelog

All notable changes to rsg-bountyhunter. Newest first.

## 3.5.0

All new features are config-toggled; optional integrations do nothing when the other resource is not started.

### Added
- Dead-or-alive conditions: some posters are "alive only" (a dead target pays nothing and fails the contract) or "dead only" (a live target is refused until dead). `Config.Conditions`.
- Hunter progression through rsg-skills: `bounty_hunting` skill, XP per capture, tier gating by level and a reward perk. `Config.Skills`.
- `CancelBounty(ref)` server export so a sponsor can withdraw a bounty early.
- Evidence items on turn-in (`installation/items.lua`) and rsg-economy reward scaling per region, with an optional treasury payout. `Config.Evidence`, `Config.Economy`.
- Streak bonus and a gang-left-dead bonus checked by the server (`registerGang`). `Config.Streak`, `Config.GangBonus`.
- rsg-telegram notices to a player when a bounty is posted on them and when they are brought in. `Config.Telegram`.
- Jail on an alive capture of a player target through rsg-lawman and rsg-prison. `Config.Jail`.
- Hideout props, outlaws idling until alerted, and an ambush on the way back (the server rolls the chance). `Config.Hideout`, `Config.Ambush`.
- The moving search area offset is re-rolled every few tracking updates (`RerollEvery`).
- Board shows condition pills, level locks, your hunter level and streak. 19 new locale keys in all 11 languages.

### Changed
- `rsg-inventory` is now a dependency (evidence items).

## 3.4.1

### Fixed
- Client: abandoning, expiring or logging out while the outlaws were still spawning could throw an error that killed the contract loop for the rest of the session. The spawn now works on its own copy of the contract and cleans up after itself.
- Client: outlaw spawn failures (invalid model, no collision) retried forever in silence. After 3 failed attempts the hunter is told to abandon (`spawn_failed`).
- Client: a clerk that was deleted by something else was never respawned; double-clicking the clerk showed a false "board unavailable" error; the board stayed open if the player died or the character unloaded.
- Server: a hunter could register another hunter's target ped (same model at the same hideout) and steal the turn-in. A target can now only be registered once and only by the player who owns the ped (`wh_reason_duplicate`).
- Server: an error in the reputation sweep or any other step of the main loop stopped board refreshes and contract expiry for good. Every step now runs protected.
- Server: restarting rsg-bountyhunter left gang-sponsored bounty money stuck in escrow. On stop every sponsored poster is now closed with `'expired'` so the sponsor refunds it.
- Server: if the reward could not be paid, the hunter was marked paid anyway and the sponsor kept nothing back. The payout result is now checked and a sponsor gets `paid = 0`.
- Server: a registered target that disappeared (deleted, owner crashed) left the contract hanging until the timer ran out. It now fails after about 45 seconds with the normal "target lost" message.
- Server: a hunter who tricked the client into firing `registerTarget` on a player contract caused a script error.

### Security
- The minimum hunt time now also scales with the hideout to office distance (`Config.MaxTravelSpeed`), so a far hideout cannot be turned in after 60 seconds by teleporting.
- One turn-in at a time per player (the player-target path waits on the target's client).

### Added
- Push-to-talk keeps working while the board is open (`Config.AllowPushToTalkWhileOpen`, `Config.PushToTalkControls`).
- `Config.RequiredJob` accepts a list of jobs.
- The Abandon button asks for a second click (`ui_confirm_abandon`), and a too-early turn-in now says how long to wait (`too_soon`) instead of "bring the target to the office".
- New locale keys `too_soon`, `spawn_failed`, `wh_reason_duplicate`, `ui_confirm_abandon` in all 11 languages.

### Changed
- Turn-in payout for NPC and player targets shares one code path (less duplicated code, same behaviour).
- Stats are cached per character and saved without waiting on the database; expired cooldowns and stale cache entries are pruned.

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
