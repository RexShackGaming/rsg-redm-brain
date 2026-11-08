# rsg-railroad — Developer Docs

## Dependencies
`rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`. **No ox_lib.**

## Framework integration
| Feature | Implementation |
|---|---|
| Locales | `@rsg-core/shared/locale.lua` in `shared_scripts`; `locale('key', ...)`; convar `rsg:locale` (> `ox:locale` > `en`). NUI gets the full table via `GetLocaleTable()` |
| Server callbacks | `RegisterCallback(name, function(source, ...) return value end)` (server/db.lua) wraps `RSGCore.Functions.CreateCallback` |
| Client callbacks | `RSGCore.Functions.AwaitCallback(name, nil, ...)` (default 10s timeout, nil on timeout) |
| Notify | client `Notify(msg, type, duration)` → `RSGCore.Functions.Notify`; server `TriggerClientEvent('RSGCore:Client:Notify', src, data)` |
| Progress | `RSGCore.Functions.ProgressBar({...})` |
| Text UI | `exports['rsg-core']:DrawText(text)` / `HideText()` |
| Targeting | `exports['rsg-target']:addLocalEntity / removeLocalEntity` |

## Client helpers (client/utils.lua)
- `ApplyNuiFocus(enable)` — the only place NUI focus is set. Applies `SetNuiFocusKeepInput` and a per-frame control whitelist so push-to-talk works while the UI is open.
- `ShowInfoMenu(title, options)` — read-only NUI list; `options = { { title, description }, ... }`. Used for the train condition report and train locations.
- `ConfirmDialog({ header, content, labels = { confirm, cancel } })` — blocking NUI confirm, returns `true`/`false`. Used by `ConfirmStoragePutAway()`.

## NUI messages
`openStation`, `closeStation`, `openTrainHUD`, `closeTrainHUD`, `updateHUD`, `openInfoMenu`, `openDialog`.
NUI callbacks added: `closeInfoMenu`, `dialogResult { confirmed }`.

## Config
```lua
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = { 0x4BC9DABB } -- INPUT_PUSH_TO_TALK
```
