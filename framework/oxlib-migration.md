# ox_lib → rsg-core migration tracker

ox_lib is being phased out. Use the rsg-core replacement wherever one is marked **done**.

| ox_lib | rsg-core replacement | Status |
|---|---|---|
| `lib.callback.register` (server) | `RSGCore.Functions.CreateCallback(name, function(source, cb, ...) cb(x) end)` | done |
| `lib.callback(name, false, cb, ...)` (client) | `RSGCore.Functions.TriggerCallback(name, cb, ...)` | done |
| `lib.callback.await(name, false, ...)` (client) | `RSGCore.Functions.AwaitCallback(name, timeout?, ...)` | done |
| `lib.callback.register` (client) | `RSGCore.Functions.CreateClientCallback(name, function(cb, ...) end)` | done |
| `lib.callback.await(name, src, ...)` (server) | `RSGCore.Functions.AwaitClientCallback(name, src, timeout?, ...)` | done |

Details and examples: `framework/rsg-core.md` → Callbacks.

| `lib.notify(data)` (client) | `RSGCore.Functions.Notify(data)` / `exports['rsg-core']:Notify(data)` (same table: title, description, type, duration, icon, position, id) | done |
| `TriggerClientEvent('ox_lib:notify', src, data)` (server) | `TriggerClientEvent('RSGCore:Client:Notify', src, data)` or `RSGCore.Functions.Notify(src, data)` | done |
| `ox_lib 'locale'` / `locale()` inside rsg-core | rsg-core's own `shared/locale.lua` (convar `rsg:locale`, falls back to `ox:locale`, then `en`) | done — shared: other resources use `shared_scripts { '@rsg-core/shared/locale.lua' }` (flattens nested keys, `${key}` refs, no `lib.locale()` needed) |
| `cache.ped/playerId/mount/vehicle` inside rsg-core | rsg-core `client/lib.lua` cache | done (rsg-core internal) |
| `lib.requestModel/AnimDict/AnimSet/NamedPtfxAsset` | `RSGCore.Functions.RequestModel/RequestAnimDict/RequestAnimSet/RequestNamedPtfxAsset(name, timeout?)` (+ exports) | done |
| `lib.playAnim(ped, ...)` | `RSGCore.Functions.PlayAnimOnPed(ped, dict, name, blendIn, blendOut, duration, flag, rate, lockX, lockY, lockZ)` | done |
| `lib.showTextUI` / `lib.hideTextUI` | `exports['rsg-core']:DrawText(text, pos)` / `HideText()` (rsg-core NUI) | done |
| `require 'module'` (ox_lib module loader for resource files) | `shared_scripts { '@rsg-core/shared/require.lua' }` — same syntax: `require 'data.items'` (→ `data/items.lua` or `data/items/init.lua`), `require '@other-resource.path'`; cached per resource. Client-side modules must be listed in `files` | done |
| `lib.math.clamp` | `math.max(min, math.min(max, v))` | done |

rsg-core no longer depends on ox_lib. Other resources load their locales with `@rsg-core/shared/locale.lua` and modules with `@rsg-core/shared/require.lua` instead of `@ox_lib/init.lua` (see `conventions/notify-locales.md`).
