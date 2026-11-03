# rsg-stores

**Version 3.1.0** · requires rsg-core, rsg-inventory, rsg-target, rsg-gizmo, oxmysql (no ox_lib)

Create NPC shopkeepers, **player-owned stores**, shops and map blips in-game for **RSG-Core (RedM)**, all from an admin menu with no config editing. Players buy with a cart or sell straight back to the shop through a themed NUI. Every transaction is checked on the server and can be logged to Discord.

Full developer and server-owner reference: **[DOCS.md](DOCS.md)**.

---

## Features

### For players
- **Shop UI**: dark leather-and-gold RDR2-style interface.
- **Buy mode**: item grid with search, sort (name / price ↑ / price ↓), stock bars, and a cart for buying several items in one purchase.
- **Sell mode**: lists only the items you hold that this shop accepts, with the payout and shop fee shown.
- **Quick quantity** buttons (1 / 5 / 10 / 25 / MAX). Right-click an item to remove one from the cart.
- **Live updates**: cash, inventory and stock refresh while the shop is open.
- **Auto-close** when you walk away or die.
- NPCs **fade in and out** as you approach and leave.

### For admins (`/createshop`)
- **Shop Manager panel:** a themed NUI panel (no ox_lib menus) for creating and editing NPCs, shops and blips in one form.
- **NPCs:** create at your position (snapped to the ground), edit, teleport to, duplicate or delete.
- **Shop contents:** searchable item picker with images; edit price and stock inline.
- **Shop types:** Buy & Sell, Buy only, Sell only, or a plain NPC with no shop.
- **Blips:** create, recolour, duplicate, show or hide, and delete. Shop blips are linked to their NPC and move with it.
- **Presets:** add, edit or remove the NPC models and blip types offered in the dropdowns, in-game. They are saved to the database, so no config editing or restart is needed.
- Everything saves to MySQL immediately and syncs live to every player.

### Player-owned stores (new in 2.2.0)
- Admins choose **Run By: NPC Shopkeeper** or **Run By: Player Owner** when creating a store. Owned stores have no NPC: customers use a counter target zone at the store position.
- Admins assign the owner from a dropdown of **online players**, change or remove the owner at any time.
- The owner targets the counter → **Manage Store** to open the management panel:
  - **Shelves**: restock from their bag, take stock back, set prices, remove listings (remaining stock is returned).
  - **Add Stock**: put any stockable item from their inventory on the shelf at a price they choose.
  - **Till**: every sale goes into the store till; withdraw an amount or everything as cash.
  - **Settings**: change the shop sign and whether the counter buys, sells or both.
- Customers selling to an owned store are paid from the till (`Config.OwnedStores.BuyBackPercentage` of the owner's price), and the items go onto the shelf.
- Stock is always limited and comes only from the owner: nothing is created from thin air. Money items, unique items and weapons cannot be stocked.
- A store with no owner shows as **(Closed)** to customers. Stock and till stay with the store when the owner changes.

### Store staff (new in 3.1.0)
- Owners hire players to help run their store: **Manage Store → Staff → Hire Nearby** lists players standing next to the owner.
- Each staff member gets their own access level. Pick a **rank** preset (Clerk, Stock Hand, Supervisor, Manager) or **Custom** and tick permissions one by one:

| Permission | Lets staff |
|---|---|
| `restock` | Put items from their own bag on the shelves |
| `takestock` | Take items off the shelves into their bag |
| `prices` | Change prices and remove listings (removing also needs `takestock`) |
| `wholesale` | Order wholesale stock (paid as `Config.Wholesale.PayFrom`) |
| `till` | Withdraw from the till (optional daily limit) |
| `ledger` | View the sales ledger |
| `settings` | Change the shop sign name and counter type |
| `upkeep` | Pay owed upkeep |

- The owner can change a staff member's access or **Let Go** (click twice) at any time, online or offline. Staff can **Leave Job** from their Staff tab.
- Staff target the store → **Manage Store** and only see the tabs and buttons they're allowed. Every action is checked again on the server.
- Staff can **never** buy from or sell to the store they work at, pack it up, move it, or hire others. All staff actions are logged in the ledger (under their name) and to the `owners` Discord channel.
- Staff are removed automatically when the store is packed up, deleted, evicted, repossessed or given a new owner.

### Shop sign item
- Admins give a player the **`shopsign`** item (e.g. `/giveitem [id] shopsign 1`).
- Using it opens the standard **rsg-gizmo** placement tool: the player positions and turns the sign, confirms, then names the store and chooses the counter type.
- The sign (`p_sandwichboard02x` by default) is placed and the player becomes the owner of a new player-owned store, with a map blip.
- Customers target the **sign** to trade; the owner targets the same sign → **Manage Store**.
- Owners can **Pick Up & Move Store** (target the sign, or the Settings tab in Manage Store): the sign goes back in their inventory and the store disappears from the world. Using the sign again places the *same* store at the new spot. Name, counter type, stock, prices, till and ledger are all kept, no setup needed. Upkeep is paused while it's picked up.
- Owners can **Pack Up Store** (Settings tab) once the shelves are empty: the till is paid out and the sign comes back.
- Limits: `Config.ShopSign.MaxPerPlayer` stores per character, `MinSpacing` from other stores.

### Security
- **Server-side checks:** the server sets all prices and totals, and ignores any amounts the client sends.
- **Range check:** players must be standing at the shop NPC to buy or sell.
- **Quantities:** whole numbers only, 1–1000 per line and at most 100 lines per cart.
- **Stock:** decremented atomically so two players can't oversell. Stock is rolled back and money refunded if any step fails.
- **Rate limit:** each player can make one transaction every 750 ms.
- **Admin events:** every admin event is permission-checked on the server, and admin input is cleaned before it's saved.
- **Webhook security:** webhook URLs live in a server-only file and are never sent to clients.
- **Item quality:** worn or spoiled stacks (below `Config.OwnedStores.MinQuality`) can't be sold to any shop or put on a shelf, so they can't be swapped for fresh items.
- **Staff:** permission-checked on the server per action; staff can't trade with their own store (stops price-setting staff buying stock at $0 or draining the till by selling at a high price).

### New in 3.0.0
- **Shopkeeper speech**: NPC shopkeepers greet you, thank you after a purchase and say goodbye (lines from the RDR2 decompiled `shop_general` script).
- **Opening hours**: shops follow the in-game clock, with per-shop overrides and hours that can wrap past midnight.
- **Job and gang discounts** on NPC shop purchases. The server works out the price; players see the discounted prices and get a notice.
- **Upkeep (rent) for sign stores**: taken from the till each period. If it's unpaid the store closes to customers until the owner pays, and it is repossessed after a set number of unpaid periods.
- **Wholesale**: owners order stock from a supplier straight onto their shelves, paid from the till or their cash.
- **Sales ledger**: owners see recent sales, buy-ins, wholesale orders, upkeep and withdrawals.
- **Admin eviction**: one button gives the stock, till and sign back to an online owner (or forfeits them if the owner is offline and you tick the box).

### Discord logging
- Five channels: **purchases, sales, admin, security, system**.
- Messages are queued and batched, and back off automatically when Discord rate-limits.
- Each message shows the player's character name, CitizenID, and Discord mention.
- Admin edits show a before → after list of changes.
- Security alerts can ping a role, and large transactions are flagged.

### Other
- **Auto database install**: tables are created and upgraded on start.
- **10 languages**: en, de, el, es, fr, ja, nl, pl, pt-br, ro. This covers the UI, menus, notifications, config labels and webhooks.

---

## Requirements

| Resource | Notes |
|---|---|
| [rsg-core](https://github.com/Rexshack-RedM/rsg-core) | Framework |
| [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) | Must provide `AddItem`, `RemoveItem`, `CanAddItem` and `GetItemCount` exports |
| [rsg-target](https://github.com/Rexshack-RedM/rsg-target) | NPC and store counter interaction |
| [oxmysql](https://github.com/overextended/oxmysql) | Database |

---

## Installation

1. Put the `rsg-stores` folder in your server's `resources` folder, for example `resources/[rsg]/rsg-stores`.
2. Add it to `server.cfg` **after** its dependencies:
   ```cfg
   ensure oxmysql
   ensure rsg-core
   ensure rsg-target
   ensure rsg-inventory
   ensure rsg-stores
   ```
3. Start the server. The database tables are created automatically, and the console shows:
   ```
   [rsg-stores] Created table `rsg_shops_npcs`.
   ...
   [rsg-stores] Database installed/updated (4 change(s)).
   ```
   To install manually instead, set `Config.AutoInstallDatabase = false` and import `install/rsg-stores.sql`. `install/example.sql` has optional sample data.
4. *(Optional)* Add your Discord webhook URLs to `server/sv_webhooks_config.lua` (see below).
5. Join the game as an admin and type **`/createshop`**.

### Updating from an older version
Replace the files and restart. 3.0.0 adds `upkeep_owed` and `upkeep_next` to `rsg_shops_npcs` and a new `rsg_shops_ledger` table. These are added automatically; for a manual install, run the new `CREATE TABLE` and the `ALTER TABLE` lines at the bottom of `install/rsg-stores.sql`. The auto-installer adds any missing columns or indexes (2.2.0 adds `store_kind`, `owner_citizenid`, `owner_name` and `balance` to `rsg_shops_npcs`) and keeps your existing shops, items and blips. Existing shops stay NPC shops. Manual installs: run the `ALTER TABLE` lines at the bottom of `install/rsg-stores.sql`. On first start after updating, the new presets table is filled from your `Config.NpcModels` and `Config.BlipTypes`, so your current dropdown options carry over.

---

## Configuration

### `shared/config.lua`

| Option | Default | Description |
|---|---|---|
| `Config.AdminPermission` | `'admin'` | RSG permission required for `/createshop` and every admin event |
| `Config.AutoInstallDatabase` | `true` | Create and upgrade tables on start |
| `Config.DefaultScenario` | `'WORLD_HUMAN_STAND_IMPATIENT'` | Scenario the shopkeepers play |
| `Config.DistanceSpawn` | `20.0` | Distance at which NPCs spawn and despawn |
| `Config.FadeIn` | `true` | Fade NPCs in and out |
| `Config.SellPricePercentage` | `0.80` | Players get 80% of the shop price when selling (20% fee) |
| `Config.SellAddsStock` | `true` | Items sold to a shop go back into its stock (limited-stock items only) |
| `Config.MaxShopStock` | `100` | Most of any one item a shop will hold from player sales (`0` = no cap) |
| `Config.TargetDistance` | `2.5` | rsg-target interaction range. The server allows up to +5.0 to cover lag |
| `Config.OwnedStores.Enabled` | `true` | Allow player-owned stores |
| `Config.OwnedStores.ZoneRadius` | `1.2` | Size of the counter target zone |
| `Config.OwnedStores.BuyBackPercentage` | `0.80` | Share of the owner's price paid (from the till) to customers selling to the store |
| `Config.OwnedStores.MaxListings` | `50` | Most different items one store can list |
| `Config.OwnedStores.MaxStock` | `500` | Most of one item a store can hold (`0` = no cap) |
| `Config.OwnedStores.MaxPrice` | `10000` | Highest price an owner can set |
| `Config.OwnedStores.NotifyOwner` | `true` | Notify an online owner of each sale or buy-back |
| `Config.OwnedStores.MinQuality` | `75` | Stacks below this quality can't be stocked or sold to any shop (`0` = off) |
| `Config.Staff.Enabled` | `true` | Owners can hire staff |
| `Config.Staff.MaxStaff` | `5` | Staff per store |
| `Config.Staff.MaxJobsPerPlayer` | `2` | Stores one character can work at (`0` = no limit) |
| `Config.Staff.HireDistance` | `5.0` | The player being hired must stand this close to the owner |
| `Config.Staff.DailyWithdrawLimit` | `0` | Most one staff member can take from the till per real day (`0` = no limit). Owners have no limit |
| `Config.Staff.Ranks` | 4 presets | `{ name, perms = { ... } }` quick presets; label is locale key `ui_rank_<name>` |
| `Config.OwnedStores.BlacklistItems` | money items | Items owners can never stock (unique items and weapons are always refused) |
| `Config.ShopSign.Enabled` | `true` | Allow the shop sign item |
| `Config.ShopSign.Item` | `'shopsign'` | Item name |
| `Config.ShopSign.Model` | `'p_sandwichboard02x'` | Sign prop |
| `Config.ShopSign.MaxPerPlayer` | `1` | Sign stores one character can own (`0` = no limit) |
| `Config.ShopSign.MinSpacing` | `8.0` | Minimum distance from any other store |
| `Config.ShopSign.PlaceDistance` | `1.5` | Base reach for the gizmo (max distance = this + 2.5 m, capped at 4 m) |
| `Config.ShopSign.DefaultType` | `'buy'` | Starting counter type |
| `Config.ShopSign.ReturnOnPackUp` | `true` | Give the sign back on pack up |
| `Config.ShopSign.AllowMove` | `true` | Owners can pick up their sign store and re-place it elsewhere, keeping everything |
| `Config.ShopSign.Blip` | general store, white | Blip created for each sign store (`Enabled = false` for none) |
| `Config.ShopSign.ItemDefinition` | table | Registered in rsg-core at start if `shopsign` isn't in your items list |
| `Config.ShopSign.Upkeep` | `{ Enabled = true, Amount = 5.0, IntervalHours = 24, EvictAfterMissed = 3 }` | Sign store rent, taken from the till. Unpaid upkeep closes the store; after `EvictAfterMissed` unpaid periods the store is repossessed (stock and till lost) |
| `Config.Speech` | `Enabled = true`, `WELCOME` / `THANKS` / `GOODBYE_POS` | Shopkeeper speech lines (set a line to `false` to skip it) and the speech params hash |
| `Config.OpeningHours` | `Enabled = false`, 7–21 | In-game opening hours. `OwnedStores` also applies them to player stores; `Shops['shop_id'] = { Open, Close }` overrides one shop |
| `Config.Discounts` | `Enabled = false` | `Jobs` / `Gangs` maps of name → discount (0.10 = 10%), capped by `MaxDiscount`. NPC shops only. Discounted players also get the same discount off what NPC shops pay them, so a discount can't be farmed by buying and selling back |
| `Config.Wholesale` | `Enabled = true` | `Items` maps item → cost each. `PayFrom` is `'till'`, `'cash'` or `'either'`; `Markup` sets the default shelf price for new listings |
| `Config.Ledger` | `Enabled = true, Keep = 100, Show = 50` | Owner ledger: entries kept per store and shown in the panel |
| `Config.BlipTypes` | list | Starting blip sprites, copied into the presets table on first start |
| `Config.NpcModels` | list | Starting ped models, copied into the presets table on first start |
| `Config.BlipColors` | list | Blip colours offered in the menu |

**NPC models and blip types** are managed in-game on the **Presets** tab (see [Managing presets](#managing-presets)). The two config lists are only used to fill the presets table the first time it is created. Later changes to them are ignored unless you empty the `rsg_shops_presets` table.

**Adding a colour** (or a default model or blip type for fresh installs): the `label` must be a locale key, and that key must exist in the locale files.
```lua
-- shared/config.lua
{ label = 'cfg_model_sheriff', value = 's_m_m_valsheriff_01' },
```
```json
// locales/en.json (and the other languages)
"cfg_model_sheriff": "Sheriff",
```

### `server/sv_webhooks_config.lua` (server only)

| Option | Description |
|---|---|
| `Enabled` | Master switch |
| `BotName` / `AvatarUrl` | Name and avatar shown on Discord messages |
| `Urls.purchases` | Cart purchases and refunds |
| `Urls.sales` | Items sold to shops |
| `Urls.admin` | NPC, shop, blip and preset create / edit / delete (with a list of changes) |
| `Urls.owners` | Player-owned store actions: stocking, taking stock, prices, listings, settings, till withdrawals |
| `Urls.security` | Executor attempts, out-of-range trades, malformed data, large transactions |
| `Urls.system` | Resource start, database install, database failures |
| `SecurityPing` | Role or user to ping on security alerts, e.g. `'<@&123456789012345678>'` |
| `LargeTransaction` | Cash amount that flags a transaction as "Large" and copies it to security |
| `ShowIdentifiers` | Which identifiers to show: `license`, `discord`, `steam`, `ip` |
| `FlushInterval` / `EmbedsPerPost` / `MaxQueue` | Queue tuning (the defaults are fine) |

Leave any URL as `''` to turn that channel off. You can point several channels at the same webhook.

**Test it** from the server console:
```
storeswebhooktest
```

### Language
Set the locale in `server.cfg`:
```cfg
setr rsg:locale "de"
```
(`ox:locale` still works as a fallback.)
Available: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

---

## Usage

### The Shop Manager panel
`/createshop` opens the **Shop Manager**, a panel docked on the right of the screen so you can still see the world. It has three tabs, **Shops**, **Blips** and **Presets**, each with a search box and a list. Click any row to edit it. Press **Esc** to go back one step or close the panel.

### Creating a shop
1. Stand where the shopkeeper should be, facing the way they should face.
2. `/createshop` → **New Shop**. The position fields fill in from where you're standing (at ground level). Click **Use My Position** at any time to refresh them.
3. Enter a name and pick a model.
4. Leave **This NPC is a shopkeeper** ticked, then enter a **Shop ID** (internal, e.g. `valentine_general`), a **Shop Label** (e.g. *Valentine General Store*) and the shop type.
5. **Add Item** opens a searchable list of every shared item (items already in the shop are greyed out). Pick one, then set its **price** and **stock** in the table. Leave stock empty for unlimited.
6. *(Optional)* Tick **Create a blip for this shop?** and choose the name, icon and colour. The name follows the shop label unless you change it.
7. Click **Create**. The NPC appears for everyone straight away.

### Creating a player-owned store
1. Stand at the store counter. `/createshop` → **New Shop**.
2. Under **Run By**, choose **Player Owner**. The model, item list and "shopkeeper" options disappear: the owner handles stock.
3. Enter a name, **Shop ID**, **Shop Label** and type.
4. *(Optional)* Pick the owner from the **Assign Owner** dropdown, which lists every online player (name, server ID and citizenid) and is searchable. You can leave it empty and assign later; until then the store shows as closed.
5. *(Optional)* create a blip, then **Create**.

To change the owner later, open the store, pick a new player from the dropdown (or tick **Remove current owner**) and **Save**. Stock and till stay with the store. Switching a store between NPC and player-owned clears its stock and till (the till amount is logged).

### Opening a store with a shop sign (players)
1. Get a **Shop Sign** from an admin and use it from your inventory.
2. The **rsg-gizmo** placement tool opens with a see-through sign (green = valid, red = invalid):

   | Key | Action |
   |---|---|
   | Look around | Free mode: the sign follows where you look and sits on the ground |
   | Mouse wheel / ← → | Turn the sign |
   | R | Switch Free / Fine mode (Fine: arrows move, wheel changes height) |
   | Ctrl (hold) | Precision |
   | G | Snap to ground |
   | LMB / Enter | Confirm the position |
   | RMB / Backspace | Cancel (the sign stays in your inventory) |

3. Enter a store name, choose the counter type and click **Open Store** (or **Reposition** to go back). The sign is used up.
4. Target your sign → **Manage Store** to stock it. Customers target the sign to shop.

**Item:** add `shopsign` to your rsg-core items if you want your own label/image (it is registered automatically otherwise) and put a `shopsign.png` in `rsg-inventory/html/images/`:
```lua
shopsign = { name = 'shopsign', label = 'Shop Sign', weight = 2000, type = 'item', image = 'shopsign.png', unique = false, useable = true, shouldClose = true, description = 'Place it to open your own store' },
```

### Running your store (owners)
Target the counter → **Manage Store**.

| Tab | What it does |
|---|---|
| Till (top) | Shows takings. Enter an amount and **Withdraw**, or **All** |
| Shelves | Each listing: **+** restock from your bag, **−** take back, **tag** set price, **bin** remove listing (stock comes back to you) |
| Add Stock | Your stockable items; pick one, choose quantity and price, **Stock** |
| Settings | Shop sign and whether the counter buys, sells or both. Sign stores also get **Pick Up & Move** and **Pack Up Store** (both click twice) |
| Staff | Owner: **Hire Nearby**, change each member's rank / permissions and **Save**, or **Let Go**. Staff: see your access and **Leave Job** |

You must stand at the counter, and you need room in your inventory to take stock back.

### Editing an NPC
Click an NPC in the list to open the same form. You can change any field, edit prices and stock in place, add or remove items, then **Save**. A linked blip moves with the NPC. The footer buttons let you **Teleport** to it, **Duplicate** it at your position (with its shop and blip, and separate stock) or **Delete** it (with a confirmation; linked blips are deleted too).

### Managing blips
On the **Blips** tab, **New Blip** creates one at your position. Click a blip to rename it or change its icon, colour or position. The footer buttons let you **Teleport**, toggle **Visibility** (only on your map), **Duplicate** at your position or **Delete**.

### Managing presets
The **Presets** tab lists every option in the **NPC Model** and **Blip Type** dropdowns. Changes appear in the dropdowns as soon as you save.

- **Add:** click **New Preset**, choose the type, then enter:
  - **Value:** for an NPC model, the ped name (e.g. `u_m_m_valgunsmith_01`; letters, numbers and underscores). For a blip type, the sprite hash (e.g. `1475879922`) or the sprite name (e.g. `blip_shop_store`), which is converted to the hash for you.
  - **Label** *(optional)*: the name shown in the dropdown. If left blank, the value is used.
- **Edit:** click a preset to change its type, label or value, then **Save**.
- **Remove:** open a preset and click **Delete**. This only removes it from the dropdown. NPCs and blips already using it keep working, and their editor still shows the current value.

Duplicates and invalid values are rejected. Every change is permission-checked on the server and logged to the admin webhook.

### Stock
- Stock goes down with each purchase.
- Selling to a shop adds the items back to its stock when `Config.SellAddsStock` is on (limited-stock items only). The shop refuses sales that would push stock past `Config.MaxShopStock`.
- To restock, use **Add Items** with the same item and the new stock amount.
- Items loaded from the database with no stock value (NULL) are unlimited and show as **∞**. Stock set in the admin menu is always a number.

### Player controls
| Action | How |
|---|---|
| Open shop | Target the shopkeeper (or store counter) → *Open Store* |
| Add to cart | Click an item, pick a quantity, **Add to Cart** |
| Remove one from cart | Right-click the item |
| Buy | **Purchase** |
| Sell | **Sell** tab, click an item, pick a quantity, **Confirm Sale** |
| Close | **Esc**, the close button, or walk away |

---

## For developers

**Send your own log through the rsg-stores queue:**
```lua
exports['rsg-stores']:SendWebhook('admin', 'Title', 'Description', source, {
    { name = 'Field', value = 'Value', inline = true },
})
```

**Database tables:**

| Table | Purpose |
|---|---|
| `rsg_shops_npcs` | NPC/store position, model, shop settings, `store_kind`, owner and till `balance` |
| `rsg_shops_items` | Items per NPC (`npc_id`), with price and stock |
| `rsg_shops_blips` | Blips, optionally linked to an NPC (`associated_npc_id`) |
| `rsg_shops_presets` | Dropdown options: `kind` (`model` / `blip`), `label`, `value` |

**File layout:**
```
rsg-stores/
├── fxmanifest.lua
├── client/client.lua             NPC spawning, shop NUI bridge, admin menu
├── server/
│   ├── sv_webhooks_config.lua    Discord settings (server only)
│   ├── sv_webhooks.lua           Webhook queue
│   ├── sv_database.lua           Auto installer / migrator
│   ├── server.lua                Transactions, admin events, cache
│   └── versionchecker.lua        Update check on start
├── shared/config.lua             General settings
├── html/                         NUI: shop (script.js, style.css), Shop Manager (admin.js, admin.css),
│                                 owner management (manage.js, manage.css)
├── locales/*.json                10 languages
└── install/
    ├── rsg-stores.sql            Manual install (optional)
    └── example.sql               Sample shop data (optional)
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `Database retry…` in the console | The database user needs `CREATE` / `ALTER` rights, or set `AutoInstallDatabase = false` and import the SQL |
| `/createshop` says access denied | Give yourself the permission in `Config.AdminPermission` (e.g. `add_principal identifier.license:xxx group.admin`) |
| "You are too far from the shop" | Stand next to the NPC. If you've moved the NPC, check its coordinates are at ground level |
| "The shop only has room for …" when selling | The item has reached `Config.MaxShopStock`. Raise the cap, set it to `0`, or turn off `Config.SellAddsStock` |
| NPC doesn't appear | Check the model name is valid. Invalid models are logged in the F8 console. Fix or remove bad model presets on the **Presets** tab |
| Config model/blip changes don't show | The dropdowns come from the **Presets** tab after first start. Add them there instead |
| Item images missing | Images come from `rsg-inventory/html/images/`; a fallback icon is shown if the image is missing |
| No Discord messages | Check the URLs, then run `storeswebhooktest` |
| Raw key such as `cfg_model_x` shows | That key is missing from `locales/en.json` |
| "No player with that server ID is online" | The new owner must be online when assigned. Check the ID with your admin menu |
| Owner doesn't see **Manage Store** | The store's owner citizenid must match the character they're on. Re-assign it from `/createshop` |
| Staff member doesn't see **Manage Store** | They must be on the character that was hired. Ask them to relog, or let go and hire again |
| "That item is too worn or spoiled to trade" | The stack's quality is under `Config.OwnedStores.MinQuality`. Lower it or set `0` to turn the check off |
| Customer sale refused with "not enough money in the till" | The owned store's till can't cover the buy-back. The owner needs sales first, or set the counter to Buy only |

---

## Changelog
### 3.1.0
- Target option renamed from "Trade with …" to "Open Store" (NPC shops and player stores).
- Added store staff: owners hire nearby players with rank presets or custom per-permission access (restock, take stock, prices, wholesale, till, ledger, settings, upkeep), optional daily till withdrawal limit, fire / leave job. New table `rsg_shops_staff`.
- Exploit fix: buying from a store while it was picked up (hidden) was still possible with an injected event.
- Exploit fix: worn / spoiled items could be sold or stocked at full value and come back out fresh. Stacks below `Config.OwnedStores.MinQuality` are now refused, and only clean stacks are removed.
- Staff can't buy from or sell to the store they work at.
- Audit fixes: a shopkeeper ped could be left behind (not cleaned up) if you walked away while its model was loading; NPC and sign spawning no longer stalls the distance loop while models load.
- Sell and Add Stock lists merge split stacks into one row and leave out worn / spoiled stacks the server would refuse.
- Sign placement is also checked with `rsg-gizmo`'s `IsPlacementValid` on the server.
- Store / blip / stock sync requests are throttled per player.
- Staff rank picker uses buttons instead of a native dropdown (native dropdowns break in RedM's CEF).

### 3.0.1
- Fixed: a job/gang discount bigger than the shop fee let players buy from an NPC shop and sell straight back for profit. NPC shop sell prices now get the same discount.
- Added a start-up console warning (`price exploit: ...`) when an item can be bought (NPC shop or wholesale) for less than an NPC shop pays for it.
- Eviction no longer silently loses stock when the owner's inventory is full; lost lines are listed in the admin log.
- Placing or moving any store no longer closes every open shop or respawns every shopkeeper on the server; only changed peds and signs respawn.
- Code clean-up: all callbacks use one rsg-core wrapper, one character-name helper, consistent sign model fallback.

### 3.0.0
- Added shopkeeper speech, opening hours, job/gang discounts, sign store upkeep with repossession, wholesale ordering, an owner sales ledger and admin eviction.
- New table `rsg_shops_ledger`; new columns `upkeep_owed` and `upkeep_next`.

### 2.2.1
- Fixed: the shop NUI could stay locked ("processing") if a buy/sell was rate-limited or sent before the database loaded; the server now always replies.
- Fixed: item pop-ups showed twice on buy/sell (rsg-inventory already shows them).
- Fixed: sign targets could fail to come back after walking away and returning.
- Hardened: rate limit on owner price/settings changes, store names capped at 60 chars, sign placement rejects NaN coords and waits for the database.
- Cleanup: removed unused variables and global client functions.

## Credits
Original script by **Phil**. Security rewrite, webhooks, localisation, auto-install and player-owned stores for RSG-Core.

---

Support: https://buymeacoffee.com/rexshack
