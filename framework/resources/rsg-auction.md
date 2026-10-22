# rsg-auction

Version 3.0.0. Real-time auction system for RSG Framework

A real-time, town-based auction house for RedM servers running the **RSG Framework**. Players list items at auctioneer NPCs, bid against each other live, use instant buyouts, and collect their winnings or earnings in person at the auctioneer. - **Town-specific auction houses**: each auctioneer NPC (Valentine, Rhodes, Saint Denis, Blackwater, Armadillo by default) runs its own market. Players only 

Source: https://github.com/Rexshack-RedM/rsg-auction

**Dependencies:** `rsg-core`, `rsg-inventory`, `oxmysql`, `ox_lib`, `ox_target`

Has NUI (`ui_page`).

## Net events registered

**server:** `auction:server:buyoutAuction`, `auction:server:cancelAuction`, `auction:server:collectItem`, `auction:server:collectMoney`, `auction:server:createAuction`, `auction:server:getAuctions`, `auction:server:getPendingCollections`, `auction:server:placeBid`, `auction:server:reportMissingImage`, `auction:server:searchAuctions`, `auction:server:validateNPCInteraction`

**client:** `auction:client:cancelResult`, `auction:client:collectionResult`, `auction:client:createResult`, `auction:client:notification`, `auction:client:openFromNPC`, `auction:client:update`, `auction:client:webhookResult`

## Event handlers

**server:** `RSGCore:Server:PlayerLoaded`

## Commands (RegisterCommand)

**server:** `/auctionwebhook`, `/auctionwebhookstatus`, `/auctionwebhooktoggle`

## Server events it triggers in other resources

**client:** `auction:server:buyoutAuction`, `auction:server:cancelAuction`, `auction:server:collectItem`, `auction:server:collectMoney`, `auction:server:createAuction`, `auction:server:getAuctions`, `auction:server:getPendingCollections`, `auction:server:placeBid`, `auction:server:reportMissingImage`, `auction:server:searchAuctions`, `auction:server:validateNPCInteraction`

## Public (table) functions

**client/main.lua:** `NUI.SendMessage(action, data)`, `NUI.Open(data)`, `NUI.Close()`, `NUI.IsOpen()`

**server/database.lua:** `AuctionDB.init()`, `AuctionDB.loadAll(historyLimit)`, `AuctionDB.pendingWrites()`, `AuctionDB.saveAuction(auction, escrowItem, escrowFunds)`, `AuctionDB.deleteAuction(auctionId)`, `AuctionDB.insertBid(auctionId, bid)`, `AuctionDB.addCollection(citizenid, entry)`, `AuctionDB.removeCollection(id)`, `AuctionDB.setPayout(citizenid, amountCents, reason)`

**server/webhooks.lua:** `EmbedBuilders.auctionCreated(data)`, `EmbedBuilders.bidPlaced(data)`, `EmbedBuilders.auctionWon(data)`, `EmbedBuilders.auctionBuyout(data)`, `EmbedBuilders.auctionExpired(data)`, `EmbedBuilders.auctionCancelled(data)`, `EmbedBuilders.highValueSale(data)`

**shared/money.lua:** `Money.dollarsToCents(dollars)`, `Money.centsToDollars(cents)`, `Money.format(cents)`, `Money.formatWithCommas(cents)`

## Database tables

`rsg_auction_bids`, `rsg_auction_collections`, `rsg_auction_payouts`, `rsg_auctions`
