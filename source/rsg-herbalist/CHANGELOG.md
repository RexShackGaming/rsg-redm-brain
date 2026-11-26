# Changelog

All notable changes to rsg-herbalist. Newest first.

## 3.5.5

### Changed
- Regrow state and admin-placed herb buyers are saved in MySQL (`rsg_herbalist_state`) instead of resource KVP, so the server no longer creates a `db` folder. Requires `oxmysql`. Old KVP data is not migrated: re-add placed buyers with `/addherbbuyer`.

## 3.5.4

### Changed
- Herb buyer ped model is now `cs_exoticcollector`.

## 3.5.3

### Added
- Herb buyer NPC at vector4(2429.99, -1262.82, 47.17, 354.84) (`Config.Buyer.locations`).

## 3.5.2

### Changed
- `Config.PickupControls` is now just `0xF6BB7378`, the control the herb prompt actually fires (found with the new debug line). The other hashes are listed in the config comment as alternates.

## 3.5.1

### Fixed
- Pickup controls: the six unlabelled hashes removed in 3.3.0 are back in `Config.PickupControls` (R stays removed), in case the game's herb prompt uses one of them.
- With `Config.Debug = true` every gather request and every server-side rejection is now logged.

## 3.5.0

### Added
- Drying and tea recipes in the mortar and pestle, with `Tonics` / `Drying` / `Teas` tabs: 6 dried herbs and 4 herbal teas (`dried_*`, `herbal_tea_*`; add the items from `installation/shared_items.lua`, art is placeholder).
- Teas restore thirst (`thirstBoost`) and use their own cooldown group.
- Herb buyer NPC: sells tonics, teas and dried herbs at server-side prices, quality tiers pay more, optional rsg-economy, admin placement with `/addherbbuyer` / `/removeherbbuyer`, `sales` webhook category.
- Recipes with unregistered items are skipped with a warning instead of failing.
- `rsg-target` is now a dependency. 23 new locale keys in all 11 languages.

## 3.4.0

### Added
- Tonic quality: herbalism level sets the tier of brewed tonics (`Config.TonicQuality`), stored as `info.tonic_tier`; the tier scales the tonic's health/stamina boost.
- Per-recipe `minLevel` (rsg-skills); locked recipes show the level needed.
- Field guide (`/herbguide`): per-character record of every herb found, with optional first-discovery XP (`Config.FieldGuide`).
- 14 new locale keys in all 11 languages.

### Fixed
- The tonic cooldown message in 9 languages was missing the seconds value.

## 3.3.0

### Added
- Herb regrow timers and regrown plants persist across restarts (resource KVP, no database).
- `Config.LockAllowAnyHeldJob`: the job lock accepts any rsg-core multi-job job the player holds.
- Gather webhook batches gathers per player (`batchSeconds`, default 60) instead of one message per herb.
- `Config.PickupControls` makes the pick-up controls configurable.

### Fixed
- Pressing R (reload) near a herb or the mystery box started a gather: `0xE30CD707` was mislabelled as gamepad pickup. It and six unlabelled hashes were removed from the default pickup controls.
- Nodes whose plant has no registered item no longer spawn as un-gatherable; they are re-pointed to a gatherable plant or disabled.

## 3.2.1

### Security
- Discord webhook URLs moved from `shared/webhook_config.lua` to `server/webhook_config.lua`; as a shared script it was downloaded by every client. **Rotate any webhook URLs you used before this version.**
- Crafting requests now require the player to hold a `mortarpestle` (previously a modified client could craft without one).
- A craft the client never finished no longer locks the player out; pending crafts expire after their duration + 15 s.

### Fixes / UX
- Gathering with the progress bar off now checks the player is still at the plant and tells them if they walked away.
- Mystery box only reports success (and logs) when loot was actually granted.
- Push-to-talk works while the crafting UI is open (`Config.AllowPushToTalkWhileOpen`).

### Cleanup / performance
- Herb streaming loop uses squared distances with a flat-distance early reject.
- Duplicate `Notify` / dead-check helpers moved into `server/utils.lua`.
- New locale keys `gather_moved_away_title/description` in all 11 languages.

## 3.2.0

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
