# rsg-cinema – Docs (v3.0.1)

## Contents
1. Files
2. How it works
3. Configuration
4. Events and commands
5. Security
6. Server owner how-tos
7. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-target` |
| `shared/config.lua` | Prices, schedule, lights, films, cinemas |
| `client/client.lua` | Projector, render target, house lights, ticket seller, admin NUI |
| `server/server.lua` | Schedule, tickets, refunds, admin actions |
| `server/versionchecker.lua` | GitHub version check |
| `data/draw.json` | Saved picture position and size per cinema |
| `html/` | NUI (ticket seller panel and admin panel) |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## 2. How it works
Moving picture shows rebuilt from the RDR2 `show_movie_magic_lantern` script. Films are projected through each cinema's own projector light, as in single player.
- **Ticket seller** NPC (rsg-target) with an NUI panel: next film, live countdown and price. The panel refreshes while open and closes if you walk away. Sellers spawn only when a player is near.
- **Scheduled showings** per cinema, run by the server. Films play in rotation; a showing is skipped if no tickets were sold.
- **Tickets** are paid in cash on the server, one per character per showing. Only ticket holders inside the cinema see and hear the film.
- Several cinemas can run at once; you see whichever one you are inside.
- **House lights** fade down during a film and back up afterwards.
- Cinemas: Saint Denis, Valentine, Blackwater. Other towns can be added in `Config.Cinemas`.
- **Admin panel** (`/cinemaadmin`): start or stop a film at any cinema (admin starts are free showings; starting a free showing or stopping a paid one refunds online ticket holders). **Picture** sliders position and size the film on screen with a live preview; **Save** applies it for everyone and stores it in `data/draw.json`.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `Debug` | `false` | Setup info in F8 |
| `TicketPrice` | `1.0` | Cash per showing |
| `ShowInterval` | `15` | Minutes between showings per cinema |
| `SalesWindow` | `10` | Minutes before a showing that tickets go on sale |
| `MaxShowLength` | `600` | Seconds; safety cut-off |
| `MinShowLength` | `60` | Seconds; earlier end reports are ignored |
| `LightsDim` / `LightsFade` | `0.05` / `3000` | House light intensity and fade ms |
| `WatchRadius` | `25.0` | Distance from the cinema centre to see the film |
| `SellerSpawnDistance` | `50.0` | Ticket seller spawn range |
| `AdminCommand` / `AdminPermission` | `'cinemaadmin'` / `'admin'` | Admin panel |
| `Films` | list | `{ playlist, label }`; playlist is a TV playlist from the game script, label a locale key |
| `Cinemas` | table | Per cinema: `enabled`, `label`, `centre`, `renderTarget`, `linkModel`, `projModel`, `screen`, seller position, lights, playlists |

To add a town, copy a `Cinemas` entry and set its coordinates, models and locale label.

## 4. Events and commands
| Name | Side | Notes |
|---|---|---|
| `rsg-cinema:server:getInfo` | callback | `(id)` next film, countdown, price |
| `rsg-cinema:server:buyTicket` | callback | `(id)` |
| `rsg-cinema:server:filmEnded` | server event | `(id)` |
| `rsg-cinema:server:sync` | server event | State on login |
| `rsg-cinema:server:getDraws` | callback | Saved picture settings |
| `rsg-cinema:server:adminData` / `adminAction` | callbacks | Admin panel (permission-checked) |
| `rsg-cinema:server:adminSetDraw` | server event | `(id, d)` |
| `rsg-cinema:client:startFilm` | client event | `(id, playlist, filmLabel, ticket)` |
| `rsg-cinema:client:stopFilm` | client event | `(id)` |
| `rsg-cinema:client:setDraw` | client event | Apply picture settings |
| `rsg-cinema:client:openAdmin` | client event | Open the admin panel |

| Command | Who | What |
|---|---|---|
| `/cinemaadmin` | `AdminPermission` | Admin panel |

## 5. Security
Tickets are bought and checked on the server (one per character per showing). Only ticket holders see the film. Admin actions and picture changes are permission-checked, and refunds are issued by the server.

## 6. How-tos
- Change the schedule with `ShowInterval` and `SalesWindow`.
- Fix the picture position: `/cinemaadmin` → Picture → adjust → Save.
- Add a film: add a `Films` entry and its `film_<name>` locale key.

## 7. Troubleshooting
| Problem | Fix |
|---|---|
| Showing skipped | No tickets were sold |
| Black screen | Stay within `WatchRadius` and hold a ticket; check `Debug` output |
| Seller missing | Move within `SellerSpawnDistance` |
| Picture off-centre | Adjust it in the admin panel and Save |

Support the Project : https://rexshack.tebex.store/
