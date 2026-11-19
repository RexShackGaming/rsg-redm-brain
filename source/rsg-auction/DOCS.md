# rsg-auction – Docs (v3.1.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Events and commands
5. Database
6. Security
7. Server owner how-tos
8. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql` |
| `shared/config.lua` | Categories, limits, fees, blacklist, auctioneer NPCs |
| `shared/money.lua` | Money helpers |
| `client/main.lua`, `client/npc.lua` | NUI bridge, auctioneer NPCs |
| `server/main.lua` | Auctions, bids, escrow, collections |
| `server/database.lua` | Automatic table creation |
| `server/sv_config.lua`, `server/webhooks.lua` | Webhook settings, Discord embeds and admin commands |
| `server/versionchecker.lua` | GitHub version check |
| `web/` | React/Tailwind NUI source; `web/dist/` is the built UI that the resource loads |
| `installation/rsg-auction.sql` | Manual database install |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 2. How it works
- Town-specific auction houses: each auctioneer NPC runs its own market (Valentine, Rhodes, Saint Denis, Blackwater, Armadillo by default). Players see only the auctions for the town they are in.
- Live bidding: every open UI updates when someone bids, an auction ends or is cancelled.
- **Escrow:** listed items and bids are held by the server. Outbid players are refunded automatically (to the bank if online, queued if offline).
- **Buyout:** optional "Buy Now" price, at least `Buyout.minMultiplier` times the start bid. Disabled once bidding passes it.
- **Anti-snipe:** a bid in the final `window` seconds extends the auction to `extendBy` seconds.
- **Collection kiosk:** won items, returned items and sale earnings wait at any auctioneer. Earnings from several sales add up.
- **Creation fee:** `baseFee + durationMultiplier × hours + quantityMultiplier × quantity`, capped, with a live preview.
- Categories, search (name, label or auction ID) and pagination; "All" and "My Auctions" views. Login reminders for waiting items or money.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `Categories` | list | `id`, `label`, `icon`, `description` (weapons, ammunition, clothing, food, resources, pelts, medicine, tools, valuables, other) |
| `MinStartingBid` | `0.01` | Minimum starting bid |
| `MinDuration` / `MaxDuration` / `DefaultDuration` | `60` / `604800` / `3600` | Seconds |
| `MaxAuctionsPerPlayer` | `10` | Active auctions per player |
| `MaxPrice` | `1000000` | Max bid/buyout |
| `HistoryRetentionDays` | `7` | Days finished auctions are kept |
| `AntiSnipe` | table | `enabled`, `window` (60), `extendBy` (120) |
| `RateLimits` | table | ms between create, bid, buyout, collect, cancel actions |
| `MinBidIncrement` | `0.05` | 5% minimum raise |
| `Buyout` | table | `enabled`, `minMultiplier` (1.5) |
| `CreationFee` | table | `enabled`, `baseFee`, `durationMultiplier`, `quantityMultiplier`, `maxFee`, `minFee` |
| `BlacklistedItems` | list | Items that can't be auctioned (money items) |
| `AuctioneerNPCs` | list | `model`, `coords`, `heading`, `name`, `location` (decides which town's market) |

Webhook URLs are in `server/sv_config.lua`.

## 4. Events and commands
| Name | Side | Notes |
|---|---|---|
| `auction:server:getAuctions` | server event | `(location)` |
| `auction:server:searchAuctions` | server event | `(params)` |
| `auction:server:createAuction` | server event | `(data)` |
| `auction:server:placeBid` | server event | `(auctionId, amount)` |
| `auction:server:buyoutAuction` | server event | `(auctionId)` |
| `auction:server:cancelAuction` | server event | `(auctionId)` |
| `auction:server:getPendingCollections` | server event | |
| `auction:server:collectItem` | server event | `(auctionId, itemName)` |
| `auction:server:collectMoney` | server event | |
| `auction:server:validateNPCInteraction` | server event | NPC proximity check |
| `auction:client:update`, `createResult`, `cancelResult`, `collectionResult`, `notification`, `webhookResult`, `openFromNPC` | client events | UI updates |

| Command | Who | What |
|---|---|---|
| `/auctionwebhook` | admin | Manage Discord webhooks in game |
| `/auctionwebhooktoggle` | admin | Turn a webhook type on or off |
| `/auctionwebhookstatus` | admin | Show webhook status |

## 5. Database
Created automatically on start: `rsg_auctions`, `rsg_auction_bids`, `rsg_auction_collections`, `rsg_auction_payouts`. Import `installation/rsg-auction.sql` if automatic creation fails.

## 6. Security
Everything is validated on the server: distance to an auctioneer, ownership and quantity of the item, price limits, per-action rate limits, and the blacklist. Items and bids are held in escrow; the client only sends requests.

## 7. How-tos
- Add a town: add an `AuctioneerNPCs` entry with a new `location`.
- Edit the UI: change `web/` and rebuild into `web/dist/` (`npm install`, then your build script).
- Language: `setr rsg:locale "de"` in server.cfg.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| UI blank | `web/dist/` must exist and be in the manifest files |
| Can't list an item | It's in `BlacklistedItems`, or you hit `MaxAuctionsPerPlayer` |
| Money missing | Collect it at an auctioneer (`collectMoney`) |
| No Discord posts | Configure `server/sv_config.lua`; check `/auctionwebhookstatus` |

Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-auction 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

### Database

Tables: `rsg_auctions`, `rsg_auction_bids`, `rsg_auction_collections`, `rsg_auction_payouts`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/rsg-auction.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.Categories` | `table` | Players select a category when creating an auction |
| `Config.MinStartingBid` | `0.01` | Auction Settings |
| `Config.MinDuration` | `60` |  |
| `Config.MaxDuration` | `604800` |  |
| `Config.DefaultDuration` | `3600` |  |
| `Config.MaxAuctionsPerPlayer` | `10` |  |
| `Config.MaxPrice` | `1000000` |  |
| `Config.HistoryRetentionDays` | `7` |  |
| `Config.AntiSnipe` | `table` | Anti-snipe: a bid placed in the last `window` seconds extends the auction to `extendBy` seconds |
| `Config.RateLimits` | `table` | Rate Limiting (milliseconds between actions) |
| `Config.MinBidIncrement` | `0.05` | Bid Settings |
| `Config.Buyout` | `table` | Buyout Price Settings |
| `Config.CreationFee` | `table` | Fee formula: BaseFee + (DurationMultiplier * hours) + (QuantityMultiplier * quantity) |
| `Config.BlacklistedItems` | `table` | Items in this list cannot be auctioned by players |
| `Config.AuctioneerNPCs` | `table` | Auctions are TOWN-SPECIFIC: players can only see auctions from the town they're in |
| `Config.InteractionDistance` | `2.5` | NPC Interaction Settings (rsg-target) |
| `Config.NotificationDuration` | `5000` | Notification Settings |
| `Config.NpcSpawnDistance` | `60.0` |  |
| `Config.Debug` | `false` | Debug |

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `auction:client:update` | client | `payload` | `client/main.lua` |
| `auction:client:createResult` | client | `result` | `client/main.lua` |
| `auction:client:cancelResult` | client | `result` | `client/main.lua` |
| `auction:client:collectionResult` | client | `result` | `client/main.lua` |
| `auction:client:notification` | client | `data` | `client/main.lua` |
| `auction:client:webhookResult` | client | `data` | `client/main.lua` |
| `auction:client:openFromNPC` | client | `locationData` | `client/npc.lua` |
| `auction:server:getAuctions` | server | `location` | `server/main.lua` |
| `auction:server:searchAuctions` | server | `params` | `server/main.lua` |
| `auction:server:reportMissingImage` | server | `itemName` | `server/main.lua` |
| `auction:server:createAuction` | server | `data` | `server/main.lua` |
| `auction:server:placeBid` | server | `auctionId, amount` | `server/main.lua` |
| `auction:server:buyoutAuction` | server | `auctionId` | `server/main.lua` |
| `auction:server:cancelAuction` | server | `auctionId` | `server/main.lua` |
| `auction:server:getPendingCollections` | server | `` | `server/main.lua` |
| `auction:server:collectItem` | server | `auctionId, itemName` | `server/main.lua` |
| `auction:server:collectMoney` | server | `` | `server/main.lua` |
| `auction:server:validateNPCInteraction` | server | `data` | `server/main.lua` |

```lua
-- from a client script
TriggerServerEvent('auction:server:getAuctions', location)
-- from a server script
TriggerClientEvent('auction:client:update', source, payload)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/auctionwebhook` |  | `server/webhooks.lua` |
| `/auctionwebhooktoggle` |  | `server/webhooks.lua` |
| `/auctionwebhookstatus` |  | `server/webhooks.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
