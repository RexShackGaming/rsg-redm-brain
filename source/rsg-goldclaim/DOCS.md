# rsg-goldclaim — Developer & Server Owner Docs

Version 3.2.0 · see [README.md](README.md) for install and player flow.

## Contents
1. [Architecture](#architecture)
2. [Data formats](#data-formats)
3. [Server events](#server-events)
4. [Callbacks](#callbacks)
5. [Client events](#client-events)
6. [Webhook API](#webhook-api)
7. [Security model](#security-model)
8. [Database schema](#database-schema)
9. [Persistence](#persistence)
10. [How-tos](#how-tos)
11. [Troubleshooting](#troubleshooting)

## Architecture
| File | Side | Purpose |
|---|---|---|
| `shared/config.lua` | shared | All gameplay settings |
| `server/sv_config.lua` | server | Webhook settings (server only, never shared) |
| `server/server.lua` | server | Rocker state, validation, processing loop, degradation timer, auto database |
| `server/webhooks.lua` | server | Batched Discord logging (`Webhook.Log`, `Webhook.Suspicious`) |
| `server/versionchecker.lua` | server | GitHub version check |
| `client/utils.lua` | client | Notify, model/anim loaders, `DoTimedAction`, busy state, blips |
| `client/nui.lua` | client | Context menu + input dialog bridge to the NUI |
| `client/placeprop.lua` | client | Ghost-prop placement with prompts |
| `client/main.lua` | client | Rocker streaming, rsg-target options, claim zones, actions |
| `html/` | NUI | Leather & gold menus and input dialog |

Dependencies: rsg-core (locale, notify, callbacks), rsg-inventory, rsg-target, oxmysql. No ox_lib.

## Data formats
**Rocker (`Config.PlayerProps[i]`, synced to clients):**
```lua
{ id = 123456, proptype = 'tool_goldrocker', x, y, z, h, hash = Config.GoldRocker,
  builder = 'CITIZENID', buildtime = os.time(), licensed = 0|1, claimname = 'string'|nil }
```
**Pending outputs (server memory only):** `PendingOutputs[propid] = { cid, gold = n, paydirt = n }`

## Server events
All take the rocker `propid` and are validated (player exists, rocker exists, player within range of the **stored** position).

| Event | Args | Checks |
|---|---|---|
| `rsg-goldclaim:rocker:server:newProp` | `coords, heading` | distance ≤ `PlaceMaxDistance`, spacing, max per character, has `tool_goldrocker`, 3s cooldown |
| `rsg-goldclaim:rocker:server:destroyProp` | `propid` | owner, quality 100, not processing, no uncollected outputs, `CanAddItem` |
| `rsg-goldclaim:rocker:server:leodestroy` | `propid` | job type `LeoJobType`, unlicensed, cooldown |
| `rsg-goldclaim:rocker:server:addpaydirt` / `addwater` | `propid` | has item, atomic capacity update, cooldown |
| `rsg-goldclaim:rocker:server:processrocker` | `propid` | owner (if `OwnerOnlyProcessing`), lock, water/paydirt/quality > 0 |
| `rsg-goldclaim:rocker:server:pickupgold` / `pickuppaydirt` | `propid` | server-produced pending output for this citizen, `PickupDistance` |
| `rsg-goldclaim:rocker:server:repairrocker` | `propid` | wood, quality < 100, conditional update with refund |
| `rsg-goldclaim:rocker:server:renameclaim` | `propid, name` | licensed owner, 3–`MaxClaimNameLength` chars, sanitised, cooldown |
| `rsg-goldclaim:rocker:server:digpaydirt` / `fillbucket` | — | has tool, cooldown matched to action time |

## Callbacks
rsg-core callbacks (`RSGCore.Functions.AwaitCallback`):
| Name | Args | Returns |
|---|---|---|
| `rsg-goldclaim:server:getprops` | — | all rockers |
| `rsg-goldclaim:server:getpending` | — | `{ {propid, gold, paydirt} }` for the caller |
| `rsg-goldclaim:server:countprops` | — | number of rockers the caller owns |
| `rsg-goldclaim:server:getrockerdata` | `propid` | DB row + `processing` flag, only if within `ClaimZoneRadius` |

## Client events
Server → client: `updatePropData(props)`, `removePropObject(propid)`, `refreshclaim(propid, name)`, `spawnoutputprop(propid, 'gold'|'paydirt', silent)`, `processingcomplete(propid)`, `goldpickupresult(amount)`, `createprop`, `useshovel`, `usebucket` (all prefixed `rsg-goldclaim:rocker:client:`).

## Webhook API
```lua
Webhook.Log('gold_pickup', src, 'Title', { { 'Field', value } }, { description = '...', ping = '<@&role>' })
Webhook.Suspicious(src, 'reason', { { 'Field', value } })
```
Console test: `goldclaim_webhooktest` (server console only).

## Security model
- The client only requests; the server validates position, ownership, job, items and cooldowns.
- Outputs can only be claimed if the server produced them for that citizen.
- Paydirt/water/repair use conditional SQL updates and refund on a lost race.
- Far-away requests (5× range) are logged to the `security` webhook.
- **Not checked server-side:** whether the player is standing in water when digging/filling (the server has no water query). The cooldown limits the rate to one per action time.

## Database schema
```sql
player_goldrockers (id PK, citizenid, owner, properties TEXT json, propid UNIQUE, proptype,
                    licensed TINYINT, claimname, paydirt, water, quality)
```
Created automatically when `Config.AutoDatabase = true`; identical to `installation/rsg-goldclaim.sql`.

## Persistence
- Rockers, contents, quality and claim names are saved in the database.
- Processing state and pending outputs live in server memory: they survive a relog but not a resource/server restart.
- Degradation runs every `Config.DegradeInterval` minutes; rockers at 0% are removed on the next run.

## How-tos
- **Change language:** `setr rsg:locale de` in server.cfg.
- **Make claims licence-free:** give players `resource_gold_claim_license` via a shop, or set `Config.LicenseItem` to an item you hand out.
- **Different LEO job:** set `Config.LeoJobType` to the job *type* (not name).
- **Remove a rocker manually:** delete its row from `player_goldrockers` and restart the resource.

## Troubleshooting
| Problem | Fix |
|---|---|
| `database setup failed` in console | Check oxmysql connection, or set `AutoDatabase = false` and import the SQL |
| No target options on rocker | Make sure `rsg-target` starts before rsg-goldclaim |
| Locale keys shown instead of text | rsg-core too old (needs `shared/locale.lua`) or bad `rsg:locale` value |
| Can't pack up | Repair to 100%, wait for processing to end, collect all outputs |
| Shovel/bucket says "not in water" | Stand in shallow river/lake water |

---
Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-goldclaim 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

### Database

Tables: `player_goldrockers`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/rsg-goldclaim.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.PlayerProps` | `{}` | populated at runtime by the server, do not edit |
| `Config.Debug` | `false` |  |
| `Config.AutoDatabase` | `true` | create the database table automatically on start (set false to import installation/rsg-goldclaim.sql manually) |
| `Config.NotifyPosition` | `'top-right'` | rsg-core notification position: 'top' \| 'top-right' \| 'top-left' \| 'bottom' \| 'bottom-right' \| 'bottom-left' \| |
| `Config.NotifyDuration` | `10000` | default notification duration (ms) |
| `Config.EnableVegModifier` | `true` | clears vegetation around placed rockers |
| `Config.GoldRocker` | ``p_goldcradlestand01x`` | prop used for gold rocker |
| `Config.MaxGoldRockers` | `4` | maximum gold rockers per character |
| `Config.DegradeChance` | `5` | % chance (per rocker) of losing 1% quality each cron cycle |
| `Config.DegradeInterval` | `30` | minutes between degradation rolls |
| `Config.RepairWoodAmount` | `5` | amount of wood needed to repair |
| `Config.LeoJobType` | `'leo'` | job type allowed to destroy unlicensed claims |
| `Config.OwnerOnlyProcessing` | `true` | only the owner can start processing (and receives the output) |
| `Config.LicenseItem` | `'resource_gold_claim_license'` | consumed on placement to make the claim licensed |
| `Config.InteractDistance` | `5.0` | max distance from a rocker to interact with it |
| `Config.PickupDistance` | `10.0` | max distance from a rocker to pick up its output |
| `Config.PlaceMaxDistance` | `6.0` | max distance between player and placed rocker |
| `Config.MinRockerSpacing` | `4.0` | min distance between two rockers |
| `Config.PropDrawDistance` | `60.0` | distance at which rocker props are streamed in |
| `Config.ProcessingTime` | `60000` | time in ms per processing cycle |
| `Config.GoldChance` | `50` | % chance of gold vs paydirt return |
| `Config.AddPaydirtTime` | `10000` | time in ms to add paydirt to rocker |
| `Config.AddWaterTime` | `10000` | time in ms to add water to rocker |
| `Config.MaxPaydirt` | `5` | max paydirt units a rocker can hold |
| `Config.MaxWater` | `5` | max water units a rocker can hold |
| `Config.RepairTime` | `10000` | time in ms to repair |
| `Config.PackUpTime` | `10000` | time in ms to pack up |
| `Config.PlaceTime` | `10000` | time in ms to set up a rocker |
| `Config.DestroyTime` | `10000` | time in ms for LEO to destroy an illegal claim |
| `Config.PickupTime` | `3000` | time in ms to pick up an output prop |
| `Config.GoldOreItem` | `'resource_gold_nugget'` |  |
| `Config.GoldOreAmount` | `{ min = 1, max = 5 }` |  |
| `Config.ShovelDigTime` | `10000` | time in ms to dig paydirt |
| `Config.BucketFillTime` | `8000` | time in ms to fill bucket |
| `Config.GoldProp` | ``p_goldstack01x`` | gold output prop |
| `Config.PaydirtProp` | ``mp005_p_dirtpile_sca02_buried`` | paydirt output prop |
| `Config.PropSpawnOffset` | `1.5` | distance to side of rocker to spawn output prop |
| `Config.ShovelProp` | `table` |  |
| `Config.DigDirtPile` | `table` | dirt pile spawned in front of the player after a successful dig (cosmetic, local only) |
| `Config.Anims` | `table` |  |
| `Config.ClaimZoneRadius` | `20.0` |  |
| `Config.MaxClaimNameLength` | `50` |  |
| `Config.ClaimBlip` | `table` |  |
| `Config.ForwardDistance` | `2.0` |  |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-goldclaim:server:getprops` | server | `_, cb` | `server/server.lua` |
| `rsg-goldclaim:server:getpending` | server | `source, cb` | `server/server.lua` |
| `rsg-goldclaim:server:countprops` | server | `source, cb` | `server/server.lua` |
| `rsg-goldclaim:server:getrockerdata` | server | `source, cb, propid` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-goldclaim:server:getprops', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-goldclaim:rocker:client:updatePropData` | client | `` | `client/main.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:removePropObject` | client | `propid` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:refreshclaim` | client | `propid, newname` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:mainmenu` | client | `propid` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:checkrocker` | client | `data` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:addpaydirt` | client | `propid` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:addwater` | client | `propid` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:startprocessing` | client | `data` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:processingcomplete` | client | `` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:spawnoutputprop` | client | `propid, resultType, silent` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:goldpickupresult` | client | `amount` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:repairrocker` | client | `data` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:renameclaim` | client | `data` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:packuprocker` | client | `data` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:destroyillegal` | client | `propid` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:useshovel` | client | `` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:usebucket` | client | `` | `client/main.lua` |
| `rsg-goldclaim:rocker:client:createprop` | client | `` | `client/placeprop.lua` |
| `rsg-goldclaim:rocker:server:digpaydirt` | server | `` | `server/server.lua` |
| `rsg-goldclaim:rocker:server:fillbucket` | server | `` | `server/server.lua` |
| `rsg-goldclaim:rocker:server:newProp` | server | `location, heading` | `server/server.lua` |
| `rsg-goldclaim:rocker:server:destroyProp` | server | `propid` | `server/server.lua` |
| `rsg-goldclaim:rocker:server:leodestroy` | server | `propid` | `server/server.lua` |
| `rsg-goldclaim:rocker:server:addpaydirt` | server | `propid` | `server/server.lua` |
| `rsg-goldclaim:rocker:server:addwater` | server | `propid` | `server/server.lua` |
| `rsg-goldclaim:rocker:server:processrocker` | server | `propid` | `server/server.lua` |
| `rsg-goldclaim:rocker:server:pickupgold` | server | `propid` | `server/server.lua` |
| `rsg-goldclaim:rocker:server:pickuppaydirt` | server | `propid` | `server/server.lua` |
| `rsg-goldclaim:rocker:server:repairrocker` | server | `propid` | `server/server.lua` |
| `rsg-goldclaim:rocker:server:renameclaim` | server | `propid, newname` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-goldclaim:rocker:server:digpaydirt')
-- from a server script
TriggerClientEvent('rsg-goldclaim:rocker:client:updatePropData', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/goldclaim_webhooktest` |  | `server/webhooks.lua` |

### Useable items

`tool_goldrocker`, `tool_rocker_shovel`, `tool_rocker_bucket_empty`

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
