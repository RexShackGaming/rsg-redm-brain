Config = {}

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
Config.OwnerOnly      = false                     -- true = only owner can brew/collect
Config.MaxBatches     = 10                        -- hopper holds this many batches worth of each ingredient
Config.EmptyJug       = 'moonshine_jug_empty'     -- one empty jug is needed per bottle collected
Config.OutputCap      = 50                        -- max bottles the still can hold before it stops brewing
Config.TickInterval   = 15                        -- seconds between server brewing ticks
Config.ImagePath      = 'nui://rsg-inventory/html/images/'

-- static stills already placed around the map: target them to open the moonshine UI
-- each one gets its own saved state the first time it is used (shared by everyone, can't be picked up)
Config.WorldStills = {
    enabled = true,
    models  = { -2094919100, 866531020, 524438086, -736911484 },
    distance = 2.5, -- ox_target distance
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
