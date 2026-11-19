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
rsg-core, rsg-target, oxmysql, rsg-doorlock.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-theatre 3.0.2**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-target`, `oxmysql`, `rsg-doorlock`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Debug` | `false` |  |
| `Config.TicketSeller` | `table` | Ticket seller (placed at the ticket fence volume from theatre_ticket_taker.c) |
| `Config.TicketPrice` | `1.50` | cash per ticket (server side) |
| `Config.TicketCooldown` | `3` | seconds between purchases per player |
| `Config.ShowInterval` | `15` | minutes between shows |
| `Config.FirstShowDelay` | `2` | minutes after resource start |
| `Config.ShowOrder` | `'rotation'` | 'rotation' or 'random' |
| `Config.MaxShowLength` | `420` | seconds, safety cap on a single show |
| `Config.Stage` | `vector3(2546.41, -1303.55, 46.9)` | Players must be within this radius of the stage when the show starts |
| `Config.AudienceRadius` | `30.0` |  |
| `Config.Backstage` | `vector3(2553.875, -1313.143, 48.2166)` | (Local_8.f_42 in show_nbx_bigband_02.c / show_nbx_cancan.c) |
| `Config.Audience` | `table` | seated with the PROP_HUMAN_SEAT_CHAIR scenario; spots 53-55 are standing spots and left out) |
| `Config.AdminCommand` | `'theatre'` | Admin command to force a show: /theatre <showId> |
| `Config.AdminPermission` | `'admin'` |  |
| `Config.Curtain` | `table` | Curtain (generic_show_mc.c / show_nbx_cancan.c func_161/func_163) |
| `Config.CurtainRange` | `60.0` | curtain is spawned (closed) while you're this close to the stage |
| `Config.CurtainOpenDelay` | `3000` | ms after the curtain starts opening before the act begins |
| `Config.CurtainCloseDelay` | `4000` | ms to let the curtain close before the 'show over' message |
| `Config.Shows` | `table` | rope = optional rope tying a prop to a frozen anchor { prop, anchorModel, anchorCoords, coords, length, ropeTy |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-theatre:server:getPlaybill` | server | `src, cb` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-theatre:server:getPlaybill', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-theatre:client:playShow` | client | `index` | `client/client.lua` |
| `rsg-theatre:client:stopShow` | client | `` | `client/client.lua` |
| `rsg-theatre:server:showFinished` | server | `` | `server/server.lua` |
| `rsg-theatre:server:buyTicket` | server | `` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-theatre:server:showFinished')
-- from a server script
TriggerClientEvent('rsg-theatre:client:playShow', source, index)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
