# rsg-guarma

Boat travel between **Saint Denis** and **Guarma** for the RSG Framework (RedM).

Version **3.0.1**. See [DOCS.md](DOCS.md) for architecture, events, security and troubleshooting.

Players buy boat tickets from a port worker, then sail to the other port. The script swaps the world horizon, water and minimap automatically when you enter or leave Guarma, including when you log in there or an admin teleports you.

## Features
- Port worker NPCs (`rsg-target`) at both ports, which fade in and out with distance
- NUI ticket office: buy tickets and travel
- Server-authoritative purchases and travel (distance, cooldowns, inventory, money)
- Guarma world switch: horizon, water type, minimap zone, ambience, shipwreck IPL
- Optional shared island weather via rsg-weather (player sync paused while on Guarma)
- Configurable ambient / scenario ped density on the island
- Fussar's soldiers: networked hostile patrols on story routes (optional)

## Dependencies
- rsg-core
- rsg-inventory
- rsg-target
- rsg-weather (optional, for island weather)

## Installation
1. Put `rsg-guarma` in your resources folder and add `ensure rsg-guarma` to `server.cfg` after the dependencies.
2. Add the item from `installation/shared_items.lua` to `rsg-core/shared/items.lua` (or your items source).
3. Copy `installation/images/boat_ticket.png` to `rsg-inventory/html/images/`.
4. Adjust prices and settings in `shared/config.lua` if needed.

## Configuration

| Option | Description |
|---|---|
| `TicketItem` | Ticket item name (`boat_ticket`) |
| `TicketCost` | Cash per ticket |
| `MaxTickets` | Max tickets per purchase |
| `BuyCooldown` / `TravelCooldown` | Cooldowns in seconds |
| `InteractRadius` | Server-side max distance from the port NPC |
| `TravelTime` | How long (ms) the screen stays black while travelling |
| `DistanceSpawn` / `FadeIn` | Port worker spawn distance and fade in/out |
| `Blip` | Port blip sprite and scale |
| `Ports` | Each port's NPC model and coords, arrival point, destination and blip |
| `Guarma` | Ambience, shipwreck and population density |
| `Weather` | Island weather on/off, change interval and weighted weather types |
| `Soldiers` | Patrols on/off, model, weapons, ped count, spawn distance and each route |

**Notes**
- While a player is on Guarma, their rsg-weather sync is paused so the island can have its own weather. Sync resumes when they leave.
- Soldiers are networked and spawned by the server. Requires OneSync. The route nearest the port is off by default.

## How to use
1. Approach a port worker at Saint Denis or Guarma.
2. Use the target option to open the ticket office.
3. Buy one or more boat tickets with cash.
4. Press Travel (requires at least one ticket). Dismount first if on a horse or in a vehicle.

## Locales
Included: en, de, el, es, fr, ja, nl, pl, pt-br, ro.

Set language with `setr rsg:locale <lang>` in `server.cfg` (for example `setr rsg:locale de`).

## Support
Support: https://buymeacoffee.com/rexshack
