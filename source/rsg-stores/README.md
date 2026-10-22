# rsg-stores

Create NPC shopkeepers, shops and map blips in-game for **RSG-Core (RedM)**, all from an admin menu with no config editing. Players buy with a cart or sell straight back to the shop through a themed NUI. Every transaction is checked on the server and can be logged to Discord.

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

### For admins (`/npcshops`)
- **Shop Manager panel:** a themed NUI panel (no ox_lib menus) for creating and editing NPCs, shops and blips in one form.
- **NPCs:** create at your position (snapped to the ground), edit, teleport to, duplicate or delete.
- **Shop contents:** searchable item picker with images; edit price and stock inline.
- **Shop types:** Buy & Sell, Buy only, Sell only, or a plain NPC with no shop.
- **Blips:** create, recolour, duplicate, show or hide, and delete. Shop blips are linked to their NPC and move with it.
- **Presets:** add, edit or remove the NPC models and blip types offered in the dropdowns, in-game. They are saved to the database, so no config editing or restart is needed.
- Everything saves to MySQL immediately and syncs live to every player.

### Security
- **Server-side checks:** the server sets all prices and totals, and ignores any amounts the client sends.
- **Range check:** players must be standing at the shop NPC to buy or sell.
- **Quantities:** whole numbers only, 1–1000 per line and at most 100 lines per cart.
- **Stock:** decremented atomically so two players can't oversell. Stock is rolled back and money refunded if any step fails.
- **Rate limit:** each player can make one transaction every 750 ms.
- **Admin events:** every admin event is permission-checked on the server, and admin input is cleaned before it's saved.
- **Webhook security:** webhook URLs live in a server-only file and are never sent to clients.

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
| [ox_lib](https://github.com/overextended/ox_lib) | Menus, dialogs, notifications, locales |
| [ox_target](https://github.com/overextended/ox_target) | NPC interaction |
| [oxmysql](https://github.com/overextended/oxmysql) | Database |

---

## Installation

1. Put the `rsg-stores` folder in your server's `resources` folder, for example `resources/[rsg]/rsg-stores`.
2. Add it to `server.cfg` **after** its dependencies:
   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure rsg-core
   ensure ox_target
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
5. Join the game as an admin and type **`/npcshops`**.

### Updating from an older version
Replace the files and restart. The auto-installer adds any missing columns or indexes and keeps your existing shops, items and blips. On first start after updating, the new presets table is filled from your `Config.NpcModels` and `Config.BlipTypes`, so your current dropdown options carry over.

---

## Configuration

### `shared/config.lua`

| Option | Default | Description |
|---|---|---|
| `Config.AdminPermission` | `'admin'` | RSG permission required for `/npcshops` and every admin event |
| `Config.AutoInstallDatabase` | `true` | Create and upgrade tables on start |
| `Config.DefaultScenario` | `'WORLD_HUMAN_STAND_IMPATIENT'` | Scenario the shopkeepers play |
| `Config.DistanceSpawn` | `20.0` | Distance at which NPCs spawn and despawn |
| `Config.FadeIn` | `true` | Fade NPCs in and out |
| `Config.SellPricePercentage` | `0.80` | Players get 80% of the shop price when selling (20% fee) |
| `Config.SellAddsStock` | `true` | Items sold to a shop go back into its stock (limited-stock items only) |
| `Config.MaxShopStock` | `100` | Most of any one item a shop will hold from player sales (`0` = no cap) |
| `Config.TargetDistance` | `2.5` | ox_target interaction range. The server allows up to +5.0 to cover lag |
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
setr ox:locale "de"
```
Available: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

---

## Usage

### The Shop Manager panel
`/npcshops` opens the **Shop Manager**, a panel docked on the right of the screen so you can still see the world. It has three tabs, **NPCs**, **Blips** and **Presets**, each with a search box and a list. Click any row to edit it. Press **Esc** to go back one step or close the panel.

### Creating a shop
1. Stand where the shopkeeper should be, facing the way they should face.
2. `/npcshops` → **New NPC**. The position fields fill in from where you're standing (at ground level). Click **Use My Position** at any time to refresh them.
3. Enter a name and pick a model.
4. Leave **This NPC is a shopkeeper** ticked, then enter a **Shop ID** (internal, e.g. `valentine_general`), a **Shop Label** (e.g. *Valentine General Store*) and the shop type.
5. **Add Item** opens a searchable list of every shared item (items already in the shop are greyed out). Pick one, then set its **price** and **stock** in the table. Leave stock empty for unlimited.
6. *(Optional)* Tick **Create a blip for this shop?** and choose the name, icon and colour. The name follows the shop label unless you change it.
7. Click **Create**. The NPC appears for everyone straight away.

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
| Open shop | Target the shopkeeper → *Trade with …* |
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
| `rsg_shops_npcs` | NPC position, model and shop settings |
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
├── html/                         NUI: shop (script.js, style.css) + Shop Manager (admin.js, admin.css)
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
| `/npcshops` says access denied | Give yourself the permission in `Config.AdminPermission` (e.g. `add_principal identifier.license:xxx group.admin`) |
| "You are too far from the shop" | Stand next to the NPC. If you've moved the NPC, check its coordinates are at ground level |
| "The shop only has room for …" when selling | The item has reached `Config.MaxShopStock`. Raise the cap, set it to `0`, or turn off `Config.SellAddsStock` |
| NPC doesn't appear | Check the model name is valid. Invalid models are logged in the F8 console. Fix or remove bad model presets on the **Presets** tab |
| Config model/blip changes don't show | The dropdowns come from the **Presets** tab after first start. Add them there instead |
| Item images missing | Images come from `rsg-inventory/html/images/`; a fallback icon is shown if the image is missing |
| No Discord messages | Check the URLs, then run `storeswebhooktest` |
| Raw key such as `cfg_model_x` shows | That key is missing from `locales/en.json` |

---

## Credits
Original script by **Phil**. Security rewrite, webhooks, localisation and auto-install for RSG-Core.
