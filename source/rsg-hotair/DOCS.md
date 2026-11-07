# rsg-hotair — Technical Docs

## Dependencies
`rsg-core` (locales, notify, callbacks), `rsg-target`, `rsg-inventory`. No ox_lib.

## Locales
`@rsg-core/shared/locale.lua` is loaded in `shared_scripts`; strings live in `locales/*.json` (en, de, el, es, fr, ja, nl, pl, pt-br, ro) and are read with `locale('key')`. The language is set with `setr rsg:locale <code>`. The NUI receives its strings from Lua when it opens.

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
