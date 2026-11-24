# Changelog

All notable changes to rsg-zonenotify. Newest first.

## 3.4.1

### Changed
- `getDiscoveries` and `getJournal` callbacks are limited to one call per second per player.
- Client keeps the current zone in one helper and only updates it when a zone actually changes.
- DOCS.md rewritten as a full hand-written technical reference (every option, export, event, callback, NUI message, table and security note, with examples).

### Removed
- Stale `LANDMARK_SOLOMONS_FOLLY` entry from `Config.LabelNames`.

### Fixed
- `Config.Rewards.Standing.Regions` key `STATE_AMBARINO` never matched (lookup is lower-case).

## 3.4.0

### Added
- **Explorer's Journal** (`/journal`, optional rebindable key): NUI in the house style with overview, categories, milestones, leaderboard and options. Push-to-talk keeps working while it is open.
- **Rewards** for first visits (cash, rsg-skills Explorer XP, rsg-reputation standing) with server-side anti-abuse checks, and **milestones** for completing a category or reaching 25/50/75/100 % (`zonenotify_milestones` table).
- **Leaderboard** of most places discovered (cached, names full / initial / anonymous).
- **Per-player options** (banners, sound, time, temperature, wind) saved on the player's PC; `Config.PlayerOptions`.
- **Banner queue** (`Config.BannerQueue`).
- **Zone events** for other scripts: `rsg-zonenotify:client:zoneChanged`, `rsg-zonenotify:server:placeDiscovered`, `rsg-zonenotify:server:milestoneReached`; exports `GetCurrentZone`, `OpenJournal`, `CloseJournal`, `GetProgress`, `GetLeaderboard`.
- Flavour lines for all states and the big towns.

### Changed
- Discoveries are recorded even while a player has banners switched off.
- Discovery events now send the player's position; the server only uses it for reward checks.
- `shared/zones.lua` now categorises every place (state, district, town, landmark, water).

### Locales
- 45 new keys in all 11 languages.

## 3.3.0

### Security
- Discovery keys are now whitelisted on the server against `shared/zones.lua` (previously any `[A-Za-z0-9_]` string was stored, so a modified client could fill a character's list with junk and inflate counts).
- Rate limit is a token bucket (burst 5, +1/s) instead of dropping every discovery within one second, which silently lost real discoveries.
- Custom banner title/subtitle length is capped on client and server.

### Fixed
- Discovery cache leaked: export lookups cached offline characters forever, and the drop handler could miss the player. Only online characters are cached and the cache is cleared on unload/drop.
- A slow discovery callback from a previous character could be merged into the next character after a character switch.
- Walking into an unmapped town hash showed a spurious district banner.
- Pending banners built up while banners were switched off with `/zonenotify`; zone tracking now keeps current instead.
- Long place names ran off screen; the title now shrinks to fit.
- Hiding the banner left a stale hide timer; the chime could stay silent while the audio context was suspended.
- `fxmanifest.lua`, README, DOCS and the version checker are on the same version again.

### Improved
- `Config.Key` is now a rebindable key (`Config.UseKeyMapping`, via rsg-core `RegisterKey`); the old control-hash polling remains as a fallback.
- `/places` shows "found of total".
- Landmark/water scan runs every 1.5 s instead of every check; place names are cached.
- Zone tables moved to `shared/zones.lua`; bottom line is built as structured parts (no colour-code parsing round trip); commands/suggestions registered from one helper and re-sent when chat restarts.

### Locales
- New `key_location`; `cl_places` now takes two values (found, total). All 11 languages updated.

## 3.2.0

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
