-- Server-only settings. This file is never sent to clients, so webhook URLs stay private.

SvConfig = {
    Webhooks = {
        -- Default webhook URL (used if an event-specific URL is not set)
        -- e.g. 'https://discord.com/api/webhooks/...'
        defaultUrl = nil,

        -- Event-specific webhook URLs (optional, override defaultUrl)
        urls = {
            auctionCreated = nil,
            bidPlaced = nil,
            auctionWon = nil,
            auctionExpired = nil,
            auctionCancelled = nil,
            auctionBuyout = nil,
            highValueSale = nil,
        },

        enabled = {
            auctionCreated = true,
            bidPlaced = false,        -- Off by default (can be spammy)
            auctionWon = true,
            auctionBuyout = true,
            auctionExpired = true,
            auctionCancelled = true,
            highValueSale = true,
        },

        highValueThreshold = 1000,   -- Dollars; sales at or above this also post to highValueSale
        maxRetries = 3,
        retryDelay = 1000,           -- ms between retries
        botName = 'Auction House',
        botAvatar = nil,             -- Image URL for the bot avatar (nil = Discord default)
    }
}
