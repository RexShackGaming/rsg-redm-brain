# Changelog

All notable changes to rsg-boats. Newest first.

## 3.2.0

### Added
- Hire boats: a *Hire* tab per yard, per-model hire price (admin form, 0 = not for hire), `Config.Rental` (minutes, warning). The clock starts when the boat is on the water; the server warns, then takes the boat back. Hire boats have no storage, can be returned at any dock and the fee is refunded if the boat never spawns.
- Storage upgrades: *Upgrades* on each owned boat (extra slots and carry weight in levels, `Config.Upgrades`), capped by `Config.Storage` limits.
- Boats owned / limit counter in the shop; buying is disabled at `Config.MaxBoats`.
- `rent` and `upgrade` webhook events.
- 29 new locale keys in all 11 languages.

### Changed
- Sell-back is based on the price paid (purchase plus upgrades) via the new `price_paid` column. Boats bought before this update use the model's current price.
- New database columns (added automatically): `rsg_boats_models.rent_price`, `rsg_boats_owned.price_paid`, `rsg_boats_owned.upgrades`.

## 3.1.1

### Fixed
- *Set Dock At My Position* and *Save Radius* never saved: the client sent a stray `false` argument, so the server received no data.
- Script error (`answerOffer` was nil) when the shop was closed while a transfer offer was open.
- Closing the shop no longer drops focus from a transfer offer that is still open.

### Security
- Exploit webhooks are limited to one per player and reason every 30 seconds and the webhook queue is capped (a modified client could flood Discord and grow memory).
- Transfers re-check the distance between both players after the receiver accepts.
- Selling a boat is refused while its storage holds items; the stash row is deleted after the sale.
- A failed purchase insert now refunds the money.

### Changed
- Spawn Assistant uses rsg-gizmo (new dependency). Removed the custom placer loop, its NUI HUD, `Config.Keys`, the old `Config.Placer` speeds and five `ui_key_*` locale keys. The ghost turns red when it is out of range of the yard.
- Push-to-talk keeps working while the shop, admin panel or transfer popup is open (`Config.AllowPushToTalkWhileOpen`, `Config.PushToTalkControls`).
- The shop closes when the player dies or walks away from the yard.
- The server stays idle if the database install fails.
- `Config.AutoInstallDB` renamed to `Config.AutoDatabase`.
- New locale key `sell_storage_not_empty` in all 11 languages.
- Enter confirms popups; the transfer player ID must be a whole number; UI locales are built once per session.

## 3.1.0

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
