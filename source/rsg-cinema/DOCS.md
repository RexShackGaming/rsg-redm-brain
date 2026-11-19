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

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-cinema 3.0.1**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-target`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Debug` | `false` | prints setup info (render target, projector, house lights) to the F8 console |
| `Config.TicketPrice` | `1.0` | cash, per showing |
| `Config.ShowInterval` | `15` | minutes between showings (per cinema) |
| `Config.SalesWindow` | `10` | minutes before a showing that tickets go on sale |
| `Config.MaxShowLength` | `600` | seconds; safety cut-off if no client reports end of film |
| `Config.MinShowLength` | `60` | seconds; end-of-film reports earlier than this are ignored |
| `Config.LightsDim` | `0.05` | house light intensity during a film (1.0 = normal, 0.0 = off) |
| `Config.LightsFade` | `3000` | ms to fade the house lights down / up |
| `Config.WatchRadius` | `25.0` | player must be this close to the cinema centre to see the film |
| `Config.SellerSpawnDistance` | `50.0` | ticket seller NPC spawns when a player is this close |
| `Config.AdminCommand` | `'cinemaadmin'` | opens the admin panel (start/stop films) |
| `Config.AdminPermission` | `'admin'` |  |
| `Config.Films` | `table` | label = locale key (locales/*.json); cinema labels below are locale keys too |
| `Config.Cinemas` | `table` | projector = coords of the S_MOVIEPROJECTION01X map light (Rockstar pins it and projects the film through it) |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-cinema:server:getDraws` | server | `_, cb` | `server/server.lua` |
| `rsg-cinema:server:getInfo` | server | `src, cb, id` | `server/server.lua` |
| `rsg-cinema:server:buyTicket` | server | `src, cb, id` | `server/server.lua` |
| `rsg-cinema:server:adminData` | server | `src, cb` | `server/server.lua` |
| `rsg-cinema:server:adminAction` | server | `src, cb, action, id, filmIndex` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-cinema:server:getDraws', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-cinema:client:startFilm` | client | `id, playlist, filmLabel, ticket` | `client/client.lua` |
| `rsg-cinema:client:stopFilm` | client | `id` | `client/client.lua` |
| `rsg-cinema:client:setDraw` | client | `` | `client/client.lua` |
| `rsg-cinema:client:openAdmin` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `rsg-cinema:server:filmEnded` | server | `id` | `server/server.lua` |
| `rsg-cinema:server:sync` | server | `` | `server/server.lua` |
| `rsg-cinema:server:adminSetDraw` | server | `id, d` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-cinema:server:filmEnded', id)
-- from a server script
TriggerClientEvent('rsg-cinema:client:startFilm', source, id, playlist, filmLabel, ticket)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
