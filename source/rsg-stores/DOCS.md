# rsg-stores — Documentation (v3.1.0)

Reference for server owners and developers. For installation and everyday use see [README.md](README.md).

## Contents
1. [Architecture](#architecture)
2. [Store kinds](#store-kinds)
3. [Data formats](#data-formats)
4. [Events and callbacks](#events-and-callbacks)
5. [Exports](#exports)
6. [Persistence](#persistence)
7. [Security model](#security-model)
8. [Database schema](#database-schema)
9. [Server owner how-tos](#server-owner-how-tos)
10. [Troubleshooting](#troubleshooting)

---

## Architecture

| File | Side | Role |
|---|---|---|
| `shared/config.lua` | shared | All settings, incl. `Config.OwnedStores` |
| `server/sv_database.lua` | server | Auto installer / non-destructive migrator (`Config.AutoInstallDatabase`) |
| `server/server.lua` | server | Cache of stores/blips/presets, buy & sell, admin events, owner management callbacks |
| `server/sv_webhooks*.lua` | server | Discord queue (`purchases`, `sales`, `admin`, `owners`, `security`, `system`) |
| `client/client.lua` | client | NPC spawning, owned-store counter zones (rsg-target), shop/admin/manage NUI bridge |
| `html/script.js` + `style.css` | NUI | Customer shop |
| `html/admin.js` + `admin.css` | NUI | `/createshop` Shop Manager |
| `html/manage.js` + `manage.css` | NUI | Owner store management |

The server holds the authoritative cache (`CachedNPCs`). Clients get the full list on join and after admin edits (`refreshNPCs`, which respawns NPCs), and a light per-store update (`updateShop`) after stock, price, label or owner changes on owned stores. The till balance is never broadcast; it is read from the database for the owner only.

Framework APIs used: rsg-core callbacks (`CreateCallback` / `AwaitCallback`), rsg-core notify, rsg-core locales (`@rsg-core/shared/locale.lua`), rsg-target (`addLocalEntity`, `addSphereZone`), rsg-inventory (`GetItemCount`, `CanAddItem`, `AddItem`, `RemoveItem`). ox_lib is not used.

## Store kinds

| `kind` | Ped | Stock | Money from sales | Buy-back paid from |
|---|---|---|---|---|
| `npc` | Spawned ped with target | Set by admins, may be unlimited (`NULL`) | Removed from the economy | Nowhere (created), `Config.SellPricePercentage` |
| `player` | None; sphere zone at the coords | Only what the owner puts in, always limited | Added to the store `balance` (till) | The till, `Config.OwnedStores.BuyBackPercentage` |

Player stores opened with the **shop sign item** also have `prop` (the sign model). Their target is the sign object (spawned within `Config.DistanceSpawn`) instead of a sphere zone, and the owner can pack them up.

An owned store without an owner is closed: customers see *(Closed)* and buy/sell events are refused.

## Data formats

**Store entry (cache / client):**
```lua
{
  id = 12, name = 'Bob\'s Goods', model = '', kind = 'player',      -- 'npc' | 'player'
  x = 0.0, y = 0.0, z = 0.0, h = 0.0,
  owner = { citizenid = 'ABC12345', name = 'Bob Smith' },           -- player stores only, nil = closed
  shop = { name = 'bobs_goods', label = 'Bob\'s Goods', type = 'both', -- 'both' | 'buy' | 'sell'
           items = { { name = 'bread', label = 'Bread', price = 0.5, amount = 20 } } },
}
```

**Admin save payload (`adminSaveNpc` → server):** as above plus, for player stores,
`owner = { assign = <server id or nil>, clear = <bool> }`. `assign` must be an online player; the server resolves citizenid and character name itself. Items sent for a player store are ignored.

**Owner state (callbacks → manage NUI):**
```lua
{ ok = true, msg = 'text or nil', label, type, balance, items = {...},
  maxListings, maxStock, maxPrice, buyBackPct }
-- on failure: { ok = false, err = '<locale key>' }
```

## Events and callbacks

### Server callbacks (rsg-core)
| Name | Args | Who | Returns |
|---|---|---|---|
| `rsg-blipmenu:server:hasAdminPerm` | — | anyone | bool |
| `rsg-stores:server:getOnlinePlayers` | — | admin | `{ {id, name, citizenid} }` for the owner dropdown |
| `rsg-blipmenu:server:saveNPC` | `data` | admin | new id or nil |
| `rsg-stores:server:getPresets` / `savePreset` / `deletePreset` | see code | admin | presets |
| `rsg-stores:server:ownerGetState` | `npcId` | owner or any staff at store | owner state |
| `rsg-stores:server:ownerAddStock` | `npcId, item, qty, price?` | owner / `restock` | owner state (price required for a new listing) |
| `rsg-stores:server:ownerTakeStock` | `npcId, item, qty` | owner / `takestock` | owner state |
| `rsg-stores:server:ownerSetPrice` | `npcId, item, price` | owner / `prices` | owner state |
| `rsg-stores:server:ownerRemoveListing` | `npcId, item` | owner / `prices` + `takestock` | owner state (stock returned to the caller) |
| `rsg-stores:server:ownerWithdraw` | `npcId, amount` (`0` = all) | owner / `till` | owner state. Staff are capped by `DailyWithdrawLimit` (error `sv_staff_limit`, `errArgs = { left }`) |
| `rsg-stores:server:ownerSetSettings` | `npcId, label, type` | owner / `settings` | owner state |
| `rsg-stores:server:staffNearby` | `npcId` | owner | `{ ok, players = { {id, name} } }` within `HireDistance`, not already staff |
| `rsg-stores:server:staffHire` | `npcId, serverId, rank, perms?` | owner | owner state. `rank` = a `Config.Staff.Ranks` name (its perms are used) or `'custom'` with `perms = { restock = true, ... }` |
| `rsg-stores:server:staffUpdate` | `npcId, citizenid, rank, perms?` | owner | owner state |
| `rsg-stores:server:staffFire` | `npcId, citizenid` | owner | owner state (works for offline staff) |
| `rsg-stores:server:staffQuit` | `npcId` | staff | `{ ok, closed=true }` |
| `rsg-stores:server:placeSign` | `{ x, y, z, h, label, type }` | player holding the sign | `{ ok, msg }` / `{ ok=false, err }` |
| `rsg-stores:server:ownerPackUp` | `npcId` | owner of a sign store | `{ ok, closed=true }` |
| `rsg-stores:server:ownerPickUp` | `npcId` | owner of a sign store, `AllowMove` on | `{ ok, closed=true }` |
| `rsg-stores:server:ownerWholesale` | `npcId, item, qty, price?` | owner / `wholesale` | owner state. Item must be in `Config.Wholesale.Items`; paid per `PayFrom`; default price = cost × `Markup` |
| `rsg-stores:server:ownerPayUpkeep` | `npcId` | owner / `upkeep` | owner state. Pays all owed upkeep from the till first, then cash |

Owner state also carries `role` (`owner|staff`), `rank` (staff), `perms` (`{ perm = bool }` for the caller), `permList`, `ranks`, `staffOn`, `maxStaff`, `withdrawLeft` (staff with a daily limit), `staff` (owner only: `{ {cid, name, rank, perms, online} }`). `balance` is only sent with `till`, `ledger` only with `ledger`, `wholesale` is empty without `wholesale`; `canPackUp`/`canPickUp` are owner only. Errors may carry `errArgs` for `string.format`.

Owner state now also carries `upkeep` (`{ amount, owed, dueIn, evictAfter }` or nil), `wholesale` (`{ {name, label, cost} }`), `ledger` (`{ {ts, kind, item, qty, amount, who} }`, `kind` = `sale|buyback|wholesale|upkeep|withdraw`) and `markup`.

### Server net events
| Event | Args | Notes |
|---|---|---|
| `rsg-stores:server:purchaseCart` | `npcId, { {name, quantity} }` | Owned: credits till, notifies owner |
| `rsg-stores:server:sellItem` | `npcId, item, qty` | Owned: paid from till |
| `rsg-stores:server:requestShopStock` | `npcId` | Live stock |
| `rsg-blipmenu:server:updateNPC` / `deleteNPC` | admin | Owner assign/clear handled in update |
| `rsg-blipmenu:server:evictOwner` | `npcId, force` | admin. Returns stock, till and sign to an online owner; `force` evicts an offline owner and forfeits them. Sign stores are deleted; admin stores are emptied and left unowned |
| `rsg-blipmenu:server:saveBlip` / `updateBlip` / `deleteBlip` | admin | |
| `rsg-blipmenu:server:requestNPCs` / `requestBlips` | — | Initial sync |

### Client events
| Event | Args |
|---|---|
| `rsg-blipmenu:client:refreshNPCs` | full store list (respawns NPCs, rebuilds counter zones) |
| `rsg-stores:client:updateShop` | `npcId, shop, owner, upkeepOwed` (no respawn) |
| `rsg-stores:client:staffStores` | `{ npcId, ... }` stores this character works at (sent on `requestNPCs` and whenever they're hired/fired/quit). Shows **Manage Store**, hides **Trade** |
| `rsg-stores:client:startSignPlacement` | — (from the usable item; opens `exports['rsg-gizmo']:Place(Config.ShopSign.Model, { rotation = 'z', snapToGround = true, maxDistance ≤ 4.0 })`; confirm opens the name/type panel, **Reposition** reopens the gizmo at the last spot, cancel keeps the item) |
| `rsg-blipmenu:client:refreshBlips` | blip list |
| `rsg-stores:client:transactionResult` / `purchaseSuccess` / `purchaseFailed` / `shopStock` | shop NUI updates |

## Exports
| Export | Side | Description |
|---|---|---|
| `SendWebhook(channel, title, description, src, fields)` | server | Send a log through the rsg-stores queue |

## Persistence
Everything is saved to MySQL immediately. Stock changes use atomic `UPDATE ... WHERE stock >= ?`, and till changes use `UPDATE ... WHERE balance >= ?`, so concurrent customers and the owner can't oversell or overdraw. Owned-store stock is the item rows' `stock` column; the till is `rsg_shops_npcs.balance`.

## Security model
**rsg-stores checks:**
- Discounts, wholesale costs and upkeep amounts are worked out on the server from config only. Wholesale and upkeep payments are taken atomically (till) or with a checked `RemoveMoney` before any stock or status changes. Eviction is admin-only and permission-checked; returned stock is checked with `CanAddItem`, and anything that doesn't fit is listed as lost in the admin log.
- Admin events/callbacks: `RSGCore.Functions.HasPermission(src, Config.AdminPermission)`; denied attempts are logged to security.
- Every trade and owner action: player exists, store exists, database loaded, player within `TargetDistance + 5.0` of the store, 750 ms per-player cooldown (rate-limited trades still get a failure reply so the NUI unlocks).
- Owner actions: the caller's citizenid must equal `owner_citizenid`, or be a hired staff member with the permission for that action (`requireAccess(src, npcId, perm)`). Callers who are neither are logged as security events; staff without the permission get `sv_no_permission`. The store id comes from client Lua state, never the NUI.
- Owner-only, never staff: hire / update / fire, pack up, pick up & move. Staff can't buy from or sell to a store they work at (blocked in `purchaseCart` and `sellItem`), so `prices` can't be used to buy stock at $0 or drain the till by selling to the store at a high price.
- Hiring: target must be online, a different character, within `HireDistance` of the owner (and the owner at the store), not already staff, under `MaxStaff` and `MaxJobsPerPlayer`. Permissions are whitelisted against the 8 keys; rank presets come from server config only. Staff rows are deleted when the store is packed up, deleted, evicted, repossessed, converted or given a new owner.
- Staff till withdrawals: `DailyWithdrawLimit` is tracked per staff row (`withdrawn`, `withdraw_day` = `YYYYMMDD`), so restarts don't reset it.
- Item quality: selling to any shop and stocking a shelf only count and remove stacks whose `info.quality` is missing or at least `Config.OwnedStores.MinQuality`; removal is per slot, rolled back on failure. Stops worn/spoiled items coming back out as fresh ones.
- Picked-up (hidden) stores refuse purchases as well as sales and owner actions.
- Sign placement: `exports['rsg-gizmo']:IsPlacementValid(src, coords, 5.0)` on top of the 5 m and spacing checks.
- Sync requests (`requestNPCs`, `requestBlips`: 2 s; `requestShopStock`: 300 ms) are throttled per player; they only read the cache.
- Quantities are whole numbers 1–1000; prices 0–`MaxPrice`, rounded to cents; labels trimmed to 100 chars; shop type whitelisted.
- Stocking: item must exist in `RSGCore.Shared.Items`, not be blacklisted, unique or a weapon (metadata would be lost); the owner must hold the items and they are removed before stock is added.
- Taking stock: `CanAddItem` first, stock reserved atomically, rolled back if `AddItem` fails. Removing a listing only deletes if the stock didn't change meanwhile.
- Withdrawals: atomic till decrement before `AddMoney('cash')`.
- Shop sign: the item must be held (checked on use and again on place), it is removed before the store is created (refunded if the insert fails), the sign must be within 5 m of the player and `MinSpacing` from every other store, and `MaxPerPlayer` is enforced per citizenid.
- Pick up & move: owner gets a **Pick Up & Move Store** target option on the sign (and a button on the Settings tab). Sign stores only, room for the sign is checked first. Sets `packed_at`; the store stays in the server cache (stock, prices, till, ledger untouched) but is left out of the NPC/blip lists sent to clients, and all trade/owner calls refuse it. Upkeep skips it. Using the sign while you have a picked-up store skips the details panel; `placeSign` then moves that store (new x/y/z/h, blip moved, `packed_at` cleared, `upkeep_next` pushed back by the time it was packed). It doesn't count against `MaxPerPlayer` twice.
- Pack up: sign stores only, shelves must hold 0 stock, room for the sign is checked first, till paid out atomically.
- Buy-back to owned stores: till reserved atomically before items are removed, refunded on any failure.

**Other scripts must check** their own permissions if they write to these tables directly, and should not hand out stock outside the owner flow.

## Database schema
Created automatically (or `install/rsg-stores.sql`):

`rsg_shops_npcs`: `id`, `name`, `model`, `x`, `y`, `z`, `h`, `shop_name`, `shop_label`, `shop_type` (`both|buy|sell`), `store_kind` (`npc|player`, default `npc`), `owner_citizenid` (nullable), `owner_name` (nullable), `balance` decimal(12,2) default 0, `prop_model` (nullable; set for shop sign stores). Indexes `idx_shop_name`, `idx_owner`.

`rsg_shops_items`: `id`, `npc_id`, `item_name`, `label`, `price`, `stock` (NULL = unlimited, NPC stores only).

`rsg_shops_blips`: `id`, `name`, `sprite`, `color`, `x`, `y`, `z`, `associated_npc_id`.

`rsg_shops_presets`: `id`, `kind` (`model|blip`), `label`, `value`.

`rsg_shops_npcs` also has `upkeep_owed` decimal(10,2) default 0 and `upkeep_next` int (unix time the next upkeep is due; sign stores only). `packed_at` int is set while a sign store is picked up (moving) and NULL otherwise.

`rsg_shops_staff`: `id`, `npc_id`, `citizenid`, `name`, `staff_rank` (rank name or `custom`), `perms` (comma list of `restock,takestock,prices,wholesale,till,ledger,settings,upkeep`), `withdrawn` decimal(12,2), `withdraw_day` int (`YYYYMMDD`), `hired_at` (unix). Unique `uq_store_staff (npc_id, citizenid)`, index `idx_staff_cid`.

`rsg_shops_ledger`: `id`, `npc_id`, `ts` (unix), `kind`, `item`, `qty`, `amount`, `who`. Index `idx_ledger_npc`. Trimmed to `Config.Ledger.Keep` rows per store every 5 minutes; deleted with the store.

## Server owner how-tos
- **Sell a store to a player:** take payment however your server does it, then `/createshop` → store → pick them in **Assign Owner** → Save.
- **Evict an owner:** open the store and press **Evict Owner** twice. Stock, till and sign go back to the owner (they must be online, unless you tick *Forfeit*). To keep the stock and till for the next owner instead, tick **Remove current owner** and Save.
- **Charge rent for sign stores:** set `Config.ShopSign.Upkeep`. The upkeep check runs every 5 minutes on the server's real clock (`os.time()`), so periods keep counting while the server is offline and are charged on the next start.
- **Opening hours** use each client's in-game clock (rsg-weather syncs it). The check happens on the client only, because closing hours don't affect money.
- **Discounts** use the player's current job (`PlayerData.job.name`) and gang. The server applies them to purchases and, at NPC shops, to what the shop pays when that player sells (payout = price x `SellPricePercentage` x (1 - discount)), so discounts can't be farmed. The client only shows them.
- **Price exploit warning:** on start the server prints `price exploit: <item> costs $X at <shop> but <shop> pays $Y` for every item you can buy (NPC shop or wholesale) for less than another NPC shop pays. Raise the buy price or lower the sell price until it's gone.
- **Refund a till before deleting:** read `balance` for the store in `rsg_shops_npcs` (also logged on delete/convert under *Till lost*) and pay the owner manually.
- **Stop customers selling to owned stores:** the owner (or admin) sets the counter to *Buy only*.
- **Staff ranks:** edit `Config.Staff.Ranks` (`{ name = 'cashier', perms = { 'restock', 'till' } }`) and add `ui_rank_cashier` to all 10 locale files. Existing staff keep the permissions they were saved with.
- **Turn staff off:** `Config.Staff.Enabled = false`. Staff rows are kept but give no access until it's back on.
- **Turn the feature off:** `Config.OwnedStores.Enabled = false` — owned stores lose their counter zones and owner actions are refused; data is kept.

## Troubleshooting
| Problem | Cause / fix |
|---|---|
| Sign doesn't appear | Check `Config.ShopSign.Model`; invalid models are printed in F8 |
| Using the sign does nothing | You already own `MaxPerPlayer` sign stores, or `Config.ShopSign.Enabled`/`Config.OwnedStores.Enabled` is false (a notification says which) |
| Owned store has no target | Check `rsg-target` is started before rsg-stores and `Config.OwnedStores.Enabled` is true |
| "No player with that server ID is online" | The owner must be online when assigned |
| Owner can't stock an item | Item is blacklisted, unique or a weapon, or the shelf hit `MaxStock` / `MaxListings` |
| "Something changed, please try again" | A customer bought stock while you removed the listing; retry |
| Buy-back refused | Till too low for the payout |
| Language not changing | Use `setr rsg:locale "xx"` |
| Shopkeeper doesn't speak | Some ped voices don't have every line; change the lines in `Config.Speech` or set `Enabled = false` |
| "Closed until the owner pays its upkeep" | Owner opens **Manage** and presses **Pay Upkeep** |
| Wholesale tab missing | `Config.Wholesale.Enabled` is false or no `Items` exist in your shared items |

---

Support: https://buymeacoffee.com/rexshack

## Dependencies
`rsg-core`, `rsg-inventory`, `rsg-target`, `rsg-gizmo` (shop sign placement), `oxmysql`. Ensure `rsg-gizmo` before `rsg-stores`.
