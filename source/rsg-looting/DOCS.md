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
- **3.1.0** — Optional rsg-reputation integration (`Config.Reputation`): `robbery` action when a player is robbed.
- **3.0.4** — Switched from ox_target to rsg-target (`exports['rsg-target']:addGlobalPed/removeGlobalPed`).
- **3.0.3** — Removed ox_lib: `@rsg-core/shared/locale.lua`, `RSGCore.Functions.Notify` / `RSGCore:Client:Notify`, `CreateCallback`/`AwaitCallback`, `CreateClientCallback`/`AwaitClientCallback`, `RSGCore.Functions.ProgressBar`, `GetClosestPed`/`GetClosestPlayer`; `cache.ped` → `PlayerPedId()`; locale convar now `rsg:locale`.

## rsg-reputation integration

`Config.Reputation = { Enabled, Action }`. In `rsg-looting:server:robPlayer`, after the checks pass and the money is taken (next to the outlaw status), the server calls `ApplyAction(src, 'robbery')`. No region is passed, so only honor changes. Looting dead bodies is not affected. Skipped when rsg-reputation is not started.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-looting 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `rsg-lawman`, `rsg-target`, `oxmysql`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.CommonItems` | `{ 'bread', 'water' }` | items must exist in rsg-core shared items |
| `Config.RareItems` | `{ 'weapon_revolver_cattleman', 'ammo_box_revolver' }` |  |
| `Config.RareChance` | `5` | % chance of rare loot |
| `Config.CommonCash` | `{ 1, 5 }` | min / max cash with common loot |
| `Config.RareCash` | `{ 5, 10 }` | min / max cash with rare loot |
| `Config.LootMethod` | `'native'` | 'target' = rsg-target option with a progress bar |
| `Config.LootTime` | `3000` | ms searching the body (target mode only) |
| `Config.LootDistance` | `3.0` | max distance to the body (server checked) |
| `Config.LootCooldown` | `3` | seconds between loot rewards per player |
| `Config.LawAlert` | `true` | alert lawmen when a body is looted |
| `Config.RobDistance` | `2.5` | robbing players |
| `Config.RobCooldown` | `60` | seconds before the same victim can be robbed again |
| `Config.TakeCash` | `true` |  |
| `Config.TakeBloodMoney` | `true` |  |
| `Config.OutlawLoot` | `10` | outlaw status added on success (0 = disabled) |
| `Config.OutlawRob` | `50` |  |
| `Config.Reputation` | `table` | rsg-reputation integration (optional). Needs the rsg-reputation resource; does nothing when it is not started. |
| `Config.Enabled` | `true` |  |
| `Config.Action` | `'robbery'` |  |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `SendWebhook` | `` | `server/sv_webhooks.lua` |

```lua
-- example
local result = exports['rsg-looting']:SendWebhook()
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-looting:client:isHandsUp` | client | `cb` | `client/client.lua` |
| `rsg-looting:server:lootReward` | server | `src, cb, netId` | `server/server.lua` |
| `rsg-looting:server:canRob` | server | `src, cb, targetId` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-looting:client:isHandsUp', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-looting:client:RobPlayer` | client | `` | `client/client.lua` |
| `rsg-looting:server:robPlayer` | server | `targetId` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-looting:server:robPlayer', targetId)
-- from a server script
TriggerClientEvent('rsg-looting:client:RobPlayer', source)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
