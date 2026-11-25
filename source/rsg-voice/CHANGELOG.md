# Changelog

All notable changes to rsg-voice. Newest first.

## 3.4.1
Minor change.

### Fixed
- Radio transmit needed two keys: with push-to-talk, players had to hold the game's voice key (N) together with the radio key, because switching the voice target does not open the microphone. While transmitting, rsg-voice now holds the push-to-talk control every frame (a dedicated thread that sleeps when not transmitting). `Config.Radio.ForcePushToTalk` (default `true`; `false` keeps the old behaviour). Based on community PR #1, reworked so the control is held every frame instead of ten times a second.

## 3.4.0
Major update.

### Added
- **Rebindable keys**: the voice range key and the party talk key are now bound by name through rsg-core `RegisterKey` (`Config.UseKeyMapping`, `Config.CycleKeyName`, `Config.Party.Key`), so players can rebind them in the game's key settings. Nothing runs every frame for them any more. `Config.UseKeyMapping = false` keeps the old control-hash polling (`CycleKey`, `Party.TalkKey`). New locale keys `key_cycle` and `key_party` (all 11 languages). The radio key uses `RegisterKey` too, under the same command name, so existing rebinds are kept.
- **Push-to-talk keeps working while a voice window is open** (party menu, party invite, HUD editor): `SetNuiFocusKeepInput` plus a control whitelist (`Config.AllowPushToTalkWhileOpen`, `Config.PushToTalkControls`).
- Client exports `GetRadioKeyLabel()` (key name for hints) and `SetRadioInputBlocked(state)` (rsg-radio uses it so typing in its panel does not key the mic).

### Fixed
- Typing an `o` in rsg-radio's text boxes (favorite name, passcode) no longer transmits (see `SetRadioInputBlocked`).
- A shared waypoint with NaN coordinates is rejected on the server.
- The database table creation is wrapped in `pcall` and prints a clear console message, instead of failing the start-up thread.
- `myServerId` is read again when the character loads.
- The `voiceRange` state bag is only written when the range changes (it was written on every mute change too).

### Changed
- Performance: the range key/ring loop, radio transmit loop and party talk loop no longer run every frame while idle (key press and release are handled directly; the loops are a 100 ms safety net). The speaker icon loop only runs every frame while somebody is talking nearby. The radio debug thread only exists with `Config.Radio.Debug = true`.
- Radio transmit starts are rate limited to one per 250 ms on the server (was 100 ms).

### Removed
- The duplicate `RSGCore:Client:OnPlayerUnload` handler and the extra server `playerDropped` mute cleanup path (merged into single handlers).

## 3.3.0

### Added
- **Radio volume test**: client export `TestRadioIncoming()` plays a simulated incoming transmission (squelch, speech-like audio, squelch) in the HUD page at the live radio gain, the same value (`volume x signal`, 0 when muted, no signal or in a call) that is applied to real radio talkers. It returns `{ gain, volume, signal, muted, call, reason }` so the caller can say why it was silent, and prints the values in F8 with `Config.Radio.Debug`. rsg-radio's volume test button and `/radiotest` call it.

## 3.2.0

### Added
- **Radio listening settings** for rsg-radio: client exports `SetRadioVolume`, `GetRadioVolume`, `SetRadioMuted`, `IsRadioMuted`, `SetRadioSignal`, `GetRadioSignal`. Volume, mute and signal scale what you hear on the radio; signal 0.0 also blocks transmitting. The radio static follows them.
- **Transmit time limit**: `Config.Radio.MaxTransmitSeconds` (0 = unlimited) and `Config.Radio.TransmitCooldown`. New locale key `cl_radio_timeout` (all 11 languages).
- **Call priority**: `SetCallActive` / `IsCallActive` exports and `Config.Priority.Call`. During a phone call radio and party transmit are blocked and incoming radio and party voice are muted. rsg-telephone 3.1.1 reports its calls.
- **Radio or party priority**: `Config.Priority.RadioVsParty` (`'first'` keeps the old behaviour, `'radio'`, `'party'`).

### Fixed
- New server-only event `rsg-voice:server:radioTalkChanged (src, state)`, fired after a transmit change is validated, so other resources do not have to listen to the client-facing `radioTalk` net event (which logged "not safe for net").
- Letting go of one channel (radio, party) no longer resets the voice target while the other channel or a phone call is using it.

## 3.1.3

### Fixed
- Radio transmit key did nothing on setups where the game never reports the O control hash. The key is now bound with `RegisterKeyMapping` (`Config.Radio.UseKeyMapping`, `Config.Radio.Key`), so it works by key name and can be rebound by players. `TalkKey` is kept as a fallback. New locale key `ui_radio_key` (all 11 languages).

## 3.1.2

### Added
- `Config.Radio.Debug`: prints the radio transmit key state and the reason it is blocked in the F8 console (on key changes and every 3 s) and the names of any known keys the game reports as pressed, for troubleshooting.

## 3.1.1

### Added
- Radio static: squelch burst when a transmission starts/ends and a low hiss while someone transmits on your channel (WebAudio in `html/index.html`). `Config.Radio.Static` (`Enabled`, `Volume`, `Hiss`, `Squelch`, `SelfHiss`).

## 3.1.0

### Added
- Radio channels (audio only). Server exports `JoinRadio(src, freq)`, `LeaveRadio(src)`, `GetPlayerRadio(src)`, `GetRadioMembers(freq)`; client exports `GetRadio()`, `IsRadioTalking()`, `GetRadioTalkKey()`; server event `rsg-voice:server:radioChanged`; local client event `rsg-voice:client:onRadioTalk`.
- `Config.Radio` (`Enabled`, `TalkKey`, `NearbyHear`, `MaxMembers`) and `Config.TalkIcon.RadioColour`.
- HUD `RADIO <freq>` tag, lit green while transmitting. New `ui_radio` locale key (all 11 languages).

### Changed
- Party talk yields to the radio while the radio key is held.

## 3.0.5

### Added
- `Config.AutoDatabase` (default `true`): the database tables are built automatically on start. Set it to `false` to skip the auto-build and import the bundled SQL file manually instead.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
