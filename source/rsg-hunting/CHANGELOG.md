# Changelog

All notable changes to rsg-hunting. Newest first.

## 3.5.0

### Added
- **Pelt quality pricing:** good / perfect skinning items remember their quality; trappers pay more (`Config.PeltQuality`). The sell screen shows the real totals.
- **Trophies:** perfect skins of listed animals can give a `hunting_trophy` item that every trapper buys (`Config.Trophies`). New item in `installation/shared_items.lua`.
- **Hunting contracts** at every trapper, with time limit, cooldown, hunting-level pool and cash + XP rewards (`Config.Contracts`, table `hunting_contracts`).
- **Trapper demand:** weather and seasonal events from rsg-weather change prices (`Config.Demand`).
- **Skill gates:** `Config.Gates` needs hunting level (optionally an rsg-skills level) to skin or sell dangerous and legendary animals.
- **Bulk sale bonus** for butcher runs and rsg-wagons' hunting cart (`Config.BulkBonus`, export `GetBulkBonus`).
- **Hunting journal** tab on the leaderboard (`Config.Journal`, table `hunting_journal`).
- **Regional daily bounties** (`Config.Bounty.PerRegion`): each butcher region has its own bounty animals.
- Every skinning animal in `Config.Animals` now has a `name`.

### Changed
- The client now sends poor / good / perfect quality (it only sent perfect before). The server accepts only those three values.
- `HuntingBounty` functions take an optional region; `GetDailyBounties(region)` still works without one.
- Skinned items now carry `info.pelt` for good / perfect carcasses, so they stack separately from plain ones.

### Fixed / tuned in the final pass
- Skill gates on level are ignored while `Config.HuntingXP.Enabled = false`.
- Contract rows from the database are normalised with `tonumber` (no string/number mix-ups).
- Trophy defaults are 25% chance and $10 sell price.
- Trapper stock is saved debounced (at most every 5 s, flushed on stop); the demand notification is throttled per player.
- Inventory stacks are tallied once per sale (`tallyInventory`); journal rows no longer get a rank-N style.
- DOCS.md rewritten by hand with exports, events, callbacks, schema and examples.

### Needs
- Run `install.sql` again, or leave `Config.AutoDatabase = true`, for the two new tables.
- Add `hunting_trophy` to your items (and `hunting_trophy.png` to your item images) if you use trophies.
- rsg-wagons gets the bulk bonus from the edit in `server/server.lua` of that resource.

## 3.4.1

### Fixed
- Selling to a trapper counted only the first inventory stack of an item, so players holding several stacks could not sell everything. All stacks are now counted.
- Switching leaderboard tabs within a second of opening it did nothing (the server answered `nil`). The throttle is gone; the unclaimed-reward query is cached per player instead.
- The trapper sell UI and the leaderboard could take focus away from each other. Both now use one shared focus manager.

### Changed
- Trapper NPCs now spawn and despawn by distance (`Config.DistanceSpawn`), like the butchers, instead of all existing from start.
- New `client/nui.lua`: one NUI focus and push-to-talk whitelist for both UIs (replaces two copies and two per-frame threads).
- Weekly tables are created from one list in `server/xp.lua`.
- Butcher NPC targets are removed when the resource stops.

### Added
- `Config.TrustClientQuality` (default `true`): set `false` to ignore the client-reported carcass quality (a modified client could otherwise always claim perfect).

### Removed
- Unused `Config.Debug` and unused skinning-animal argument.

## 3.4.0

### Added
- Optional rsg-reputation integration (`Config.Reputation`): selling a carcass to a butcher earns standing in the butcher's region, and the region's standing adjusts the cash paid (`1 - price modifier`, limited by `PayoutMin` / `PayoutMax`). Standing gains have a per-player, per-region cooldown.
- `region` on every `Config.ButcherLocations` entry (rsg-reputation region id). Check the ids for Spider Gorge (ambarino), Riggs Station (west_elizabeth) and Elysian (new_hanover) against your map.

### Changed
- `nearButcher` returns the butcher location instead of `true`.

## 3.3.2

### Changed
- The "last paid week" marker for weekly rewards is now stored in a new `hunting_weekly_state` table (created automatically, also in `install.sql`) instead of resource KVP, so the server no longer creates a `db` folder. After updating, the first start re-seeds the marker, so a weekly payout that was still pending at that moment is skipped once.

## 3.3.1

### Added
- `Config.AutoDatabase` (default `true`): the database tables are built automatically on start. Set it to `false` to skip the auto-build and import the bundled SQL file manually instead.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
