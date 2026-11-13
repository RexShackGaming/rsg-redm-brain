# rsg-cards – documentation

For server owners and developers. Player-facing overview and install steps are in [README.md](README.md).

## Contents

1. [Architecture](#architecture)
2. [Data formats](#data-formats)
3. [Exports](#exports)
4. [Events and callbacks](#events-and-callbacks)
5. [Integration examples](#integration-examples)
6. [Persistence](#persistence)
7. [Security model](#security-model)
8. [Database schema](#database-schema)
9. [Server owner how-tos](#server-owner-how-tos)
10. [Troubleshooting](#troubleshooting)

## Architecture

| File | Purpose |
|---|---|
| `fxmanifest.lua` | Resource manifest. Locales are loaded by rsg-core (`@rsg-core/shared/locale.lua`) |
| `shared/config.lua` | All settings: sets, prices, pack chances, cooldowns, NPC locations |
| `shared/cards_points.lua` | `Config.CardPoints`: world location of each card |
| `shared/cards.lua` | Builds the global `Cards` lookup tables from `Config.Sets` |
| `server/server.lua` | Database setup, shared server helpers (`CardsServer`), packs, world pickups, collection tracking, storage box, inspect usable items |
| `server/vendor.lua` | Card vendor: selling cards and sets, making sets from 12 cards, rsg-inventory shop for packs and boxes |
| `server/trades.lua` | Card collectors: rotating requests and trades, `/refreshcardtrades` |
| `client/client.lua` | NUI bridge (focus, push-to-talk whitelist), pack / vendor / collector UI, card inspect |
| `client/world.lua` | NPCs, blips, prompts, world card props, pickups, Eagle Eye hint, cleanup |
| `html/` | NUI (house "leather & gold" style). `html/img` holds the card artwork, named `<item>.png` |
| `locales/*.json` | 10 languages with identical keys |
| `install.sql` | Manual database install (same schema the script creates itself) |
| `installation/` | Items for rsg-core and images for rsg-inventory |

Flow of a reward (the same pattern everywhere): the client only asks ("flip card 2", "pick up point 17", "sell 3 of X at shop Y"); the server validates, decides the result, changes the inventory or money, and returns what the UI should show.

## Data formats

### Items

| Item | Type | Notes |
|---|---|---|
| `card_package_cards` | useable, category `cardpack` | Card pack |
| `card_storage_box` | useable, unique, `shouldClose = false` | `info.serie` holds the box serial once registered |
| `card_cigcard_<set>_c<1-12>` | useable, category `card` | Single card |
| `card_cigcard_<set>` | not useable, category `cardset` | Complete set. Made from one each of that set's 12 cards |

Set ids: `act`, `amer`, `aml`, `inv`, `art`, `grl`, `lnd`, `plt`, `gun`, `hrs`, `spt`, `veh`.

### `Config.Sets` entry

```lua
{ id = 'aml', tier = 'basic', cardPrice = 0.50, deckPrice = 15.00, landscape = true }
```

`tier` is one of `basic`, `rare`, `ultra`, `v`, `vmax` and must match a tier in `Config.Pack.Chances`. `landscape` picks the wide-card inspect animation.

### `Cards` (global, client and server)

| Field | Content |
|---|---|
| `Cards.Info[item]` | `{ set, tier, price, order, deck }` for sets; plus `number`, `model`, `landscape` for single cards |
| `Cards.List` | Every single-card item name, in set order |
| `Cards.Decks` | Every complete-set item name |
| `Cards.ByTier[tier]` | Single-card item names of that tier |
| `Cards.Total` | Number of single cards (144) |

### `Config.CardPoints` entry

```lua
{ item = 'card_cigcard_plt_c1', coords = vector4(2238.9089, -768.6769, 43.4078, 77.0264) }
```

One entry per card; the item name is also the cooldown key, so don't list the same card twice.

### Collector request (server memory)

```lua
{ id = '3:1', set = 'act', reward = 'card_cigcard_act', amount = 1, cards = { 'card_cigcard_act_c2', ... } }
```

`id` is `<rotation>:<index>`, so a request from an old rotation can't be redeemed.

### Storage box stash

Stash id `box_<serial>`, opened with `exports['rsg-inventory']:OpenInventory`. Contents are stored by rsg-inventory.

- **Open / close:** using the box opens it beside the player inventory. Using the same box again while it is open calls `OpenInventory(src)` with no stash, which removes the box panel and leaves the inventory open.
- **Bundle Sets:** with `Config.Storage.BundleSets = true` the box is opened with `actions = { { id = 'bundle_sets', label = locale('bundle_sets') } }`, which rsg-inventory (3.2.0+) shows as a button under the box name. A click arrives as the local server event `rsg-inventory:stashAction (src, stashId, actionId)`. rsg-cards then counts the single cards in the box and, for each set, removes `n` of every card (`n` = the lowest count of any card in that set) and adds `n` complete-set items to the box. If the set can't be stored in the box it goes to the player, then to the ground; if a removal fails the cards already taken are put back. Only cards inside the box count, not the ones in the satchel. On an older rsg-inventory the `actions` option is ignored and the button simply doesn't appear.
- **Card-only rule:** rsg-inventory has no per-stash item filter, so rsg-cards checks the box itself: when it opens, after every move in or out of it (it listens to `rsg-inventory:server:move`), and when the inventory closes. Anything that is not a rsg-cards card, set or pack, and whose `category` is not in `Config.Storage.AllowedCategories`, is removed from the box and given back to the player, or dropped at their feet if they can't carry it.

## Exports

rsg-cards has no exports. Other resources work with the items directly through rsg-inventory (see the integration examples). The `Cards` table only exists inside this resource.

## Events and callbacks

Other resources normally don't need these. They are listed so you know what each one checks.

### Server callbacks (`RSGCore.Functions.CreateCallback`)

| Name | Arguments | Returns | Checks |
|---|---|---|---|
| `rsg-cards:server:flipCard` | `index` | card data or `false` | Player has an open pack, index valid and not flipped yet |
| `rsg-cards:server:getPickups` | – | `{ [item] = secondsLeft }` | – |
| `rsg-cards:server:pickupCard` | `pointIndex` | card data + `cooldown`, `{ cooldown }` or `false` | Distance to the point, per-character cooldown, rate limit, inventory space |
| `rsg-cards:server:getVendor` | `shopId` | `{ items, sets, boxesOnly }` or `false` | Distance to the vendor, rate limit (0.5 s). `sets` = sets the player holds all 12 cards of; `boxesOnly` mirrors `Config.Shop.BoxesOnly` (the UI uses it to explain an empty list) |
| `rsg-cards:server:sell` | `shopId, item, amount` | `{ message, type, items, sets }` or `false` | Distance, item is a card, whole amount ≥ 1 and owned, rate limit. Price from `Config.Sets` |
| `rsg-cards:server:sellAll` | `shopId` | `{ message, type, items, sets }` or `false` | Distance, rate limit. Only cards and sets are sold |
| `rsg-cards:server:makeSet` | `shopId, setId` | `{ message, type, items, sets }` or `false` | Distance, `Config.Shop.CraftSets`, set exists, all 12 cards owned, inventory space, rate limit. A failed removal refunds |
| `rsg-cards:server:getTrades` | `locationId` | `{ offers, refresh }` or `false` | Distance to the collector, rate limit (0.5 s). Each offer has `done = true` when the player already completed it |
| `rsg-cards:server:trade` | `locationId, offerId` | `{ message, type, offers, refresh }` or `false` | Distance, request still active, not already completed by this player (`Config.Trades.OncePerPlayer`), every card owned, inventory space, rate limit. A failed removal or reward refunds the cards |

Card data: `{ item, label, image, tier, deck, isNew, collected, total }`.

### Server net events

| Name | Arguments | Purpose |
|---|---|---|
| `rsg-cards:server:closePack` | – | Pack UI closed: gives the cards that were not turned over |
| `rsg-cards:server:openShop` | `shopId` | Opens the rsg-inventory shop (distance checked) |
| `rsg-cards:server:boxClosed` | – | Inventory closed: checks the box contents one last time |
| `rsg-inventory:server:move` | – | Also handled here (read-only) to check the open box after a move |

### Server local events (not net events)

| Name | Arguments | Purpose |
|---|---|---|
| `rsg-inventory:stashAction` | `src, stashId, actionId` | Sent by rsg-inventory when a stash header button is clicked. rsg-cards acts on `actionId = 'bundle_sets'` for the box that player has open |

### Client events

| Name | Arguments | Purpose |
|---|---|---|
| `rsg-cards:client:openPack` | `amount` | (net) Sent by the server after a pack was consumed |
| `rsg-cards:client:inspectCard` | `item` | (net) Hold and look at a card |
| `rsg-cards:client:boxOpened` | – | (net) Starts watching for the inventory to close |
| `rsg-cards:client:openVendor` | `shopId` | (local) Open the vendor UI |
| `rsg-cards:client:openTrades` | `locationId` | (local) Open the collector UI |
| `rsg-cards:client:takecard` | `pointIndex` | (local) Pick up a world card (used by prompts) |
| `rsg-cards:client:revealCard` | card data | (local) Show a found card |

### Commands

| Command | Permission | Purpose |
|---|---|---|
| `/refreshcardtrades` | `admin` | New collector requests immediately |

## Integration examples

Give a pack as a reward from another script (server side):

```lua
if exports['rsg-inventory']:CanAddItem(src, 'card_package_cards', 1) then
    exports['rsg-inventory']:AddItem(src, 'card_package_cards', 1, nil, nil, 'my-script:reward')
end
```

Check whether a player holds a complete set (server side):

```lua
local hasSet = exports['rsg-inventory']:HasItem(src, 'card_cigcard_gun', 1)
```

Query a character's collection progress:

```lua
local found = MySQL.scalar.await('SELECT COUNT(*) FROM rsg_cards_collection WHERE citizenid = ?', { citizenid })
```

## Persistence

| Data | Where | Notes |
|---|---|---|
| Cards a character has ever found | `rsg_cards_collection` | Written when a single card is given by a pack or a pickup |
| World card cooldowns | `rsg_cards_pickups` | Unix time of the last pickup per character and card. Cached in memory while the player is online |
| Storage box registry | `rsg_cards_boxes` | Serial, creator, last user. Box contents live in rsg-inventory's stash storage |
| Collector requests | memory | Regenerated on resource start and every `Config.Trades.Refresh` minutes. Who completed which request is kept in memory until the next refresh |
| Open packs | memory | Cards not yet turned over are given when the UI closes, the player leaves, or the resource stops |
| Vendor stock | rsg-inventory | Persistent when `Config.Shop.PersistStock = true` |

## Security model

What the script enforces:

- The client never names a reward, price or amount of money. Packs are rolled on the server when the pack item is removed; flipping a card only reveals a card the server already chose.
- Every callback and event resolves the player and returns early if there is none.
- Location actions (pickup, vendor, shop, collector) are distance-checked against the server's own coordinates for the player.
- Amounts are checked for type, whole numbers, range and ownership. Only items in `Cards.Info` can be sold or traded.
- Sell prices and trade contents come from server config / server memory.
- Reward, sale and vendor/collector callbacks are rate limited per player (millisecond precision).
- Collector requests can only be completed once per player (`Config.Trades.OncePerPlayer`); completed requests are remembered in memory until the requests refresh. Without this a player could trade the same few cheap cards for a set worth up to $60 over and over.
- World pickups have a per-character cooldown, set before the card is given.
- `CanAddItem` is checked before items are given; a failed removal aborts and refunds a trade.
- All SQL uses `?` parameters. Box serials are validated (`%w+`) before being used in a stash id.
- Bundle Sets: the click carries no data from the client. rsg-inventory only passes it on for a button registered on the stash the player has open; rsg-cards then checks it is that player's open box, rate limits it (2 s) and works out the sets from the box contents on the server.
- `/refreshcardtrades` requires the `admin` permission.

What you must look after:

- Anyone holding a storage box item can open that box. Giving away the item gives away its contents.
- The card-only rule on boxes is enforced by rsg-cards after the move, not by rsg-inventory before it, so a rejected item is in the box for a fraction of a second before it is handed back.
- Sell prices are in `Config.Sets`; check them against your economy before going live. Vendors buy without limit.

## Database schema

```sql
CREATE TABLE IF NOT EXISTS `rsg_cards_boxes` (
    `serial`  VARCHAR(20) NOT NULL,
    `creator` VARCHAR(50) NOT NULL,
    `owner`   VARCHAR(50) NOT NULL,
    PRIMARY KEY (`serial`),
    INDEX `idx_creator` (`creator`),
    INDEX `idx_owner` (`owner`)
);

CREATE TABLE IF NOT EXISTS `rsg_cards_collection` (
    `citizenid`   VARCHAR(50) NOT NULL,
    `card`        VARCHAR(50) NOT NULL,
    `obtained_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `card`)
);

CREATE TABLE IF NOT EXISTS `rsg_cards_pickups` (
    `citizenid` VARCHAR(50) NOT NULL,
    `card`      VARCHAR(50) NOT NULL,
    `picked_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`citizenid`, `card`)
);
```

With `Config.AutoDatabase = true` these are created on start, and a legacy `hdrp_boxes` table is renamed to `rsg_cards_boxes`. A table that came from `hdrp_boxes` also has an unused `position` column; it is harmless.

## Server owner how-tos

**Change what cards sell for** – edit `cardPrice` / `deckPrice` in `Config.Sets`.

**Change pack odds** – edit the weights in `Config.Pack.Chances`. They are relative whole numbers; the defaults add up to 1000, so `5` means 0.5%.

**Let boxes hold other items** – add the item's category to `Config.Storage.AllowedCategories`.

**Turn off set making at vendors** – `Config.Shop.CraftSets = false`.

**Let vendors use loose cards too** – `Config.Shop.BoxesOnly = false` (default `true`: vendors only look in the player's card boxes).

**Turn off the Bundle Sets button on boxes** – `Config.Storage.BundleSets = false`.

**Move or add a vendor / collector** – add an entry to `Config.Shop.Locations` or `Config.Trades.Locations` with a unique `id`, `coords`, `npcmodel` and `npccoords`.

**Move or add a world card** – edit `shared/cards_points.lua`. `card_cigcard_grl_c1` has no world location in the shipped data; add one if you want it findable outside packs.

**Make world cards one-time only** – set `Config.Card.Cooldown` to a very large number of minutes.

**Reset a character's cooldowns or collection** – `DELETE FROM rsg_cards_pickups WHERE citizenid = '...'` / `DELETE FROM rsg_cards_collection WHERE citizenid = '...'`, then have the player relog.

**Use prompts instead of targeting** – `Config.EnableTarget = false`. Keys are `Config.Card.Key`, `Config.Shop.Key`, `Config.Trades.Key`.

**Turn off voice passthrough** – `Config.AllowPushToTalkWhileOpen = false`.

**Allow repeat trades with collectors** – `Config.Trades.OncePerPlayer = false` (check your set prices first).

**Turn off the update check** – `Config.VersionCheck = false`.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Console: `N item(s) missing from rsg-core shared items` | Add `installation/shared_items.lua` to rsg-core and restart |
| Using a pack does nothing | The item must be named `card_package_cards` and be `useable = true` |
| Using a card does nothing | Single cards need `useable = true` in rsg-core items (older installs had `false`) |
| Card faces are blank in the UI | Artwork is `html/img/<item name>.png`; the resource folder must be named `rsg-cards` |
| Item thumbnails missing in vendor / collector UI | Copy `installation/images` to rsg-inventory, or fix `Config.ImagePath` |
| No sound | interact-sound must be running and have the `dealfour` and `flip` sounds, or set `Config.Sounds.enabled = false` |
| No world cards appear | They only spawn after the character has loaded, within `Config.DistanceSpawn`, and not while on cooldown |
| Console: `database setup failed` | Check oxmysql, or set `Config.AutoDatabase = false` and import `install.sql` |
| No **Bundle Sets** button on the box | Update rsg-inventory to 3.2.0 or newer and check `Config.Storage.BundleSets = true` |
| Bundle Sets says there are no complete sets | All 12 cards of a set must be inside the box (cards in the satchel don't count) |
| Items jump back out of a storage box | Only cards, sets, packs and `Config.Storage.AllowedCategories` are allowed |
| The inventory flickers when the box is used | Set the box item to `shouldClose = false` in rsg-core items |
| Using a storage box closes the inventory and nothing opens | The box opens `Config.Storage.OpenDelay` ms after use, once rsg-inventory has closed the inventory. Raise the delay if the box flashes open and shut |
| Old boxes are empty after upgrading | The box table must be `rsg_cards_boxes` (auto-renamed from `hdrp_boxes`); stash ids are unchanged (`box_<serial>`) |
| No Discord logs | Add a `rsg-cards` webhook to rsg-log |
| Vendor says it only buys cards from a card box | `Config.Shop.BoxesOnly = true` (default): put cards in a card box and carry the box. Set it to `false` to also buy loose cards from the inventory |
| Collector request shows *Completed* | The player already did it; new requests arrive every `Config.Trades.Refresh` minutes or with `/refreshcardtrades` |
| Vendor has nothing to buy | Stock is `amount` in `Config.Shop.Items`; with persistent stock it only refills when rsg-inventory restocks |

Support the Project : https://rexshack.tebex.store/


## Vendor and card boxes

Vendors (`server/vendor.lua`) work on everything the player carries: the inventory **and** every card storage box in it (stash `box_<serial>`).

- `CardsServer.countCards(src, scope)` returns `{ [itemName] = amount }`. `scope` is nil (inventory only, used by trades), `true` (inventory + boxes) or `'boxes'` (boxes only). Vendors use `'boxes'` when `Config.Shop.BoxesOnly = true`, otherwise `true`.
- `CardsServer.getBoxIds(src)` returns the stash ids of the boxes the player carries (only boxes that have been registered, i.e. have a serial).
- `CardsServer.removeCards(src, name, amount, reason, scope)` removes from the inventory first, then from the boxes (`scope = 'boxes'` skips the inventory). It is all-or-nothing: if any step fails the cards already taken are handed back. Box stashes that were changed are saved.
- Make Set removes cards 1-12 (from inventory/boxes) and gives one complete-set item to the inventory. Sell and Sell All pay `cardPrice` per card and `deckPrice` per set from `Config.Sets`.
