-- Auction System Configuration

Config = {
    -- Categories for Auction Items
    -- Players select a category when creating an auction
    Categories = {
        {
            id = 'weapons',
            label = 'Weapons',
            icon = '🔫',
            description = 'Firearms, melee weapons, and ammunition'
        },
        {
            id = 'ammunition',
            label = 'Ammunition',
            icon = '🎯',
            description = 'Bullets, arrows, and throwing weapons'
        },
        {
            id = 'clothing',
            label = 'Clothing',
            icon = '👒',
            description = 'Apparel, hats, and accessories'
        },
        {
            id = 'food',
            label = 'Food & Drink',
            icon = '🥩',
            description = 'Consumables, provisions, and beverages'
        },
        {
            id = 'resources',
            label = 'Resources',
            icon = '🪨',
            description = 'Ores, minerals, and raw materials'
        },
        {
            id = 'pelts',
            label = 'Pelts & Hides',
            icon = '🦌',
            description = 'Animal pelts, hides, and taxidermy'
        },
        {
            id = 'medicine',
            label = 'Medicine',
            icon = '💊',
            description = 'Tonics, medicines, and healing items'
        },
        {
            id = 'tools',
            label = 'Tools',
            icon = '🔧',
            description = 'Tools, kits, and crafting supplies'
        },
        {
            id = 'valuables',
            label = 'Valuables',
            icon = '💎',
            description = 'Jewelry, gold, and valuable items'
        },
        {
            id = 'other',
            label = 'Other',
            icon = '📦',
            description = 'Miscellaneous items'
        }
    },
    
    -- Auction Settings
    MinStartingBid = 0.01,      -- Minimum starting bid in dollars (1 cent)
    MinDuration = 60,           -- Minimum auction duration in seconds (1 minute)
    MaxDuration = 604800,       -- Maximum auction duration in seconds (7 days)
    DefaultDuration = 3600,     -- Default duration (1 hour)
    MaxAuctionsPerPlayer = 10,  -- Maximum active auctions per player
    MaxPrice = 1000000,         -- Maximum starting bid / bid / buyout in dollars
    HistoryRetentionDays = 7,   -- Finished auctions are pruned from the save file after this many days

    -- Anti-snipe: a bid placed in the last `window` seconds extends the auction to `extendBy` seconds
    AntiSnipe = {
        enabled = true,
        window = 60,
        extendBy = 120,
    },
    
    -- Rate Limiting (milliseconds between actions)
    RateLimits = {
        createAuction = 5000,   -- 5 seconds between creating auctions
        placeBid = 1000,        -- 1 second between bids
        buyoutAuction = 3000,   -- 3 seconds between buyouts
        collectItem = 500,      -- 0.5 seconds between item collections
        collectMoney = 500,     -- 0.5 seconds between money collections
        cancelAuction = 2000,   -- 2 seconds between cancellations
    },
    
    -- Bid Settings
    MinBidIncrement = 0.05,     -- 5% minimum increase over current bid (used by server and UI)

    -- Buyout Price Settings
    Buyout = {
        enabled = true,              -- Enable/disable buyout feature
        minMultiplier = 1.5,         -- Buyout must be at least 1.5x the starting bid
    },
    
    -- Auction Creation Fee Settings
    -- Fee formula: BaseFee + (DurationMultiplier * hours) + (QuantityMultiplier * quantity)
    CreationFee = {
        enabled = true,              -- Enable/disable creation fees
        baseFee = 0.50,              -- Base fee for any auction
        durationMultiplier = 0.10,   -- Fee per hour of duration
        quantityMultiplier = 0.10,   -- Fee per item quantity
        maxFee = 500,                -- Maximum fee cap
        minFee = 0.50,               -- Minimum fee (base fee)
    },
    
    -- Item Blacklist
    -- Items in this list cannot be auctioned by players
    BlacklistedItems = {
        'dollar',
        'cent',
        'blood_dollar',
        'blood_cent',
        'money_clip',
        'blood_money_clip',
    },
    
    -- NPC Auctioneers
    -- Players interact with these NPCs to open the auction UI
    -- Each NPC has a 'location' field that determines which town's auctions are shown
    -- Auctions are TOWN-SPECIFIC: players can only see auctions from the town they're in
    AuctioneerNPCs = {
        {
            model = 'cs_valauctionboss_01',
            coords = vector3(-240.97, 658.76, 113.33),
            heading = 149.33,
            name = 'Valentine Auctioneer',
            location = 'valentine',
            locationLabel = 'Valentine'
        },
        {
            model = 'cs_valauctionboss_01',
            coords = vector3(1219.21, -1273.62, 76.40),
            heading = 281.20,
            name = 'Rhodes Auctioneer',
            location = 'rhodes',
            locationLabel = 'Rhodes'
        },
        {
            model = 'cs_valauctionboss_01',
            coords = vector3(2620.79, -1497.12, 45.97),
            heading = 278.82,
            name = 'Saint Denis Auctioneer',
            location = 'saintdenis',
            locationLabel = 'Saint Denis'
        },
        {
            model = 'cs_valauctionboss_01',
            coords = vector3(-838.22, -1383.41, 43.58),
            heading = 158.86,
            name = 'Blackwater Auctioneer',
            location = 'blackwater',
            locationLabel = 'Blackwater'
        },
        {
            model = 'cs_valauctionboss_01',
            coords = vector3(-3732.26, -2620.65, -13.27),
            heading = 95.71,
            name = 'Armadillo Auctioneer',
            location = 'armadillo',
            locationLabel = 'Armadillo'
        },
    },

    -- NPC Interaction Settings (ox_target)
    InteractionDistance = 2.5,      -- Max distance to target NPC
    
    -- Notification Settings
    NotificationDuration = 5000, -- How long notifications show (ms)
    
    
    -- Debug
    Debug = false,
    
    -- Discord Webhooks
    Webhooks = {
        -- Default webhook URL (used if event-specific URL not set)
        -- Set to your Discord webhook URL, e.g., 'https://discord.com/api/webhooks/...'
        defaultUrl = nil,
        
        -- Event-specific webhook URLs (optional, overrides defaultUrl)
        urls = {
            auctionCreated = nil,     -- New auctions
            bidPlaced = nil,          -- Bid notifications (can be spammy)
            auctionWon = nil,         -- Auction winners
            auctionExpired = nil,     -- Expired auctions (no bids)
            auctionCancelled = nil,   -- Cancelled auctions
            auctionBuyout = nil,      -- Buyouts
            highValueSale = nil,      -- High value alerts
        },
        
        -- Enable/disable specific webhook types
        enabled = {
            auctionCreated = true,
            bidPlaced = false,        -- Off by default (can be spammy)
            auctionWon = true,
            auctionBuyout = true,
            auctionExpired = true,
            auctionCancelled = true,
            highValueSale = true,
        },
        
        -- High value threshold (triggers additional highValueSale webhook)
        highValueThreshold = 1000,
        
        -- Bot appearance in Discord
        botName = 'Auction House',
        botAvatar = nil,  -- Set to an image URL for custom avatar
    }
}
