# rsg-loyalty: Developer Docs

## Contents
1. [Overview and files](#overview-and-files)
2. [Earning](#earning)
3. [Tiers, daily bonus and boost](#tiers-daily-bonus-and-boost)
4. [Rewards and redemption](#rewards-and-redemption)
5. [Activities](#activities)
6. [Exports](#exports)
7. [Events](#events)
8. [Security model](#security-model)
9. [Database](#database)
10. [NUI and push-to-talk](#nui-and-push-to-talk)
11. [Locales and notifications](#locales-and-notifications)
12. [Troubleshooting](#troubleshooting)
13. [Changelog](#changelog)

## Overview and files

Dependencies: rsg-core (locales, notify, model loading, `points.lua`), rsg-target, rsg-inventory, oxmysql. No ox_lib.

| File | Purpose |
|---|---|
| `shared/config.lua` | All settings, reward catalogs, tiers and NPC locations (loaded by clients too) |
| `server/config.lua` | Server-only: Discord webhook URL |
| `server/server.lua` | Database, sessions, earning, tiers, daily bonus, boost, redemption, history, admin, exports |
| `server/discord.lua` | Webhook logging (batched points-earned) and scheduled leaderboard |
| `server/versionchecker.lua` | Checks the GitHub version file on start |
| `client/client.lua` | Session start, NUI open/close, push-to-talk whitelist |
| `client/npcs.lua` | Distance-based NPC spawning, blips, rsg-target option |
| `web/` | NUI: tier card, five tabs (cash, items, specials, leaderboard, history) |
| `installation/rsg_loyalty.sql` | Manual table install |

## Earning

One server loop runs once a minute. For each active session it checks the player is still the same character, `MinPlaytimeBeforeEarning` has passed, the player moved at least `MinMoveDistance` (when `RequireMovement` is on) and `MaxPointsPerSession` is not reached. Points = `PointsPerMinute` x tier `earnMultiplier` x active boost, rounded, minimum 1, then capped by the session limit. If the new balance crosses a reward the player can redeem, they get a "You can now afford" notification.

## Tiers, daily bonus and boost

- **Tiers** come from lifetime points (`Config.Tiers`, sorted lowest first). A tier gives `discount` (% off every reward, minimum cost 1) and `earnMultiplier` (passive and activity points).
- **Daily bonus** is claimed when a character starts a session. One SQL statement checks the date and awards the points, so it can never be claimed twice. The streak continues if the last claim was yesterday, otherwise it restarts at 1. Amount = `BasePoints + (streak - 1) * PerStreakDay`, capped at `MaxPoints`, plus `Milestones[streak]`.
- **Boost** (`/loyaltyboost [multiplier] [minutes]`, or the `setLoyaltyBoost` export) multiplies passive and activity points for everyone until it expires. It is held in memory, so a restart clears it. Limits come from `Config.Boost`.

## Rewards and redemption

Reward lists: `Config.CashRewards`, `Config.ItemRewards`, `Config.SpecialRewards`. The client sends `'cash' | 'item' | 'special'` and an index to `rsg-loyalty:server:redeem`. The server then:

1. Checks the player, the 2 second cooldown and the distance to a loyalty NPC.
2. Finds the reward in config. Specials must be active this period.
3. Checks tier and job requirements, and (items) that the item exists and fits (`CanAddItem`).
4. Works out the cost with the tier discount.
5. Takes the points. For rewards with `stock` or `limit` it first takes a per-reward lock, counts earlier redemptions in the period, then removes points and records the redemption, so the last item cannot be taken twice.
6. Gives the reward. If that fails, points are refunded (lifetime untouched) and the redemption row is deleted.

**Rotating specials:** entries with `rotating = true` form a pool; `Config.Rotation.Count` of them are active per `Period`. The pick is seeded by the period number, so every player sees the same set and nothing is stored. Entries with `rotating = false` are always active.

**Custom rewards:** `type = 'custom'` with `export = { resource, func }` and optional `args`. The server calls `exports[resource][func](resource_exports, source, unpack(args))`. The resource must be started. A thrown error or a return value of exactly `false` refunds the points; anything else counts as given. Write the target export so it is all-or-nothing: if it hands something out and then errors, the player gets the reward and the refund.

**Stock and limit ids:** tracking uses the reward `id` (default `type_index`). Set an explicit `id` on any reward with `stock` or `limit` so reordering the config keeps its history.

## Activities

Other resources award points for gameplay:

```lua
-- in your hunting script (server side)
exports['rsg-loyalty']:awardActivity(source, 'hunting')
```

The calling resource must be in `Config.Exports.AllowedResources`. `Config.Activities[name]` sets `points`, `cooldown` (seconds, per player) and `dailyCap` (max points per player per day for that activity, counted from the history table after multipliers). Tier multiplier and boost apply. Returns `ok, points`.

## Exports

All server side.

| Export | Returns | Notes |
|---|---|---|
| `getLoyaltyPoints(citizenid)` | number | Current points |
| `getLifetimeLoyaltyPoints(citizenid)` | number | Lifetime points |
| `getLoyaltyTier(citizenid)` | table | `{ index, key, discount, earnMultiplier }` |
| `addLoyaltyPoints(citizenid, points)` | boolean | Restricted. Whole number 1 to 2,000,000,000. Logged to history |
| `removeLoyaltyPoints(citizenid, points)` | boolean | Restricted. False if too few points |
| `awardActivity(source, activity)` | ok, points | Restricted. See Activities |
| `setLoyaltyBoost(multiplier, minutes)` | boolean | Restricted. Multiplier of 1 or less clears the boost |

An admin menu such as rsg-adminmenu can use `setLoyaltyBoost`, `getLoyaltyTier` and the `rsg-loyalty:server:adminAwardPoints` event to add a loyalty page.

## Events

| Event | Side | Purpose |
|---|---|---|
| `rsg-loyalty:server:playerLoaded` | server | Client starts a session; runs the daily bonus (rate limited) |
| `rsg-loyalty:server:getStore` | server | Refresh totals, tier, per-reward cost, locks and stock (rate limited) |
| `rsg-loyalty:server:getLeaderboard` | server | Top 10 lists (rate limited, cached 30 s) |
| `rsg-loyalty:server:getHistory` | server | Recent history (rate limited) |
| `rsg-loyalty:server:redeem` | server | Redeem a reward |
| `rsg-loyalty:server:adminAwardPoints` | server | For admin menus. Admin permission required |
| `rsg-loyalty:client:openloyaltyUI` | client | Open the menu (optional origin `vector3` for the distance check) |
| `rsg-loyalty:client:updateLoyaltyData` | client | Points, tier, streak, boost |
| `rsg-loyalty:client:storeState` | client | Per-reward state and rotation timer |
| `rsg-loyalty:client:leaderboardData` | client | Leaderboard lists |
| `rsg-loyalty:client:historyData` | client | History rows |

## Security model

- Every net event resolves the player, validates arguments and is rate limited.
- Points, prices, discounts, stock and requirements come only from server config and the database. Earning has no client trigger.
- Distance to a store is checked with the server-side ped position.
- Spending is one atomic SQL update; stock and limits are checked under a per-reward lock.
- Admin actions need `admin` permission through rsg-core. Mutation exports are closed by default.
- Job requirements use the player's active job.
- Shared config (including `Config.Exports` and `Config.Discord` switches) is readable by clients. The webhook URL is server-only.

## Database

| Table | Purpose |
|---|---|
| `rsg_loyalty` | One row per character: points, lifetime points, `daily_streak`, `last_daily` |
| `rsg_loyalty_history` | Point changes (daily, activity, redeem, admin, export). Old rows deleted after `History.KeepDays` |
| `rsg_loyalty_redemptions` | One row per redemption of a reward with `stock` or `limit` |

With `Config.AutoDatabase = true` the tables are created and 3.0.x installs get the two new columns automatically. With it false, import `installation/rsg_loyalty.sql`; upgrading by hand also needs the two `ALTER TABLE` lines at the bottom of that file. Passive playtime points are not written to history (one row per player per minute would be too much).

## NUI and push-to-talk

Focus is set through one helper. With `Config.AllowPushToTalkWhileOpen = true` the menu uses `SetNuiFocusKeepInput(true)` and a per-frame whitelist disables all game controls except `Config.PushToTalkControls`. The menu closes when the player dies, leaves `MaxRedeemDistance`, logs out or the resource stops. Countdowns (boost, rotation) tick live while it is open.

## Locales and notifications

Locales load through `@rsg-core/shared/locale.lua` from `locales/*.json` (en, de, el, es, fr, ja, nl, pl, pt-br, ro; same keys in every file). Set the language with `setr rsg:locale <code>`. Reward labels, tier labels and blip names in config are locale keys. When you add a reward or tier, add its key to all 10 files. Notifications use `RSGCore:Client:Notify`.

## Troubleshooting

| Problem | Check |
|---|---|
| No points | `EnableEarning`, `MinPlaytimeBeforeEarning`, `RequireMovement` (player must move), session cap |
| Reward shows a lock | Tier or job requirement; the card says which |
| "Sold out" / "Limit reached" | `stock` / `limit` within the `period`; set `period` for a rolling reset |
| Special missing | Rotating specials show only `Rotation.Count` at a time; check the "Rotates in" timer |
| Custom reward fails | Target resource must be started and export a function that does not return `false` |
| Activity gives nothing | Calling resource in `AllowedResources`; activity name in `Config.Activities`; cooldown or `dailyCap` reached |
| Table errors on start | Set `Config.AutoDatabase = false` and import the SQL file |
| Webhook silent | URL in `server/config.lua`, `EnableWebhooks`, event enabled in `LogEvents` (points earned arrive every `PointsBatchMinutes`) |
| Voice cut while menu is open | `Config.AllowPushToTalkWhileOpen = true` and check `PushToTalkControls` |

## Changelog

**3.1.0**
- Tiers with reward discounts and earn multipliers, daily login bonus with streak, admin boost events
- Activity points export, history tab, "you can now afford" notification
- Reward stock, per-player limits, tier and job requirements; specials tab with weekly rotation and custom (export) rewards
- Points-earned Discord logs sent as one batch summary
- New exports: `getLoyaltyTier`, `awardActivity`, `setLoyaltyBoost`; add/remove exports now write history
- New tables `rsg_loyalty_history` and `rsg_loyalty_redemptions`; `rsg_loyalty` gains `daily_streak` and `last_daily`
- Removed event `rsg-loyalty:server:getLoyaltyData` (replaced by `getStore`)
- Server-side earning, `Config.AutoDatabase`, fixed SQL file, push-to-talk whitelist, menu closes on death, UTF-8 safe names, capped export amounts

Support: https://rexshack.tebex.store
