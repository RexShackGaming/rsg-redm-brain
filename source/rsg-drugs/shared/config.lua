Config = {}
-- build the database tables automatically on start (set false and import the SQL file for a manual install)
Config.AutoDatabase = true

-- While a panel is open the mouse/keyboard go to the UI. Keep push-to-talk working (rsg-voice) while it is open.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

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

---------------------------------
-- low wage chest warning
---------------------------------
Config.Payroll = {
    WarnShifts          = 3,   -- warn the owner when the wage chest covers fewer shifts than this (0 = off)
    WarnCooldownMinutes = 30,  -- at most one warning per lab per this many minutes
}

---------------------------------
-- product quality (potency 0-100)
-- Crew skill sets the potency of what they make, input potency is partly carried through, and the final
-- potency is stored on withdrawn items (info.potency) and changes what they sell for.
---------------------------------
Config.Quality = {
    Enabled     = true,
    Default     = 50,   -- potency of fresh weed handed in, and of items that have none recorded
    InputWeight = 0.4,  -- share of the input's potency carried into the output (the rest comes from the crew)
    Step        = 5,    -- item potency is rounded to this so stacks still merge in the inventory
    CrewPotency = { [1] = 40, [2] = 55, [3] = 70, [4] = 85, [5] = 95 }, -- by worker skill (1-5)
    PriceMin    = 0.7,  -- price multiplier at potency 0
    PriceMax    = 1.3,  -- price multiplier at potency 100
}

---------------------------------
-- heat and raids
-- Making and selling drugs builds heat on your lab. Hot labs get reported; on-duty law is alerted and can raid
-- the lab at the processing NPC within the window. A raid destroys part of the stock and pays the officer.
---------------------------------
Config.Heat = {
    Enabled        = true,
    Max            = 100,
    Decay          = 2,     -- heat lost per shift while no raid is pending
    PerBrick       = 2.0,   -- per brick finished by the crew
    PerBag         = 0.1,   -- per bag finished by the crew
    PerExportBrick = 3.0,   -- per brick exported
    PerSale        = 1.0,   -- per bag sold to an NPC
    PerRefusal     = 10.0,  -- when an NPC refuses a sale (it called the law)
    RaidThreshold  = 70,    -- a raid can start at or above this heat
    RaidChance     = 25,    -- % per shift while above the threshold
    MinLaw         = 1,     -- on-duty law needed before a raid is called
    RaidWindowMinutes = 10, -- how long the law has to carry out the raid
    SeizePercent   = 60,    -- % of every stock type destroyed in a raid
    HeatAfterRaid  = 20,
    HeatAfterEscape = 40,   -- the law was too slow
    CooldownMinutes = 60,   -- no new raid on the same lab for this long
    OfficerReward  = 150,
    MoneyType      = 'cash',
    AlertRadius    = 80.0,  -- law map blip radius around the lab
    LawJobTypes    = { leo = true },
    LawJobs        = {},
}

---------------------------------
-- rsg-skills: drug XP also feeds this skill; its perks boost sales and crew speed
---------------------------------
Config.Skills = {
    Enabled     = true,
    Key         = 'drugs',
    XPScale     = 1.0,   -- skill XP = drug XP * this
    ResetOnJail = true,  -- follows Config.XP.ResetOnJail
    Definition  = {
        label       = locale('cfg_skill_drugs'),
        description = locale('cfg_skill_drugs_desc'),
        order       = 120,
        maxLevel    = 20,
        -- perk names come from rsg-skills locale keys perk_sell_bonus and perk_speed_bonus
        perks = {
            sell_bonus  = { suffix = '%', levels = { [3] = 2, [6] = 4, [10] = 6, [15] = 8, [20] = 10 } }, -- NPC bag sales and brick export
            speed_bonus = { suffix = '%', levels = { [5] = 5, [10] = 10, [15] = 15, [20] = 20 } },        -- crew output
        },
    },
}

---------------------------------
-- rsg-reputation: dealing costs honor and local standing, helping the law earns it
-- Standing is applied in the town nearest to the player (needs rsg-economy GetRegionAt).
---------------------------------
Config.Reputation = {
    Enabled = true,
    HostileBuyMult = 0.5, -- NPCs in a town that is hostile to you are this much less likely to buy
    Events = {
        sale    = { honor = -1, standing = -1 },
        refused = { honor = -2, standing = -3 },
        export  = { honor = -5, standing = -3 },
        rehab   = { honor = 3,  standing = 2 },
        raid    = { honor = 5,  standing = 4 },
    },
}

---------------------------------
-- rsg-economy: bag sales to NPCs follow the town's market (flooding a town lowers the price)
---------------------------------
Config.Economy = {
    Enabled = true,
}
