# rsg-mining – Developer Docs

## Framework usage (ox_lib free)
rsg-mining has no ox_lib dependency. Everything runs on rsg-core and rsg-target.

| Feature | API used |
|---|---|
| Locales | `@rsg-core/shared/locale.lua` + `locale(key, ...)`; language from `setr rsg:locale <lang>` (falls back to `ox:locale`, then `en`) |
| UI locale bundle | `locale()` with no key returns every string; the client sends the `ui_*` / `status_*` keys to the NUI |
| Notify (client) | `RSGCore.Functions.Notify({ title, description, type, duration, icon, position })` |
| Notify (server) | `TriggerClientEvent('RSGCore:Client:Notify', src, data)` |
| Callbacks | server `RSGCore.Functions.CreateCallback` (wrapped by `registerCallback`, so handlers keep `return` style); client `RSGCore.Functions.AwaitCallback(name, nil, ...)` |
| Model loading | `RSGCore.Functions.RequestModel(model, 10000)` |
| Proximity spawning | `points.new({...})` from `@rsg-core/client/points.lua` |
| Targeting | `exports['rsg-target']:addLocalEntity / removeLocalEntity` |
| Lease purchase confirm | the resource's own NUI confirm box (`confirm` NUI message → `confirmAnswer` NUI callback) |

## Server callbacks
All re-validate lease holder, distance and cooldown server-side.
- `rsg-mining:server:getMineData(mineId)` → `{ data }`, `{ noLease, price, hours, label }` or `{ error }`
- `rsg-mining:server:buyLease(mineId)` → bool
- `rsg-mining:server:renewLease / hire(key) / fire(workerId) / addWages(amount) / withdrawWages(amount) / deposit(key, amount) / collect(item)` → updated ledger data or false

## NUI messages
- `open { data, locales }`, `update { data }`, `close`
- `confirm { title, text, locales }` – lease purchase prompt; answered with POST `confirmAnswer { ok }`

## Locale keys added in the migration
`ui_confirm_buy`, `ui_cancel` (all 11 languages).

## rsg-skills integration

`Config.Skills = { Enabled, Skill, CollectXP, MaxXPPerCollect }`. After the server has handed over the ore in `rsg-mining:server:collect`, it calls `exports['rsg-skills']:AddXP(src, 'mining', xp, 'mining collect')` with `xp = min(items collected * CollectXP, MaxXPPerCollect)`. The amount comes from config. Skipped when rsg-skills is not started.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-mining 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-target`, `oxmysql`, `rsg-inventory`

### Database

Tables: `rsg_mining`, `rsg_mining_workers`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/rsg-mining.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.ForemanModel` | `'u_m_m_bht_mineforeman'` |  |
| `Config.SpawnDistance` | `50.0` | foreman ped spawns when player is within this range |
| `Config.TargetDistance` | `2.5` |  |
| `Config.ManageDistance` | `10.0` | server-side: max distance from the foreman to use the ledger |
| `Config.ActionCooldown` | `500` | ms between foreman actions per player (anti-spam) |
| `Config.MoneyType` | `'cash'` | cash \| bank |
| `Config.NotifyPosition` | `'top-right'` |  |
| `Config.ImagePath` | `'nui://rsg-inventory/html/images/'` | where item images live |
| `Config.LeaseDurationHours` | `72` | real-time hours a lease lasts |
| `Config.AllowRenew` | `true` | lease holder can extend from the foreman UI |
| `Config.MaxLeaseHours` | `336` | cap on total remaining time when renewing |
| `Config.Supplies` | `table` |  |
| `Config.WorkInterval` | `10` | minutes between work cycles |
| `Config.FoodDrain` | `25` | food lost per cycle (0-100) |
| `Config.WaterDrain` | `34` | water lost per cycle (0-100) |
| `Config.PickaxeWear` | `20` | durability lost per cycle (0-100) |
| `Config.BreadRestore` | `100` | food restored by 1 bread |
| `Config.WaterRestore` | `100` | water restored by 1 water |
| `Config.MinSkill` | `1` |  |
| `Config.MaxSkill` | `10` |  |
| `Config.SkillGainPerCycle` | `0.05` | workers improve slowly on the job |
| `Config.SkillChanceBonus` | `0.08` | +8% ore chance per skill level above 1 |
| `Config.SkillAmountBonus` | `0.5` | extra ore per skill level (floored) |
| `Config.WageBase` | `2` | base pay per shift |
| `Config.WagePerSkill` | `0.5` | extra pay per skill level (wage is rounded up) |
| `Config.MaxPayroll` | `5000` | most money the payroll fund can hold |
| `Config.AllowWithdraw` | `true` | lease holder can take unused wages back out |
| `Config.CandidateCount` | `5` | hiring |
| `Config.CandidateRefresh` | `30` | minutes before the hiring board refreshes |
| `Config.HireBaseCost` | `10` |  |
| `Config.HireCostPerSkill` | `8` | cost = base + skill * this |
| `Config.CandidateSkillMax` | `7` | best skill a fresh hire can have |
| `Config.FirstNames` | `{ 'Amos','Bill','Cyrus','Eli','Silas','Jeb','Otis','Hank','Walt','Clem` |  |
| `Config.LastNames` | `{ 'Hollis','Carver','Dunn','Pruitt','Mosby','Hale','Riggs','Tate','Boo` |  |
| `Config.Mines` | `table` |  |
| `Config.Skills` | `table` | rsg-skills integration (optional). Needs the rsg-skills resource; does nothing when it is not started. |
| `Config.Enabled` | `true` |  |
| `Config.Skill` | `'mining'` |  |
| `Config.CollectXP` | `1` |  |
| `Config.MaxXPPerCollect` | `50` |  |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-mining:server:getMineData` | server | `src, id` | `server/server.lua` |
| `rsg-mining:server:buyLease` | server | `src, id` | `server/server.lua` |
| `rsg-mining:server:renewLease` | server | `src, id` | `server/server.lua` |
| `rsg-mining:server:hire` | server | `src, id, key` | `server/server.lua` |
| `rsg-mining:server:fire` | server | `src, id, wid` | `server/server.lua` |
| `rsg-mining:server:addWages` | server | `src, id, amount` | `server/server.lua` |
| `rsg-mining:server:withdrawWages` | server | `src, id, amount` | `server/server.lua` |
| `rsg-mining:server:deposit` | server | `src, id, key, amount` | `server/server.lua` |
| `rsg-mining:server:collect` | server | `src, id, item` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-mining:server:getMineData', function(result)
    -- use result
end)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/rsgmining_webhooktest` |  | `server/sv_webhooks.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
