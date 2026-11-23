# rsg-crafting

An XP-based crafting book for **RSG-Core (RedM)**. Players use a crafting book item to open a NUI menu. From there they pick a recipe and a batch size, then craft it while an animation plays. They earn crafting XP that unlocks more recipes.

## Features
- Usable `craftingbook` item opens a draggable NUI (position saved per player, double-click header or ↺ to reset)
- Recipe categories, locked recipes shown with the XP needed, and a progress bar to the next unlock
- Batch crafting (up to `Config.MaxBatch`); time, output and XP scale with quantity
- Live ingredient counts (have / need) and max-craftable indicator
- Optional job / job-type restriction per recipe
- Optional required tools per recipe (e.g. a hammer) that must be in the inventory but are never consumed
- Crafting keeps going in the background if you close the book; reopen it to watch progress or press Stop. Dying also cancels. Nothing is taken until the craft completes
- Fully server-authoritative: the server picks the recipe, validates timing, removes ingredients, gives items and XP, and refunds if anything fails
- rsg-core notifications, callbacks and locales (`locales/*.json`). No ox_lib needed
- Discord webhook logging with per-type channels, a rate-limited queue and optional rsg-log mirroring
- **Search, favourites and a Max button** in the book (favourites are remembered per player)
- **Crafting queue**: line up several crafts that run back to back
- **Category tabs** with icons and translated names
- **Failure chance** per recipe that shrinks as the player gains XP, with partly refunded ingredients
- **Quality**: crafted items get a quality value that rises with crafting XP
- **Blueprints**: recipes that stay hidden until the player uses a blueprint item
- **Crafting stations**: recipes that need a forge, workbench, ... nearby (placed by admins, saved in the database)
- **Shared crafting**: a nearby player can help, shortening the craft and earning XP
- Admin commands for XP, recipes and stations
- Push-to-talk keeps working while the book is open

## Dependencies
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [oxmysql](https://github.com/overextended/oxmysql)
- [rsg-target](https://github.com/Rexshack-RedM/rsg-target) (stations and shared crafting)
- [rsg-gizmo](https://github.com/Rexshack-RedM/rsg-gizmo) (placing prop stations)
- Optional: rsg-skills (XP mirroring, `save_chance` and `speed_bonus` perks), rsg-log

## Installation
1. Drop `rsg-crafting` into your resources folder.
2. Add the items from `installation/shared_items.lua` to `rsg-core/shared/items.lua` (skip any that already exist).
3. Copy the images from `installation/images/` to `rsg-inventory/html/images/`.
4. Add `ensure rsg-crafting` to your server.cfg **after** rsg-core, rsg-inventory, oxmysql, rsg-target and rsg-gizmo.
5. Restart the server. The database tables are created automatically on first start. To install them by hand, set `Config.AutoDatabase = false` and import `install.sql`.

## Configuration (`shared/config.lua`)
| Option | Description |
|---|---|
| `Config.BookItem` | Usable item that opens the book |
| `Config.XPType` | Rep type used with `AddRep` / `GetRep` |
| `Config.Image` | NUI image path for item icons |
| `Config.MaxBatch` | Maximum quantity per craft |
| `Config.ShowLocked` | Show recipes the player hasn't unlocked yet |
| `Config.Anim` | Animation dict / clip / flag while crafting |
| `Config.AllowPushToTalkWhileOpen` | Keep push-to-talk usable while the book is open (other controls stay blocked) |
| `Config.PushToTalkControls` | Control hashes that stay enabled while the book is open |
| `Config.AutoDatabase` | Create the tables on start (`false` = import `install.sql` yourself) |
| `Config.Queue` | `Enabled`, `MaxLength` of the craft queue |
| `Config.Categories` | Per category: `label` (locale key) and `image` (item image used as tab icon) |
| `Config.Failure` | `Enabled`, `RefundPercent`, `XPPercent`, `ReducePerXP`, `MinChance` |
| `Config.Quality` | `Enabled`, `Min`, `Max`, `XPForMax`, `Variance` |
| `Config.Blueprints` | `ShowUnknown`: show unlearned blueprint recipes greyed out instead of hiding them |
| `Config.Stations` | `Enabled`, `SpawnDistance`, `MaxPlaced`, `Types`, `Static` |
| `Config.Assist` | `Enabled`, `Distance`, `ReductionPercent`, `MaxHelpers`, `XPSharePercent`, `RequireBook`, `Cooldown` |
| `Config.Skills` | rsg-skills: `Enabled`, `Skill`, `XPScale`, `SaveChance`, `SpeedBonus` |

### Adding a recipe
```lua
{
    category = 'Tools',
    receive = 'pickaxe', giveamount = 1,   -- item & amount given per craft
    crafttime = 30000,                     -- ms per craft
    requiredxp = 25, xpreward = 3,         -- XP to unlock / XP earned per craft
    requiredjob = 'blacksmith',            -- optional: job name or job type
    failchance = 10,                       -- optional: base % chance for a unit to fail
    quality = true,                        -- optional: crafted item gets a quality value
    station = 'forge',                     -- optional: must stand near a station of this type
    blueprint = 'blueprint_pickaxe',       -- optional: item that teaches the recipe when used
    requireditems = {                      -- optional: tools needed but NOT consumed
        { item = 'hammer' },               -- amount defaults to 1
    },
    ingredients = {
        { item = 'resource_wood', amount = 1 },
        { item = 'resource_steel_bar', amount = 1 },
    },
},
```
Recipes are checked on resource start. Invalid ones are disabled and an error is printed to the console. This covers unknown items, bad amounts, a missing ingredient list, duplicate ingredients or tools, and a tool that is also listed as an ingredient.

## Using the book
- **Search and favourites**: type in the search box to filter recipes; click the star on a recipe to favourite it. A *Favourites* tab appears once you have one. Favourites are stored in the player's own browser storage.
- **Max**: sets the quantity to the most the player can craft (up to `Config.MaxBatch`).
- **Queue**: while a craft runs, the craft button becomes *Add to queue*. Queued crafts start one after another, each one checked by the server when it starts (a craft that can no longer be made is skipped with a message). *Stop Crafting* cancels the running craft and clears the queue. The queue is not saved.
- **Categories**: set `Config.Categories[<category>] = { label = 'locale_key', image = 'item.png' }` for a translated tab name and icon. A category without an entry shows its own name.

## Failure chance and quality
- `failchance` on a recipe is the base % chance that one unit fails. Every unit in a batch is rolled on its own. Each `Config.Failure.ReducePerXP` crafting XP lowers the chance by one point (never below `MinChance`). The book shows the player's current chance.
- A failed unit uses up its ingredients except `RefundPercent`% (rounded down) and earns `XPPercent`% of the recipe XP. If every unit fails the player gets nothing but the refund.
- `quality = true` on a recipe stores `info.quality` on the crafted item: `Min` at 0 XP up to `Max` at `XPForMax` XP, plus a random spread of `Variance`. For decaying items and weapons rsg-inventory uses it as the condition. Items with different quality do not stack, so only enable it on recipes where that makes sense (tools, weapons).
- With rsg-skills, the `speed_bonus` perk shortens every craft and `save_chance` returns the ingredients of the successful units.

## Blueprints
Give a recipe `blueprint = 'item_name'` (the item must exist). The recipe stays hidden until a player uses that item: the item is consumed and the recipe is saved for the character in `rsg_crafting_recipes`. Each blueprint teaches one recipe. Admins can grant or remove a recipe with `/craftingrecipe`, and other scripts with the `LearnRecipe` / `ForgetRecipe` exports.

## Crafting stations
A recipe with `station = 'forge'` can only be crafted when the player stands within the station type's `radius` of a station of that type (checked by the server when the craft starts and again when it finishes). The book shows the station and greys the craft button when the player is not close enough. With `Config.Stations.Enabled = false` the station requirement is ignored.

- Station types live in `Config.Stations.Types` (`label` locale key, `radius`, optional `model`, `icon`, `zoneRadius`).
- `model = nil` makes an invisible rsg-target zone. Set `model` to a prop name to spawn that prop instead (the prop name must exist in the game; look it up, don't guess).
- **Static** stations are listed in `Config.Stations.Static` (`{ type = 'forge', coords = vector3(...), heading = 0.0 }`).
- **Placed** stations are created in game with `/craftstation <type>` (rsg-gizmo for prop stations, your position for zone stations) and saved in `rsg_crafting_stations`. `/removecraftstation` removes the nearest one within 3 metres.
- Players use a station through rsg-target (*Use the Forge*), which opens the crafting book.

## Shared crafting
While a player crafts, a nearby player who has a crafting book can target them and choose *Help craft*. Each helper removes `ReductionPercent`% of the time that is left (up to `MaxHelpers`), and plays the crafting animation. When the craft finishes, every helper who stayed close earns `XPSharePercent`% of the recipe XP. A helper can help again after `Cooldown` seconds.

## Commands (admin)
| Command | Description |
|---|---|
| `/craftingxp [id] [amount]` | Give crafting XP (a negative amount takes XP away) |
| `/craftingrecipe [id] [blueprint] [remove]` | Teach (or with `remove`, take away) a blueprint recipe |
| `/craftstation [type]` | Place a crafting station |
| `/removecraftstation` | Remove the nearest placed station |

## Push-to-talk
While the book is open the game's controls are blocked, but push-to-talk keeps working (`Config.AllowPushToTalkWhileOpen`, `Config.PushToTalkControls`).

## Discord Webhooks (`server/sv_config.lua`)
Webhook URLs are kept in a **server-only** config file, so clients can never read them. Paste a URL into each log type you want. Leave a type as `''` to turn it off, or use the same URL for every type.

| Type | Sent when |
|---|---|
| `craft` | A craft completes (item, amount, XP earned, total XP, ingredients used) |
| `failed` | A craft fails after the timer, e.g. inventory full or ingredients gone (ingredients are refunded) |
| `cancelled` | A player stops a craft (can be noisy) |
| `suspicious` | A craft finishes faster than allowed, or a finish request has no matching session. Can ping a role via `SuspiciousMention` |
| `xp` | XP is granted through the `GivePlayerCraftingXP` export (logs which resource called it) |

Each embed includes the character name, citizen ID, server ID, Steam name and, optionally, license, Discord and Steam identifiers. Requests are queued per URL and spaced by `RateLimit`. A 429 response is retried after the `Retry-After` delay. With `UseRsgLog = true`, logs are also sent to rsg-log (except cancelled logs).

Other server resources can reuse the logger:
```lua
exports['rsg-crafting']:SendCraftingLog('craft', 'Title', 'Description', src, {
    { name = 'Field', value = 'Value' },
})
```

## Exports
**Client**
```lua
exports['rsg-crafting']:OpenCraftingBook()        -- still requires the player to own the book
```
**Server**
```lua
exports['rsg-crafting']:GetPlayerCraftingXP(src)          -- number
exports['rsg-crafting']:GivePlayerCraftingXP(src, amount) -- boolean
exports['rsg-crafting']:GetCraftingRecipes()              -- copy of Config.Crafting
exports['rsg-crafting']:LearnRecipe(src, 'blueprint_item')       -- boolean (true when newly learned)
exports['rsg-crafting']:ForgetRecipe(src, 'blueprint_item')      -- boolean
exports['rsg-crafting']:HasLearnedRecipe(src, 'blueprint_item')  -- boolean
exports['rsg-crafting']:IsNearStation(src, 'forge')              -- boolean
exports['rsg-crafting']:SendCraftingLog(type, title, desc, src?, fields?)
```

## Locales
All player-facing, UI and Discord log text lives in `locales/*.json` (loaded by rsg-core). Included languages:
`en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`.

Set the language in server.cfg, e.g. `setr rsg:locale de` (falls back to `ox:locale`, then `en`). To add another language, copy `en.json`, translate the values and keep every `%s` placeholder. Category tab names are translated through `Config.Categories` (add a `category_*` key to every locale file); a category without an entry shows its own name from `shared/config.lua`.

## Security notes
- The client only sends a recipe index and a quantity. Both are re-validated on the server.
- One active session per player. The finish request is rejected if it arrives sooner than the craft time minus a 1.5s latency grace.
- Book ownership, job, XP and required tools are checked again when the craft finishes.
- Ingredients are removed and the result added only on the server. Removed items are refunded if any step fails.
- Failure rolls, quality, blueprints, station distance and helper rewards are all decided on the server. The client's queue only repeats requests that the server validates again.
- Station and recipe commands need the `admin` permission; station placement is re-checked on the server (permission, rsg-gizmo placement check, database).
- A batch quantity that is not a real number (NaN) is rejected.

## Changelog
### 3.3.0
- New: search, favourites and a Max button in the book
- New: craft queue (`Config.Queue`)
- New: category icons and translated category names (`Config.Categories`)
- New: failure chance with partial refunds (`Config.Failure`, recipe `failchance`)
- New: crafted item quality (`Config.Quality`, recipe `quality`)
- New: blueprints / recipe discovery (recipe `blueprint`, `rsg_crafting_recipes` table, `LearnRecipe` / `ForgetRecipe` / `HasLearnedRecipe` exports)
- New: crafting stations (recipe `station`, `Config.Stations`, `/craftstation`, `/removecraftstation`, `rsg_crafting_stations` table)
- New: shared crafting, nearby players can help (`Config.Assist`)
- New: admin commands `/craftingxp` and `/craftingrecipe`
- New: rsg-skills `speed_bonus` perk shortens crafts (`Config.Skills.SpeedBonus`)
- Push-to-talk keeps working while the book is open
- Tables are built automatically (`Config.AutoDatabase`); `install.sql` is provided for manual installs
- Added locale keys to all 11 languages; added `oxmysql`, `rsg-target` and `rsg-gizmo` as dependencies

### 3.2.1
- Server: a NaN batch quantity from a modified client could skip the ingredient and craft-time checks; it is now rejected
- Server: recipe validation also checks `crafttime`, `requiredxp` and `xpreward`, and ingredient, tool and output amounts must be whole numbers (bad recipes are reported on start)
- Server: recipe list function defined before the callback that uses it; duplicated rsg-skills checks merged
- Client: the book can't be opened while dead, and closes (and cancels any craft) when the character unloads
- Client: crafting stops only its own animation instead of clearing every ped task

### 3.2.0
- Optional rsg-skills integration (`Config.Skills`): crafting XP mirrored to the `crafting` skill and the `save_chance` perk.

### 3.1.0
- Removed the ox_lib dependency: notifications, callbacks, locales and anim loading now use rsg-core
- Fixed the Cloth and String recipes using `cotton` instead of `herb_cotton`, which disabled them on start
- Fixed duplicate item pop-ups (rsg-inventory already shows them on add/remove)
- Fixed a double-click race that could start the crafting animation twice
- Closing the book no longer cancels a craft; it finishes in the background and reopening the book shows its progress
- The NUI now closes cleanly if the resource stops while it is open

## rsg-skills integration

Optional. With `rsg-skills` started, crafting XP is also awarded to the shared `crafting` skill (`Config.Skills.XPScale` times the recipe XP), and the skill's `save_chance` perk gives that percent chance a craft does not use up its ingredients. The crafting XP and `requiredxp` gates above keep working as before. Set `Config.Skills.Enabled = false` (or `SaveChance = false`) to turn it off.


Support the Project : https://rexshack.tebex.store/
