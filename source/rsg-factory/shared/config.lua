Config = {}

-- Build the database tables automatically on start.
-- Set to false and import install.sql manually instead.
Config.AutoDatabase = true

-- Admin command + permission level needed to create / edit / delete factories
Config.CommandName = 'createfactory'
Config.AdminPermission = 'admin'

-- Factory NPC
Config.DefaultPedModel = 'a_m_m_rancher_01' -- used when an admin leaves the model empty or invalid
Config.InteractDistance = 2.5               -- target distance (server allows a little extra)
Config.SpawnDistance = 60.0                 -- NPCs spawn/despawn around this distance

-- Ownership: players buy a factory at its NPC and become its owner.
-- Only the owner can stock fuel and water; anyone can then run production lines.
Config.DefaultPrice = 5000          -- price of newly created factories (admins can change it per factory)
Config.MaxPrice = 1000000
Config.MaxFactoriesPerPlayer = 3    -- factories one player can own

-- Fuel & water: every production line burns some per batch (set per line in the editor).
-- Production cannot start unless the factory has enough of both in stock.
Config.DefaultFuelPerBatch = 1      -- default for new lines
Config.DefaultWaterPerBatch = 1
Config.MaxUtilityPerBatch = 100
Config.MaxFuel = 500                -- storage capacity (units)
Config.MaxWater = 500
Config.ImagePath = 'nui://rsg-inventory/html/images/'   -- where item pictures are loaded from
Config.MaxSupplyAtOnce = 100        -- items an owner can add in one go

-- Items the owner can add. `stock` is 'fuel' or 'water'; `units` is how many units one item adds.
-- Optional `returnItem` gives an item back per item used (here the empty `bucket` for each `fullbucket`).
-- Remove the returnItem field to give nothing back. It is skipped if the item does not exist.
Config.Supplies = {
    { key = 'wood',  item = 'resource_wood', stock = 'fuel',  units = 1 },
    { key = 'coal',  item = 'resource_coal', stock = 'fuel',  units = 3 },
    { key = 'water', item = 'fullbucket',    stock = 'water', units = 10, returnItem = 'bucket' },
}

-- Owner features
-- Fees: the owner charges other players a fee per batch (up to MaxPerBatch).
-- TrustedDiscount = % off for the owner's trusted workers (100 = they run it free).
-- JobDiscounts = % off per job name, the best discount applies, e.g. { sheriff = 50, blacksmith = 25 }
Config.Fees = { MaxPerBatch = 500, TrustedDiscount = 100, JobDiscounts = {} }
Config.SellbackPercent = 60           -- % of the price the owner PAID that comes back when selling the factory
Config.SellbackUpgradePercent = 50    -- % of the money spent on upgrades that comes back as well (the next owner starts at level 0)

-- Worker wages: the owner can set a wage per batch for trusted workers, paid from the factory's society account
-- (needs rsg-society and Config.Society.EarningsToSociety). Nothing is paid when the account cannot cover it.
Config.Wages = { Enabled = true, MaxPerBatch = 50 }

-- Supply stash: the owner gets a storage (rsg-inventory stash) at the factory. Wood, coal and water buckets put in it
-- (anything listed in Config.Supplies) refill the fuel and water tanks by themselves when a run needs them.
Config.Stash = { Enabled = true, Slots = 20, MaxWeight = 100000 }

-- Activity log shown on the owner's tab: last entries and the top users of the last ReportDays days.
Config.Log = { KeepDays = 30, ReportDays = 7, Entries = 10 }
Config.TransferExpiry = 60            -- seconds the receiver has to type /acceptfactory
Config.TrustedMax = 8                 -- trusted workers per factory

-- Upgrades the owner buys with cash. Cost of the next level = cost * (current level + 1).
Config.Upgrades = {
    tank  = { maxLevel = 5, cost = 1000, bonus = 250 },    -- + storage per level (fuel and water each)
    speed = { maxLevel = 5, cost = 1500, percent = 5 },    -- production time shorter by this % per level
}

-- Breakdowns: each production start has a small chance to break the factory.
-- A broken factory cannot start new runs until the owner repairs it (finished and running products are safe).
-- Repair costs `repairCost` cash, or 1x `repairItem` if you set one (use an item that exists in your items.lua).
Config.Breakdown = { enabled = true, chance = 2.0, repairCost = 150, repairItem = nil }

-- Alerts and delivery
Config.AutoDeliver = true             -- finished products go straight to the player's inventory when they are online with room
Config.Alerts = {
    interval = 30,                    -- seconds between checks for finished productions
    ready = true,                     -- tell players when a production is ready (telegram if they are offline)
    telegram = true,                  -- use rsg-telegram for offline players and owners (skipped if it is not running)
    lowStockPercent = 20,             -- warn the owner when fuel or water drops below this % of capacity (0 = off)
    lowStockCooldown = 600,           -- seconds between low stock warnings
}

-- Map blips (sprite blip_shop_blacksmith; colours are the rsg-banking modifiers)
Config.Blips = {
    enabled = true,
    sprite = -758970771,
    scale = 0.2,
    mineColor = 'BLIP_MODIFIER_MP_COLOR_8',  -- factories you own
    saleColor = nil,                          -- factories for sale (default colour)
    readyColor = 'BLIP_MODIFIER_MP_COLOR_2',  -- a factory where you have finished products to collect (shown even if it is not yours)
    showOwnedByOthers = false,
}

-- rsg-society integration: every factory gets its own job (JobPrefix + factory id) and a job society in rsg-society
-- the moment it is created (treasury, member list, ranks, storage, audit trail). The owner holds the boss grade,
-- trusted workers the first grade. With EarningsToSociety the fees other players pay go into the society account
-- (money already in the factory's earnings moves over on the next start); the owner's Earnings tab, selling and
-- transferring all use that account. Deleting a factory removes the society and pays its balance to the owner (if online).
-- Factories created before this was added get their society on the next start. Needs rsg-society started.
Config.Society = {
    Enabled = true,
    JobPrefix = 'factory_',
    JobType = 'factory',        -- rsg-core job type
    EarningsToSociety = true,   -- false = earnings stay in the factory (database column)
    -- Grades created for each factory job, lowest first. payment = wage in dollars paid from the society account (0 = unpaid).
    Grades = {
        { name = 'Worker', payment = 0 },
        { name = 'Owner', payment = 0, isboss = true },
    },
}

-- Limits (enforced on the server)
Config.MaxRecipes = 20            -- production lines per factory
Config.MaxItemsPerRecipe = 6      -- distinct input items and distinct output items per line
Config.MaxAmount = 1000           -- max amount of one item in a line
Config.MinTime = 1                -- seconds per batch
Config.MaxTime = 3600
Config.MaxChainLength = 5        -- production lines that can be linked in one chain
Config.MaxBatches = 50            -- batches a player can start at once
Config.MaxQueuePerPlayer = 5      -- running productions per player per factory

-- While NUI is open, block game controls but allow push-to-talk.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}
