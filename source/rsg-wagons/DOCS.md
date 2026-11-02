# rsg-wagons · Documentation

## Contents
1. [Files](#files)
2. [Data formats](#data-formats)
3. [Exports](#exports)
4. [Events and callbacks](#events-and-callbacks)
5. [NUI messages and callbacks](#nui-messages-and-callbacks)
6. [Persistence](#persistence)
7. [Security model](#security-model)
8. [Database schema](#database-schema)
9. [Server owner how-tos](#server-owner-how-tos)
10. [Ideas taken from the RDR2 decompiled scripts](#ideas-taken-from-the-rdr2-decompiled-scripts)
11. [Troubleshooting](#troubleshooting)

## Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest. rsg-core locales, NUI page, dependencies |
| `shared/config.lua` | All settings, yards and the wagon catalogue |
| `client/client.lua` | NPCs, blips, rsg-target options, NUI bridge, preview vehicle + orbit camera, spawning the owned wagon |
| `server/server.lua` | Database setup, purchase/take-out/store/sell/rename callbacks, storage, cleanup, exports |
| `html/index.html`, `style.css`, `app.js` | Full-screen catalogue, details card (with camera controls), name + confirm modals |
| `locales/*.json` | 10 languages, identical keys |
| `install.sql` | Manual schema (same as auto-build) |

## Data formats
**Wagon entry** (`Config.Wagons[model]`)
```lua
wagon02x = { label = 'Standard Camping Wagon', category = 'wagons', price = 40,
             weight = 560, slots = 50, seats = 2, tier = 3,
             description = '...', stores = { 'valentine' } } -- stores optional
```
`weight` is in kg; the stash uses `weight * 1000` grams. `tier` 1 light, 2 medium, 3 large, 4 tanker (from the RDR2 fence classes).

**Owned wagon** (returned by `getOwned` / `GetPlayerWagons`)
```lua
{ id, model, name, label, category, condition, conditionTier, store, storeLabel, active, sellValue, weight, slots }
```
`conditionTier` is `damaged | poor | average | quality | exceptional`.

## Exports
### Server
| Export | Params | Returns |
|---|---|---|
| `GetActiveWagon(src)` | server id | `{ id, netId, model }` or `nil` |
| `GetPlayerWagons(citizenid)` | citizenid | array of owned wagons (format above) |

Entity state bags on a spawned owned wagon: `rsgWagonId` (DB id) and `rsgWagonOwner` (server id). Other scripts can read `Entity(veh).state.rsgWagonId` to detect a player wagon.

## Events and callbacks
| Name | Type | Side | Notes |
|---|---|---|---|
| `rsg-wagons:server:getOwned` | callback | server | `cb(list)` |
| `rsg-wagons:server:buy` | callback | server | `(storeKey, model, name)` → `cb(ok, owned)` |
| `rsg-wagons:server:takeOut` | callback | server | `(storeKey, id)` → `cb(ok, { id, model, name, condition, coords })` |
| `rsg-wagons:server:store` | callback | server | `(storeKey, condition)` → `cb(ok, owned)` |
| `rsg-wagons:server:sell` | callback | server | `(storeKey, id)` → `cb(ok, owned)` |
| `rsg-wagons:server:rename` | callback | server | `(id, name)` → `cb(ok, owned)` |
| `rsg-wagons:server:registerSpawned` | net event | server | `(id, netId)` after the client creates the wagon |
| `rsg-wagons:server:spawnFailed` | net event | server | `(id)` frees the pending take-out |
| `rsg-wagons:server:openStorage` | net event | server | `(netId)` opens `wagon_<id>` stash |
| `rsg-wagons:client:openShop` | event | client | `(storeKey)` opens the shop (e.g. from another script) |

## Liveries
- `shared/liveries.lua` holds `Config.Liveries[model] = { { id, label }, ... }`, generated from femga/rdr3_discoveries `vehicles/vehicle_modding/vehicle_liveries.lua` for every model in `Config.Wagons`. Labels are the game's internal names (English, not localised). Delete an entry to hide it; a model with no list shows "No liveries".
- Applied with `_SET_VEHICLE_LIVERY` (`0xF89D82A0582E46ED`) on the preview wagon and on the networked wagon when it's taken out.
- Saved in the `livery` column of `player_wagons` (`-1` = none). Older tables get the column added automatically on start when `AutoDatabase = true`; otherwise run the `ALTER TABLE` line at the bottom of `install.sql`.
- Paint (livery + colour) is chosen **only when buying**, is free, and can't be changed afterwards. The details panel hides the pickers for owned wagons; their preview still shows the saved paint. The chosen livery is sent with `rsg-wagons:server:buy` and validated server side (an unknown id falls back to the model's first livery).
- NUI callback: `previewLivery { livery, tint }` repaints the preview without respawning.

## Colours (tints)
- The base colour is a separate layer from the livery. `Config.Tints[model] = count` in `shared/liveries.lua` (from femga/rdr3_discoveries `vehicle_tints.lua`); tint ids run `0..count-1`, `-1` = the model's default colour. Tints have no names in the game, so the UI shows "Default", "Colour 1", "Colour 2"…
- RDR2 itself has no player colour shop: the decompiled scripts (build 1436) only call `_SET_VEHICLE_TINT` (`0x8268B098F6FCA4E2`) from missions/ambient events (e.g. `braithwaites1.c`, `av_wagon_music.c`) to colour scripted wagons; `generic_wagon_fence_core.c` has no paint option.
- Applied **tint first, then livery** (livery re-applied 150 ms later), on the preview and on take-out. In RDR2 a tint is a full paint scheme that also sets its own livery (tested in-game: tint 5 on a cart forces livery 2), so the chosen livery must go on after it; tint 5 then livery 7 keeps both. Rockstar's missions set the tint straight after `CREATE_VEHICLE` (e.g. `rcm_dutch11.c` three `WAGON04X` with tints 11/9/10).
- Horse-coat style recolouring (metaped shop components) does not apply: wagons are vehicles, not metapeds, so tint + livery are the only paint controls.
- Saved in the `tint` column (auto-added on start; manual `ALTER TABLE` line in `install.sql`).
- `rsg-wagons:server:buy(..., livery, tint)` validates both; take-out returns the saved `livery` and `tint` and the client applies them.

## List / details flow
Selecting a wagon hides the catalogue and shows the details panel with the preview. **Back** (or ESC) clears the selection, ends the preview and shows the catalogue again; ESC on the catalogue closes the shop. Selling a wagon also returns to the list.

## Preview camera
The camera stays still unless you rotate it (`Config.Preview.autoRotate = 0.0`; set it above 0 for an idle spin). Rotate/zoom works from the camera row in the details panel (buttons, or mouse wheel over that row; the old bottom camera bar was removed), A/D or arrow keys, and the mouse wheel over the open game view.

## Movable UI
`html/drag.js` makes the catalogue, details panel and both pop-ups draggable by their title bars. The catalogue and details panel share one position (`main`), since they swap in the same spot — moving either moves both. Offsets are applied through the `--dx`/`--dy` CSS variables and saved in the NUI's localStorage under `rsg-wagons:pos:<panel>`. Double-clicking a title bar resets that panel. To make a new panel movable, add it to the `targets` list in `drag.js`.

## NUI messages and callbacks
Lua → NUI: `{ action = 'open', store, categories, wagons, owned, maxWagons, nameMax, hasActive, strings }`, `{ action = 'close' }`.

NUI → Lua: `close`, `preview {model}`, `clearPreview`, `rotateCam {dir = 'left'|'right'|nil}`, `zoomCam {dir = 1|-1}`, `buy {model, name}`, `takeOut {id}`, `store`, `sell {id}`, `rename {id, name}`.

## Persistence
- Owned wagons live in `player_wagons`.
- `active = 1` while a wagon is out; all rows reset to `0` on resource start.
- On **Return Wagon** the condition (vehicle health %) and yard are saved. A wrecked wagon saves as 10%.
- On take-out the saved condition is applied to the new vehicle's health.
- Leaving the server or stopping the resource deletes the out wagon and marks it stored.
- Storage contents are kept by rsg-inventory under `wagon_<id>` and cleared when the wagon is sold.

## Security model
Checked on the server:
- Player exists, per-player cooldown on every action.
- Store key and model must exist in config (and the wagon must be sold at that yard if `stores` is set).
- Distance from the player to the yard keeper / preview spot for buy, take out, store and sell.
- Price taken from config; `RemoveMoney` result checked before inserting; refunded if the insert fails.
- Owner check (`id` + `citizenid`) on every row operation; max wagons; one wagon out at a time.
- Spawned entity must exist and match the expected model before it is registered.
- Storage: entity must carry `rsgWagonId`, the player must own that row and stand within `UseDistance + 2`.
- Names are stripped of `< > " ' \` \` and cut to `NameMaxLength`. SQL uses `?` parameters only.

- Every action that changes money or items (buy, sell, yard/field repair, stow carcass, sell cart load) works out prices and rewards from server config, checks distance and ownership, and is rate limited.
- Cart loads: carcass must be a dead, non-player animal in `Config.HuntingCart.animals`, near the player; it's deleted before the load is saved. Items are checked with `CanAddItem` before anything is paid out.

Client-reported values and how they're limited:
- **Wagon condition** (vehicle health is client-owned): the server only accepts reports that **lower** the condition it already knows (`reportedCondition`). Only server-side repairs raise it, so a modified client can't skip repair costs or raise the trade-in value.
- **Carcass quality** (poor/good/perfect, read with `GetPedQuality` on the client): trusted the same way rsg-hunting's butcher trusts it; there's no server-side native to read it.

## Changelog
- **2.1.0**: audit. Condition reports can only lower a wagon's condition; rename is rate limited; calling a wrecked wagon is refused before anything changes; paint now applies per wagon (several wagons in view no longer cancel each other's livery); hunting cart carcass lookup cached (it ran every frame while aiming at the cart); field repair checks you can pay before the animation; shop can't be opened twice by double-clicking; customise panel closes on logout. Removed: `/wagonpaint` debug command and `Config.Debug`, unused `rsg-wagons:client:openShop` event, unused `rsgWagonOwner` state bag, 5 unused UI text keys; database upgrades merged into one helper.

## Database schema
```sql
CREATE TABLE IF NOT EXISTS `player_wagons` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `model` VARCHAR(50) NOT NULL,
  `name` VARCHAR(40) NOT NULL,
  `wagon_condition` INT(11) NOT NULL DEFAULT 100,
  `store` VARCHAR(50) NOT NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
);
```

## Server owner how-tos
- **Add a yard:** add an entry to `Config.Stores` with `npc` (where the keeper stands) and `preview` (an open, flat spot big enough for a stagecoach and its horses; also the spawn point).
- **Add a wagon:** add `Config.Wagons.<model>`; use a model from the list in `shared/config.lua` or check the name in rdr3_discoveries. Put it in an existing category or add one to `Config.Categories` plus `cat_<id>` in every locale file.
- **Yard-only wagons:** `stores = { 'saintdenis' }`.
- **Hide draft horses in the preview:** `Config.Preview.draftAnimals = false`.
- **Open the shop from another script:** `TriggerEvent('rsg-wagons:client:openShop', 'valentine')` (server still checks distance).

## Ideas taken from the RDR2 decompiled scripts
From `generic_wagon_fence_core.c` (build 1436):
- The model list in `shared/config.lua` is the wagon fence's list of valid wagons (`func_29`).
- Wagon classes 1–4 (`func_30`) are used as the **Class** badge.
- The fence treats a wagon as damaged when health is below 90% of max (`GET_ENTITY_HEALTH < MAX - MAX/10`) and grades the rest poor/average/quality/exceptional; this drives the condition tiers and the damaged trade-in penalty.

## Cargo & lanterns (propsets)
- Target your own wagon → **Customise Wagon** (only shown if the model has sets) opens a panel with **Cargo** and **Lanterns** pickers (each with **None**). Changes preview live on the wagon; **Save** stores them, **Cancel**/ESC puts the saved look back.
- Lists: `shared/propsets.lua` → `Config.Propsets[model]` / `Config.Lanterns[model] = { { name, label } }`, built from femga/rdr3_discoveries @ f729ba0:
  - https://github.com/femga/rdr3_discoveries/blob/f729ba03f75a591ce5c841642dc873345242f612/vehicles/vehicle_modding/vehicle_propsets.lua
  - https://github.com/femga/rdr3_discoveries/blob/f729ba03f75a591ce5c841642dc873345242f612/vehicles/vehicle_modding/vehicle_lantern_propsets.lua
  Story-mission-only sets were left out. Models with none (buggies, wagon03x, coach3–6, oilwagon01x) don't get the option.
- Natives, following Rockstar's decompiled scripts (`av_wagon_music.c`, `ambush_odr_*.c`): `_REQUEST_PROP_SET` `0xF3DE57A46D5585E9` → wait for `_HAS_PROP_SET_LOADED` `0x48A88FC684C55FDC` → `_ADD_PROP_SET_FOR_VEHICLE` `0xD80FAF919A2E56EA`. femga's example uses `_ADD_ADDITIONAL_PROP_SET_FOR_VEHICLE` (`0x75F90E4051CC084C`), which Rockstar never calls and is the likely cause of the screen judder reported while driving. Removal: `_REMOVE_VEHICLE_PROP_SETS` `0x3BCF32FF37EA9F1D`, `_ADD_LIGHT_PROP_SET_TO_VEHICLE` `0xC0F0417A90402742`, `_REMOVE_VEHICLE_LIGHT_PROP_SETS` `0xE31C0CB1C3186D40`.
- Saved in `propset` / `lantern` columns (auto-added on start; manual `ALTER TABLE` line in `install.sql`). Server: `rsg-wagons:server:setLook(propset, lantern)` checks you own the wagon that's out, are within reach, and that both names are in the config list.
- **Sync**: the server puts the wagon's full look (livery, tint, propset, lantern) in the entity state bag `rsgWagonLook`. Every client scans nearby vehicles every 2.5 s and applies it once per change, so other players (and players who stream in later) see the same paint, cargo and lanterns.

## Hunting cart (huntercart01)
- RDR2 story scripts (decompile builds 1355 / 1436) have nothing on `huntercart01`: it's a Red Dead Online vehicle. What's known comes from femga/rdr3_discoveries: tarp propset `pg_mp005_huntingWagonTarp01`, `_SET_BATCH_TARP_HEIGHT` (`0x31F343383F19C987`, height = cargo + pelt ratio), 6 liveries (Hunt0–5), 6 tints, cart06's lantern sets.
- Sold in the shop as **Hunting Cart** (`Config.Wagons.huntercart01`, carts). The tarp is always fitted; its height is `tarpMin..tarpMax` scaled by load / `capacity` and synced to everyone through the `rsgWagonLook` state bag (`look.tarp`, `look.cargo`).
- **Stow Carcass** (target on your own cart): takes the dead animal you're carrying, or one strapped to your horse within `horseRange` (same itemset lookup as rsg-hunting's butcher). Server `rsg-wagons:server:stowCarcass(netId, quality)` checks it's a dead, non-player animal in `Config.HuntingCart.animals`, close to you, cart within reach and not full; deletes the carcass and saves `{ model, quality }` to the wagon's `cargo` column (JSON, auto-added on start). Quality = `GetPedQuality` 0/1/2 → poor/good/perfect.
- **Sell Cart Load** (shown when the cart is within `sellRange` of a butcher in `Config.HuntingCart.butchers`): progress bar, then `rsg-wagons:server:sellCargo` pays `money x qualityMultiplier` per carcass, gives `items x itemQuantity`, and awards hunting XP through rsg-hunting's `AwardHuntingXP` export (`xpPerCarcass x quality`, skipped if rsg-hunting isn't running). Items are checked with `CanAddItem` first; if they don't fit, nothing is sold.
- Prices, items and butcher locations are a copy of rsg-hunting's `Config.Animal` / `Config.ButcherLocations` — keep them in step if you change rsg-hunting.
- The load stays in the cart when it's stored, sent away, called back or the server restarts. Selling the wagon itself loses any load.

## Repairs
- **Field patch (temporary)**: target your wagon → **Patch Up Wagon** (shown when it's below `Config.FieldRepair.condition`), or `/repairwagon` (`FieldRepair.command`), which also works on a wreck from anywhere. The player crouches (`WORLD_HUMAN_CROUCH_INSPECT`) for `duration` ms, then the server charges `cost` (`{ type = 'item', item, amount }` or `{ type = 'money', amount }`) and raises the condition to `condition` (default 35%), never higher. A patched wreck is cleared and becomes "away", so J calls it back.
- **Yard repair (full)**: My Wagons → select a stored wagon → **Repair · $x** restores 100%. Price = `ceil((100 - condition) * Config.YardRepair.pricePerPercent)`. Server: `rsg-wagons:server:yardRepair(storeKey, id)`.
- Condition `0` now means **wrecked only**. Normal damage saves are clamped to at least 1%, so a badly damaged (but not wrecked) wagon is no longer restored as wrecked after a restart — the cause of wagons wrongly showing as wrecked.

## Wagons out across restarts / relogs
- A wagon that is out stays out (`active = 1`) when the server restarts, the resource stops, the player disconnects, or logs out to character select (`RSGCore:Server:OnPlayerUnload`). Only the entity is removed. Previously these all forced the wagon back to its yard.
- On login (`RSGCore:Client:OnPlayerLoaded`, or resource start while logged in) the client sends `rsg-wagons:server:restore`. The server finds the character's `active = 1` wagon, re-registers it as out-but-away, and the client shows "<name> is still out. Press J to call it". If more than one row is somehow active, the extras are put back at their yard.
- Condition survives too: the client reports it via `rsg-wagons:server:condition` whenever it changes, and the server writes it to the database when the wagon leaves the world without being stored.
- A wagon wrecked while out is saved with `wagon_condition = 0`. After a restart it stays wrecked: it can't be called and must be returned at a yard (it's then stored at 10% condition).

## Wagon blip
- While your wagon is out and in the world it carries a blip (`BLIP_ADD_FOR_ENTITY` with `BLIP_STYLE_PLAYER_COACH`, sprite `blip_player_coach`, named after the wagon). That style is RDR2's own player-coach blip: shown on map and radar at any range, heading arrow, and hidden while you ride the wagon (femga/rdr3_discoveries `useful_info_from_rpfs/blip_styles`).
- The blip is removed when the wagon is stored, sent away, streams out of the world, is wrecked, or the resource stops, and re-added when you call it back or take it out.
- Change or disable it with `Config.WagonBlip`.

## Send away / call (like horses)
- **Send away**: target the wagon → **Send Wagon Away**, or `/fleewagon`. You're taken off the seat if needed, the wagon fades out and is deleted, its condition is saved, and it stays **out** (not stored). Server: `rsg-wagons:server:fleeWagon(condition)`.
- **Call**: press `Config.CallKey` (J, `0xF3830D8E` INPUT_OPEN_JOURNAL) or `/callwagon` while you have a wagon out. If it's within `CallNearDistance` you're told it's nearby; otherwise any old copy is removed and it fades in on the nearest road node within `CallRoadDistance` (`GET_NTH_CLOSEST_VEHICLE_NODE_WITH_HEADING`), or 8 m in front of you if there's no road. Paint, condition and storage come with it. Server: `rsg-wagons:server:callWagon` → client spawns → `registerSpawned`; if the spawn fails the wagon simply stays away.
- A wrecked wagon can't be called; return it at a yard. A wagon that streams out of the world (you rode far away) is treated as away, not wrecked, so J brings it back.
- An away wagon can still be stored with the yard prompt (your position is used).
- J normally opens the journal in RDR2; RedM servers usually don't use it, but if yours does, change `Config.CallKey` (any RedM control hash) or set it to `false` and use the command.

## Storing a wagon
There are three ways to store, all handled on the server:
- **Yard prompt**: with your wagon out and both you and the wagon within `Config.StoreRadius` of a yard, a hold prompt (`Config.StoreKey`, default G) appears. Works while sitting on the wagon.
- **Wagon target**: target your wagon → **Store Wagon**.
- **Keeper menu**: My Wagons → **Return Wagon**.

The prompt and target both call `rsg-wagons:server:storeNearest`, which stores at whichever yard is closest to the wagon. A wrecked wagon uses your own position instead. The keeper menu calls `rsg-wagons:server:store` for that specific yard.

## Troubleshooting
| Problem | Fix |
|---|---|
| `database setup failed` in console | Check oxmysql connection, or set `AutoDatabase = false` and import `install.sql` |
| No keeper / no target | Make sure `rsg-target` starts before rsg-wagons |
| Preview doesn't appear | Check the yard's `preview` coords are on open ground; look for `Could not load the wagon preview` (bad model name) |
| Camera clips into buildings | Lower `Config.Preview.radiusMax` or move `preview` to a more open spot |
| "You already have a wagon out" | Your wagon is still out (also after a restart): press **J** to call it, or go to any yard → My Wagons → **Return Wagon** (needed if it was wrecked) |
| Can't store the wagon | You and the wagon must both be within `StoreRadius` of a yard's keeper or preview spot; raise it if your yards are spread out |
| Selling does nothing | Every refusal now shows a notification and prints `[rsg-wagons] sell refused for <id> (wagon <id>): <reason>` in the server console; "The wagon yard did not respond" means the server callback errored, so check the server console for a Lua error |
| Storage won't open | Only the owner can open it, within `UseDistance` |
| Storage does nothing right after taking a wagon out | Fixed: the server now waits up to 5s for the spawned wagon to replicate before linking it, and falls back to its own active-wagon record. If it still fails, look for `entity never reached the server` in the server console |

Support: https://buymeacoffee.com/rexshack
