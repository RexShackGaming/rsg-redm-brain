# Changelog

All notable changes to rsg-canteen. Newest first.

## 3.1.0

### Added
- **Canteen tiers** (`Config.Canteens`): `canteen` (10 uses) and `canteen_large` (20 uses), each with its own capacity and thirst per drink.
- **Water level bar** in the inventory (`info.quality` mirrors the remaining uses).
- **Dirty water:** river/lake fills are dirty; drinking them restores less and may make you sick (`Config.DirtyWater`).
- **Purify** dirty water at a fire by targeting the fire prop (`Config.Purify`, default rsg-cooking campfire).
- **Give a drink** to another player through an rsg-target player option (`Config.Share`), server-checked distance.
- **Weather-aware thirst** (`Config.WeatherThirst`): hot weather restores less per drink.
- **Pump verification** (`Config.PumpVerify`): the server only accepts pump fills at registered pumps. `/canteenaddpump` and `/canteenremovepump` for admins; rsg-wellpump pumps are accepted automatically. New table `rsg_canteen_pumps` (`Config.AutoDatabase`, `install.sql`).
- **Pump fee** (`Config.PumpFee`), charged on the server (needs pump verification).
- Export `ConsumeUse(src)`, used by rsg-stables so *Water Horse* can use a canteen.
- Dependency `oxmysql`. 23 new locale keys in all 11 languages.

### Changed
- `Config.CanteenItem`, `Config.MaxUses` and `Config.ThirstAmount` are replaced by `Config.Canteens` (per item).
- Inventory state is read from player data (no per-call inventory export), and all fill/purify/share actions share one client flow.

## 3.0.6

### Fixed
- Thirst is now applied on the server through `rsg-hud` (`SetNeed`), like rsg-consume. Client-side writes were capped by rsg-hud's per-minute gain limit and could be reverted or lost against its decay loop.
- A failed anim dict or prop model load (rsg-core raises an error on timeout) no longer leaves the client stuck as "busy" with a stuck prop/animation; the action now continues without the cosmetic part and the busy flag is always released.
- `startFill` now reports "no canteen" and "already full" from a single inventory pass instead of an extra export call.

### Changed
- Drinking is blocked (with a notification) while mounted, swimming, in a vehicle or dead; filling is blocked in the same states.
- A drink no longer consumes a use when thirst is already full.
- Inventory check for the pump target and the water prompt is cached for 1 second, and the water zone check runs every 250 ms instead of every frame.
- Canteen metadata is written as a fresh table; locale strings use `locale(key, ...)` formatting.

### Removed
- Client event `rsg-canteen:client:addThirst` (replaced by the server-side thirst write).

### Added
- Locale keys `cannot_now` and `not_thirsty` in all 11 languages.

## 3.0.5

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
