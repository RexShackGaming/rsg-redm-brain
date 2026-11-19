# rsg-cards – documentation

For server owners and developers. Player-facing overview and install steps are in [README.md](README.md).

## Contents

1. [Architecture](#architecture)
2. [Data formats](#data-formats)
3. [Exports](#exports)
4. [Events and callbacks](#events-and-callbacks)
5. [Integration examples](#integration-examples)
6. [Configuration reference](#configuration-reference)
7. [Flows](#flows)
8. [NUI reference](#nui-reference)
9. [Locales](#locales)
10. [Useful SQL](#useful-sql)
11. [Persistence](#persistence)
12. [Security model](#security-model)
13. [Database schema](#database-schema)
14. [Server owner how-tos](#server-owner-how-tos)
15. [Vendor and card boxes](#vendor-and-card-boxes)
16. [Troubleshooting](#troubleshooting)

## Architecture

| File | Purpose |
|---|---|
| `fxmanifest.lua` | Resource manifest. Locales are loaded by rsg-core (`@rsg-core/shared/locale.lua`) |
| `shared/config.lua` | All settings: sets, prices, pack chances, cooldowns, NPC locations |
| `shared/cards_points.lua` | `Config.CardPoints`: starting world locations. Only copied into the database on the first start; the database is the source of truth afterwards |
| `shared/cards.lua` | Builds the global `Cards` lookup tables from `Config.Sets` |
| `server/server.lua` | Database setup, shared server helpers (`CardsServer`), packs, world pickups, collection tracking, storage box, inspect usable items |
| `server/points.lua` | Card locations in `rsg_cards_points`, the `CardsServer.points` registry, sync to clients and the admin editor (`/cardplace`, `/cardmove`, `/cardremove`, `/cardedit`, `/cardmissing`) |
| `server/collection.lua` | Set completion (bonus, first collector), collection viewer and leaderboard data, `/cardcollection`, leaderboard names |
| `server/vendor.lua` | Card vendor: selling cards and sets, making sets from 12 cards, rsg-inventory shop for packs and boxes |
| `server/trades.lua` | Card collectors: rotating requests and trades, `/refreshcardtrades` |
| `server/ptrade.lua` | Player to player trading: sessions, offers, ready flags and the exchange, `/cardtrade` |
| `client/client.lua` | NUI bridge (focus, push-to-talk whitelist, closes the UI on death or when walking away, `Config.CloseDistance`), pack / vendor / collector UI, card inspect, shared `CardsClient.loadModel` |
| `client/world.lua` | NPCs, blips, prompts, world card props, pickups, Eagle Eye hint, cleanup |
| `html/` | NUI (house "leather & gold" style). `html/img` holds the card artwork, named `<item>.png` |
| `locales/*.json` | 11 languages with identical keys |
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

### Card location (`CardsServer.points[id]`, server) / `points[id]` (client)

```lua
{ id = 17, item = 'card_cigcard_plt_c1', coords = vector4(2238.9, -768.7, 43.4, 77.0), exact = false }
```

`exact = true` means the location was set with the gizmo, so the prop is not snapped to the ground. Locations seeded from the config use `exact = false`.

### `Config.CardPoints` entry (only used to seed the database)

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
- **Sort & Stack:** with `Config.Storage.SortButton = true` the box also gets a `sort_box` button (`Config.Storage.SortOnOpen = true` runs the same sort every time the box opens). The server reads the box contents, merges identical non-unique items (same name and same `info`) into one entry, orders them (complete sets, single cards by set and card number, packs, anything else by name) and, if the box is not already stacked and in order, takes every item out and adds them back in that order so rsg-inventory fills slots 1, 2, 3... Nothing is deleted: if a removal or add fails, the items already taken out are put back in the box, else given to the player, else dropped. Unique items are never merged. Rate limited to once every 2 s and only works on the box that player has open.
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
| `rsg-cards:server:getPoints` | – | list of `{ id, item, x, y, z, w, exact }` | Waits (up to 10 s) until the points are loaded from the database |
| `rsg-cards:server:pickupCard` | `pointId` | card data + `cooldown`, `{ cooldown }` or `false` | Distance to the point, per-character cooldown, rate limit, inventory space |
| `rsg-cards:server:getVendor` | `shopId` | `{ items, sets, boxesOnly }` or `false` | Distance to the vendor, rate limit (0.5 s). `sets` = sets the player holds all 12 cards of; `boxesOnly` mirrors `Config.Shop.BoxesOnly` (the UI uses it to explain an empty list) |
| `rsg-cards:server:sell` | `shopId, item, amount` | `{ message, type, items, sets }` or `false` | Distance, item is a card, whole amount ≥ 1 and owned, rate limit. Price from `Config.Sets` |
| `rsg-cards:server:sellAll` | `shopId` | `{ message, type, items, sets }` or `false` | Distance, rate limit. Only cards and sets are sold |
| `rsg-cards:server:makeSet` | `shopId, setId` | `{ message, type, items, sets }` or `false` | Distance, `Config.Shop.CraftSets`, set exists, all 12 cards owned, inventory space, rate limit. A failed removal refunds |
| `rsg-cards:server:sellDuplicates` | `shopId` | `{ message, type, items, sets, duplicates }` or `false` | Distance, `Config.Shop.SellDuplicates`, rate limit. Sells everything beyond one of each single card (complete sets are never touched) and saves each box once |
| `rsg-cards:server:getCollection` | – | `{ sets, found, total, board, myRank }` or `false` | Rate limit (1 s). `sets` = every set with its 12 cards and whether the player found each, `first` (name of the first player to complete it), `firstMe`; `board` = top collectors (cached `Config.Collection.CacheSeconds`); `myRank` only when the player is not in the top list |
| `rsg-cards:server:getTrades` | `locationId` | `{ offers, refresh }` or `false` | Distance to the collector, rate limit (0.5 s). Each offer has `done = true` when the player already completed it |
| `rsg-cards:server:trade` | `locationId, offerId` | `{ message, type, offers, refresh }` or `false` | Distance, request still active, not already completed by this player (`Config.Trades.OncePerPlayer`), every card owned, inventory space, rate limit. A failed removal or reward refunds the cards |

Card data: `{ item, label, image, tier, deck, isNew, collected, total, setComplete }`. `setComplete` is true when this card was the last one the character needed to find in its set.

### Server net events

| Name | Arguments | Purpose |
|---|---|---|
| `rsg-cards:server:closePack` | – | Pack UI closed: gives the cards that were not turned over |
| `rsg-cards:server:claimUnclaimed` | – | Sent by the client on login: gives the cards queued in `rsg_cards_unclaimed` (rate limited, stops when the inventory is full and keeps the rest queued) |
| `rsg-cards:server:ptradeRequest` | `targetId` | Ask a player to trade. Checks the feature is on, the target is another online player, neither is in a trade, they are within `Config.PlayerTrade.Distance`, rate limit (3 s) |
| `rsg-cards:server:ptradeRespond` | `accept` | The invited player accepts or declines (only valid for the invited player of an open request) |
| `rsg-cards:server:ptradeOffer` | `name, amount` | Set how many of a card/set the player offers (0 takes it back). Checks it is a card item, whole amount, owned (minus the copy kept when `DuplicatesOnly`) and within `MaxPerSide`. Clears both Ready flags |
| `rsg-cards:server:ptradeReady` | `ready` | Sets the player's Ready flag. When both are ready the server re-checks everything and swaps the cards |
| `rsg-cards:server:ptradeCancel` | – | Leave the trade (also sent when the window is closed) |
| `rsg-cards:server:pointAdd` | `item, x, y, z, heading` | Admin: add a card location. Checks `Config.Editor`, permission, rate limit (1 s), finite numbers, admin within `Config.Editor.Distance`, single card, no location yet for that card |
| `rsg-cards:server:pointMove` | `id, x, y, z, heading` | Admin: move a location (same checks, the id must exist) |
| `rsg-cards:server:pointRemove` | `id` | Admin: delete a location (same checks, admin near the location) |
| `rsg-cards:server:openShop` | `shopId` | Opens the rsg-inventory shop (distance checked) |
| `rsg-cards:server:boxClosed` | – | Inventory closed: checks the box contents one last time |
| `rsg-inventory:server:move` | – | Also handled here (read-only) to check the open box after a move |

### Server local events (not net events)

| Name | Arguments | Purpose |
|---|---|---|
| `rsg-inventory:stashAction` | `src, stashId, actionId` | Sent by rsg-inventory when a stash header button is clicked. rsg-cards acts on `actionId = 'bundle_sets'` and `'sort_box'` for the box that player has open |

### Client events

| Name | Arguments | Purpose |
|---|---|---|
| `rsg-cards:client:openPack` | `amount` | (net) Sent by the server after a pack was consumed |
| `rsg-cards:client:inspectCard` | `item` | (net) Hold and look at a card |
| `rsg-cards:client:boxOpened` | – | (net) Starts watching for the inventory to close |
| `rsg-cards:client:openCollection` | – | (net) Open the collection viewer |
| `rsg-cards:client:tradeInvite` | `name` | (net) Another player wants to trade: shows the accept / decline window |
| `rsg-cards:client:tradeState` | `state` | (net) Current offers of a player trade (opens or updates the window) |
| `rsg-cards:client:tradeClosed` | `reason` | (net) Trade ended: `declined`, `cancelled`, `done`, `expired`, `distance`, `full` or `changed` (each has an `ptrade_<reason>` locale text) |
| `rsg-cards:client:openVendor` | `shopId` | (local) Open the vendor UI |
| `rsg-cards:client:openTrades` | `locationId` | (local) Open the collector UI |
| `rsg-cards:client:takecard` | `pointIndex` | (local) Pick up a world card (used by prompts) |
| `rsg-cards:client:revealCard` | card data | (local) Show a found card |
| `rsg-cards:client:setPoint` | `id, data` | A card location was added, moved (`data = { id, item, x, y, z, w, exact }`) or removed (`data = nil`) |
| `rsg-cards:client:editorPlace` | `item` | Admin: start placing a card with rsg-gizmo |
| `rsg-cards:client:editorMove` / `editorRemove` / `editorToggle` | – | Admin: move or remove the nearest spawned card, or toggle showing all cards |

### Commands

| Command | Permission | Purpose |
|---|---|---|
| `/refreshcardtrades` | `admin` | New collector requests immediately |
| `/cardcollection` | everyone | Open your collection and the leaderboard (`Config.Collection.Command`) |
| `/cardtrade [id]` | everyone | Ask a nearby player to trade cards (`Config.PlayerTrade.Command`) |
| `/cardplace [card]` | `Config.Editor.Permission` | Place a card with rsg-gizmo (`grl_c1` or the full item name) |
| `/cardmove` | `Config.Editor.Permission` | Move the nearest spawned world card with rsg-gizmo |
| `/cardremove` | `Config.Editor.Permission` | Delete the nearest spawned world card |
| `/cardedit` | `Config.Editor.Permission` | Toggle showing all world cards regardless of your cooldowns |
| `/cardmissing` | `Config.Editor.Permission` | List cards without a world location |

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

Pay a card reward from another script, with a notification (rsg-core notify, server side):

```lua
RegisterNetEvent('my-script:server:reward', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    -- validate everything here (distance, cooldown...) - never trust the client

    local card = 'card_cigcard_act_c1'
    if exports['rsg-inventory']:CanAddItem(src, card, 1) then
        exports['rsg-inventory']:AddItem(src, card, 1, nil, nil, 'my-script:reward')
        TriggerClientEvent('RSGCore:Client:Notify', src, {
            title = 'Reward', description = 'You received a card', type = 'success', duration = 5000,
        })
    end
end)
```

Count a player's cards, including cards inside card boxes (rsg-cards helpers are local to the resource, so use rsg-inventory from outside):

```lua
local items = exports['rsg-inventory']:GetItemsByName(src, 'card_cigcard_act_c1') or {}
local total = 0
for _, item in pairs(items) do total = total + (item.amount or 0) end
```

Add an item reward to the set bonus (`shared/config.lua`):

```lua
Config.SetBonus = {
    Enabled = true, Payment = 'cash', Multiplier = 2.0,
    Items = { { name = 'goldbar', amount = 1 } },
}
```

Add a new set (items `card_cigcard_xyz` and `card_cigcard_xyz_c1..c12`, the artwork `html/img/<item>.png` and an entry in rsg-core shared items are needed):

```lua
{ id = 'xyz', tier = 'rare', cardPrice = 0.50, deckPrice = 65.00 },
```

Add a vendor (unique `id`):

```lua
{ id = 'CardshopValentine', coords = vector3(-282.5, 804.9, 119.4),
  npcmodel = `mp_u_f_m_nat_traveler_01`, npccoords = vector4(-282.5, 804.9, 119.4, 100.0) },
```

Start a trade from another script (client side, same as the target):

```lua
TriggerServerEvent('rsg-cards:server:ptradeRequest', GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped)))
```

Open the collection viewer from a radial menu or another script:

```lua
TriggerEvent('rsg-cards:client:openCollection')
```

## Configuration reference

Every option in `shared/config.lua`. Tables list the default.

### General

| Option | Default | Description |
|---|---|---|
| `Config.Debug` | `false` | Extra console output |
| `Config.VersionCheck` | `true` | Check GitHub for a new version on start |
| `Config.AutoDatabase` | `true` | Create the tables on start. `false` = import `install.sql` yourself |
| `Config.AllowPushToTalkWhileOpen` | `true` | Keep voice keys working while a UI is open |
| `Config.PushToTalkControls` | `{ 0x4BC9DABB }` | Control hashes passed through to the game while the UI has focus |
| `Config.CloseDistance` | `6.0` | Vendor, collector and trade UIs close when the player walks this far away (or dies) |
| `Config.ImagePath` | `nui://rsg-inventory/html/images/` | Where item thumbnails come from |
| `Config.Items.Pack` / `Box` | `card_package_cards` / `card_storage_box` | Item names of the pack and the storage box |
| `Config.EnableTarget` | `true` | `true` = rsg-target, `false` = rsg-core prompts |
| `Config.FadeIn` | `true` | Fade NPCs and card props in and out |
| `Config.DistanceSpawn` | `20.0` | Distance at which NPCs and world cards spawn |

### Sets, packs and world cards

| Option | Default | Description |
|---|---|---|
| `Config.CardsPerSet` | `12` | Cards in a set. Items are `card_cigcard_<id>_c1..cN` |
| `Config.Sets[]` | 12 sets | `{ id, tier, cardPrice, deckPrice, landscape? }`. `id` forms the item names, `tier` is `basic` `rare` `ultra` `v` `vmax`, `landscape = true` renders the cards sideways |
| `Config.Pack.Cards` | `4` | Cards per pack |
| `Config.Pack.OpenTime` | `3000` | Progress time in ms |
| `Config.Pack.Chances[]` | sums to 1000 | `{ tier, weight }`. `tier = 'deck'` can give a complete set. Weights are relative |
| `Config.Card.Key` | `'J'` | Prompt key (prompt mode) |
| `Config.Card.PickupTime` / `PickupDistance` | `3000` / `3.0` | World pickup progress (ms) and server distance check |
| `Config.Card.Cooldown` | `360` | Minutes before the same character can take the same world card again |
| `Config.Card.InspectTime` | `15000` | Maximum time a card is held when used from the inventory |
| `Config.Card.EagleEye` | enabled, 50.0 | `{ enabled, distance, soundRef, soundName }`: heartbeat hint when a card is near |
| `Config.Blip` | see file | `showblipShop`, `showblipCollect`, `showblipCards` and sprite/scale for each |
| `Config.Sounds` | enabled, 0.8 | `{ enabled, volume, open, flip }`. Needs interact-sound |

### Storage box

| Option | Default | Description |
|---|---|---|
| `Config.Storage.MaxWeight` / `MaxSlots` | `500` / `156` | Stash size |
| `Config.Storage.OpenDelay` | `300` | ms between use and opening, so the inventory can close first |
| `Config.Storage.BundleSets` | `true` | Show the **Bundle Sets** button |
| `Config.Storage.SortButton` | `true` | Show the **Sort & Stack** button |
| `Config.Storage.SortOnOpen` | `false` | Sort and stack every time the box opens |
| `Config.Storage.AllowedCategories` | `card`, `cardset`, `cardpack` | Item categories a box accepts |

### Vendors, collectors and bonuses

| Option | Default | Description |
|---|---|---|
| `Config.Shop.Key` | `'J'` | Prompt key |
| `Config.Shop.Payment` | `'cash'` | `cash` or `bloodmoney`, used for buying and selling |
| `Config.Shop.InteractDistance` | `5.0` | Server distance check |
| `Config.Shop.PersistStock` | `true` | Keep vendor stock across restarts |
| `Config.Shop.CraftSets` | `true` | Allow making a set from 12 cards |
| `Config.Shop.SellDuplicates` | `true` | **Sell Duplicates** button (keeps one of each card) |
| `Config.Shop.BoxesOnly` | `true` | Vendors only look in carried card boxes |
| `Config.Shop.Items[]` | pack, box | `{ name, amount, price }` stock of the rsg-inventory shop |
| `Config.Shop.Locations[]` | 2 | `{ id, coords, npcmodel, npccoords }` (ids must be unique) |
| `Config.Trades.*` | see file | `Key`, `Refresh` (min), `MaxActive`, `MinCards`, `MaxCards`, `RewardAmount`, `OncePerPlayer`, `InteractDistance`, `Locations[]` |
| `Config.Collection.Command` | `'cardcollection'` | Opens the collection and leaderboard |
| `Config.Collection.LeaderboardSize` | `10` | Rows on the leaderboard |
| `Config.Collection.CacheSeconds` | `60` | Leaderboard cache time |
| `Config.Collection.AnnounceFirst` | `true` | Notify everyone when someone is first to complete a set |
| `Config.SetBonus.Enabled` | `true` | Pay a bonus the first time a character completes a set |
| `Config.SetBonus.Payment` | `'cash'` | `cash` or `bloodmoney` |
| `Config.SetBonus.Multiplier` | `2.0` | Money = the set's `deckPrice` x this (`0` = no money) |
| `Config.SetBonus.Items[]` | `{}` | Extra items `{ name, amount }` |
| `Config.PlayerTrade.Enabled` | `true` | Player to player trading |
| `Config.PlayerTrade.Command` | `'cardtrade'` | `/cardtrade [id]` |
| `Config.PlayerTrade.Distance` | `5.0` | Both players must be this close (server checked; +3.0 tolerance during the swap) |
| `Config.PlayerTrade.InviteSeconds` | `30` | How long a request stays open |
| `Config.PlayerTrade.MaxPerSide` | `30` | Most cards one player can offer |
| `Config.PlayerTrade.DuplicatesOnly` | `true` | Only spare copies can be offered; one of each single card is kept |
| `Config.PlayerTrade.CountAsFound` | `true` | Received cards count for the collection, set bonus and leaderboard |
| `Config.Editor.Enabled` | `true` | Admin card editor and the commands |
| `Config.Editor.Permission` | `'admin'` | Permission for the editor commands (also checked on the server for every edit) |
| `Config.Editor.SeedFromConfig` | `true` | Copy `Config.CardPoints` into the database when `rsg_cards_points` is empty |
| `Config.Editor.Distance` | `10.0` | Admin must be this close to the location (server checked) |
| `Config.Webhook` | `rsg-cards` | `{ Name, Title, Colour }`; `Name` must match an rsg-log webhook |

## Flows

### Editing a card location

`/cardplace grl_c1` -> server validates the name and sends `rsg-cards:client:editorPlace` -> client `exports['rsg-gizmo']:Place(model, { rotation = 'z' })` -> on confirm `rsg-cards:server:pointAdd(item, x, y, z, heading)` -> server checks permission, throttle, that the numbers are finite, the admin is within `Config.Editor.Distance`, the card is a single card with no location yet -> inserts the row -> `rsg-cards:client:setPoint` to everyone. `pointMove` and `pointRemove` work the same way on an existing id.

### Opening a pack

1. Player uses `card_package_cards`; the server removes the pack, the client opens the NUI (mode `pack`) and the server and rolls `Config.Pack.Cards` cards from `Config.Pack.Chances` (all decided server side).
2. The client posts `flip` with a slot; the server hands out that card (`grantCard`), records it (`CardsServer.markFound`) and returns the card plus `setComplete`.
3. Unflipped cards are given when the UI closes, the player drops, or the resource stops. Cards that can't be given are stored in `rsg_cards_unclaimed`.

### World card pickup

Client asks `pickup <pointId>` (the `rsg_cards_points` id) -> server checks the point exists, distance (`Config.Card.PickupDistance`), cooldown (`rsg_cards_pickups`) and throttle -> gives the card -> `markFound`.

### Sell, sell all, sell duplicates, make set

Client posts the action with names/amounts only. The server takes the prices from `Config.Sets`, checks distance (`CardsServer.findLocation`), counts cards (`countCards`), removes them (`removeCards`, all-or-nothing, refund on failure) and pays with `AddMoney`. **Sell Duplicates** keeps one of each single card; **Make Set** removes cards 1-N and adds the set item (refunds if it can't be added).

### Set completion

`CardsServer.markFound` -> `recordCard` (insert into `rsg_cards_collection`) -> if the card is new, `checkSetComplete`: counts the set's cards, `INSERT IGNORE` into `rsg_cards_bonuses` (unique `citizenid, set_id`, so it can only pay once), pays `giveBonus`, logs, and announces when the lowest `id` for that set is this character.

### Player trade

```
A: /cardtrade 12 (or target)      server: session{a, b, phase='invite'} + timeout
B: tradeInvite  -> Accept         server: phase='open', push state to both
A/B: ptradeOffer(name, amount)    server: validates against own cards, clears BOTH ready flags
A/B: ptradeReady(true)            server: when both ready and anything is offered -> execute()
execute(): re-check ownership, distance, CanAddItem -> remove from both (rollback on failure)
           -> hand over (refund on failure) -> log -> close 'done' -> mark received cards found
```

Close reasons (locale `ptrade_<reason>`): `declined`, `cancelled`, `done`, `expired`, `distance`, `full`, `changed`.

## NUI reference

Messages from Lua to the page (`SendNUIMessage`):

| `action` | Fields | Purpose |
|---|---|---|
| `open` | `mode`, `data`, `strings`, `imagePath` | Show a view. `mode` is `pack`, `reveal`, `vendor`, `trade`, `collection` or `ptrade` |
| `update` | `mode = 'ptrade'`, `data` | Live update of the trade window |
| `close` | | Hide everything |

NUI callbacks (page -> `RegisterNUICallback`, each is validated again on the server):

| Callback | Body | Server side |
|---|---|---|
| `close` | | Releases focus, finishes an open pack, cancels a trade |
| `flip` | `{ index }` | Reveals one pack card (`rsg-cards:server:flipCard`) |
| `sell` / `sellAll` / `sellDuplicates` | `{ name, amount }` / none | Vendor sales |
| `makeSet` | `{ id }` | Make a complete set (set id) |
| `buy` | | Closes the UI and opens the rsg-inventory vendor shop |
| `collection` | | Opens the collection viewer (`rsg-cards:server:getCollection`) |
| `trade` | `{ id }` | Complete a collector request (`rsg-cards:server:trade`) |
| `ptradeRespond` / `ptradeOffer` / `ptradeReady` | `{ accept }` / `{ name, amount }` / `{ ready }` | Player trade |

## Locales

Language comes from rsg-core's `rsg:locale` convar (for example `setr rsg:locale de`). The 10 files in `locales/` (`en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`) must keep identical keys and the same `%s`/`%d` placeholders in the same order.

To add a text: add the key to `en.json`, translate it into the other nine, use `locale('key', ...)` on the server or client. If the UI needs it, also add it to `getStrings()` in `client/client.lua` and read it from `strings` in `html/script.js`. Some keys are built at runtime (`ptrade_<reason>`, `vendor_empty*`, `inventory_full_dropped`), so keep them even if a search for the full key finds no use.

## Useful SQL

```sql
-- how many cards a character has found
SELECT COUNT(*) FROM rsg_cards_collection WHERE citizenid = 'ABC12345';

-- first collector of each set
SELECT b.set_id, p.name FROM rsg_cards_bonuses b
JOIN (SELECT set_id, MIN(id) id FROM rsg_cards_bonuses GROUP BY set_id) f ON f.id = b.id
LEFT JOIN rsg_cards_profiles p ON p.citizenid = b.citizenid;

-- top collectors
SELECT p.name, COUNT(*) found FROM rsg_cards_collection c
LEFT JOIN rsg_cards_profiles p ON p.citizenid = c.citizenid
GROUP BY c.citizenid, p.name ORDER BY found DESC LIMIT 10;

-- cards waiting to be handed over
SELECT * FROM rsg_cards_unclaimed;
```


## Persistence

| Data | Where | Notes |
|---|---|---|
| Cards a character has ever found | `rsg_cards_collection` | Written when a single card is given by a pack or a pickup |
| World card locations | `rsg_cards_points` | One row per card location. Filled from `Config.CardPoints` when the table is empty, then edited in game. Changes are sent to every client straight away |
| World card cooldowns | `rsg_cards_pickups` | Unix time of the last pickup per character and card. Cached in memory while the player is online |
| Storage box registry | `rsg_cards_boxes` | Serial, creator, last user. Box contents live in rsg-inventory's stash storage |
| Collector requests | memory | Regenerated on resource start and every `Config.Trades.Refresh` minutes. Who completed which request is kept in memory until the next refresh |
| Open packs | memory | Cards not yet turned over are given when the UI closes, the player leaves, or the resource stops |
| Set completions | `rsg_cards_bonuses` | One row per character and set the first time all cards were found. Pays the set bonus once (unique key), and the lowest `id` per set is the "first collector". Characters who had already completed a set when the table was added are recorded on start without a bonus |
| Leaderboard names | `rsg_cards_profiles` | Character name per citizenid, updated on login, when a new card is found and when the collection is opened |
| Player trades | memory | A trade only exists while both players are online and in the window; nothing is written until the swap |
| Cards that could not be handed over | `rsg_cards_unclaimed` | A pack card that can't be given (player already gone when they disconnect, inventory full and nowhere to drop it) is stored here by citizenid and given on the next login (`rsg-cards:server:claimUnclaimed`), so it is never lost |
| Vendor stock | rsg-inventory | Persistent when `Config.Shop.PersistStock = true` |

## Security model

What the script enforces:

- The client never names a reward, price or amount of money. Packs are rolled on the server when the pack item is removed; flipping a card only reveals a card the server already chose.
- Every callback and event resolves the player and returns early if there is none.
- Location actions (pickup, vendor, shop, collector) are distance-checked against the server's own coordinates for the player.
- Amounts are checked for type, whole numbers, range and ownership. Only items in `Cards.Info` can be sold or traded.
- Sell prices and trade contents come from server config / server memory.
- Reward, sale and vendor/collector callbacks are rate limited per player (millisecond precision).
- Collectors count and take cards from the player's inventory and the card boxes they carry (vendors follow `Config.Shop.BoxesOnly`). Sell All, Make Set and trades remove cards first and save each touched box once, and hand everything back if a step fails.
- Player trading: the server owns the trade. Clients only send "offer N of X", "ready" and "cancel"; every offer is checked against what the player really carries (inventory and boxes), changing an offer clears both Ready flags so a card can't be swapped in after the other side confirmed, and the swap re-checks ownership, distance and inventory space before moving anything. Cards are removed from both players first and everything is handed back if a step fails. Requests are rate limited and expire.
- Set bonus: paid at most once per character and set (database unique key), amounts come from `Config.SetBonus` and the set's `deckPrice`, never from the client.
- Collector requests can only be completed once per player (`Config.Trades.OncePerPlayer`); completed requests are remembered in memory until the requests refresh. Without this a player could trade the same few cheap cards for a set worth up to $60 over and over.
- World pickups have a per-character cooldown, set before the card is given.
- `CanAddItem` is checked before items are given; a failed removal aborts and refunds a trade.
- All SQL uses `?` parameters. Box serials are validated (`%w+`) before being used in a stash id.
- Sort & Stack: like Bundle Sets, the click carries no data from the client; it is rate limited (2 s), only acts on the player's own open box, and never deletes items (failures return them).
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

CREATE TABLE IF NOT EXISTS `rsg_cards_points` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `item`       VARCHAR(50) NOT NULL,
    `x`          DOUBLE NOT NULL,
    `y`          DOUBLE NOT NULL,
    `z`          DOUBLE NOT NULL,
    `heading`    DOUBLE NOT NULL DEFAULT 0,
    `exact`      TINYINT(1) NOT NULL DEFAULT 0,
    `created_by` VARCHAR(50) NOT NULL DEFAULT 'config',
    PRIMARY KEY (`id`),
    INDEX `idx_item` (`item`)
);

CREATE TABLE IF NOT EXISTS `rsg_cards_pickups` (
    `citizenid` VARCHAR(50) NOT NULL,
    `card`      VARCHAR(50) NOT NULL,
    `picked_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`citizenid`, `card`)
);

CREATE TABLE IF NOT EXISTS `rsg_cards_bonuses` (
    `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`    VARCHAR(50) NOT NULL,
    `set_id`       VARCHAR(20) NOT NULL,
    `completed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_set` (`citizenid`, `set_id`),
    INDEX `idx_set` (`set_id`)
);

CREATE TABLE IF NOT EXISTS `rsg_cards_profiles` (
    `citizenid` VARCHAR(50) NOT NULL,
    `name`      VARCHAR(100) NOT NULL,
    PRIMARY KEY (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `rsg_cards_unclaimed` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`  VARCHAR(50) NOT NULL,
    `card`       VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_citizenid` (`citizenid`)
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

**Change or turn off the set bonus** – `Config.SetBonus.Enabled = false`, or change `Multiplier` (money = the set's `deckPrice` x this) and `Items` (extra rewards).

**Turn off player trading** – `Config.PlayerTrade.Enabled = false`. Allow offering every copy instead of only spares with `DuplicatesOnly = false`. Stop received cards counting for the collection and set bonus with `CountAsFound = false` (recommended if you worry about alt accounts farming set bonuses).

**Hide the Sell Duplicates button** – `Config.Shop.SellDuplicates = false`.

**Reset the leaderboard or titles** – `DELETE FROM rsg_cards_bonuses WHERE set_id = '...'` removes a set's completions and first-collector title; `DELETE FROM rsg_cards_collection` resets what everyone has found.

**Turn off the Sort & Stack button** – `Config.Storage.SortButton = false`. **Sort every time a box opens** – `Config.Storage.SortOnOpen = true`.

**Move or add a vendor / collector** – add an entry to `Config.Shop.Locations` or `Config.Trades.Locations` with a unique `id`, `coords`, `npcmodel` and `npccoords`.

**Move or add a world card** – in game as an admin: `/cardplace grl_c1` (opens the gizmo, confirm to save), or stand next to a card and use `/cardmove` / `/cardremove` (use `/cardedit` first if the card is on cooldown for you). `/cardmissing` lists cards without a location (`card_cigcard_grl_c1` has none in the shipped data). Edits are saved in `rsg_cards_points` and sent to all players immediately. To start over from the config, empty the table and restart the resource (`TRUNCATE rsg_cards_points`).

**Make world cards one-time only** – set `Config.Card.Cooldown` to a very large number of minutes.

**Add cards from a script** – read `CardsServer.points` inside this resource, or `SELECT * FROM rsg_cards_points` from another one; other resources should not write the table directly (use the commands, so every client is updated).

**Reset a character's cooldowns or collection** – `DELETE FROM rsg_cards_pickups WHERE citizenid = '...'` / `DELETE FROM rsg_cards_collection WHERE citizenid = '...'`, then have the player relog.

**Use prompts instead of targeting** – `Config.EnableTarget = false`. Keys are `Config.Card.Key`, `Config.Shop.Key`, `Config.Trades.Key`.

**Turn off voice passthrough** – `Config.AllowPushToTalkWhileOpen = false`.

**Allow repeat trades with collectors** – `Config.Trades.OncePerPlayer = false` (check your set prices first).

**Turn off the update check** – `Config.VersionCheck = false`.

## Vendor and card boxes

Vendors (`server/vendor.lua`) work on everything the player carries: the inventory **and** every card storage box in it (stash `box_<serial>`).

- `CardsServer.countCards(src, scope)` returns `{ [itemName] = amount }`. `scope` is nil (inventory only), `true` (inventory + boxes) or `'boxes'` (boxes only). Vendors use `'boxes'` when `Config.Shop.BoxesOnly = true`, otherwise `true`; collectors and player trades use `true`.
- `CardsServer.getBoxIds(src)` returns the stash ids of the boxes the player carries (only boxes that have been registered, i.e. have a serial).
- `CardsServer.removeCards(src, name, amount, reason, scope, touched)` removes from the inventory first, then from the boxes (`scope = 'boxes'` skips the inventory). It is all-or-nothing: if any step fails the cards already taken are handed back. Box stashes that were changed are saved, or collected in the optional `touched` table so the caller can save them once with `CardsServer.saveStashes(touched)`.
- Make Set removes cards 1-12 (from inventory/boxes) and gives one complete-set item to the inventory. Sell and Sell All pay `cardPrice` per card and `deckPrice` per set from `Config.Sets`.

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

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-cards 3.2.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `oxmysql`, `rsg-target`, `rsg-gizmo`

### Database

Tables: `rsg_cards_boxes`, `rsg_cards_collection`, `rsg_cards_bonuses`, `rsg_cards_profiles`, `rsg_cards_unclaimed`, `rsg_cards_pickups`, `rsg_cards_points`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `install.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.CardPoints` | `table` | coords = vector4(x, y, z, heading) |
| `Config.Debug` | `false` |  |
| `Config.VersionCheck` | `true` | Prints a console message on start when a newer version is available on GitHub. |
| `Config.AutoDatabase` | `true` | Set to false to import install.sql manually instead. |
| `Config.AllowPushToTalkWhileOpen` | `true` | While the NUI is open, block game controls but allow push-to-talk. |
| `Config.PushToTalkControls` | `table` |  |
| `Config.CloseDistance` | `6.0` | The vendor / collector window closes by itself when the player walks further than this from where it was opene |
| `Config.ImagePath` | `'nui://rsg-inventory/html/images/'` | Inventory image folder used for item thumbnails in the UI |
| `Config.Items` | `table` | Item names (must exist in rsg-core shared items, see installation/shared_items.lua) |
| `Config.Pack` | `'card_package_cards'` |  |
| `Config.Box` | `'card_storage_box'` |  |
| `Config.EnableTarget` | `true` | true = rsg-target, false = rsg-core prompts |
| `Config.FadeIn` | `true` | fade NPCs and card props in/out |
| `Config.DistanceSpawn` | `20.0` | distance at which NPCs and card props spawn |
| `Config.Blip` | `table` |  |
| `Config.ShopSprite` | `'blip_rc'` |  |
| `Config.ShopScale` | `0.2` |  |
| `Config.CollectSprite` | `'blip_ambient_secret'` |  |
| `Config.CollectScale` | `0.2` |  |
| `Config.CardsPerSet` | `12` |  |
| `Config.Sets` | `table` |  |
| `Config.Cards` | `4` |  |
| `Config.OpenTime` | `3000` |  |
| `Config.Chances` | `table` | Weights must be whole numbers; these add up to 1000. |
| `Config.Card` | `table` |  |
| `Config.Key` | `'J'` |  |
| `Config.PickupTime` | `3000` |  |
| `Config.PickupDistance` | `3.0` |  |
| `Config.Cooldown` | `360` |  |
| `Config.InspectTime` | `15000` |  |
| `Config.EagleEye` | `table` | Eagle Eye: cards glow and a heartbeat plays when one is close |
| `Config.Storage` | `table` | Use the box to open it beside your inventory; use it again to close just the box. |
| `Config.MaxWeight` | `500` |  |
| `Config.MaxSlots` | `156` |  |
| `Config.OpenDelay` | `300` |  |
| `Config.BundleSets` | `true` | inside the box into the complete-set item (needs rsg-inventory 3.2.0 or newer). |
| `Config.SortButton` | `true` | and puts the box in order: complete sets, then single cards by set and number, then packs. |
| `Config.SortOnOpen` | `false` |  |
| `Config.AllowedCategories` | `{ 'card', 'cardset', 'cardpack' }` | Anything else put in a box is handed straight back to the player. |
| `Config.Sounds` | `table` | Sounds (interact-sound). Skipped automatically if interact-sound isn't running. |
| `Config.Shop` | `table` |  |
| `Config.Payment` | `'cash'` |  |
| `Config.InteractDistance` | `5.0` |  |
| `Config.PersistStock` | `true` |  |
| `Config.CraftSets` | `true` |  |
| `Config.SellDuplicates` | `true` |  |
| `Config.BoxesOnly` | `true` |  |
| `Config.Locations` | `table` |  |
| `Config.Trades` | `table` |  |
| `Config.Refresh` | `90` |  |
| `Config.MaxActive` | `3` |  |
| `Config.MinCards` | `3` |  |
| `Config.MaxCards` | `8` |  |
| `Config.RewardAmount` | `1` |  |
| `Config.OncePerPlayer` | `true` |  |
| `Config.Collection` | `table` |  |
| `Config.Command` | `'cardcollection'` |  |
| `Config.LeaderboardSize` | `10` |  |
| `Config.CacheSeconds` | `60` |  |
| `Config.AnnounceFirst` | `true` |  |
| `Config.SetBonus` | `table` | Reward the first time a character has found all cards of a set. |
| `Config.Enabled` | `true` |  |
| `Config.Multiplier` | `2.0` |  |
| `Config.PlayerTrade` | `table` |  |
| `Config.Distance` | `5.0` |  |
| `Config.InviteSeconds` | `30` |  |
| `Config.MaxPerSide` | `30` |  |
| `Config.DuplicatesOnly` | `true` |  |
| `Config.CountAsFound` | `true` |  |
| `Config.Editor` | `table` | Locations are stored in the database (rsg_cards_points). shared/cards_points.lua is only used to fill an empty |
| `Config.Permission` | `'admin'` |  |
| `Config.SeedFromConfig` | `true` |  |
| `Config.Webhook` | `table` |  |
| `Config.Name` | `'rsg-cards'` |  |
| `Config.Title` | `'CARDS'` |  |
| `Config.Colour` | `'default'` |  |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-cards:server:getCollection` | server | `source, cb` | `server/collection.lua` |
| `rsg-cards:server:getPoints` | server | `source, cb` | `server/points.lua` |
| `rsg-cards:server:flipCard` | server | `source, cb, index` | `server/server.lua` |
| `rsg-cards:server:getPickups` | server | `source, cb` | `server/server.lua` |
| `rsg-cards:server:pickupCard` | server | `source, cb, index` | `server/server.lua` |
| `rsg-cards:server:getTrades` | server | `source, cb, locationId` | `server/trades.lua` |
| `rsg-cards:server:trade` | server | `source, cb, locationId, offerId` | `server/trades.lua` |
| `rsg-cards:server:getVendor` | server | `source, cb, shopId` | `server/vendor.lua` |
| `rsg-cards:server:sell` | server | `source, cb, shopId, name, amount` | `server/vendor.lua` |
| `rsg-cards:server:sellAll` | server | `source, cb, shopId` | `server/vendor.lua` |
| `rsg-cards:server:sellDuplicates` | server | `source, cb, shopId` | `server/vendor.lua` |
| `rsg-cards:server:makeSet` | server | `source, cb, shopId, setId` | `server/vendor.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-cards:server:getCollection', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-cards:client:openPack` | client | `amount` | `client/client.lua` |
| `rsg-cards:client:openCollection` | client | `` | `client/client.lua` |
| `rsg-cards:client:tradeInvite` | client | `name` | `client/client.lua` |
| `rsg-cards:client:tradeState` | client | `state` | `client/client.lua` |
| `rsg-cards:client:tradeClosed` | client | `reason` | `client/client.lua` |
| `rsg-cards:client:boxOpened` | client | `` | `client/client.lua` |
| `rsg-cards:client:inspectCard` | client | `card` | `client/client.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |
| `rsg-cards:client:setPoint` | client | `id, data` | `client/world.lua` |
| `rsg-cards:client:editorToggle` | client | `` | `client/world.lua` |
| `rsg-cards:client:editorPlace` | client | `item` | `client/world.lua` |
| `rsg-cards:client:editorMove` | client | `` | `client/world.lua` |
| `rsg-cards:client:editorRemove` | client | `` | `client/world.lua` |
| `rsg-cards:server:pointAdd` | server | `item, x, y, z, heading` | `server/points.lua` |
| `rsg-cards:server:pointMove` | server | `id, x, y, z, heading` | `server/points.lua` |
| `rsg-cards:server:pointRemove` | server | `id` | `server/points.lua` |
| `rsg-cards:server:ptradeRequest` | server | `targetId` | `server/ptrade.lua` |
| `rsg-cards:server:ptradeRespond` | server | `accept` | `server/ptrade.lua` |
| `rsg-cards:server:ptradeOffer` | server | `name, amount` | `server/ptrade.lua` |
| `rsg-cards:server:ptradeReady` | server | `ready` | `server/ptrade.lua` |
| `rsg-cards:server:ptradeCancel` | server | `` | `server/ptrade.lua` |
| `rsg-cards:server:claimUnclaimed` | server | `` | `server/server.lua` |
| `rsg-cards:server:closePack` | server | `` | `server/server.lua` |
| `rsg-inventory:server:move` | server | `data` | `server/server.lua` |
| `rsg-cards:server:boxClosed` | server | `` | `server/server.lua` |
| `rsg-cards:server:openShop` | server | `shopId` | `server/vendor.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-cards:server:pointAdd', item, x, y, z, heading)
-- from a server script
TriggerClientEvent('rsg-cards:client:openPack', source, amount)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/cardplace` | locale('command_cardplace') | `server/points.lua` |
| `/cardmove` | locale('command_cardmove') | `server/points.lua` |
| `/cardremove` | locale('command_cardremove') | `server/points.lua` |
| `/cardedit` | locale('command_cardedit') | `server/points.lua` |
| `/cardmissing` | locale('command_cardmissing') | `server/points.lua` |
| `/refreshcardtrades` | locale('command_refresh') | `server/trades.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
