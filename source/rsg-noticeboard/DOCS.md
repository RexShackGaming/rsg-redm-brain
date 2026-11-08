# rsg-noticeboard – Developer Docs

## Dependencies
- `rsg-core` (locales, notify, callbacks, model loading)
- `rsg-target` (board interaction)
- `oxmysql`

ox_lib is **not** used (migrated in v3.1.0).

## Structure
| File | Purpose |
|---|---|
| `shared/config.lua` | Main config (boards, durations, categories, towns) |
| `client/client.lua` | Board spawning, blips, target, NUI bridge, expiry renew prompt |
| `client/placer.lua` | Admin ghost placer for new boards |
| `server/server.lua` | Notices, fees, expiry, admin actions, callbacks |
| `server/sv_config.lua` / `webhooks.lua` | Server-only config and Discord logs |
| `html/` | NUI (board, admin panel, modals) |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## Callbacks (server, `RSGCore.Functions.CreateCallback`)
Registered through a local `registerCallback(name, fn)` wrapper that calls `cb(fn(source, ...))`, so handlers simply `return` their value. Client side uses `RSGCore.Functions.AwaitCallback(name, 10000, ...)`.

`getBoards`, `getBoardData`, `createNotice`, `renewNotice`, `deleteOwnNotice`, `getAdminData`, `saveBoard`, `renameBoard`, `deleteBoard`, `adminDeleteNotice`, `adminExtendNotice` (all prefixed `rsg-noticeboard:server:`). Admin callbacks check `Config.AdminPermission` server-side.

## Events
- `rsg-noticeboard:client:syncBoards` – placed board list
- `rsg-noticeboard:client:openAdmin` – open admin panel
- `rsg-noticeboard:client:expiryWarning` – notice about to expire; shows a notify and opens the NUI `expiryRenew` prompt (confirm → duration picker → `renewNotice`)
- Server notifications use `RSGCore:Client:Notify`

## NUI actions
`openBoard`, `openAdmin`, `expiryRenew`. NUI callbacks: `close`, `refresh`, `refreshAdmin`, `createNotice`, `renewNotice`, `deleteOwnNotice`, `adminDeleteNotice`, `adminExtendNotice`, `adminDeleteBoard`, `adminRenameBoard`, `adminTeleport`, `adminPlaceBoard`.

## Language
`setr rsg:locale "de"` (falls back to `ox:locale`, then `en`). `ui_*` keys are sent to the NUI.

## Changelog
- **3.1.0** – Removed ox_lib: rsg-core locales/notify/callbacks/RequestModel, `cache.ped` → `PlayerPedId()`, ox_target → rsg-target, renew alert/context menu moved into the NUI.
