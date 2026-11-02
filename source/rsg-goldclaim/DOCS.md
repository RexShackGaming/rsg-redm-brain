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
Support: https://buymeacoffee.com/rexshack
