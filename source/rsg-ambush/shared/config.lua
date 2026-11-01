Config = {}

Config.Debug = false            -- true = /testambush command + chance forced to 100

---------------------------------------------------------------------
-- Triggering
---------------------------------------------------------------------
Config.CheckInterval   = 60     -- seconds between ambush rolls
Config.TriggerChance   = 6      -- % chance per roll
Config.RequireMounted  = true   -- only ambush riders (like the SP ambush_* scripts)
Config.BlockInTowns    = true   -- no ambushes inside town zones
Config.PlayerCooldown  = 1800   -- seconds (server enforced) between ambushes per player
Config.MinPlayerSpeed  = 2.0    -- m/s, player must be travelling

---------------------------------------------------------------------
-- Spawning / lifetime
---------------------------------------------------------------------
Config.SpawnDistance   = { min = 60.0, max = 90.0 } -- ahead of the player
Config.SpawnSpread     = 12.0   -- metres between bandits
Config.DespawnDistance = 350.0  -- player rides this far away = ambush ends
Config.MaxDuration     = 600    -- seconds before a running ambush is cleaned up
Config.CorpseTime      = 240    -- seconds bodies stay for looting after the fight
Config.UseBlips        = true   -- red enemy blips (BLIP_STYLE_ENEMY, as in ambush_* scripts)

-- Horse models used by the SP ambush scripts (ambush_*.c, build 1436)
Config.Horses = {
    'A_C_HORSE_MORGAN_FLAXENCHESTNUT',
    'A_C_HORSE_TENNESSEEWALKER_REDROAN',
    'A_C_HORSE_AMERICANSTANDARDBRED_BLACK',
    'A_C_HORSE_KENTUCKYSADDLE_GREY',
    'A_C_HORSE_MUSTANG_WILDBAY',
}

---------------------------------------------------------------------
-- Gangs (models / relationship groups / weapons from ambush_*.c)
-- display names live in locales (gang_<key>)
-- accuracy & shootRate mirror the difficulty table in ambush_odr_road_robbery.c
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
    },
    raiders = {
        weight = 25,
        relGroup = 'REL_GANG_LEMOYNE_RAIDERS',
        models = { 'G_M_Y_UNIEXCONFEDS_01', 'G_M_Y_UNIEXCONFEDS_02', 'G_M_O_UNIEXCONFEDS_01' },
        weapons = { 'WEAPON_REVOLVER_SCHOFIELD', 'WEAPON_REPEATER_CARBINE', 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK' },
        count = { 3, 6 },
        mountedChance = 50,
        accuracy = { 45, 60 },
        shootRate = { 90, 110 },
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
    },
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
