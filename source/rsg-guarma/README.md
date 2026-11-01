# rsg-guarma

Boat travel between **Saint Denis** and **Guarma** for the RSG Framework (RedM).

Players buy boat tickets from a port worker, then sail to the other port. The script swaps the world horizon, water and minimap automatically when you enter or leave Guarma, including when you log in there or an admin teleports you.

## Features
- Port worker NPCs (ox_target) at both ports, which fade in and out with distance
- One ticket office NUI at the port worker (house leather & gold style): buy tickets with a quantity stepper, see your cash, tickets owned and the live total, and travel (each trip uses one `boat_ticket`)
- Travel is a simple fade out, teleport and fade in
- Server-side validation of distance, ticket amount, inventory space, money and per-player cooldowns
- Players who are dead, handcuffed or jailed can't sail away
- Ports, prices, cooldowns and coords all set in `shared/config.lua`
- Map blips that are removed when the resource stops; all text in `locales/`

### Guarma like the original game
Built from the RDR2 decompiled Guarma scripts (`guama1-3.c`, `camp_guarma.c`, `aguasdulces.c`, `region_law_guama_fussar.c`):
- **Island ambience:** the story-mode Guarma ambient sounds (`AZL_Endlesss_Summer`)
- **Shipwreck:** loads the story steamer map data (`Guarma_Boat`)
- **Population:** configurable ambient and scenario ped density while on the island (the per-frame loop only runs if you change a value from 1.0)
- **Island weather:** the server picks one shared Guarma weather (including the Guarma hurricane variation) through rsg-weather
- **Fussar's soldiers:** hostile `s_m_m_fussarhenchman_01` patrols on the original story routes, with snipers on the high ground

## Languages
Included: en, de, el, es, fr, ja, nl, pl, pt-br, ro. Set your language with ox_lib's `setr ox:locale <lang>` in server.cfg (for example `setr ox:locale de`).

## Dependencies
- rsg-core
- rsg-weather (optional, for island weather)
- rsg-inventory
- ox_lib
- ox_target

## Installation
1. Put `rsg-guarma` in your resources folder and add `ensure rsg-guarma` to your server.cfg, after the dependencies.
2. Add the item from `installation/shared_items.lua` to `rsg-core/shared/items.lua`.
3. Copy `installation/images/boat_ticket.png` to `rsg-inventory/html/images/`.
4. Change prices and settings in `shared/config.lua` if you want to.

## Configuration
| Option | Description |
|---|---|
| `TicketItem` | Ticket item name (`boat_ticket`) |
| `TicketCost` | Cash per ticket |
| `MaxTickets` | Max tickets per purchase |
| `BuyCooldown` / `TravelCooldown` | Cooldowns in seconds |
| `InteractRadius` | How close the player must be to the NPC (checked on the server; the ticket office also closes if you move further away) |
| `TravelTime` | How long (ms) the screen stays black while travelling |
| `DistanceSpawn` / `FadeIn` | Port worker spawn distance and fade in/out |
| `Blip` | Port blip sprite and scale |
| `Ports` | Each port's NPC model and coords, arrival point, destination and blip |
| `Guarma` | Ambience, shipwreck and population density |
| `Weather` | Island weather on/off, change interval and weighted weather types |
| `Soldiers` | Patrols on/off, model, weapons, ped count, spawn distance and each route (on/off, sniper) |

**Notes**
- While a player is on Guarma, their rsg-weather sync is paused so the island can have its own weather. Sync (weather and time) resumes when they leave.
- Soldiers are networked and spawned by the server, so everyone sees and fights the same patrols. Each route spawns when any player gets close and despawns (dead soldiers included) once nobody is near. Requires OneSync. The route nearest the port is off by default.

## Support
Support: https://buymeacoffee.com/rexshack
