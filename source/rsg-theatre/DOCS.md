# rsg-theatre – Developer Docs

## Flow
1. Server scheduler (`server/server.lua`) starts a show every `Config.ShowInterval` minutes.
2. Players buy a ticket at the seller NPC (rsg-target → playbill NUI → `rsg-theatre:server:buyTicket`). Tickets are stored in memory per citizenid and consumed when the holder is within `Config.AudienceRadius` of `Config.Stage` at curtain up.
3. Each viewer gets `rsg-theatre:client:playShow(index)`; all performers, props, rope and audience are local entities.
4. When a viewer's show ends or they walk away, the client sends `rsg-theatre:server:showFinished`. The show ends when every viewer has reported or `Config.MaxShowLength` passes.

## Events / callbacks
| Name | Side | Notes |
|---|---|---|
| `rsg-theatre:server:getPlaybill` | server callback | next show, minutes, price, hasTicket, running |
| `rsg-theatre:server:buyTicket` | server event | validates player, cooldown, distance to seller, cash |
| `rsg-theatre:server:showFinished` | server event | only affects the sender's watching state |
| `rsg-theatre:client:playShow` | client event | server → viewer |
| `rsg-theatre:client:stopShow` | client event | server → viewer when an admin forces a new show |

## Security
- Price, show and distance are all server-side; the client sends no values.
- Ticket purchases are rate limited (`Config.TicketCooldown`).
- `/theatre` uses `RSGCore.Commands.Add` with `Config.AdminPermission`.

## Doors
`server/doors.lua` inserts four rows into `rsg_doorlocks` once rsg-doorlock has seeded its table; existing names are skipped.

## Dependencies
rsg-core, ox_lib (locales only), rsg-target, oxmysql, rsg-doorlock.
