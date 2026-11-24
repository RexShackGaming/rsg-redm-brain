# Changelog

## 3.3.2
Minor change.

### Fixed
- Typing in the panel's text boxes (favorite name, passcode, private channel name, search) no longer keys the mic when the transmit key letter is typed. The panel tells rsg-voice while a text box has focus (needs **rsg-voice 3.4.0+**; older versions just ignore it).
- The panel hint shows the real transmit key from rsg-voice (`Config.Radio.Key`) instead of the fixed `Config.TransmitKeyLabel`, which is now only the fallback.
- `Config.PushToTalkControls` missing from the config no longer errors while the panel is open.

### Removed
- Three separate `RSGCore:Client:OnPlayerUnload` handlers, merged into one.

## 3.3.1
Minor change.

### Fixed
- Hovering a row in the recents, favorites or channel lists no longer makes the box grow: the 2 px hover shift pushed the row past the list edge and added a scrollbar. Hover now only brightens the row, long names are cut off with an ellipsis, and the lists and panel never scroll sideways.

## 3.3.0
Major update.

### Added
- **Volume test**: a play button next to the volume slider and a `/radiotest` command (`Config.Volume.TestCommand`, `''` = none) ask **rsg-voice** (new export `TestRadioIncoming`, **rsg-voice 3.3.0+**) to play a simulated incoming transmission at its own live radio gain, so you test what rsg-voice really applies and can check how loud the radio is without another player. Plays nothing while muted, without signal or in a call, and says so. New locale keys `ui_test_volume`, `cl_test_silent` and `cl_test_unavailable` in all 11 languages.

## 3.2.1
Minor change.

### Added
- **Volume bleep**: moving the slider plays a short tone at the chosen volume (higher pitch and louder as it goes up; silent when muted or at 0). `Config.Volume.Bleep = false` turns it off.

## 3.2.0
Major update.

### Added
- **Volume slider is back** next to the mute button in the panel, saved per character (`radiosettings` metadata) and applied through rsg-voice.
- `Config.Volume` is a table again: `{ Default = 50, Step = 5 }`. The default is now 50% (it was 100%, which was too loud), so new characters start at a sensible level. Existing saved values are kept.

### Changed
- `rsg-radio:server:setSettings` takes `vol` and `muted` again, and the `ui_volume` locale key is back in all 11 languages.
- NUI callbacks are `setVolume` / `saveVolume` again.
- Config change: replace `Config.Volume = 50` with `Config.Volume = { Default = 50, Step = 5 }`.

## 3.1.1
Minor change.

### Changed
- **Removed the volume slider** from the panel (it did not work as expected). The mute button stays.
- New `Config.Volume` (percent, default `50`) sets how loud incoming radio is for everyone, since the old default was too loud. It replaces the old `{ Default, Step }` table; change the value to a plain number.
- `rsg-radio:server:setSettings` now takes only `muted`; the `ui_volume` locale key is removed from all 11 languages.
- NUI callbacks `setVolume` / `saveVolume` renamed `setMute` / `saveMute`.
- Panel lists keep their scroll position on live updates.
- Opening the panel is rate limited on the server (250 ms) and debounced on the client, so key spam cannot flood the server with state builds.
- The hogtie report, signal interference, handheld and battery loops now only run when their feature is enabled.
- Unchanged private channel saves no longer write to the database; finished staff blocks are cleaned up hourly.

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
