# rsg-crafting

An XP-based crafting book for **RSG-Core (RedM)**. Players use a crafting book item to open a NUI menu. From there they pick a recipe and a batch size, then craft it while an animation plays. They earn crafting XP that unlocks more recipes.

## Features
- Usable `craftingbook` item opens a draggable NUI (position saved per player, double-click header or ↺ to reset)
- Recipe categories, locked recipes shown with the XP needed, and a progress bar to the next unlock
- Batch crafting (up to `Config.MaxBatch`); time, output and XP scale with quantity
- Live ingredient counts (have / need) and max-craftable indicator
- Optional job / job-type restriction per recipe
- Optional required tools per recipe (e.g. a hammer) that must be in the inventory but are never consumed
- Cancel at any time (Stop button, closing the book, or dying). Nothing is taken until the craft completes
- Fully server-authoritative: the server picks the recipe, validates timing, removes ingredients, gives items and XP, and refunds if anything fails
- ox_lib notifications and locales (`locales/*.json`)
- Discord webhook logging with per-type channels, a rate-limited queue and optional rsg-log mirroring

## Dependencies
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [ox_lib](https://github.com/overextended/ox_lib)

## Installation
1. Drop `rsg-crafting` into your resources folder.
2. Add the items from `installation/shared_items.lua` to `rsg-core/shared/items.lua` (skip any that already exist).
3. Copy the images from `installation/images/` to `rsg-inventory/html/images/`.
4. Add `ensure rsg-crafting` to your server.cfg **after** rsg-core, rsg-inventory and ox_lib.
5. Restart the server.

## Configuration (`shared/config.lua`)
| Option | Description |
|---|---|
| `Config.BookItem` | Usable item that opens the book |
| `Config.XPType` | Rep type used with `AddRep` / `GetRep` |
| `Config.Image` | NUI image path for item icons |
| `Config.MaxBatch` | Maximum quantity per craft |
| `Config.ShowLocked` | Show recipes the player hasn't unlocked yet |
| `Config.Anim` | Animation dict / clip / flag while crafting |

### Adding a recipe
```lua
{
    category = 'Tools',
    receive = 'pickaxe', giveamount = 1,   -- item & amount given per craft
    crafttime = 30000,                     -- ms per craft
    requiredxp = 25, xpreward = 3,         -- XP to unlock / XP earned per craft
    requiredjob = 'blacksmith',            -- optional: job name or job type
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
exports['rsg-crafting']:SendCraftingLog(type, title, desc, src?, fields?)
```

## Locales
All player-facing, UI and Discord log text lives in `locales/*.json` (ox_lib). Included languages:
`en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

Set the language in server.cfg, e.g. `setr ox:locale de`. To add another language, copy `en.json`, translate the values and keep every `%s` placeholder. Recipe `category` names come from `shared/config.lua`, so rename them there.

## Security notes
- The client only sends a recipe index and a quantity. Both are re-validated on the server.
- One active session per player. The finish request is rejected if it arrives sooner than the craft time minus a 1.5s latency grace.
- Book ownership, job, XP and required tools are checked again when the craft finishes.
- Ingredients are removed and the result added only on the server. Removed items are refunded if any step fails.
