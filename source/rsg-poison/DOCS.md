# rsg-poison — Developer Docs

## Dependencies
- `rsg-core` (locales, notify, callbacks, commands, model loading) — **no ox_lib required**
- `rsg-inventory`

## ox_lib migration (v3.0.2)
| Before (ox_lib) | Now (rsg-core) |
|---|---|
| `@ox_lib/init.lua` + `lib.locale()` | `@rsg-core/shared/locale.lua`, `locale()` |
| `lib.notify` / `ox_lib:notify` | `RSGCore.Functions.Notify` / `RSGCore:Client:Notify` |
| `lib.callback.register` / `.await` | `RSGCore.Functions.CreateCallback` / `AwaitCallback` |
| `lib.requestModel` | `RSGCore.Functions.RequestModel` |
| `cache.ped` | `PlayerPedId()` |
| `lib.addCommand` (`restricted`) | `RSGCore.Commands.Add` (`TestCommandPermission`) |

## Locale
Set with `setr rsg:locale <lang>` (falls back to `ox:locale`, then `en`). Languages: en, de, el, es, fr, ja, nl, pl, pt-br, ro.

## Callbacks
- `rsg-poison:server:getPoisonState` → `cb(boolean)`; client calls it on load/restart to resume saved poison state.

## Exports (server)
- `exports['rsg-poison']:SendPoisonLog(event, { title, description, src })`

## Commands
- `/poisonwebhooktest` — sends a test embed to each configured webhook (permission: `WebhookConfig.TestCommandPermission`).

## Config change
`WebhookConfig.TestCommandAce = 'group.admin'` was replaced by `TestCommandPermission = 'admin'`. Update any custom config.
