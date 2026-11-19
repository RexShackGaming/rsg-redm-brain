# rsg-moonshine — Developer Docs

Version 3.0.2 · RSG Framework (rsg-core) · no ox_lib dependency

## Dependencies
- rsg-core (locales, notify, callbacks, progress bar, text UI)
- rsg-inventory
- rsg-target (targeting; replaces ox_target)
- oxmysql

## Framework functions used
| Purpose | Call |
|---|---|
| Locales | `@rsg-core/shared/locale.lua` in `shared_scripts`, `locale('key')`; language via `setr rsg:locale "en"` |
| Client notify | `RSGCore.Functions.Notify({ title, description, type })` |
| Server notify | `TriggerClientEvent('RSGCore:Client:Notify', src, data)` |
| Callbacks | server `RSGCore.Functions.CreateCallback(name, function(src, cb, ...) cb(x) end)` · client `RSGCore.Functions.AwaitCallback(name, nil, ...)` |
| Progress bar | `RSGCore.Functions.ProgressBar({ duration, label, canCancel, disable = { move, combat, mount }, anim })` |
| Text UI | `exports['rsg-core']:DrawText(text)` / `exports['rsg-core']:HideText()` |
| Targeting | `exports['rsg-target']:addLocalEntity / removeLocalEntity / addModel / removeModel` |

## Server callbacks
| Name | Args | Returns |
|---|---|---|
| `rsg-moonshine:server:getStills` | — | list of public still data |
| `rsg-moonshine:server:getState` | `id` | UI state, or nil if too far / throttled |
| `rsg-moonshine:server:action` | `id, action, data` | updated UI state, or nil (closed / rejected) |
| `rsg-moonshine:server:getWorldStill` | `coords` (vector3) | public data for a static map still (created on first use) |

All callbacks validate the player, distance (`Config.InteractDist`) and are rate-limited server side.

## Events
**Server (net):** `rsg-moonshine:server:placeStill (coords, heading)`, `rsg-moonshine:server:destroy (id)` — law-only destroy.
**Client:** `rsg-moonshine:client:placeStill`, `rsg-moonshine:client:syncStill (still)`, `rsg-moonshine:client:removeStill (id)`.

## Usable item
`Config.StillItem` (`moonshine_still`) starts placement.

## Database
Table `rsg_moonshine_stills` is created automatically on start; `installation/rsg-moonshine.sql` remains for manual install.

## Changelog
- **3.0.2** — Removed ox_lib: locales, notify, callbacks, progress bar and text UI moved to rsg-core; ox_target replaced with rsg-target; `cache.ped` replaced with `PlayerPedId()`. Language convar is now `rsg:locale` (falls back to `ox:locale`).

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-moonshine 3.0.2**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

### Database

Tables: `rsg_moonshine_stills`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/rsg-moonshine.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.StillItem` | `'moonshine_still'` | usable item that places a still |
| `Config.StillProp` | ``mp001_p_mp_still02x`` | still prop model |
| `Config.MaxStills` | `2` | max stills per character |
| `Config.MinStillDist` | `10.0` | min distance between any two stills |
| `Config.InteractDist` | `3.0` | server side max distance for actions |
| `Config.PlaceDist` | `5.0` | server side max distance between player and placed still |
| `Config.SpawnDist` | `120.0` | stills only spawn as props within this distance of the player |
| `Config.OwnerOnly` | `false` | true = only owner can brew/collect |
| `Config.MaxBatches` | `10` | hopper holds this many batches worth of each ingredient |
| `Config.EmptyJug` | `'moonshine_jug_empty'` | one empty jug is needed per bottle collected |
| `Config.OutputCap` | `50` | max bottles the still can hold before it stops brewing |
| `Config.TickInterval` | `15` | seconds between server brewing ticks |
| `Config.ImagePath` | `'nui://rsg-inventory/html/images/'` |  |
| `Config.WorldStills` | `table` | each one gets its own saved state the first time it is used (shared by everyone, can't be picked up) |
| `Config.Fuels` | `table` | fuel only burns while a batch is cooking; when it runs out the batch pauses |
| `Config.MaxFuel` | `7200` | max seconds of fuel the firebox can hold |
| `Config.BrewFx` | `table` | particle effects shown on the still while a batch is brewing (offsets are relative to the prop) |
| `Config.BlockedZones` | `table` | no stills inside these zones (towns etc.) |
| `Config.XpName` | `'moonshiner'` |  |
| `Config.XpPerBottle` | `2` | xp earned for each bottle collected (recipes can override with xpPerBottle) |
| `Config.Levels` | `{ 0, 100, 250, 500, 1000, 2000 }` | total xp needed to reach each level (index = level) |
| `Config.Recipes` | `table` |  |
| `Config.LawJobs` | `{ 'vallaw', 'rholaw', 'blklaw', 'strlaw', 'stdenlaw' }` |  |
| `Config.LawRequireDuty` | `true` |  |
| `Config.DestroyTime` | `10000` | ms |
| `Config.DestroyReward` | `15` | cash paid to lawman per still destroyed |
| `Config.Speakeasy` | `table` |  |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-moonshine:server:getStills` | server | `source, cb` | `server/server.lua` |
| `rsg-moonshine:server:getState` | server | `src, cb, id` | `server/server.lua` |
| `rsg-moonshine:server:action` | server | `src, cb, id, action, data` | `server/server.lua` |
| `rsg-moonshine:server:getWorldStill` | server | `src, cb, coords` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-moonshine:server:getStills', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |
| `rsg-moonshine:client:syncStill` | client | `s` | `client/client.lua` |
| `rsg-moonshine:client:removeStill` | client | `id` | `client/client.lua` |
| `rsg-moonshine:client:placeStill` | client | `` | `client/client.lua` |
| `rsg-moonshine:server:placeStill` | server | `coords, heading` | `server/server.lua` |
| `rsg-moonshine:server:destroy` | server | `id` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-moonshine:server:placeStill', coords, heading)
-- from a server script
TriggerClientEvent('RSGCore:Client:OnPlayerLoaded', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/moonshine_unfocus` |  | `client/client.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
