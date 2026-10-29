# rsg-hunting

Hunting, trapper and butcher script for the RSG Framework (RedM). Players skin animals for materials, sell those materials to trappers, sell whole carcasses to butchers, and earn **hunting XP** that unlocks level perks and ranks them on a server **leaderboard**.

## Features

### Skinning
- Hooks into the game's native skinning event (no minigame)
- Up to 5 reward items per animal, 90+ animals preconfigured (`Config.Animals`)
- Server-side validation: the client only sends the carcass network id; the server checks it exists, is dead, is close to the player, is skinnable and hasn't been skinned before
- Optional carcass removal after skinning (`Config.DeleteCarcass`)

### Trappers
- 5 trapper NPCs with blips and an NUI sell screen (search, owned-only filter, quantity picker, basket, confirm)
- Stock-based pricing: 1.25x below 50% of `maxStock`, 1.5x below 25%; stock saved to `vendor_stock.json`
- Server validates distance, accepted items, ownership and cooldown, and rolls back if an item removal fails

### Butchers
- 12 butcher NPCs (spawned near the player, fade in/out) with blips, ox_target or prompt interaction
- Sell the carcass you are carrying for cash + meat, scaled by pelt quality (poor / good / perfect)
- The server validates and deletes the carried carcass itself, so sales can't be faked or repeated
- Optional `rsg-log` logging of every sale

### Hunting XP, levels and perks
- XP for every skin and butcher sale (per-animal values, quality multiplier for butcher sales)
- 7 configurable levels (Greenhorn → Master Hunter) with perks:
  - **Trapper bonus**: % extra on trapper prices (shown in the sell screen)
  - **Butcher bonus**: % extra butcher cash
  - **Extra skin chance**: chance of a second main skinning reward
- Level-up notifications; XP is stored as player rep (`metadata.rep.hunting`), no extra table needed

### Leaderboard
- `/huntingboard` or the **Hunting Leaderboard** option on any trapper
- NUI panel showing your rank, level, progress to next level and perks, plus the top 10 hunters
- **Movable**: drag the header, position remembered; double-click the header to reset
- **Pin** it to keep it on screen while you play (auto-refreshes); run the command again to hide it
- Includes offline players (read from the database, cached for 60s; online players use live values)

### Discord webhooks
- Separate channels for **skinning**, **trapper** sales, **butcher** sales, **level ups**, **security** alerts and **admin** actions
- Rich embeds with character name, server ID, citizen ID and (optionally) license and Discord mention
- Skinning is batched into one summary per player (default every 120s) so busy hunters don't flood the channel
- High-value sales are copied to the security channel; suspicious/rejected requests are alerted with a per-player throttle and an optional role ping
- Queued and rate limited per webhook, with automatic retry when Discord returns 429
- URLs live in the server-only `server/sv_config.lua`, never sent to clients
- `/huntingwebhooktest` (admin) sends a test message to every channel

## Requirements
- `rsg-core`, `rsg-inventory`, `ox_lib`, `ox_target`, `oxmysql`
- `rsg-log` (optional, butcher sale logging)

## Installation
1. Put `rsg-hunting` in your resources folder.
2. Add the items from `installation/shared_items.lua` to your shared items and copy `installation/images/` into your inventory image folder (`Config.Image`).
3. Add to `server.cfg` after its dependencies:
   ```
   ensure rsg-hunting
   ```
4. No SQL is needed.

## Configuration (`config.lua`)

| Setting | Description |
|---|---|
| `Config.DeleteCarcass` | Remove the carcass after skinning |
| `Config.Image` | Item image folder used by the trapper UI |
| `Config.BlipSprite` / `Config.BlipScale` | Trapper blips |
| `Config.Vendors` | Trapper NPCs and the items each buys (`sellPrice`, `maxStock`, `canSell`, `stockBasedPrice`) |
| `Config.HuntingXP` | XP, levels, perks and leaderboard (see below) |
| `Config.Animals` | Skinnable animals: `modelhash`, `skinable`, `rewarditem1`–`rewarditem5` |
| `Config.SellTime` | Butcher sell progress bar (ms) |
| `Config.Poor/Good/PerfectMultiplier` | Butcher cash multipliers by quality (items: 1/2/3) |
| `Config.KeyBind` / `Config.EnableTarget` | Butcher prompt key or ox_target |
| `Config.ServerCooldown` | Per-player reward cooldown (ms) |
| `Config.EnableLogging` + `Config.Webhook*` | Butcher sale logging via rsg-log |
| `Config.DistanceSpawn` / `Config.FadeIn` | Butcher NPC spawn distance and fade |
| `Config.Blip` | Butcher blips |
| `Config.ButcherLocations` | Butcher prompt coords, NPC model and coords |
| `Config.Animal` | Animals the butcher buys: `model`, `rewardmoney`, `rewarditem1`–`rewarditem3` |

### Hunting XP
```lua
Config.HuntingXP = {
    Enabled = true,
    RepName = 'hunting',          -- rep key in player metadata
    DefaultXP = 1,                -- xp for animals not listed in Animals
    Notify = true,
    ButcherXP = true,
    ButcherQualityMultiplier = { poor = 1, good = 2, perfect = 3 },
    Levels = {
        { level = 1, xp = 0, label = 'Greenhorn', perks = { trapperBonus = 0, butcherBonus = 0, extraSkinChance = 0 } },
        -- ...
    },
    Leaderboard = { Command = 'huntingboard', AtTrapper = true, ShowTop = 10, MaxEntries = 500, CacheSeconds = 60 },
    Animals = { [`a_c_bear_01`] = 15, -- ...
    },
}
```
Each level lists its full perk set (perks are not added together).

### Discord webhooks (`server/sv_config.lua`)
Server-only file, so webhook URLs never reach clients.
```lua
SVConfig.Webhooks = {
    Enabled = true,
    BotName = 'RSG Hunting', BotAvatar = '', FooterText = 'rsg-hunting', ServerName = 'My RedM Server',
    ShowIdentifiers = true,      -- license + discord mention in embeds
    MentionOnAlert = '',         -- e.g. '<@&ROLE_ID>' on security alerts
    Channels = {
        skinning = { url = '', colour = 5763719,  enabled = true },
        trapper  = { url = '', colour = 15844367, enabled = true },
        butcher  = { url = '', colour = 15105570, enabled = true },
        levelup  = { url = '', colour = 3447003,  enabled = true },
        security = { url = '', colour = 15548997, enabled = true },
        admin    = { url = '', colour = 9807270,  enabled = true },
    },
    DefaultUrl = '',             -- used by any channel with an empty url
    SkinningBatchSeconds = 120,  -- 0 = one message per skin
    HighValueSale = 75,          -- sales >= this also alert the security channel
    SecurityThrottleSeconds = 60,
}
```
Set one `DefaultUrl` to log everything to a single channel, or give each channel its own URL. `Config.EnableLogging` (rsg-log) still works alongside the webhooks.

## Exports (server)
```lua
exports['rsg-hunting']:AwardHuntingXP(src, amount)   -- give hunting xp (handles level-up notify)
exports['rsg-hunting']:GetHuntingXP(src)             -- current xp
exports['rsg-hunting']:GetHuntingLevel(src)          -- level, label
exports['rsg-hunting']:SendWebhook(channel, { title = '', description = '', src = playerId, fields = {} })
```

## Commands
| Command | Who | Description |
|---|---|---|
| `/huntingboard` | players | Open / close the hunting leaderboard (name set in config) |
| `resetvendorstock` | server console | Reset all trapper stock |
| `/huntingwebhooktest` | admin | Send a test embed to every webhook channel |

## Locales
All text (notifications, menus, prompts, the trapper and leaderboard NUI, and Discord webhook embeds) comes from ox_lib JSON locales in `locales/`.

Included languages: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

The language follows ox_lib's convar, e.g. in `server.cfg`:
```
setr ox:locale de
```
Level titles (`Config.HuntingXP.Levels[].label`), vendor/butcher names and butcher animal names are set in `config.lua`, so translate those there.

## Notes
- Butcher pelt quality is read on the client (the server can't read it); the server still validates the carcass, distance, location and one sale per carcass.
- If the leaderboard stays empty after players earn XP, check that your rsg-core stores rep in `players.metadata` under `rep`.

---
Support: https://buymeacoffee.com/rexshack
