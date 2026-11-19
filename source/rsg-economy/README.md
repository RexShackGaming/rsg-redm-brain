# rsg-economy

A regional economy for the RSG Framework: every town has a **treasury**, its own **tax rates** set by its officials, **supply-and-demand prices** that react to what players buy and sell, and **town projects** the treasury can pay for. Taxes flow into the treasuries, and projects and officials' decisions spend them, so money keeps moving instead of piling up.

Version 3.1.0 · Requires `rsg-core` and `oxmysql` · Optional: `rsg-reputation` · No ox_lib, no target and no inventory dependency

Full developer and server owner documentation is in [DOCS.md](DOCS.md).

## Features
- **9 town treasuries** (Valentine, Rhodes, Saint Denis, Strawberry, Blackwater, Annesburg, Van Horn, Armadillo, Tumbleweed). Add or remove towns in `shared/config.lua`.
- **Four tax categories** (sales, trade, property, licence) with a default, a minimum and a maximum each. Officials change rates inside those limits.
- **Officials per town** by job: the town's law job at Sheriff grade plus the `government` job by default. Fully configurable.
- **Dynamic prices:** selling to shops pushes an item's price down in that town, buying pushes it up. Prices drift back to normal over time (configurable half-life, limits and sensitivity, per item if you like).
- **One call for shops:** `Quote` returns unit price (market and reputation applied), tax and total for a purchase or a sale. `Record` banks the tax and moves the market once the money has really changed hands.
- **Reputation link:** if `rsg-reputation` is running, disliked players pay more and respected players pay less in a town.
- **Treasury** panel: balance, deposits (anyone can donate), officials' withdrawals with a daily limit, and a ledger of recent activity. Every change is logged with who did it.
- **Town projects** (street lamps, extra deputies, road repairs, town festival by default): officials pay for them from the treasury and other scripts read `HasProject` or listen for an event to apply the effect.
- Admin commands to set taxes, adjust treasuries, reset markets and inspect a town (also from the console).
- Push-to-talk keeps working while the panel is open.
- Database tables are created automatically.

## Installation
1. Copy the `rsg-economy` folder into your resources.
2. Start it after `oxmysql` and `rsg-core` (and `rsg-reputation` if you use it), and before any script that uses it:
   ```
   ensure oxmysql
   ensure rsg-core
   ensure rsg-reputation
   ensure rsg-economy
   ```
3. Database: the tables (`rsg_economy_treasury`, `rsg_economy_tax`, `rsg_economy_ledger`, `rsg_economy_market`, `rsg_economy_project`) are created automatically on first start. To install manually instead, set `Config.AutoDatabase = false` in `shared/config.lua` and import `install.sql`.
4. Optional: set the language with `setr rsg:locale de` in `server.cfg` (see Locales).
5. Check the officials. The seed jobs in rsg-core include the five town law jobs (`vallaw`, `rholaw`, `stdenlaw`, `strlaw`, `blklaw`). There is no mayor or governor job, so the `government` job (the manager job used by rsg-townhall) is also accepted in every town. Raise its `minGrade` in `Config.Regions` if not every government worker should be an official.
6. The economy does nothing on its own. Shop and trade scripts must call `Quote` / `Record` (see below). No existing RSG resource does this yet, so taxes stay empty until a script uses it.

## Configuration
All options are in `shared/config.lua`.

| Option | Default | Description |
| --- | --- | --- |
| `AutoDatabase` | `true` | Create the tables on start. Set `false` and import `install.sql` to do it by hand. |
| `AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk working while the panel is open. |
| `PushToTalkControls` | `0x4BC9DABB` | Controls left enabled while the panel has focus. |
| `Command` | `'economy'` | Chat command that opens the panel (`''` to disable). |
| `AdminPermission` | `'admin'` | Permission level for the admin commands. |
| `SaveInterval` | `30` | Seconds between saves of changed data. |
| `MoneyType` | `'cash'` | Money type used for deposits and withdrawals. |
| `UseReputation` | `true` | Apply `rsg-reputation` price modifiers when it is running. |
| `RequireOnDuty` | `false` | Officials must be on duty. |
| `Regions` | 9 towns | Region id, label, panel `order` and the `officials` list (`job`, `minGrade`). |
| `Tax.Step` / `Tax.ChangeCooldown` | `0.005` / `300` | Rate step (0.5%) and seconds before the same rate can change again. |
| `Tax.Categories` | 4 categories | `default`, `min`, `max`, `label`, `order` per category. |
| `Treasury.PublicBalance` | `true` | Everyone can see the balance (`false` = officials only). |
| `Treasury.AllowPublicDonations` | `true` | Any player may donate. |
| `Treasury.DonationAction` | `'donation'` | `rsg-reputation` action applied to donors. |
| `Treasury.MaxAmount` | `1000000` | Largest single deposit or withdrawal. |
| `Treasury.Withdraw` | `Enabled true, DailyLimit 2000` | Official withdrawals through the panel; limit per town and UTC day. |
| `Treasury.Ledger` | `KeepDays 30, PageSize 20, LogTax true` | History kept, rows shown, and whether each taxed sale gets a row. |
| `Market` | `PressurePerUnit 0.02, HalfLifeHours 12, Sensitivity 0.5, 0.5 to 1.5` | Dynamic price settings and optional per-item overrides in `Items`. |
| `Projects` | 4 projects | `id`, `label`, `cost`, `days` (0 = permanent). |

## How to use
**Players**
- `/economy` opens the panel. Use it again, the close button or Escape to close it.
- Pick a town. **Taxes** shows its rates, **Treasury** shows the balance, projects and recent activity, **Market** lists items whose price has moved.
- Anyone can donate to a treasury (when `AllowPublicDonations` is on).

**Officials** (see Installation, step 5)
- On the Taxes tab, use − and + to choose a rate and press Apply. Each rate can change once per `Tax.ChangeCooldown` seconds.
- On the Treasury tab, withdraw money (up to the daily limit for the whole town) and fund town projects.

**Admin commands** (permission `Config.AdminPermission`; region ids are the keys in `Config.Regions`, categories are `sales`, `trade`, `property`, `license`)

| Command | Description |
| --- | --- |
| `/settax [region] [category] [percent]` | Set a tax rate (within the category limits). |
| `/addtreasury [region] [amount]` | Add money to a treasury (negative removes). |
| `/settreasury [region] [amount]` | Set a treasury balance exactly. |
| `/resetmarket [region or all]` | Clear market price pressure. |
| `/economyinfo [region]` | Show a town's treasury, tax rates and number of moved items. |

## For developers
In any shop or trade script, ask for a quote, move the money yourself, then record it:
```lua
-- buying: the player pays q.total
local q = exports['rsg-economy']:Quote(src, { region = 'valentine', mode = 'buy', base = 4.50, qty = 2, item = 'bread' })
if not q then return end
if not Player.Functions.RemoveMoney('cash', q.total, 'general-store') then return end
exports['rsg-inventory']:AddItem(src, 'bread', 2)
exports['rsg-economy']:Record(src, q)   -- tax goes to the treasury, demand raises the price

-- selling: the player receives q.total (price minus trade tax)
local s = exports['rsg-economy']:Quote(src, { region = 'valentine', mode = 'sell', base = 3.00, qty = 5, item = 'venison' })
```
Apply a funded project:
```lua
if exports['rsg-economy']:HasProject('valentine', 'street_lamps') then
    -- lamps on
end
AddEventHandler('rsg-economy:server:projectFunded', function(region, projectId, expires, src) end)
```
Pay for something out of a treasury, or put money in:
```lua
exports['rsg-economy']:WithdrawTreasury('rhodes', 500, 'new well', 'rsg-town')
exports['rsg-economy']:DepositTreasury('rhodes', 25, 'fine collected', 'rsg-lawman')
```
All exports, events and callbacks are in [DOCS.md](DOCS.md).

## Locales
Ships with `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br` and `ro`, all with the same keys. Tax category names are locale keys (`cat_*`); region and project labels may be plain text or a locale key.

## Notes
- Regions are passed by the calling script (for example the town a shop belongs to). The resource does not detect where the player is.
- Prices are rounded to two decimals at the unit price and again at the subtotal, tax and total.
- Data is saved every `SaveInterval` seconds and when the resource stops. Withdrawals, deposits and project funding are saved immediately, before money is paid out.
- The panel works from anywhere. If officials should only act inside the town hall, open it with the `rsg-economy:client:open` event from a prompt or target there and set `Config.Command = ''`.

---
## Finding the region of a position

Other scripts call `exports['rsg-economy']:GetRegionAt(coords)` to find the town nearest to a position (within `Config.RegionRadius`, default 800 m). Each region has approximate town-centre `coords` in `Config.Regions`; edit them if your towns are elsewhere.


Support the Project : https://rexshack.tebex.store/
