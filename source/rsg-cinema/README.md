# rsg-cinema

Moving picture shows for the RSG Framework.
Films are projected through each cinema's own projector light, exactly as in single player.

## Features
- **Ticket seller** NPC (ox_target) with NUI: next film, countdown and price. Sellers only spawn when a player is nearby.
- **Scheduled showings** per cinema (server-run). Films play in rotation; a showing is skipped when no tickets were sold.
- **Tickets** are paid in cash on the server, one per character per showing. Only ticket holders inside the cinema see and hear the film.
- **House lights** fade down while a film plays and back up afterwards (Rockstar's own light positions).
- **Admin panel** (`/cinemaadmin`):
  - pick a film and start or stop it at any cinema (admin starts are free showings for everyone inside)
  - stopping a paid showing refunds online ticket holders
  - **Picture** sliders to position and size the film on the screen, with a live preview; **Save** applies it for everyone and keeps it in `data/draw.json`
  - the panel can be dragged by its header (double-click the header to re-centre)
- Cinemas: **Saint Denis** and **Blackwater** enabled, **Valentine** ready in config.

## Languages
All player-facing text (notifications, NUI, ox_target label, blip, film and cinema names) is in ox_lib locales:
`en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr ox:locale "de"` in server.cfg.
Film and cinema `label` values in the config are locale keys.

## Requirements
- rsg-core, ox_lib, ox_target

## Installation
1. Drop `rsg-cinema` into your resources folder.
2. Add `ensure rsg-cinema` to your server.cfg (after rsg-core, ox_lib and ox_target).
3. Make sure the server can write to `rsg-cinema/data/draw.json` (picture settings).

## Configuration (`shared/config.lua`)
| Setting | Purpose |
|---|---|
| `TicketPrice` | Cash price per ticket |
| `ShowInterval` / `SalesWindow` | Minutes between showings / minutes before a showing that tickets go on sale |
| `MaxShowLength` / `MinShowLength` | Safety cut-off, and the minimum runtime before an end-of-film report is accepted |
| `LightsDim` / `LightsFade` | House light level during a film (1.0 normal, 0.0 off) and fade time in ms |
| `WatchRadius` | How close to the cinema centre a player must be to see the film |
| `SellerSpawnDistance` | Distance at which the ticket seller spawns |
| `AdminCommand` / `AdminPermission` | Admin panel command and RSG permission level |
| `Films` | Rockstar TV playlists and their display names |
| `Cinemas` | Per-town setup (see below) |

### Adding a town
Copy a block in `Config.Cinemas`, give it a new id and set `enabled = true`. Each cinema needs:
`centre`, `renderTarget`, `linkModel`, `screen` (hidden render-target object), `projector` (map projector light),
`draw`, `volume`, `seller`, `films` (indexes into `Config.Films`), optional `lights`, `entitySets` and `blip`.
The values for the Rockstar cinemas come from `show_movie_magic_lantern.c` (func_76, func_103-113, func_154, func_156)
and `theatre_ticket_taker.c` (func_13).

## Troubleshooting
Set `Config.Debug = true` to print render target, projector and house light setup to the F8 console.

Support: https://buymeacoffee.com/rexshack
