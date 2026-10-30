# rsg-trams

Saint Denis trolleys for RSG Framework.

## Features
- Networked Saint Denis trolleys that every player sees, with map blips
- Speeds, spawn points and station stops taken from Rockstar's ambient trolley code
- Conductor shouts arrival and next-stop announcements with Rockstar's conductor voices (optional)
- Trolleys keep their distance instead of driving through each other
- Smooth braking for people, horses and carts on the rails; NPC traffic that blocks the line is cleared, and a trolley never waits forever (`Config.Avoid`)
- Trolley engine sound forced on every client (`Config.Audio`)
- Admin limit on how many trolleys run at once (`/trams`), saved across restarts
- Free to ride: no fares or tickets
- Self-healing: the server checks every trolley and respawns any that disappear
- Trolleys survive the spawning player leaving; no duplicate trolleys on host change

## How it matches Rockstar
| Rockstar (medium_update.c) | rsg-trams |
|---|---|
| Ambient trains 8-12 `AMBIENT_NBX_TROLLEY*` (func_1283) | `Config.Lines` |
| Config hashes via func_308 (`-1083616881`, `1936859429`, `-272646696`) | `line.config` |
| Spawn coords/direction (func_1284 / func_1285) | `line.coords` / `line.direction` |
| Cruise speed 3.5 (func_775), max 6.0 (func_779) | `Config.CruiseSpeed` / `Config.MaxSpeed` |
| Stops for stations (func_1287) | `Config.StopForStations` |
| Conductor voice `0835_S_M_M_GenConductor_01_WHITE_01-03` (func_1277) | set on each trolley driver |
| Station-based `TROLLEY_ARRIVAL_*` / `TROLLEY_NEXT_*` / `CALL_OUT_NEUTRAL` shouts via `GET_CURRENT_STATION_FOR_TRAIN` (func_773/1278/1279) | `Config.Announce` / `Config.AnnounceRange` |

## How it works
The server picks one player (the host) to create the trolleys as networked mission trains, and stores their network IDs in `GlobalState.rsgTrams`. Every `Config.HostCheckInterval` ms the server checks that each enabled line's trolley still exists and asks the host to respawn any that are missing. Trolleys are set to persist when their owner leaves, and whichever client owns a trolley keeps its cruise speed applied. If the host leaves, the server picks a new one, which only spawns trolleys that are actually missing.

## Requirements
- rsg-core, ox_lib, OneSync enabled

## Install
1. Drop `rsg-trams` into `resources/[framework]`.
2. `ensure rsg-trams` after `rsg-core` and `ox_lib`.

## Admin command
| Command | Permission | Description |
|---|---|---|
| `/trams` | `Config.AdminGroup` (default `group.admin`) | Show running trolleys and the current limit |
| `/trams <number>` | same | Set how many trolleys run at once (0 = none). Extra trolleys are removed at once; missing ones spawn within `Config.HostCheckInterval` |

The limit is saved (resource KVP) and overrides `Config.MaxTrams` until changed again.

## Configuration
All options are in `shared/config.lua`:
- `Config.Lines`: which lines are enabled, spawn points and direction. `callOutOnly` makes a line's conductor only use the neutral call-out (Rockstar's upper line).
- `Config.MaxTrams` / `Config.AdminGroup`: default trolley limit and who may change it
- Speeds, passengers/conductor, invincibility, blip sprite and modifier, announcements
- `Config.Audio`: trolley car models that get their sound forced on
- `Config.TrafficGap`: gap kept behind the trolley ahead
- `Config.Avoid`: look-ahead distance and width, braking/acceleration, stop gap, when NPC traffic is cleared (`clearNpcAfter`) and when a blocked trolley moves off anyway (`maxWait`, `pushTime`)

## Tickets
Trolleys are free. Every trolley car carries the `ownFare` state bag, so any ticket system that respects it (rsg-railroad does) leaves trolleys alone and never charges riders.

Support: https://buymeacoffee.com/rexshack
