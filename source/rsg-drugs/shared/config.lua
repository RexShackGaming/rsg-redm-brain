Config = {}
lib.locale() -- player-facing labels below come from locales/*.json (cfg_* keys); plain strings work too

---------------------------------
-- processing npc
---------------------------------
Config.NPC = {
    coords   = vector4(2858.32, -1199.03, 45.61, 106.44),
    model    = `g_m_m_unicriminals_01`, -- verify against peds_list in rdr3_discoveries
    spawnDistance = 50.0,
    interactDistance = 3.0, -- server-side distance check for every NUI action
    targetDistance = 2.5,
}

---------------------------------
-- items (change to match your rsg-inventory items)
---------------------------------
Config.Items = {
    raw       = 'weed',           -- fresh cannabis brought by the player
    dried     = 'weed_dried',     -- output of drying
    processed = 'weed_processed', -- output of processing (for bricks / bags)
    brick     = 'weed_brick',     -- packed by packers
    bag       = 'weed_bag',       -- packed by packers
    seed      = 'seedweed',       -- rare find while drying (rsg-farming weed seed)
}

-- chance (%) per fresh weed dried that a seed is found; collect them from the Supplies tab
Config.SeedChance = 2.0

-- packer products: uses = weed_processed consumed per unit, work = work points needed per unit
-- a packer adds their skill rate in work points each shift (e.g. Skilled = 1.5 per shift)
Config.Packing = {
    bag   = { label = locale('cfg_pack_bag'),   uses = 1,    work = 1 },
    brick = { label = locale('cfg_pack_brick'), uses = 1000, work = 10 },
}

-- food and drink employees can be given (item = how many 'meals' it gives)
Config.Food  = { bread = 1, cooked_meat = 2 }
Config.Water = { water = 1 }

---------------------------------
-- work loop
---------------------------------
Config.TickSeconds   = 60    -- one work shift tick
Config.MaxEmployees  = 6
Config.MaxStorage    = 5000  -- max of each stock type held at the lab (must be >= a brick's uses)

Config.HungerDrain   = 8     -- per tick
Config.ThirstDrain   = 12    -- per tick
Config.MealRestore   = 50    -- hunger restored per food unit
Config.DrinkRestore  = 50    -- thirst restored per water unit
Config.AutoFeedBelow = 50    -- staff eat/drink from the pantry under this value
Config.UnpaidStrikeTicks = 3 -- missed paydays before going on strike

-- skill 1-5: production per tick and wage per tick
Config.Skill = {
    [1] = { rate = 0.5, wage = 0.10, label = locale('cfg_skill_1') },
    [2] = { rate = 1.0, wage = 0.20, label = locale('cfg_skill_2') },
    [3] = { rate = 1.5, wage = 0.30, label = locale('cfg_skill_3') },
    [4] = { rate = 2.0, wage = 0.45, label = locale('cfg_skill_4') },
    [5] = { rate = 3.0, wage = 0.65, label = locale('cfg_skill_5') },
}

Config.Roles = {
    dryer     = { label = locale('cfg_role_dryer'),     from = 'raw',   to = 'dried' },
    processor = { label = locale('cfg_role_processor'), from = 'dried', to = 'processed' },
    packer    = { label = locale('cfg_role_packer') }, -- uses processed weed; output set per packer (Config.Packing)
}

Config.HireFee        = 5.0   -- one-off signing fee
Config.CandidateCount = 6
Config.CandidateRefreshMinutes = 30

Config.FirstNames = { 'Amos','Bill','Cyrus','Dutch','Eli','Floyd','Gus','Hattie','Ida','Jeb','Lottie','Mabel','Otis','Pearl','Silas','Wade' }
Config.LastNames  = { 'Barlow','Cobb','Dawes','Fenwick','Grady','Holt','Kincaid','Mercer','Pryor','Rudd','Slade','Tate','Wilkes' }

---------------------------------
-- drug reputation / XP (stored as rsg-core rep, metadata.rep[RepName])
---------------------------------
Config.XP = {
    Enabled = true,
    RepName = 'drugs',
    Notify  = true,   -- "+X XP" notifications
    BrickMinLevel = 5,  -- owner level needed for weed_brick packing (5 = Distributor, 6 = Kingpin); 1 = everyone
    ResetOnJail = true, -- wipe drug XP to 0 when the player starts an rsg-prison sentence (rehab doesn't count)
    -- XP to the lab owner per finished unit (employees' work counts as yours).
    -- If the owner is offline it is banked and paid the next time they open the lab.
    Produce = {
        dried     = 0,
        processed = 0,
        bag       = 1,   -- low
        brick     = 50,  -- high
    },
    -- XP per completed sale
    Sell = {
        weed_bag   = 2,
        weed_brick = 60, -- per brick exported (Config.Export)
    },
    -- level thresholds (total XP needed)
    Levels = {
        { xp = 0,    label = locale('cfg_level_1') },
        { xp = 100,  label = locale('cfg_level_2') },
        { xp = 300,  label = locale('cfg_level_3') },
        { xp = 750,  label = locale('cfg_level_4') },
        { xp = 1500, label = locale('cfg_level_5') },
        { xp = 3000, label = locale('cfg_level_6') },
    },
}
