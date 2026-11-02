Config = {}

-- ===================== GENERAL =====================
Config.AutoDatabase   = true    -- build the player_wagons table on start; set false to import install.sql manually
Config.MoneyType      = 'cash'  -- 'cash' | 'bank' | 'gold' | 'bloodmoney' (always taken via RemoveMoney)
Config.MaxWagons      = 5       -- max wagons a player can own in total
Config.SellPercent    = 0.50    -- trade-in value = price * SellPercent * condition modifier
Config.DamagedThreshold = 90    -- condition % below this counts as "damaged" (RDR2 fence: health < 90% of max)
Config.DamagedSellModifier = 0.5 -- damaged wagons fetch this fraction of the normal trade-in
Config.StoreDistance  = 15.0    -- wagon must be within this distance of a store to be stored / sold
Config.StoreRadius    = 35.0    -- wagon AND player must be within this distance of a yard (keeper or preview spot) to store
Config.StorePrompt    = true    -- show a hold-to-store prompt when near a yard with your wagon out
Config.StoreKey       = 0x760A9C6F -- prompt key (G); any RedM control hash works
Config.StoreHoldTime  = 1000    -- ms to hold the key
-- field repair: patch a damaged or wrecked wagon on the road (temporary) - full repair only at a yard
Config.FieldRepair = {
    enabled   = true,
    condition = 35,               -- a patch brings the wagon up to this % (never higher)
    cost      = { type = 'item', item = 'resource_wood', amount = 3 }, -- or { type = 'money', amount = 10 }
    duration  = 8000,             -- ms the player works on the wagon
    command   = 'repairwagon',    -- chat command (needed for a wrecked wagon); false = off
}
-- yard repair: back to 100% at any wagon yard (My Wagons -> Repair), priced by damage
Config.YardRepair = {
    enabled         = true,
    pricePerPercent = 0.5,        -- $ per missing condition % (a wreck at 0% costs $50)
}

-- call / send away (like horses)
Config.CallKey        = 0xF3830D8E -- J (INPUT_OPEN_JOURNAL, works on foot and on horseback); set false to disable the key
Config.CallCommand    = 'callwagon' -- chat command to call your wagon (false = off)
Config.FleeCommand    = 'fleewagon' -- chat command to send your wagon away (false = off)
Config.CallNearDistance = 25.0  -- if the wagon is closer than this, calling just tells you it's nearby
Config.CallRoadDistance = 60.0  -- look for a road this close to you to bring the wagon to; otherwise it appears beside you
Config.UseDistance    = 4.0     -- distance to the wagon to open its storage
Config.InteractDistance = 3.0   -- server-side check: player distance to the shop NPC (plus target distance)
Config.ActionCooldown = 1500    -- ms between purchase/take-out/store/sell actions per player
Config.NameMaxLength  = 24

-- ===================== PREVIEW CAMERA =====================
-- Orbit camera around the preview wagon, same controls as rsg-stables
Config.Preview = {
    radius       = 8.0,   -- starting distance from the wagon
    radiusMin    = 4.5,
    radiusMax    = 14.0,
    height       = 2.4,   -- camera height above the wagon origin
    lookAtHeight = 1.0,
    rotateSpeed  = 60.0,  -- degrees per second while rotating
    autoRotate   = 0.0,   -- idle spin in degrees per second (0 = off, camera only moves when you rotate it)
    draftAnimals = true,  -- show the draft horses in the preview
}

-- ===================== BLIPS =====================
-- blip sprite verified in rdr3_discoveries textures/blips
Config.Blip = {
    enabled = true,
    sprite  = 'blip_shop_coach_fencing',
    scale   = 0.2,
}

-- map blip on the wagon you have out (follows it, hidden while you ride it)
Config.WagonBlip = {
    enabled = true,
    style   = 'BLIP_STYLE_PLAYER_COACH', -- RDR2 style for the player's own coach: always on map + radar
    sprite  = 'blip_player_coach',       -- set nil to use the style's default (blip_ambient_wagon)
}

-- ===================== STORES =====================
-- npc         : shop keeper position (s_m_m_cghworker_01 verified in rdr3_discoveries peds_list)
-- preview     : where the preview wagon is spawned AND where bought/taken-out wagons appear
Config.Stores = {
    valentine = {
        label   = 'Valentine Wagon Yard',
        npcModel = 's_m_m_cghworker_01',
        npc     = vector4(-355.11, 775.18, 116.22, 321.41),
        preview = vector4(-353.43, 788.54, 116.15, 274.7),
        showBlip = true,
    },
    saintdenis = {
        label   = 'Saint Denis Wagon Yard',
        npcModel = 's_m_m_cghworker_01',
        npc     = vector4(2506.02, -1459.52, 46.37, 66.78),
        preview = vector4(2502.689, -1441.257, 45.313, 177.895),
        showBlip = true,
    },
    strawberry = {
        label   = 'Strawberry Wagon Yard',
        npcModel = 's_m_m_cghworker_01',
        npc     = vector4(-1811.18, -555.63, 155.98, 265.87),
        preview = vector4(-1821.550, -561.547, 155.060, 253.239),
        showBlip = true,
    },
    blackwater = {
        label   = 'Blackwater Wagon Yard',
        npcModel = 's_m_m_cghworker_01',
        npc     = vector4(-870.62, -1370.70, 43.62, 40.36),
        preview = vector4(-865.77, -1366.23, 43.49, 88.50),
        showBlip = true,
    },
    tumbleweed = {
        label   = 'Tumbleweed Wagon Yard',
        npcModel = 's_m_m_cghworker_01',
        npc     = vector4(-5515.295, -3039.497, -2.388, 182.161),
        preview = vector4(-5522.063, -3044.438, -3.388, 265.561),
        showBlip = true,
    },
}

-- ===================== CATEGORIES =====================
-- order + icon (Font Awesome) used by the NUI category tabs
Config.Categories = {
    { id = 'carts',   icon = 'fa-solid fa-cart-flatbed' },
    { id = 'buggies', icon = 'fa-solid fa-horse' },
    { id = 'wagons',  icon = 'fa-solid fa-truck-pickup' },
    { id = 'coaches', icon = 'fa-solid fa-van-shuttle' },
    { id = 'heavy',   icon = 'fa-solid fa-truck-moving' },
}

-- ===================== WAGONS FOR SALE =====================
-- model names verified against RDR2 generic_wagon_fence_core (the SP wagon fence list).
-- tier mirrors the fence's wagon class: 1 light, 2 medium, 3 large, 4 tanker.
-- weight is storage in kg, slots is storage slots, seats is shown in the UI only.
-- stores (optional) = { 'valentine', ... } limits a wagon to those yards.
Config.Wagons = {
    -- Carts
    cart01 = { label = 'Light Peasant Cart',    category = 'carts', price = 25,  weight = 400, slots = 35, seats = 2, tier = 1, description = 'A simple two-wheeled cart for short hauls around town.' },
    cart02 = { label = 'Peasant Cart with Sides', category = 'carts', price = 30, weight = 450, slots = 40, seats = 2, tier = 1, description = 'Raised sides keep your load from spilling on rough roads.' },
    cart03 = { label = 'Small Market Cart',     category = 'carts', price = 22,  weight = 360, slots = 30, seats = 2, tier = 1, description = 'Light and nimble, ideal for market traders.' },
    cart04 = { label = 'Compact Farm Cart',     category = 'carts', price = 28,  weight = 430, slots = 38, seats = 2, tier = 1, description = 'A sturdy little cart built for farm work.' },
    cart06 = { label = 'General Cargo Cart',    category = 'carts', price = 60,  weight = 790, slots = 70, seats = 2, tier = 1, description = 'The biggest of the carts, built to carry crates and sacks.' },
    cart07 = { label = "Farmer's Cart",         category = 'carts', price = 32,  weight = 475, slots = 42, seats = 2, tier = 1, description = 'A dependable cart favoured by homesteaders.' },
    cart08 = { label = 'Rural Utility Cart',    category = 'carts', price = 38,  weight = 520, slots = 46, seats = 2, tier = 1, description = 'A versatile cart for the countryside.' },
    huntercart01 = { label = 'Hunting Cart', category = 'carts', price = 150, weight = 300, slots = 25, seats = 2, tier = 1, description = 'A hunter\'s cart with a pelt tarp. Stow up to 20 carcasses and sell the whole load at a butcher.' },

    -- Buggies
    buggy01 = { label = 'Two-Seat Buggy',       category = 'buggies', price = 90,  weight = 120, slots = 10, seats = 2, tier = 1, description = 'A fast, light buggy for getting about in style.' },
    buggy02 = { label = 'Hooded Buggy',         category = 'buggies', price = 110, weight = 120, slots = 10, seats = 2, tier = 1, description = 'A buggy with a folding hood to keep off the rain.' },
    buggy03 = { label = 'Sport Buggy',          category = 'buggies', price = 130, weight = 100, slots = 8,  seats = 2, tier = 1, description = 'Built for speed, not for cargo.' },

    -- Wagons
    wagon02x = { label = 'Standard Camping Wagon',  category = 'wagons', price = 40, weight = 560, slots = 50, seats = 2, tier = 3, description = 'A covered wagon for life on the trail.' },
    wagon03x = { label = 'Reinforced Camping Wagon', category = 'wagons', price = 50, weight = 600, slots = 60, seats = 2, tier = 3, description = 'A camp wagon with a reinforced frame.' },
    wagon04x = { label = 'Light Farm Wagon',        category = 'wagons', price = 35, weight = 500, slots = 45, seats = 2, tier = 3, description = 'An open wagon for hauling feed and tools.' },
    wagon05x = { label = 'Open Utility Wagon',      category = 'wagons', price = 45, weight = 635, slots = 55, seats = 2, tier = 3, description = 'A no-frills open wagon that carries a good load.' },
    wagon06x = { label = 'Covered Supply Wagon',    category = 'wagons', price = 55, weight = 725, slots = 65, seats = 2, tier = 3, description = 'Canvas covered and roomy, ready for long journeys.' },
    utilliwag = { label = 'Buckboard',              category = 'wagons', price = 30, weight = 450, slots = 40, seats = 2, tier = 3, description = 'A low, light buckboard wagon.' },
    chuckwagon000x = { label = 'Chuckwagon',        category = 'wagons', price = 80, weight = 860, slots = 75, seats = 2, tier = 2, description = 'A kitchen on wheels for camps and cattle drives.' },
    chuckwagon002x = { label = 'Tool Cargo Wagon',  category = 'wagons', price = 65, weight = 815, slots = 70, seats = 2, tier = 2, description = 'Packed with racks for tools and supplies.' },
    wagondairy01x = { label = 'Dairy Wagon',        category = 'wagons', price = 70, weight = 700, slots = 40, seats = 2, tier = 2, description = 'A delivery wagon built for milk churns.' },

    -- Coaches
    coach2 = { label = 'Town Coach',               category = 'coaches', price = 200, weight = 300, slots = 25, seats = 6, tier = 2, description = 'An elegant coach for city folk.' },
    coach3 = { label = 'Covered Coach',            category = 'coaches', price = 220, weight = 300, slots = 25, seats = 6, tier = 2, description = 'A fully enclosed coach for comfortable travel.' },
    coach4 = { label = 'Open Coach',               category = 'coaches', price = 180, weight = 300, slots = 25, seats = 6, tier = 2, description = 'Open air travel for the whole family.' },
    coach5 = { label = 'Gentleman\'s Coach',       category = 'coaches', price = 260, weight = 300, slots = 25, seats = 6, tier = 2, description = 'A finely trimmed coach for those with means.' },
    coach6 = { label = 'Luxury Coach',             category = 'coaches', price = 300, weight = 300, slots = 25, seats = 6, tier = 2, description = 'The finest coach money can buy.' },
    stagecoach001x = { label = 'Stagecoach',       category = 'coaches', price = 240, weight = 450, slots = 40, seats = 8, tier = 3, description = 'A classic overland stagecoach with roof rack.' },
    stagecoach002x = { label = 'Painted Stagecoach', category = 'coaches', price = 250, weight = 450, slots = 40, seats = 8, tier = 3, description = 'A brightly painted stagecoach.' },
    stagecoach003x = { label = 'Mail Stagecoach',  category = 'coaches', price = 260, weight = 500, slots = 45, seats = 8, tier = 3, description = 'Built to carry passengers and the mail.' },
    stagecoach005x = { label = 'Armoured Stagecoach', category = 'coaches', price = 320, weight = 500, slots = 45, seats = 8, tier = 3, description = 'Strongbox and plating for valuable cargo.' },
    stagecoach006x = { label = 'Frontier Stagecoach', category = 'coaches', price = 280, weight = 500, slots = 45, seats = 8, tier = 3, description = 'Tough enough for the roughest trails.' },

    -- Heavy
    supplywagon = { label = 'Large Supply Wagon',  category = 'heavy', price = 130, weight = 1700, slots = 100, seats = 2, tier = 3, description = 'A true freight wagon for serious hauling.' },
    logwagon    = { label = 'Log Hauling Wagon',   category = 'heavy', price = 65,  weight = 1700, slots = 5,   seats = 2, tier = 2, description = 'Long bed for timber; few slots but heavy capacity.' },
    oilwagon01x = { label = 'Oil Tanker Wagon',    category = 'heavy', price = 85,  weight = 860,  slots = 8,   seats = 2, tier = 4, description = 'A tanker for oil and other liquids.' },
    cart05      = { label = 'Water Tank Wagon',    category = 'heavy', price = 70,  weight = 900,  slots = 10,  seats = 2, tier = 1, description = 'Carries water out to farms and camps.' },
}
