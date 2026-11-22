# rsg-factory

**Version 3.1.0** · Requires: `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql` · Optional: `rsg-telegram`, `rsg-society`

Admin-built factories for the RSG Framework. An admin stands where the factory NPC should be, runs `/createfactory`, and then defines production lines in an NUI: which items go in, which items come out, and how long it takes. Players buy a factory at its NPC and become its owner. The owner keeps it stocked with fuel (wood or coal) and water, and every production line burns some of both. Anyone can then use the factory to start production, wait, and collect.

See [DOCS.md](DOCS.md) for the full developer and server-owner documentation.

## Features
- `/createfactory [name]` places a factory NPC at the admin's position and opens the editor
- Admin editor: factory name, NPC model, any number of production lines
- Each line has multiple input items, multiple output items, time per batch and an optional job lock
- Searchable item picker built from your server's items (no manual typing of item names)
- **Chained lines:** link a line to another ("Then run") so when it finishes the next one starts automatically; the first line's products feed the next line
- **Ownership:** a factory is for sale until a player buys it (price set per factory, owner limit per player)
- **Fuel and water:** only the owner can add them (wood `resource_wood`, coal `resource_coal`, water `fullbucket`). Each line has its own fuel and water cost per batch; production cannot start without enough of both in the factory's stock
- **Owner panel** (a tab in *Use Factory*, owners only):
  - **Earnings:** the owner sets a fee per batch that other players pay; it builds up in the factory and is withdrawn here
  - **Access:** everyone, trusted workers only, or owner only; pick trusted workers from a searchable player list (online players first, then a database search of every character, so offline players work too) and remove them again
  - **Staffing:** optionally require the owner or a trusted worker to be online before anyone can start production
  - **Pause:** the owner can pause and resume production
  - **Upgrades:** storage tanks (more fuel/water capacity) and faster production (shorter times), bought with cash
  - **Breakdowns:** each production start has a small chance to break the factory; it can't start new runs until the owner repairs it (cash, or an item if you configure one). Running and finished products are never lost
  - **Sell or transfer:** sell back for a percentage of the price (earnings are paid out), or hand it to a nearby online player picked from the list, who accepts with `/acceptfactory`
- **rsg-society:** every new factory gets its own job (`factory_<id>`) and society the moment `/createfactory` runs. The owner becomes boss, trusted workers get the first grade, and the owner's earnings are the society account (treasury, members, ranks, storage and audit in the society menu). Selling or transferring the factory moves the people on; deleting it closes the society. Optional: without rsg-society the factory works as before
- **Alerts and delivery:** finished products are delivered straight to the player's inventory when they're online and have room (otherwise they get a "ready" notice, or a telegram if offline). The owner gets low fuel/water warnings and breakdown alerts, by telegram when offline (needs `rsg-telegram`, skipped if it isn't running)
- **Movable, fitted window:** the panel sizes itself to its content (wider for the admin editor); drag the header to move it anywhere on screen and double-click the header to recentre it
- **Item pictures:** recipes, the queue, supplies and the admin item picker show each item's picture from rsg-inventory (falls back to the item's first letter if an image is missing)
- **Map blips:** green for factories you own, default colour for ones for sale
- The Produce row shows the fuel and water a line will burn and is disabled when a single line can't be afforded
- Players pick a line and a batch count; inputs are taken and production runs in real time
- Production keeps running while the player is offline and survives restarts; collect any time at the NPC
- NPCs spawn only when a player is nearby; interaction through `rsg-target`
- Push-to-talk keeps working while the UI is open
- Locales: en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru

## Installation
1. Put `rsg-factory` in your resources folder.
2. Add `ensure rsg-factory` to your `server.cfg` after `rsg-core`, `rsg-inventory`, `rsg-target` and `oxmysql`.
3. Database: tables are created automatically on first start. To install manually, set `Config.AutoDatabase = false` in `shared/config.lua` and import `install.sql`.
4. Optional: start `rsg-society` before `rsg-factory` to give each factory a society (see `Config.Society`). Factories that already exist get theirs on the next start.
5. Set your language with `setr rsg:locale en` (or any supported language).

## Usage
| Command | Permission | Description |
|---|---|---|
| `/createfactory [name]` | `Config.AdminPermission` (default `admin`) | Creates a factory at your position and opens the editor |
| `/acceptfactory` | everyone | Accepts a factory handed over by its owner (within `Config.TransferExpiry` seconds, at the factory) |

- **Admins:** target the NPC and choose *Manage Factory* to edit lines, rename, change the NPC model or delete the factory.
- **Buying:** target the NPC, choose *Use Factory* and press *Buy Factory* (cash). Only one owner per factory.
- **Owner:** open *Use Factory* and use the *Supplies* section to add wood, coal or water to the factory. The bars show the current stock. Fuel and water are shared by everyone who produces here, so keep it topped up.
- **Players:** target the NPC and choose *Use Factory*, pick a production line, set the batches and press *Produce*. Press *Collect* once the timer shows *Ready*.

## Configuration
| Option | Default | Description |
|---|---|---|
| `AutoDatabase` | `true` | Create tables automatically (set `false` to import `install.sql`) |
| `CommandName` | `'createfactory'` | Admin command name |
| `AdminPermission` | `'admin'` | Permission needed to create/edit/delete factories |
| `DefaultPedModel` | `'a_m_m_rancher_01'` | NPC model used when none or an invalid one is set |
| `InteractDistance` | `2.5` | Target distance |
| `SpawnDistance` | `60.0` | NPC spawn/despawn distance |
| `DefaultPrice` | `5000` | Price of new factories (editable per factory in the admin editor) |
| `MaxPrice` | `1000000` | Highest price an admin can set |
| `MaxFactoriesPerPlayer` | `3` | Factories one player can own |
| `DefaultFuelPerBatch` / `DefaultWaterPerBatch` | `1` / `1` | Default cost of a new line per batch (editable per line) |
| `MaxUtilityPerBatch` | `100` | Highest fuel or water cost a line can have per batch |
| `MaxFuel` / `MaxWater` | `500` / `500` | Storage capacity of a factory (units) |
| `MaxSupplyAtOnce` | `100` | Items an owner can add in one go |
| `ImagePath` | `nui://rsg-inventory/html/images/` | Where item pictures are loaded from (`<item image>` from rsg-core, else `<item>.png`) |
| `Supplies` | wood, coal, water | Items the owner can add: `key`, `item`, `stock` (`'fuel'`/`'water'`), `units` per item, optional `returnItem` |
| `Fees.MaxPerBatch` | `500` | Highest fee per batch an owner can charge |
| `SellbackPercent` | `60` | % of the price an owner gets when selling back |
| `TransferExpiry` | `60` | Seconds to accept a transfer |
| `TrustedMax` | `8` | Trusted workers per factory |
| `Upgrades.tank` / `Upgrades.speed` | see file | `maxLevel`, `cost` (next level costs `cost * (level + 1)`), tank `bonus` capacity per level, speed `percent` shorter per level |
| `Breakdown` | enabled, `2.0`% | `enabled`, `chance` (% per production start), `repairCost` (cash) or `repairItem` (item name; leave `nil` unless the item exists on your server) |
| `AutoDeliver` | `true` | Deliver finished products straight to online players with room |
| `Alerts` | see file | `interval` (s), `ready`, `telegram`, `lowStockPercent`, `lowStockCooldown` |
| `Blips` | enabled | `sprite` (`blip_shop_blacksmith`), `scale`, `mineColor`, `saleColor`, `showOwnedByOthers` |
| `MaxRecipes` | `20` | Production lines per factory |
| `MaxItemsPerRecipe` | `6` | Distinct inputs and distinct outputs per line |
| `MaxAmount` | `1000` | Max amount of one item in a line |
| `MinTime` / `MaxTime` | `1` / `3600` | Allowed seconds per batch |
| `MaxChainLength` | `5` | Lines that can be linked in one chain |
| `MaxBatches` | `50` | Batches per production start |
| `MaxQueuePerPlayer` | `5` | Running productions per player per factory |
| `AllowPushToTalkWhileOpen` | `true` | Allow push-to-talk while the UI is open |
| `PushToTalkControls` | `{ 0x4BC9DABB }` | Controls kept active while the UI is open |

## Example factory
`example_factory.lua` is a reference-only file (not loaded by the resource) with a three-stage chained Cigarette Factory: dry tobacco, cut and roll, pack. It contains the production lines, step-by-step instructions for building it in the editor, item definitions for `shared/items.lua`, and a ready-made SQL insert. Make sure the items it uses exist on your server first.

## Notes
- The default NPC model could not be checked against the RedM brain while writing this; if it does not spawn on your build, change the model in the editor or `Config.DefaultPedModel`.
- Chains: a linked line must make at least one item the next line uses, and loops are not allowed. The next line runs as many batches as the previous line's output can feed (so batches may need to be higher if a line makes less than the next one needs). Inputs the next line needs that the previous line doesn't make are taken at the start, and surplus or by-products are paid out with the final products.
- Deleting a factory also deletes productions still running there.
- Fuel and water used is `fuel`/`water` per batch of each stage times the batches that stage runs, taken from the factory's stock when production starts.
- Coal counts as 3 fuel units and wood as 1; a full bucket adds 10 water units (see `Config.Supplies`). Each full bucket used gives the owner an empty `bucket` back (`returnItem` on the water supply; remove it to give nothing back).
- Existing factories keep working after the update: they become unowned and for sale at 5000 (set the real price in the editor), their lines default to 1 fuel and 1 water per batch, and the new columns are added automatically.
- Selling back pays `SellbackPercent` of the price plus any earnings, clears the owner and the factory's fuel and water, and resets fee, access, staffing, pause and trusted workers. Upgrades and breakdown state stay with the factory.
- A transfer hands over the factory with its stock and settings (trusted workers are cleared); earnings are paid to the previous owner, who must still be online.
- Fees are charged to other players only, per batch, and refunded if the start fails. Productions already running keep the time they were started with; speed upgrades apply to new runs.
- Existing databases get the new columns (`bank`, `settings`, `notified`) automatically; nothing is removed.
- Auto delivery only pays rows whose products all fit; anything that doesn't fit stays ready to collect at the NPC.

Support: https://rexshack.tebex.store
