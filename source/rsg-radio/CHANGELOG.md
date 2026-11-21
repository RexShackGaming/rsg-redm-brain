# Changelog

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
