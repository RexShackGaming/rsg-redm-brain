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
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

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
