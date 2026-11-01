# rsg-auction

A real-time, town-based auction house for RedM servers running the **RSG Framework**. Players list items at auctioneer NPCs, bid against each other live, use instant buyouts, and collect their winnings or earnings in person at the auctioneer.

---

## Features

- **Town-specific auction houses**: each auctioneer NPC (Valentine, Rhodes, Saint Denis, Blackwater, Armadillo by default) runs its own market. Players only see and trade the auctions for the town they're standing in.
- **Live bidding**: every open UI updates instantly when someone bids, an auction ends, or one is cancelled.
- **Escrow system**: listed items and bids are held by the server. Outbid players are refunded automatically, straight to the bank if they're online or queued for collection if they're offline.
- **Buyout prices**: sellers can set an optional "Buy Now" price (with a configurable minimum multiplier of the starting bid). Buyout is disabled once bidding passes the buyout price.
- **Anti-snipe protection**: a bid placed in the final seconds extends the auction.
- **Collection kiosk**: won items, returned items and sale earnings wait at any auctioneer until the player collects them. Earnings from several sales add up.
- **Creation fees**: optional listing fee based on duration and quantity, with min/max caps and a live preview in the UI.
- **Categories, search and pagination**: filter by category, search by item name, label or auction ID, and switch between "All" and "My Auctions" in list or card view.
- **Login reminders**: players are told on login if they have items or money waiting.
- **Discord webhooks**: optional embeds for created, bid, won, buyout, expired, cancelled and high-value sales, with admin commands to manage them in-game.
- **MySQL persistence**: auctions, bids, pending collections and payouts are stored in the database (oxmysql). Tables are created automatically, timers resume after restarts, and finished auctions are pruned after a configurable number of days.
- **RDR2 leather & gold UI**: a dark monochrome React interface with custom (non-native) dropdowns, rsg-core notifications and full translations.
- **10 languages**: en, de, el, es, fr, ja, nl, pl, pt-br, ro (game text *and* UI).
- **Auto-close**: the UI closes if the player walks away from the auctioneer or dies.

### Security

All money and item handling happens on the server:

- Item labels, metadata and images come from the server (`RSGCore.Shared.Items` and the player's actual inventory slot), never from the client.
- Every action (create, bid, buyout, cancel, collect, open) is checked server-side against the player's distance to the right auctioneer.
- Amounts are integer cents, validated and capped (`Config.MaxPrice`).
- Per-action rate limits, per-auction locks to stop race conditions, an item blacklist, and a max active auctions per player.
- Players' citizen IDs and server IDs are never sent to clients. Every payload is scrubbed and the UI only sees opaque per-restart tokens, enough to mark "your auction" and "winning" and nothing more.
- Discord webhook URLs live in `server/sv_config.lua`, which is never sent to clients.

---

## Dependencies

| Resource | Notes |
|---|---|
| [rsg-core](https://github.com/Rexshack-RedM/rsg-core) | Framework |
| [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) | Item add/remove and item images |
| [oxmysql](https://github.com/overextended/oxmysql) | Database |
| [rsg-target](https://github.com/Rexshack-RedM/rsg-target) | NPC interaction |

---

## Installation

1. Download or clone the resource into your server's `resources` folder, e.g. `resources/[rsg]/rsg-auction`.
2. Make sure the dependencies start **before** it in your `server.cfg`:
   ```cfg
   ensure oxmysql
   ensure rsg-core
   ensure rsg-target
   ensure rsg-inventory
   ensure rsg-auction
   ```
3. Database: the tables are created automatically on first start. If you'd rather create them yourself, run `installation/rsg-auction.sql` against your server database.
4. Adjust `shared/config.lua` (gameplay) and `server/sv_config.lua` (webhooks) to suit your server (see below).
5. Restart the server.

> **Updating from a version that used `auctions.json`:** on the first start the file is imported into the database automatically. The original is kept as `auctions.json.bak`, and `auctions.json` is marked as imported so it is never imported twice. Back up both your database and `auctions.json` before updating.

### Building the UI (optional)

The compiled UI ships in `web/dist`, so you only need this if you change the React source in `web/`:

```bash
cd web
npm ci
npm run build
```

---

## Configuration

Gameplay settings are in `shared/config.lua`; webhook settings are in `server/sv_config.lua`.

### Auction settings

| Option | Default | Description |
|---|---|---|
| `MinStartingBid` | `0.01` | Lowest allowed starting bid (dollars) |
| `MaxPrice` | `1000000` | Maximum starting bid, bid or buyout (dollars) |
| `MinDuration` / `MaxDuration` | `60` / `604800` | Allowed auction length in seconds (1 minute to 7 days) |
| `DefaultDuration` | `3600` | Duration used if none is given |
| `MaxAuctionsPerPlayer` | `10` | Active listings per character |
| `MinBidIncrement` | `0.05` | Minimum raise over the current bid (5%) |
| `HistoryRetentionDays` | `7` | Finished auctions are removed from the save after this long |
| `InteractionDistance` | `2.5` | rsg-target distance to auctioneers |
| `NpcSpawnDistance` | `60.0` | Auctioneer peds spawn within this range of the player |
| `NotificationDuration` | `5000` | Notification duration (ms) |
| `Debug` | `false` | Extra console logging |

### Anti-snipe

```lua
AntiSnipe = {
    enabled = true,
    window = 60,    -- a bid in the last 60 seconds...
    extendBy = 120, -- ...resets the timer to 120 seconds
},
```

### Buyout

```lua
Buyout = {
    enabled = true,
    minMultiplier = 1.5, -- buyout must be at least 1.5x the starting bid
},
```

### Creation fee

`fee = baseFee + (durationMultiplier × hours) + (quantityMultiplier × quantity)`, clamped between `minFee` and `maxFee`.

```lua
CreationFee = {
    enabled = true,
    baseFee = 0.50,
    durationMultiplier = 0.10,
    quantityMultiplier = 0.10,
    maxFee = 500,
    minFee = 0.50,
},
```

### Rate limits (ms between actions, per player)

```lua
RateLimits = {
    createAuction = 5000,
    placeBid = 1000,
    buyoutAuction = 3000,
    collectItem = 500,
    collectMoney = 500,
    cancelAuction = 2000,
},
```

### Blacklisted items

Items that can never be listed (money items are blocked by default):

```lua
BlacklistedItems = { 'dollar', 'cent', 'blood_dollar', 'blood_cent', 'money_clip', 'blood_money_clip' },
```

### Categories

Players pick one when listing. Add, remove or rename freely; `id` must be unique.

```lua
{ id = 'pelts', label = 'Pelts & Hides', icon = '🦌', description = 'Animal pelts, hides, and taxidermy' },
```

### Auctioneer NPCs and towns

Each NPC belongs to a `location` (its town market). To add a new town, add an NPC with a new `location` id and a `locationLabel`. Several NPCs can share a `location`.

```lua
AuctioneerNPCs = {
    {
        model = 'cs_valauctionboss_01',
        coords = vector3(-240.97, 658.76, 113.33),
        heading = 149.33,
        name = 'Valentine Auctioneer',
        location = 'valentine',
        locationLabel = 'Valentine'
    },
},
```

NPCs only spawn when a player is nearby. Every auctioneer gets a map blip.

### Discord webhooks (`server/sv_config.lua`)

```lua
SvConfig.Webhooks = {
    defaultUrl = 'https://discord.com/api/webhooks/...', -- used when no event URL is set
    urls = {
        auctionCreated = nil, bidPlaced = nil, auctionWon = nil, auctionBuyout = nil,
        auctionExpired = nil, auctionCancelled = nil, highValueSale = nil,
    },
    enabled = {
        auctionCreated = true, bidPlaced = false, auctionWon = true, auctionBuyout = true,
        auctionExpired = true, auctionCancelled = true, highValueSale = true,
    },
    highValueThreshold = 1000, -- dollars; sales at or above this also go to highValueSale
    maxRetries = 3,
    retryDelay = 1000,
    botName = 'Auction House',
    botAvatar = nil,
}
```

Only `https://discord.com/api/webhooks/` URLs are accepted. Failed sends are retried 3 times, then logged to `webhook_errors.log`.

### Locales

All text, game and UI, lives in `locales/<lang>.json` (rsg-core locale loader, ox_lib-compatible JSON). Keys starting with `ui.` are sent to the NUI when it opens, so translations need **no UI rebuild**; `web/locales.ts` only holds the English fallback. Shipped languages: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Pick one with `setr rsg:locale "de"` in your `server.cfg`.

---

## How to use

### Players

1. **Find an auctioneer**: look for the auction blip in any configured town and use **rsg-target** on the NPC to open the auction house.
2. **Browse**: filter by category, search, or switch to *My Auctions*. Click an auction for details and bid history.
3. **Create an auction**: choose *Create Auction*, pick an item from your inventory (each stack is listed separately, so you choose exactly which one, e.g. which revolver; blacklisted items aren't shown), set the quantity, category, starting bid, duration and an optional buyout price. The listing fee is shown before you confirm. The item is taken from your inventory and held until the auction ends.
4. **Bid**: enter an amount (at least the minimum shown, or press *Min*) and place your bid. The money is held immediately. If you're outbid it's refunded automatically. Raising your own bid only charges the difference.
5. **Buy now**: if a buyout price is listed (and bidding hasn't passed it), buy the item instantly.
6. **Cancel**: you can cancel your own auction while it has no bids. The item goes back to your inventory, or to collection if your inventory is full.
7. **Collect**: when you win, sell, or an auction expires with no bids, visit **any auctioneer** and open *Collect Items* to claim your items and earnings (paid to your bank).

Money is taken from **cash first, then bank**. Earnings and refunds are paid to the **bank**.

### Admins (console or players with the rsg-core `admin` permission)

| Command | Description |
|---|---|
| `auctionwebhook <event> <url>` | Set a webhook URL at runtime (`default` or any event name) |
| `auctionwebhooktoggle <event> <true/false>` | Enable or disable an event's webhook |
| `auctionwebhookstatus` | Show the current webhook setup |

Runtime webhook changes reset on restart. Put permanent values in `server/sv_config.lua`.

---

## Database

| Table | Contents |
|---|---|
| `rsg_auctions` | Every auction (active and recently finished), including what is held in escrow (`escrow_item`, `escrow_amount`) |
| `rsg_auction_bids` | Bid history. Rows are deleted automatically with their auction. |
| `rsg_auction_collections` | Items waiting to be collected at an auctioneer (won, expired or returned) |
| `rsg_auction_payouts` | Each player's total uncollected money |

All money columns are stored in **cents** (e.g. `1250` = $12.50).

The server keeps live state in memory and writes every change to the database in order, in the background, so gameplay never waits on MySQL. The database is read only at resource start, so **stop the resource before editing the tables by hand**, otherwise your edits will be overwritten.

### Other files

| File | Purpose |
|---|---|
| `installation/rsg-auction.sql` | Optional manual table creation |
| `webhook_errors.log` | Webhook sends that failed after all retries |
| `auctions.json.bak` | Backup of the old JSON save, only present if one was imported |

---

## Credits

Created by **RexShack** for the RSG Framework community.

Support: https://buymeacoffee.com/rexshack
