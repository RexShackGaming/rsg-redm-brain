# Changelog

All notable changes to rsg-deliveries. Newest first.

## 3.3.0

### Added
- **Teamster skill (rsg-skills):** XP per delivery, perks `pay_bonus` and `time_bonus`.
- **Economy (rsg-economy):** payouts go through a `sell` quote for the hub's town, tax lands in the treasury.
- **Fragile cargo:** `fragile = true` on a route scales pay by the wagon's health, read on the server.
- **Streaks and daily hot route:** bonus pay for back-to-back deliveries and for one route per hub each day, badged on the board.
- **Return trips:** `/returntrip` hauls a load back to the hub for a share of the pay.
- **Ambush (rsg-ambush 3.2.1+):** higher ambush chance during a contract and a bonus for beating one.
- **Job lock and society (rsg-society):** per-hub `job`/`minGrade`, company cut or society-paid payouts.
- **Leaderboard** tab on the contract board (deliveries, distance, earned) backed by the new `rsg_deliveries_stats` table (auto-created, `install.sql` included, `Config.AutoDatabase`).
- `Config.MaxPayoutAmount`: hard cap on the final payout after bonuses.
- 21 new locale keys in all 11 languages.

### Changed
- The start callback returns `{ seconds, fragile }`; the wagon is kept until the server confirms the completion instead of a fixed 3 second delay.
- Needs oxmysql.

## 3.2.1

### Security
- Wagon registration now requires the wagon to have been created by the registering player and refuses a net id already used by another delivery (stops a player claiming someone else's wagon, which was also deleted on completion).
- A rejected completion (expired, away from the drop-off, too fast, wagon check failed) now deletes the wagon and applies the cooldown.

### Fixes
- Server timer has 15 seconds of grace so a delivery finished at the last second is no longer rejected by the client/server timer difference.
- Rejected starts and completions now tell the player instead of failing silently (new locale keys `delivery_too_far_hub`, `delivery_rejected`, all 11 languages).
- Contract board can no longer be used to start a second delivery while one is active or starting.
- A foreman whose model fails to load is no longer retried every tick.
- `Config.Reputation` access is nil-safe on the server.

### Optimization
- Delivery loop only runs per frame while in the wagon or near the drop-off marker (250ms otherwise); the cinematic-camera block applies only in the wagon.
- Foreman spawn loop sleeps 2s when far from every hub.

### Cleanup
- Removed the redundant forward declaration of `StartDelivery` on the server.

## 3.2.0

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
