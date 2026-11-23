# Changelog

All notable changes to rsg-chat. Newest first.

## 3.4.0

### Added
- **Private messages:** `/pm <id or First_Last> <message>` and `/r <message>` to reply. Click a name in a PM (while the input is open) to start a reply. `Config.PM`.
- **@mentions:** `@First_Last` or `@First` in a message highlights it for that player. Clicking a name while the input is open adds the mention. `Config.Mentions`.
- **"Nobody heard you" hint** for local and regional channels. `Config.NobodyHeardHint`.
- **Chat logs:** every message is stored in `rsg_chat_logs` (batched inserts, automatic clean-up) and can be searched by text, player or channel in the `/chatlog` admin tab. Optional forwarding to rsg-log / Discord. `Config.Logging`.
- **Mutes:** `/chatmute <id> <minutes> [reason]` and `/chatunmute <id>`. Mutes are stored by character, survive relogs and restarts, and are logged. `Config.ModPermission`, `Config.Moderation`.
- **Word filter:** whole-word, leetspeak-aware, `mask` or `block` mode, staff exempt. `Config.WordFilter`.
- **`/do` and `/roll [sides]`:** range-limited roleplay lines; the roll is decided on the server. `Config.Roleplay`. (`/me` stays with rsg-core.)
- **Fade while aiming** or in a cinematic camera, as a player setting in chat settings. `aimHide` in `Config.DefaultSettings`.
- Admin panel now has **Channels** and **Chat logs** tabs.
- New tables `rsg_chat_mutes` and `rsg_chat_logs` (created automatically, also in `install.sql`).
- 46 new locale keys in all 11 languages.

### Changed
- `server/extras.lua` holds the new server features; `server/main.lua` calls into it.
- Mentions flag the message per recipient on the server; the NUI only highlights what the server marks.

## 3.3.0

### Security
- Messages are now cut to the channel limit by characters instead of bytes. Russian, Greek and Japanese text was being cut mid-character, which could send broken text to the NUI and gave those players a shorter limit than the box showed.
- Invalid UTF-8 and oversized payloads are dropped before any processing.
- Zero-width and text-direction override characters are stripped from messages and channel text so names and messages can't be spoofed or hidden.
- Colour codes typed by players (`^1`) are stripped before the console log line.
- Malformed suggestions sent by other resources can no longer break the suggestion list; suggestion names with regex characters (for example `/foo(`) no longer throw.

### Added
- `Config.UseKeyMapping` (default `true`) and `Config.OpenKey` (default `'T'`): the open-chat key is now rebindable in the game's key settings through rsg-core `RegisterKey`. Set `UseKeyMapping = false` for the old per-frame control check.
- `Config.ConsoleLog` (default `true`): turn the per-message server console line off.
- Locale key `key_open_chat` in all 11 languages.

### Changed
- With the rebindable key the client no longer runs a `Wait(0)` loop; the screen-state check runs every 250 ms.
- Suggestions are sent to the NUI in one batch instead of one message per command (a few hundred NUI messages saved on every refresh).
- Chat themes are only re-applied when a resource with a `chat_theme` starts or stops, not on every resource start.
- `/clearchat` runs on the client (no server round trip).
- The database auto-build runs inside `pcall` and prints a console line on success or failure.

### Removed
- Unused `animate.css` vendor file, the `window.emulate` debug helper, the unused `ON_COMMANDS_RESET` handler and `defaultChannel` state.
- Unused locale keys `ui_on`, `ui_off`, `ui_disabled`.

## 3.2.1

### Added
- `Config.AutoDatabase` (default `true`): the database tables are built automatically on start. Set it to `false` to skip the auto-build and import the bundled SQL file manually instead.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
