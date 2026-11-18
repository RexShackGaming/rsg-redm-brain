# rsg-factory — Documentation

## Contents
1. [Architecture](#architecture)
2. [Data formats](#data-formats)
3. [Callbacks and events](#callbacks-and-events)
4. [Exports](#exports)
5. [Persistence](#persistence)
6. [Security model](#security-model)
7. [Database schema](#database-schema)
8. [Server owner how-tos](#server-owner-how-tos)
9. [Troubleshooting](#troubleshooting)

## Architecture
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Resource manifest; depends on `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql` |
| `shared/config.lua` | All settings (see README) |
| `server/server.lua` | Database build, factory cache, `/createfactory`, all callbacks and validation |
| `client/client.lua` | NPC spawning, `rsg-target` options, NUI bridge, push-to-talk whitelist |
| `html/index.html`, `style.css`, `script.js` | NUI (house "leather & gold" style, custom HTML dropdowns) |
| `locales/*.json` | 10 languages, loaded by rsg-core (`@rsg-core/shared/locale.lua`) |
| `install.sql` | Manual schema (identical to the auto-build) |
| `example_factory.lua` | Reference example (chained cigarette factory); not loaded |

Client: NPCs are only respawned when a factory's position, heading or model changed, so an admin saving one factory doesn't make every NPC blink.

Flow: admin runs `/createfactory` → server inserts the row using the admin's server-side position → all clients get the new list → editor opens. Players use the NPC → server returns the factory, its lines and the player's queue → NUI sends `start` / `collect` → the server validates and applies.

## Data formats

NUI window: the panel is `min(880px, 94vw)` wide (`.wide` for the admin editor, `min(1040px, 96vw)`) and as tall as its content up to 88vh. The header is a drag handle (pointer events, position kept in `--dx/--dy` and clamped so the header stays on screen); double-click it to recentre. The position is kept between openings until the UI is reloaded.

Item pictures: the server sends each item with an `image` file name (rsg-core's `image`, else `<item>.png`); the NUI loads it from `Config.ImagePath`. Missing images fall back to the item's first letter.

Production line (a factory holds up to `Config.MaxRecipes`):
```lua
{
    label   = 'Planks',                                   -- 1-48 chars
    time    = 30,                                         -- seconds per batch
    job     = nil,                                        -- optional job name
    next    = nil,                                        -- optional index of the line to run after this one (chain)
    inputs  = { { item = 'resource_wood', amount = 4 } }, -- distinct items, up to MaxItemsPerRecipe
    outputs = { { item = 'plank', amount = 2 } },
    fuel    = 1,                                          -- fuel units burned per batch (0..MaxUtilityPerBatch)
    water   = 1,                                          -- water units burned per batch
}
```
Every `item` must exist in `RSGCore.Shared.Items`. Production time for a run is `time * batches`; inputs and outputs are multiplied by `batches`.

### Chained lines
Setting `next` on a line links it to another line of the same factory. The whole run is planned on the server when the player presses *Produce* (`buildPlan`):
- Stage 1 runs the chosen batches. Each later stage runs `floor(available / needed)` batches, limited by the items the previous stage made (minimum 1, otherwise the start is refused).
- Inputs a later stage needs that the previous stage does not produce are taken from the player at the start, together with stage 1's inputs.
- Surplus and by-products are added to the final products. The player collects only the final result.
- Rules checked on save: `next` exists and is not the line itself, the line outputs at least one item the next line uses, no loops, chain length ≤ `Config.MaxChainLength`. Job locks of every stage are checked at the start.

### Ownership, fuel and water
A factory row holds `owner` (citizenid, `NULL` = for sale), `owner_name`, `price`, `fuel` and `water` (current stock in units).
- **Buying:** `buyFactory` takes `price` in cash (`RemoveMoney('cash', ...)`), sets the owner and refuses when the factory is owned or the player already owns `Config.MaxFactoriesPerPlayer`.
- **Stocking:** `addSupply(factoryId, key, amount)` is owner-only. `key` must be one of `Config.Supplies`; the item is removed from the owner and `amount * units` is added to the `fuel` or `water` stock, capped at `MaxFuel` / `MaxWater`. If `returnItem` is configured it is handed back per item used.
- **Spending:** `startProduction` refuses unowned factories. `buildPlan` totals `fuel` and `water` for the whole run (each stage's cost times the batches that stage runs). The stock is checked and deducted in the same step, after the player's inputs are verified, and given back if removing the inputs fails.
- Anyone can run a line at an owned factory; the owner's stock pays for it. Production does not need the owner online.

### Owner features (v3.0.0)
Settings live in `rsg_factories.settings` (JSON) and earnings in `bank`; `normSettings` rebuilds a clean table on load, so bad or missing data falls back to defaults.
```lua
settings = { fee = 0, access = 'public' | 'trusted' | 'owner', staffed = false, paused = false, broken = false,
             tank = 0, speed = 0, trusted = { { cid = '...', name = '...' } } }
```
- **Can this player start production?** `usageBlock` returns the locale key of the first rule that blocks: `no_owner`, `no_access`, `paused`, `broken`, `not_staffed` (staffing needs the owner or a trusted worker online unless the player is staff themselves).
- **Fee:** `fee * batches` cash is taken from non-owners and added to `bank` in the same step that takes fuel and water; every rollback path refunds it.
- **Upgrades:** tank adds `Upgrades.tank.bonus` per level to both capacities; speed shortens every stage time by `Upgrades.speed.percent` % per level (minimum 1 second per stage) when the run is planned.
- **Breakdowns:** after a successful start there is a `Breakdown.chance` % chance that `settings.broken` becomes true and the owner is alerted. New starts are refused until `repair` (cash, or 1x `Breakdown.repairItem` when set).
- **Sell:** pays `price * SellbackPercent / 100 + bank` after the database row is updated; clears owner, `bank`, fuel, water, fee, access, staffing, pause and trusted workers.
- **Transfer:** the owner sends an offer to a player standing at the factory; the receiver types `/acceptfactory` within `Config.TransferExpiry` seconds while at the factory. The row is updated first (`WHERE owner = old owner`), then the previous owner receives the earnings.
- **Alerts:** a thread every `Config.Alerts.interval` seconds claims finished queue rows (`notified` 0 -> 1, so each is handled once). With `AutoDeliver` an online player gets the products directly when they all fit; otherwise they get a notification, or an `rsg-telegram` telegram if offline (`SendTelegram(citizenid, subject, message, { senderName })`). Low fuel/water and breakdown alerts go to the owner the same way, throttled by `lowStockCooldown`.
- **Per-player sync:** `rsg-factory:client:sync` is sent per player and each factory carries `status` = `mine` | `sale` | `owned`, which drives the map blips. Ownership changes (buy, sell, transfer) re-sync everyone.

## Callbacks and events
All use the rsg-core callback system (`RSGCore.Functions.AwaitCallback` on the client).

| Name | Args | Returns | Notes |
|---|---|---|---|
| `rsg-factory:server:getFactories` | – | `{ factories, isAdmin }` or `nil` while loading | Public list for NPC spawning |
| `rsg-factory:server:getFactory` | `factoryId` | factory state or `nil` | Distance checked |
| `rsg-factory:server:getItems` | – | `{ {name,label}... }` or `nil` | Admin only |
| `rsg-factory:server:saveFactory` | `factoryId, data` | `bool` | Admin; `data = { name, ped_model, price, recipes }` |
| `rsg-factory:server:deleteFactory` | `factoryId` | `bool` | Admin; removes running productions |
| `rsg-factory:server:startProduction` | `factoryId, recipeIndex, batches` | `bool` | Takes inputs, queues output |
| `rsg-factory:server:buyFactory` | `factoryId` | `bool` | Takes cash, sets the owner |
| `rsg-factory:server:addSupply` | `factoryId, key, amount` | `bool` | Owner only; adds fuel or water to the stock |
| `rsg-factory:server:findPlayers` | `factoryId, query, mode` | `{ {cid, name, online} }` | Owner only, throttled. Player picker: online players first, then a database search of `players` (name or citizenid, min 2 characters; `mode = 'transfer'` lists online players only). Max 30 results |
| `rsg-factory:server:ownerAction` | `factoryId, action, data` | `bool` | Owner only. Actions: `setFee {value}`, `setAccess {value}`, `setStaffed {value}`, `setPaused {value}`, `addTrusted {cid}`, `removeTrusted {cid}`, `withdraw`, `upgrade {kind = 'tank'|'speed'}`, `repair`, `sell`, `transfer {cid}` (online, at the factory) |
| `rsg-factory:server:collect` | `factoryId` | `bool` | Pays out every finished production |

Events: `rsg-factory:client:sync` (server → all, public factory list) and `rsg-factory:client:openAdmin` (server → admin, opens the editor).

## Exports
None.

## Persistence
Factories and their lines live in `rsg_factories`. Running productions live in `rsg_factory_queue` with an absolute `finish_at` (unix seconds), so they continue while players are offline and across restarts. A run is one queue row whose `finish_at` is the end of the last stage; `stages` only drives the "Stage 2/3" display. Databases from older versions get the missing `stages`, `owner`, `owner_name`, `price`, `fuel` and `water` columns added automatically (only ever adding, never destructive). If you change `Config.DefaultPrice`, existing rows keep their own price. The queue stores the final outputs at start time, so editing a line later does not change productions already running.

## Security model
- Factory position is taken from the admin's server-side ped, never from the client.
- Every NUI callback is re-validated on the server: permission (`Config.AdminPermission`), distance to the factory, factory/line existence, batch limits, job lock, queue limit.
- Buying and stocking are server-side: ownership and price come from the server cache, the owner check uses the citizenid, supply items/units come from `Config.Supplies` (the client only sends a key and an amount), and the amount is clamped to the storage room. Money is removed before the owner is set, and the owner is set before any wait so two buyers cannot both succeed.
- Buying, stocking, starting production and collecting run through `lockedCallback`: one request at a time per player (released on error and on disconnect), so double-clicks or parallel calls can't beat the queue limit or spend the same items twice.
- A failed queue insert rolls back the inputs and the fuel/water; a failed purchase save refunds the cash and clears the owner. A price of 0 never calls `RemoveMoney`.
- Every owner action re-checks ownership by citizenid, distance to the factory and its own limits (fee range, access values, trusted list size, upgrade level, money). Trusted workers are validated on the server by citizenid against the `players` table (online or offline); transfer receivers must be online and at the factory. The picker callback only answers the owner and is throttled. Starts, upgrades, repairs, sales and transfers run through the per-player lock; the sale and transfer rows are updated with `WHERE owner = ...` before any money moves.
- Alerts only send server-built text (locale keys) to `rsg-telegram`; no client input is forwarded.
- Fuel and water cost per line is validated on save (`0..MaxUtilityPerBatch`); stock can never go below zero.
- Items and amounts are sanitised on save (existing item, no duplicates, `1..MaxAmount`, time `MinTime..MaxTime`, bounded text lengths); the client never supplies prices or output amounts at production time.
- Inputs are verified with `HasItem` and removed with rollback on failure. Outputs are paid after `CanAddItem` checks; the queue row is deleted first so it can never pay twice, and anything that fails to add is re-queued as a ready leftover.
- SQL uses `?` parameters only.

## Database schema
`rsg_factories` (`id`, `name`, `ped_model`, `x`, `y`, `z`, `h`, `recipes` JSON, `created_by`, `owner`, `owner_name`, `price` default 5000, `fuel`, `water`, `bank`, `settings` JSON) and `rsg_factory_queue` (`id`, `factory_id`, `citizenid`, `label`, `outputs` JSON, `finish_at`, `stages` JSON for chained runs, `notified` 0/1 for the ready alert). See `install.sql`. With `Config.AutoDatabase = true` they are created with `CREATE TABLE IF NOT EXISTS` on start; set it to `false` to import `install.sql` yourself.

## Server owner how-tos
- **Create a factory:** stand where the NPC should be, face the direction it should face, run `/createfactory Sawmill`.
- **Add a line:** target the NPC → *Manage Factory* → *Add Production Line*, pick items from the dropdowns, set amounts and time, *Save*.
- **Lock a line to a job:** type the job name in *Job Lock*; players need it as their active or a held multi-job job.
- **Chain lines:** in a line's editor choose *Then run (chain)* and pick the next line. Make sure the first line outputs something the next line uses.
- **Set a factory's price:** target the NPC → *Manage Factory* → *Sale Price*, *Save*.
- **Set a line's fuel and water cost:** in the line's editor set *Fuel per batch* and *Water per batch* (0 means the line needs none).
- **Change what counts as fuel or water:** edit `Config.Supplies` (item names, units per item).
- **Free up an owned factory:** there is no transfer yet; delete and recreate it.
- **Tune the economy:** `Config.Fees`, `SellbackPercent`, `Upgrades` costs and `Breakdown` (chance, repair cost) are all in `shared/config.lua`. Set `Breakdown.enabled = false` to turn breakdowns off, `AutoDeliver = false` to keep manual collection.
- **Repair with an item:** set `Config.Breakdown.repairItem = 'your_item'` (it must exist in `RSGCore.Shared.Items`); the owner then needs 1 of it instead of cash.
- **Turn off blips or alerts:** `Config.Blips.enabled`, `Config.Alerts.ready`, `Config.Alerts.telegram`, `Config.Alerts.lowStockPercent = 0`.
- **Move a factory:** delete it and create a new one (placement is by admin position).
- **Change language:** `setr rsg:locale de`.
- **Example factory:** `example_factory.lua` documents a chained Cigarette Factory (`tobacco_leaf` -> `tobacco_leaf_dried` -> `cigarette` -> `cigarettes`) with item definitions for `shared/items.lua` plus in-game and SQL install steps. It is reference only and is not loaded by the manifest.

## Troubleshooting
| Problem | Fix |
|---|---|
| NPC does not appear | Check the model name in the editor / `Config.DefaultPedModel`; stand within `SpawnDistance` |
| "Manage Factory" missing | Your account needs `Config.AdminPermission`; reconnect after changing permissions |
| Console: database setup failed | Check oxmysql, or set `Config.AutoDatabase = false` and import `install.sql` |
| Item pictures missing (letter shown instead) | rsg-inventory must be started and ship `html/images/<image>.png`; check `Config.ImagePath` and the item's `image` field |
| Item missing from the picker | It must exist in `RSGCore.Shared.Items` |
| Can't hear/talk with UI open | Keep `Config.AllowPushToTalkWhileOpen = true` |
| "Not enough product to feed the next line" | Increase batches, or raise the first line's output amount |
| Chain won't save | The linked line must use an item the previous line outputs; no loops |
| "no owner yet" when producing | The factory must be bought at its NPC first |
| "Not enough fuel/water" | The owner adds wood/coal/water under *Supplies*; check the line's per-batch cost |
| Supplies section missing | Only the owner sees it; check the factory's owner name |
| Console: "production lines rejected" | A line uses an item that no longer exists (or is otherwise invalid). The factory loads with no lines but the saved lines stay in the database; fix or re-add the item, or re-create the lines in the editor and save |
| Owner panel tab missing | Only the factory's owner sees it |
| "Nobody is working here" | The factory has *Needs staff online* on: the owner or a trusted worker must be online (or be the one starting) |
| "This factory has broken down" | The owner repairs it in the owner panel (*Condition*) |
| Can't add a trusted worker / transfer | The other player must be online, within about 12 m of the factory, and (for transfers) below `MaxFactoriesPerPlayer` |
| No "ready" telegram for offline players | `rsg-telegram` must be started and `Config.Alerts.telegram` true; the sender can still be blocked by the recipient |
| No blip | `Config.Blips.enabled`; owned-by-others factories are hidden unless `showOwnedByOthers` |
| Collect says inventory full | Free space; unpaid items stay queued |

Support: https://rexshack.tebex.store
