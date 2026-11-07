# rsg-mdt — Developer Docs

## Dependencies
- **rsg-core** — callbacks, notify, locales (`@rsg-core/shared/locale.lua`)
- **rsg-target** — fines payment NPC interaction
- **oxmysql** — database
- No ox_lib. The fines payment NPC menu and confirm dialogs are NUI (`web/components/FinesClerk.tsx`).

## ox_lib migration (v2.1.0)
| Was (ox_lib) | Now |
|---|---|
| `@ox_lib/init.lua` + `shared/locale.lua` (`lib.loadJson`) | `@rsg-core/shared/locale.lua`, `setr rsg:locale <lang>` |
| `lib.notify` | `RSGCore.Functions.Notify` |
| `lib.callback.register` (server) | `RegisterCallback(name, fn)` → `RSGCore.Functions.CreateCallback` (see `shared/callbacks.lua`) |
| `lib.callback.register` (client) | `RegisterClientCallback(name, fn)` → `RSGCore.Functions.CreateClientCallback` |
| `lib.callback.await` | `RSGCore.Functions.AwaitCallback(name, nil, ...)` |
| `lib.callback(name, false, cb, ...)` | `RSGCore.Functions.TriggerCallback(name, cb, ...)` |
| `lib.addKeybind` | raw-key thread using `Config.Settings.keybind` (virtual-key code, default `0x76` = F7) |
| `exports.ox_target` | `exports['rsg-target']` |

`shared/callbacks.lua` lets handlers keep `return value` style; the bridge forwards returns to `cb()`.
| `lib.registerContext/showContext/alertDialog` | NUI fines clerk (v2.2.0) |

`shared/locale.lua` is no longer loaded and can be deleted.

## Callbacks
Server callbacks are registered in `server/*.lua` under the `rsg-mdt:server:*` namespace; client callback `rsg-mdt:roleSync:getLocalState` in `client/roleSync.lua`.

## Config
- `Config.Settings.command` — chat command (default `mdt`)
- `Config.Settings.keybind` — virtual-key code or `nil` to disable

## Fines clerk NUI
Client → NUI messages: `openFinesClerk`, `updateFinesClerk`, `closeFinesClerk` with `{ title, fines = [{ id, amount, timeLeft, overdue }], total, labels }` (labels are sent from Lua locales).
NUI → client callbacks: `finesClerkPay { fineId }`, `finesClerkPayAll`, `finesClerkClose`. Payment is validated server-side in `rsg-mdt:server:payFine` (ownership, status, cash).

## Push-to-talk
`Config.AllowPushToTalkWhileOpen` / `Config.PushToTalkControls`. Both MDT (`client/nui.lua` `NUI.SetFocus`) and the fines clerk route focus through a helper that uses `SetNuiFocusKeepInput` and a per-frame control whitelist.

## Building the UI
`cd web && npm install && npm run build` → outputs `web/dist`.

## Locales
`locales/*.json` — en, de, el, es, fr, ja, nl, pl, pt-br, ro (required set) plus pt, it, ru, tr. All files share the same 147 keys.
Plural suffix arguments (`%s` after day/hour/second) are English-only; non-English files consume them with `%.0s` so argument order stays intact.
