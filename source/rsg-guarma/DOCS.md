# rsg-guarma — Developer & Owner Docs

## Contents
1. Architecture
2. Data / config
3. Events & callbacks
4. Security model
5. Integration notes
6. Troubleshooting
7. Support

## Architecture

| File | Purpose |
|---|---|
| `shared/config.lua` | Prices, cooldowns, ports, Guarma world, weather, soldiers |
| `client/guarma.lua` | World horizon / water / minimap / ambience / shipwreck / weather / population |
| `client/client.lua` | Blips, NUI ticket office, travel sequence |
| `client/npcs.lua` | Port worker spawn / despawn / `rsg-target` |
| `client/soldiers.lua` | Local owner AI for networked Fussar patrols |
| `server/server.lua` | Buy ticket callback, travel event, island weather GlobalState |
| `server/soldiers.lua` | Server spawn / despawn of networked soldiers |
| `server/versionchecker.lua` | Optional remote version check |
| `html/` | Ticket office NUI (house monochrome style) |
| `locales/*.json` | Player-facing strings (rsg-core locale loader) |

## Data / config
- Ticket item: `Config.TicketItem` (default `boat_ticket`).
- Ports keyed by id (`stdenis`, `guarma`) with `npccoords`, `arrival`, `destination`, `guarma` flag.
- Guarma detection: client coords with `x >= 0` and `y <= -4096`.
- Weather: `GlobalState.guarmaWeather` set by the server on an interval; clients apply only while in Guarma.

## Events & callbacks

### Server callback
- `rsg-guarma:server:buyTicket` `(portId, amount)` → `true|false`  
  Registered with `RSGCore.Functions.CreateCallback`. Validates distance, cooldown, amount, item existence, inventory space, cash; refunds on failed `AddItem`.

### Server event
- `rsg-guarma:server:requestTravel` `(portId)`  
  Validates player state (dead / cuffed / jail), distance, cooldown, removes 1 ticket, then triggers client travel.

### Client event
- `rsg-guarma:client:performTravel` `(destId)`  
  Server-only (rejects if `GetInvokingResource()` is set). Fades out, applies Guarma world, teleports to arrival, fades in.

### Client event (internal)
- `rsg-guarma:client:guarmaChanged` `(state)` — fired when entering/leaving Guarma; used for population density.

### GlobalState
- `guarmaWeather` — shared island weather type string.
- `guarmaSoldiers` — list of soldier network ids (when soldiers enabled).

## Security model
- All money and item changes are server-side only.
- Buy and travel re-check distance with `GetEntityCoords(GetPlayerPed(src))` against `Config.InteractRadius`.
- Amounts are clamped with `math.tointeger` / range checks; ticket name checked against `RSGCore.Shared.Items`.
- Cooldowns are per-source tables cleaned on `playerDropped`.
- Buy cooldown is applied only after a successful purchase; failed `AddItem` refunds cash.
- Travel event is not trustable from the client for free travel: ticket is removed on the server before the client event is sent.
- NUI callbacks only request server actions; they do not grant items or money.

Calling scripts that teleport players to Guarma do not need extra checks for the world switch — the client loop in `guarma.lua` will apply it from coords.

## Integration notes
- Targeting uses `exports['rsg-target']:addLocalEntity` / `removeLocalEntity` (not ox_target).
- Notifications use `RSGCore:Client:Notify` / `RSGCore.Functions.Notify` (not ox_lib).
- Locales load via `@rsg-core/shared/locale.lua` and `locale('key')` (not `lib.locale`).
- Callbacks use `RSGCore.Functions.CreateCallback` / `AwaitCallback` (not `lib.callback`).
- Optional weather needs `rsg-weather` started; if absent, weather features no-op.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Target option missing on NPC | `rsg-target` not started, or player outside spawn distance |
| Cannot buy tickets | Missing `boat_ticket` in shared items, inventory full, or not enough cash |
| Travel does nothing | No ticket, on cooldown, dead/cuffed/jailed, or still mounted |
| Wrong map / water after teleport | Client Guarma loop should correct within ~1s; check `IsGuarmaCoords` |
| No island weather | `Config.Weather.enabled = false` or `rsg-weather` not started |
| Soldiers not spawning | `Config.Soldiers.enabled = false`, OneSync off, or routes disabled |
| NUI fonts missing | Google Fonts blocked offline; UI still works with system fallback |

## Support
Support: https://buymeacoffee.com/rexshack
