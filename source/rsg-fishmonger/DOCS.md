# rsg-fishmonger – Docs (v3.3.1)

## Contents
1. Files
2. How it works
3. Configuration
4. Events, callbacks and commands
5. Data formats
6. Database
7. Security
8. Integrations
9. Code examples
10. Server owner how-tos
11. Troubleshooting
12. Locales

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `rsg-target` |
| `shared/config.lua` | NPC, locations, hours, demand, bonus, stock, shop, fish prices |
| `shared/utils.lua` | Shared `FishmongerFillet(item)` helper |
| `client/client.lua` | NPC spawning, blips, targets, NUI bridge |
| `server/server.lua` | Menu data, checkout, daily demand and stock, shop |
| `server/sv_config.lua`, `server/webhook.lua` | Webhook settings and Discord logs |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI cart menu |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 2. How it works
- 8 fishmonger NPCs: Saint Denis, Blackwater, Valentine, Rhodes, Annesburg, Van Horn, Tumbleweed and the river trading post, each with an optional blip.
- Use rsg-target on the NPC to open a cart menu. **Sell** fish for money (`cash`, `bank` or `bloodmoney`) or **process** them into fillets (`raw_fish` by default).
- **Daily demand:** each town rolls a price multiplier every real day (80%–125%).
- **Seller bonus:** extra pay from fishing rep (earned per fish traded) and optional per-job bonuses.
- **Town stock:** each town only buys a set number of fish; the count survives restarts and recovers `recoveryPerHour` fish every real hour (`0` = resets at midnight). Processing and fillet sales are not limited.
- **Fish quality:** each fish stack is paid by its own size (`info.weight`) and freshness (`info.quality`). `planPicks` sells stacks in slot order, and `getMenuData` sends each fish's multipliers in that same order (`stacks`) so the menu preview is exact.
- **Daily orders:** `contractsFor(loc)` builds the day's orders from a hash of date + town + slot (same for everyone). `deliverOrder` marks the order done in `rsg_fishmonger_orders` first, then removes the fish and pays, and undoes the mark if anything fails.
- **Fillet market:** items in `Config.FilletSale.items` can be sold (never processed).
- **Supplies shop tiers:** one rsg-inventory shop per tier per town (`fishmonger_<key>`, `fishmonger_<key>_t2`, ...). `openShop` picks the highest tier the player's rsg-skills level unlocks.
- **Supplies shop:** buy bait and lures from the same NPC (an rsg-inventory shop per town).
- **Fillet types:** any fish can give its own fillet item.
- **Opening hours** (optional) use the rsg-weather in-game clock.

> **rsg-economy (3.2.0):** in `checkout` (sell mode) the total is passed to `exports['rsg-economy']:Quote(src, { region = GetRegionAt(loc.coords), mode = 'sell', base = total, qty = 1, market = false })`, the payout uses `quote.total`, and `Record(src, quote)` runs after `AddMoney` succeeds. Config: `Config.Economy.Enabled`.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `NpcModel` | `cs_fishcollector` | NPC model |
| `SpawnDistance` | `50.0` | NPC spawn/despawn range |
| `TargetDistance` | `2.5` | rsg-target range |
| `MaxUseDistance` | `5.0` | The menu closes beyond this range; the server allows 1.5 m extra |
| `AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk working while the menu is open; all other controls are blocked |
| `PushToTalkControls` | table | Control hashes left enabled while the menu is open (default `INPUT_PUSH_TO_TALK`) |
| `Cooldown` | `2000` | ms between checkouts |
| `MoneyType` | `'cash'` | `cash`, `bank` or `bloodmoney` |
| `FilletItem` | `'raw_fish'` | Default fillet item |
| `Blip` | table | `enabled`, `sprite`, `style`, `scale`, `openColor`, `closedColor` (blip colour modifiers while open / closed; only with opening hours) |
| `ItemHints` | `true` | Appends a "sells for about $x" line to each fish item's description at start, using rsg-core `UpdateItem` |
| `BanOnTamper` | `false` | `ExploitBan` for requests the menu can never produce |
| `Quality` | table | `enabled`, `size = { enabled, perKg, max }`, `freshness = { enabled, min }` |
| `Contracts` | table | `enabled`, `perLocation`, `minQty`, `maxQty`, `payMultiplier`, `repReward`, `xpReward`; per-location `orders = false` |
| `FilletSale` | table | `enabled`, `items = { [item] = pricePerFillet }` |
| `Locations` | list | `{ key, coords, hours?, demand?, stock? }`; display name comes from locale `loc_<key>` |
| `OpeningHours` | table | `enabled`, `open` (6), `close` (22); wraps past midnight; per-location `hours` override |
| `Demand` | table | `enabled`, `min` 0.80, `max` 1.25; `demand = false` on a location for base price |
| `Bonus` | table | `jobs` (job → fraction) and `rep` (`name`, `perPoint`, `max` 0.15, `gainPerFish`) |
| `AutoDatabase` | boolean | `true` creates `rsg_fishmonger_stock` on start; `false` = import `install.sql` yourself |
| `DailyStock` | table | `enabled`, `perLocation` (200), `recoveryPerHour` (20, `0` = midnight reset); per-location `stock` (0 = unlimited) |
| `Shop` | table | `enabled`, `persistentStock`, `skill` (rsg-skills skill for the tiers), `items` (`name`, `price`, `amount`), `tiers` (`{ level, items }`, each includes the lower tiers) |
| `Fish` | table | fish model → `{ price, fillets, fillet? }` |

Example, a fish with its own fillet:
```lua
['a_c_fishsalmonsockeye_01_lg'] = { price = 2.75, fillets = 3, fillet = 'salmon_fillet' },
```
Webhook URLs are in `server/sv_config.lua`.

## 4. Events, callbacks and commands
Callbacks use rsg-core (`RSGCore.Functions.TriggerCallback` / `AwaitCallback`). All of them re-validate the player, the arguments and the distance on the server.

| Name | Side | Arguments | Returns / notes |
|---|---|---|---|
| `rsg-fishmonger:server:getMenuData` | callback | `locationIndex` | `{ counts, stacks, orders, demand, bonus, econ, stockLeft }`, `{ denied = true, message }` when too far or closed, or `nil` without a player |
| `rsg-fishmonger:server:checkout` | callback | `locationIndex, mode, cart` | `{ ok, message }`. `mode` is `'sell'` or `'process'` |
| `rsg-fishmonger:server:deliverOrder` | callback | `locationIndex, slot` | `{ ok, message }` |
| `rsg-fishmonger:server:getHours` | callback | none | `{ [locationIndex] = open }` |
| `rsg-fishmonger:server:openShop` | server event | `locationIndex` | Opens the supplies shop tier the player's fishing level unlocks; throttled to 1/s |
| `rsg-fishmonger:client:hours` | client event | `states` | Sent to everyone when a town opens or closes |

| Command | Who | What |
|---|---|---|
| `/fishmonger_webhooktest` | admin | Sends a test message to every webhook |

The resource has no exports. `FishmongerFillet(item)` is a shared global helper that returns the fillet item for a fish.

## 5. Data formats
`locationIndex` is the 1-based position in `Config.Locations`. `slot` is the 1-based order slot for the day.

`cart` (client to server) is a table of item name to amount. Fish and sellable fillets only; fillets are rejected in `process` mode.
```lua
{ ['a_c_fishrainbowtrout_01_ms'] = 4, ['raw_fish'] = 10 }
```
`getMenuData` result:
```lua
{
  counts   = { [item] = totalOwned },
  stacks   = { [fishItem] = { { n = 3, m = 1.07 }, { n = 1, m = 1.0 } } }, -- stacks in sale order, m = quality multiplier
  orders   = { { slot = 1, item = '...', qty = 5, reward = 21.5, done = false } },
  demand   = 1.12,   -- town price multiplier today
  bonus    = 0.08,   -- seller bonus (job + skill + rep)
  econ     = 1.0,    -- rsg-economy price factor (1 when off)
  stockLeft = -1,    -- -1 = unlimited
}
```
Payout per sale: `sum(price * quality units) * demand * (1 + bonus)`, then rsg-economy tax and standing when enabled. Quality multiplier per fish: `(freshMin + (1 - freshMin) * quality / 100) * (1 + min(sizeMax, kg * perKg))`.

## 6. Database
Created automatically while `Config.AutoDatabase = true` (a missing `updated` column is added). Otherwise import `install.sql`.

| Table | Columns |
|---|---|
| `rsg_fishmonger_stock` | `location` (PK), `day`, `sold`, `updated` (unix time of last sale, used for recovery) |
| `rsg_fishmonger_orders` | `citizenid`, `location`, `slot` (PK together), `day` |

Rows in `rsg_fishmonger_orders` from earlier days are deleted on start. Upgrading a manual 3.2.x install: import `install.sql` and run the `ALTER TABLE` line at its end.

## 7. Security
The server checks distance to the NPC (`MaxUseDistance` + 1.5 m), opening hours, cooldown, a per-player busy lock, that items are sellable and owned, stock, and computes every price itself. Order delivery uses the same lock and cooldown and can be done once per player per order per day (the DB row is written first and undone on failure). Failed payouts or removals roll the inventory back. With `Config.BanOnTamper = true`, requests the menu can never produce (invalid mode, malformed or oversized cart, unknown items) call `ExploitBan`; "more than owned" and distance problems never do, since lag can cause them. Suspicious-activity webhooks are limited to one per player every 5 seconds. Opening hours are decided only by the server using rsg-weather's clock. Other scripts must not trigger these callbacks on a player's behalf.

## 8. Integrations
All optional and pcall-guarded; the script works without them.
- **rsg-weather:** `getTime()` for opening hours.
- **rsg-skills:** `Config.Bonus.skill` (`GetPerk`, percent), shop tiers (`GetLevel`) and order XP (`AddXP`).
- **rsg-economy:** `GetRegionAt`, `Quote` (sell mode) and `Record` after payment. `Config.Economy.Enabled`.
- **rsg-inventory:** `AddItem`, `RemoveItem`, `CanAddItem`, `CreateShop`, `OpenShop`, `DoesShopExist`.
- **rsg-core:** `GetRep` / `AddRep`, `UpdateItem` (sell hints), `ExploitBan`.
- **Push-to-talk:** the menu uses `SetNuiFocusKeepInput(true)` and a loop that blocks all controls except `Config.PushToTalkControls`. Set `Config.AllowPushToTalkWhileOpen = false` for full input focus.

## 9. Code examples
Add a fish with its own fillet:
```lua
['a_c_fishsalmonsockeye_01_lg'] = { price = 2.75, fillets = 3, fillet = 'salmon_fillet' },
```
Add a town with custom hours, no demand swing and a larger stock:
```lua
{ key = 'strawberry', coords = vector4(-1800.0, -400.0, 160.0, 90.0), hours = { open = 8, close = 18 }, demand = false, stock = 400 },
```
(add `loc_strawberry` to every `locales/*.json`).

Give a job a sell bonus and sell fillets back:
```lua
Config.Bonus.jobs = { fisherman = 0.10 }
Config.FilletSale = { enabled = true, items = { raw_fish = 0.30, salmon_fillet = 0.55 } }
```
Quality is read from the fish's item info, so another script can set it when it gives a fish:
```lua
exports['rsg-inventory']:AddItem(src, 'a_c_fishrainbowtrout_01_ms', 1, { weight = '2.4', quality = 90 }, nil, 'my-fishing')
```
Open the menu check from another client script (read-only):
```lua
RSGCore.Functions.TriggerCallback('rsg-fishmonger:server:getMenuData', function(res)
    if res and res.denied then print(res.message) end
end, 1)
```
Webhook helper (server, inside this resource): `Webhook.Send('sales', { title = 'Title', description = 'Text', src = source, fields = { { name = 'A', value = 'B', inline = true } } })`. Log types: `sales`, `processing`, `suspicious`, `errors`, `system`. URLs, colours and the large-sale alert thresholds are in `server/sv_config.lua`.

## 10. How-tos
- Add a fish: add its model to `Config.Fish`; the item must exist in rsg-core items.
- Stop daily stock limits: `Config.DailyStock.enabled = false`.
- Manual database install: `Config.AutoDatabase = false` and import `install.sql`.
- Bait item names should match rsg-fishing's baits.
- After changing prices, restart the resource; sell hints refresh on start.

## 11. Troubleshooting
| Problem | Fix |
|---|---|
| NPC says closed | Check `OpeningHours` and that rsg-weather is started |
| "Town stock full" | Wait for recovery, raise `perLocation`, or disable stock |
| Shop items missing | The item must exist in rsg-core items; check the console warning at start |
| Fish not listed | Missing from `Config.Fish` or not in shared items |
| Menu preview differs from payout | Check rsg-economy is the same state; the preview mirrors server quality, demand, bonus and economy |
| Push-to-talk stops in the menu | `AllowPushToTalkWhileOpen` and the control hash in `PushToTalkControls` |

## 12. Locales
`locales/`: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru` (identical keys). Set `setr rsg:locale "en"`.

Support the Project : https://rexshack.tebex.store/
