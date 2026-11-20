# Changelog

All notable changes to rsg-housing. Format based on Keep a Changelog.

## [3.3.1] - 2026-11-20
### Fixed
- The automatic database setup no longer runs `ALTER TABLE ... MODIFY houseid` on every start (oxmysql logged it as a slow query). The `houseid` columns are only widened to `varchar(20)` when they are currently shorter.

## [3.3.0] - 2026-11-18
### Added
- Optional rsg-economy integration (`Config.Economy`): rent and storage upgrade payments are deposited into the treasury of the town nearest to the house. `ReplaceGovernor = true` uses the treasury instead of the governor boss account.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.

## [3.2.0] - 2026-11-18
### Added
- **Public API.** Server exports: `GetHouse`, `GetHouses`, `IsHouseRented`, `GetTenant`, `GetPlayerHouses`, `GetHouseAccess`, `HasHouseAccess`, `GetHouseAt`, `GetHouseByDoor`, `GetDoorState`, `SetHouseDoors`, `GetHouseGuests`, `AddGuest`, `RemoveGuest`, `SetHouseRent`, `EvictTenant`, `OpenHouseStorage`, `GetHouseProps`.
- **Hook events** (server): `houseRented`, `rentPaid`, `tenancyEnded` (with reason), `guestAdded`, `guestRemoved`.
- **Client API:** `IsHouseRented`, `IsMyHouse`, `GetMyHouses`, `GetHouseName`, `GetNearestHouse`, `OpenHouseMenu`, `IsHouseMenuOpen`, and the `housesUpdated` event.
- Guests are told when they receive or lose a key (`key_received`, `key_removed` in all 10 languages).
- Index on `rsg_housekeys (houseid, citizenid)` for the permission checks that run on every action.
- `CHANGELOG.md`; `DOCS.md` rewritten with the full technical reference and examples.

### Changed
- The API and the in-game callbacks share one code path for keys, evictions and opening storage, so they behave the same.
- Admin storage-size checks read the live stash instead of the last saved copy.
- README restructured (commands before troubleshooting, support last).

### Removed
- Unused locale keys `adm_evict` and `adm_confirm_evict` and their NUI string entries.

## [3.1.0] - 2026-11-18
### Added
- **Decorating:** tenants place furniture with rsg-gizmo, move or remove it with rsg-target (partial refund). `Config.DecorProps`, `MaxPropsPerHouse`, `PropPlaceRadius`, `PropStreamDistance`, `PropRefundPercent`. New table `rsg_housing_props`.
- **Time-limited guest keys** (`Config.GuestDurations`, `rsg_housekeys.expires`) with a duration selector in the guest panel.
- **Knocking** for visitors without a key (`Config.AllowKnock`, `KnockCooldown`).
- **Rent reminder at login** (`Config.LoginRentReminder`).
- **Belongings kept after a tenancy** (`Config.RetrievalDays`, `/housebelongings`, table `rsg_housing_retrieval`).
- **Early-exit refund** (`Config.EndTenancyRefundPercent`).
- `/myhouse` GPS route.
- Dependencies: `rsg-target`, `rsg-gizmo`.

### Changed
- Guest search defaults to logged-in players near the tenant (`Config.GuestSearchScope`, `GuestSearchDistance`); the whole-table search is now opt-in (`'all'`).
- Ending a tenancy requires being at the house.
- `Config.EnableGovenor` renamed `Config.EnableGovernor` (the old name still works).
- `Config.PurgeStorageOnLeave = false` now keeps a departing tenant's items for retrieval instead of leaving the stash for the next tenant.

### Fixed
- **Storage purge could silently fail:** the previous purge called `ClearStash` / `DeleteInventory`, which current rsg-inventory doesn't define, so an in-memory copy of the stash could survive. The purge now uses `ClearInventory` first.

## [3.0.3] - 2026-11-18
### Added
- `Config.AutoDatabase` toggle (manual install stays possible), `Config.MaxGuests`.
- Push-to-talk keeps working while a panel is open (`Config.AllowPushToTalkWhileOpen`, `PushToTalkControls`).
- Clean-up on character unload (clears houses, closes panels).

### Fixed
- Database setup used `ADD COLUMN IF NOT EXISTS`, which MySQL doesn't support. Columns are now checked through `information_schema`.
- `houseid` columns were `varchar(7)` (broke at `house100`); widened to `varchar(20)` automatically.
- Houses added to `Config.Houses` had no database row and couldn't be rented; rows are now created from the config (`region`) or the console warns.
- The SQL import is now re-runnable (`INSERT IGNORE`).
- The key animation prop could leak (now timed out and cleaned on resource stop); doors can't be used while dead, mounted or in a vehicle.
- Governor payout no longer errors when rsg-bossmenu isn't running; a nil rent count and over-long citizen ids are handled.

## [3.0.2] and earlier
Baseline: monthly rent at the house, grace period and eviction, guests with per-feature permissions, storage tiers, wardrobe, mailbox, house rename, at-home status, blips, admin panel, no ox_lib dependency. Earlier history was not recorded in this file.
