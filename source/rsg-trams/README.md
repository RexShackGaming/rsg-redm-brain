# rsg-trams

Saint Denis trolleys for RSG Framework, with **one trolley on the Saint Denis loop**.

## Features
- One networked trolley on the Saint Denis loop (upper and inner tracks removed), with map blips
- Only one trolley ever: if a trolley already exists anywhere, no new one is spawned (a lost one is re-adopted)
- Server enforces one trolley: a second or late spawn is deleted, stray cars are swept every check
- Speeds, spawn points and station stops from Rockstar's ambient trolley code
- Conductor shouts arrival and next-stop announcements with Rockstar's conductor voices
- Smooth braking for people, horses, carts and other trolleys on the rails; NPC traffic that blocks the line is cleared, and a trolley never waits forever
- Trolley engine sound forced on every client
- Admins turn the loop on/off in-game (`/trams`), saved across restarts
- Free to ride: every car carries the `ownFare` state bag, so rsg-railroad never charges riders
- Self-healing: missing or driverless trolleys are replaced; trolleys survive the spawning player leaving
- No ox_lib: rsg-core locales, notify and commands. Languages: en, de, el, es, fr, ja, nl, pl, pt-br, ro

## Requirements
- rsg-core, OneSync

## Install
1. Drop `rsg-trams` into `resources/[framework]`.
2. `ensure rsg-trams` after `rsg-core`.
3. Optional: `setr rsg:locale "en"` in server.cfg for the language.

No database is used.

## Admin command
| Command | Description |
|---|---|
| `/trams` | Status of every track (running / spawning / off) |
| `/trams loop <on\|off>` | Turn the loop on or off (saved with resource KVP) |
| `/trams reset` | Remove all trolleys; they respawn on the next check |

Permission: `Config.AdminPermission` (rsg-core permission, default `admin`).

## Upgrading from 3.x
`Config.Lines` and `Config.MaxTrams` are gone. The three main-loop lines (Rockstar 8/9/10) are now one `loop` track with one trolley. The upper and inner tracks were removed. `/trams <number>` is replaced by per-track on/off. ox_lib is no longer needed.

See `DOCS.md` for configuration and internals.

Support: https://buymeacoffee.com/rexshack
