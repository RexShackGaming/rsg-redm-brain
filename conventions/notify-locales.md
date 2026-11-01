# Notifications and locales

## Notifications: rsg-core only (never ox_lib)
Client:
```lua
RSGCore.Functions.Notify({ title = locale('title'), description = locale('msg'), type = 'success', duration = 5000 })
```
Server:
```lua
TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('title'), description = locale('msg'), type = 'error', duration = 5000 })
```
Types: `success`, `error`, `inform`, `warning`. Optional: `icon` (Font Awesome class), `position`, `id` (replaces a toast with the same id). Keep durations between 3000 and 7000 ms.

Replace these when converting: `lib.notify`, `ox_lib:notify`, legacy `RSGCore:Notify` events, native feed posts (`BeginTextCommandThefeedPost`), and custom notify events.
Type mapping: green → success, red → error, primary/info/blue → inform, yellow → warning.

## Locales: rsg-core shared loader (no ox_lib)
fxmanifest:
```lua
shared_scripts { '@rsg-core/shared/locale.lua', 'shared/config.lua' } -- loader first
files { 'locales/*.json' }
dependencies { 'rsg-core' }
```
Code (client and server) — no `lib.locale()` call needed:
```lua
locale('bought_success', amount, label, total)
locale('webhooks.common.na') -- nested JSON tables are flattened to dot keys
```
Language: `setr rsg:locale "en"` in server.cfg (falls back to `ox:locale`, then `en`). Use `setr` so clients get it too.
Missing keys fall back to `en.json`, then the key itself. `"${other.key}"` inside a string is replaced with that key's text (same as ox_lib).
Converting from ox_lib: replace `'@ox_lib/init.lua'` with `'@rsg-core/shared/locale.lua'`, delete `ox_libs { 'locale' }` and `lib.locale()` calls, and drop `ox_lib` from dependencies if nothing else uses it. A leftover `lib.locale()` is harmless when ox_lib isn't loaded.
`locales/en.json`:
```json
{ "bought_success": "You bought %sx %s for $%s" }
```
Rules: every player-facing string (notify, progress bar, prompt text, target label, menu, NUI) goes in a locale. Debug output doesn't. Keys are snake_case and consistent across the whole resource.

> Note: an older version of the audit skill used `locales/*.lua` with `return {}`. Use JSON, which is what rsg-core uses.
