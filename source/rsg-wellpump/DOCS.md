# rsg-wellpump: developer docs

## Contents
1. Files
2. How it works
3. Configuration
4. Server exports
5. Client exports
6. Events and callbacks
7. Integration examples
8. Database and migration
9. Security model
10. Server owner how-tos
11. Troubleshooting

Dependencies: `rsg-core`, `rsg-inventory`, `rsg-target`, `rsg-gizmo`, `oxmysql`. No ox_lib and no ox_target.

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest |
| `shared/config.lua` | All options |
| `server/server.lua` | Pumps, database and migration, placement, fill and pack, bucket API, exports |
| `client/client.lua` | Pump props and targets, rsg-gizmo placement, fill animation, `PlayFill` export |
| `install.sql` | Manual database install (only when `AutoDatabase = false`) |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 2. How it works
- A player uses `Config.Item` (or an item in `Config.ExtraItems`). The server checks the per-player limit and tells the client to start rsg-gizmo. After placing, the client plays a short animation and asks the server to save the pump. The server re-validates the spot (`IsPlacementValid`, spacing, limit), takes one pump item and inserts the row.
- Pumps are broadcast to every client. Props spawn client-side within `Config.RenderDistance` and carry rsg-target options (Fill Bucket, Pack Up). Clients never receive citizenids: each player gets the shared list plus the ids of the pumps they own.
- **Fill / pack**: the client asks the server for a pre-check (which starts an action timer), plays the animation, then calls the action. The server only accepts it after about 80% of the duration has passed.
- **Drinking**: the client checks thirst, asks for a pre-check, plays the drink scenario (male: `WORLD_HUMAN_BUCKET_DRINK_GROUND`, female: `WORLD_HUMAN_CROUCH_INSPECT`, the same ones rsg-essentials uses at rivers) and calls the server. The server enforces `Config.Drink.cooldown`, picks a random amount from `Config.Drink.thirst` and sends it to the client, which raises thirst with `hud:client:UpdateThirst` like the rest of the server.
- **The bucket**: a filled bucket is `Config.FullItem` with item info `{ uses, description }`. `FillBucket` gives full uses. Using water takes one use; on the last use an empty bucket (`Config.EmptyItem`) is given back.

## 3. Configuration
See the table in README.md. Item names must exist in your rsg-core items; the server warns on start for missing ones.

## 4. Server exports
All are `exports['rsg-wellpump']:Name(...)`.

| Export | Returns | Notes |
|---|---|---|
| `FillBucket(src)` | `ok, message` | Removes one `Config.EmptyItem`, adds one `Config.FullItem` with `Config.BucketUses` uses. Refunds the empty bucket if the full one cannot be added. **Does not check access or distance: do that in your own script first.** |
| `UseBucket(src)` | `ok, usesLeft` or `false, message` | Takes one use from the player's full bucket. The bucket goes back with one use less, or an empty bucket when it was the last use |
| `TakeBucketUse(src)` | `ok, ticket` or `false, message` | Step 1 of a two-step use: removes the full bucket and returns a ticket (a plain table) |
| `CommitBucketUse(src, ticket)` | `ok, usesLeft` | Step 2a: your work succeeded; gives back the bucket with one use less (or an empty bucket) |
| `RefundBucketUse(src, ticket)` | `ok` | Step 2b: your work failed; gives the bucket back exactly as it was |
| `Drink(src)` | `ok, message, amount` | Enforces the drink cooldown, picks the thirst amount and tells the player's client to apply it. **Does not check access or distance: do that in your own script first** |
| `GetBucketUses(itemInfo)` | number | Uses left from a bucket's `info` (full uses when it has none) |
| `GetMaxUses()` | number | `Config.BucketUses` |
| `GetFillTime()` | number | `Config.FillTime` in ms (for rate limits in your own script) |
| `GetPumps()` | list | Every placed pump as `{ id, x, y, z, h }` (no owner) |
| `IsNearPump(src, distance?)` | bool | Whether the player is within `distance` (default `Config.InteractDist + 2`) of any pump |

## 5. Client exports
| Export | Returns | Notes |
|---|---|---|
| `PlayDrink()` | bool | Checks the player is thirsty enough, plays the drink scenario with a progress bar and cleans up props. Returns `true` when finished; then ask your own server event to call `Drink(src)` |
| `PlayFill()` | bool | Checks the player carries an empty bucket, plays the fill scenario with a progress bar and cleans up the scenario prop. Returns `true` when finished. Call it from a thread; then ask your own server event to fill |

## 6. Events and callbacks
| Name | Kind | Notes |
|---|---|---|
| `rsg-wellpump:server:getPumps` | callback | Returns the pump list and the ids the caller owns |
| `rsg-wellpump:server:placePump` | callback | `(coords, heading)`; validated, takes the item, saves the pump |
| `rsg-wellpump:server:precheck` | callback | `(action, pumpId)`; starts the action timer |
| `rsg-wellpump:server:fill` | callback | `(pumpId)` |
| `rsg-wellpump:server:drink` | callback | `(pumpId)` |
| `rsg-wellpump:server:pack` | callback | `(pumpId)` |
| `rsg-wellpump:client:sync` | client event | `(pumps, ownedIds)` |
| `rsg-wellpump:client:place` | client event | Start the placement gizmo |
| `rsg-wellpump:client:thirst` | client event | `(amount)` raise thirst by `amount` (sent by the server) |

Callbacks are for rsg-wellpump's own client; other resources should use the exports.

## 7. Integration examples
**Using water (farming, ranch, anything that consumes a bucket use):**
```lua
local ok, usesLeft = exports['rsg-wellpump']:UseBucket(src)
if not ok then return false, locale('no_water') end
```

**Using water when your own step can fail (rsg-ranch's trough refill):**
```lua
local took, ticket = exports['rsg-wellpump']:TakeBucketUse(src)
if not took then return end
local ok = doMyWork()
if ok then
    exports['rsg-wellpump']:CommitBucketUse(src, ticket)
else
    exports['rsg-wellpump']:RefundBucketUse(src, ticket)
end
```

**Your own pump prop (rsg-gangs):** spawn your prop, add your own rsg-target option, check access and distance on the server, then call the exports:
```lua
-- client
onSelect = function()
    CreateThread(function()
        if exports['rsg-wellpump']:PlayFill() then TriggerServerEvent('my-script:server:fill') end
    end)
end

-- server
RegisterNetEvent('my-script:server:fill', function()
    local src = source
    -- your own checks: membership, distance, rate limit (exports['rsg-wellpump']:GetFillTime())
    local ok, msg = exports['rsg-wellpump']:FillBucket(src)
    TriggerClientEvent('RSGCore:Client:Notify', src, { description = msg, type = ok and 'success' or 'error' })
end)
```

## 8. Database and migration
Created automatically on start while `Config.AutoDatabase = true`; `install.sql` holds the same schema.
- `rsg_wellpumps`: `id`, `citizenid`, `x`, `y`, `z`, `h`, `placed_at`.
- `rsg_wellpump_migrations`: `source`, `migrated_at`. One row per old pump table that has been imported.

On start, for each entry in `Config.Migration.Sources` whose table exists and is not yet in `rsg_wellpump_migrations`, all its rows are copied into `rsg_wellpumps` and the source is recorded, so a pump packed up later is never re-imported. The old tables are never changed or dropped; drop them yourself once you are happy. Set `Config.Migration.Enabled = false` to skip it.

## 9. Security model
- The client result from rsg-gizmo is untrusted: the server runs `IsPlacementValid`, spacing, per-player limit checks and reserves the spot while the database insert is pending.
- Fill and pack need a server-issued action timer, the player next to the pump, the right items and inventory space. Packing is owner-only by default.
- Items are only removed after validation; if a refund or reward no longer fits it is dropped at the player's feet, never lost.
- Clients never receive citizenids.
- `FillBucket` and the bucket exports are server-side and trust the calling resource: check access, distance and rate limits before calling.

## 10. Server owner how-tos
- **Change bucket size:** `Config.BucketUses`. Existing buckets keep their own count.
- **Use different bucket items:** change `Config.EmptyItem` and `Config.FullItem`, and keep farming's and ranch's `Config.WaterItem` equal to `Config.FullItem`.
- **Change how much a drink gives:** `Config.Drink.thirst`; the cooldown is `Config.Drink.cooldown`. Set `Config.Drink.enabled = false` to remove the option.
- **Remove a pump:** the owner packs it up at the pump; for staff, delete the row in `rsg_wellpumps` and restart the resource.

## 11. Troubleshooting
| Problem | Fix |
|---|---|
| Console warns about a missing item | Add the item to `rsg-core/shared/items.lua` |
| "No water" when watering or refilling | rsg-wellpump must be started before the script that uses it; `Config.WaterItem` there must equal `Config.FullItem` here |
| Bucket always has the same uses | `fullbucket` must be `unique = true` so its uses are kept per bucket |
| Pump won't place | Check `MaxPerPlayer` and `MinDistance`; `rsg-gizmo` must be started |
| No Fill / Pack option | `rsg-target` must start before rsg-wellpump; you must be within `InteractDist`; Pack is owner-only while `OwnerOnlyPackup = true` |
| Drink option does nothing | You are above `Config.Drink.notThirstyAbove`, or still in the cooldown; your HUD must handle `hud:client:UpdateThirst` |
| Old pumps are missing | Check the console for the import line on first start; the old tables must exist and `Config.Migration.Enabled` must be `true` |

Support: https://rexshack.tebex.store
