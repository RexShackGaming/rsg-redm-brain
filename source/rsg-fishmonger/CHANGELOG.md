# Changelog

All notable changes to rsg-fishmonger. Newest first.

## 3.3.1

### Changed
- Final review pass: no code bugs found. DOCS.md rewritten as one complete reference (data formats, database, integrations, code examples, troubleshooting); the outdated auto-generated block was removed.

## 3.3.0

### Added
- **Fish quality:** each fish is paid by its own size (`info.weight`) and freshness (`info.quality`, when rsg-inventory decay is on). The menu preview uses the same numbers, so it matches the payout. `Config.Quality`.
- **Daily orders:** every town posts fish orders each real day (same for everyone). Deliver one per player for a bonus payout, fishing rep and rsg-skills XP. New **Today's orders** panel in the menu. `Config.Contracts`.
- **Fillet market:** fillets can be sold back to the fishmonger from the same menu. `Config.FilletSale`.
- **Supplies shop tiers:** better lures unlock with the player's fishing level (rsg-skills). `Config.Shop.tiers`.
- **Closed-town blips:** the map blip turns red while a town is closed and green when open (needs `Config.OpeningHours.enabled`). `Config.Blip.openColor` / `closedColor`.
- **Stock recovery:** a town can buy fish again gradually through the day instead of resetting at midnight. `Config.DailyStock.recoveryPerHour` (`0` = old midnight reset).
- **Sell hint on items:** each fish's description now says roughly what it sells for. `Config.ItemHints`.
- **Optional tamper bans:** `Config.BanOnTamper` bans a player for requests the menu can never produce (off by default).
- New locale keys in all 11 languages.

### Database
- New table `rsg_fishmonger_orders` and a new `updated` column on `rsg_fishmonger_stock`. Both are created or added automatically while `Config.AutoDatabase = true`. For a manual install, import the new `install.sql` and run the `ALTER TABLE` line in it.

### Changed
- Sales are now worked out per fish stack instead of per item name, so the oldest stack in your inventory is sold first.

## 3.2.1

### Fixed
- The menu no longer stays locked (buttons greyed out) if the client refuses a checkout request.
- The "closed" check no longer uses the client's native clock, which could disagree with rsg-weather. The server alone decides, and the menu now tells you when you are too far away instead of doing nothing.
- The price preview and confirm pop-up now include the rsg-economy town tax and standing, so they match the payout.
- A missing or failing rsg-skills / rsg-weather / rsg-economy export can no longer stop the menu from opening or a trade from completing.
- Carts with more lines than there are fish types are rejected (stops oversized requests burning server time).
- Suspicious-activity webhooks are limited to one per player every 5 seconds, so spam cannot push real logs out of the queue.
- The server allows 1.5 m of slack on top of `Config.MaxUseDistance` to avoid false "not at fishmonger" alerts.
- Discord embeds can no longer ping; only the configured alert ping does.
- Sales are refused for a moment on startup until the saved daily stock has loaded.
- The item list is built when the menu opens instead of at resource start; the NPC model is checked with `IsModelValid`.

### Added
- Push-to-talk keeps working while the menu is open (`Config.AllowPushToTalkWhileOpen`, `Config.PushToTalkControls`).
- `Config.Blip.scale`.
- The database table is created by `ensureDatabase()` with a console message, and the shop opens at most once per second per player.

### Changed
- The menu closes when the character logs out; the spawn loop checks less often when far from every fishmonger.
- Removed unused shared code (`FishmongerIsOpen` moved into the server, the only place it is used).
- Config: the rsg-economy block now sits above the bonus settings.

### Added
- Optional rsg-economy integration: sales go through `Quote` (town tax + reputation price modifier, no market multiplier) and `Record` after payout. Toggle with `Config.Economy.Enabled`; skipped if rsg-economy is not started.

## 3.1.1

### Changed
- Daily stock is now saved in a new `rsg_fishmonger_stock` table (created automatically, also in `install.sql`) instead of resource KVP, so the server no longer creates a `db` folder. Adds the `oxmysql` dependency and `Config.AutoDatabase`. Today's sold counts from before the update are not migrated.

## 3.1.0

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
