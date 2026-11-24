Config = {}
-- build the database tables automatically on start (set false and import the SQL file for a manual install)
Config.AutoDatabase = true

---------------------------------
-- general
---------------------------------
Config.StillItem      = 'moonshine_still'         -- usable item that places a still
Config.StillProp      = `mp001_p_mp_still02x`     -- still prop model
Config.MaxStills      = 2                         -- max stills per character
Config.MinStillDist   = 10.0                      -- min distance between any two stills
Config.InteractDist   = 3.0                       -- server side max distance for actions
Config.PlaceDist      = 5.0                       -- server side max distance between player and placed still
Config.SpawnDist      = 120.0                     -- stills only spawn as props within this distance of the player
Config.SyncDist       = 200.0                     -- the server only tells a player about stills within this distance (hides far still locations)
Config.OwnerOnly      = true                      -- true = only the owner (and people they trust) can use a placed still
Config.TrustedMax     = 5                         -- how many people an owner can trust per still
Config.TrustDist      = 6.0                       -- the person being trusted must be this close to the still
Config.MaxBatches     = 10                        -- hopper holds this many batches worth of each ingredient
Config.EmptyJug       = 'moonshine_jug_empty'     -- one empty jug is needed per bottle collected
Config.OutputCap      = 50                        -- max bottles the still can hold before it stops brewing
Config.TickInterval   = 15                        -- seconds between server brewing ticks
Config.ImagePath      = 'nui://rsg-inventory/html/images/'

-- while the still menu is open, block game controls but keep push-to-talk working
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

-- still quality: stored on the bottles (info.quality). Better moonshiners make better moonshine, which sells for more.
Config.Quality = {
    enabled = true,
    base = 40,              -- quality of a batch at level 0
    perLevel = 3,           -- quality added per moonshiner level
    variance = 8,           -- each batch is +/- this much
    defaultSold = 50,       -- quality assumed for bottles without any (old stock)
    minPriceMult = 0.6,     -- price multiplier at quality 0
    maxPriceMult = 1.4,     -- price multiplier at quality 100
}

-- still materials: copper is the standard still (existing stills stay copper), tin is cheaper but worse.
-- quality = shift to every batch, wear = how fast grime builds up (x), risk = explosion chance (x)
Config.Materials = {
    copper = { item = Config.StillItem,        quality = 0,  wear = 1.0, risk = 1.0 },
    tin    = { item = 'moonshine_still_tin',   quality = -8, wear = 1.6, risk = 1.5 },
}

-- ingredient quality: loaded ingredients with info.quality shift the batch. Items without quality count as `default`.
Config.Ingredients = { enabled = true, default = 50, weight = 0.3 }   -- batch quality +/- (ingredient quality - 50) * weight

-- law inspection: on duty law can inspect a still (read only) to see how dirty it is, its fire and what it holds
Config.Inspect = { enabled = true, time = 5000 }

-- wear: every run leaves grime in the pot. A dirty still makes worse spirit and blows up more often until it is scrubbed out.
Config.Wear = {
    enabled = true,
    perBatch = 8,            -- wear added by a finished batch (0-100 scale)
    rerun = 4,               -- wear added by a second run
    maxQualityLoss = 20,     -- quality lost at 100 wear
    maxRiskMult = 2.0,       -- explosion chance multiplier at 100 wear
    cleanItem = 'fullbucket', -- item used up to scrub the still clean
    cleanAmount = 1,
}

-- cooling water: the condenser needs cold water while distilling. Without it the vapour is lost and the spirit turns harsh.
Config.Cooling = {
    enabled = true,
    item = 'fullbucket',     -- item poured into the cooling tank
    seconds = 600,           -- seconds of cooling per item
    max = 2400,              -- tank capacity in seconds
    use = 0.5,               -- seconds of cooling used per second of distilling
    dryYieldLoss = 0.5,      -- share of the batch lost when it runs completely dry
    dryQuality = 15,         -- quality lost when it runs completely dry
    dryRisk = 2.0,           -- extra explosion chance (x) when it runs completely dry
}

-- taste test: sample the tank with a chosen cut to find out whether that cut would be poisonous. Costs a little spirit.
Config.Taste = { enabled = true, cost = 1, minVolume = 2 }

-- fermenting barrels: placeable barrels that ferment mash into wash (no fuel). Draw the wash off as an item and pour it into any still.
Config.Barrel = {
    enabled = true,
    item = 'moonshine_barrel',   -- usable item that places a barrel
    washItem = 'moonshine_wash', -- one item per fermented batch (info.recipe says which mash it is)
    prop = `p_barrel01ax`,       -- barrel prop (same model rsg-housing sells as a barrel)
    max = 3,                     -- barrels per character
    minDist = 2.0,               -- min distance between barrels and other stills/barrels
    maxWash = 4,                 -- batches a barrel holds
}

-- fermentation: mashed ingredients ferment on their own (no fuel) and become wash, which the still then distils
Config.Ferment = {
    time = 1800,             -- seconds a batch ferments (a recipe can set its own with ferment = seconds)
    maxWash = 2,             -- fermented batches that can wait for the still
}

-- weather and time of day (read from rsg-weather when it is running)
Config.Environment = {
    cold = { 'snow', 'snowlight', 'blizzard', 'whiteout', 'groundblizzard', 'sleet' },
    sunny = { 'sunny', 'highpressure' },
    wet  = { 'drizzle', 'rain', 'shower', 'thunder', 'thunderstorm', 'hurricane' },
    fermentCold = 0.5,       -- fermentation speed in cold weather
    fermentWet  = 0.9,
    fermentSunny = 1.15,
    burnWet = 1.25,          -- fuel burns faster in the rain and cold
    burnCold = 1.1,
    smokeWet = 0.6,          -- how far the smoke and smell carry (multiplier on Config.Smell.distance)
    smokeNight = 0.6,
    nightFrom = 21, nightTo = 5,
}

-- fire heat (the player picks one in the menu). speed = distilling speed, burn = fuel use, quality/proof = change to the batch,
-- risk = multiplier on the explosion chance, smoke = multiplier on how far the smoke and smell carry
Config.Heat = {
    { key = 'low',    speed = 0.6, burn = 0.55, quality = 6,   proof = 4,  risk = 0.4, smoke = 0.6 },
    { key = 'medium', speed = 1.0, burn = 1.0,  quality = 0,   proof = 0,  risk = 1.0, smoke = 1.0 },
    { key = 'high',   speed = 1.5, burn = 1.8,  quality = -10, proof = -4, risk = 3.0, smoke = 1.5 },
}

-- proof (twice the alcohol %). A first run comes off weak; a second run through the still raises it.
Config.Proof = { first = 90, variance = 6, max = 190, priceRef = 100, minPriceMult = 0.6, maxPriceMult = 1.6 }
Config.Rerun = { time = 600, yield = 0.8, proofMult = 1.45, quality = 8, minVolume = 2 } -- time at medium heat, in seconds

-- heads, hearts and tails: the player chooses how much to cut off when bottling.
-- yield = share of the tank that is bottled, quality = quality change, taint = % chance the batch is toxic at level 1
-- (falls to 0 at safeLevel). Tainted bottles look normal; the bootlegger tests every bottle and refuses them.
Config.Cuts = {
    safeLevel = 8,
    order = { 'tight', 'normal', 'loose' },
    options = {
        tight  = { yield = 0.75, quality = 8,  taint = 0 },
        normal = { yield = 0.90, quality = 0,  taint = 4 },
        loose  = { yield = 1.00, quality = -8, taint = 30 },
    },
}

-- charred oak cask: install one on a still (item is used up, returned when the still is packed up), then age the tank in it.
Config.Cask = {
    enabled = true,
    item = 'moonshine_cask',
    capacity = 20,           -- bottles of liquid the cask holds
    stepTime = 1800,         -- seconds per ageing step
    qualityPerStep = 1,
    maxBonus = 20,
    evaporation = 0.01,      -- share lost per step (the angel's share)
    maxLoss = 0.25,
}

-- custom bottle label: whoever can use a still can name its moonshine; the name is stored on the bottles (info.label)
Config.Label = {
    enabled = true,
    maxLength = 24,
    blocked = {},            -- lower case words that are not allowed in a label, e.g. { 'badword' }
}

-- a finished batch can blow the still up. chance (%) is highest for new moonshiners and falls to 0 at safeLevel.
-- world (map) stills never explode. Set enabled = false to switch it off.
Config.Risk = {
    enabled = true,
    baseChance = 3.0,
    safeLevel = 6,
}

-- law on duty near a brewing still smell the mash and get a hint
Config.Smell = {
    enabled = true,
    distance = 80.0,
    cooldown = 120,         -- seconds before the same lawman is told about the same still again
}

-- bootlegger buyers: sell bottles for cash. By default one waits in every speakeasy cellar (at the inside teleport spot).
Config.Buyers = {
    enabled = true,
    atSpeakeasies = true,
    extra = {                -- more buyers: { name = 'Bootlegger', coords = vector3(x, y, z) }
    },
    distance = 2.5,          -- rsg-target radius
    sellDist = 4.0,          -- server side max distance
    maxPerSale = 50,         -- bottles taken per visit
    lawAlertChance = 10,     -- % chance a sale tips off on-duty law
}

-- integration with your other framework scripts (each is used only when it is running)
Config.UseSkills = true         -- moonshining level/xp live in rsg-skills (imports old rep xp). false = built in rep xp + Config.Levels
Config.SkillName = 'moonshining'
Config.Reputation = {            -- rsg-reputation honor changes
    enabled = true,
    sell = -1,                   -- per sale to a bootlegger
    raid = 2,                    -- lawman who destroys someone else's still
}

-- static stills already placed around the map: target them to open the moonshine UI
-- each one gets its own saved state the first time it is used (shared by everyone, can't be picked up)
Config.WorldStills = {
    enabled = true,
    models  = { -2094919100, 866531020, 524438086, -736911484 },
    distance = 2.5, -- rsg-target distance
    maxTotal = 150, -- max saved world stills (stops anyone filling the database)
    locations = {}, -- optional allow-list of map still coords (vector3); empty = any spot near a world still model
}

-- fuel for the firebox: burnTime = seconds of brewing one item provides
-- fuel only burns while a batch is cooking; when it runs out the batch pauses
Config.Fuels = {
    { item = 'resource_wood', burnTime = 300 },
    { item = 'resource_coal', burnTime = 900 },
}
Config.MaxFuel        = 7200                      -- max seconds of fuel the firebox can hold

-- particle effects shown on the still while a batch is brewing (offsets are relative to the prop)
Config.BrewFx = {
    enabled = true,
    dict = 'core',
    effects = {
        { name = 'ent_amb_smoke_moon_still', offset = vector3(-0.4, 0.0, 1.6), scale = 1.0 },
        { name = 'ent_amb_fire_moon_still',  offset = vector3(-0.4, 0.0, 0.1), scale = 2.0 }, -- x = sideways, y = forward/back
    },
}

-- no stills inside these zones (towns etc.)
Config.BlockedZones = {
    { name = 'Valentine',   coords = vector3(-281.0, 742.0, 117.0),   radius = 150.0 },
    { name = 'Saint Denis', coords = vector3(2630.0, -1225.0, 53.0),  radius = 400.0 },
    { name = 'Rhodes',      coords = vector3(1290.0, -1300.0, 77.0),  radius = 150.0 },
    { name = 'Blackwater',  coords = vector3(-800.0, -1300.0, 43.0),  radius = 200.0 },
    { name = 'Strawberry',  coords = vector3(-1790.0, -410.0, 155.0), radius = 120.0 },
    { name = 'Annesburg',   coords = vector3(2930.0, 1350.0, 44.0),   radius = 150.0 },
    { name = 'Tumbleweed',  coords = vector3(-5510.0, -2940.0, -2.0), radius = 120.0 },
    { name = 'Armadillo',   coords = vector3(-3660.0, -2600.0, -14.0),radius = 120.0 },
}

---------------------------------
-- moonshiner xp (stored as RSG rep 'moonshiner' in player metadata)
---------------------------------
Config.XpName      = 'moonshiner'
Config.XpPerBottle = 2             -- xp earned for each bottle collected (recipes can override with xpPerBottle)
-- total xp needed to reach each level (index = level)
Config.Levels = { 0, 100, 250, 500, 1000, 2000 }

---------------------------------
-- recipes (time in seconds, real time - survives restarts)
---------------------------------
Config.Recipes = {
    {
        key = 'moonshine',
        price = 6,   -- bootlegger pays this per bottle at quality 50
        label = 'Corn Moonshine',
        level = 1,
        xpPerBottle = 2,
        time = 600,
        ingredients = { 
            { item = 'corn', amount = 5 }, 
            { item = 'sugarcane', amount = 2 }, 
            { item = 'yeast', amount = 1 }, 
            { item = 'water', amount = 2 } },
        output = { item = 'moonshine', amount = 5 },
    },
    {
        key = 'moonshine_apple',
        price = 8,   -- bootlegger pays this per bottle at quality 50
        label = 'Apple Moonshine',
        level = 2,
        xpPerBottle = 3,
        time = 900,
        ingredients = { 
            { item = 'apple', amount = 5 }, 
            { item = 'sugarcane', amount = 2 },
            { item = 'yeast', amount = 1 }, 
            { item = 'water', amount = 2 } },
        output = { item = 'moonshine_apple', amount = 5 },
    },
    {
        key = 'moonshine_blackberry',
        price = 8,   -- bootlegger pays this per bottle at quality 50
        label = 'Blackberry Moonshine',
        level = 2,
        xpPerBottle = 3,
        time = 900,
        ingredients = { 
            { item = 'blackberry', amount = 5 }, 
            { item = 'sugarcane', amount = 2 },
            { item = 'yeast', amount = 1 }, 
            { item = 'water', amount = 2 } },
        output = { item = 'moonshine_blackberry', amount = 5 },
    },
    {
        key = 'moonshine_raspberry',
        price = 8,   -- bootlegger pays this per bottle at quality 50
        label = 'Raspberry Moonshine',
        level = 2,
        xpPerBottle = 3,
        time = 900,
        ingredients = { 
            { item = 'raspberry', amount = 5 }, 
            { item = 'sugarcane', amount = 2 },
            { item = 'yeast', amount = 1 }, 
            { item = 'water', amount = 2 } },
        output = { item = 'moonshine_raspberry', amount = 5 },
    },
    {
        key = 'moonshine_peach',
        price = 10,   -- bootlegger pays this per bottle at quality 50
        label = 'Peach Moonshine',
        level = 3,
        xpPerBottle = 4,
        time = 900,
        ingredients = { 
            { item = 'peach', amount = 5 }, -- will need to add peaches to farming
            { item = 'sugarcane', amount = 2 },
            { item = 'yeast', amount = 1 }, 
            { item = 'water', amount = 2 } },
        output = { item = 'moonshine_peach', amount = 5 },
    },
    {
        key = 'moonshine_plumb',
        price = 10,   -- bootlegger pays this per bottle at quality 50
        label = 'Plum Moonshine',
        level = 3,
        xpPerBottle = 4,
        time = 900,
        ingredients = { 
            { item = 'herb_creek_plum', amount = 5 }, 
            { item = 'sugarcane', amount = 2 },
            { item = 'yeast', amount = 1 }, 
            { item = 'water', amount = 2 } },
        output = { item = 'moonshine_plumb', amount = 5 },
    },
    {
        key = 'moonshine_wildcider',
        price = 12,   -- bootlegger pays this per bottle at quality 50
        label = 'Wild Cider Moonshine',
        level = 4,
        xpPerBottle = 5,
        time = 900,
        ingredients = { 
            { item = 'herb_wild_mint', amount = 2 },
            { item = 'apple', amount = 5 },
            { item = 'sugarcane', amount = 2 },
            { item = 'yeast', amount = 1 }, 
            { item = 'water', amount = 2 } },
        output = { item = 'moonshine_wildcider', amount = 5 },
    },
    {
        key = 'moonshine_currant',
        price = 12,   -- bootlegger pays this per bottle at quality 50
        label = 'Sweet Currant Moonshine',
        level = 4,
        xpPerBottle = 5,
        time = 900,
        ingredients = { 
            { item = 'herb_black_current', amount = 3 },
            { item = 'herb_golden_currant', amount = 4 },
            { item = 'sugarcane', amount = 2 },
            { item = 'yeast', amount = 1 }, 
            { item = 'water', amount = 2 } },
        output = { item = 'moonshine_currant', amount = 5 },
    },
    {
        key = 'moonshine_applepie',
        price = 14,   -- bootlegger pays this per bottle at quality 50
        label = 'Apple Crumb Moonshine',
        level = 5,
        xpPerBottle = 6,
        time = 900,
        ingredients = { 
            { item = 'herb_vanilla_orchid', amount = 2 },
            { item = 'apple', amount = 5 },
            { item = 'sugarcane', amount = 2 },
            { item = 'yeast', amount = 1 }, 
            { item = 'water', amount = 2 } },
        output = { item = 'moonshine_applepie', amount = 5 },
    },
    {
        key = 'moonshine_orange',
        price = 14,   -- bootlegger pays this per bottle at quality 50
        label = 'Vanilla Orange Moonshine',
        level = 5,
        xpPerBottle = 6,
        time = 900,
        ingredients = { 
            { item = 'herb_vanilla_orchid', amount = 2 },
            { item = 'orange', amount = 5 },
            { item = 'sugarcane', amount = 2 },
            { item = 'yeast', amount = 1 }, 
            { item = 'water', amount = 2 } },
        output = { item = 'moonshine_orange', amount = 5 },
    },
    {
        key = 'moonshine_alaskan',
        price = 16,   -- bootlegger pays this per bottle at quality 50
        label = 'Alaskan Moonshine',
        level = 6,
        xpPerBottle = 7,
        time = 900,
        ingredients = { 
            { item = 'herb_wintergreen_berry', amount = 2 },
            { item = 'lemon', amount = 5 },  -- will need to add lemons to farming
            { item = 'sugarcane', amount = 2 },
            { item = 'yeast', amount = 1 }, 
            { item = 'water', amount = 2 } },
        output = { item = 'moonshine_alaskan', amount = 5 },
    },
    {
        key = 'moonshine_american',
        price = 16,   -- bootlegger pays this per bottle at quality 50
        label = 'American Moonshine',
        level = 6,
        xpPerBottle = 7,
        time = 900,
        ingredients = { 
            { item = 'herb_wintergreen_berry', amount = 2 },
            { item = 'corn', amount = 5 },
            { item = 'sugarcane', amount = 2 },
            { item = 'yeast', amount = 1 }, 
            { item = 'water', amount = 2 } },
        output = { item = 'moonshine_american', amount = 5 },
    },
}

---------------------------------
-- law enforcement raids
---------------------------------
Config.LawJobs          = { 'vallaw', 'rholaw', 'blklaw', 'strlaw', 'stdenlaw' }
Config.LawRequireDuty   = true
Config.DestroyTime      = 10000          -- ms
Config.DestroyReward    = 15             -- cash paid to lawman per still destroyed

---------------------------------
-- speakeasy teleports (outside hatch <-> inside cellar)
---------------------------------
Config.Speakeasy = {
    enabled   = true,
    promptKey = 0xF3830D8E,   -- J
    holdTime  = 1000,         -- ms to hold the prompt
    dist      = 1.5,          -- distance to show the prompt
    fadeTime  = 500,          -- ms screen fade
    locations = {
        { name = 'Lemoyne Speakeasy',        outside = vector4(1784.90, -821.65, 42.86, 0.0),    inside = vector4(1784.95, -821.62, 192.60, 330.49) },
        { name = 'Cattail Pond Speakeasy',   outside = vector4(-1085.63, 714.14, 103.32, 0.0),   inside = vector4(-1085.63, 714.14, 83.23, 0.0) },
        { name = 'New Austin Speakeasy',     outside = vector4(-2769.23, -3048.90, 11.38, 0.0),  inside = vector4(-2769.3, -3048.87, -9.7, 0.0) },
        { name = 'Hanover Speakeasy',        outside = vector4(1627.64, 822.90, 144.03, 0.0),    inside = vector4(1627.64, 822.9, 123.94, 0.0) },
        { name = 'Manzanita Post Speakeasy', outside = vector4(-1861.70, -1722.17, 108.35, 0.0), inside = vector4(-1861.7, -1722.17, 88.35, 0.0) },
    },
}

---------------------------------
-- bootlegger buy spots (built from the options above, used by client and server)
---------------------------------
Config.BuyerSpots = {}
if Config.Buyers.enabled then
    if Config.Buyers.atSpeakeasies and Config.Speakeasy then
        for _, loc in ipairs(Config.Speakeasy.locations) do
            Config.BuyerSpots[#Config.BuyerSpots + 1] = { name = loc.name, coords = loc.inside.xyz }
        end
    end
    for _, b in ipairs(Config.Buyers.extra or {}) do
        Config.BuyerSpots[#Config.BuyerSpots + 1] = { name = b.name, coords = b.coords }
    end
end
