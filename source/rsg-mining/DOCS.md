# rsg-mining – Developer Docs

## Framework usage (ox_lib free)
rsg-mining has no ox_lib dependency. Everything runs on rsg-core and rsg-target.

| Feature | API used |
|---|---|
| Locales | `@rsg-core/shared/locale.lua` + `locale(key, ...)`; language from `setr rsg:locale <lang>` (falls back to `ox:locale`, then `en`) |
| UI locale bundle | `locale()` with no key returns every string; the client sends the `ui_*` / `status_*` keys to the NUI |
| Notify (client) | `RSGCore.Functions.Notify({ title, description, type, duration, icon, position })` |
| Notify (server) | `TriggerClientEvent('RSGCore:Client:Notify', src, data)` |
| Callbacks | server `RSGCore.Functions.CreateCallback` (wrapped by `registerCallback`, so handlers keep `return` style); client `RSGCore.Functions.AwaitCallback(name, nil, ...)` |
| Model loading | `RSGCore.Functions.RequestModel(model, 10000)` |
| Proximity spawning | `points.new({...})` from `@rsg-core/client/points.lua` |
| Targeting | `exports['rsg-target']:addLocalEntity / removeLocalEntity` |
| Lease purchase confirm | the resource's own NUI confirm box (`confirm` NUI message → `confirmAnswer` NUI callback) |

## Server callbacks
All re-validate lease holder, distance and cooldown server-side.
- `rsg-mining:server:getMineData(mineId)` → `{ data }`, `{ noLease, price, hours, label }` or `{ error }`
- `rsg-mining:server:buyLease(mineId)` → bool
- `rsg-mining:server:renewLease / hire(key) / fire(workerId) / addWages(amount) / withdrawWages(amount) / deposit(key, amount) / collect(item)` → updated ledger data or false

## NUI messages
- `open { data, locales }`, `update { data }`, `close`
- `confirm { title, text, locales }` – lease purchase prompt; answered with POST `confirmAnswer { ok }`

## Locale keys added in the migration
`ui_confirm_buy`, `ui_cancel` (all 10 languages).
