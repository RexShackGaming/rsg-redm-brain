# Changelog

## 3.1.0
Major update. Needs **rsg-voice 3.2.0+**.

### Added
- **Radio volume slider and mute button** in the panel, saved per character (`radiosettings` metadata) and applied through rsg-voice.
- **Channel HUD**: who is on your channel and who is speaking, visible with the panel closed. `Config.Hud` (top left by default, drag it to move it while the panel is open), `/radiohud` toggle, names as character, callsign or id.
- **Search, recent frequencies and a compact menu**. Recents are saved per character (`radiorecents` metadata, `Config.Recents`); the search box filters channels, private channels, favorites and recents; the compact toggle is remembered.
- **Handheld radio prop and animation** while transmitting, seen by nearby players (`Config.Handheld`, off by default). No animation or prop is set by default; `Anim`, `AnimFemale` (female peds) and `Model` are all optional.
- **Automatic disconnect when downed, cuffed or hogtied** (`Config.Incapacitated`), with an optional rejoin when the player recovers. They cannot tune in while it lasts.
- **Reserved frequency ranges** (`Config.Ranges`) with the same job, job type, gang, duty and grade rules as channels, plus a new `permission` rule (rsg-core permission level) for both ranges and channels.
- **Instant access updates**: losing the radio, changing job or gang, going on or off duty, or becoming downed or cuffed now takes effect immediately. The periodic check stays as a fallback.
- **Optional battery** (`Config.Battery`): charge stored in the radio item, drain while tuned in and while transmitting, low warning, a flat radio cannot connect, recharge with a battery item. Export `GetBattery`.
- **Optional signal interference** (`Config.Interference`): dead zones and weak spots that quiet the channel, add static and, at zero signal, block transmitting.
- New locale keys in all 11 languages.

### Changed
- `Config.Channels` entries accept `permission`.
- With `Config.Battery.Enabled` the auto-registered radio item becomes unique.

### Notes
- The transmit-time limit and the call and party priority are rsg-voice settings (`Config.Radio.MaxTransmitSeconds`, `Config.Priority`).

## 3.0.0
First release of rsg-radio for RSG 3. Includes:
- Radio item and `/radio` command with a movable, leather-and-gold NUI; push-to-talk keeps working while it is open.
- Real frequencies (default `100.0`–`470.0 MHz`, configurable range, decimals and unit) with live feedback in the UI.
- Restricted channels by job, job type or gang, with `onduty`, `minGrade` and multi-job support.
- Favorites (per character, with names) and next/previous favorite hotkeys.
- Live member counts in the open panel.
- Private passcode channels (cost, limits, wrong-passcode lockout, expiry) stored in `rsg_radio_private`, built automatically (`Config.AutoDatabase`) or imported from `install.sql`.
- Staff chat commands and the `/radioadmin` panel (channels, members, private channels, blocks, action log) with optional Discord webhook.
- Radio and access checks while connected; export `GetFrequency`.
- 11 languages (en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru).
