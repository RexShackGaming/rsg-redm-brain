# rsg-crafting – Docs (v3.3.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Exports and events
5. Security
6. Server owner how-tos
7. Troubleshooting
8. Database

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `oxmysql`, `rsg-target`, `rsg-gizmo` |
| `shared/config.lua` | Book item, XP, animation, recipes |
| `client/client.lua` | NUI bridge, crafting animation, queue, shared-crafting target, push-to-talk whitelist |
| `client/stations.lua` | Station props / target zones, `/craftstation` placement |
| `server/server.lua` | Recipes, craft start/finish/cancel, failure/quality, blueprints, assist, XP, exports |
| `server/database.lua` | Builds the tables (`Config.AutoDatabase`), `CraftingServer.OnReady` |
| `server/stations.lua` | Static and placed stations, proximity check, station sync |
| `server/commands.lua` | Admin commands |
| `server/sv_config.lua`, `server/webhook.lua` | Webhook settings and Discord logs |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI crafting book |
| `installation/shared_items.lua` | Items to add to your items file |
| `install.sql` | Table schema for a manual install |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 2. How it works
- The usable `craftingbook` item opens a draggable NUI (position saved per player).
- Recipes are grouped by category. Locked recipes show the XP needed, with a progress bar to the next unlock.
- Pick a recipe and a batch size (up to `MaxBatch`); time, output and XP scale with quantity.
- Live ingredient counts (have / need) and a max-craftable indicator.
- Optional job or job-type restriction per recipe, and optional tools (e.g. a hammer) that must be in the inventory but are never consumed.
- Crafting continues if you close the book; reopen to watch or press Stop. Dying cancels. Nothing is taken until the craft completes.
- Search box, favourites (stored in the player's browser storage) and a Max quantity button.
- Craft queue: while a craft runs, extra crafts are held by the client and started one at a time; each start goes through the normal server validation. Stop clears the queue.
- Failure chance: each unit rolls `failchance` (lowered by `ReducePerXP`); failed units refund `RefundPercent`% of their ingredients and earn `XPPercent`% XP.
- Quality: recipes with `quality = true` give `info.quality` (`Min` to `Max` by XP, plus `Variance`).
- Blueprints: `blueprint = 'item'` hides a recipe until the item is used; learned recipes are saved per citizenid.
- Stations: `station = 'type'` needs the player within the type's `radius` of a static or placed station of that type.
- Shared crafting: a helper targets a crafting player, cuts `ReductionPercent`% of the remaining time and earns `XPSharePercent`% of the XP if still close at the end.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `BookItem` | `'craftingbook'` | Usable item that opens the UI |
| `XPType` | `'crafting'` | Rep type for `AddRep` / `GetRep` |
| `Image` | `rsg-inventory/html/images/` | Item images |
| `MaxBatch` | `10` | Max of one recipe per craft |
| `ShowLocked` | `true` | Show locked recipes greyed out |
| `Anim` | table | `dict`, `clip`, `flag` |
| `Crafting` | list | Recipes |
| `AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk working while the book is open |
| `PushToTalkControls` | `{ 0x4BC9DABB }` | Controls left enabled while the book is open |
| `AutoDatabase` | `true` | Create tables on start; `false` = import `install.sql` |
| `Queue` | table | `Enabled`, `MaxLength` |
| `Categories` | table | `[category] = { label = locale key, image = item image }` |
| `Failure` | table | `Enabled`, `RefundPercent`, `XPPercent`, `ReducePerXP`, `MinChance` |
| `Quality` | table | `Enabled`, `Min`, `Max`, `XPForMax`, `Variance` |
| `Blueprints` | table | `ShowUnknown` |
| `Stations` | table | `Enabled`, `SpawnDistance`, `MaxPlaced`, `Types`, `Static` |
| `Assist` | table | `Enabled`, `Distance`, `ReductionPercent`, `MaxHelpers`, `XPSharePercent`, `RequireBook`, `Cooldown` |

Recipe fields: `category`, `receive`, `giveamount`, `crafttime` (ms per craft), `requiredxp`, `xpreward`, optional `requiredjob`, `failchance` (0-100), `quality` (bool), `station` (type from `Config.Stations.Types`), `blueprint` (item name, one recipe per blueprint), `ingredients` (`{ item, amount }`, removed) and `requireditems` (tools, not removed). Amounts must be whole numbers.
```lua
{
    category = 'Basics', receive = 'bandage', giveamount = 1,
    crafttime = 10000, requiredxp = 0, xpreward = 1,
    ingredients = { { item = 'resource_cloth', amount = 1 } },
},
```
Webhook URLs are in `server/sv_config.lua`.

## 4. Exports and events
| Name | Side | Notes |
|---|---|---|
| `OpenCraftingBook()` | client export | Open the book |
| `GetPlayerCraftingXP(src)` | server export | |
| `GivePlayerCraftingXP(src, amount)` | server export | |
| `GetCraftingRecipes()` | server export | Copy of `Config.Crafting` |
| `LearnRecipe(src, blueprint)` | server export | Teach a blueprint recipe; returns true when newly learned |
| `ForgetRecipe(src, blueprint)` | server export | Remove a learned recipe |
| `HasLearnedRecipe(src, blueprint)` | server export | |
| `IsNearStation(src, type)` | server export | Whether the player is close to a station of that type |
| `SendCraftingLog(...)` | server export | Webhook log |
| `rsg-crafting:client:openBook` | client event | Open the book |
| `rsg-crafting:server:getRecipes` | callback | Recipes with the player's unlocks |
| `rsg-crafting:server:startCrafting` | callback | `(index, qty)` |
| `rsg-crafting:server:finishCrafting` | callback | `(index)` |
| `rsg-crafting:server:cancelCrafting` | server event | Stop crafting |
| `rsg-crafting:server:getStations` | callback | Static + placed stations for the client |
| `rsg-crafting:server:assist` | server event | `(targetServerId)` help a crafting player |
| `rsg-crafting:server:createStation` | server event | `(type, coords, rotation)` admin only |
| `rsg-crafting:client:assisted` | client event | New total craft time after a helper joined |
| `rsg-crafting:client:assistAnim` | client event | Helper animation time (ms) |
| `rsg-crafting:client:setStations` / `addStation` / `removeStation` | client events | Station sync |
| `rsg-crafting:client:placeStation` | client event | Starts station placement for an admin |

Commands (all need the `admin` permission):
| Command | Description |
|---|---|
| `/craftingxp [id] [amount]` | Give crafting XP; a negative amount takes XP away (max 100000) |
| `/craftingrecipe [id] [blueprint] [remove]` | Teach, or with `remove` take away, a blueprint recipe |
| `/craftstation [type]` | Place a crafting station (gizmo for prop stations, your position otherwise) |
| `/removecraftstation` | Remove the nearest placed station within 3 metres |

## 5. Security
Fully server-authoritative: the server picks the recipe, validates timing, removes ingredients, gives items and XP, and refunds if anything fails. The client only sends a recipe index and quantity.

- Quantity is checked for NaN, range and whole numbers; recipe config is validated on start.
- Failure rolls, quality, blueprint ownership and station distance are decided on the server. Station distance is checked when a craft starts and again when it finishes (with a few metres of slack).
- The queue lives on the client but every queued craft is started with a normal `startCrafting` request, so it cannot skip a check.
- `rsg-crafting:server:assist`: checks the helper (player, cooldown, not crafting, book), the target's session, helper count, distance between both players and the time left. Helpers are paid only if still close when the craft completes, and only a share of the recipe XP.
- `rsg-crafting:server:createStation`: needs the `admin` permission, a known type, finite coordinates, `rsg-gizmo:IsPlacementValid` and the `MaxPlaced` limit. Other scripts must not trigger it.
- Admin commands are registered with the `admin` permission.

## 6. How-tos
- Add a recipe: add an entry to `Config.Crafting`; all items must exist in `items.lua`.
- Job-locked recipe: add `requiredjob = 'blacksmith'` (job name or type).
- Give the book: `/giveitem [id] craftingbook 1`.
- Failure/quality on a recipe: add `failchance = 10` and/or `quality = true`; tune `Config.Failure` / `Config.Quality`.
- Blueprint recipe: create an item (e.g. `blueprint_hammer`), set `blueprint = 'blueprint_hammer'` on the recipe, give the item to players. They learn it by using it.
- Station recipe: set `station = 'forge'`, then place stations with `/craftstation forge` (admin) or list them in `Config.Stations.Static`. To use a prop, set `model` on the station type to a model name you have looked up.
- Teach or remove a recipe: `/craftingrecipe [id] [blueprint] [remove]`. Change XP: `/craftingxp [id] [amount]`.
- Translated category tabs: add `Config.Categories.<Name> = { label = 'category_x', image = 'x.png' }` and the `category_x` key to every locale file.

## 7. Troubleshooting
| Problem | Fix |
|---|---|
| Book does nothing | Item name must match `BookItem` |
| Recipe locked | Needs `requiredxp` crafting XP |
| Can't craft | Missing ingredient or required tool |
| No images | Check `Config.Image` |
| Station recipe stays locked | Stand within the type's `radius` of a station; check `/craftstation` ran, or `Config.Stations.Enabled` |
| Station prop does not appear | The `model` name could not be loaded; the console prints it. Remove `model` to use a zone |
| Blueprint recipe missing | Use the blueprint item, or run `/craftingrecipe`; with `Config.Blueprints.ShowUnknown = true` it shows greyed out |
| "database tables" error on start | oxmysql must be running before rsg-crafting; or set `Config.AutoDatabase = false` and import `install.sql` |
| Tools no longer stack | Recipes with `quality = true` give items with different quality values, which do not stack |
| Cannot hear / speak while the book is open | Keep `Config.AllowPushToTalkWhileOpen = true` and check `PushToTalkControls` matches your voice key |

## 8. Database
Created automatically on start (`Config.AutoDatabase`); `install.sql` has the same schema.

| Table | Columns |
|---|---|
| `rsg_crafting_recipes` | `citizenid`, `recipe` (blueprint item name), `learned_at`; primary key (`citizenid`, `recipe`) |
| `rsg_crafting_stations` | `id`, `type`, `x`, `y`, `z`, `rx`, `ry`, `rz` |

## rsg-skills integration

`Config.Skills = { Enabled, Skill, XPScale, SaveChance }`. In `craftRecipe` (the only place items and XP are granted), after the output is added the server calls `AddXP(src, 'crafting', xpreward * XPScale, 'crafting')`, and rolls the `save_chance` perk; on a hit every ingredient is given back (when `CanAddItem` allows it). `GivePlayerCraftingXP` mirrors its XP the same way. Recipes' `requiredxp` still reads the rep value (`Config.XPType`), not rsg-skills. Skipped when rsg-skills is not started.


Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-crafting 3.3.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `oxmysql`, `rsg-target`, `rsg-gizmo`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.BookItem` | `'craftingbook'` | usable item that opens the crafting UI |
| `Config.XPType` | `'crafting'` | rep type used with Player.Functions.AddRep / GetRep |
| `Config.Image` | `'rsg-inventory/html/images/'` | item image path |
| `Config.MaxBatch` | `10` | max of one recipe crafted in a single go (time scales with qty) |
| `Config.ShowLocked` | `true` | show locked recipes (greyed out with the XP needed) |
| `Config.Anim` | `table` | animation played while crafting |
| `Config.Crafting` | `table` |  |
| `Config.AllowPushToTalkWhileOpen` | `true` | keep push-to-talk working while the book is open |
| `Config.PushToTalkControls` | `table` | controls left enabled while the book is open |
| `Config.AutoDatabase` | `true` | build the database tables on start |
| `Config.Queue` | `table` | craft queue |
| `Config.Categories` | `table` | category tab names and icons |
| `Config.Failure` | `table` | failure chance settings |
| `Config.Quality` | `table` | crafted item quality settings |
| `Config.Blueprints` | `table` | recipe discovery settings |
| `Config.Stations` | `table` | crafting stations |
| `Config.Assist` | `table` | shared crafting |
| `Config.Skills` | `table` | The crafting XP above keeps working; this also awards XP to the shared rsg-skills skill (`Enabled`, `Skill`, `XPScale`, `SaveChance`, `SpeedBonus`). |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `GetPlayerCraftingXP` | `src` | `server/server.lua` |
| `GivePlayerCraftingXP` | `src, amount` | `server/server.lua` |
| `GetCraftingRecipes` | `` | `server/server.lua` |
| `LearnRecipe` | `src, key` | `server/server.lua` |
| `ForgetRecipe` | `src, key` | `server/server.lua` |
| `HasLearnedRecipe` | `src, key` | `server/server.lua` |
| `IsNearStation` | `src, stationType` | `server/stations.lua` |
| `SendCraftingLog` | `` | `server/webhook.lua` |

**Client**

| Export | Arguments | File |
|---|---|---|
| `OpenCraftingBook` | `` | `client/client.lua` |

```lua
-- example
local result = exports['rsg-crafting']:GetPlayerCraftingXP(src)
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-crafting:server:getRecipes` | server | `src, cb` | `server/server.lua` |
| `rsg-crafting:server:startCrafting` | server | `src, cb, index, qty` | `server/server.lua` |
| `rsg-crafting:server:finishCrafting` | server | `src, cb, index` | `server/server.lua` |
| `rsg-crafting:server:getStations` | server | `src, cb` | `server/stations.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-crafting:server:getRecipes', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-crafting:client:openBook` | client | `` | `client/client.lua` |
| `rsg-crafting:server:cancelCrafting` | server | `` | `server/server.lua` |
| `rsg-crafting:server:assist` | server | `targetServerId` | `server/server.lua` |
| `rsg-crafting:server:createStation` | server | `stationType, coords, rotation` | `server/stations.lua` |
| `rsg-crafting:client:assisted` | client | `duration` | `client/client.lua` |
| `rsg-crafting:client:assistAnim` | client | `ms` | `client/client.lua` |
| `rsg-crafting:client:setStations` | client | `list` | `client/stations.lua` |
| `rsg-crafting:client:addStation` | client | `station` | `client/stations.lua` |
| `rsg-crafting:client:removeStation` | client | `id` | `client/stations.lua` |
| `rsg-crafting:client:placeStation` | client | `stationType` | `client/stations.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-crafting:server:cancelCrafting')
-- from a server script
TriggerClientEvent('rsg-crafting:client:openBook', source)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
