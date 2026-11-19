# rsg-cards

Collectable cigarette cards for the RSG Framework: 144 cards in 12 sets, found in the world, pulled from card packs, traded with collectors and sold to card vendors.

**Version:** 3.2.0 · **Requires:** `rsg-core`, `rsg-inventory` (3.2.0+ for the Bundle Sets button), `rsg-target`, `rsg-gizmo`, `oxmysql` · **Optional:** `interact-sound`, `rsg-log` · **ox_lib:** not required

> Server owners and developers: see **[DOCS.md](DOCS.md)** for the architecture, events, callbacks, security model and database schema.

## Features

- **144 cards in 12 sets**, each with its own artwork, plus a "complete set" item for every set
- **Card packs** – open a pack and turn over 4 cards in a card-flip UI. Rarity chances are configurable
- **Cards in the world** – 143 cards are hidden around the map. Pick one up and that spot goes on a per-character cooldown (saved in the database, survives restarts)
- **Eagle Eye** – world cards glow in Eagle Eye and a heartbeat gets faster the closer you are
- **Card vendors** – buy packs and storage boxes, sell single cards, complete sets or everything at once
- **Make sets** – a vendor spots when you hold all 12 cards of a set (in your inventory or in your card boxes) and turns them into the complete set
- **Boxes count** – vendors check the card boxes you carry as well as your inventory, for sets and single cards, and take what they buy or use from the boxes when your inventory runs out
- **Never lose a card** – cards from a pack that were not turned over when a player left, or that could not be handed over, are kept and given on the next login
- **Card collectors** – NPCs who swap a handful of cards from one set for the complete set. Requests rotate on a timer
- **Storage box** – every box gets its own serial number and stash, opens beside your inventory, and only holds cards, sets and packs. A **Sort & Stack** button merges duplicate cards into single stacks and puts the box in order (sets, then cards by set and number, then packs), and a **Bundle Sets** button at the top of the box turns every complete run of 12 cards inside it into the complete set
- **Inspect** – use a card from your inventory to hold it and turn it over
- **Collection tracking** – the script remembers every card a character has ever found and announces a complete collection
- **Collection viewer and leaderboard** – `/cardcollection` (or the **Collection** button at a vendor) shows every set with the cards you have, and a leaderboard of the top collectors
- **Set bonus** – the first time a character has found all 12 cards of a set they get a bonus (money based on the set's price, and optional items)
- **First collector titles** – the first player on the server to complete each set gets a title in the collection viewer, and everyone online is told
- **Player trading** – swap cards with a nearby player in a window where both sides see the offers and must confirm. Only spare copies can be offered by default, so nobody gives away their last card
- **Sell Duplicates** – one button at the vendor sells every spare copy and keeps one of each card
- **Admin card editor** – place, move and remove world cards in game with rsg-gizmo. Locations are stored in the database, so no config edits or restarts are needed
- Server-authoritative: every reward, price and cooldown is decided on the server
- House-style NUI, push-to-talk keeps working while it is open, rsg-target or prompts, 11 languages

## Installation

1. Put the folder in your resources as `rsg-cards` (the name matters).
2. Add the items in `installation/shared_items.lua` to `rsg-core/shared/items.lua`.
3. Copy the images in `installation/images` to `rsg-inventory/html/images`.
4. Add to `server.cfg`, after its dependencies:
   ```cfg
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-target
   ensure rsg-cards
   ```
5. **Database:** the tables are created automatically on first start. To install by hand instead, set `Config.AutoDatabase = false` and import `install.sql`.
6. Optional: add a `rsg-cards` webhook to rsg-log to get Discord logs.

### Upgrading from tilp-hdrp-collectablecards

- The old `hdrp_boxes` table is renamed to `rsg_cards_boxes` automatically, so existing boxes keep their contents.
- The pack item is `card_package_cards` (the old code looked for the misspelt `card_packge_cards`).
- Single cards must be `useable = true` in `rsg-core/shared/items.lua` to be inspected. `installation/shared_items.lua` has been updated (it also adds the `card` / `cardset` / `cardpack` categories and makes the box `shouldClose = false`); copy it over your old entries.
- `shared/config.lua` has a new layout. Start from the new file and re-apply your changes.
- The rsg-log webhook name is now `rsg-cards`.

## Configuration

Everything is in `shared/config.lua`.

| Option | Default | Description |
|---|---|---|
| `Config.Debug` | `false` | Extra console output |
| `Config.VersionCheck` | `true` | Prints a console message on start when a newer version is on GitHub |
| `Config.AutoDatabase` | `true` | Create tables on start. `false` = import `install.sql` yourself |
| `Config.CloseDistance` | `6.0` | The vendor / collector window closes by itself when the player walks this far from where it was opened (it also closes on death) |
| `Config.AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk working while the UI is open |
| `Config.PushToTalkControls` | `{ 0x4BC9DABB }` | Controls left enabled while the UI is open |
| `Config.ImagePath` | `nui://rsg-inventory/html/images/` | Where item thumbnails come from |
| `Config.Items.Pack` / `.Box` | `card_package_cards` / `card_storage_box` | Item names |
| `Config.EnableTarget` | `true` | `true` = rsg-target, `false` = rsg-core prompts |
| `Config.FadeIn` | `true` | Fade NPCs and card props in and out |
| `Config.DistanceSpawn` | `20.0` | Spawn distance for NPCs and card props |
| `Config.Blip` | shop on, others off | Blips for vendors, collectors and card locations |
| `Config.Sets` | 12 sets | Set id, rarity tier, vendor prices, landscape flag |
| `Config.Pack.Cards` | `4` | Cards per pack |
| `Config.Pack.OpenTime` | `3000` | Progress bar when opening a pack (ms) |
| `Config.Pack.Chances` | see file | Weighted chance per rarity tier (`deck` = complete set) |
| `Config.Card.PickupTime` | `3000` | Progress bar when picking up a card (ms) |
| `Config.Card.PickupDistance` | `3.0` | Interaction distance for world cards |
| `Config.Card.Cooldown` | `360` | Minutes before a character can collect the same card again |
| `Config.Card.InspectTime` | `15000` | Longest time a card is held when inspected (ms) |
| `Config.Card.EagleEye` | enabled, 50 m | Eagle Eye glow and heartbeat hint |
| `Config.Storage` | 500 weight, 156 slots, 300 ms | Size of a storage box, and the delay before it opens when the box item is `shouldClose = true` |
| `Config.Storage.BundleSets` | `true` | Shows the **Bundle Sets** button on a box (needs rsg-inventory 3.2.0+) |
| `Config.Storage.SortButton` | `true` | Shows the **Sort & Stack** button on a box (needs rsg-inventory 3.2.0+) |
| `Config.Storage.SortOnOpen` | `false` | Also sorts and stacks the box automatically every time it is opened |
| `Config.Storage.AllowedCategories` | `card`, `cardset`, `cardpack` | Item categories a box accepts. rsg-cards cards, sets and packs are always accepted; anything else is handed back |
| `Config.Sounds` | enabled | interact-sound names for opening a pack / flipping a card |
| `Config.Shop.Payment` | `cash` | Money type paid for sold cards (`cash` or `bloodmoney`) |
| `Config.Shop.CraftSets` | `true` | Vendors turn all 12 cards of a set into the complete set |
| `Config.Shop.BoxesOnly` | `true` | Vendors only look in the card boxes the player carries; `false` also uses loose cards in the inventory |
| `Config.Shop.Items` | pack $5, box $50 | What vendors sell (`amount` = stock) |
| `Config.Shop.Locations` | 2 | Vendor NPCs |
| `Config.Trades.Refresh` | `90` | Minutes between new collector requests |
| `Config.Trades.MaxActive` | `3` | Requests per collector |
| `Config.Trades.MinCards` / `MaxCards` | `3` / `8` | Cards a request asks for |
| `Config.Trades.RewardAmount` | `1` | Complete sets given per trade |
| `Config.Trades.OncePerPlayer` | `true` | Each request can be completed once per player until the requests refresh (stops endless cheap-cards-for-sets trading) |
| `Config.Trades.Locations` | 12 | Collector NPCs |
| `Config.Shop.SellDuplicates` | `true` | Shows the **Sell Duplicates** button at vendors |
| `Config.Collection` | `/cardcollection`, top 10, 60 s cache | Command name, leaderboard size, how long the leaderboard is cached, announce the first player to complete a set |
| `Config.SetBonus` | on, 2x set price, no items | Reward for finding all cards of a set: `Payment`, `Multiplier` (x the set's `deckPrice`) and extra `Items` |
| `Config.PlayerTrade` | on, `/cardtrade`, 5 m | Player trading: `Distance`, `InviteSeconds`, `MaxPerSide`, `DuplicatesOnly` (only spare copies can be offered), `CountAsFound` (received cards count for the collection and set bonus) |
| `Config.Webhook` | `rsg-cards` | rsg-log webhook name, title and colour |

| `Config.Editor` | on, `admin` | Admin card editor: `Permission`, `SeedFromConfig`, `Distance` |

Card locations live in the database table `rsg_cards_points`. `shared/cards_points.lua` is only used to fill an empty table on the first start (when `Config.Editor.SeedFromConfig = true`); after that use the editor commands below.

## How to use

| Action | How |
|---|---|
| Open a pack | Use `card_package_cards`, then click each card to turn it over. Cards you don't turn over are still given when you close |
| Find a card | Walk up to a card in the world and target it (or press the prompt key). Use Eagle Eye to spot them |
| Look at a card | Use the card from your inventory |
| Store cards | Use `card_storage_box` to open it beside your inventory, then drag cards in. Use the box again to close just the box. The first use registers its serial number |
| Sort & stack a box | Open your storage box and press **Sort & Stack** at the top. Duplicate cards are merged into one stack each and the box is put in order: complete sets, then single cards by set and number, then packs |
| Bundle complete sets | Open your storage box and press **Bundle Sets** at the top. Every set you have all 12 cards of inside the box is combined into the complete set (duplicates make extra sets); spare cards stay as they are |
| Sell cards and sets / buy packs | Talk to a card vendor |
| Sell spare copies | Press **Sell Duplicates** at a vendor. One of each single card is kept (complete sets are never sold by this button) |
| See your collection | `/cardcollection` or the **Collection** button at a vendor. **My Collection** lists every set and card; **Leaderboard** shows the top collectors and who was first to complete each set |
| Trade with a player | Stand next to them and target them (**Trade cards**) or use `/cardtrade [id]`. They accept, both click cards to offer them, either side can take a card back, and both press **Ready** to swap. Changing an offer clears both Ready buttons |
| Get a complete set | Collect all 12 cards of a set and press **Bundle Sets** on your storage box or **Make Set** at a card vendor, or bring a card collector the cards they ask for |

### Commands

| Command | Permission | Description |
|---|---|---|
| `/refreshcardtrades` | admin | Give every collector new requests now |
| `/cardcollection` | everyone | Open your collection and the leaderboard (name set by `Config.Collection.Command`) |
| `/cardtrade [id]` | everyone | Ask a nearby player to trade cards (name set by `Config.PlayerTrade.Command`) |
| `/cardplace [card]` | admin | Place a card with the gizmo, e.g. `/cardplace grl_c1`. Saved to the database |
| `/cardmove` | admin | Move the nearest world card with the gizmo |
| `/cardremove` | admin | Delete the nearest world card |
| `/cardedit` | admin | Toggle showing every world card, ignoring your own cooldowns (so you can find the one to move or remove) |
| `/cardmissing` | admin | List cards that have no world location |

Give items for testing: `/giveitem [id] card_package_cards 1`, `/giveitem [id] card_storage_box 1`.

## For developers

```lua
-- inside rsg-cards: shared lookup built from Config.Sets (client and server)
local info = Cards.Info['card_cigcard_act_c1'] -- { set = 'act', tier = 'basic', number = 1, price = 0.5, model = 's_inv_cigcard_act_01x', ... }
print(Cards.Total) -- 144
```

Adding a set: add a line to `Config.Sets`, add the 13 items (`card_cigcard_<id>` and `card_cigcard_<id>_c1`–`_c12`) to rsg-core, and add the card artwork to `html/img` as `<item name>.png`.

## Locales

`en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"` in `server.cfg`.

## Credits

Original script (tilp-hdrp-collectablecards) by Sadicius ([linktr.ee/sadicius](https://linktr.ee/sadicius)) and Tankie ([linktr.ee/tankietwitch](https://linktr.ee/tankietwitch)).

Support the Project : https://rexshack.tebex.store/
