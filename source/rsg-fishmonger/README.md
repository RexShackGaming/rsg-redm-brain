# rsg-fishmonger

A fishmonger system for **RSG-Core (RedM)**. Players visit a fishmonger NPC in any major town to **sell their catch for cash** or **process fish into fillets**, using a cart-based menu styled to match the rest of the RSG UI.

---

<img width="1920" height="1080" alt="20260930182134_1" src="https://github.com/user-attachments/assets/a64ceaae-b9c8-4cfe-b786-94c1223a61a6" />

## Features

- **8 fishmonger NPCs**: Saint Denis, Blackwater, Valentine, Rhodes, Annesburg, Van Horn, Tumbleweed and the river trading post. Each has an optional map blip.
- **Sell or process**: sell fish for money (`cash`, `bank` or `bloodmoney`) or turn them into fillets (`raw_fish` by default).
- **Daily demand**: each town rolls a price multiplier every real day (80%–125% by default), so it pays to shop around.
- **Seller bonus**: extra pay from fishing reputation (earned per fish traded), the rsg-skills fishing perk and optional per-job bonuses.
- **Fish quality**: bigger and fresher fish pay more. The menu shows the exact amount, including this bonus.
- **Daily orders**: each town posts a few fish orders every day (the same for everyone). Deliver one for a bonus payout, fishing rep and XP.
- **Fillet market**: sell fillets back to the fishmonger from the same menu, so processing has a payoff even if you don't cook.
- **Town stock**: each town only buys a set number of fish. The limit recovers a little every hour (or resets at midnight, your choice) and survives restarts.
- **Fishing supplies shop**: buy bait and lures from the same NPC (rsg-inventory shop, one per town). Better lures unlock as the player's fishing level goes up.
- **Map blips** turn red while a town is closed (when opening hours are on).
- **Sell hint**: every fish's item description says roughly what it sells for.
- **Fillet types**: any fish can give its own fillet item instead of the default.
- **Opening hours** (optional) using the rsg-weather in-game clock.
- **Cart-based menu**:
  - Search fish by name, or filter to fish you own.
  - Set a quantity with the +/- buttons, or add one type or everything to the cart at once.
  - Live totals for fish count, sell value and fillets.
  - Today's demand, your bonus and the town's remaining stock shown in the cart.
  - **Sell All Owned** in one click (best fish first if stock is limited).
  - A confirmation pop-up before every trade (`Enter` confirms).
  - If a trade fails, the menu stays open with your cart kept and the reason shown.
  - `ESC` or the close button to leave. The menu closes itself if you walk away.
- **Server-side security**:
  - Every trade is checked against the config, the shared items list and the player's real inventory.
  - The server checks the player's distance to the NPC.
  - Quantities must be whole numbers within a sane range.
  - There is a per-player cooldown and a lock that stops two trades running at once.
  - If any step fails, the trade is fully reversed, so nothing is lost or duplicated.
- **Discord webhook logging** with separate channels for sales, processing, suspicious activity, errors and system events. Posts include the player's character, citizen ID and identifiers. Suspicious activity and large trades can ping staff, and sends are queued to stay within Discord's rate limits.
- **Translations** (rsg-core locales): `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. This covers notifications, the menu, the blip, location names and webhook logs.
- **Performance**: NPCs spawn only when a player is nearby, the spawn check slows down when you are far from every fishmonger, and the model is released when no NPCs are nearby.
- **Push-to-talk keeps working** while the menu is open.
- **Version checker** that reports on startup whether an update is available.

---

## Dependencies

| Resource | Notes |
|---|---|
| [rsg-core](https://github.com/Rexshack-RedM/rsg-core) | Framework |
| [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) | Needs a recent build with the `AddItem`, `RemoveItem` and `CanAddItem` exports |
| [rsg-target](https://github.com/Rexshack-RedM/rsg-target) | NPC interaction |
| [oxmysql](https://github.com/overextended/oxmysql) | Saves the town stock and delivered orders (`rsg_fishmonger_stock`, `rsg_fishmonger_orders`; created automatically, and the new `updated` column is added to an older stock table). Set `Config.AutoDatabase = false` and import `install.sql` to install by hand; upgrading by hand also needs the `ALTER TABLE` line in `install.sql` |
| [rsg-weather](https://github.com/Rexshack-RedM/rsg-weather) | Optional, only for opening hours |
| [rsg-skills](https://github.com/Rexshack-RedM/rsg-skills) | Optional: fishing sell bonus, order XP and the shop tiers (without it only the base shop list is sold) |

No ox_lib required: callbacks, notifications, locales and commands all use rsg-core.

---

## Installation

1. Download the resource and place the `rsg-fishmonger` folder in your resources directory, e.g. `resources/[rsg]/rsg-fishmonger`.
2. Make sure every **fish item** in `Config.Fish` and the **fillet item** (`raw_fish`) exist in `rsg-core/shared/items.lua`. The console warns on startup about any that are missing.
3. Make sure the item images exist in `rsg-inventory/html/images/`, named `<item>.png`.
4. Add the resource to your `server.cfg` **after** its dependencies:
   ```cfg
   ensure rsg-core
   ensure rsg-inventory
   ensure oxmysql
   ensure rsg-target
   ensure rsg-fishmonger
   ```
5. *(Optional)* Set the language in `server.cfg`:
   ```cfg
   setr rsg:locale "en"   # en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru
   ```
6. *(Optional)* Set up Discord webhooks in `server/sv_config.lua` (see below).
7. Restart the server.

---

## Configuration

### `shared/config.lua`

| Option | Default | Description |
|---|---|---|
| `Config.NpcModel` | `cs_fishcollector` | Ped model used for every fishmonger |
| `Config.SpawnDistance` | `50.0` | Distance at which NPCs spawn and despawn |
| `Config.TargetDistance` | `2.5` | rsg-target interaction range |
| `Config.MaxUseDistance` | `5.0` | Distance at which the menu closes itself. The server allows 1.5 m extra to cover lag |
| `Config.Cooldown` | `2000` | Milliseconds between trades per player (anti-spam) |
| `Config.MoneyType` | `'cash'` | Payout type: `'cash'`, `'bank'` or `'bloodmoney'` |
| `Config.FilletItem` | `'raw_fish'` | Item given when processing |
| `Config.ImagePath` | `nui://rsg-inventory/html/images/` | Where item images are loaded from |
| `Config.AllowPushToTalkWhileOpen` / `Config.PushToTalkControls` | on | Keep push-to-talk working while the menu is open (all other game controls are blocked) |
| `Config.ItemHints` | `true` | Add "sells for about $x" to each fish's description |
| `Config.BanOnTamper` | `false` | Ban a player who sends a request the menu can never produce (invalid mode, malformed cart). Check your logs before turning this on |
| `Config.Blip` | enabled | `enabled`, `sprite`, `style`, `scale`, `openColor`, `closedColor` (blip colour while open / closed, only used with opening hours). The blip name comes from the locale key `cl_blip_name` |

| `Config.OpeningHours` | off | `enabled`, `open`, `close` (in-game hours). `close` lower than `open` wraps past midnight |
| `Config.Demand` | on | `enabled`, `min`, `max`: daily sell-price multiplier per town |
| `Config.Bonus.jobs` | empty | `{ jobname = 0.10 }` gives +10% to players whose current job matches |
| `Config.Bonus.rep` | on | `name` (rsg-core rep key), `perPoint`, `max` bonus, `gainPerFish` rep earned |
| `Config.DailyStock` | on, 200 | `perLocation` fish each town buys. `recoveryPerHour` (default 20) fish come back every real hour; `0` resets the count at midnight instead. Processing is not limited |
| `Config.Quality` | on | `size` (`perKg`, `max`) and `freshness` (`min`) bonuses read from the fish's item info |
| `Config.Contracts` | on | Daily orders: `perLocation`, `minQty`, `maxQty`, `payMultiplier`, `repReward`, `xpReward`. A location can set `orders = false` |
| `Config.FilletSale` | on | `items = { raw_fish = 0.30 }`: fillets that can be sold back, with the price per fillet |
| `Config.Shop` | on | `enabled`, `persistentStock`, `skill`, `items` (`name`, `price`, `amount`) and `tiers` (`level`, `items`). Bait names match rsg-fishing |

The sale price is `base price x quality x demand x (1 + bonus)`, worked out on the server, where *quality* is each fish's own size and freshness bonus.

#### Fish quality

Each fish is its own item with its own info. Size is `info.weight` (kg): `+Config.Quality.size.perKg` per kg, up to `+size.max`. Freshness is `info.quality` (0-100, which only exists when rsg-inventory decay is switched on): 100 pays full price and 0 pays `freshness.min` of it. Fish are sold in inventory slot order, and the menu uses the same order for its preview. Set `Config.Quality.enabled = false` for flat prices.

#### Daily orders

Every real day each town posts `Config.Contracts.perLocation` orders such as "6 x Smallmouth Bass". They are picked from `Config.Fish` and are the same for every player. A player can deliver each order once a day for `fish price x quantity x payMultiplier`, plus fishing rep and XP. Delivered orders are kept in `rsg_fishmonger_orders` and cleared the next day.

#### Fillet market

Anything in `Config.FilletSale.items` can be sold in the menu (shown with a **Fillet** tag). Fillets are not counted against the town's stock and give no rep. **Keep the price per fillet below the fish it came from**, otherwise processing and selling becomes a money loop. The defaults are safe: the best fish gives 5 fillets worth $1.50, against a fish price of $4.00.

#### Supplies shop tiers

`Config.Shop.items` is always for sale. Each entry in `Config.Shop.tiers` adds more stock once the player's `Config.Shop.skill` level (rsg-skills) reaches its `level`. Tiers stack, and a hint tells the player what the next tier needs. Without rsg-skills only the base list is sold.

#### Locations

```lua
Config.Locations = {
    { key = 'saint_denis', coords = vector4(2661.74, -1506.05, 45.96, 321.56) },
    -- ...
}
```

Optional per-location overrides: `hours = { open = 8, close = 18 }`, `stock = 300` (`0` = unlimited), `demand = false` (always base price).

`key` points to the locale entry `loc_<key>`, which holds the location's display name. **To add a location**, add a new line with a unique key and add `"loc_<key>": "Name"` to **every** file in `locales/`.

#### Fish

```lua
Config.Fish = {
    ['a_c_fishbluegil_01_sm'] = { price = 0.40, fillets = 1 },
    -- ...
}
```

| Field | Description |
|---|---|
| `price` | Money paid per fish when selling |
| `fillets` | Amount of fillets given per fish when processing |
| `fillet` | *(optional)* Item given instead of `Config.FilletItem` for this fish, e.g. `'salmon_fillet'` |

Fish names come from each item's `label` in rsg-core shared items, so they follow your items file.

### `server/sv_config.lua` (Discord webhooks)

This file is **server-only** and is never sent to players, so your webhook URLs stay private. Don't move these settings into `shared/config.lua`.

| Option | Description |
|---|---|
| `enabled` | Turns all webhook logging on or off |
| `username` / `avatar` / `footer` / `serverName` | Embed branding |
| `mentionOnAlert` | Ping on suspicious activity, e.g. `'<@&ROLE_ID>'` |
| `urls.sales` | Fish sold for money |
| `urls.processing` | Fish processed into fillets |
| `urls.suspicious` | Possible exploit attempts, spam and large trades |
| `urls.errors` | Failed or reversed transactions and script errors |
| `urls.system` | Resource start |
| `colors` | Embed colour per channel |
| `largeSaleAlert` | Sales at or above this value also alert the suspicious channel (`0` = off) |
| `largeProcessAlert` | Processing at or above this many fish also alerts (`0` = off) |
| `showIdentifiers` | Which identifiers to include: `license`, `discord`, `steam`, `ip` |
| `sendInterval` / `maxQueue` | Rate-limit queue tuning |

Leave any URL as `''` to turn that log off. You can point several channels at the same URL.

Suspicious alerts are limited to one per player every 5 seconds.

**The suspicious channel catches:** an invalid checkout mode, a trade attempted away from an NPC, a malformed cart, invalid or unknown items, more fish than the player owns, 5 requests blocked by the cooldown, and large sales or processing runs.

### Locales (`locales/*.json`)

All player-facing text, menu text and webhook text lives here. Keys use these prefixes:

| Prefix | Used for |
|---|---|
| `cl_` | Client text (target label, title, blip) |
| `loc_` | Location names |
| `ui_` | Menu text. `{name}` placeholders are filled in by the menu |
| `sv_` | Server notifications. `%s` placeholders |
| `wh_` / `cmd_` | Discord logs and command help |

To add a language, copy `en.json` to `<code>.json`, translate the values, and set `setr rsg:locale "<code>"`. Keep every key and placeholder.

---

## How to use

### Players

1. Travel to any fishmonger. Look for the fishing blip on the map.
2. Aim at the NPC with rsg-target and choose **Talk to Fishmonger**, or **Browse Fishing Supplies** to buy bait.
3. In the menu:
   - Use **Search** or **Owned only** to find your fish.
   - Pick a quantity and click **Add**, or click **All** to add every fish of that type. **Add All To Cart** adds every fish currently shown.
   - Adjust or remove fish in the **Cart** panel on the right. The totals update as you go.
4. Click **Sell For Cash** or **Process Into Fillets** (or **Sell All Owned**), then confirm. Check the demand and stock at the top of the cart first.
5. A notification confirms what you received.

### Admins

| Command | Permission | Description |
|---|---|---|
| `/fishmonger_webhooktest` | `admin` (or server console) | Sends a test message to every configured webhook channel |

---

## File structure

```
rsg-fishmonger/
├── client/client.lua        # NPCs, blips, target, NUI bridge
├── server/
│   ├── sv_config.lua        # server-only config (webhooks)
│   ├── webhook.lua          # Discord logger & queue
│   ├── server.lua           # validated sell / process logic
│   └── versionchecker.lua
├── shared/config.lua        # general config, locations, fish, shop
├── shared/utils.lua         # fillet helper
├── install.sql              # stock + orders tables (manual install)
├── html/                    # NUI (index.html, style.css, script.js)
├── locales/                 # en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru
└── fxmanifest.lua
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| NPC not showing | Check that `rsg-target` is started, and that you are within `Config.SpawnDistance` |
| Fish missing from the menu | The item must exist in shared items. Check the console for warnings on startup |
| "You do not have enough inventory space" | Processing needs room for the fillets. Free up space and try again |
| Text shows as a key, e.g. `ui_sell` | The key is missing from your locale file. Copy it from `en.json` |
| Webhooks not posting | Check the URLs in `sv_config.lua`, run `/fishmonger_webhooktest` and look for `webhook failed (HTTP …)` in the console |
| Can't talk while the menu is open | Make sure `Config.AllowPushToTalkWhileOpen = true` and that your push-to-talk control is listed in `Config.PushToTalkControls` |
| Items sell for less than expected | Quality applies: small or old fish pay less. Check `Config.Quality`, or turn it off |
| Order panel missing | `Config.Contracts.enabled`, and the town must not have `orders = false` |
| Shop has no lures | The tier needs rsg-skills started and the fishing level in `Config.Shop.tiers` |
| Map blip never changes colour | Only works with `Config.OpeningHours.enabled = true` |
| Images missing | Check `Config.ImagePath` and that `<item>.png` exists |

---

## Credits

- **RexShack / Rexshack-RedM**: [github.com/Rexshack-RedM](https://github.com/Rexshack-RedM)

---

## Changelog

### 3.3.1
- Final review: no code changes needed. DOCS.md is now a complete reference with code examples.

### 3.3.0
- New: fish quality (size and freshness), daily orders, fillet market, supplies shop tiers by fishing level, closed-town blips, gradual stock recovery, sell hint on fish items, optional tamper bans. Adds the `rsg_fishmonger_orders` table and an `updated` column on the stock table (automatic; see the database note below).

### 3.2.1
- Fixes: menu lock-up after a refused checkout, closed-hours check now server-only, price preview includes rsg-economy tax, optional integrations can no longer break the menu, oversized carts rejected, webhook flood limit and no embed pings.
- Added push-to-talk while the menu is open, `Config.Blip.scale`, and `ensureDatabase()` console messages. Removed unused code.

### 3.2.0
- Daily stock is now saved in the `rsg_fishmonger_stock` table instead of resource KVP, so the server no longer creates a `db` folder. Adds the `oxmysql` dependency and `Config.AutoDatabase`. Today's sold counts from before the update are not migrated.

### 3.1.0
- Optional rsg-skills integration: fishing `sell_bonus` perk adds to the seller bonus (`Config.Bonus.skill`).

### 2.2.0
- Daily demand per town, reputation/job seller bonus and daily stock limits.
- Fishing supplies shop on every fishmonger NPC.
- Per-fish fillet items and optional opening hours.
- Menu stays open on a failed trade; added Sell All Owned and Enter to confirm.

### 2.1.0
- Removed the ox_lib dependency: locales, callbacks, notifications and the admin command now use rsg-core.
- Switched from ox_target to rsg-target.
- Fixed duplicate inventory pop-ups after a trade (rsg-inventory already shows them).
- NUI focus is now released cleanly when the resource stops.

---

## rsg-economy integration (optional)
When `rsg-economy` is started and `Config.Economy.Enabled = true`, the sale total (after demand and bonus) is taxed by the location's town and scaled by the player's standing there (hated pays less, celebrated pays more). The tax goes to the town treasury. Processing is unaffected. The menu preview and confirm pop-up include this, so the amount shown matches the payout.

## rsg-skills integration

Optional. With `rsg-skills` started, the player's fishing `sell_bonus` perk is added to the seller bonus when selling fish (`Config.Bonus.skill`). The bonus shown in the shop UI includes it. Set `Config.Bonus.skill.enabled = false` to turn it off.


Support the Project : https://rexshack.tebex.store/
