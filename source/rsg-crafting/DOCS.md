# rsg-crafting – Docs (v3.2.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Exports and events
5. Security
6. Server owner how-tos
7. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory` |
| `shared/config.lua` | Book item, XP, animation, recipes |
| `client/client.lua` | NUI bridge, crafting animation |
| `server/server.lua` | Recipes, craft start/finish/cancel, XP, exports |
| `server/sv_config.lua`, `server/webhook.lua` | Webhook settings and Discord logs |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI crafting book |
| `installation/shared_items.lua` | Items to add to your items file |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 2. How it works
- The usable `craftingbook` item opens a draggable NUI (position saved per player).
- Recipes are grouped by category. Locked recipes show the XP needed, with a progress bar to the next unlock.
- Pick a recipe and a batch size (up to `MaxBatch`); time, output and XP scale with quantity.
- Live ingredient counts (have / need) and a max-craftable indicator.
- Optional job or job-type restriction per recipe, and optional tools (e.g. a hammer) that must be in the inventory but are never consumed.
- Crafting continues if you close the book; reopen to watch or press Stop. Dying cancels. Nothing is taken until the craft completes.

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

Recipe fields: `category`, `receive`, `giveamount`, `crafttime` (ms per craft), `requiredxp`, `xpreward`, optional `requiredjob`, `ingredients` (`{ item, amount }`, removed) and `requireditems` (tools, not removed).
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
| `SendCraftingLog(...)` | server export | Webhook log |
| `rsg-crafting:client:openBook` | client event | Open the book |
| `rsg-crafting:server:getRecipes` | callback | Recipes with the player's unlocks |
| `rsg-crafting:server:startCrafting` | callback | `(index, qty)` |
| `rsg-crafting:server:finishCrafting` | callback | `(index)` |
| `rsg-crafting:server:cancelCrafting` | server event | Stop crafting |

## 5. Security
Fully server-authoritative: the server picks the recipe, validates timing, removes ingredients, gives items and XP, and refunds if anything fails. The client only sends a recipe index and quantity.

## 6. How-tos
- Add a recipe: add an entry to `Config.Crafting`; all items must exist in `items.lua`.
- Job-locked recipe: add `requiredjob = 'blacksmith'` (job name or type).
- Give the book: `/giveitem [id] craftingbook 1`.

## 7. Troubleshooting
| Problem | Fix |
|---|---|
| Book does nothing | Item name must match `BookItem` |
| Recipe locked | Needs `requiredxp` crafting XP |
| Can't craft | Missing ingredient or required tool |
| No images | Check `Config.Image` |

## rsg-skills integration

`Config.Skills = { Enabled, Skill, XPScale, SaveChance }`. In `craftRecipe` (the only place items and XP are granted), after the output is added the server calls `AddXP(src, 'crafting', xpreward * XPScale, 'crafting')`, and rolls the `save_chance` perk; on a hit every ingredient is given back (when `CanAddItem` allows it). `GivePlayerCraftingXP` mirrors its XP the same way. Recipes' `requiredxp` still reads the rep value (`Config.XPType`), not rsg-skills. Skipped when rsg-skills is not started.


Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-crafting 3.2.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`

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
| `Config.Skills` | `table` | The crafting XP above keeps working; this also awards XP to the shared rsg-skills skill. |
| `Config.Enabled` | `true` |  |
| `Config.Skill` | `'crafting'` |  |
| `Config.XPScale` | `5` |  |
| `Config.SaveChance` | `true` |  |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `GetPlayerCraftingXP` | `src` | `server/server.lua` |
| `GivePlayerCraftingXP` | `src, amount` | `server/server.lua` |
| `GetCraftingRecipes` | `` | `server/server.lua` |
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

```lua
-- from a client script
TriggerServerEvent('rsg-crafting:server:cancelCrafting')
-- from a server script
TriggerClientEvent('rsg-crafting:client:openBook', source)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
