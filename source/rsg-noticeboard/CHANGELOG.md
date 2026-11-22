# Changelog

All notable changes to rsg-noticeboard. Newest first.

## 3.3.0

### Added
- **Search, sorting and paging**: the board is now loaded one page at a time (`Config.PageSize`) with a search box (`Config.SearchMaxLength`) and sorting by newest, expiring soon or title. Notice texts are fetched only when a notice is opened.
- **Edit your own notice** (title, text, image, category) for free (`Config.AllowEdit`).
- **Featured notices** for an extra fee (`Config.Featured`): highlighted tile, listed first, limited per town.
- **Town treasury**: a share of every fee goes to the notice's town through rsg-economy `DepositTreasury` (`Config.Economy`, optional).
- **Report button and abuse handling** (`Config.Reports`): notices are hidden after enough distinct reports; admins get a Reports tab (dismiss, remove, remove and ban) and a Bans tab (unban), plus "Ban poster" on any notice. Posting bans are stored in `rsg_noticeboard_bans`.
- **Reputation** (rsg-reputation, optional, `Config.Reputation`): low honor cannot post, and an online poster loses honor when an admin removes their reported notice (offline posters are not penalised).
- **Map pin and reminders**: posters can pin their position (`Config.AllowPins`) so viewers can set a waypoint; viewers can ask for a telegram reminder (rsg-telegram, optional, `Config.Reminders`) before a notice expires.
- Seven new Discord webhook events, new tables (`reports`, `reminders`, `bans`) and columns on `notices`, all created automatically.
- Orphaned reports and reminders are cleaned up in the expiry loop.

### Changed
- The `refresh` NUI callback is replaced by `getNotices`; the "My notices" list is fetched on demand.
- 73 new locale keys in all 11 languages.

## 3.2.0

### Changed
- Admin board placement now uses **rsg-gizmo** (new dependency) instead of the built-in placer. `client/placer.lua` and `Config.PlacerKeys` / `PlacerRotateSpeed` / `PlacerHeightSpeed` / `PlacerMaxDistance` are gone; use `Config.PlaceMaxDistance`.
- Push-to-talk keeps working while the NUI is open (`Config.AllowPushToTalkWhileOpen`, `Config.PushToTalkControls`).
- The category and town drop-downs are now pure HTML (native `<select>` can crash RedM's CEF).
- Placed boards no longer disappear and respawn for everyone when an admin edits a board.
- The expiry popup can be turned off (`Config.ExpiryPopup`) and no longer opens while the player is dead or placing a board.
- Free durations (admin extend) show "Free" instead of `$0.00`; Enter confirms the text prompt.

### Security
- Image links are checked with the same rules as the UI (no quotes or brackets) and `Config.AllowedImageHosts` now matches the real host name (`i.imgur.com` also no longer matches `i.imgur.com.evil.com`).
- Titles, texts and board names are stripped of control, zero-width and text-direction characters, and invalid UTF-8 is rejected.
- Saving a board now checks the admin is actually where the board is placed (`rsg-gizmo:IsPlacementValid`) and sanitises the rotation.
- Expiry no longer deletes a notice that was renewed at the same moment; the expiry loop survives database errors.
- The fee is only taken after everything that could fail has been worked out.
- All client ids are validated as whole numbers.

### Cleanup
- Database setup is one `ensureDatabase()` with a console message and no duplicated `AutoDatabase` checks; the `town` upgrade only runs when auto database is on.
- Removed the redundant login warning handler (the expiry loop already warns), unused locale keys (`cl_place_help`, `cl_renew`, `cl_later`) and the duplicated NUI callback bodies.
- Added the `ui_free` locale key in all 11 languages.

## 3.1.1

### Added
- `Config.AutoDatabase` (default `true`): the database tables are built automatically on start. Set it to `false` to skip the auto-build and import the bundled SQL file manually instead.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
