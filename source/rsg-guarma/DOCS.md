# rsg-guarma — Developer & Owner Docs

## Contents
1. Architecture
2. Data / config
3. Events & callbacks
4. Security model
5. Database
6. Integration notes
7. Troubleshooting
8. Support

## Architecture

| File | Purpose |
|---|---|
| `shared/config.lua` | All settings |
| `client/guarma.lua` | World horizon / water / minimap / ambience / shipwreck / weather / time / population |
| `client/travel.lua` | Boarding countdown, boarding checks, crossing and arrival |
| `client/client.lua` | Blips and ticket office NUI |
| `client/npcs.lua` | Port worker spawn / despawn / `rsg-target` |
| `client/soldiers.lua` | Local owner AI for networked Fussar patrols |
| `server/database.lua` | `Guarma` namespace, table setup, per-character records |
| `server/utils.lua` | Shared server helpers |
| `server/management.lua` | Closures, discounts, port income, command |
| `server/customs.lua` | Arrival searches |
| `server/trade.lua` | Island cargo |
| `server/server.lua` | Office data, tickets, schedule, departure, rescue, island weather |
| `server/soldiers.lua` | Soldier spawning and alert level |
| `server/versionchecker.lua` | Optional remote version check |
| `html/` | Ticket office, boarding countdown, crossing screen |

## Data / config
- Ports are keyed by id (`stdenis`, `guarma`). Each has `npccoords`, `arrival`, `destination`, `guarma`, `customs`, `rescue`, `society`.
- Guarma detection: `x >= 0` and `y <= -4096`.
- Weather: `GlobalState.guarmaWeather`, applied by clients on the island. Because rsg-weather's sync switch also covers the clock, the client passes `GlobalState.rsgTime` to `setMyTime` while there.
- **Schedule:** departures fall on multiples of `interval` counted from the Unix epoch (10 min = :00, :10, :20...). Keep `boarding` shorter than the interval, or boarding is always open. If a hurricane or manual closure applies at departure, nobody sails and no ticket is taken.
- **Return pair:** two ordinary `boat_ticket` items at `ReturnTicket.price`. They can be traded like any ticket. Needs `MaxTickets >= 2`.
- **Rescue:** only cash and bank are counted. Money or tickets kept in a stash or given to a friend are not detected; the cooldown and long crossing limit abuse.
- **Customs:** carried inventory only. Items in horse, wagon or stash storage are not searched. The seizure happens as the boat leaves; the message and alert follow on arrival.
- **Cargo:** goods must have no other source. Selling uses `exports['rsg-economy']:Quote` / `Record` (market price, trade tax, reputation) for `Trade.region`; without rsg-economy it pays `sell` x quantity. The daily limit is per character, per good, per UTC day. There is no separate sell limit.
- **Alert:** only soldiers killed by a player's ped count (`GetPedSourceOfDeath`); kills credited to a vehicle or another entity do not. Reinforcements join patrols that still have a living soldier, and later spawns. A wiped patrol is replaced after `Soldiers.respawnTime`. The level resets on restart.
- **Port income:** `incomeShare` of ticket sales is paid with `exports['rsg-society']:AddMoney`. The society must exist. Cargo money is not shared.
- `AllowPushToTalkWhileOpen` / `PushToTalkControls`: while the office is open all game controls are disabled except these.

## Events & callbacks

### Server callbacks
- `rsg-guarma:server:getOffice` `(portId)` -> office table (price, returnPrice, discount, max, cash, owned, closed, schedule, rescue, cargo, alert) or `false`. Requires being at the port.
- `rsg-guarma:server:buyTicket` `(portId, amount, kind)` -> `true|false`. `kind` is `'single'` or `'return'` (amount ignored).
- `rsg-guarma:server:trade` `(portId, item, qty)` -> `true|false`. The port decides whether it is a buy or a sale.

### Server events
- `rsg-guarma:server:requestTravel` `(portId)`: boards the next sailing, or departs at once when the schedule is off.
- `rsg-guarma:server:cancelBoarding`
- `rsg-guarma:server:requestRescue` `(portId)`

### Client events and callbacks
- `rsg-guarma:client:performTravel` `(destId, seconds)`: server only.
- `rsg-guarma:client:boarded` `(portId, secondsLeft)` / `rsg-guarma:client:boardingEnded`
- `rsg-guarma:client:canBoard` (client callback): false when dead, hogtied, lassoed, mounted, in a vehicle or travelling.
- `rsg-guarma:client:guarmaChanged` `(state)`: local event on entering or leaving Guarma.

### GlobalState
- `guarmaWeather`: island weather type.
- `guarmaSoldiers`: soldier network ids.

## Security model
- All money and item changes are server-side. Prices, discounts, limits and rewards come from server config.
- Buying, trading and boarding check distance with server coords. Departure re-checks player state, distance (`Schedule.boardRadius`), closure and ticket after waiting for the client.
- A ticket is removed only at departure; disconnecting or walking away earlier costs nothing.
- Cargo trades are locked per character, so parallel requests can't beat the daily limit. If the database can't be read, buying and rescue are refused.
- Hogtied, lassoed and mounted states exist only on the player's client, so a modified client can skip those checks.
- Teleporting runs on the client, so general teleport cheating needs an anti-cheat. A cheater who teleports skips customs.

## Database

| Table | Columns |
|---|---|
| `rsg_guarma_players` | `citizenid` (key), `trade_day`, `bought` (JSON), `rescue_at` (unix time) |

Created on start when `Config.AutoDatabase = true`; otherwise import `install.sql`.

## Integration notes
- Targeting uses `rsg-target`; notifications, callbacks and locales come from rsg-core.
- All optional integrations are skipped when the resource isn't started.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Target option missing on NPC | `rsg-target` not started, or player outside spawn distance |
| Cargo tab missing or empty | `guarma_*` items not added to shared items, `Trade.enabled = false`, or (Guarma) database not ready |
| "Port ledger is unavailable" | Database table missing or oxmysql error: check the server console |
| Board button greyed out | No ticket, boarding not open yet, or port closed |
| "You missed the boat" | Mounted, hogtied or slow to respond at departure |
| No ticket income | `society` not set on the port, wrong name, or rsg-society not started |
| No island weather or hurricane closures | `Weather.enabled = false` or rsg-weather not started |
| Soldiers not spawning | `Soldiers.enabled = false`, OneSync off, or routes disabled |
| Push-to-talk not working with the UI open | `AllowPushToTalkWhileOpen = false`, or your voice key isn't in `PushToTalkControls` |

## Support
Support: https://rexshack.tebex.store

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

**rsg-guarma 3.1.0**. Dependencies: `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`. Configuration defaults are in `shared/config.lua`; events and callbacks are listed above.

- Items: `boat_ticket`, `guarma_sugar`, `guarma_coffee`, `guarma_rum`, `guarma_cigars`
- Command: `/guarmaport`
- Locales: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru` (`setr rsg:locale "en"`)

<!-- END AUTO-REFERENCE -->
