# rsg-guarma

Boat travel between **Saint Denis** and **Guarma** for the RSG Framework (RedM).

Version **3.1.1**. See [DOCS.md](DOCS.md) for architecture, events, security and troubleshooting.

Players buy boat tickets from a port worker, then sail to the other port. The script swaps the world horizon, water and minimap automatically when you enter or leave Guarma, including when you log in there or an admin teleports you.

## Features
- Port worker NPCs (`rsg-target`) at both ports, which fade in and out with distance
- NUI ticket office: buy tickets and travel. The window can be moved, and each player's position is remembered
- Server-authoritative purchases and travel (distance, cooldowns, inventory, money)
- Sailing schedule with a boarding window and countdown (or instant travel)
- Crossing screen and arrival banner
- Discounted return pair, and a slow rescue passage for stranded players
- Customs searches on arrival at Saint Denis
- Island cargo trade with daily limits
- Fussar alert level with reinforcements
- Port management: job discounts, society income, hurricane closures, `/guarmaport`
- Guarma world switch: horizon, water type, minimap zone, ambience, shipwreck IPL
- Optional shared island weather via rsg-weather (player sync paused while on Guarma)
- Configurable ambient / scenario ped density on the island
- Fussar's soldiers: networked hostile patrols on story routes (optional)

## Dependencies
- rsg-core
- rsg-inventory
- rsg-target
- oxmysql
- Optional: rsg-weather (island weather and hurricane closures), rsg-zonenotify (arrival banner), rsg-economy (cargo prices), rsg-lawman (customs alerts), rsg-reputation (alert penalties), rsg-society (ticket income)

## Installation
1. Put `rsg-guarma` in your resources folder and add `ensure rsg-guarma` to `server.cfg` after the dependencies.
2. Add the items from `installation/shared_items.lua` (the ticket and four `guarma_*` goods) to `rsg-core/shared/items.lua` (or your items source). The goods reuse existing inventory images.
3. Copy `installation/images/boat_ticket.png` to `rsg-inventory/html/images/`.
4. The database table is created automatically on first start. For a manual install, set `Config.AutoDatabase = false` and import `install.sql`.
5. Adjust prices and settings in `shared/config.lua` if needed. To pay ticket income to a society, set `society` on a port.

## Configuration

| Option | Description |
|---|---|
| `TicketItem` | Ticket item name (`boat_ticket`) |
| `TicketCost` | Cash per ticket |
| `MaxTickets` | Max tickets per purchase |
| `BuyCooldown` / `TravelCooldown` | Cooldowns in seconds |
| `InteractRadius` | Server-side max distance from the port NPC |
| `TravelTime` | How long (ms) the screen stays black when `Voyage.enabled = false` |
| `AutoDatabase` | Build the database table on start (`true`) |
| `Schedule` | `enabled`, `interval` (10 min), `boarding` (120s), `boardRadius` (25m) |
| `Voyage` | Crossing screen: `enabled`, `duration` (12s), `banner` |
| `ReturnTicket` | `enabled`, `price` for two tickets ($18) |
| `Rescue` | `enabled`, `voyage` (60s), `cooldown` (60 min) |
| `Customs` | `enabled`, `chance` (25%), `fine` ($25), `alertLawmen`, `outlawStatus`, `exemptJobTypes`, `items` |
| `Trade` | `enabled`, `buyPort`, `sellPort`, `dailyLimit` (20 of each), `region`, `goods` |
| `Management` | `discounts`, `incomeShare`, `hurricaneClosure`, `command`, `adminPermission` |
| `Alert` | `enabled`, `decayMinutes`, `levels`, `reputation` |
| `DistanceSpawn` / `FadeIn` | Port worker spawn distance and fade in/out |
| `AllowPushToTalkWhileOpen` / `PushToTalkControls` | Keep push-to-talk working while the ticket office is open (default on) |
| `Blip` | Port blip sprite and scale |
| `Ports` | Each port's NPC model and coords, arrival point, destination, blip, `customs`, `rescue` and `society` |
| `Guarma` | Ambience, shipwreck and population density |
| `Weather` | Island weather on/off, change interval and weighted weather types |
| `Soldiers` | Patrols on/off, model, weapons, ped count, spawn distance, `respawnTime` (default 600s, 0 = only once everyone leaves) and each route |

**Notes**
- While a player is on Guarma, their rsg-weather sync is paused so the island can have its own weather. The clock still follows the server time. Sync resumes when they leave.
- Soldiers are networked and spawned by the server. Requires OneSync. The route nearest the port is off by default.

## How to use
1. Approach a port worker at Saint Denis or Guarma and use the target option.
2. Buy tickets with cash (**Max** picks as many as you can afford), or a discounted return pair.
3. During the boarding window, choose **Board**. Stay near the port worker until the boat leaves; walk away to cancel. Dismount before the boat leaves.
4. **Cargo:** buy goods from the Guarma worker and sell them to the Saint Denis worker.
5. **Stranded:** with no ticket, no island cargo and less than a fare in cash plus bank, choose **Work your passage home** on Guarma.

### Moving the window
Drag the ticket office by its title bar. It stays on screen, and the position is saved on that player's computer. Double-click the title bar to centre it again.

### Command
`/guarmaport <stdenis|guarma> <open|close>` stops or resumes sailings from a port. Admins and the boss of the port's `society` can use it. Closures reset when the resource restarts.

## Locales
Included: en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru.

Set language with `setr rsg:locale <lang>` in `server.cfg` (for example `setr rsg:locale de`).

## Support
Support: https://rexshack.tebex.store
