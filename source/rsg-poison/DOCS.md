# rsg-poison — Developer Docs

## Dependencies
- `rsg-core` (locales, notify, callbacks, commands, model loading) — **no ox_lib required**
- `rsg-inventory`

## ox_lib migration (v3.0.2)
| Before (ox_lib) | Now (rsg-core) |
|---|---|
| `@ox_lib/init.lua` + `lib.locale()` | `@rsg-core/shared/locale.lua`, `locale()` |
| `lib.notify` / `ox_lib:notify` | `RSGCore.Functions.Notify` / `RSGCore:Client:Notify` |
| `lib.callback.register` / `.await` | `RSGCore.Functions.CreateCallback` / `AwaitCallback` |
| `lib.requestModel` | `RSGCore.Functions.RequestModel` |
| `cache.ped` | `PlayerPedId()` |
| `lib.addCommand` (`restricted`) | `RSGCore.Commands.Add` (`TestCommandPermission`) |

## Locale
Set with `setr rsg:locale <lang>` (falls back to `ox:locale`, then `en`). Languages: en, de, el, es, fr, ja, nl, pl, pt-br, ro.

## Callbacks
- `rsg-poison:server:getPoisonState` → `cb(boolean)`; client calls it on load/restart to resume saved poison state.

## Exports (server)
- `exports['rsg-poison']:SendPoisonLog(event, { title, description, src })`

## Commands
- `/poisonwebhooktest` — sends a test embed to each configured webhook (permission: `WebhookConfig.TestCommandPermission`).

## Config change
`WebhookConfig.TestCommandAce = 'group.admin'` was replaced by `TestCommandPermission = 'admin'`. Update any custom config.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-poison 3.0.2**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `/assetpacks`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Snakes` | `table` | Snake peds that can inflict poison on bite |
| `Config.PoisonAmmo` | `table` | Ammo types that inflict poison on hit |
| `Config.PoisonWeapons` | `table` | Weapons that inflict poison on hit directly (no separate poison ammo type) |
| `Config.PoisonTickInterval` | `10000` | ms |
| `Config.PoisonHealthDrainBase` | `5` | health removed per tick |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `CurePlayer` | `` | `server/server.lua` |
| `IsPoisoned` | `src` | `server/server.lua` |
| `SendPoisonLog` | `` | `server/webhooks.lua` |

```lua
-- example
local result = exports['rsg-poison']:CurePlayer()
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-poison:server:getPoisonState` | server | `source, cb` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-poison:server:getPoisonState', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-poison:client:useAntidote` | client | `` | `client/client.lua` |
| `rsg-poison:client:cured` | client | `` | `client/client.lua` |
| `rsg-poison:client:resumePoison` | client | `` | `client/client.lua` |
| `rsg-poison:server:setPoisoned` | server | `state, cause` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-poison:server:setPoisoned', state, cause)
-- from a server script
TriggerClientEvent('rsg-poison:client:useAntidote', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/poisonwebhooktest` | locale('cmd_webhooktest_help') | `server/webhooks.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
