Config = {}

-- ===================== GENERAL =====================
Config.MaxOwnedHorses      = 8      -- max horses a single player can own across all stables
Config.MaxHorsesPerStable  = 20     -- max horses a single player can keep at one stable location
Config.RenameCost          = 15     -- $ cost to rename an owned horse
Config.InsuranceCost       = 25     -- $ cost to insure a horse
Config.ReviveCost          = 40     -- $ cost to revive/replace a dead insured horse
Config.StoreDistance       = 8.0    -- max distance player's mount can be from stable to store it
Config.PaymentAccount      = 'cash' -- 'cash' or 'bank'
Config.WhistleStopDistance = 1.0 -- whistled horse stops this many meters in front of the player (measured to the horse's nose)
Config.WhistleAnim = 'WHISTLEHORSESHORT' -- whistle sound + animation played on H ('WHISTLEHORSESHORT', 'WHISTLEHORSELONG', 'WHISTLEHORSEDOUBLE'), false to disable
Config.WhistleTeleportDistance = 60.0 -- if the active horse is farther than this when whistled, it's moved near the player instead of walking/running over
Config.AllowTwoPlayersRide = false

-- ===================== ACTIVE HORSE PERSISTENCE =====================
-- While a horse is out, its position is saved to the database. If the player logs out
-- (or the resource restarts) the horse stays "out" — whistling after logging back in
-- brings it back toward the player instead of it being returned to the stable.
Config.ActiveHorse = {
    saveInterval      = 10000, -- ms between position saves while the horse is out
    minMoveToSave     = 2.0,   -- only save if the horse moved at least this far since the last save
    recallMaxDistance = 150.0, -- whistle after relog: if the saved position is within this range the horse spawns there and travels to you,
                               -- otherwise it spawns respawnDistance behind you and runs over
    respawnDistance   = 30.0,  -- how far behind the player the horse spawns when it can't use its saved position
    minSpawnDistance  = 25.0,  -- never spawn the horse closer than this to the player (e.g. you logged out next to it)
    notifyOnLogin     = true,  -- remind the player on login that their horse is still out
}

-- ===================== FEEDING / NEEDS =====================
Config.HorseFeedItems = {
    { item = 'horse_apple',  label = 'Horse Apple',  health = 10, stamina = 10, hunger = 15 },
    { item = 'horse_carrot', label = 'Horse Carrot', health = 10, stamina = 10, hunger = 15 },
}

Config.HorseDrinkItems = {
    { item = 'fullbucket', label = 'Water Bucket', thirst = 50, stamina = 10 },
}

-- ===================== HORSE STIMULANT =====================
Config.HorseStimulant = {
    enabled        = true,
    item           = 'horse_stimulant',
    label          = 'Horse Stimulant',
    duration       = 30 * 60, -- seconds the boost lasts (30 minutes)
    useDistance    = 3.0,     -- must be mounted or within this distance of your active horse
    staminaFloor   = 100,     -- stamina (0-100) is kept topped up to this while boosted
    fortifyAmount  = 100.0,   -- golden "fortified" overpower applied to the stamina core/bar
    speedMultiplier = 1.10,   -- move-rate multiplier while mounted & boosted (1.0 = no speed boost)
    allowReuse     = false,   -- false = can't use another while a boost is still active
}

Config.HorseNeeds = {
    enabled            = true,
    decayInterval      = 60000, -- ms between hunger/thirst decay ticks while a horse is active
    hungerDecayPerTick = 1,     -- hunger points lost per tick
    thirstDecayPerTick = 1,     -- thirst points lost per tick (drains a bit faster than hunger)
    criticalThreshold  = 15,    -- once hunger OR thirst drops below this, the horse starts taking damage
    healthDrainPerTick = 1,     -- health % lost per decay tick while starving/dehydrated
    wellFedThreshold   = 50,    -- once hunger AND thirst are both at/above this, the horse slowly heals
    healthRegenPerTick = 1,     -- health % gained per decay tick while well fed/watered (capped at 100)
}

-- ===================== HITCHED HORSES =====================
-- RedM has no "is hitched" native, so a horse counts as hitched when you're off it and it is
-- standing right next to one of these hitching-post props. Natural drinking/grazing is skipped
-- while hitched so the horse doesn't pull itself off the post and wander.
Config.HorseHitch = {
    blockNaturalNeeds = true,
    detectRadius      = 3.0,   -- how close the horse must be to a post to count as hitched
    postModels = {
        'p_hitchingpost01x', 'p_hitchingpost02x', 'p_hitchingpost03x', 'p_hitchingpost04x',
        'p_hitchingpost05x', 'p_hitchingpost06x', 'p_hitchingpost07x', 'p_horsehitchnbd01x',
        'p_hitchpost01x', 'p_hitchpost02x',
    },
}

-- ===================== NATURAL DRINKING (rivers / lakes / troughs) =====================
Config.HorseNaturalDrink = {
    enabled         = true,
    thirstThreshold = 40,    -- horse only drinks when thirst is at/below this
    thirstRestore   = 100,   -- thirst is restored to this value (0-100)
    checkInterval   = 2000,  -- ms between proximity checks
    stillTime       = 3000,  -- ms the horse must stand still near water before it drinks
    drinkDuration   = 8000,  -- ms the drinking animation plays
    cooldown        = 120000,-- ms before the horse can drink naturally again
    waterRadius     = 2.5,   -- how far in front of the horse to look for river/lake water
    troughRadius    = 2.5,   -- how close the horse must be to a trough prop
    allowMounted    = true,  -- drink while the player is still in the saddle
    troughModels = {
        'p_watertrough01x', 'p_watertrough01x_new', 'p_watertrough02x', 'p_watertrough03x', 'p_watertroughsml01x',
    },
}

-- ===================== NATURAL GRAZING (hay near the player) =====================
Config.HorseNaturalGraze = {
    enabled         = true,
    hungerThreshold = 40,     -- horse only goes looking for hay when hunger is at/below this
    hungerRestore   = 100,    -- hunger is restored to this value (0-100)
    checkInterval   = 3000,   -- ms between checks for nearby hay
    searchRadius    = 15.0,   -- how far from the PLAYER the horse will wander to find hay
    eatDistance     = 1.8,    -- how close the horse gets to the hay before eating
    walkTimeout     = 15000,  -- ms the horse gets to reach the hay before giving up
    eatDuration     = 10000,  -- ms the eating animation plays
    cooldown        = 120000, -- ms before the horse can graze naturally again
    eatAnim = { dict = 'amb_creature_mammal@world_horse_grazing@base', clip = 'base' },
    hayModels = {             -- world props the horse will eat from (add/remove as you like)
        'p_haybale01x', 'mp001_p_mp_haybalecover01x', 'mp001_p_mp_haybalecover03x',  'p_gndblnd_hay01x', 'p_gndblnd_hay02x',
        'p_gndblnd_hay03x', 'p_haybale03x', 'p_haybale04x',  'p_haybalecover01x', 'p_haybalecover02x', 'p_haybalecover03x',
        'p_haypile_wag01x', 'p_haypile01x', 'p_haypile02x',  'p_haypile03x', 'p_haypile04x', 's_haybale01x', 'p_feedtrough01x',
		'p_feedtroughsml01x',
    },
}

-- ===================== HORSE LANTERN =====================
-- Using the item toggles a saddle lantern on your active horse (item is not consumed).
-- Hashes as used by rsg-horses (github.com/RexShack/rsg-horses, client/client.lua)
Config.HorseLantern = {
    enabled  = true,
    item     = 'horse_lantern',
    hash     = 0x635E387C, -- lantern shop item
    category = 0x1530BE1C, -- metaped category removed to take the lantern off
    distance = 3.0, -- how close you must be to your horse (or be riding it) to fit/remove the lantern
}

-- ===================== BRUSHING =====================
Config.HorseBrushItem = 'horse_brush' -- item required (not consumed) to Brush Horse; using it from the inventory brushes your horse
Config.HorseBrushDistance = 3.0 -- how close you must be to your horse to use the brush or a feed item from the inventory

-- ===================== BONDING =====================
Config.HorseBonding = {
    enabled   = true,
    feedGain  = 1, -- bonding gained per successful Feed Horse
    waterGain = 1, -- bonding gained per successful Water Horse
    brushGain = 2, -- bonding gained per successful Brush Horse (grooming bonds the most)
}

Config.HideNativeBrushFeed = true -- hide the game's own Brush / Feed horse prompts (ox_target options are used instead)

-- ===================== HORSE INVENTORY =====================
Config.HorseInventory = {
    enabled   = true,     -- adds an "Open Saddlebags" target prompt to the player's active horse (rsg-inventory stash)
    maxweight = 40000,    -- stash max weight (grams)
    slots     = 20,       -- stash slots
    distance  = 2.5,      -- ox_target interaction distance
    nativeCargoPrompt = true, -- the game's Horse Cargo prompt (B) beside the horse opens this stash
    requireSaddlebags = true, -- true: the horse stash can only be opened when saddlebags are fitted (tack); false: always accessible
}

-- ===================== FLEE =====================
Config.HorseFlee = {
    enabled          = true,  -- adds a "Flee Horse" target prompt to the player's active horse
    fleeDelay        = 10000, -- ms the horse runs off for before being removed from the world
    storeOnFlee      = false, -- true: horse is stored back at its nearest stable, player must go retrieve it
                              -- false: horse stays "checked out"; whistling brings it running back to the player
    respawnDistance  = 15.0,  -- distance behind the player a fled horse is respawned at before it runs over (whistle recall)
}

-- ===================== WILD HORSES =====================
-- Break a wild horse (the game's taming minigame), ride it to any stable and choose
-- "Claim Wild Horse" at the stable hand. Only breeds listed in Config.Breeds can be claimed.
Config.WildHorse = {
    enabled       = true,
    claimFee      = 0,        -- $ paperwork fee to register the horse (0 = free), taken from Config.PaymentAccount
    claimWindow   = 30 * 60,  -- seconds after breaking it the horse can still be claimed
    horseDistance = 15.0,     -- the broken horse must be this close to the player (and the stable) to claim it
}

-- ===================== BREEDING =====================
Config.Breeding = {
    enabled       = true,
    cost          = 60,             -- $ cost to start breeding two horses
    time          = 24 * 60 * 60 * 1000, -- ms until foal is ready (1 real-life day)
    sameStableOnly = true,          -- both parent horses must be stabled at the same location
    requireOppositeGender = true,   -- parents must be one stallion (male) and one mare (female)
    lockParents   = true,           -- parents can't be taken out or transferred until the foal is collected
    parentCooldown = 60 * 60 * 1000,-- ms after a breeding starts before either parent can breed again (0 = none)
    statVariance  = 1,              -- foal stats = parents' average +/- this many points (stats use the 1..Config.BreedStatMax scale)
    betterParentChance = 25,        -- % chance per stat that the foal inherits the BETTER parent's value instead of the average
}

-- ===================== AGING / LIFESPAN =====================
-- Age is counted in real-life days since the horse was bought (or born as a foal).
Config.HorseAging = {
    enabled       = true,
    youngUntilDays = 7,      -- 0..6 days owned = Young (can't breed)
    oldFromDays    = 60,     -- 60+ days owned  = Old (can't breed)
    lifespanDays   = 90,     -- at this age the horse dies of natural causes (can't be revived or insured back)
    warnDays       = 7,      -- show "X days left" on old horses within this many days of their lifespan
    oldMinStamina  = 40,     -- stamina core cap (%) an old horse falls to by the end of its life; starts at 100 on the first 'old' day and drops each day
    checkInterval  = 10 * 60 * 1000, -- ms between server checks for horses that have reached their lifespan
}

-- ===================== GIVE HORSE TO ANOTHER PLAYER =====================
Config.HorseGive = {
    enabled  = true,
    distance = 5.0,    -- the other player must be standing this close to you (at the stable)
    fee      = 0,      -- $ paperwork fee charged to the giver (0 = free)
    timeout  = 30000,  -- ms the receiving player has to accept
    maxPrice = 100000, -- highest asking price a player can set (0 / blank = free)
}

-- ===================== STABLES =====================
Config.Stables = {
    {
        name       = 'valentine',
        label      = 'Valentine Stables',
        pedModel   = `u_m_m_bwmstablehand_01`,
        pedCoords  = vector4(-366.26, 790.76, 116.17, 187.53),
        storeCoords = vector4(-318.5, 783.2, 116.2, 60.0),
        previewCoords = vector4(-368.52, 786.96, 116.16 -1, 277.88),
        blip = { sprite = 'blip_shop_horse', color = 'BLIP_MODIFIER_MP_COLOR_6', scale = 0.2 },
    },
    {
        name       = 'blackwater',
        label      = 'Blackwater Stables',
        pedModel   = `u_m_m_bwmstablehand_01`,
        pedCoords  = vector4(-865.1928, -1366.3270, 43.5440, 86.8795),
        storeCoords = vector4(-865.1928, -1366.3270, 43.5440, 86.8795),
        previewCoords = vector4(-872.01, -1366.28, 42.53, 265.47),
        blip = { sprite = 'blip_shop_horse', color = 'BLIP_MODIFIER_MP_COLOR_6', scale = 0.2 },
    },
    {
        name       = 'rhodes',
        label      = 'Rhodes Stables',
        pedModel   = `u_m_m_bwmstablehand_01`,
        pedCoords  = vector4(1211.71, -191.07, 101.46, 118.85),
        storeCoords = vector4(1211.71, -191.07, 101.46, 118.85),
        previewCoords = vector4(1209.35, -192.60, 100.38, 10.14),
        blip = { sprite = 'blip_shop_horse', color = 'BLIP_MODIFIER_MP_COLOR_6', scale = 0.2 },
    },
    {
        name       = 'saintdenis',
        label      = 'Saint Denis Stables',
        pedModel   = `u_m_m_bwmstablehand_01`,
        pedCoords  = vector4(2506.05, -1459.82, 46.32, 96.34),
        storeCoords = vector4(2506.05, -1459.82, 46.32, 96.34),
        previewCoords = vector4(2503.22, -1454.04, 45.31, 179.25),
        blip = { sprite = 'blip_shop_horse', color = 'BLIP_MODIFIER_MP_COLOR_6', scale = 0.2 },
    },
    {
        name       = 'strawberry',
        label      = 'Strawberry Stables',
        pedModel   = `u_m_m_bwmstablehand_01`,
        pedCoords  = vector4(-1819.25, -564.85, 156.06, 347.82),
        storeCoords = vector4(-1819.83, -561.63, 155.06, 257.78),
        previewCoords = vector4(-1819.83, -561.63, 155.06, 257.78),
        blip = { sprite = 'blip_shop_horse', color = 'BLIP_MODIFIER_MP_COLOR_6', scale = 0.2 },
    },
}

-- ===================== BREEDS =====================
Config.BreedStatMax = 10

-- Price ranges shown in the Buy menu "Price" filter (max = nil means no upper limit)
Config.BuyPriceBands = {
    { label = 'Under $150',   min = 0,   max = 149 },
    { label = '$150 - $299',  min = 150, max = 299 },
    { label = '$300 - $599',  min = 300, max = 599 },
    { label = '$600 - $999',  min = 600, max = 999 },
    { label = '$1000+',       min = 1000 },
}

Config.Breeds = {
	{
        model = `a_c_horse_americanpaint_greyovero`,
        label = 'American Paint (Grey Overo)',
        class = 'Work Horse',
        breed = 'americanpaint',
        price = 130,
        handling = 'Standard',
        health = 3,
        stamina = 4,
        speed = 3,
        acceleration = 3,
        description = 'American Paints are workhorses, identified by their robust build and distinctive patterned coat. Their personality, intelligence, and willingness to work make these horses easy to care for. This breed is healthy, with a reasonable amount of speed and great stamina; perfect for ranch work.'
    },
    {
        model = `a_c_horse_americanpaint_overo`,
        label = 'American Paint (Overo)',
        class = 'Work Horse',
        breed = 'americanpaint',
        price = 130,
        handling = 'Standard',
        health = 3,
        stamina = 4,
        speed = 3,
        acceleration = 3,
        description = 'American Paints are workhorses, identified by their robust build and distinctive patterned coat. Their personality, intelligence, and willingness to work make these horses easy to care for. This breed is healthy, with a reasonable amount of speed and great stamina; perfect for ranch work.'
    },
    {
        model = `a_c_horse_americanpaint_splashedwhite`,
        label = 'American Paint (Splashed White)',
        class = 'Work Horse',
        breed = 'americanpaint',
        price = 140,
        handling = 'Standard',
        health = 3,
        stamina = 5,
        speed = 3,
        acceleration = 3,
        description = 'American Paints are workhorses, identified by their robust build and distinctive patterned coat. Their personality, intelligence, and willingness to work make these horses easy to care for. This breed is healthy, with a reasonable amount of speed and great stamina; perfect for ranch work.'
    },
    {
        model = `a_c_horse_americanpaint_tobiano`,
        label = 'American Paint (Tobiano)',
        class = 'Work Horse',
        breed = 'americanpaint',
        price = 130,
        handling = 'Standard',
        health = 3,
        stamina = 4,
        speed = 3,
        acceleration = 3,
        description = 'American Paints are workhorses, identified by their robust build and distinctive patterned coat. Their personality, intelligence, and willingness to work make these horses easy to care for. This breed is healthy, with a reasonable amount of speed and great stamina; perfect for ranch work.'
    },
    {
        model = `a_c_horse_americanstandardbred_black`,
        label = 'American Standardbred (Black)',
        class = 'Race Horse',
        breed = 'americanstandardbred',
        price = 130,
        handling = 'Race',
        health = 3,
        stamina = 3,
        speed = 4,
        acceleration = 3,
        description = 'American Standardbreds are race horses, identified by their agile frame, powerful limbs and healthy coat. This breed handles well, is easy to train, but can be frightened by loud noises. They are healthy, and their average stamina allows them to maintain a fast pace for a long time.'
    },
    {
        model = `a_c_horse_americanstandardbred_buckskin`,
        label = 'American Standardbred (Buckskin)',
        class = 'Race Horse',
        breed = 'americanstandardbred',
        price = 130,
        handling = 'Race',
        health = 3,
        stamina = 3,
        speed = 4,
        acceleration = 3,
        description = 'American Standardbreds are race horses, identified by their agile frame, powerful limbs and healthy coat. This breed handles well, is easy to train, but can be frightened by loud noises. They are healthy, and their average stamina allows them to maintain a fast pace for a long time.'
    },
    {
        model = `a_c_horse_americanstandardbred_lightbuckskin`,
        label = 'American Standardbred (Light Buckskin)',
        class = 'Race Horse',
        breed = 'americanstandardbred',
        price = 150,
        handling = 'Race',
        health = 3,
        stamina = 3,
        speed = 4,
        acceleration = 3,
        description = 'American Standardbreds are race horses, identified by their agile frame, powerful limbs and healthy coat. This breed handles well, is easy to train, but can be frightened by loud noises. They are healthy, and their average stamina allows them to maintain a fast pace for a long time.'
    },
    {
        model = `a_c_horse_americanstandardbred_palominodapple`,
        label = 'American Standardbred (Palomino Dapple)',
        class = 'Race Horse',
        breed = 'americanstandardbred',
        price = 150,
        handling = 'Race',
        health = 3,
        stamina = 3,
        speed = 5,
        acceleration = 4,
        description = 'American Standardbreds are race horses, identified by their agile frame, powerful limbs and healthy coat. This breed handles well, is easy to train, but can be frightened by loud noises. They are healthy, and their average stamina allows them to maintain a fast pace for a long time.'
    },
    {
        model = `a_c_horse_americanstandardbred_silvertailbuckskin`,
        label = 'American Standardbred (Silver Tail Buckskin)',
        class = 'Race Horse',
        breed = 'americanstandardbred',
        price = 450,
        handling = 'Race',
        health = 4,
        stamina = 4,
        speed = 5,
        acceleration = 4,
        description = 'American Standardbreds are race horses, identified by their agile frame, powerful limbs and healthy coat. This breed handles well, is easy to train, but can be frightened by loud noises. They are healthy, and their average stamina allows them to maintain a fast pace for a long time.'
    },
    {
        model = `a_c_horse_andalusian_darkbay`,
        label = 'Andalusian (Dark Bay)',
        class = 'War Horse',
        breed = 'andalusian',
        price = 150,
        handling = 'Standard',
        health = 5,
        stamina = 4,
        speed = 3,
        acceleration = 3,
        description = 'Andalusians are war horses, identified by their muscular build and proud bearing. Intelligent, hardy and naturally brave, these horses make reliable mounts in a firefight or predator attack. With great health and average speed and stamina, they are steadfast companions.'
    },
    {
        model = `a_c_horse_andalusian_perlino`,
        label = 'Andalusian (Perlino)',
        class = 'War Horse',
        breed = 'andalusian',
        price = 475,
        handling = 'Standard',
        health = 7,
        stamina = 5,
        speed = 3,
        acceleration = 3,
        description = 'Andalusians are war horses, identified by their muscular build and proud bearing. Intelligent, hardy and naturally brave, these horses make reliable mounts in a firefight or predator attack. With great health and average speed and stamina, they are steadfast companions.'
    },
    {
        model = `a_c_horse_andalusian_rosegray`,
        label = 'Andalusian (Rose Gray)',
        class = 'War Horse',
        breed = 'andalusian',
        price = 450,
        handling = 'Standard',
        health = 7,
        stamina = 5,
        speed = 3,
        acceleration = 3,
        description = 'Andalusians are war horses, identified by their muscular build and proud bearing. Intelligent, hardy and naturally brave, these horses make reliable mounts in a firefight or predator attack. With great health and average speed and stamina, they are steadfast companions.'
    },
    {
        model = `a_c_horse_appaloosa_blacksnowflake`,
        label = 'Appaloosa (Black Snowflake)',
        class = 'Work Horse',
        breed = 'appaloosa',
        price = 130,
        handling = 'Standard',
        health = 3,
        stamina = 4,
        speed = 3,
        acceleration = 3,
        description = 'Appaloosas are workhorses, identified by their sturdy build and unique spotted coat patterns. Gentle, hardy and willing, they are popular among travelers and frontiersmen alike. This breed is healthy with great stamina and decent speed.'
    },
    {
        model = `a_c_horse_appaloosa_blanket`,
        label = 'Appaloosa (Blanket)',
        class = 'Work Horse',
        breed = 'appaloosa',
        price = 130,
        handling = 'Standard',
        health = 3,
        stamina = 4,
        speed = 3,
        acceleration = 3,
        description = 'Appaloosas are workhorses, identified by their sturdy build and unique spotted coat patterns. Gentle, hardy and willing, they are popular among travelers and frontiersmen alike. This breed is healthy with great stamina and decent speed.'
    },
    {
        model = `a_c_horse_appaloosa_brownleopard`,
        label = 'Appaloosa (Brown Leopard)',
        class = 'Work Horse',
        breed = 'appaloosa',
        price = 450,
        handling = 'Standard',
        health = 5,
        stamina = 6,
        speed = 4,
        acceleration = 3,
        description = 'Appaloosas are workhorses, identified by their sturdy build and unique spotted coat patterns. Gentle, hardy and willing, they are popular among travelers and frontiersmen alike. This breed is healthy with great stamina and decent speed.'
    },
    {
        model = `a_c_horse_appaloosa_fewspotted_pc`,
        label = 'Appaloosa (Few Spotted)',
        class = 'Work Horse',
        breed = 'appaloosa',
        price = 130,
        handling = 'Standard',
        health = 3,
        stamina = 5,
        speed = 3,
        acceleration = 3,
        description = 'Appaloosas are workhorses, identified by their sturdy build and unique spotted coat patterns. Gentle, hardy and willing, they are popular among travelers and frontiersmen alike. This breed is healthy with great stamina and decent speed.'
    },
    {
        model = `a_c_horse_appaloosa_leopard`,
        label = 'Appaloosa (Leopard)',
        class = 'Work Horse',
        breed = 'appaloosa',
        price = 450,
        handling = 'Standard',
        health = 5,
        stamina = 6,
        speed = 4,
        acceleration = 3,
        description = 'Appaloosas are workhorses, identified by their sturdy build and unique spotted coat patterns. Gentle, hardy and willing, they are popular among travelers and frontiersmen alike. This breed is healthy with great stamina and decent speed.'
    },
    {
        model = `a_c_horse_appaloosa_leopardblanket`,
        label = 'Appaloosa (Leopard Blanket)',
        class = 'Work Horse',
        breed = 'appaloosa',
        price = 130,
        handling = 'Standard',
        health = 3,
        stamina = 4,
        speed = 3,
        acceleration = 3,
        description = 'Appaloosas are workhorses, identified by their sturdy build and unique spotted coat patterns. Gentle, hardy and willing, they are popular among travelers and frontiersmen alike. This breed is healthy with great stamina and decent speed.'
    },
    {
        model = `a_c_horse_arabian_black`,
        label = 'Arabian (Black)',
        class = 'Superior Horse',
        breed = 'arabian',
        price = 1050,
        handling = 'Elite',
        health = 6,
        stamina = 6,
        speed = 6,
        acceleration = 6,
        description = 'Arabians are superior horses, identified by their distinct head shape and high-arched tail. Spirited and intelligent, the breed possesses high-end stats across the board, making them prized possessions for any rider.'
    },
    {
        model = `a_c_horse_arabian_grey`,
        label = 'Arabian (Grey)',
        class = 'Superior Horse',
        breed = 'arabian',
        price = 450,
        handling = 'Elite',
        health = 5,
        stamina = 5,
        speed = 6,
        acceleration = 6,
        description = 'Arabians are superior horses, identified by their distinct head shape and high-arched tail. Spirited and intelligent, the breed possesses high-end stats across the board, making them prized possessions for any rider.'
    },
    {
        model = `a_c_horse_arabian_redchestnut`,
        label = 'Arabian (Red Chestnut)',
        class = 'Superior Horse',
        breed = 'arabian',
        price = 250,
        handling = 'Elite',
        health = 4,
        stamina = 4,
        speed = 5,
        acceleration = 5,
        description = 'Arabians are superior horses, identified by their distinct head shape and high-arched tail. Spirited and intelligent, the breed possesses high-end stats across the board, making them prized possessions for any rider.'
    },
    {
        model = `a_c_horse_arabian_redchestnut_pc`,
        label = 'Arabian (Red Chestnut)',
        class = 'Superior Horse',
        breed = 'arabian',
        price = 250,
        handling = 'Elite',
        health = 4,
        stamina = 4,
        speed = 5,
        acceleration = 5,
        description = 'Arabians are superior horses, identified by their distinct head shape and high-arched tail. Spirited and intelligent, the breed possesses high-end stats across the board, making them prized possessions for any rider.'
    },
    {
        model = `a_c_horse_arabian_rosegreybay`,
        label = 'Arabian (Rose Grey Bay)',
        class = 'Superior Horse',
        breed = 'arabian',
        price = 1250,
        handling = 'Elite',
        health = 7,
        stamina = 7,
        speed = 6,
        acceleration = 6,
        description = 'Arabians are superior horses, identified by their distinct head shape and high-arched tail. Spirited and intelligent, the breed possesses high-end stats across the board, making them prized possessions for any rider.'
    },
    {
        model = `a_c_horse_arabian_warpedbrindle_pc`,
        label = 'Arabian (Warped Brindle)',
        class = 'Superior Horse',
        breed = 'arabian',
        price = 450,
        handling = 'Elite',
        health = 4,
        stamina = 5,
        speed = 5,
        acceleration = 5,
        description = 'Arabians are superior horses, identified by their distinct head shape and high-arched tail. Spirited and intelligent, the breed possesses high-end stats across the board, making them prized possessions for any rider.'
    },
    {
        model = `a_c_horse_arabian_white`,
        label = 'Arabian (White)',
        class = 'Superior Horse',
        breed = 'arabian',
        price = 1200,
        handling = 'Elite',
        health = 5,
        stamina = 5,
        speed = 6,
        acceleration = 6,
        description = 'Arabians are superior horses, identified by their distinct head shape and high-arched tail. Spirited and intelligent, the breed possesses high-end stats across the board, making them prized possessions for any rider.'
    },
    {
        model = `a_c_horse_ardennes_bayroan`,
        label = 'Ardennes (Bay Roan)',
        class = 'War Horse',
        breed = 'ardennes',
        price = 140,
        handling = 'Standard',
        health = 5,
        stamina = 4,
        speed = 3,
        acceleration = 3,
        description = 'Ardennes are war horses, identified by their heavy build and powerful frame. Exceptionally brave and calm under fire, these horses excel in dangerous situations and heavy labor, boasting high health and endurance.'
    },
    {
        model = `a_c_horse_ardennes_irongreyroan`,
        label = 'Ardennes (Iron Grey Roan)',
        class = 'War Horse',
        breed = 'ardennes',
        price = 450,
        handling = 'Standard',
        health = 7,
        stamina = 5,
        speed = 3,
        acceleration = 3,
        description = 'Ardennes are war horses, identified by their heavy build and powerful frame. Exceptionally brave and calm under fire, these horses excel in dangerous situations and heavy labor, boasting high health and endurance.'
    },
    {
        model = `a_c_horse_ardennes_strawberryroan`,
        label = 'Ardennes (Strawberry Roan)',
        class = 'War Horse',
        breed = 'ardennes',
        price = 500,
        handling = 'Standard',
        health = 7,
        stamina = 5,
        speed = 3,
        acceleration = 3,
        description = 'Ardennes are war horses, identified by their heavy build and powerful frame. Exceptionally brave and calm under fire, these horses excel in dangerous situations and heavy labor, boasting high health and endurance.'
    },
    {
        model = `a_c_horse_belgian_blondchestnut`,
        label = 'Belgian Draft Horse (Blond Chestnut)',
        class = 'Draft Horse',
        breed = 'belgian',
        price = 120,
        handling = 'Heavy',
        health = 3,
        stamina = 3,
        speed = 3,
        acceleration = 3,
        description = 'Belgian draft horses are heavy workhorses, identified by their massive size and muscular build. Docile and incredibly strong, they are built for hauling heavy loads rather than fast-paced riding.'
    },
    {
        model = `a_c_horse_belgian_mealychestnut`,
        label = 'Belgian Draft Horse (Mealy Chestnut)',
        class = 'Draft Horse',
        breed = 'belgian',
        price = 130,
        handling = 'Heavy',
        health = 3,
        stamina = 3,
        speed = 3,
        acceleration = 3,
        description = 'Belgian draft horses are heavy workhorses, identified by their massive size and muscular build. Docile and incredibly strong, they are built for hauling heavy loads rather than fast-paced riding.'
    },
    {
        model = `a_c_horse_breton_grullodun`,
        label = 'Breton (Grullo Dun)',
        class = 'Multi-Class War/Race',
        breed = 'breton',
        price = 550,
        handling = 'Standard',
        health = 5,
        stamina = 4,
        speed = 4,
        acceleration = 3,
        description = 'Bretons are compact, muscular multi-class horses combining the agility of a race horse with the fearlessness and bulk of a war horse. Bred for rugged frontier work and bounty hunting.'
    },
    {
        model = `a_c_horse_breton_mealydapplebay`,
        label = 'Breton (Mealy Dapple Bay)',
        class = 'Multi-Class War/Race',
        breed = 'breton',
        price = 950,
        handling = 'Standard',
        health = 6,
        stamina = 5,
        speed = 5,
        acceleration = 4,
        description = 'Bretons are compact, muscular multi-class horses combining the agility of a race horse with the fearlessness and bulk of a war horse. Bred for rugged frontier work and bounty hunting.'
    },
    {
        model = `a_c_horse_breton_redroan`,
        label = 'Breton (Red Roan)',
        class = 'Multi-Class War/Race',
        breed = 'breton',
        price = 150,
        handling = 'Standard',
        health = 5,
        stamina = 4,
        speed = 4,
        acceleration = 3,
        description = 'Bretons are compact, muscular multi-class horses combining the agility of a race horse with the fearlessness and bulk of a war horse. Bred for rugged frontier work and bounty hunting.'
    },
    {
        model = `a_c_horse_breton_sealbrown`,
        label = 'Breton (Seal Brown)',
        class = 'Multi-Class War/Race',
        breed = 'breton',
        price = 550,
        handling = 'Standard',
        health = 6,
        stamina = 6,
        speed = 5,
        acceleration = 4,
        description = 'Bretons are compact, muscular multi-class horses combining the agility of a race horse with the fearlessness and bulk of a war horse. Bred for rugged frontier work and bounty hunting.'
    },
    {
        model = `a_c_horse_breton_sorrel`,
        label = 'Breton (Sorrel)',
        class = 'Multi-Class War/Race',
        breed = 'breton',
        price = 150,
        handling = 'Standard',
        health = 5,
        stamina = 4,
        speed = 4,
        acceleration = 3,
        description = 'Bretons are compact, muscular multi-class horses combining the agility of a race horse with the fearlessness and bulk of a war horse. Bred for rugged frontier work and bounty hunting.'
    },
    {
        model = `a_c_horse_breton_steelgrey`,
        label = 'Breton (Steel Grey)',
        class = 'Multi-Class War/Race',
        breed = 'breton',
        price = 950,
        handling = 'Standard',
        health = 7,
        stamina = 7,
        speed = 6,
        acceleration = 5,
        description = 'Bretons are compact, muscular multi-class horses combining the agility of a race horse with the fearlessness and bulk of a war horse. Bred for rugged frontier work and bounty hunting.'
    },
    {
        model = `a_c_horse_criollo_baybrindle`,
        label = 'Criollo (Bay Brindle)',
        class = 'Multi-Class Race/Work',
        breed = 'criollo',
        price = 550,
        handling = 'Standard',
        health = 4,
        stamina = 4,
        speed = 4,
        acceleration = 3,
        description = 'Criollos are nimble multi-class horses combining endurance, speed, and cow-sense, making them exceptional companions for long-distance travel and collector expeditions.'
    },
    {
        model = `a_c_horse_criollo_bayframeovero`,
        label = 'Criollo (Bay Frame Overo)',
        class = 'Multi-Class Race/Work',
        breed = 'criollo',
        price = 950,
        handling = 'Standard',
        health = 5,
        stamina = 5,
        speed = 6,
        acceleration = 5,
        description = 'Criollos are nimble multi-class horses combining endurance, speed, and cow-sense, making them exceptional companions for long-distance travel and collector expeditions.'
    },
    {
        model = `a_c_horse_criollo_blueroanovero`,
        label = 'Criollo (Blue Roan Overo)',
        class = 'Multi-Class Race/Work',
        breed = 'criollo',
        price = 150,
        handling = 'Standard',
        health = 4,
        stamina = 4,
        speed = 4,
        acceleration = 3,
        description = 'Criollos are nimble multi-class horses combining endurance, speed, and cow-sense, making them exceptional companions for long-distance travel and collector expeditions.'
    },
    {
        model = `a_c_horse_criollo_dun`,
        label = 'Criollo (Dun)',
        class = 'Multi-Class Race/Work',
        breed = 'criollo',
        price = 150,
        handling = 'Standard',
        health = 4,
        stamina = 4,
        speed = 4,
        acceleration = 3,
        description = 'Criollos are nimble multi-class horses combining endurance, speed, and cow-sense, making them exceptional companions for long-distance travel and collector expeditions.'
    },
    {
        model = `a_c_horse_criollo_marblesabino`,
        label = 'Criollo (Marble Sabino)',
        class = 'Multi-Class Race/Work',
        breed = 'criollo',
        price = 950,
        handling = 'Standard',
        health = 5,
        stamina = 5,
        speed = 6,
        acceleration = 5,
        description = 'Criollos are nimble multi-class horses combining endurance, speed, and cow-sense, making them exceptional companions for long-distance travel and collector expeditions.'
    },
    {
        model = `a_c_horse_criollo_sorrelovero`,
        label = 'Criollo (Sorrel Overo)',
        class = 'Multi-Class Race/Work',
        breed = 'criollo',
        price = 550,
        handling = 'Standard',
        health = 4,
        stamina = 4,
        speed = 4,
        acceleration = 3,
        description = 'Criollos are nimble multi-class horses combining endurance, speed, and cow-sense, making them exceptional companions for long-distance travel and collector expeditions.'
    },
    {
        model = `a_c_horse_dutchwarmblood_chocolateroan`,
        label = 'Chocolate Dutch Warmblood',
        class = 'Work Horse',
        breed = 'dutchwarmblood',
        price = 450,
        handling = 'Standard',
        health = 5,
        stamina = 6,
        speed = 4,
        acceleration = 3,
        description = 'Dutch Warmbloods are athletic workhorses known for their impressive build, agility, and stamina. They excel at jumping and long-distance travel.'
    },
    {
        model = `a_c_horse_dutchwarmblood_sealbrown`,
        label = 'Seal Brown Dutch Warmblood',
        class = 'Work Horse',
        breed = 'dutchwarmblood',
        price = 150,
        handling = 'Standard',
        health = 4,
        stamina = 5,
        speed = 3,
        acceleration = 3,
        description = 'Dutch Warmbloods are athletic workhorses known for their impressive build, agility, and stamina. They excel at jumping and long-distance travel.'
    },
    {
        model = `a_c_horse_dutchwarmblood_sootybuckskin`,
        label = 'Sooty Dutch Warmblood',
        class = 'Work Horse',
        breed = 'dutchwarmblood',
        price = 450,
        handling = 'Standard',
        health = 4,
        stamina = 5,
        speed = 3,
        acceleration = 3,
        description = 'Dutch Warmbloods are athletic workhorses known for their impressive build, agility, and stamina. They excel at jumping and long-distance travel.'
    },
    {
        model = `a_c_horse_gypsycob_skewbald`,
        label = 'Gypsy Cob (Skewbald)',
        class = 'Multi-Class War/Work',
        breed = 'gypsycob',
        price = 150,
        handling = 'Standard',
        health = 5,
        stamina = 4,
        speed = 4,
        acceleration = 3,
        description = 'Gypsy Cobs are sturdy, heavy-boned multi-class horses featuring distinctive feathering on their legs. They combine a calm temperament with great strength and stamina.'
    },
    {
        model = `a_c_horse_gypsycob_splashedpiebald`,
        label = 'Gypsy Cob (Splashed Piebald)',
        class = 'Multi-Class War/Work',
        breed = 'gypsycob',
        price = 500,
        handling = 'Standard',
        health = 6,
        stamina = 5,
        speed = 5,
        acceleration = 4,
        description = 'Gypsy Cobs are sturdy, heavy-boned multi-class horses featuring distinctive feathering on their legs. They combine a calm temperament with great strength and stamina.'
    },
    {
        model = `a_c_horse_gypsycob_whiteblagdon`,
        label = 'Gypsy Cob (White Blagdon)',
        class = 'Multi-Class War/Work',
        breed = 'gypsycob',
        price = 950,
        handling = 'Standard',
        health = 6,
        stamina = 5,
        speed = 5,
        acceleration = 4,
        description = 'Gypsy Cobs are sturdy, heavy-boned multi-class horses featuring distinctive feathering on their legs. They combine a calm temperament with great strength and stamina.'
    },
    {
        model = `a_c_horse_hungarianhalfbred_darkdapplegrey`,
        label = 'Hungarian Half-bred (Dark Dapple Grey)',
        class = 'War Horse',
        breed = 'hungarianhalfbred',
        price = 150,
        handling = 'Standard',
        health = 5,
        stamina = 4,
        speed = 3,
        acceleration = 3,
        description = 'Hungarian Half-breds are powerful war horses, easily identified by their large frame and bold disposition. Courageous and resilient, they make reliable mounts in dangerous environments.'
    },
    {
        model = `a_c_horse_hungarianhalfbred_flaxenchestnut`,
        label = 'Hungarian Half-bred (Flaxen Chestnut)',
        class = 'War Horse',
        breed = 'hungarianhalfbred',
        price = 130,
        handling = 'Standard',
        health = 3,
        stamina = 4,
        speed = 3,
        acceleration = 3,
        description = 'Hungarian Half-breds are powerful war horses, easily identified by their large frame and bold disposition. Courageous and resilient, they make reliable mounts in dangerous environments.'
    },
    {
        model = `a_c_horse_hungarianhalfbred_liverchestnut`,
        label = 'Hungarian Half-bred (Liver Chestnut)',
        class = 'War Horse',
        breed = 'hungarianhalfbred',
        price = 150,
        handling = 'Standard',
        health = 4,
        stamina = 3,
        speed = 3,
        acceleration = 3,
        description = 'Hungarian Half-breds are powerful war horses, easily identified by their large frame and bold disposition. Courageous and resilient, they make reliable mounts in dangerous environments.'
    },
    {
        model = `a_c_horse_hungarianhalfbred_piebaldtobiano`,
        label = 'Hungarian Half-bred (Piebald Tobiano)',
        class = 'War Horse',
        breed = 'hungarianhalfbred',
        price = 130,
        handling = 'Standard',
        health = 4,
        stamina = 3,
        speed = 3,
        acceleration = 3,
        description = 'Hungarian Half-breds are powerful war horses, easily identified by their large frame and bold disposition. Courageous and resilient, they make reliable mounts in dangerous environments.'
    },
    {
        model = `a_c_horse_kentuckysaddle_black`,
        label = 'Kentucky Saddler (Black)',
        class = 'Riding Horse',
        breed = 'kentuckysaddle',
        price = 50,
        handling = 'Standard',
        health = 3,
        stamina = 2,
        speed = 3,
        acceleration = 2,
        description = 'The Kentucky Saddler is a medium-build, muscular riding horse. Hardy and easy to tend to, their good nature and smooth gait make them ideal for everyday riding.'
    },
    {
        model = `a_c_horse_kentuckysaddle_buttermilkbuckskin_pc`,
        label = 'Kentucky Saddler (Buttermilk Buckskin)',
        class = 'Riding Horse',
        breed = 'kentuckysaddle',
        price = 50,
        handling = 'Standard',
        health = 3,
        stamina = 3,
        speed = 3,
        acceleration = 2,
        description = 'The Kentucky Saddler is a medium-build, muscular riding horse. Hardy and easy to tend to, their good nature and smooth gait make them ideal for everyday riding.'
    },
    {
        model = `a_c_horse_kentuckysaddle_chestnutpinto`,
        label = 'Kentucky Saddler (Chestnut Pinto)',
        class = 'Riding Horse',
        breed = 'kentuckysaddle',
        price = 50,
        handling = 'Standard',
        health = 3,
        stamina = 2,
        speed = 3,
        acceleration = 2,
        description = 'The Kentucky Saddler is a medium-build, muscular riding horse. Hardy and easy to tend to, their good nature and smooth gait make them ideal for everyday riding.'
    },
    {
        model = `a_c_horse_kentuckysaddle_grey`,
        label = 'Kentucky Saddler (Grey)',
        class = 'Riding Horse',
        breed = 'kentuckysaddle',
        price = 50,
        handling = 'Standard',
        health = 3,
        stamina = 2,
        speed = 3,
        acceleration = 2,
        description = 'The Kentucky Saddler is a medium-build, muscular riding horse. Hardy and easy to tend to, their good nature and smooth gait make them ideal for everyday riding.'
    },
    {
        model = `a_c_horse_kentuckysaddle_silverbay`,
        label = 'Kentucky Saddler (Silver Bay)',
        class = 'Riding Horse',
        breed = 'kentuckysaddle',
        price = 50,
        handling = 'Standard',
        health = 3,
        stamina = 2,
        speed = 3,
        acceleration = 2,
        description = 'The Kentucky Saddler is a medium-build, muscular riding horse. Hardy and easy to tend to, their good nature and smooth gait make them ideal for everyday riding.'
    },
    {
        model = `a_c_horse_kladruber_black`,
        label = 'Kladruber (Black)',
        class = 'Multi-Class War/Race',
        breed = 'kladruber',
        price = 150,
        handling = 'Standard',
        health = 5,
        stamina = 4,
        speed = 4,
        acceleration = 3,
        description = 'Kladrubers are stately multi-class carriage and war horses known for their distinctive Roman nose, heavy build, and impressive stamina over long distances.'
    },
    {
        model = `a_c_horse_kladruber_cremello`,
        label = 'Kladruber (Cremello)',
        class = 'Multi-Class War/Race',
        breed = 'kladruber',
        price = 550,
        handling = 'Standard',
        health = 6,
        stamina = 6,
        speed = 5,
        acceleration = 4,
        description = 'Kladrubers are stately multi-class carriage and war horses known for their distinctive Roman nose, heavy build, and impressive stamina over long distances.'
    },
    {
        model = `a_c_horse_kladruber_dapplerosegrey`,
        label = 'Kladruber (Dapple Rose Grey)',
        class = 'Multi-Class War/Race',
        breed = 'kladruber',
        price = 950,
        handling = 'Standard',
        health = 7,
        stamina = 7,
        speed = 6,
        acceleration = 5,
        description = 'Kladrubers are stately multi-class carriage and war horses known for their distinctive Roman nose, heavy build, and impressive stamina over long distances.'
    },
    {
        model = `a_c_horse_kladruber_grey`,
        label = 'Kladruber (Grey)',
        class = 'Multi-Class War/Race',
        breed = 'kladruber',
        price = 150,
        handling = 'Standard',
        health = 5,
        stamina = 4,
        speed = 4,
        acceleration = 3,
        description = 'Kladrubers are stately multi-class carriage and war horses known for their distinctive Roman nose, heavy build, and impressive stamina over long distances.'
    },
    {
        model = `a_c_horse_kladruber_silver`,
        label = 'Kladruber (Silver)',
        class = 'Multi-Class War/Race',
        breed = 'kladruber',
        price = 950,
        handling = 'Standard',
        health = 7,
        stamina = 7,
        speed = 6,
        acceleration = 5,
        description = 'Kladrubers are stately multi-class carriage and war horses known for their distinctive Roman nose, heavy build, and impressive stamina over long distances.'
    },
    {
        model = `a_c_horse_kladruber_white`,
        label = 'Kladruber (White)',
        class = 'Multi-Class War/Race',
        breed = 'kladruber',
        price = 550,
        handling = 'Standard',
        health = 5,
        stamina = 4,
        speed = 4,
        acceleration = 3,
        description = 'Kladrubers are stately multi-class carriage and war horses known for their distinctive Roman nose, heavy build, and impressive stamina over long distances.'
    },
    {
        model = `a_c_horse_missourifoxtrotter_amberchampagne`,
        label = 'Missouri Fox Trotter (Amber Champagne)',
        class = 'Multi-Class Race/Work',
        breed = 'missourifoxtrotter',
        price = 950,
        handling = 'Standard',
        health = 5,
        stamina = 6,
        speed = 7,
        acceleration = 5,
        description = 'Missouri Fox Trotters are smooth-gaiting multi-class race and work horses. Renowned for their incredible speed and stamina, they are built to cover vast distances effortlessly.'
    },
    {
        model = `a_c_horse_missourifoxtrotter_buckskinbrindle`,
        label = 'Missouri Fox Trotter (Buckskin Brindle)',
        class = 'Multi-Class Race/Work',
        breed = 'missourifoxtrotter',
        price = 1125,
        handling = 'Standard',
        health = 5,
        stamina = 6,
        speed = 7,
        acceleration = 5,
        description = 'Missouri Fox Trotters are smooth-gaiting multi-class race and work horses. Renowned for their incredible speed and stamina, they are built to cover vast distances effortlessly.'
    },
    {
        model = `a_c_horse_missourifoxtrotter_dapplegrey`,
        label = 'Missouri Fox Trotter (Dapple Gray)',
        class = 'Multi-Class Race/Work',
        breed = 'missourifoxtrotter',
        price = 500,
        handling = 'Standard',
        health = 5,
        stamina = 6,
        speed = 6,
        acceleration = 5,
        description = 'Missouri Fox Trotters are smooth-gaiting multi-class race and work horses. Renowned for their incredible speed and stamina, they are built to cover vast distances effortlessly.'
    },
    {
        model = `a_c_horse_missourifoxtrotter_sablechampagne`,
        label = 'Missouri Fox Trotter (Sable Champagne)',
        class = 'Multi-Class Race/Work',
        breed = 'missourifoxtrotter',
        price = 950,
        handling = 'Standard',
        health = 5,
        stamina = 6,
        speed = 6,
        acceleration = 5,
        description = 'Missouri Fox Trotters are smooth-gaiting multi-class race and work horses. Renowned for their incredible speed and stamina, they are built to cover vast distances effortlessly.'
    },
    {
        model = `a_c_horse_missourifoxtrotter_silverdapplepinto`,
        label = 'Missouri Fox Trotter (Silver Dapple Pinto)',
        class = 'Multi-Class Race/Work',
        breed = 'missourifoxtrotter',
        price = 500,
        handling = 'Standard',
        health = 5,
        stamina = 6,
        speed = 6,
        acceleration = 5,
        description = 'Missouri Fox Trotters are smooth-gaiting multi-class race and work horses. Renowned for their incredible speed and stamina, they are built to cover vast distances effortlessly.'
    },
    {
        model = `a_c_horse_morgan_bay`,
        label = 'Morgan (Bay)',
        class = 'Riding Horse',
        breed = 'morgan',
        price = 15,
        handling = 'Standard',
        health = 2,
        stamina = 3,
        speed = 3,
        acceleration = 2,
        description = 'Morgans are compact riding horses with a refined build and docile temperament. While their health and stamina are modest, they make dependable companions for shorter journeys.'
    },
    {
        model = `a_c_horse_morgan_bayroan`,
        label = 'Morgan (Bay Roan)',
        class = 'Riding Horse',
        breed = 'morgan',
        price = 55,
        handling = 'Standard',
        health = 2,
        stamina = 3,
        speed = 3,
        acceleration = 2,
        description = 'Morgans are compact riding horses with a refined build and docile temperament. While their health and stamina are modest, they make dependable companions for shorter journeys.'
    },
    {
        model = `a_c_horse_morgan_flaxenchestnut`,
        label = 'Morgan (Flaxen Chestnut)',
        class = 'Riding Horse',
        breed = 'morgan',
        price = 55,
        handling = 'Standard',
        health = 2,
        stamina = 3,
        speed = 3,
        acceleration = 2,
        description = 'Morgans are compact riding horses with a refined build and docile temperament. While their health and stamina are modest, they make dependable companions for shorter journeys.'
    },
    {
        model = `a_c_horse_morgan_liverchestnut_pc`,
        label = 'Morgan (Liver Chestnut)',
        class = 'Riding Horse',
        breed = 'morgan',
        price = 55,
        handling = 'Standard',
        health = 2,
        stamina = 4,
        speed = 4,
        acceleration = 2,
        description = 'Morgans are compact riding horses with a refined build and docile temperament. While their health and stamina are modest, they make dependable companions for shorter journeys.'
    },
    {
        model = `a_c_horse_morgan_palomino`,
        label = 'Morgan (Palomino)',
        class = 'Riding Horse',
        breed = 'morgan',
        price = 15,
        handling = 'Standard',
        health = 2,
        stamina = 3,
        speed = 3,
        acceleration = 2,
        description = 'Morgans are compact riding horses with a refined build and docile temperament. While their health and stamina are modest, they make dependable companions for shorter journeys.'
    },
    {
        model = `a_c_horse_mustang_goldendun`,
        label = 'Mustang (Golden Dun)',
        class = 'Multi-Class War/Work',
        breed = 'mustang',
        price = 500,
        handling = 'Standard',
        health = 5,
        stamina = 5,
        speed = 5,
        acceleration = 4,
        description = 'Mustangs are tough, resilient multi-class war and work horses. Exceptionally hardy and sure-footed in the wild, they possess high endurance and courage.'
    },
    {
        model = `a_c_horse_mustang_grullodun`,
        label = 'Mustang (Grullo Dun)',
        class = 'Multi-Class War/Work',
        breed = 'mustang',
        price = 500,
        handling = 'Standard',
        health = 4,
        stamina = 4,
        speed = 3,
        acceleration = 2,
        description = 'Mustangs are tough, resilient multi-class war and work horses. Exceptionally hardy and sure-footed in the wild, they possess high endurance and courage.'
    },
    {
        model = `a_c_horse_mustang_reddunovero`,
        label = 'Mustang (Red Dun Overo)',
        class = 'Multi-Class War/Work',
        breed = 'mustang',
        price = 500,
        handling = 'Standard',
        health = 5,
        stamina = 5,
        speed = 5,
        acceleration = 4,
        description = 'Mustangs are tough, resilient multi-class war and work horses. Exceptionally hardy and sure-footed in the wild, they possess high endurance and courage.'
    },
    {
        model = `a_c_horse_mustang_tigerstripedbay`,
        label = 'Mustang (Tiger Striped Bay)',
        class = 'Multi-Class War/Work',
        breed = 'mustang',
        price = 500,
        handling = 'Standard',
        health = 5,
        stamina = 5,
        speed = 4,
        acceleration = 3,
        description = 'Mustangs are tough, resilient multi-class war and work horses. Exceptionally hardy and sure-footed in the wild, they possess high endurance and courage.'
    },
    {
        model = `a_c_horse_mustang_wildbay`,
        label = 'Mustang (Wild Bay)',
        class = 'Multi-Class War/Work',
        breed = 'mustang',
        price = 150,
        handling = 'Standard',
        health = 4,
        stamina = 4,
        speed = 3,
        acceleration = 2,
        description = 'Mustangs are tough, resilient multi-class war and work horses. Exceptionally hardy and sure-footed in the wild, they possess high endurance and courage.'
    },
    {
        model = `a_c_horse_nokota_blueroan`,
        label = 'Nokota (Blue Roan)',
        class = 'Race Horse',
        breed = 'nokota',
        price = 130,
        handling = 'Race',
        health = 3,
        stamina = 3,
        speed = 4,
        acceleration = 3,
        description = 'Nokotas are agile race horses with slender, sturdy frames. Known for their speed and responsiveness, they thrive when pushed on racing tracks and open plains.'
    },
    {
        model = `a_c_horse_nokota_reversedappleroan`,
        label = 'Nokota (Reverse Dapple Roan)',
        class = 'Race Horse',
        breed = 'nokota',
        price = 500,
        handling = 'Race',
        health = 3,
        stamina = 3,
        speed = 7,
        acceleration = 5,
        description = 'Nokotas are agile race horses with slender, sturdy frames. Known for their speed and responsiveness, they thrive when pushed on racing tracks and open plains.'
    },
    {
        model = `a_c_horse_nokota_whiteroan`,
        label = 'Nokota (White Roan)',
        class = 'Race Horse',
        breed = 'nokota',
        price = 130,
        handling = 'Race',
        health = 3,
        stamina = 3,
        speed = 4,
        acceleration = 3,
        description = 'Nokotas are agile race horses with slender, sturdy frames. Known for their speed and responsiveness, they thrive when pushed on racing tracks and open plains.'
    },
    {
        model = `a_c_horse_norfolkroadster_piebaldroan`,
        label = 'Norfolk Roadster (Piebald Roan)',
        class = 'Race Horse',
        breed = 'norfolkroadster',
        price = 150,
        handling = 'Race',
        health = 4,
        stamina = 4,
        speed = 5,
        acceleration = 4,
        description = 'Norfolk Roadsters are swift, athletic race horses bred for speed and endurance, making them premier choices for fast travel and long-distance racing.'
    },
    {
        model = `a_c_horse_norfolkroadster_speckledgrey`,
        label = 'Norfolk Roadster (Speckled Gray)',
        class = 'Race Horse',
        breed = 'norfolkroadster',
        price = 150,
        handling = 'Race',
        health = 4,
        stamina = 4,
        speed = 5,
        acceleration = 4,
        description = 'Norfolk Roadsters are swift, athletic race horses bred for speed and endurance, making them premier choices for fast travel and long-distance racing.'
    },
    {
        model = `a_c_horse_norfolkroadster_spottedtricolor`,
        label = 'Norfolk Roadster (Spotted Tricolor)',
        class = 'Race Horse',
        breed = 'norfolkroadster',
        price = 950,
        handling = 'Race',
        health = 6,
        stamina = 7,
        speed = 7,
        acceleration = 6,
        description = 'Norfolk Roadsters are swift, athletic race horses bred for speed and endurance, making them premier choices for fast travel and long-distance racing.'
    },
    {
        model = `a_c_horse_shire_darkbay`,
        label = 'Shire (Dark Bay)',
        class = 'Draft Horse',
        breed = 'shire',
        price = 120,
        handling = 'Heavy',
        health = 4,
        stamina = 3,
        speed = 3,
        acceleration = 2,
        description = 'Shires are massive draft horses recognized by their towering height and powerful build. Gentle giants with high health, built primarily for heavy labor and pulling.'
    },
    {
        model = `a_c_horse_shire_lightgrey`,
        label = 'Shire (Light Grey)',
        class = 'Draft Horse',
        breed = 'shire',
        price = 130,
        handling = 'Heavy',
        health = 4,
        stamina = 3,
        speed = 3,
        acceleration = 2,
        description = 'Shires are massive draft horses recognized by their towering height and powerful build. Gentle giants with high health, built primarily for heavy labor and pulling.'
    },
    {
        model = `a_c_horse_shire_ravenblack`,
        label = 'Shire (Raven Black)',
        class = 'Draft Horse',
        breed = 'shire',
        price = 120,
        handling = 'Heavy',
        health = 4,
        stamina = 4,
        speed = 3,
        acceleration = 2,
        description = 'Shires are massive draft horses recognized by their towering height and powerful build. Gentle giants with high health, built primarily for heavy labor and pulling.'
    },
    {
        model = `a_c_horse_suffolkpunch_redchestnut`,
        label = 'Suffolk Punch (Red Chestnut)',
        class = 'Draft Horse',
        breed = 'suffolkpunch',
        price = 130,
        handling = 'Heavy',
        health = 3,
        stamina = 4,
        speed = 3,
        acceleration = 2,
        description = 'Suffolk Punches are sturdy draft horses characterized by a compact, muscular build and chestnut coats. Willing and hardworking, they excel at agricultural work.'
    },
    {
        model = `a_c_horse_suffolkpunch_sorrel`,
        label = 'Suffolk Punch (Sorrel)',
        class = 'Draft Horse',
        breed = 'suffolkpunch',
        price = 120,
        handling = 'Heavy',
        health = 3,
        stamina = 4,
        speed = 3,
        acceleration = 2,
        description = 'Suffolk Punches are sturdy draft horses characterized by a compact, muscular build and chestnut coats. Willing and hardworking, they excel at agricultural work.'
    },
    {
        model = `a_c_horse_tennesseewalker_blackrabicano`,
        label = 'Tennessee Walker (Black Rabicano)',
        class = 'Riding Horse',
        breed = 'tennesseewalker',
        price = 60,
        handling = 'Standard',
        health = 3,
        stamina = 3,
        speed = 2,
        acceleration = 2,
        description = 'Tennessee Walkers are riding horses renowned for their calm demeanor and smooth gaits. Healthy and reliable, they are great for gentle traveling across long distances.'
    },
    {
        model = `a_c_horse_tennesseewalker_chestnut`,
        label = 'Tennessee Walker (Chestnut)',
        class = 'Riding Horse',
        breed = 'tennesseewalker',
        price = 60,
        handling = 'Standard',
        health = 3,
        stamina = 3,
        speed = 2,
        acceleration = 2,
        description = 'Tennessee Walkers are riding horses renowned for their calm demeanor and smooth gaits. Healthy and reliable, they are great for gentle traveling across long distances.'
    },
    {
        model = `a_c_horse_tennesseewalker_dapplebay`,
        label = 'Tennessee Walker (Dapple Bay)',
        class = 'Riding Horse',
        breed = 'tennesseewalker',
        price = 60,
        handling = 'Standard',
        health = 3,
        stamina = 3,
        speed = 2,
        acceleration = 2,
        description = 'Tennessee Walkers are riding horses renowned for their calm demeanor and smooth gaits. Healthy and reliable, they are great for gentle traveling across long distances.'
    },
    {
        model = `a_c_horse_tennesseewalker_flaxenroan`,
        label = 'Tennessee Walker (Flaxen Roan)',
        class = 'Riding Horse',
        breed = 'tennesseewalker',
        price = 150,
        handling = 'Standard',
        health = 3,
        stamina = 3,
        speed = 3,
        acceleration = 2,
        description = 'Tennessee Walkers are riding horses renowned for their calm demeanor and smooth gaits. Healthy and reliable, they are great for gentle traveling across long distances.'
    },
    {
        model = `a_c_horse_tennesseewalker_goldpalomino_pc`,
        label = 'Tennessee Walker (Gold Palomino)',
        class = 'Riding Horse',
        breed = 'tennesseewalker',
        price = 60,
        handling = 'Standard',
        health = 3,
        stamina = 3,
        speed = 3,
        acceleration = 2,
        description = 'Tennessee Walkers are riding horses renowned for their calm demeanor and smooth gaits. Healthy and reliable, they are great for gentle traveling across long distances.'
    },
    {
        model = `a_c_horse_tennesseewalker_mahoganybay`,
        label = 'Tennessee Walker (Mahogany Bay)',
        class = 'Riding Horse',
        breed = 'tennesseewalker',
        price = 60,
        handling = 'Standard',
        health = 3,
        stamina = 4,
        speed = 2,
        acceleration = 2,
        description = 'Tennessee Walkers are riding horses renowned for their calm demeanor and smooth gaits. Healthy and reliable, they are great for gentle traveling across long distances.'
    },
    {
        model = `a_c_horse_tennesseewalker_redroan`,
        label = 'Tennessee Walker (Red Roan)',
        class = 'Riding Horse',
        breed = 'tennesseewalker',
        price = 60,
        handling = 'Standard',
        health = 3,
        stamina = 3,
        speed = 2,
        acceleration = 2,
        description = 'Tennessee Walkers are riding horses renowned for their calm demeanor and smooth gaits. Healthy and reliable, they are great for gentle traveling across long distances.'
    },
    {
        model = `a_c_horse_thoroughbred_blackchestnut`,
        label = 'Thoroughbred (Black Chestnut)',
        class = 'Race Horse',
        breed = 'thoroughbred',
        price = 130,
        handling = 'Race',
        health = 3,
        stamina = 3,
        speed = 5,
        acceleration = 4,
        description = 'Thoroughbreds are elite race horses recognized by their lean legs, deep chest, and athletic build. Famous for exceptional speed and agility.'
    },
    {
        model = `a_c_horse_thoroughbred_bloodbay`,
        label = 'Thoroughbred (Blood Bay)',
        class = 'Race Horse',
        breed = 'thoroughbred',
        price = 130,
        handling = 'Race',
        health = 3,
        stamina = 3,
        speed = 4,
        acceleration = 3,
        description = 'Thoroughbreds are elite race horses recognized by their lean legs, deep chest, and athletic build. Famous for exceptional speed and agility.'
    },
    {
        model = `a_c_horse_thoroughbred_brindle`,
        label = 'Thoroughbred (Brindle)',
        class = 'Race Horse',
        breed = 'thoroughbred',
        price = 450,
        handling = 'Race',
        health = 3,
        stamina = 4,
        speed = 7,
        acceleration = 5,
        description = 'Thoroughbreds are elite race horses recognized by their lean legs, deep chest, and athletic build. Famous for exceptional speed and agility.'
    },
    {
        model = `a_c_horse_thoroughbred_dapplegrey`,
        label = 'Thoroughbred (Dapple Grey)',
        class = 'Race Horse',
        breed = 'thoroughbred',
        price = 130,
        handling = 'Race',
        health = 3,
        stamina = 3,
        speed = 4,
        acceleration = 3,
        description = 'Thoroughbreds are elite race horses recognized by their lean legs, deep chest, and athletic build. Famous for exceptional speed and agility.'
    },
    {
        model = `a_c_horse_thoroughbred_reversedappleblack`,
        label = 'Thoroughbred (Reverse Dapple Black)',
        class = 'Race Horse',
        breed = 'thoroughbred',
        price = 500,
        handling = 'Race',
        health = 4,
        stamina = 4,
        speed = 5,
        acceleration = 5,
        description = 'Thoroughbreds are elite race horses recognized by their lean legs, deep chest, and athletic build. Famous for exceptional speed and agility.'
    },
    {
        model = `a_c_horse_turkoman_darkbay`,
        label = 'Turkoman (Dark Bay)',
        class = 'Multi-Class War/Race',
        breed = 'turkoman',
        price = 925,
        handling = 'Standard',
        health = 7,
        stamina = 5,
        speed = 6,
        acceleration = 5,
        description = 'Turkomans are multi-class war and race horses combining slender builds with high endurance, top-tier speed, and sturdy health.'
    },
    {
        model = `a_c_horse_turkoman_gold`,
        label = 'Turkoman (Gold)',
        class = 'Multi-Class War/Race',
        breed = 'turkoman',
        price = 950,
        handling = 'Standard',
        health = 7,
        stamina = 5,
        speed = 6,
        acceleration = 5,
        description = 'Turkomans are multi-class war and race horses combining slender builds with high endurance, top-tier speed, and sturdy health.'
    },
    {
        model = `a_c_horse_turkoman_silver`,
        label = 'Turkoman (Silver)',
        class = 'Multi-Class War/Race',
        breed = 'turkoman',
        price = 950,
        handling = 'Standard',
        health = 7,
        stamina = 5,
        speed = 6,
        acceleration = 5,
        description = 'Turkomans are multi-class war and race horses combining slender builds with high endurance, top-tier speed, and sturdy health.'
    }
}

-- ===================== HORSE TACK / CUSTOMIZATION =====================
-- Lets players fit their horse with separate saddle, blanket, saddlebags, horn, stirrups,
Config.Tack = {
    enabled = true, -- set false to hide "Customize Tack" entirely
}

-- Horse coat colours (custom tint system, adapted from rsg-horses)
-- tint0 = main coat (0-254), tint1 = markings (0-255, 255 = none), tint2 = nose (0-255, 255 = default)
-- mane / tail = 0-254. Applied with SetMetaPedTag on the metaped_tint_horse palette.
Config.Coat = {
    enabled = true, -- set false to hide "Customize Coat"
    price   = 100,  -- flat fee whenever any colour changes (restoring the natural coat is free)
    presets = {     -- quick-pick main coat colours shown in the editor
        { label = 'White',        tint0 = 0 },
        { label = 'Black',        tint0 = 9 },
        { label = 'Brown',        tint0 = 40 },
        { label = 'Bay',          tint0 = 100 },
        { label = 'Chestnut Red', tint0 = 127 },
        { label = 'Silver',       tint0 = 128 },
        { label = 'Grey',         tint0 = 130 },
        { label = 'Bronze',       tint0 = 121 },
        { label = 'Blood Red',    tint0 = 125 },
        { label = 'Orange',       tint0 = 120 },
        { label = 'Yellow',       tint0 = 119 },
        { label = 'Lime',         tint0 = 115 },
        { label = 'Green',        tint0 = 112 },
        { label = 'Dark Green',   tint0 = 109 },
        { label = 'Blue',         tint0 = 110 },
        { label = 'Purple',       tint0 = 105 },
        { label = 'Pink',         tint0 = 107 },
        { label = 'Lilac',        tint0 = 108 },
    },
}

-- frontend sound played when cycling tack styles in the customisation menu
Config.TackSounds = {
    enabled  = true,
    soundset = 'PAUSE_MENU_SOUNDSET',
    left     = 'NAV_LEFT',
    right    = 'NAV_RIGHT',
}

Config.TackCategories = {
    { key = 'blanket',    label = 'Blanket' },
    { key = 'saddle',     label = 'Saddle' },
    { key = 'saddlebags', label = 'Saddlebags' },
    { key = 'horn',       label = 'Saddle Horn' },
    { key = 'stirrups',   label = 'Stirrups' },
    { key = 'bedroll',    label = 'Bedroll' },
    { key = 'tail',       label = 'Tail' },
    { key = 'mane',       label = 'Mane' },
    { key = 'mask',       label = 'Mask' },
    { key = 'mustache',   label = 'Mustache' },
    { key = 'holster',    label = 'Holster', required = true }, -- required = a style must be fitted (no 'None'); the holster is needed to carry weapons on the horse
    { key = 'bridle',     label = 'Bridle' },
    { key = 'horseshoe',  label = 'Horseshoes' },
}
Config.TackItems = {
    saddle = { -- category_hash 0xBAA7E618
        { label = 'Saddle Style 1', hash = 0xAD4A6355, price = 25, verified = true }, -- hashid 1
        { label = 'Saddle Style 2', hash = 0x8FFCF06B, price = 25, verified = true }, -- hashid 2
        { label = 'Saddle Style 3', hash = 0x5546EB7A, price = 30, verified = true }, -- hashid 3
        { label = 'Saddle Style 4', hash = 0x8E64DDB5, price = 30, verified = true }, -- hashid 4
        { label = 'Saddle Style 5', hash = 0x7092A211, price = 40, verified = true, bonus = { stamina = 2, speed = 1 } }, -- hashid 5
        { label = 'Saddle Style 6', hash = 0xC0C04297, price = 20, verified = true }, -- hashid 6
        { label = 'Saddle Style 7', hash = 0xBE703DF7, price = 20, verified = true }, -- hashid 7
        { label = 'Saddle Style 8', hash = 0xE5510BB8, price = 20, verified = true }, -- hashid 8
        { label = 'Saddle Style 9', hash = 0x7D795D72, price = 20, verified = true }, -- hashid 9
        { label = 'Saddle Style 10', hash = 0x0522CCED, price = 20, verified = true }, -- hashid 10
        { label = 'Saddle Style 11', hash = 0x5B45F932, price = 20, verified = true }, -- hashid 11
        { label = 'Saddle Style 12', hash = 0x219D85E2, price = 20, verified = true }, -- hashid 12
        { label = 'Saddle Style 13', hash = 0x7DBB3E1C, price = 20, verified = true }, -- hashid 13
        { label = 'Saddle Style 14', hash = 0x4C1A5ADB, price = 20, verified = true }, -- hashid 14
        { label = 'Saddle Style 15', hash = 0xF1BAA60D, price = 20, verified = true }, -- hashid 15
        { label = 'Saddle Style 16', hash = 0xE6488B58, price = 20, verified = true }, -- hashid 16
        { label = 'Saddle Style 17', hash = 0xD2FA64BC, price = 20, verified = true }, -- hashid 17
        { label = 'Saddle Style 18', hash = 0x189F7005, price = 20, verified = true }, -- hashid 18
        { label = 'Saddle Style 19', hash = 0xF7682D97, price = 20, verified = true }, -- hashid 19
        { label = 'Saddle Style 20', hash = 0x1D0BF8F2, price = 20, verified = true }, -- hashid 20
        { label = 'Saddle Style 21', hash = 0x0A39D34E, price = 20, verified = true }, -- hashid 21
        { label = 'Saddle Style 22', hash = 0xBFD09512, price = 20, verified = true }, -- hashid 22
        { label = 'Saddle Style 23', hash = 0x17153A45, price = 20, verified = true }, -- hashid 23
        { label = 'Saddle Style 24', hash = 0x05D717C9, price = 20, verified = true }, -- hashid 24
        { label = 'Saddle Style 25', hash = 0x4B372288, price = 20, verified = true }, -- hashid 25
        { label = 'Saddle Style 26', hash = 0x78F07DFA, price = 20, verified = true }, -- hashid 26
        { label = 'Saddle Style 27', hash = 0x2E4668A3, price = 20, verified = true }, -- hashid 27
        { label = 'Saddle Style 28', hash = 0x1C14443F, price = 20, verified = true }, -- hashid 28
        { label = 'Saddle Style 29', hash = 0x353FC03C, price = 20, verified = true }, -- hashid 29
        { label = 'Saddle Style 30', hash = 0xD97573C1, price = 20, verified = true }, -- hashid 30
        { label = 'Saddle Style 31', hash = 0xF3BEA853, price = 20, verified = true }, -- hashid 31
        { label = 'Saddle Style 32', hash = 0x01F7C4C5, price = 20, verified = true }, -- hashid 32
        { label = 'Saddle Style 33', hash = 0x106961A8, price = 20, verified = true }, -- hashid 33
        { label = 'Saddle Style 34', hash = 0x2ECD9E70, price = 20, verified = true }, -- hashid 34
        { label = 'Saddle Style 35', hash = 0x3D0C3AED, price = 20, verified = true }, -- hashid 35
        { label = 'Saddle Style 36', hash = 0xF94D5623, price = 20, verified = true }, -- hashid 36
        { label = 'Saddle Style 37', hash = 0x3F9F62CE, price = 20, verified = true }, -- hashid 37
        { label = 'Saddle Style 38', hash = 0x150D0DAA, price = 20, verified = true }, -- hashid 38
        { label = 'Saddle Style 39', hash = 0xEB1139AB, price = 20, verified = true }, -- hashid 39
        { label = 'Saddle Style 40', hash = 0xC04FE429, price = 20, verified = true }, -- hashid 40
        { label = 'Saddle Style 41', hash = 0x0DE47F51, price = 20, verified = true }, -- hashid 41
        { label = 'Saddle Style 42', hash = 0x5BBC54C3, price = 20, verified = true }, -- hashid 42
        { label = 'Saddle Style 43', hash = 0x8D163776, price = 20, verified = true }, -- hashid 43
        { label = 'Saddle Style 44', hash = 0x3E949A74, price = 20, verified = true }, -- hashid 44
        { label = 'Saddle Style 45', hash = 0x70BB7EC1, price = 20, verified = true }, -- hashid 45
        { label = 'Saddle Style 46', hash = 0xD11CBF82, price = 20, verified = true }, -- hashid 46
        { label = 'Saddle Style 47', hash = 0xBA6A921E, price = 20, verified = true }, -- hashid 47
        { label = 'Saddle Style 48', hash = 0xD225CCA0, price = 20, verified = true }, -- hashid 48
        { label = 'Saddle Style 49', hash = 0x6D403492, price = 20, verified = true }, -- hashid 49
        { label = 'Saddle Style 50', hash = 0xBB335077, price = 20, verified = true }, -- hashid 50
        { label = 'Saddle Style 51', hash = 0x8D9D754C, price = 20, verified = true }, -- hashid 51
        { label = 'Saddle Style 52', hash = 0x5B6390D9, price = 20, verified = true }, -- hashid 52
        { label = 'Saddle Style 53', hash = 0x14168240, price = 20, verified = true }, -- hashid 53
        { label = 'Saddle Style 54', hash = 0x7FD859C2, price = 20, verified = true }, -- hashid 54
        { label = 'Saddle Style 55', hash = 0x87F421F7, price = 20, verified = true }, -- hashid 55
        { label = 'Saddle Style 56', hash = 0xC1AF1568, price = 20, verified = true }, -- hashid 56
        { label = 'Saddle Style 57', hash = 0xF36A78DE, price = 20, verified = true }, -- hashid 57
        { label = 'Saddle Style 58', hash = 0x9CD94BC1, price = 20, verified = true }, -- hashid 58
        { label = 'Saddle Style 59', hash = 0xCE8C2F22, price = 20, verified = true }, -- hashid 59
        { label = 'Saddle Style 60', hash = 0x2844E292, price = 20, verified = true }, -- hashid 60
        { label = 'Saddle Style 61', hash = 0xC10B5450, price = 20, verified = true }, -- hashid 61
        { label = 'Saddle Style 62', hash = 0xD2C8F7CB, price = 20, verified = true }, -- hashid 62
        { label = 'Saddle Style 63', hash = 0xE5B31D9F, price = 20, verified = true }, -- hashid 63
        { label = 'Saddle Style 64', hash = 0xF373B920, price = 20, verified = true }, -- hashid 64
        { label = 'Saddle Style 65', hash = 0x7A23C686, price = 20, verified = true }, -- hashid 65
        { label = 'Saddle Style 66', hash = 0x88C363C5, price = 20, verified = true }, -- hashid 66
        { label = 'Saddle Style 67', hash = 0xB5802A5F, price = 20, verified = true }, -- hashid 67
        { label = 'Saddle Style 68', hash = 0x7C2C580C, price = 20, verified = true }, -- hashid 68
        { label = 'Saddle Style 69', hash = 0x6FEABF89, price = 20, verified = true }, -- hashid 69
        { label = 'Saddle Style 70', hash = 0xA21923E5, price = 20, verified = true }, -- hashid 70
        { label = 'Saddle Style 71', hash = 0x93DA8768, price = 20, verified = true }, -- hashid 71
        { label = 'Saddle Style 72', hash = 0xA8DB3175, price = 20, verified = true }, -- hashid 72
        { label = 'Saddle Style 73', hash = 0x9B1C95F8, price = 20, verified = true }, -- hashid 73
        { label = 'Saddle Style 74', hash = 0x7C19770A, price = 20, verified = true }, -- hashid 74
        { label = 'Saddle Style 75', hash = 0xA1154105, price = 20, verified = true }, -- hashid 75
        { label = 'Saddle Style 76', hash = 0xB357E58A, price = 20, verified = true }, -- hashid 76
        { label = 'Saddle Style 77', hash = 0x8DD09A7C, price = 20, verified = true }, -- hashid 77
        { label = 'Saddle Style 78', hash = 0x9FF23EBF, price = 20, verified = true }, -- hashid 78
        { label = 'Saddle Style 79', hash = 0xFC6AF7AF, price = 20, verified = true }, -- hashid 79
        { label = 'Saddle Style 80', hash = 0xB9BE555D, price = 20, verified = true }, -- hashid 80
        { label = 'Saddle Style 81', hash = 0x01EC65C0, price = 20, verified = true }, -- hashid 81
        { label = 'Saddle Style 82', hash = 0x0F2F0045, price = 20, verified = true }, -- hashid 82
        { label = 'Saddle Style 83', hash = 0xE52BAC3F, price = 20, verified = true }, -- hashid 83
        { label = 'Saddle Style 84', hash = 0xF4B14B4A, price = 20, verified = true }, -- hashid 84
        { label = 'Saddle Style 85', hash = 0x3827D232, price = 20, verified = true }, -- hashid 85
        { label = 'Saddle Style 86', hash = 0xDE5A2905, price = 20, verified = true }, -- hashid 86
        { label = 'Saddle Style 87', hash = 0xEC882931, price = 20, verified = true }, -- hashid 87
        { label = 'Saddle Style 88', hash = 0xDA36048D, price = 20, verified = true }, -- hashid 88
        { label = 'Saddle Style 89', hash = 0xC7FC601A, price = 20, verified = true }, -- hashid 89
        { label = 'Saddle Style 90', hash = 0xB7B33F88, price = 20, verified = true }, -- hashid 90
        { label = 'Saddle Style 91', hash = 0xA7AC9F7B, price = 20, verified = true }, -- hashid 91
        { label = 'Saddle Style 92', hash = 0x9533FA8E, price = 20, verified = true }, -- hashid 92
        { label = 'Saddle Style 93', hash = 0xE039FC0F, price = 20, verified = true }, -- hashid 93
        { label = 'Saddle Style 94', hash = 0xF687A8AA, price = 20, verified = true }, -- hashid 94
        { label = 'Saddle Style 95', hash = 0x47D2CB3F, price = 20, verified = true }, -- hashid 95
        { label = 'Saddle Style 96', hash = 0x15FB6791, price = 20, verified = true }, -- hashid 96
        { label = 'Saddle Style 97', hash = 0xE36C8274, price = 20, verified = true }, -- hashid 97
        { label = 'Saddle Style 98', hash = 0x40C53D24, price = 20, verified = true }, -- hashid 98
        { label = 'Saddle Style 99', hash = 0x64CEC6DF, price = 20, verified = true }, -- hashid 99
        { label = 'Saddle Style 100', hash = 0x9E0C3959, price = 20, verified = true }, -- hashid 100
        { label = 'Saddle Style 101', hash = 0x90489DD2, price = 20, verified = true }, -- hashid 101
        { label = 'Saddle Style 102', hash = 0xBC52F5E6, price = 20, verified = true }, -- hashid 102
        { label = 'Saddle Style 103', hash = 0xD61B2996, price = 20, verified = true }, -- hashid 103
        { label = 'Saddle Style 104', hash = 0xC7D58D0B, price = 20, verified = true }, -- hashid 104
        { label = 'Saddle Style 105', hash = 0x2BEA8ED4, price = 20, verified = true }, -- hashid 105
        { label = 'Saddle Style 106', hash = 0x8DABACD7, price = 20, verified = true }, -- hashid 106
        { label = 'Saddle Style 107', hash = 0x6384D886, price = 20, verified = true }, -- hashid 107
        { label = 'Saddle Style 108', hash = 0x694DE418, price = 20, verified = true }, -- hashid 108
        { label = 'Saddle Style 109', hash = 0x60DE5335, price = 20, verified = true }, -- hashid 109
        { label = 'Saddle Style 110', hash = 0x76887E89, price = 20, verified = true }, -- hashid 110
        { label = 'Saddle Style 111', hash = 0x2E216DBC, price = 20, verified = true }, -- hashid 111
        { label = 'Saddle Style 112', hash = 0x5A9E4F6C, price = 20, verified = true }, -- hashid 112
        { label = 'Saddle Style 113', hash = 0x2F8C7941, price = 20, verified = true }, -- hashid 113
        { label = 'Saddle Style 114', hash = 0xFD4E14C5, price = 20, verified = true }, -- hashid 114
        { label = 'Saddle Style 115', hash = 0xB61F0668, price = 20, verified = true }, -- hashid 115
        { label = 'Saddle Style 116', hash = 0x21E8DDFA, price = 20, verified = true }, -- hashid 116
        { label = 'Saddle Style 117', hash = 0xDA84CF33, price = 20, verified = true }, -- hashid 117
        { label = 'Saddle Style 118', hash = 0xC454830C, price = 20, verified = true }, -- hashid 118
        { label = 'Saddle Style 119', hash = 0xD6BF27E1, price = 20, verified = true }, -- hashid 119
        { label = 'Saddle Style 120', hash = 0x24F24446, price = 20, verified = true }, -- hashid 120
        { label = 'Saddle Style 121', hash = 0x0F4118E4, price = 20, verified = true }, -- hashid 121
        { label = 'Saddle Style 122', hash = 0x0306806F, price = 20, verified = true }, -- hashid 122
        { label = 'Saddle Style 123', hash = 0x70C65BED, price = 20, verified = true }, -- hashid 123
        { label = 'Saddle Style 124', hash = 0xC76C46D9, price = 20, verified = true }, -- hashid 124
        { label = 'Saddle Style 125', hash = 0x2E3F3A62, price = 20, verified = true }, -- hashid 125
        { label = 'Saddle Style 126', hash = 0x660B29F9, price = 20, verified = true }, -- hashid 126
        { label = 'Saddle Style 127', hash = 0x335DC49F, price = 20, verified = true }, -- hashid 127
        { label = 'Saddle Style 128', hash = 0xFCE1D7A4, price = 20, verified = true }, -- hashid 128
        { label = 'Saddle Style 129', hash = 0x093B7057, price = 20, verified = true }, -- hashid 129
        { label = 'Saddle Style 130', hash = 0x20359E53, price = 20, verified = true }, -- hashid 130
        { label = 'Saddle Style 131', hash = 0x534A7D59, price = 20, verified = true }, -- hashid 131
        { label = 'Saddle Style 132', hash = 0xD7FC86BF, price = 20, verified = true }, -- hashid 132
        { label = 'Saddle Style 133', hash = 0xE9B7AA35, price = 20, verified = true }, -- hashid 133
        { label = 'Saddle Style 134', hash = 0x6C622F8C, price = 20, verified = true }, -- hashid 134
        { label = 'Saddle Style 135', hash = 0x8E22730C, price = 20, verified = true }, -- hashid 135
        { label = 'Saddle Style 136', hash = 0x1EE21489, price = 20, verified = true }, -- hashid 136
        { label = 'Saddle Style 137', hash = 0xBCBE0337, price = 20, verified = true }, -- hashid 137
        { label = 'Saddle Style 138', hash = 0x4BC19FC4, price = 20, verified = true }, -- hashid 138
    },
    blanket = { -- category_hash 0x17CEB41A
        { label = 'Blanket Style 1', hash = 0x0FAE487F, price = 10, verified = true }, -- hashid 1
        { label = 'Blanket Style 2', hash = 0x2286EE30, price = 10, verified = true }, -- hashid 2
        { label = 'Blanket Style 3', hash = 0x41D52CD8, price = 12, verified = true }, -- hashid 3
        { label = 'Blanket Style 4', hash = 0xC4C732B2, price = 8, verified = true }, -- hashid 4
        { label = 'Blanket Style 5', hash = 0xFDF4250B, price = 15, verified = true }, -- hashid 5
        { label = 'Blanket Style 6', hash = 0x508B80B9, price = 10, verified = true }, -- hashid 6
        { label = 'Blanket Style 7', hash = 0x67CAAF37, price = 8, verified = true }, -- hashid 7
        { label = 'Blanket Style 8', hash = 0xEBB4B70D, price = 8, verified = true }, -- hashid 8
        { label = 'Blanket Style 9', hash = 0xFA1153C6, price = 8, verified = true }, -- hashid 9
        { label = 'Blanket Style 10', hash = 0x0F537E4A, price = 8, verified = true }, -- hashid 10
        { label = 'Blanket Style 11', hash = 0x97EBE669, price = 8, verified = true }, -- hashid 11
        { label = 'Blanket Style 12', hash = 0x269583CA, price = 8, verified = true }, -- hashid 12
        { label = 'Blanket Style 13', hash = 0x3973A986, price = 8, verified = true }, -- hashid 13
        { label = 'Blanket Style 14', hash = 0x4A294AF1, price = 8, verified = true }, -- hashid 14
        { label = 'Blanket Style 15', hash = 0xED0190A3, price = 8, verified = true }, -- hashid 15
        { label = 'Blanket Style 16', hash = 0xBBF05395, price = 8, verified = true }, -- hashid 16
        { label = 'Blanket Style 17', hash = 0x823A602A, price = 8, verified = true }, -- hashid 17
        { label = 'Blanket Style 18', hash = 0x533A022A, price = 8, verified = true }, -- hashid 18
        { label = 'Blanket Style 19', hash = 0xB0F7BDA4, price = 8, verified = true }, -- hashid 19
        { label = 'Blanket Style 20', hash = 0xFDC3D6D3, price = 8, verified = true }, -- hashid 20
        { label = 'Blanket Style 21', hash = 0x6B2084E5, price = 8, verified = true }, -- hashid 21
        { label = 'Blanket Style 22', hash = 0x78FB209A, price = 8, verified = true }, -- hashid 22
        { label = 'Blanket Style 23', hash = 0x8FAD4DFE, price = 8, verified = true }, -- hashid 23
        { label = 'Blanket Style 24', hash = 0x9DE0EA65, price = 8, verified = true }, -- hashid 24
        { label = 'Blanket Style 25', hash = 0x342916F3, price = 8, verified = true }, -- hashid 25
        { label = 'Blanket Style 26', hash = 0xAD283105, price = 8, verified = true }, -- hashid 26
        { label = 'Blanket Style 27', hash = 0xC2EF5C93, price = 8, verified = true }, -- hashid 27
        { label = 'Blanket Style 28', hash = 0xC8A467FD, price = 8, verified = true }, -- hashid 28
        { label = 'Blanket Style 29', hash = 0x4655E362, price = 8, verified = true }, -- hashid 29
        { label = 'Blanket Style 30', hash = 0xDBEF0E96, price = 8, verified = true }, -- hashid 30
        { label = 'Blanket Style 31', hash = 0x7951D487, price = 8, verified = true }, -- hashid 31
        { label = 'Blanket Style 32', hash = 0xC073E2CA, price = 8, verified = true }, -- hashid 32
        { label = 'Blanket Style 33', hash = 0xEDCB3D78, price = 8, verified = true }, -- hashid 33
        { label = 'Blanket Style 34', hash = 0xA3D5298D, price = 8, verified = true }, -- hashid 34
        { label = 'Blanket Style 35', hash = 0xB19B4519, price = 8, verified = true }, -- hashid 35
        { label = 'Blanket Style 36', hash = 0xCDD2FB96, price = 8, verified = true }, -- hashid 36
        { label = 'Blanket Style 37', hash = 0xC097E12C, price = 8, verified = true }, -- hashid 37
        { label = 'Blanket Style 38', hash = 0xD333865B, price = 8, verified = true }, -- hashid 38
        { label = 'Blanket Style 39', hash = 0xE409A807, price = 8, verified = true }, -- hashid 39
        { label = 'Blanket Style 40', hash = 0xF6484C84, price = 8, verified = true }, -- hashid 40
        { label = 'Blanket Style 41', hash = 0xEC040C89, price = 8, verified = true }, -- hashid 41
        { label = 'Blanket Style 42', hash = 0x19C5E80C, price = 8, verified = true }, -- hashid 42
        { label = 'Blanket Style 43', hash = 0x64BE7DF8, price = 8, verified = true }, -- hashid 43
        { label = 'Blanket Style 44', hash = 0x3278996D, price = 8, verified = true }, -- hashid 44
        { label = 'Blanket Style 45', hash = 0x003D34F3, price = 8, verified = true }, -- hashid 45
        { label = 'Blanket Style 46', hash = 0x3BA0D76D, price = 8, verified = true }, -- hashid 46
        { label = 'Blanket Style 47', hash = 0x4BF1F80F, price = 8, verified = true }, -- hashid 47
        { label = 'Blanket Style 48', hash = 0x5F0F9E4A, price = 8, verified = true }, -- hashid 48
        { label = 'Blanket Style 49', hash = 0x71DFC3EA, price = 8, verified = true }, -- hashid 49
        { label = 'Blanket Style 50', hash = 0xF506CA32, price = 8, verified = true }, -- hashid 50
        { label = 'Blanket Style 51', hash = 0x2A6D33E8, price = 8, verified = true }, -- hashid 51
        { label = 'Blanket Style 52', hash = 0xFFB1DE72, price = 8, verified = true }, -- hashid 52
        { label = 'Blanket Style 53', hash = 0x0DC87A9F, price = 8, verified = true }, -- hashid 53
        { label = 'Blanket Style 54', hash = 0x20D4A0BF, price = 8, verified = true }, -- hashid 54
        { label = 'Blanket Style 55', hash = 0x127E0412, price = 8, verified = true }, -- hashid 55
        { label = 'Blanket Style 56', hash = 0xE32A1050, price = 8, verified = true }, -- hashid 56
        { label = 'Blanket Style 57', hash = 0x5894FB24, price = 8, verified = true }, -- hashid 57
        { label = 'Blanket Style 58', hash = 0xD9E17DBB, price = 8, verified = true }, -- hashid 58
        { label = 'Blanket Style 59', hash = 0xAB302059, price = 8, verified = true }, -- hashid 59
        { label = 'Blanket Style 60', hash = 0x9E468686, price = 8, verified = true }, -- hashid 60
        { label = 'Blanket Style 61', hash = 0x90A31F96, price = 8, verified = true }, -- hashid 61
        { label = 'Blanket Style 62', hash = 0x9AD633FC, price = 8, verified = true }, -- hashid 62
        { label = 'Blanket Style 63', hash = 0x53B325B7, price = 8, verified = true }, -- hashid 63
        { label = 'Blanket Style 64', hash = 0x7D637917, price = 8, verified = true }, -- hashid 64
        { label = 'Blanket Style 65', hash = 0xC7688D20, price = 8, verified = true }, -- hashid 65
    },
    saddlebags = { -- category_hash 0x80451C25
        { label = 'Saddlebags Style 1', hash = 0x5277E9BA, price = 20, verified = true }, -- hashid 1
        { label = 'Saddlebags Style 2', hash = 0x20AA8620, price = 20, verified = true }, -- hashid 2
        { label = 'Saddlebags Style 3', hash = 0x577EF434, price = 25, verified = true }, -- hashid 3
        { label = 'Saddlebags Style 4', hash = 0x293E17B3, price = 15, verified = true }, -- hashid 4
        { label = 'Saddlebags Style 5', hash = 0xE4108D59, price = 15, verified = true }, -- hashid 5
        { label = 'Saddlebags Style 6', hash = 0xC019F804, price = 15, verified = true }, -- hashid 6
        { label = 'Saddlebags Style 7', hash = 0x8BE10F93, price = 15, verified = true }, -- hashid 7
        { label = 'Saddlebags Style 8', hash = 0x9D593283, price = 15, verified = true }, -- hashid 8
        { label = 'Saddlebags Style 9', hash = 0xE57042B4, price = 15, verified = true }, -- hashid 9
        { label = 'Saddlebags Style 10', hash = 0xF8FB69CA, price = 15, verified = true }, -- hashid 10
        { label = 'Saddlebags Style 11', hash = 0xC05AA4AA, price = 15, verified = true }, -- hashid 11
        { label = 'Saddlebags Style 12', hash = 0xAE110017, price = 15, verified = true }, -- hashid 12
        { label = 'Saddlebags Style 13', hash = 0xB4F40DD9, price = 15, verified = true }, -- hashid 13
        { label = 'Saddlebags Style 14', hash = 0xE2ADE94C, price = 15, verified = true }, -- hashid 14
        { label = 'Saddlebags Style 15', hash = 0xD048C482, price = 15, verified = true }, -- hashid 15
        { label = 'Saddlebags Style 16', hash = 0xEEC77E72, price = 15, verified = true }, -- hashid 16
        { label = 'Saddlebags Style 17', hash = 0x2AEFF6CA, price = 15, verified = true }, -- hashid 17
        { label = 'Saddlebags Style 18', hash = 0x1D4EDB88, price = 15, verified = true }, -- hashid 18
        { label = 'Saddlebags Style 19', hash = 0x0E893DFD, price = 15, verified = true }, -- hashid 19
        { label = 'Saddlebags Style 20', hash = 0xF0C30271, price = 15, verified = true }, -- hashid 20
        { label = 'Saddlebags Style 21', hash = 0x162D31BD, price = 15, verified = true }, -- hashid 21
        { label = 'Saddlebags Style 22', hash = 0xD4B6AED1, price = 15, verified = true }, -- hashid 22
        { label = 'Saddlebags Style 23', hash = 0x2280CA64, price = 15, verified = true }, -- hashid 23
        { label = 'Saddlebags Style 24', hash = 0xFCC2FEE9, price = 15, verified = true }, -- hashid 24
        { label = 'Saddlebags Style 25', hash = 0xCA541A0C, price = 15, verified = true }, -- hashid 25
        { label = 'Saddlebags Style 26', hash = 0x98ECB73E, price = 15, verified = true }, -- hashid 26
        { label = 'Saddlebags Style 27', hash = 0xEBBB5CDA, price = 15, verified = true }, -- hashid 27
        { label = 'Saddlebags Style 28', hash = 0xA15F4823, price = 15, verified = true }, -- hashid 28
        { label = 'Saddlebags Style 29', hash = 0x88161591, price = 15, verified = true }, -- hashid 29
        { label = 'Saddlebags Style 30', hash = 0x3DF3014C, price = 15, verified = true }, -- hashid 30
        { label = 'Saddlebags Style 31', hash = 0x27E754ED, price = 15, verified = true }, -- hashid 31
        { label = 'Saddlebags Style 32', hash = 0x3D327F83, price = 15, verified = true }, -- hashid 32
        { label = 'Saddlebags Style 33', hash = 0xFDAB0075, price = 15, verified = true }, -- hashid 33
        { label = 'Saddlebags Style 34', hash = 0x10DBA6D6, price = 15, verified = true }, -- hashid 34
        { label = 'Saddlebags Style 35', hash = 0x61C248A2, price = 15, verified = true }, -- hashid 35
        { label = 'Saddlebags Style 36', hash = 0x745FEDDD, price = 15, verified = true }, -- hashid 36
        { label = 'Saddlebags Style 37', hash = 0x149EAC60, price = 15, verified = true }, -- hashid 37
        { label = 'Saddlebags Style 38', hash = 0xE2DFC8E3, price = 15, verified = true }, -- hashid 38
        { label = 'Saddlebags Style 39', hash = 0xF105E52F, price = 15, verified = true }, -- hashid 39
        { label = 'Saddlebags Style 40', hash = 0xBF3A0198, price = 15, verified = true }, -- hashid 40
        { label = 'Saddlebags Style 41', hash = 0xCEFD2E33, price = 15, verified = true }, -- hashid 41
        { label = 'Saddlebags Style 42', hash = 0xBB4F86D8, price = 15, verified = true }, -- hashid 42
        { label = 'Saddlebags Style 43', hash = 0xAB49E6CD, price = 15, verified = true }, -- hashid 43
        { label = 'Saddlebags Style 44', hash = 0x98BC41B2, price = 15, verified = true }, -- hashid 44
        { label = 'Saddlebags Style 45', hash = 0x867B1D30, price = 15, verified = true }, -- hashid 45
        { label = 'Saddlebags Style 46', hash = 0x3CD9F305, price = 15, verified = true }, -- hashid 46
        { label = 'Saddlebags Style 47', hash = 0x2F2C57AA, price = 15, verified = true }, -- hashid 47
        { label = 'Saddlebags Style 48', hash = 0xE08DBA6E, price = 15, verified = true }, -- hashid 48
        { label = 'Saddlebags Style 49', hash = 0xD2B91EC5, price = 15, verified = true }, -- hashid 49
        { label = 'Saddlebags Style 50', hash = 0xB433E1C3, price = 15, verified = true }, -- hashid 50
    },
    horn = { -- category_hash 0x05447332
        { label = 'Saddle Horn Style 1', hash = 0xC6C381F5, price = 12, verified = true }, -- hashid 1
        { label = 'Saddle Horn Style 2', hash = 0xDBE6AC3B, price = 12, verified = true }, -- hashid 2
        { label = 'Saddle Horn Style 3', hash = 0x2A28C8BE, price = 15, verified = true }, -- hashid 3
        { label = 'Saddle Horn Style 4', hash = 0xE1DC3856, price = 10, verified = true }, -- hashid 4
        { label = 'Saddle Horn Style 5', hash = 0x34135CC3, price = 10, verified = true }, -- hashid 5
        { label = 'Saddle Horn Style 6', hash = 0x3E40711D, price = 10, verified = true }, -- hashid 6
        { label = 'Saddle Horn Style 7', hash = 0x107D9598, price = 10, verified = true }, -- hashid 7
        { label = 'Saddle Horn Style 8', hash = 0x9AD2AA40, price = 10, verified = true }, -- hashid 8
        { label = 'Saddle Horn Style 9', hash = 0xED0BCEB5, price = 10, verified = true }, -- hashid 9
        { label = 'Saddle Horn Style 10', hash = 0xF826E4EB, price = 10, verified = true }, -- hashid 10
        { label = 'Saddle Horn Style 11', hash = 0xF8CAE723, price = 10, verified = true }, -- hashid 11
        { label = 'Saddle Horn Style 12', hash = 0xE1B1B8F1, price = 10, verified = true }, -- hashid 12
        { label = 'Saddle Horn Style 13', hash = 0x333CDC06, price = 10, verified = true }, -- hashid 13
        { label = 'Saddle Horn Style 14', hash = 0xF09C56EE, price = 10, verified = true }, -- hashid 14
    },
    stirrups = { -- category_hash 0xDA6DADCA
        { label = 'Stirrups Style 1', hash = 0x587DD49F, price = 8, verified = true }, -- hashid 1
        { label = 'Stirrups Style 2', hash = 0x67AF7302, price = 8, verified = true }, -- hashid 2
        { label = 'Stirrups Style 3', hash = 0x75178DD2, price = 10, verified = true }, -- hashid 3
        { label = 'Stirrups Style 4', hash = 0x8246282F, price = 6, verified = true }, -- hashid 4
        { label = 'Stirrups Style 5', hash = 0xCB9A3AD6, price = 6, verified = true }, -- hashid 5
        { label = 'Stirrups Style 6', hash = 0x9EE8E174, price = 6, verified = true }, -- hashid 6
        { label = 'Stirrups Style 7', hash = 0xE73FF221, price = 6, verified = true }, -- hashid 7
        { label = 'Stirrups Style 8', hash = 0xBDF19F85, price = 6, verified = true }, -- hashid 8
        { label = 'Stirrups Style 9', hash = 0x03B3AB08, price = 6, verified = true }, -- hashid 9
        { label = 'Stirrups Style 10', hash = 0xD8AE54FE, price = 6, verified = true }, -- hashid 10
        { label = 'Stirrups Style 11', hash = 0x8D0BC7DA, price = 6, verified = true }, -- hashid 11
    },
    bedroll = { -- category_hash 0xEFB31921
        { label = 'Bedroll Style 1', hash = 0x9FD99D7D, price = 10, verified = true }, -- hashid 1
        { label = 'Bedroll Style 2', hash = 0x8C9F7709, price = 10, verified = true }, -- hashid 2
        { label = 'Bedroll Style 3', hash = 0x7B55D476, price = 12, verified = true }, -- hashid 3
        { label = 'Bedroll Style 4', hash = 0xD8258E14, price = 8, verified = true }, -- hashid 4
        { label = 'Bedroll Style 5', hash = 0x0AC1F34C, price = 8, verified = true }, -- hashid 5
        { label = 'Bedroll Style 6', hash = 0x18BB6B30, price = 8, verified = true }, -- hashid 6
        { label = 'Bedroll Style 7', hash = 0x12F0DF9F, price = 8, verified = true }, -- hashid 7
        { label = 'Bedroll Style 8', hash = 0x1B43F045, price = 8, verified = true }, -- hashid 8
        { label = 'Bedroll Style 9', hash = 0x55A0E4FE, price = 8, verified = true }, -- hashid 9
        { label = 'Bedroll Style 10', hash = 0xFFB0391E, price = 8, verified = true }, -- hashid 10
        { label = 'Bedroll Style 11', hash = 0x084E5AFA, price = 8, verified = true }, -- hashid 11
        { label = 'Bedroll Style 12', hash = 0x9D868568, price = 8, verified = true }, -- hashid 12
        { label = 'Bedroll Style 13', hash = 0x72FCB059, price = 8, verified = true }, -- hashid 13
        { label = 'Bedroll Style 14', hash = 0x69B29DC5, price = 8, verified = true }, -- hashid 14
        { label = 'Bedroll Style 15', hash = 0xD258EF10, price = 8, verified = true }, -- hashid 15
        { label = 'Bedroll Style 16', hash = 0x98214B1C, price = 8, verified = true }, -- hashid 16
        { label = 'Bedroll Style 17', hash = 0x45FEA6D8, price = 8, verified = true }, -- hashid 17
        { label = 'Bedroll Style 18', hash = 0xA643680C, price = 8, verified = true }, -- hashid 18
        { label = 'Bedroll Style 19', hash = 0x7C8A149A, price = 8, verified = true }, -- hashid 19
        { label = 'Bedroll Style 20', hash = 0x8DD7B735, price = 8, verified = true }, -- hashid 20
        { label = 'Bedroll Style 21', hash = 0xA1FD8B43, price = 8, verified = true }, -- hashid 21
        { label = 'Bedroll Style 22', hash = 0xB4532FEE, price = 8, verified = true }, -- hashid 22
        { label = 'Bedroll Style 23', hash = 0xBC664014, price = 8, verified = true }, -- hashid 23
        { label = 'Bedroll Style 24', hash = 0xD020E789, price = 8, verified = true }, -- hashid 24
        { label = 'Bedroll Style 25', hash = 0x69B21ADD, price = 8, verified = true }, -- hashid 25
        { label = 'Bedroll Style 26', hash = 0x4B7E0712, price = 8, verified = true }, -- hashid 26
        { label = 'Bedroll Style 27', hash = 0x36BEDD90, price = 8, verified = true }, -- hashid 27
        { label = 'Bedroll Style 28', hash = 0x27543EBB, price = 8, verified = true }, -- hashid 28
        { label = 'Bedroll Style 29', hash = 0x841C784A, price = 8, verified = true }, -- hashid 29
        { label = 'Bedroll Style 30', hash = 0x73D157B4, price = 8, verified = true }, -- hashid 30
    },
    tail = { -- category_hash 0xA63CAE10
        { label = 'Tail Style 1', hash = 0x04951F22, price = 10, verified = true }, -- hashid 1
        { label = 'Tail Style 2', hash = 0x0607E6DD, price = 10, verified = true }, -- hashid 2
        { label = 'Tail Style 3', hash = 0x066C266F, price = 10, verified = true }, -- hashid 3
        { label = 'Tail Style 4', hash = 0x073073A2, price = 10, verified = true }, -- hashid 4
        { label = 'Tail Style 5', hash = 0x084D6B90, price = 10, verified = true }, -- hashid 5
        { label = 'Tail Style 6', hash = 0x0AFB492C, price = 10, verified = true }, -- hashid 6
        { label = 'Tail Style 7', hash = 0x12DBBBAF, price = 10, verified = true }, -- hashid 7
        { label = 'Tail Style 8', hash = 0x17EB79D3, price = 10, verified = true }, -- hashid 8
        { label = 'Tail Style 9', hash = 0x1A3B721B, price = 10, verified = true }, -- hashid 9
        { label = 'Tail Style 10', hash = 0x1BB5EAA1, price = 10, verified = true }, -- hashid 10
        { label = 'Tail Style 11', hash = 0x1E9A18C2, price = 10, verified = true }, -- hashid 11
        { label = 'Tail Style 12', hash = 0x1F7A99EA, price = 10, verified = true }, -- hashid 12
        { label = 'Tail Style 13', hash = 0x25B51566, price = 10, verified = true }, -- hashid 13
        { label = 'Tail Style 14', hash = 0x2E753874, price = 10, verified = true }, -- hashid 14
        { label = 'Tail Style 15', hash = 0x30603BB5, price = 10, verified = true }, -- hashid 15
        { label = 'Tail Style 16', hash = 0x33E7B1CB, price = 10, verified = true }, -- hashid 16
        { label = 'Tail Style 17', hash = 0x383E86F3, price = 10, verified = true }, -- hashid 17
        { label = 'Tail Style 18', hash = 0x3AE050B5, price = 10, verified = true }, -- hashid 18
        { label = 'Tail Style 19', hash = 0x3B27D1DD, price = 10, verified = true }, -- hashid 19
        { label = 'Tail Style 20', hash = 0x3B8A8D0C, price = 10, verified = true }, -- hashid 20
        { label = 'Tail Style 21', hash = 0x3D1F13D4, price = 10, verified = true }, -- hashid 21
        { label = 'Tail Style 22', hash = 0x3D212D77, price = 10, verified = true }, -- hashid 22
        { label = 'Tail Style 23', hash = 0x4124CC49, price = 10, verified = true }, -- hashid 23
        { label = 'Tail Style 24', hash = 0x49CD2991, price = 10, verified = true }, -- hashid 24
        { label = 'Tail Style 25', hash = 0x4B51B039, price = 10, verified = true }, -- hashid 25
        { label = 'Tail Style 26', hash = 0x4F5268A4, price = 10, verified = true }, -- hashid 26
        { label = 'Tail Style 27', hash = 0x5062FC53, price = 10, verified = true }, -- hashid 27
        { label = 'Tail Style 28', hash = 0x508AD44A, price = 10, verified = true }, -- hashid 28
        { label = 'Tail Style 29', hash = 0x543203ED, price = 10, verified = true }, -- hashid 29
        { label = 'Tail Style 30', hash = 0x574BC82D, price = 10, verified = true }, -- hashid 30
        { label = 'Tail Style 31', hash = 0x5D7FA043, price = 10, verified = true }, -- hashid 31
        { label = 'Tail Style 32', hash = 0x5F4871C5, price = 10, verified = true }, -- hashid 32
        { label = 'Tail Style 33', hash = 0x607956E9, price = 10, verified = true }, -- hashid 33
        { label = 'Tail Style 34', hash = 0x695B2E3F, price = 10, verified = true }, -- hashid 34
        { label = 'Tail Style 35', hash = 0x69756C80, price = 10, verified = true }, -- hashid 35
        { label = 'Tail Style 36', hash = 0x6DB6F164, price = 10, verified = true }, -- hashid 36
        { label = 'Tail Style 37', hash = 0x740701A3, price = 10, verified = true }, -- hashid 37
        { label = 'Tail Style 38', hash = 0x7522834F, price = 10, verified = true }, -- hashid 38
        { label = 'Tail Style 39', hash = 0x75C4C716, price = 10, verified = true }, -- hashid 39
        { label = 'Tail Style 40', hash = 0x7A248ABE, price = 10, verified = true }, -- hashid 40
        { label = 'Tail Style 41', hash = 0x810A5CE0, price = 10, verified = true }, -- hashid 41
        { label = 'Tail Style 42', hash = 0x82DB38EE, price = 10, verified = true }, -- hashid 42
        { label = 'Tail Style 43', hash = 0x84269E43, price = 10, verified = true }, -- hashid 43
        { label = 'Tail Style 44', hash = 0x84ADE4E4, price = 10, verified = true }, -- hashid 44
        { label = 'Tail Style 45', hash = 0x876B27E0, price = 10, verified = true }, -- hashid 45
        { label = 'Tail Style 46', hash = 0x88A2AA53, price = 10, verified = true }, -- hashid 46
        { label = 'Tail Style 47', hash = 0x894C290D, price = 10, verified = true }, -- hashid 47
        { label = 'Tail Style 48', hash = 0x96EDC3D1, price = 10, verified = true }, -- hashid 48
        { label = 'Tail Style 49', hash = 0x972AC447, price = 10, verified = true }, -- hashid 49
        { label = 'Tail Style 50', hash = 0x9CB1CFD8, price = 10, verified = true }, -- hashid 50
        { label = 'Tail Style 51', hash = 0xA0775A83, price = 10, verified = true }, -- hashid 51
        { label = 'Tail Style 52', hash = 0xA3DA055A, price = 10, verified = true }, -- hashid 52
        { label = 'Tail Style 53', hash = 0xA4F0E056, price = 10, verified = true }, -- hashid 53
        { label = 'Tail Style 54', hash = 0xA62C9657, price = 10, verified = true }, -- hashid 54
        { label = 'Tail Style 55', hash = 0xA7438C29, price = 10, verified = true }, -- hashid 55
        { label = 'Tail Style 56', hash = 0xA8A4673A, price = 10, verified = true }, -- hashid 56
        { label = 'Tail Style 57', hash = 0xB244FE1E, price = 10, verified = true }, -- hashid 57
        { label = 'Tail Style 58', hash = 0xB4374DB1, price = 10, verified = true }, -- hashid 58
        { label = 'Tail Style 59', hash = 0xB4AB3354, price = 10, verified = true }, -- hashid 59
        { label = 'Tail Style 60', hash = 0xBCD412B1, price = 10, verified = true }, -- hashid 60
        { label = 'Tail Style 61', hash = 0xC0AF3489, price = 10, verified = true }, -- hashid 61
        { label = 'Tail Style 62', hash = 0xC2FA4FF2, price = 10, verified = true }, -- hashid 62
        { label = 'Tail Style 63', hash = 0xC304EB4C, price = 10, verified = true }, -- hashid 63
        { label = 'Tail Style 64', hash = 0xC74FCC45, price = 10, verified = true }, -- hashid 64
        { label = 'Tail Style 65', hash = 0xCDFF359A, price = 10, verified = true }, -- hashid 65
        { label = 'Tail Style 66', hash = 0xCE62B5CE, price = 10, verified = true }, -- hashid 66
        { label = 'Tail Style 67', hash = 0xD143E02D, price = 10, verified = true }, -- hashid 67
        { label = 'Tail Style 68', hash = 0xD7D68A7B, price = 10, verified = true }, -- hashid 68
        { label = 'Tail Style 69', hash = 0xD9288D47, price = 10, verified = true }, -- hashid 69
        { label = 'Tail Style 70', hash = 0xD9EA1916, price = 10, verified = true }, -- hashid 70
        { label = 'Tail Style 71', hash = 0xDCE41557, price = 10, verified = true }, -- hashid 71
        { label = 'Tail Style 72', hash = 0xDD9F5447, price = 10, verified = true }, -- hashid 72
        { label = 'Tail Style 73', hash = 0xDDB48566, price = 10, verified = true }, -- hashid 73
        { label = 'Tail Style 74', hash = 0xE38F5D96, price = 10, verified = true }, -- hashid 74
        { label = 'Tail Style 75', hash = 0xEAA5EEE7, price = 10, verified = true }, -- hashid 75
        { label = 'Tail Style 76', hash = 0xEABBBAB9, price = 10, verified = true }, -- hashid 76
        { label = 'Tail Style 77', hash = 0xEAEAB164, price = 10, verified = true }, -- hashid 77
        { label = 'Tail Style 78', hash = 0xEBC7218B, price = 10, verified = true }, -- hashid 78
        { label = 'Tail Style 79', hash = 0xED0397AC, price = 10, verified = true }, -- hashid 79
        { label = 'Tail Style 80', hash = 0xED787168, price = 10, verified = true }, -- hashid 80
        { label = 'Tail Style 81', hash = 0xEFA67855, price = 10, verified = true }, -- hashid 81
        { label = 'Tail Style 82', hash = 0xF4294320, price = 10, verified = true }, -- hashid 82
        { label = 'Tail Style 83', hash = 0xF4A3443C, price = 10, verified = true }, -- hashid 83
        { label = 'Tail Style 84', hash = 0xF6B0AB06, price = 10, verified = true }, -- hashid 84
        { label = 'Tail Style 85', hash = 0xF867D611, price = 10, verified = true }, -- hashid 85
    },
    mane = { -- category_hash 0xAA0217AB
        { label = 'Mane Style 1', hash = 0x0235DBF1, price = 8, verified = true }, -- hashid 1
        { label = 'Mane Style 2', hash = 0x0354F6B7, price = 8, verified = true }, -- hashid 2
        { label = 'Mane Style 3', hash = 0x0512377B, price = 8, verified = true }, -- hashid 3
        { label = 'Mane Style 4', hash = 0x054A3CB0, price = 8, verified = true }, -- hashid 4
        { label = 'Mane Style 5', hash = 0x0632F2B7, price = 8, verified = true }, -- hashid 5
        { label = 'Mane Style 6', hash = 0x09836E71, price = 8, verified = true }, -- hashid 6
        { label = 'Mane Style 7', hash = 0x09A640A3, price = 8, verified = true }, -- hashid 7
        { label = 'Mane Style 8', hash = 0x0AFB7C24, price = 8, verified = true }, -- hashid 8
        { label = 'Mane Style 9', hash = 0x0B52F0BC, price = 8, verified = true }, -- hashid 9
        { label = 'Mane Style 10', hash = 0x0DCF5321, price = 8, verified = true }, -- hashid 10
        { label = 'Mane Style 11', hash = 0x130E341A, price = 8, verified = true }, -- hashid 11
        { label = 'Mane Style 12', hash = 0x14098229, price = 8, verified = true }, -- hashid 12
        { label = 'Mane Style 13', hash = 0x16923E26, price = 8, verified = true }, -- hashid 13
        { label = 'Mane Style 14', hash = 0x18199F48, price = 8, verified = true }, -- hashid 14
        { label = 'Mane Style 15', hash = 0x1A5A45B6, price = 8, verified = true }, -- hashid 15
        { label = 'Mane Style 16', hash = 0x1DF21752, price = 8, verified = true }, -- hashid 16
        { label = 'Mane Style 17', hash = 0x1FDC6D0F, price = 8, verified = true }, -- hashid 17
        { label = 'Mane Style 18', hash = 0x241D7FBD, price = 8, verified = true }, -- hashid 18
        { label = 'Mane Style 19', hash = 0x25627B98, price = 8, verified = true }, -- hashid 19
        { label = 'Mane Style 20', hash = 0x2D47B5FD, price = 8, verified = true }, -- hashid 20
        { label = 'Mane Style 21', hash = 0x2E378E8A, price = 8, verified = true }, -- hashid 21
        { label = 'Mane Style 22', hash = 0x2FCAF0CB, price = 8, verified = true }, -- hashid 22
        { label = 'Mane Style 23', hash = 0x388E4B32, price = 8, verified = true }, -- hashid 23
        { label = 'Mane Style 24', hash = 0x3A7C2C86, price = 8, verified = true }, -- hashid 24
        { label = 'Mane Style 25', hash = 0x3BFE2A17, price = 8, verified = true }, -- hashid 25
        { label = 'Mane Style 26', hash = 0x3F1FEE4C, price = 8, verified = true }, -- hashid 26
        { label = 'Mane Style 27', hash = 0x419D9470, price = 8, verified = true }, -- hashid 27
        { label = 'Mane Style 28', hash = 0x41EA9196, price = 8, verified = true }, -- hashid 28
        { label = 'Mane Style 29', hash = 0x446A6F01, price = 8, verified = true }, -- hashid 29
        { label = 'Mane Style 30', hash = 0x483AC803, price = 8, verified = true }, -- hashid 30
        { label = 'Mane Style 31', hash = 0x4F148D45, price = 8, verified = true }, -- hashid 31
        { label = 'Mane Style 32', hash = 0x4FCC51B3, price = 8, verified = true }, -- hashid 32
        { label = 'Mane Style 33', hash = 0x50AC7CC6, price = 8, verified = true }, -- hashid 33
        { label = 'Mane Style 34', hash = 0x52DC15C8, price = 8, verified = true }, -- hashid 34
        { label = 'Mane Style 35', hash = 0x5445B9C0, price = 8, verified = true }, -- hashid 35
        { label = 'Mane Style 36', hash = 0x5D596CCD, price = 8, verified = true }, -- hashid 36
        { label = 'Mane Style 37', hash = 0x5DE62AE8, price = 8, verified = true }, -- hashid 37
        { label = 'Mane Style 38', hash = 0x5ED14B9F, price = 8, verified = true }, -- hashid 38
        { label = 'Mane Style 39', hash = 0x5F0395A3, price = 8, verified = true }, -- hashid 39
        { label = 'Mane Style 40', hash = 0x5FE29755, price = 8, verified = true }, -- hashid 40
        { label = 'Mane Style 41', hash = 0x6038F7FF, price = 8, verified = true }, -- hashid 41
        { label = 'Mane Style 42', hash = 0x648A3924, price = 8, verified = true }, -- hashid 42
        { label = 'Mane Style 43', hash = 0x66215D77, price = 8, verified = true }, -- hashid 43
        { label = 'Mane Style 44', hash = 0x6B3A6471, price = 8, verified = true }, -- hashid 44
        { label = 'Mane Style 45', hash = 0x6CB9310E, price = 8, verified = true }, -- hashid 45
        { label = 'Mane Style 46', hash = 0x6D9412B5, price = 8, verified = true }, -- hashid 46
        { label = 'Mane Style 47', hash = 0x6F4510C4, price = 8, verified = true }, -- hashid 47
        { label = 'Mane Style 48', hash = 0x7098D141, price = 8, verified = true }, -- hashid 48
        { label = 'Mane Style 49', hash = 0x7D902D5A, price = 8, verified = true }, -- hashid 49
        { label = 'Mane Style 50', hash = 0x817B10F6, price = 8, verified = true }, -- hashid 50
        { label = 'Mane Style 51', hash = 0x83563E39, price = 8, verified = true }, -- hashid 51
        { label = 'Mane Style 52', hash = 0x838E5EB8, price = 8, verified = true }, -- hashid 52
        { label = 'Mane Style 53', hash = 0x86457C9A, price = 8, verified = true }, -- hashid 53
        { label = 'Mane Style 54', hash = 0x8679685F, price = 8, verified = true }, -- hashid 54
        { label = 'Mane Style 55', hash = 0x92B2579E, price = 8, verified = true }, -- hashid 55
        { label = 'Mane Style 56', hash = 0x94F58186, price = 8, verified = true }, -- hashid 56
        { label = 'Mane Style 57', hash = 0x960C1B33, price = 8, verified = true }, -- hashid 57
        { label = 'Mane Style 58', hash = 0x96FE6589, price = 8, verified = true }, -- hashid 58
        { label = 'Mane Style 59', hash = 0x97105EF6, price = 8, verified = true }, -- hashid 59
        { label = 'Mane Style 60', hash = 0x97D095F4, price = 8, verified = true }, -- hashid 60
        { label = 'Mane Style 61', hash = 0x99F5A3FA, price = 8, verified = true }, -- hashid 61
        { label = 'Mane Style 62', hash = 0x9DF8175C, price = 8, verified = true }, -- hashid 62
        { label = 'Mane Style 63', hash = 0xA0F4F423, price = 8, verified = true }, -- hashid 63
        { label = 'Mane Style 64', hash = 0xA193A97A, price = 8, verified = true }, -- hashid 64
        { label = 'Mane Style 65', hash = 0xA4E1B8DE, price = 8, verified = true }, -- hashid 65
        { label = 'Mane Style 66', hash = 0xA64BFD6D, price = 8, verified = true }, -- hashid 66
        { label = 'Mane Style 67', hash = 0xA7A4DD49, price = 8, verified = true }, -- hashid 67
        { label = 'Mane Style 68', hash = 0xAA3FAC1A, price = 8, verified = true }, -- hashid 68
        { label = 'Mane Style 69', hash = 0xABA8475F, price = 8, verified = true }, -- hashid 69
        { label = 'Mane Style 70', hash = 0xACA2B4B1, price = 8, verified = true }, -- hashid 70
        { label = 'Mane Style 71', hash = 0xB13D134B, price = 8, verified = true }, -- hashid 71
        { label = 'Mane Style 72', hash = 0xB288D42C, price = 8, verified = true }, -- hashid 72
        { label = 'Mane Style 73', hash = 0xB2FB934B, price = 8, verified = true }, -- hashid 73
        { label = 'Mane Style 74', hash = 0xB5F379E6, price = 8, verified = true }, -- hashid 74
        { label = 'Mane Style 75', hash = 0xB881489D, price = 8, verified = true }, -- hashid 75
        { label = 'Mane Style 76', hash = 0xBD7B6B05, price = 8, verified = true }, -- hashid 76
        { label = 'Mane Style 77', hash = 0xC0085B74, price = 8, verified = true }, -- hashid 77
        { label = 'Mane Style 78', hash = 0xC15371C1, price = 8, verified = true }, -- hashid 78
        { label = 'Mane Style 79', hash = 0xC8646863, price = 8, verified = true }, -- hashid 79
        { label = 'Mane Style 80', hash = 0xC929BFA7, price = 8, verified = true }, -- hashid 80
        { label = 'Mane Style 81', hash = 0xC9D16B31, price = 8, verified = true }, -- hashid 81
        { label = 'Mane Style 82', hash = 0xCDC9C8E7, price = 8, verified = true }, -- hashid 82
        { label = 'Mane Style 83', hash = 0xCF434F57, price = 8, verified = true }, -- hashid 83
        { label = 'Mane Style 84', hash = 0xD152FE09, price = 8, verified = true }, -- hashid 84
        { label = 'Mane Style 85', hash = 0xD43503D5, price = 8, verified = true }, -- hashid 85
        { label = 'Mane Style 86', hash = 0xD4E65BE5, price = 8, verified = true }, -- hashid 86
        { label = 'Mane Style 87', hash = 0xD894BF28, price = 8, verified = true }, -- hashid 87
        { label = 'Mane Style 88', hash = 0xD9CE8DB4, price = 8, verified = true }, -- hashid 88
        { label = 'Mane Style 89', hash = 0xDC62E996, price = 8, verified = true }, -- hashid 89
        { label = 'Mane Style 90', hash = 0xE02377D6, price = 8, verified = true }, -- hashid 90
        { label = 'Mane Style 91', hash = 0xE0BC27A6, price = 8, verified = true }, -- hashid 91
        { label = 'Mane Style 92', hash = 0xE12C9C64, price = 8, verified = true }, -- hashid 92
        { label = 'Mane Style 93', hash = 0xE1435081, price = 8, verified = true }, -- hashid 93
        { label = 'Mane Style 94', hash = 0xE9FE04D0, price = 8, verified = true }, -- hashid 94
        { label = 'Mane Style 95', hash = 0xEA46E28C, price = 8, verified = true }, -- hashid 95
        { label = 'Mane Style 96', hash = 0xEAB72F85, price = 8, verified = true }, -- hashid 96
        { label = 'Mane Style 97', hash = 0xF2E555D8, price = 8, verified = true }, -- hashid 97
        { label = 'Mane Style 98', hash = 0xF304C014, price = 8, verified = true }, -- hashid 98
        { label = 'Mane Style 99', hash = 0xFC74DF3B, price = 8, verified = true }, -- hashid 99
        { label = 'Mane Style 100', hash = 0xFF020F3A, price = 8, verified = true }, -- hashid 100
        { label = 'Mane Style 101', hash = 0xFF17AB82, price = 8, verified = true }, -- hashid 101
        { label = 'Mane Style 102', hash = 0xFFF3B76A, price = 8, verified = true }, -- hashid 102
    },
    mask = { -- category_hash 0xD3500E5D
        { label = 'Mask Style 1', hash = 0x08A78F53, price = 12, verified = true }, -- hashid 1
        { label = 'Mask Style 2', hash = 0x13AC6E51, price = 12, verified = true }, -- hashid 2
        { label = 'Mask Style 3', hash = 0x226B2F76, price = 12, verified = true }, -- hashid 3
        { label = 'Mask Style 4', hash = 0x30044BAC, price = 12, verified = true }, -- hashid 4
        { label = 'Mask Style 5', hash = 0x406FC6C7, price = 12, verified = true }, -- hashid 5
        { label = 'Mask Style 6', hash = 0x4C8C83A4, price = 12, verified = true }, -- hashid 6
        { label = 'Mask Style 7', hash = 0x4E22622C, price = 12, verified = true }, -- hashid 7
        { label = 'Mask Style 8', hash = 0x53EEEBD4, price = 12, verified = true }, -- hashid 8
        { label = 'Mask Style 9', hash = 0x61BEAE08, price = 12, verified = true }, -- hashid 9
        { label = 'Mask Style 10', hash = 0x68FB97DE, price = 12, verified = true }, -- hashid 10
        { label = 'Mask Style 11', hash = 0x69CD996E, price = 12, verified = true }, -- hashid 11
        { label = 'Mask Style 12', hash = 0x6B355791, price = 12, verified = true }, -- hashid 12
        { label = 'Mask Style 13', hash = 0x702A4AF3, price = 12, verified = true }, -- hashid 13
        { label = 'Mask Style 14', hash = 0x7A773AC1, price = 12, verified = true }, -- hashid 14
        { label = 'Mask Style 15', hash = 0x7BFA791B, price = 12, verified = true }, -- hashid 15
        { label = 'Mask Style 16', hash = 0x872A0C5A, price = 12, verified = true }, -- hashid 16
        { label = 'Mask Style 17', hash = 0x8C471684, price = 12, verified = true }, -- hashid 17
        { label = 'Mask Style 18', hash = 0x8DB38601, price = 12, verified = true }, -- hashid 18
        { label = 'Mask Style 19', hash = 0x8DCC1CBE, price = 12, verified = true }, -- hashid 19
        { label = 'Mask Style 20', hash = 0x90A62272, price = 12, verified = true }, -- hashid 20
        { label = 'Mask Style 21', hash = 0x9946F874, price = 12, verified = true }, -- hashid 21
        { label = 'Mask Style 22', hash = 0x9A11B219, price = 12, verified = true }, -- hashid 22
        { label = 'Mask Style 23', hash = 0x9DB125FC, price = 12, verified = true }, -- hashid 23
        { label = 'Mask Style 24', hash = 0xA45049C6, price = 12, verified = true }, -- hashid 24
        { label = 'Mask Style 25', hash = 0xB0395F88, price = 12, verified = true }, -- hashid 25
        { label = 'Mask Style 26', hash = 0xB395D1C5, price = 12, verified = true }, -- hashid 26
        { label = 'Mask Style 27', hash = 0xB567EBF5, price = 12, verified = true }, -- hashid 27
        { label = 'Mask Style 28', hash = 0xBD887906, price = 12, verified = true }, -- hashid 28
        { label = 'Mask Style 29', hash = 0xC4886BDC, price = 12, verified = true }, -- hashid 29
        { label = 'Mask Style 30', hash = 0xC70D8F40, price = 12, verified = true }, -- hashid 30
        { label = 'Mask Style 31', hash = 0xC907FCA9, price = 12, verified = true }, -- hashid 31
        { label = 'Mask Style 32', hash = 0xD6E279B1, price = 12, verified = true }, -- hashid 32
        { label = 'Mask Style 33', hash = 0xDDCDB9A0, price = 12, verified = true }, -- hashid 33
        { label = 'Mask Style 34', hash = 0xE3278C28, price = 12, verified = true }, -- hashid 34
        { label = 'Mask Style 35', hash = 0xEC10D626, price = 12, verified = true }, -- hashid 35
        { label = 'Mask Style 36', hash = 0xEEF65F11, price = 12, verified = true }, -- hashid 36
        { label = 'Mask Style 37', hash = 0xF606EC4A, price = 12, verified = true }, -- hashid 37
        { label = 'Mask Style 38', hash = 0xFA5B72BB, price = 12, verified = true }, -- hashid 38
        { label = 'Mask Style 39', hash = 0xD70C73EA, price = 12, verified = true }, -- hashid 39
        { label = 'Mask Style 40', hash = 0xF17728C7, price = 12, verified = true }, -- hashid 40
        { label = 'Mask Style 41', hash = 0x68DB4FAD, price = 12, verified = true }, -- hashid 41
        { label = 'Mask Style 42', hash = 0x62C5B02A, price = 12, verified = true }, -- hashid 42
        { label = 'Mask Style 43', hash = 0xF0ED62FF, price = 12, verified = true }, -- hashid 43
        { label = 'Mask Style 44', hash = 0x2E776EE6, price = 12, verified = true }, -- hashid 44
        { label = 'Mask Style 45', hash = 0x75637CBD, price = 12, verified = true }, -- hashid 45
        { label = 'Mask Style 46', hash = 0x4A992729, price = 12, verified = true }, -- hashid 46
        { label = 'Mask Style 47', hash = 0x4E312E61, price = 12, verified = true }, -- hashid 47
        { label = 'Mask Style 48', hash = 0x48099436, price = 12, verified = true }, -- hashid 48
        { label = 'Mask Style 49', hash = 0x77987353, price = 12, verified = true }, -- hashid 49
        { label = 'Mask Style 50', hash = 0xAD6DDEFD, price = 12, verified = true }, -- hashid 50
        { label = 'Mask Style 51', hash = 0x5B22BA68, price = 12, verified = true }, -- hashid 51
    },
    mustache = { -- category_hash 0x30DEFDDF
        { label = 'Mustache Style 1', hash = 0x004BBEED, price = 5, verified = true }, -- hashid 1
        { label = 'Mustache Style 2', hash = 0x0960D117, price = 5, verified = true }, -- hashid 2
        { label = 'Mustache Style 3', hash = 0x281A6D81, price = 5, verified = true }, -- hashid 3
        { label = 'Mustache Style 4', hash = 0x334F83D3, price = 5, verified = true }, -- hashid 4
        { label = 'Mustache Style 5', hash = 0x5497E784, price = 5, verified = true }, -- hashid 5
        { label = 'Mustache Style 6', hash = 0x67590D8F, price = 5, verified = true }, -- hashid 6
        { label = 'Mustache Style 7', hash = 0x91887491, price = 5, verified = true }, -- hashid 7
        { label = 'Mustache Style 8', hash = 0x9ADAF492, price = 5, verified = true }, -- hashid 8
        { label = 'Mustache Style 9', hash = 0xAC459767, price = 5, verified = true }, -- hashid 9
        { label = 'Mustache Style 10', hash = 0xAF2A2FD8, price = 5, verified = true }, -- hashid 10
        { label = 'Mustache Style 11', hash = 0xB755402E, price = 5, verified = true }, -- hashid 11
        { label = 'Mustache Style 12', hash = 0xCFBA5E50, price = 5, verified = true }, -- hashid 12
        { label = 'Mustache Style 13', hash = 0xDC895660, price = 5, verified = true }, -- hashid 13
        { label = 'Mustache Style 14', hash = 0xEAEEF32B, price = 5, verified = true }, -- hashid 14
        { label = 'Mustache Style 15', hash = 0xED8D1970, price = 5, verified = true }, -- hashid 15
        { label = 'Mustache Style 16', hash = 0xF7203FC3, price = 5, verified = true }, -- hashid 16
    },
    holster = { -- category_hash 0xAC106B30
        { label = 'Holster Style 1', hash = 0xF772CED6, price = 15, verified = true }, -- hashid 1
    },
    bridle = { -- category_hash 0x94B2E3AF
        { label = 'Bridle Style 1', hash = 0x0C48F261, price = 10, verified = true }, -- hashid 1
        { label = 'Bridle Style 2', hash = 0x0CBA8E54, price = 10, verified = true }, -- hashid 2
        { label = 'Bridle Style 3', hash = 0x2F62D3A4, price = 10, verified = true }, -- hashid 3
        { label = 'Bridle Style 4', hash = 0x433DE046, price = 10, verified = true }, -- hashid 4
        { label = 'Bridle Style 5', hash = 0x5BC3AC4D, price = 10, verified = true }, -- hashid 5
        { label = 'Bridle Style 6', hash = 0x63899BC6, price = 10, verified = true }, -- hashid 6
        { label = 'Bridle Style 7', hash = 0x754C3F4B, price = 10, verified = true }, -- hashid 7
        { label = 'Bridle Style 8', hash = 0x7956475F, price = 10, verified = true }, -- hashid 8
        { label = 'Bridle Style 9', hash = 0x7E89F1D9, price = 10, verified = true }, -- hashid 9
        { label = 'Bridle Style 10', hash = 0x874F0363, price = 10, verified = true }, -- hashid 10
        { label = 'Bridle Style 11', hash = 0x880FE4D2, price = 10, verified = true }, -- hashid 11
        { label = 'Bridle Style 12', hash = 0x95ADA020, price = 10, verified = true }, -- hashid 12
        { label = 'Bridle Style 13', hash = 0xAAA9CA18, price = 10, verified = true }, -- hashid 13
        { label = 'Bridle Style 14', hash = 0xB8F0E6A6, price = 10, verified = true }, -- hashid 14
        { label = 'Bridle Style 15', hash = 0xCFFBF4B5, price = 10, verified = true }, -- hashid 15
        { label = 'Bridle Style 16', hash = 0xD1D7988F, price = 10, verified = true }, -- hashid 16
        { label = 'Bridle Style 17', hash = 0xE006B4ED, price = 10, verified = true }, -- hashid 17
        { label = 'Bridle Style 18', hash = 0xE3139FF7, price = 10, verified = true }, -- hashid 18
        { label = 'Bridle Style 19', hash = 0xF0D53B7A, price = 10, verified = true }, -- hashid 19
        { label = 'Bridle Style 20', hash = 0xF18C3CE4, price = 10, verified = true }, -- hashid 20
        { label = 'Bridle Style 21', hash = 0xFB2178EC, price = 10, verified = true }, -- hashid 21
        { label = 'Bridle Style 22', hash = 0xFE8E56EC, price = 10, verified = true }, -- hashid 22
    },
    horseshoe = { -- category_hash 0xFACFC3C0
        { label = 'Horseshoes Style 1', hash = 0x0865A270, price = 10, verified = true }, -- hashid 1
    },
}

-- ===================== HORSE CARD =====================
-- Live horse information panel (target "Horse Stats" on your horse, or the command below)
Config.HorseCard = {
    command     = 'horseinfo', -- false to disable the command
    maxDistance = 15.0,        -- how close you must be to your horse to open it (mounted always works)
}

-- ===================== HORSE MEDICINE =====================
-- Health counterpart to the stimulant (SP: CONSUMABLE_HORSE_CARE_PACKAGE / horse medicine)
Config.HorseMedicine = {
    enabled     = true,
    item        = 'horse_medicine',
    label       = 'Horse Medicine',
    healPercent = 50,   -- % of max health restored
    fillCore    = true, -- also refill the health core
    useDistance = 3.0,
    cooldown    = 60,   -- seconds between doses
}

-- ===================== HORSE REVIVER =====================
-- SP: CONSUMABLE_HORSE_REVIVER. When your horse goes down you have `window` seconds to revive it
-- in the field with the item before it counts as dead (insurance / death rules then apply as normal).
Config.HorseReviver = {
    enabled       = true,
    item          = 'horse_reviver',
    label         = 'Horse Reviver',
    window        = 90,   -- seconds to reach the horse and revive it
    useDistance   = 3.0,
    revivedHealth = 30,   -- % health after reviving
    bondingLoss   = 5,    -- bonding lost when the horse goes down (0 = none)
}

-- ===================== TACK STAT BONUSES =====================
-- Tack gives bonus ranks like it does in SP (player_horse.c reads each item's effects into
-- SET_ATTRIBUTE_BONUS_RANK). Stats: health, stamina, speed, accel. Bonuses stack with training.
-- A per-item `bonus = { speed = 1 }` on any Config.TackItems entry overrides its category default.
Config.TackBonuses = {
    enabled = true,
    categoryDefaults = {
        saddle    = { stamina = 1 },
        stirrups  = { accel = 1 },
        horseshoe = { speed = 1 },
        blanket   = { health = 1 },
    },
}

-- ===================== SELLING HORSES =====================
-- Sell a stabled horse back to the stablehand (Sell Horse in the horse menu)
Config.HorseSell = {
    enabled      = true,
    percent      = 0.5,  -- of the breed's buy price
    perTrainedLevel = 5, -- extra $ per trained level (all stats)
    minPrice     = 5,
}

-- Horse fence: sell wild or stolen (unowned) horses for blood money, no questions asked.
-- SP/MP have horse fences (SHOP_*_HORSE_FENCE in the decompile) but their coords aren't in the
-- brain data, so add your own locations below (vector4 x, y, z, heading for the fence NPC).
Config.HorseFence = {
    enabled   = true,
    account   = 'bloodmoney',
    percent   = 0.35,  -- of the breed's buy price
    cooldown  = 300,   -- seconds between sales per player
    sellDistance = 10.0, -- horse and player must be this close to the fence NPC
    pedModel  = `u_m_m_bwmstablehand_01`, -- same model the stables use
    blip      = false, -- fences are usually secret
    locations = {
        -- { label = 'Horse Fence', coords = vector4(0.0, 0.0, 0.0, 0.0) },
    },
}

-- ===================== HORSE TRAINING =====================
-- Trained levels are applied as attribute BONUS ranks (SET_ATTRIBUTE_BONUS_RANK), the same layer
-- Rockstar uses for tack bonuses in player_horse.c, so a breed's own base stats are never overwritten.
-- Attribute IDs: rsg-redm-brain data/rdr3-native-enums/PedAttribute__AttributeType.md
Config.Training = {
    enabled = true,
    debug   = false,

    stats = {
        health  = { attribute = 0 }, -- PA_Health
        stamina = { attribute = 1 }, -- PA_Stamina
        speed   = { attribute = 5 }, -- PA_Speed
        accel   = { attribute = 6 }, -- PA_Acceleration
        courage = { attribute = 3 }, -- PA_Courage: less spooking at gunfire / predators
    },
    statOrder = { 'health', 'stamina', 'speed', 'accel', 'courage' },
    courageFromBonding = 25, -- +1 courage bonus rank per this much bonding (0-100); 0 = off

    levelXp       = { 100, 250, 450, 700, 1000 }, -- total XP needed for level 1..n (n = max level)
    bonusPerLevel = 1,                             -- bonus ranks added per trained level

    -- passive XP from riding your own horse (distance measured on the server)
    riding = {
        enabled     = true,
        interval    = 60,     -- seconds between ride ticks
        metersPerXp = 100.0,  -- metres ridden per 1 XP
        maxXpPerTick = 12,
        maxSpeed    = 22.0,   -- m/s; anything faster is treated as a teleport and ignored
        split       = { stamina = 0.6, speed = 0.4 }, -- how ride XP is shared between stats
    },

    -- paid training sessions at a stable (ox_target on your horse)
    session = {
        enabled        = true,
        price          = { health = 10, stamina = 10, speed = 15, accel = 15, courage = 10 }, -- taken from Config.PaymentAccount
        rounds         = 5,     -- timing rounds per session
        roundMs        = 2000,  -- how long the marker takes to sweep once (NUI)
        baseXp         = 20,    -- XP for finishing a session
        xpPerHit       = 12,    -- extra XP per successful round
        cooldown       = 900,   -- seconds between sessions for the same horse
        stableDistance = 25.0,  -- how close to a stable (ped/store/preview point) you must be
        horseDistance  = 6.0,   -- how close to your horse you must be
    },
}
