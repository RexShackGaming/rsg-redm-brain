Config = {}

Config.Debug = false            -- true = /testambush command, 100% chance, no cooldown or request throttle. NEVER on a live server.

---------------------------------------------------------------------
-- Triggering (the client checks mounted / speed / town, the SERVER rolls the chance and enforces the rest)
---------------------------------------------------------------------
Config.CheckInterval   = 60     -- seconds between ambush checks on the client
Config.TriggerChance   = 6      -- % chance per check, before the modifiers in Config.Hooks / Config.Zones
Config.RequireMounted  = true   -- only ambush riders (like the SP ambush_* scripts)
Config.BlockInTowns    = true   -- no ambushes inside town zones
Config.PlayerCooldown  = 1800   -- seconds (server enforced) between ambushes per player
Config.RequestThrottle = 20     -- seconds (server enforced) minimum between two checks of one player
Config.MinPlayerSpeed  = 2.0    -- m/s, player must be travelling

-- Warning before the bandits appear: a sound and a notice, then this many seconds (0 = no warning)
Config.WarningSeconds  = 4
Config.WarningSound    = { name = 'Wanted_Spotted', ref = 'HUD_Wanted_Sounds' } -- frontend sound, set to nil for silence

---------------------------------------------------------------------
-- Spawning / lifetime
---------------------------------------------------------------------
Config.SpawnDistance   = { min = 60.0, max = 90.0 } -- ahead of the player
Config.SpawnSpread     = 12.0   -- metres between bandits
Config.DespawnDistance = 350.0  -- player rides this far away = ambush ends
Config.MaxDuration     = 600    -- seconds before a running ambush is cleaned up
Config.CorpseTime      = 240    -- seconds bodies stay for looting after the fight
Config.UseBlips        = true   -- red enemy blips (BLIP_STYLE_ENEMY, as in ambush_* scripts)
Config.DeathCleanupDelay = 15   -- seconds the ambush lingers after the player dies (bandits ride off), then it is removed

-- Safe spawn points: every bandit is placed on a point that passes these checks
Config.SpawnChecks = {
    Attempts      = 8,      -- tries to find a safe centre / bandit position before giving up
    MinNormalZ    = 0.80,   -- ground steepness: 1.0 = flat, lower = steeper. Steeper ground is rejected
    MaxWaterDepth = 0.4,    -- metres of water above the ground; deeper is rejected (rivers, lakes)
    AvoidInteriors = true,  -- reject points inside an interior
}

-- Horse models used by the SP ambush scripts (ambush_*.c, build 1436)
Config.Horses = {
    'A_C_HORSE_MORGAN_FLAXENCHESTNUT',
    'A_C_HORSE_TENNESSEEWALKER_REDROAN',
    'A_C_HORSE_AMERICANSTANDARDBRED_BLACK',
    'A_C_HORSE_KENTUCKYSADDLE_GREY',
    'A_C_HORSE_MUSTANG_WILDBAY',
}

---------------------------------------------------------------------
-- Gang behaviour (applies to every gang, can be overridden per gang)
---------------------------------------------------------------------
Config.LowHealth        = 0.30   -- a bandit below this fraction of max health may flee or surrender (per gang chances below)
Config.SurrenderTime    = 20     -- seconds a surrendered bandit stands with hands up before running
Config.FleeEscapeDistance = 120.0 -- a fleeing bandit this far from the player has escaped and is removed

---------------------------------------------------------------------
-- Gangs (models / relationship groups / weapons from ambush_*.c)
-- display names live in locales (gang_<key>)
-- accuracy & shootRate mirror the difficulty table in ambush_odr_road_robbery.c
--
-- optional per gang:
--   fleeChance / surrenderChance  % of bandits that run / give up when badly hurt (0 = fight to the death)
--   reinforcements = { chance, count = { min, max }, delay }  a second group rides in from behind (delay in seconds,
--                     or sooner once the first group is nearly beaten)
--   sniper = { chance, weapon }   one bandit takes high ground and fires from range
--   bounty = { min, max }         cash per killed bandit (default Config.Bounty.PerBandit)
--   loot = { cash = { min, max }, items = { ... } }   replaces the global loot below for this gang
---------------------------------------------------------------------
Config.Gangs = {
    odriscoll = {
        weight = 35,
        relGroup = 'REL_GANG_ODRISCOLL',
        models = { 'G_M_M_UNIDUSTER_01', 'G_M_M_UNIDUSTER_02', 'G_M_M_UNIDUSTER_03', 'G_M_M_UNIDUSTER_04', 'G_M_M_UNIDUSTER_05' },
        weapons = { 'WEAPON_REVOLVER_CATTLEMAN', 'WEAPON_REPEATER_CARBINE', 'WEAPON_SHOTGUN_DOUBLEBARREL' },
        count = { 3, 5 },
        mountedChance = 60,
        accuracy = { 40, 50 },
        shootRate = { 80, 110 },
        fleeChance = 25,
        surrenderChance = 15,
        reinforcements = { chance = 20, count = { 2, 3 }, delay = 45 },
    },
    raiders = {
        weight = 25,
        relGroup = 'REL_GANG_LEMOYNE_RAIDERS',
        models = { 'G_M_Y_UNIEXCONFEDS_01', 'G_M_Y_UNIEXCONFEDS_02', 'G_M_O_UNIEXCONFEDS_01' },
        weapons = { 'WEAPON_REVOLVER_SCHOFIELD', 'WEAPON_REPEATER_CARBINE' },
        count = { 3, 6 },
        mountedChance = 50,
        accuracy = { 45, 60 },
        shootRate = { 90, 110 },
        fleeChance = 15,
        surrenderChance = 10,
        sniper = { chance = 40, weapon = 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK' },
        reinforcements = { chance = 15, count = { 2, 3 }, delay = 50 },
        loot = { cash = { min = 3, max = 12 }, items = {} },
    },
    murfree = {
        weight = 20,
        relGroup = 'REL_GANG_MURFREE_BROOD',
        models = { 'G_M_M_UNIINBRED_01' },
        weapons = { 'WEAPON_MELEE_KNIFE', 'WEAPON_SHOTGUN_DOUBLEBARREL', 'WEAPON_REVOLVER_CATTLEMAN' },
        count = { 3, 5 },
        mountedChance = 0,       -- Murfrees attack on foot
        accuracy = { 15, 25 },
        shootRate = { 80, 100 },
        fleeChance = 0,          -- they fight to the death
        surrenderChance = 0,
        reinforcements = { chance = 25, count = { 2, 3 }, delay = 40 },
        loot = { cash = { min = 1, max = 5 }, items = {} },
    },
    skinners = {
        weight = 20,
        relGroup = 'REL_GANG_SKINNER_BROTHERS',
        models = { 'G_M_M_UNIMOUNTAINMEN_01' },
        weapons = { 'WEAPON_REVOLVER_DOUBLEACTION', 'WEAPON_REPEATER_CARBINE', 'WEAPON_MELEE_KNIFE' },
        count = { 3, 5 },
        mountedChance = 40,
        accuracy = { 30, 45 },
        shootRate = { 80, 110 },
        fleeChance = 35,
        surrenderChance = 20,
        reinforcements = { chance = 10, count = { 1, 2 }, delay = 45 },
    },
}

---------------------------------------------------------------------
-- Optional integrations (each one is skipped when its resource is not started)
---------------------------------------------------------------------
Config.Hooks = {
    -- rsg-reputation: honor changes the chance. The first matching entry wins, so order them from the most extreme.
    -- { maxHonor = n }: applies at or below n.  { minHonor = n }: applies at or above n.
    Honor = {
        Enabled = true,
        Chance = {
            { maxHonor = -600, mult = 2.0 },   -- notorious outlaws are hunted
            { maxHonor = -200, mult = 1.5 },
            { minHonor = 400,  mult = 0.6 },   -- honorable riders are left alone more often
        },
    },
    -- rsg-skills: a veteran rider meets bigger gangs (+Extra bandits for every PerLevels levels, up to MaxExtra)
    Scaling = { Enabled = true, Skill = 'horsemanship', PerLevels = 10, Extra = 1, MaxExtra = 2 },
}

-- rsg-economy decides which town area the player is in (nearest town within Radius metres).
-- chance multiplies the trigger chance, gangs multiplies each gang's weight (missing = 1.0, 0 = never there).
Config.Zones = {
    Enabled = true,
    Radius = 2500.0,
    Areas = {
        valentine   = { chance = 1.0, gangs = { odriscoll = 2.0 } },
        rhodes      = { chance = 1.2, gangs = { raiders = 3.0, odriscoll = 0.5 } },
        saint_denis = { chance = 0.8, gangs = { raiders = 3.0, odriscoll = 0.5 } },
        strawberry  = { chance = 1.0, gangs = { odriscoll = 2.0, skinners = 1.5 } },
        blackwater  = { chance = 1.0, gangs = { odriscoll = 1.5 } },
        annesburg   = { chance = 1.3, gangs = { murfree = 3.0, skinners = 2.0, raiders = 0.2 } },
        van_horn    = { chance = 1.2, gangs = { murfree = 2.0, skinners = 2.0 } },
        armadillo   = { chance = 1.0, gangs = { odriscoll = 1.5, raiders = 0.2, murfree = 0.0 } },
        tumbleweed  = { chance = 1.1, gangs = { odriscoll = 1.5, raiders = 0.2, murfree = 0.0 } },
    },
}

---------------------------------------------------------------------
-- Rewards for beating the gang (server side, once per ambush)
---------------------------------------------------------------------
-- cash for every killed bandit, paid with AddMoney('cash'). JobMultipliers is matched against the player's job
-- name first, then the job type, and only while they are on duty (lawmen are type 'leo').
Config.Bounty = {
    Enabled = true,
    PerBandit = { min = 4, max = 8 },
    JobMultipliers = { leo = 2.0, bountyhunter = 1.5 },
}

Config.Rewards = {
    MinKilledPct = 50,       -- at least this % of the bandits must be dead to count as a win (the rest may have fled or surrendered)
    Honor        = 4,        -- rsg-reputation honor for beating the gang
    Standing     = 3,        -- rsg-reputation standing in the nearby town
    MercyHonor   = 1,        -- extra honor for every bandit left alive (surrendered or fled), up to MercyMax
    MercyMax     = 3,
    Skill        = { name = 'horsemanship', xp = 20 }, -- rsg-skills XP (nil to disable)
}

---------------------------------------------------------------------
-- Loot (server side, per body)
---------------------------------------------------------------------
Config.LootDistance = 3.0
Config.LootTime     = 3000      -- ms progress bar
Config.LootCash     = { min = 1, max = 8 }   -- dollars, paid with AddMoney('cash')
Config.LootItems    = {
    -- { item = 'resource_wood', min = 1, max = 2, chance = 20 },  -- use item names from your server
}

-- A rare strongbox: with this chance per ambush ONE of the bandits carries extra cash (and items) that only the server knows about
Config.Strongbox = {
    Enabled = true,
    Chance  = 5,                         -- % per ambush
    Cash    = { min = 40, max = 120 },
    Items   = {
        -- { item = 'goldbar', min = 1, max = 1, chance = 25 },
    },
}
