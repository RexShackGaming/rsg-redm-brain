# Changelog

All notable changes to rsg-fishing. Newest first.

## 3.2.0

### Added
- Bite conditions: time of day and weather (rsg-weather) change the bite chance; the controls HUD shows Poor / Fair / Good (`Config.BiteModifiers`).
- Regional fish pools per state and legendary spots for the legendary salmon (`Config.Regions`); optional server position check per spot.
- Angler's journal (`/fishjournal`, optional rebindable key): species catalogue, server records, top anglers. Record announcement, optional cash reward and the `rsg-fishing:server:newRecord` event.
- rsg-skills perks `bite_chance`, `line_strength`, `rare_chance`; rsg-reputation actions for a new species, a beaten record and a complete journal.
- Database: `rsg_fishing_journal`, `rsg_fishing_records` (auto-created, `install.sql` included). New dependency: oxmysql.
- 22 new locale keys in all 13 languages.

### Changed
- `Config.fishData` rows have a species family as the third value; new `Config.Species` and `Config.SpeciesOrder`.
- `rsg-fishing:server:catchFish` takes two more arguments (`region`, `spot`).

## 3.1.1

### Security
- The server checks a minigame catch against the bait used (`Config.EnforceBaitList`), the time since the bait went on the rod (`Config.MinCatchTime`) and the fish's weight band. Ground pickups are capped (`Config.GroundPickupLimit`).

### Changed
- Bait is spent when it is put on the rod, not when the item is used.
- Items are added and removed through rsg-inventory exports.
- New `Config.BiteChance`, `Config.WeightBands`, `Config.WeightFactor`; `Config.fishData` is now `{ name, band }` (unused provision strings removed).

### Performance
- Minigame struct writes are batched once per frame and skipped when unchanged; bobber NUI messages are only sent when the marker moves.

## 3.1.0

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
