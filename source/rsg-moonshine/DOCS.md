# rsg-moonshine — Developer Docs

Version 3.0.2 · RSG Framework (rsg-core) · no ox_lib dependency

## Dependencies
- rsg-core (locales, notify, callbacks, progress bar, text UI)
- rsg-inventory
- rsg-target (targeting; replaces ox_target)
- oxmysql

## Framework functions used
| Purpose | Call |
|---|---|
| Locales | `@rsg-core/shared/locale.lua` in `shared_scripts`, `locale('key')`; language via `setr rsg:locale "en"` |
| Client notify | `RSGCore.Functions.Notify({ title, description, type })` |
| Server notify | `TriggerClientEvent('RSGCore:Client:Notify', src, data)` |
| Callbacks | server `RSGCore.Functions.CreateCallback(name, function(src, cb, ...) cb(x) end)` · client `RSGCore.Functions.AwaitCallback(name, nil, ...)` |
| Progress bar | `RSGCore.Functions.ProgressBar({ duration, label, canCancel, disable = { move, combat, mount }, anim })` |
| Text UI | `exports['rsg-core']:DrawText(text)` / `exports['rsg-core']:HideText()` |
| Targeting | `exports['rsg-target']:addLocalEntity / removeLocalEntity / addModel / removeModel` |

## Server callbacks
| Name | Args | Returns |
|---|---|---|
| `rsg-moonshine:server:getStills` | — | list of public still data |
| `rsg-moonshine:server:getState` | `id` | UI state, or nil if too far / throttled |
| `rsg-moonshine:server:action` | `id, action, data` | updated UI state, or nil (closed / rejected) |
| `rsg-moonshine:server:getWorldStill` | `coords` (vector3) | public data for a static map still (created on first use) |

All callbacks validate the player, distance (`Config.InteractDist`) and are rate-limited server side.

## Events
**Server (net):** `rsg-moonshine:server:placeStill (coords, heading)`, `rsg-moonshine:server:destroy (id)` — law-only destroy.
**Client:** `rsg-moonshine:client:placeStill`, `rsg-moonshine:client:syncStill (still)`, `rsg-moonshine:client:removeStill (id)`.

## Usable item
`Config.StillItem` (`moonshine_still`) starts placement.

## Database
Table `rsg_moonshine_stills` is created automatically on start; `installation/rsg-moonshine.sql` remains for manual install.

## Changelog
- **3.0.2** — Removed ox_lib: locales, notify, callbacks, progress bar and text UI moved to rsg-core; ox_target replaced with rsg-target; `cache.ped` replaced with `PlayerPedId()`. Language convar is now `rsg:locale` (falls back to `ox:locale`).
