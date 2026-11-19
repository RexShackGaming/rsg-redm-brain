# rsg-economy developer and server owner documentation

## Contents
- [How it works](#how-it-works)
- [Files](#files)
- [Regions and officials](#regions-and-officials)
- [Taxes](#taxes)
- [Dynamic prices](#dynamic-prices)
- [Quotes](#quotes)
- [Treasury and ledger](#treasury-and-ledger)
- [Projects](#projects)
- [Server exports](#server-exports)
- [Events and callbacks](#events-and-callbacks)
- [Integration examples](#integration-examples)
- [Persistence](#persistence)
- [Commands](#commands)
- [Security model](#security-model)
- [Database schema](#database-schema)
- [Server owner how-tos](#server-owner-how-tos)
- [Troubleshooting](#troubleshooting)

## How it works
Everything is held in memory on the server and saved in batches. Shop scripts call `Quote` to get a price with market movement, reputation and tax applied, move the money themselves, then call `Record` so the tax lands in the town treasury and the market reacts. Officials change rates and spend the treasury through the panel; every request is validated on the server.

Regions are plain ids (`valentine`, ...) chosen by the calling script. The resource does not detect where the player is.

## Files
| File | Purpose |
| --- | --- |
| `shared/config.lua` | All settings: regions and officials, taxes, treasury, market, projects. |
| `server/database.lua` | Table creation, in-memory state, loading, saving, ledger, pruning. |
| `server/economy.lua` | Taxes, treasury, market, quotes, projects, officials, exports. |
| `server/actions.lua` | Panel data and the official / donor actions (callbacks). |
| `server/commands.lua` | Admin commands. |
| `client/ui.lua` | Panel open/close, NUI focus with push-to-talk, forwarding to the server. |
| `html/` | The NUI panel (`index.html`, `style.css`, `script.js`). |
| `locales/*.json` | The 11 languages. |
| `install.sql` | Manual install of the tables. |

## Regions and officials
`Config.Regions[id] = { label, order, officials }`. `officials` is a list of `{ job, minGrade }`. A player is an official of a region when any entry matches either:
- they hold the job (multi-job, `HasPlayerJob`) at a grade of at least `minGrade`, or
- their active job is that job and either `isboss` is true or the grade level is at least `minGrade`.

With `Config.RequireOnDuty = true` the active job must also be on duty. Defaults: each of the five original towns accepts its law job at grade 2 (Sheriff) and every town accepts the `government` job at any grade. Edit the `officials(...)` helper at the top of the config to change this.

## Taxes
Four categories (`Config.Tax.Categories`): `sales` (added to purchases), `trade` (taken from sales to shops), `property` and `license` (for scripts that charge rent, deeds or permits). Each has `default`, `min`, `max` as fractions (`0.05` = 5%). Rates are per region and are only stored once changed. Officials change a rate in steps of `Tax.Step` and each rate can change once per `Tax.ChangeCooldown` seconds. Admin changes through the console or exports ignore the cooldown but still respect `min` and `max`.

## Dynamic prices
Every item has a **pressure** per region between -1 (heavy demand) and +1 (oversupply).
- A sale to a shop adds `qty * perUnit`, a purchase subtracts it. `perUnit` is `Market.PressurePerUnit` (default 0.02) unless the item overrides it.
- Pressure halves every `Market.HalfLifeHours` hours (calculated when read, also while the server is down).
- Multiplier = `1 - pressure * sensitivity`, kept between `min` and `max` (defaults 0.5 and 1.5).
- Entries that have faded below 0.5% pressure are removed.

Per-item overrides: `Config.Market.Items['venison'] = { sensitivity = 0.8, min = 0.4, max = 1.6, perUnit = 0.03 }`.

## Quotes
`Quote(src, opts)` never changes anything; it only computes.

| Option | Description |
| --- | --- |
| `region` | Required. A key of `Config.Regions`. |
| `mode` | `'buy'` (player pays) or `'sell'` (player receives). Default `'buy'`. |
| `base` | Required. Unit base price, a finite number >= 0. |
| `qty` | Whole number 1 to 10000. Default 1. |
| `item` | Item name. Enables the market multiplier and market recording. |
| `category` | Tax category. Default `sales` for buy, `trade` for sell. |
| `market = false` | Skip the market multiplier. |
| `reputation = false` | Skip the reputation modifier. |

Result: `{ region, mode, category, item, qty, base, marketMultiplier, repModifier, unitPrice, subtotal, taxRate, tax, total }`, or `nil` for invalid input.
- `unitPrice = base * marketMultiplier * (1 + repModifier)` for a purchase and `* (1 - repModifier)` for a sale, rounded to 2 decimals. The reputation factor is never below 0.1.
- `subtotal = unitPrice * qty`, `tax = subtotal * taxRate`.
- Buy: `total = subtotal + tax`. Sell: `total = subtotal - tax`.
- The reputation modifier is read from `rsg-reputation`'s `GetPriceModifier(src, region)` when `UseReputation` is on, the resource is started and `src` is given.

`Record(src, quote)` banks `quote.tax` in the treasury (ledger kind `tax`, with the player as actor) and records the trade in the market when `quote.item` is set. Call it only after the money really moved.

## Treasury and ledger
- Balances have two decimals and never go below 0.
- Ledger kinds: `tax`, `deposit`, `withdraw` (official panel withdrawals, counted toward the daily limit), `payout` (script payouts through `WithdrawTreasury`), `project`, `admin`, `tax_rate`.
- Every entry stores amount, balance after, kind, reason, actor and time. Entries older than `Ledger.KeepDays` are deleted. `Ledger.LogTax = false` stops one row per taxed sale.
- Withdrawals through the panel: official only, at most `Treasury.Withdraw.DailyLimit` per region and UTC day across all officials (summed from the ledger, plus withdrawals still in progress), and at most the balance. The lower balance is saved before the money is paid out.
- Deposits take money from the player and are open to everyone when `AllowPublicDonations` is on. Donors can also earn reputation through `Treasury.DonationAction`.

## Projects
`Config.Projects` entries: `{ id, label, cost, days }`. An official funds a project from the panel; the cost leaves the treasury, the project becomes active for `days` days (0 = permanent) and a project already active cannot be funded again. The effect is up to other scripts: read `HasProject(region, id)` or listen to `rsg-economy:server:projectFunded`.

## Server exports
Regions and categories are validated; invalid input returns `nil` or `false` as noted.

| Export | Returns | Description |
| --- | --- | --- |
| `Quote(src, opts)` | quote table / `nil` | Compute a price (see Quotes). `src` may be `nil`. |
| `Record(src, quote)` | boolean | Bank the tax and move the market. |
| `GetTaxRate(region, category)` | fraction / `nil` | Current rate. |
| `SetTaxRate(region, category, rate, actor?)` | `ok, newRate` or `false, reason` | Set a rate (rounded to the step, clamped). No cooldown. Reasons: `unknown`, `invalid`. |
| `GetTreasury(region)` | balance / `nil` | |
| `DepositTreasury(region, amount, reason?, actor?)` | new balance / `nil` | Amount must be > 0. Ledger kind `deposit`. |
| `WithdrawTreasury(region, amount, reason?, actor?)` | new balance / `nil` | `nil` when the balance cannot cover it. Ledger kind `payout`. It does not pay anyone: your script gives the money out. |
| `GetMarketMultiplier(item, region)` | multiplier | 1.0 when nothing moved or the market is off. |
| `GetPressure(item, region)` | -1 to 1 | Current pressure. |
| `RecordTrade(item, region, qty, mode)` | boolean | Move the market directly (`mode` `'sell'` or `'buy'`). |
| `ResetMarket(region?, item?)` | entries cleared | Clear pressure for a region, an item, or everything. |
| `IsOfficial(src, region)` | boolean | |
| `HasProject(region, id)` | boolean | The project is active now. |
| `GetRegions()` / `GetCategories()` | config tables | |

## Events and callbacks
| Name | Side | Arguments | Purpose |
| --- | --- | --- | --- |
| `rsg-economy:server:ready` | server | none | Database ready and data loaded. |
| `rsg-economy:server:taxChanged` | server | `region, category, newRate, oldRate` | A rate changed. |
| `rsg-economy:server:treasuryChanged` | server | `region, balance, delta, kind` | A balance changed. |
| `rsg-economy:server:projectFunded` | server | `region, projectId, expires, src` | A project was funded (`expires` is 0 for permanent). |
| `rsg-economy:client:open` | client | none | Opens the panel. |
| `rsg-economy:server:getPanel` | callback | none | Panel data. Read only, throttled. |
| `rsg-economy:server:getLedger` | callback | `region` | Recent ledger rows. Read only, throttled. |
| `rsg-economy:server:setTax` | callback | `region, category, rate` | Official only. Returns `{ ok, msg }`. |
| `rsg-economy:server:withdraw` | callback | `region, amount` | Official only. Returns `{ ok, msg }`. |
| `rsg-economy:server:deposit` | callback | `region, amount` | Returns `{ ok, msg }`. |
| `rsg-economy:server:fundProject` | callback | `region, project` | Official only. Returns `{ ok, msg }`. |

## Integration examples
### A general store
```lua
local q = exports['rsg-economy']:Quote(src, { region = shop.region, mode = 'buy', base = item.price, qty = amount, item = item.name })
if not q then return end
if not Player.Functions.RemoveMoney('cash', q.total, 'store') then return end
exports['rsg-inventory']:AddItem(src, item.name, amount)
exports['rsg-economy']:Record(src, q)
```
Show `q.unitPrice` and `q.tax` to the player before they confirm.

### A butcher who buys meat
```lua
local q = exports['rsg-economy']:Quote(src, { region = 'saint_denis', mode = 'sell', base = 3.5, qty = count, item = 'venison' })
-- remove the items first, then pay
Player.Functions.AddMoney('cash', q.total, 'butcher')
exports['rsg-economy']:Record(src, q)
```

### Fines into the treasury
```lua
exports['rsg-economy']:DepositTreasury('blackwater', fine, 'fine', 'rsg-lawman')
```

### Pay a town expense from the treasury
```lua
local ok = exports['rsg-economy']:WithdrawTreasury('rhodes', 300, 'well repair', 'rsg-town')
if ok then -- start the repair end
```

### React to a funded project
```lua
AddEventHandler('rsg-economy:server:projectFunded', function(region, id, expires, src)
    if id == 'extra_deputies' then -- spawn guards in that town until `expires` end
end)
```

## Persistence
- Treasuries, rates, market pressure and projects are saved every `SaveInterval` seconds and when the resource stops. A failed write is kept and retried on the next save.
- Panel withdrawals, deposits and project funding save immediately; the ledger row for those is written before the action finishes.
- Expired projects and old ledger entries are removed on start and every 6 hours.

## Commands
See the table in [README.md](README.md). Admin commands also work from the server console (source 0). All use `Config.AdminPermission`.

## Security model
- The client only displays data and forwards requests. Every callback re-checks the region, category, project and amount, and whether the player is an official.
- Amounts must be finite and between 0 and `Treasury.MaxAmount`; rates are clamped to the category limits; project costs come from config, never from the client.
- Actions are throttled per player and run one at a time. Tax changes have a per-rate cooldown; withdrawals have a daily per-town limit that concurrent requests cannot exceed.
- Money moves in a safe order: a withdrawal lowers and saves the treasury before paying the player (refunded if the payout fails); a deposit takes the player's money first.
- Exports trust their caller. Never forward client-supplied prices or quantities to `Quote` / `Record` / `WithdrawTreasury`, and call `Record` only after the money has moved.

## Database schema
Created automatically (`Config.AutoDatabase`), or import `install.sql`.

| Table | Columns |
| --- | --- |
| `rsg_economy_treasury` | `region` (PK), `balance` DECIMAL(14,2) |
| `rsg_economy_tax` | `region`, `category` (PK), `rate` DECIMAL(6,4) |
| `rsg_economy_ledger` | `id` (PK, auto), `region`, `amount`, `balance_after`, `kind`, `reason`, `actor`, `created` (unix time); index on `region, created` |
| `rsg_economy_market` | `item`, `region` (PK), `pressure` DOUBLE, `updated` (unix time) |
| `rsg_economy_project` | `region`, `project` (PK), `expires` (unix time, 0 = permanent) |

## Server owner how-tos
- **Add a town:** add it to `Config.Regions` with its `officials`, and use the same id in the scripts that quote for it.
- **Change who governs a town:** edit its `officials` list (job and minimum grade). Create a mayor job with `/jobadmin` first if you want one.
- **Change tax limits:** edit `Tax.Categories` (`min`, `max`, `default`). Existing saved rates are clamped when they are next changed.
- **Make prices more or less volatile:** `Market.PressurePerUnit`, `Sensitivity` and `HalfLifeHours`, or per-item `Items` overrides.
- **Stop treasury withdrawals:** `Treasury.Withdraw.Enabled = false`. Scripts can still use `WithdrawTreasury`.
- **Add a project:** add an entry to `Config.Projects` and make a script read `HasProject`.
- **Open the panel from a place instead of a command:** set `Config.Command = ''` and trigger `rsg-economy:client:open` from a prompt or target.

## Troubleshooting
| Problem | Check |
| --- | --- |
| "could not create database tables" in the console | oxmysql is running and the database user may create tables, or set `AutoDatabase = false` and import `install.sql`. |
| Quote returns `nil` | The region is not in `Config.Regions`, `base` is not a number >= 0, `qty` is not 1 to 10000, or the category is unknown. |
| Treasuries stay at 0 | No script calls `Record` yet, or the tax rates are 0. |
| Officials cannot change taxes | Their job and grade match an entry in the region's `officials`; `RequireOnDuty`; the 5 minute cooldown. |
| "Daily withdrawal limit reached" | The limit is per town and UTC day across all officials. Raise `Treasury.Withdraw.DailyLimit`. |
| Reputation prices have no effect | `rsg-reputation` is started before this resource's quotes run and `UseReputation` is true; pass the player's `src` to `Quote`. |
| A locale shows a raw key | The key is missing from that language file. |
| Push-to-talk does not work with the panel open | `Config.AllowPushToTalkWhileOpen` and `PushToTalkControls`. |

## Finding the region of a position

`GetRegionAt(coords, maxDistance?)` returns `regionId, distance` for the nearest region that has `coords`, or `nil` when none is within `maxDistance` (default `Config.RegionRadius`). `coords` may be a vector3, a vector4 or a table with `x`, `y`, `z`. Shop, rent and fine scripts use it so the region does not have to be configured per shop:
```lua
local region = exports['rsg-economy']:GetRegionAt(GetEntityCoords(GetPlayerPed(src)))
if region then exports['rsg-economy']:DepositTreasury(region, fine, 'fine', 'my-script') end
```
Regions without `coords` are never returned.


---
Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-economy 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`oxmysql`, `rsg-core`

### Database

Tables: `rsg_economy_treasury`, `rsg_economy_tax`, `rsg_economy_ledger`, `rsg_economy_market`, `rsg_economy_project`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `install.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | Tables are created automatically on start. Set to false to import install.sql manually. |
| `Config.AllowPushToTalkWhileOpen` | `true` | While the NUI is open, block game controls but allow push-to-talk. |
| `Config.PushToTalkControls` | `table` |  |
| `Config.Command` | `'economy'` | Chat command that opens the economy panel ('' to disable) |
| `Config.AdminPermission` | `'admin'` | Permission level needed for the admin commands |
| `Config.SaveInterval` | `30` | Seconds between database saves of changed treasuries, rates and prices |
| `Config.MoneyType` | `'cash'` | Money type used for deposits and withdrawals ('cash' or 'bank') |
| `Config.UseReputation` | `true` | Use rsg-reputation price modifiers (disliked players pay more, respected players less) when it is running |
| `Config.RequireOnDuty` | `false` |  |
| `Config.RegionRadius` | `800.0` | exports['rsg-economy']:GetRegionAt(coords). A position further than RegionRadius from every town has no region |
| `Config.Regions` | `table` |  |
| `Config.Tax` | `table` |  |
| `Config.Step` | `0.005` |  |
| `Config.ChangeCooldown` | `300` | seconds an official must wait before changing the same rate again in the same region |
| `Config.Categories` | `table` |  |
| `Config.Treasury` | `table` |  |
| `Config.PublicBalance` | `true` |  |
| `Config.AllowPublicDonations` | `true` |  |
| `Config.DonationAction` | `'donation'` |  |
| `Config.MaxAmount` | `1000000` |  |
| `Config.Withdraw` | `table` |  |
| `Config.Ledger` | `table` |  |
| `Config.Market` | `table` |  |
| `Config.Enabled` | `true` |  |
| `Config.PressurePerUnit` | `0.02` |  |
| `Config.HalfLifeHours` | `12` |  |
| `Config.Sensitivity` | `0.5` |  |
| `Config.MinMultiplier` | `0.5` |  |
| `Config.MaxMultiplier` | `1.5` |  |
| `Config.Items` | `table` | per-item overrides: { sensitivity, min, max, perUnit } |
| `Config.Projects` | `table` |  |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `Quote` | `` | `server/economy.lua` |
| `Record` | `` | `server/economy.lua` |
| `GetTaxRate` | `` | `server/economy.lua` |
| `SetTaxRate` | `` | `server/economy.lua` |
| `GetTreasury` | `` | `server/economy.lua` |
| `DepositTreasury` | `region, amount, reason, actor` | `server/economy.lua` |
| `WithdrawTreasury` | `region, amount, reason, actor` | `server/economy.lua` |
| `GetMarketMultiplier` | `` | `server/economy.lua` |
| `GetPressure` | `` | `server/economy.lua` |
| `RecordTrade` | `` | `server/economy.lua` |
| `ResetMarket` | `` | `server/economy.lua` |
| `IsOfficial` | `` | `server/economy.lua` |
| `HasProject` | `` | `server/economy.lua` |
| `GetRegions` | `` | `server/economy.lua` |
| `GetRegionAt` | `coords, maxDistance` | `server/economy.lua` |
| `GetCategories` | `` | `server/economy.lua` |

```lua
-- example
local result = exports['rsg-economy']:Quote()
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-economy:server:getPanel` | server | `source, cb` | `server/actions.lua` |
| `rsg-economy:server:getLedger` | server | `source, cb, region` | `server/actions.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-economy:server:getPanel', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-economy:client:open` | client | `` | `client/ui.lua` |

```lua
-- from a server script
TriggerClientEvent('rsg-economy:client:open', source)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
