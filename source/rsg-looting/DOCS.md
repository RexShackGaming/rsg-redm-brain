# rsg-looting — Developer Docs

## Overview
NPC body looting and player robbery for RSG Framework. All rewards are decided server side. No ox_lib dependency — locales, notify, callbacks, progress bars and closest-entity helpers come from **rsg-core**.

## Dependencies
rsg-core, rsg-inventory, rsg-lawman, rsg-target (only used when `Config.LootMethod = 'target'`), oxmysql, OneSync.

## Locales
Loaded through `@rsg-core/shared/locale.lua` from `locales/*.json`. Language is set with `setr rsg:locale <code>` (falls back to `ox:locale`, then `en`). Languages: en, de, el, es, fr, ja, nl, pl, pt-br, ro.

## Flow
### NPC loot
1. Client detects a dead, networked, human, unlooted NPC (`native` prompt via `GetClosestPed` + `_IS_ENTITY_FULLY_LOOTED`, or `target` via rsg-target + `RSGCore.Functions.ProgressBar`).
2. Client: `RSGCore.Functions.AwaitCallback('rsg-looting:server:lootReward', nil, netId)`.
3. Server validates (netId, cooldown, already looted, entity type/dead/distance), gives item + cash, adds outlaw status, logs to webhook, returns `true`/`false`.
4. On success the client may fire `rsg-lawman:server:lawmanAlert`.

### Player robbery
1. Client event `rsg-looting:client:RobPlayer` finds the closest player within `Config.RobDistance`.
2. Client: `AwaitCallback('rsg-looting:server:canRob', nil, targetId)` — server checks distance, cooldown, and victim state (dead / handcuffed / hands up). Hands up is asked on the **victim's** client via `AwaitClientCallback('rsg-looting:client:isHandsUp', targetId, 3000)`.
3. Progress bar (5–7 s), then `TriggerServerEvent('rsg-looting:server:robPlayer', targetId)`; server only accepts it if approved and at least 4.5 s have passed.

## Events & callbacks
| Name | Side | Type |
|---|---|---|
| `rsg-looting:client:RobPlayer` | client | event (start a robbery) |
| `rsg-looting:client:isHandsUp` | client | rsg-core client callback |
| `rsg-looting:server:lootReward` | server | rsg-core callback |
| `rsg-looting:server:canRob` | server | rsg-core callback |
| `rsg-looting:server:robPlayer` | server | net event (validated) |

## Exports
`exports['rsg-looting']:SendWebhook(channel, embed)` — channel `loot`, `rob` or `exploit`.

## Changelog
- **3.0.4** — Switched from ox_target to rsg-target (`exports['rsg-target']:addGlobalPed/removeGlobalPed`).
- **3.0.3** — Removed ox_lib: `@rsg-core/shared/locale.lua`, `RSGCore.Functions.Notify` / `RSGCore:Client:Notify`, `CreateCallback`/`AwaitCallback`, `CreateClientCallback`/`AwaitClientCallback`, `RSGCore.Functions.ProgressBar`, `GetClosestPed`/`GetClosestPlayer`; `cache.ped` → `PlayerPedId()`; locale convar now `rsg:locale`.
