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
Config.Fees = { MaxPerBatch = 500 }   -- highest fee per batch an owner can charge other players
Config.SellbackPercent = 60           -- % of the factory price the owner gets when selling it back
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
    showOwnedByOthers = false,
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
