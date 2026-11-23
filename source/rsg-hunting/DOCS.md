# rsg-hunting – Docs (v3.5.0)

Technical documentation for server owners and developers. For a short overview see [README.md](README.md).

## Contents
1. [Overview and requirements](#1-overview-and-requirements)
2. [Files](#2-files)
3. [Installation](#3-installation)
4. [How it works](#4-how-it-works)
5. [Configuration](#5-configuration)
6. [Server exports](#6-server-exports)
7. [Events, callbacks and NUI callbacks](#7-events-callbacks-and-nui-callbacks)
8. [Commands](#8-commands)
9. [Items and item info](#9-items-and-item-info)
10. [Database](#10-database)
11. [Integrations](#11-integrations)
12. [Security model](#12-security-model)
13. [Discord webhooks](#13-discord-webhooks)
14. [Locales](#14-locales)
15. [Server owner how-tos](#15-server-owner-how-tos)
16. [Developer examples](#16-developer-examples)
17. [Troubleshooting](#17-troubleshooting)

## 1. Overview and requirements

rsg-hunting covers the whole hunting loop: skinning, trappers (NUI sell screen), butchers, hunting XP and levels, daily bounties, a weekly leaderboard, pelt quality pricing, trophies, contracts, trapper demand, skill gates, bulk sale bonuses and a hunting journal.

| Needs | Why |
|---|---|
| `rsg-core` | Players, money, locales, notifications, callbacks, rep (hunting XP is stored as player rep) |
| `rsg-inventory` | Items (`AddItem`, `RemoveItem`, `CanAddItem`, `GetItemCount`, `GetInventory`) |
| `rsg-target` | Trapper and butcher NPC interaction |
| `oxmysql` | Weekly leaderboard, journal, contracts |

Optional, each skipped when not started: `rsg-weather` (trapper demand), `rsg-skills`, `rsg-reputation`, `rsg-wagons` (hunting cart bulk bonus), `rsg-log`.

## 2. Files

| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest and load order |
| `config.lua` | All settings, animals, trappers, butchers (shared: client and server both read it) |
| `server/sv_config.lua` | Server-only webhook settings (never sent to clients) |
| `server/database.lua` | Creates the journal and contract tables (`HuntingDB.ready`) |
| `server/webhooks.lua` | Discord webhook queue (`HuntingWebhook`) |
| `server/bounty.lua` | Daily bounties, per butcher region (`HuntingBounty`) |
| `server/xp.lua` | Hunting XP, levels, weekly tables, leaderboard, weekly rewards (`HuntingXP`) |
| `server/journal.lua` | Journal records and the journal tab (`HuntingJournal`) |
| `server/gates.lua` | Skill gates (`HuntingGates`) |
| `server/demand.lua` | Weather and season demand (`HuntingDemand`) |
| `server/contracts.lua` | Trapper contracts (`HuntingContracts`) |
| `server/server.lua` | Skinning rewards (`rsg-hunting:server:giverewards`) |
| `server/vendor.lua` | Trapper selling, stock, contract event |
| `server/butcher.lua` | Carcass selling, bulk bonus (`HuntingBulk`) |
| `server/versionchecker.lua` | GitHub version check |
| `client/nui.lua` | Shared NUI focus manager and push-to-talk whitelist (`HuntingNui`) |
| `client/client.lua` | Skinning hook, trapper blips |
| `client/vendor.lua` | Trapper NPCs (spawned by distance), NUI sell screen |
| `client/butcher.lua`, `client/npcs.lua` | Butcher sale flow, butcher NPCs, prompts and blips |
| `client/leaderboard.lua` | Leaderboard and journal panel |
| `client/main.js` | `DataViewNativeGetEventData` export (reads the skinning event) |
| `html/` | NUI: `index.html`, `style.css`, `script.js` (sell screen), `board.css`, `board.js` (leaderboard) |
| `install.sql` | Manual database install |
| `installation/shared_items.lua`, `installation/images/` | Items and images to add to your server |
| `stream/annesburg.ymap` | Map streaming file |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 3. Installation

1. Put `rsg-hunting` in your resources folder.
2. Add the items from `installation/shared_items.lua` to your shared items (including `hunting_trophy` if you use trophies) and copy `installation/images/` into your inventory image folder (`Config.Image`). Add a `hunting_trophy.png` image.
3. `ensure rsg-hunting` after its dependencies (optional resources first if you use them).
4. The database tables are created automatically on first start. To install by hand set `Config.AutoDatabase = false` and import `install.sql` once.

```cfg
ensure oxmysql
ensure rsg-core
ensure rsg-inventory
ensure rsg-target
ensure rsg-weather
ensure rsg-hunting
```

## 4. How it works

### Skinning
1. The client hooks the game's loot-complete event (`EVENT_LOOT_COMPLETE`, read through the `DataViewNativeGetEventData` export). When the local player finishes skinning a `skinable` animal from `Config.Animals` it sends **only** the carcass network id and the pelt quality (`poor`, `good` or `perfect`) to the server.
2. The server resolves the carcass itself and checks: the player exists, per-player cooldown, the carcass was not skinned before, it is a dead non-player ped, within 6 m of the player, and a skinnable animal. The animal model comes from the entity, never from the client.
3. Skill gate (`Config.Gates`): below the required level the carcass is spent and nothing is paid.
4. Rewards: every `rewarditem1..5` that exists in the shared items, only if all fit (`CanAddItem`). Good and perfect carcasses give items with `info.pelt` set. `extraSkinChance` (level perk) and rsg-skills `extra_yield` can give a second copy of the first item.
5. XP: animal XP x bounty multiplier (bounty of the butcher region nearest to the player) x clean-kill multiplier for perfect pelts.
6. Perfect skin of a trophy animal: trophy item with the configured chance. Then the journal and an active contract are updated.

### Trappers
- Five NPCs (`Config.Vendors`) that spawn within `Config.DistanceSpawn` of the player. Target options: sell, hunting contract, today's bounties, claim weekly reward, hunting leaderboard.
- The NUI sell screen is filled by `rsg-hunting:server:getSellData`; the basket is checked out with `rsg-hunting:server:sellBasket`.
- **Unit price** = `sellPrice` x level perk (`trapperBonus`) x demand multiplier x stock multiplier (1.25 below 50% of `maxStock`, 1.5 below 25%, if `stockBasedPrice`).
- **Pelt quality:** stacks with `info.pelt` are paid `Config.PeltQuality.good` / `.perfect` times the unit price. The best quality is removed from the inventory first, and the sell screen computes the same total.
- Each trapper has its own stock, saved to `vendor_stock.json` (written at most every 5 seconds and on resource stop). Stock decays by `StockDecayPercent` every `StockDecayMinutes` so prices recover.

### Butchers
- Twelve NPCs (`Config.ButcherLocations`) with blips and an rsg-target option (or a prompt if `Config.EnableTarget = false`). Sells the carcass in your arms, or one strapped to your horse (`Config.SellFromHorse`).
- Cash = `rewardmoney` x quality multiplier x (1 + perk bonus + bounty bonus + rsg-skills bonus) x rsg-reputation factor x (1 + bulk bonus). Items = quality multiplier amount of `rewarditem1..3`.
- The server deletes the carcass itself, checks the butcher distance, gates, inventory space and a one-sale-per-carcass list.

### Hunting XP and levels
XP is player rep (`Config.HuntingXP.RepName`). Levels and perks are in `Config.HuntingXP.Levels`; each level lists its full perk set (not cumulative): `trapperBonus` %, `butcherBonus` %, `extraSkinChance` %.

### Daily bounties
Per UTC day `Config.Bounty.Count` animals pay `ButcherBonus` % more at the butcher and give `XPMultiplier` x XP. With `PerRegion = true` each butcher region has its own pick (seed = day + region); a trapper shows the bounties of the nearest butcher region.

### Weekly leaderboard
Weeks start Monday 00:00 UTC. At the start of a new week the top `#Config.HuntingXP.Weekly.Rewards` hunters get a cash reward in `hunting_weekly_rewards`, collected at any trapper (one claim per reward, guarded in SQL).

### Contracts
`Config.Contracts.Pool` entries are filtered by the player's hunting level (and by `TrustClientQuality` for quality contracts). A player has one contract at a time (`hunting_contracts`): skin `need` animals within `Duration` minutes; talk to any trapper to claim (cash + XP) or to see progress; then wait `Cooldown` minutes. A finished contract can still be claimed after it expires.

### Trapper demand
`Config.Demand.Rules` read `GlobalState.rsgWeather.weather` and `GlobalState.rsgSeason.name` (rsg-weather). The highest matching `mult` applies to items whose name contains a `match` part. The trapper shows the live prices and names the active rules (at most once every 5 minutes per player).

### Bulk bonus
Carcasses sold at a butcher within `Config.BulkBonus.WindowSeconds` of each other count as one run. From `MinCarcasses` up, each carcass adds `PerCarcass` % (capped at `Max`). rsg-wagons' hunting cart calls the `GetBulkBonus` export with the load size.

### Journal
Per citizen and animal model: `skinned`, `perfect`, `sold` and `best_sale`. Shown as the "Journal" tab of the leaderboard panel.

## 5. Configuration

All options are in `config.lua`. Text in labels and blip names is plain text; player-facing messages come from `locales/*.json`.

### General

| Option | Default | Description |
|---|---|---|
| `Config.AutoDatabase` | `true` | Create the tables on start. `false` = import `install.sql` yourself |
| `Config.DeleteCarcass` | `false` | Remove the carcass after skinning |
| `Config.Image` | `'rsg-inventory/html/images/'` | Item image folder for the trapper UI |
| `Config.AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk working while an NUI is open |
| `Config.PushToTalkControls` | `{ 0x4BC9DABB }` | Controls left enabled while an NUI is open |
| `Config.BlipSprite` / `Config.BlipScale` | `'blip_shop_animal_trapper'` / `0.2` | Trapper blips |
| `Config.StockDecayMinutes` / `Config.StockDecayPercent` | `30` / `10` | Trapper stock recovery (`0` minutes = never) |
| `Config.DistanceSpawn` | `20.0` | Spawn/despawn distance of butcher and trapper NPCs |
| `Config.FadeIn` | `true` | Fade butcher NPCs in and out |
| `Config.TrustClientQuality` | `true` | Use the pelt quality reported by the client. `false` treats every carcass as poor (cheat-proof, switches off pelt prices, trophies, quality contracts and clean-kill XP) |

### Butcher

| Option | Default | Description |
|---|---|---|
| `Config.SellTime` | `10000` | Sell progress bar (ms) |
| `Config.SellFromHorse` | `true` | Also buy a carcass strapped to your horse |
| `Config.HorseCarcassRange` | `6.0` | Max distance between you, the horse and the carcass |
| `Config.PoorMultiplier` / `GoodMultiplier` / `PerfectMultiplier` | `1` / `2` / `3` | Cash and item multipliers by quality |
| `Config.KeyBind` | `'J'` | Prompt key when `EnableTarget = false` |
| `Config.EnableTarget` | `true` | rsg-target on butcher NPCs instead of prompts |
| `Config.ServerCooldown` | `2000` | Per-player cooldown on skinning and butcher rewards (ms) |
| `Config.EnableLogging` | `true` | Send butcher sales to rsg-log |
| `Config.WebhookName` / `WebhookTitle` / `WebhookColour` | `'rsghunting'` / `'RSG Hunting - Butcher'` / `'default'` | rsg-log entry |
| `Config.Blip` | `{ blipName, blipSprite, blipScale }` | Butcher blips |
| `Config.ButcherLocations` | 12 entries | `name`, `region` (rsg-reputation region id), `prompt`, `coords`, `npcmodel`, `npccoords`, `showblip` |
| `Config.Animal` | list | Butcher prices: `name`, `model`, `rewardmoney`, `rewarditem1..3` |

### Animals and trappers

```lua
-- skinning (Config.Animals): rewards and journal name
{ modelhash = `a_c_deer_01`, name = 'Deer', skinable = true, rewarditem1 = 'resource_skin_deer', rewarditem2 = 'consumable_meat_deer' },

-- trapper (Config.Vendors)
{
    pedModel = 'u_m_m_sdtrapper_01',
    coords = vector4(-333.97, 773.49, 116.22, 111.87),   -- NPC position and heading
    blipname = 'Valentine Trapper', blipcoords = vector3(-333.97, 773.49, 116.22), showblip = true,
    items = {
        { name = 'resource_skin_bear', label = 'Bear Skin', sellPrice = 1.25, maxStock = 100, canSell = true, stockBasedPrice = true },
    },
},
```

### Hunting XP (`Config.HuntingXP`)

| Option | Default | Description |
|---|---|---|
| `Enabled` | `true` | Master switch (levels, perks, gates, leaderboard) |
| `RepName` | `'hunting'` | Rep key in player metadata |
| `DefaultXP` | `1` | XP for a skinnable animal not listed in `Animals` |
| `Notify` | `true` | Show "+X hunting xp" |
| `ButcherXP` / `ButcherQualityMultiplier` | `true` / `{ poor = 1, good = 2, perfect = 3 }` | XP for butcher sales |
| `Levels` | 7 levels | `{ level, xp, label, perks = { trapperBonus, butcherBonus, extraSkinChance } }`, sorted by `xp` |
| `CleanKillMultiplier` | `1.5` | Skinning XP multiplier for perfect pelts (capped at 3) |
| `Weekly` | `{ Enabled = true, Rewards = { 100, 50, 25 }, KeepWeeks = 4 }` | Weekly leaderboard and rewards |
| `Leaderboard` | `{ Command = 'huntingboard', AtTrapper = true, ShowTop = 10, MaxEntries = 500, CacheSeconds = 60 }` | Leaderboard panel (`Command = ''` disables the command) |
| `Animals` | table | `[model] = xp` per animal |

### Bounties (`Config.Bounty`)

| Option | Default | Description |
|---|---|---|
| `Enabled` | `true` | |
| `Count` | `2` | Bounty animals per day (per region when `PerRegion`) |
| `ButcherBonus` | `50` | % extra butcher cash |
| `XPMultiplier` | `2` | XP multiplier for skinning and butcher sales |
| `MinReward` | `3` | Default pool: `Config.Animal` entries paying at least this (legendaries excluded) |
| `Animals` | `{}` | Optional fixed pool `{ { model = -1124266369, label = 'Bear' } }` |
| `PerRegion` | `true` | One pick per butcher region instead of one for the whole map |

### Features added in 3.5.0

```lua
Config.PeltQuality = { Enabled = true, good = 1.15, perfect = 1.40 }          -- trapper price multipliers

Config.Trophies = {
    Enabled = true, Item = 'hunting_trophy', Chance = 25, SellPrice = 10.00,   -- Chance in %, price at every trapper
    Animals = { [`a_c_bear_01`] = true, [`a_c_elk_01`] = true },
}

Config.Contracts = {
    Enabled = true, Duration = 120, Cooldown = 30,                              -- minutes
    Pool = {                                                                    -- need = { min, max }, reward and xp are PER animal
        { model = `a_c_elk_01`, need = { 2, 3 }, reward = 7.0, xp = 5, minLevel = 2, quality = 'good' },
    },
}

Config.Demand = {
    Enabled = true,
    Rules = {                                                                   -- weather and/or season, match = parts of the item name
        { label = 'skins and pelts (cold weather)', weather = { 'snow', 'blizzard' }, match = { 'skin', 'pelt', 'hide' }, mult = 1.20 },
    },
}

Config.Gates = {                                                                -- [model] = { level = hunting level, skill = rsg-skills level (optional) }
    [`a_c_bear_01`] = { level = 4 },
    [-1392359921]   = { level = 7 },                                            -- Legendary Wolf
}

Config.BulkBonus = { Enabled = true, MinCarcasses = 3, PerCarcass = 2, Max = 20, WindowSeconds = 600 }
Config.Journal   = { Enabled = true }
```

| Option | Notes |
|---|---|
| `Config.PeltQuality` | Needs `TrustClientQuality = true` |
| `Config.Trophies.Item` | Must exist in your shared items, otherwise no trophy is given |
| `Config.Contracts.Pool[].quality` | `'good'` or `'perfect'`; omit for any quality. Needs `TrustClientQuality = true` |
| `Config.Demand.Rules[].season` | An rsg-weather seasonal event name (`rsg-weather` `Config.Seasonal.Events`) |
| `Config.Gates[].level` | Ignored while `Config.HuntingXP.Enabled = false` |
| `Config.BulkBonus` | Bonus % = `min(Max, (count - MinCarcasses + 1) * PerCarcass)`, 0 below `MinCarcasses` |

### rsg-skills and rsg-reputation

```lua
Config.Skills = { Enabled = true, Skill = 'hunting', MirrorXP = true, SellBonus = true, ExtraYield = true }
Config.Reputation = { Enabled = true, StandingPerSale = 1, StandingCooldown = 600, PayoutModifier = true, PayoutMin = 0.5, PayoutMax = 1.5 }
```
See [Integrations](#11-integrations).

## 6. Server exports

| Export | Arguments | Returns | Description |
|---|---|---|---|
| `AwardHuntingXP` | `src, amount` | | Give hunting XP (also mirrors to rsg-skills, handles level-up notifications and the weekly total) |
| `GetHuntingXP` | `src` | `number` | Current hunting XP |
| `GetHuntingLevel` | `src` | `level, label` | Current level and its label |
| `GetDailyBounties` | `region?` | `string[]` | Today's bounty animal labels. Without a region (and `PerRegion`) every region's animals |
| `GetBulkBonus` | `count` | `number` | Bulk sale bonus in % for selling `count` carcasses (0 when off) |
| `SendWebhook` | `channel, data` | | Queue a Discord embed (see [webhooks](#13-discord-webhooks)) |

Client export: `DataViewNativeGetEventData(eventGroup, index, argStructSize)` returns the event data as an `Int32Array` (used by the skinning hook; do not call it from other resources).

```lua
-- give XP from another resource (server)
exports['rsg-hunting']:AwardHuntingXP(src, 10)

-- gate your own content on hunting level
local level, label = exports['rsg-hunting']:GetHuntingLevel(src)
if level < 4 then return end

-- today's bounties for the Valentine butcher region
for _, label in ipairs(exports['rsg-hunting']:GetDailyBounties('valentine')) do print(label) end

-- pay a bulk bonus for your own carcass system
local pct = exports['rsg-hunting']:GetBulkBonus(#carcasses)
cash = cash * (1 + pct / 100)
```

## 7. Events, callbacks and NUI callbacks

All server handlers re-validate the player, arguments, distance and cooldown. Callbacks use rsg-core (`RSGCore.Functions.TriggerCallback` / `AwaitCallback`).

### Server events (client to server)

| Event | Arguments | Description |
|---|---|---|
| `rsg-hunting:server:giverewards` | `netId, quality` | Skin rewards for a skinned carcass. `quality` is `'poor'`, `'good'`, `'perfect'` or nil |
| `rsg-hunting:server:contract` | `vendorIndex` | Talk to the trapper about contracts (must be within 6 m of that trapper) |

### Callbacks (client to server)

| Callback | Arguments | Returns |
|---|---|---|
| `rsg-hunting:server:getSellData` | `vendorIndex` | `{ title, items = { { name, label, image, price, owned, good, perfect } }, qualityMult = { good, perfect } }` or nil |
| `rsg-hunting:server:sellBasket` | `vendorIndex, basket` (`{ { name, amount } }`) | `{ ok, payout?, message?, items? }` |
| `rsg-hunting:server:sellCarcass` | `netId, quality` | `true` when sold |
| `rsg-hunting:server:getBounties` | `vendorIndex?` | `string[]` bounty labels for that trapper's region (or the player's region) |
| `rsg-hunting:server:getLeaderboard` | `mode` (`'all'`, `'weekly'`, `'journal'`) | Panel data table or nil |
| `rsg-hunting:server:claimWeekly` | | `{ ok, cash }` |

### Client events

| Event | Description |
|---|---|
| `rsg-hunting:client:butcher:mainmenu` | Start the butcher sale flow (used by the prompt) |

### Client functions (global)

`OpenSellMenu(vendorIndex)`, `ShowDailyBounties(vendorIndex)`, `ClaimWeeklyReward()`, `OpenHuntingLeaderboard()`, `OpenButcherMenu()` and `HuntingNui.Focus(owner, enable)` (shared NUI focus; every NUI opens and closes through it so push-to-talk keeps working).

### NUI callbacks

`close`, `sellBasket` (sell screen) and `boardClose`, `boardMode { mode }`, `boardPin` (leaderboard).

```lua
-- client: read the bounties of trapper 1
local labels = RSGCore.Functions.AwaitCallback('rsg-hunting:server:getBounties', nil, 1)

-- client: ask the server for the journal data
local data = RSGCore.Functions.AwaitCallback('rsg-hunting:server:getLeaderboard', nil, 'journal')
```

## 8. Commands

| Command | Who | Description |
|---|---|---|
| `/huntingboard` | everyone | Open or close the leaderboard (name from `Leaderboard.Command`) |
| `/huntingwebhooktest` | admin | Send a test message to every webhook channel |
| `resetvendorstock` | server console only | Reset all trapper stock |

## 9. Items and item info

- Reward items come from `Config.Animals` and `Config.Animal`; add them from `installation/shared_items.lua`.
- `hunting_trophy`: trophy item, `info.animal` holds the animal name.
- **Pelt quality** is stored as `info.pelt` (`'good'` or `'perfect'`) on skinning rewards. rsg-inventory uses `info.quality` for decay, so a different key is used on purpose. Stacks with different `info` do not merge.

```lua
-- read the pelt quality of every stack of an item (server)
for slot, item in pairs(exports['rsg-inventory']:GetInventory(src)) do
    if item.name == 'resource_skin_bear' then print(slot, item.amount, item.info and item.info.pelt) end
end
```

## 10. Database

`server/database.lua` and `server/xp.lua` create these tables on start (`Config.AutoDatabase = true`); `install.sql` has the same schema. Nothing is ever dropped or altered.

```sql
-- weekly leaderboard
hunting_weekly          (citizenid, week, name, xp)           PRIMARY KEY (citizenid, week), KEY (week, xp)
hunting_weekly_rewards  (id, citizenid, week, rank, cash, claimed)   UNIQUE (citizenid, week)
hunting_weekly_state    (key, value)                           -- 'lastPaidWeek'
-- journal and contracts
hunting_journal         (citizenid, model, skinned, perfect, sold, best_sale)   PRIMARY KEY (citizenid, model)
hunting_contracts       (citizenid, model, need, got, quality, reward, xp, expires, status, claimed_at)   PRIMARY KEY (citizenid)
```

`hunting_contracts.status` is `active`, `claimed` or `expired`. Hunting XP itself is player rep (`players.metadata.rep.<RepName>`); the all-time leaderboard reads it from there. Trapper stock is stored in `vendor_stock.json` in the resource folder.

## 11. Integrations

| Resource | What happens |
|---|---|
| `rsg-skills` | `Config.Skills`: every XP award is mirrored (`AddXP(src, 'hunting', amount, 'hunting', { raw = true })`), `sell_bonus` adds to butcher cash, `extra_yield` adds to the second-reward chance, `Config.Gates[].skill` uses `GetLevel` |
| `rsg-reputation` | `Config.Reputation`: butcher sales earn standing in the butcher's `region`, and the region's price modifier changes the payout (`1 - modifier`, kept between `PayoutMin` and `PayoutMax`, at most one standing gain per player and region per `StandingCooldown` seconds). Honor is never changed |
| `rsg-weather` | `Config.Demand` reads `GlobalState.rsgWeather.weather` and `GlobalState.rsgSeason.name`; no weather resource = no demand changes |
| `rsg-wagons` | The hunting cart calls `GetBulkBonus(#cargo)` when a load is sold |
| `rsg-log` | `Config.EnableLogging` logs butcher sales |

## 12. Security model

- **Never trusted from the client:** prices, rewards, item names, amounts of rewards, coordinates. The client sends a carcass network id (and a quality label), a vendor index and a basket.
- **Skinning:** carcass checked on the server (exists, dead, not a player, within 6 m, known skinnable model, not skinned before, per-player cooldown). Rewards are computed from server config.
- **Selling:** vendor and butcher distance, accepted items per vendor, ownership by stack, amount limits (whole numbers, max 500 per line, max 200 lines), cooldown, rollback if an item removal fails, carcass deleted by the server and remembered so it cannot be sold twice.
- **Contracts, gates, journal:** progress and gates are evaluated on the server from the verified skin payout.
- **Known limit:** the server cannot read pelt quality. A modified client can claim `perfect`, which affects pelt prices, trophies, quality contracts, butcher quality multipliers and clean-kill XP. Set `Config.TrustClientQuality = false` on servers that need this closed.
- Suspicious requests are printed to the console and sent to the `security` webhook channel (throttled).
- All SQL uses `?` parameters.

## 13. Discord webhooks

Settings are in `server/sv_config.lua` (`SVConfig.Webhooks`): `Enabled`, `BotName`, `BotAvatar`, `FooterText`, `ServerName`, `ShowIdentifiers`, `MentionOnAlert`, `Channels` (`skinning`, `trapper`, `butcher`, `levelup`, `security`, `admin`, each `{ url, colour, enabled }`), `DefaultUrl`, `SkinningBatchSeconds`, `HighValueSale`, `SecurityThrottleSeconds`. Requests are queued, rate limited per webhook and retried on 429.

```lua
-- send your own embed from another resource (server)
exports['rsg-hunting']:SendWebhook('trapper', {
    title = 'Custom event',
    description = 'Something happened',
    src = source,                                   -- adds character, player and citizen id fields
    fields = { { name = 'Amount', value = '$10.00', inline = true } },
})
```

## 14. Locales

`locales/<lang>.json`: `en` (master), `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. rsg-core loads them through `@rsg-core/shared/locale.lua`; set the language with `setr rsg:locale "de"`. Every file has the same keys; `%s` and `%d` placeholders keep their order.

```lua
locale('butcher_sold', animalName, qualityLabel, cash)   -- same call on client and server
```

To add a message: add the key to all 11 files (English first), then call `locale('your_key', ...)`. Keys built at runtime: `quality_<poor|good|perfect>`, `contract_q_<good|perfect>`, `butcher_not_holding[_horse]`, `contract_step` / `contract_ready`, `gate_level` / `gate_skill`.

## 15. Server owner how-tos

```lua
-- add a skinnable animal (Config.Animals) with XP, butcher price and a trapper item
{ modelhash = `a_c_fox_01`, name = 'Fox', skinable = true, rewarditem1 = 'resource_pelt_fox' },    -- Config.Animals
[`a_c_fox_01`] = 3,                                                                                 -- Config.HuntingXP.Animals
{ name = 'American Red Fox', model = 252669332, rewardmoney = 5, rewarditem1 = 'raw_meat' },        -- Config.Animal (butcher)

-- add a contract
{ model = `a_c_boar_01`, need = { 2, 4 }, reward = 4.0, xp = 3, minLevel = 1 },                      -- Config.Contracts.Pool

-- add a demand rule (snow raises meat too)
{ label = 'meat (snow)', weather = { 'snow' }, match = { 'meat' }, mult = 1.15 },                    -- Config.Demand.Rules

-- gate an animal behind hunting level 5 and rsg-skills level 3
[`a_c_wolf`] = { level = 5, skill = 3 },                                                             -- Config.Gates
```

- **New trapper or butcher:** copy an entry in `Config.Vendors` / `Config.ButcherLocations`; butchers need a `region` from rsg-reputation's `Config.Regions`. Every trapper automatically buys trophies.
- **Turn features off:** `Config.HuntingXP.Enabled`, `Config.Contracts.Enabled`, `Config.Demand.Enabled`, `Config.PeltQuality.Enabled`, `Config.Trophies.Enabled`, `Config.BulkBonus.Enabled`, `Config.Journal.Enabled`, `Config.Bounty.Enabled`.
- **Reset trapper stock:** type `resetvendorstock` in the server console.
- **Move to a new language:** `setr rsg:locale "pt-br"`.

## 16. Developer examples

```lua
-- server: pay a hunting level reward from your own script
RegisterNetEvent('myres:server:huntingQuest', function()
    local src = source
    local level = exports['rsg-hunting']:GetHuntingLevel(src)
    if level < 3 then return end
    exports['rsg-hunting']:AwardHuntingXP(src, 25)
end)

-- server: sell an item stack at the best pelt quality first (what the trapper does)
local stacks = {}
for slot, it in pairs(exports['rsg-inventory']:GetInventory(src)) do
    if it.name == 'resource_skin_deer' then stacks[#stacks + 1] = { slot = slot, amount = it.amount, pelt = it.info and it.info.pelt } end
end

-- client: open the trapper sell screen from your own target (needs a valid vendor index)
OpenSellMenu(1)
```

## 17. Troubleshooting

| Problem | Fix |
|---|---|
| Nothing from skinning | The model is missing in `Config.Animals`, `skinable = false`, the carcass was skinned before, or the animal needs a higher hunting level (`Config.Gates`) |
| "Inventory full" | All reward items must fit; free space and skin again (the carcass is only used once items are given) |
| Trapper prices low | Stock is full (wait for decay or reset), or no demand rule is active |
| No trophies | `hunting_trophy` is missing in your shared items, the pelt was not perfect, or `Config.Trophies.Chance` rolled low |
| Pelt quality does nothing | `Config.TrustClientQuality` is `false` or `Config.PeltQuality.Enabled` is `false` |
| No contract offered | Your level is below every `minLevel`, the cooldown is running, or `HuntingDB.ready` is false (check the console for the database message) |
| Demand never changes | rsg-weather is not started, or the weather names in `Config.Demand.Rules` do not match the weather names it uses |
| No leaderboard or journal | Check `Leaderboard.Command`, `HuntingXP.Enabled`, `Config.Journal.Enabled` and the console for table creation errors |
| Missing item images | Check `Config.Image` and the image files |
| Trapper NPC missing | NPCs spawn within `Config.DistanceSpawn`; the console prints a message if the ped model fails to load |

Support: https://rexshack.tebex.store
