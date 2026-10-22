# Notifications and locales

## Notifications: ox_lib only
Client:
```lua
lib.notify({ title = locale('title'), description = locale('msg'), type = 'success', duration = 5000 })
```
Server:
```lua
TriggerClientEvent('ox_lib:notify', src, { title = locale('title'), description = locale('msg'), type = 'error', duration = 5000 })
```
Types: `success`, `error`, `inform`, `warning`. Keep durations between 3000 and 7000 ms.

Replace these when converting: `RSGCore.Functions.Notify`, `RSGCore:Notify` events, `exports['rsg-core']:Notify`, native feed posts (`BeginTextCommandThefeedPost`), and custom notify events.
Type mapping: green → success, red → error, primary/info/blue → inform, yellow → warning.

## Locales: ox_lib JSON (matches rsg-core)
fxmanifest:
```lua
shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
files { 'locales/*.json' }
```
Code (client and server):
```lua
lib.locale()
-- then
locale('bought_success', amount, label, total)
```
`locales/en.json`:
```json
{ "bought_success": "You bought %sx %s for $%s" }
```
Rules: every player-facing string (notify, progress bar, prompt text, target label, menu, NUI) goes in a locale. Debug output doesn't. Keys are snake_case and consistent across the whole resource.

> Note: an older version of the audit skill used `locales/*.lua` with `return {}`. Use JSON, which is what rsg-core uses.
