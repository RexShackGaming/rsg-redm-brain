# rsg-loyalty

Loyalty points for RSG Framework (RedM). Players earn points for playing, climb loyalty tiers and spend points at NPC stores on cash, items and weekly specials. Full developer reference: [DOCS.md](DOCS.md).

**Version:** 3.1.0 | **Dependencies:** rsg-core, rsg-target, rsg-inventory, oxmysql (no ox_lib)

## Features

- Passive points per minute, awarded entirely on the server (anti-AFK movement check, session cap, minimum playtime)
- **Tiers** (Bronze, Silver, Gold, Platinum) from lifetime points, with reward discounts and earn multipliers
- **Daily login bonus** with a streak and milestone bonuses
- **Admin boost events**: `/loyaltyboost 2 60` doubles earning for an hour
- **Activity points** for other scripts (hunting, deliveries, bounties...) through one export
- Reward **stock**, **per-player limits**, **tier** and **job** requirements, per day, week or month
- **Specials tab** with rotating weekly rewards and custom rewards that call another resource's export
- **History tab** with your recent point gains and spends
- "You can now afford: ..." notification when you reach a reward
- NPC stores with blips; menu closes if you walk away or die
- Leaderboard (current and lifetime points)
- Admin commands to award, remove and check points
- Discord webhook logging (points earned are sent as one summary per batch) and a scheduled leaderboard post
- Push-to-talk keeps working while the menu is open
- Locales: en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru

## Installation

1. Put `rsg-loyalty` in your resources folder.
2. Add to `server.cfg` after rsg-core, rsg-target, rsg-inventory and oxmysql:
   ```
   ensure rsg-loyalty
   ```
3. Tables are created automatically on first start (and upgraded from 3.0.x). To install by hand, set `Config.AutoDatabase = false` and import `installation/rsg_loyalty.sql`.
4. Optional: set your Discord webhook in `server/config.lua`:
   ```lua
   Config.Discord.WebhookURL = 'YOUR_WEBHOOK_URL'
   ```
5. Optional: choose a language with `setr rsg:locale en` in `server.cfg`.

## Configuration (`shared/config.lua`)

| Option | Default | Description |
|---|---|---|
| `Config.Enabled` | `true` | Master switch. Saved points are kept when off. Restart after changing |
| `Config.AutoDatabase` | `true` | Create/upgrade tables on start. False = import the SQL file yourself |
| `Config.AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk usable while the menu is open |
| `Config.PushToTalkControls` | `{ 0x4BC9DABB }` | Controls left enabled while the menu is open |
| `Config.Loyalty.*` | see file | Earning: `EnableEarning`, `RequireMovement`, `MinMoveDistance`, `MaxRedeemDistance`, `PointsPerMinute`, `MaxPointsPerSession`, `MinPlaytimeBeforeEarning`, `MaxAdminAwardPoints` |
| `Config.Tiers` | 4 tiers | `key`, `label` (locale key), `minLifetime`, `discount` (% off rewards), `earnMultiplier`. Keep sorted lowest first |
| `Config.Daily` | enabled | `BasePoints`, `PerStreakDay`, `MaxPoints`, `Milestones = { [day] = bonus }` |
| `Config.Boost` | 5.0 / 240 | Limits for `/loyaltyboost`: `MaxMultiplier`, `MaxMinutes` |
| `Config.Activities` | 4 examples | Per activity: `points`, `cooldown` (s), `dailyCap` |
| `Config.History` | 20 / 30 | `Rows` shown, `KeepDays` before cleanup |
| `Config.Notify.AffordableReward` | `true` | "You can now afford" notification |
| `Config.Rotation` | 2 / week | `Count` of rotating specials shown, `Period` = `'day'` or `'week'` |
| `Config.CashRewards` / `Config.ItemRewards` / `Config.SpecialRewards` | see file | Reward catalogs. `label` is a locale key |
| `Config.UI.*` | see file | Optional open command, notification length |
| `Config.Exports.*` | closed | Which resources may use the restricted exports |
| `Config.Discord.*` | see file | Webhook switches, `PointsBatchMinutes`, leaderboard schedule |
| `Config.LoyaltyLocations` | 7 towns | NPC model, position, scenario and blip per store |

### Reward options

Any reward (cash, item or special) can have:

| Field | Meaning |
|---|---|
| `minTier = 'gold'` | Tier key from `Config.Tiers` required to redeem |
| `jobs = { 'vallaw' }` | Only players whose active job is listed can redeem |
| `stock = 10` | Total available to all players |
| `limit = 1` | Per player |
| `period = 'week'` | Window for stock and limit: `'day'`, `'week'`, `'month'`; leave out for lifetime |
| `id = 'my_reward'` | Stable id for stock/limit tracking (default is type and position, so set one if you reorder rewards) |

Special rewards add `type = 'cash' | 'item' | 'custom'` and `rotating = true | false`. A `custom` reward calls `exports[resource][func](source, ...args)` on the server; it counts as given unless it errors or returns `false`. See the commented example in the config.

## Commands

| Command | Permission | Description |
|---|---|---|
| `/loyalty` | everyone | Open the menu anywhere (only if `Config.UI.EnableCommand = true`) |
| `/awardloyalty [id] [points]` | admin | Award points |
| `/removeloyalty [id] [points]` | admin | Remove points |
| `/checkloyalty [id]` | admin | Show a player's points |
| `/loyaltyboost [multiplier] [minutes]` | admin | Boost earning for everyone. `/loyaltyboost off` cancels |
| `/postleaderboard` | admin | Post the leaderboard to Discord now |

## Exports (server)

```lua
local points   = exports['rsg-loyalty']:getLoyaltyPoints(citizenid)
local lifetime = exports['rsg-loyalty']:getLifetimeLoyaltyPoints(citizenid)
local tier     = exports['rsg-loyalty']:getLoyaltyTier(citizenid)   -- { index, key, discount, earnMultiplier }

-- restricted: the calling resource must be in Config.Exports.AllowedResources
exports['rsg-loyalty']:addLoyaltyPoints(citizenid, 100)
exports['rsg-loyalty']:removeLoyaltyPoints(citizenid, 100)
local ok, points = exports['rsg-loyalty']:awardActivity(source, 'hunting')
exports['rsg-loyalty']:setLoyaltyBoost(2.0, 60)   -- multiplier <= 1 clears the boost
```

## Support

Support: https://rexshack.tebex.store
Buy Me a Coffee: https://buymeacoffee.com/rexshack
