# Changelog

All notable changes to rsg-cooking. Newest first.

## 3.5.0

### Added
- **Campfire expiry** (`Config.Campfire.ExpireDays`, default 14): an empty campfire nobody used for that long is removed. Campfires holding food or ingredients are never removed. Needs the new `last_used` column (added automatically; with `Config.AutoDatabase = false` run the `ALTER TABLE` in `installation/rsg-cooking.sql`).
- **Stove whitelist** (`Config.WorldStations.Locations`): when filled, the server refuses pots anywhere else. `/cookingstove` (admin) prints the closest stove as a ready-to-paste line.
- **Per-batch XP** (`Config.XpMode = 'batch'`): every batch pays the same however many items it makes. The default stays `'item'`, so nothing changes until you switch it.
- **Cookbooks** (`Config.Cookbooks`, recipe flag `locked = true`): useable items teach hidden recipes, saved on the character. Exports `LearnCookingRecipe` and `KnowsCookingRecipe`.
- **Food quality** (`Config.Quality`): collected food carries `info.quality` from the collector's cooking level, which rsg-inventory's decay then ages. The tray shows the quality.
- **Top cooks leaderboard** (`/cookingtop`, `Config.Leaderboard`): leather & gold NUI with the top cooks, cached.
- 12 new locale keys in all 11 languages.

## 3.4.0

### Changed
- Campfire placement now uses **rsg-gizmo** (new dependency) instead of the built-in camera preview; the custom raycast, ghost and key polling code was removed.
- `getStations` and station sync only send what a player needs: private world pots are no longer broadcast to everyone, only to their owner.
- The server tick skips stations that have no recipe.
- Unloading the pantry now takes as much as fits in the inventory (like collecting) instead of failing outright.

### Fixed
- Push-to-talk now works while the cooking UI is open (`Config.AllowPushToTalkWhileOpen`, `Config.PushToTalkControls`).
- Amounts sent by the client are sanitised (NaN / infinity can no longer pass the load and fuel checks).
- A character can hold at most `Config.WorldStations.MaxPerPlayer` world pots, so a modded client can't flood the database with pots.
- `AddCustomRecipe` normalises numbers and rejects bad ingredients and outputs larger than `Config.OutputCap`.
- The UI no longer loses focus on the fuel amount box while refreshing, and ignores clicks while the server is still answering the last action.
- The webhook queue is capped when a webhook is unreachable.

### Removed
- Unused locale key `campfire_controls` (all 11 languages). Added `sv_world_limit`.

## 3.3.1

### Added
- `Config.AutoDatabase` (default `true`): the database tables are built automatically on start. Set it to `false` to skip the auto-build and import the bundled SQL file manually instead.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
