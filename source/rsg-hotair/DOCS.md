# rsg-hotair — Technical Docs

## Dependencies
`rsg-core` (locales, notify, callbacks), `rsg-target`, `rsg-inventory`. No ox_lib.

## Locales
`@rsg-core/shared/locale.lua` is loaded in `shared_scripts`; strings live in `locales/*.json` (en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru) and are read with `locale('key')`. The language is set with `setr rsg:locale <code>`. The NUI receives its strings from Lua when it opens.

## Config (`shared/config.lua`)
| Key | Purpose |
|---|---|
| `Config.Model` | Balloon model |
| `Config.HirePrice` | Hire fee (cash) |
| `Config.PassengerOffsets` | Basket seat offsets (4) |
| `Config.CruiseSpeed` / `BoostSpeed` | Drift per tick |
| `Config.MaxAltitudeAGL` | Ceiling above ground |
| `Config.StoreMax*` / `BoardMax*` | Speed/height limits to store or board |
| `Config.TargetDistance` | rsg-target interaction distance |
| `Config.StorageMaxWeight` / `StorageMaxSlots` | Per-balloon stash |
| `Config.Docks` | Hire docks (NPC, blip, spawn) |

## Server callbacks (RSGCore)
- `rsg-hotair:server:hireBalloon` (dock) → success, reason
- `rsg-hotair:server:requestSeat` (netId) → granted, seat, reason
- `rsg-hotair:server:openStorage` → success, reason

## Server events
`rsg-hotair:server:registerBalloon`, `cancelHire`, `storedBalloon`, `vacateSeat`, `disembarkAll`

## Client events
`rsg-hotair:client:forceDisembark`, `rsg-hotair:client:seatUpdate`

## NUI callbacks
`hireBalloon`, `storeBalloon`, `closeUI`

## Commands
`/hotair`

## Changelog
- **2.1.0** — Removed ox_lib: locales now come from rsg-core, `lib.notify` is replaced by `RSGCore.Functions.Notify`, ox_target is replaced by rsg-target.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-hotair 3.0.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-target`, `rsg-inventory`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Model` | `'hotAirBalloon01'` | Balloon vehicle model |
| `Config.HirePrice` | `50` | Flat hire fee (cash). No timers, no cooldowns, no fuel. |
| `Config.PassengerOffsets` | `table` | pilot uses the driver seat (-1), passengers attach at these offsets |
| `Config.CruiseSpeed` | `0.05` | drift added per tick |
| `Config.BoostSpeed` | `0.15` | drift added per tick while boost held |
| `Config.MaxAltitudeAGL` | `150.0` | ceiling above ground level |
| `Config.StoreMaxSpeed` | `3.0` | m/s, balloon must be near-stationary to store |
| `Config.StoreMaxHeightAGL` | `4.0` | must be close to the ground to store |
| `Config.BoardMaxSpeed` | `3.0` | same limits for boarding / piloting |
| `Config.BoardMaxHeightAGL` | `4.0` |  |
| `Config.TargetDistance` | `6.0` | rsg-target distance (balloon is a large entity) |
| `Config.StorageMaxWeight` | `100000` | Balloon storage (rsg-inventory stash per owner citizenid) |
| `Config.StorageMaxSlots` | `20` |  |
| `Config.Docks` | `table` | created per entry automatically. Ground Z is resolved at runtime. |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-hotair:server:hireBalloon` | server | `source, cb, dock` | `server/server.lua` |
| `rsg-hotair:server:requestSeat` | server | `source, cb, netId` | `server/server.lua` |
| `rsg-hotair:server:openStorage` | server | `source, cb` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-hotair:server:hireBalloon', function(result)
    -- use result
end, dock)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-hotair:client:forceDisembark` | client | `` | `client/client.lua` |
| `rsg-hotair:client:seatUpdate` | client | `count` | `client/client.lua` |
| `rsg-hotair:server:registerBalloon` | server | `netId` | `server/server.lua` |
| `rsg-hotair:server:cancelHire` | server | `` | `server/server.lua` |
| `rsg-hotair:server:storedBalloon` | server | `` | `server/server.lua` |
| `rsg-hotair:server:vacateSeat` | server | `netId, seat` | `server/server.lua` |
| `rsg-hotair:server:disembarkAll` | server | `netId` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-hotair:server:registerBalloon', netId)
-- from a server script
TriggerClientEvent('rsg-hotair:client:forceDisembark', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/hotair` |  | `client/client.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
