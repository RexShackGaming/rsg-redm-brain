Config = {}

-- Debug Settings
Config.Debug = false

-- ============================================================================
-- CHOPPING SETTINGS (wild trees + processing dropped logs into wood)
-- ============================================================================
Config.Chopping = {
    RequireAxe = true,
    AxeItem = 'axe',
    AxeBreakChance = 10,        -- % chance the axe breaks per successful chop (rolled server-side)
    TreeChopDuration = 7000,    -- ms
    LogChopDuration = 5000,     -- ms
    ChopCooldownMs = 10000,     -- ms, per-player cooldown after a completed chop
    InteractDistance = 1.5,     -- ox_target distance for trees
    ServerDistance = 4.0,       -- server-side max distance between player and a log/tree/wood pile
    RaycastDistance = 3.0,      -- how far in front of the player a seed is planted
    ActionTimeoutMs = 20000,    -- ms, how long a server-authorised chop stays valid before it expires
}

-- ============================================================================
-- TREE PLANTING SETTINGS (Growing) - plant anywhere on the map
-- ============================================================================
Config.Planting = {
    SeedItem = 'tree_seeds',
    WaterItem = 'fullbucket',
    RequireWater = true,         -- false = trees grow through every stage without watering
    MaxTreesPerPlayer = 10,
    MinPlantDistance = 3.0,
    PlantDuration = 5000,        -- ms
    WaterDuration = 8000,        -- ms
    RenderDistance = 40.0,       -- tree props only spawn client-side within this distance (perf)
    ProgressBarDistance = 12.0,  -- owner sees the growth progress bar within this distance
    GrowthTickSeconds = 10,      -- how often the server checks for trees that finished a stage
    GrowthDurations = {          -- seconds per stage
        60, -- Stage 1 -> 2
        60, -- Stage 2 -> 3
        60  -- Stage 3 -> 4 (ready to chop)
    },
    StageModels = {
        'p_tree_birch_01_sapling',
        'p_tree_birch_02_sapling',
        'p_tree_birch_03',
        'p_tree_birch_03_md'
    }
}

-- ============================================================================
-- LOG & WOOD SETTINGS
-- ============================================================================
Config.Items = {
    Wood = 'resource_wood',      -- item given when picking up processed wood
    WoodAmountFromLog = 4,       -- wood piles spawned per processed log (1 item each)
    SpawnRadius = 3.0,           -- scatter radius of wood piles around the log
    GroundDespawnMinutes = 30,   -- dropped logs / wood piles left on the ground are removed after this
}

Config.Models = {
    GroundLog = `p_cedar_log_06x`,
    WoodProp = `p_cs_woodpile01x`,
    CarryLog = `p_cedar_log_06x`
}

-- Carry settings
Config.Carry = {
    AnimDict = 'amb_wander@code_human_hay_bale_wander@male_a@base',
    AnimClip = 'base',
    AnimFlag = 25,
    MoveClipset = '',            -- optional movement clipset while carrying ('' = none)
    AttachBox = {
        bone = 7966,
        pos = { x = 0.0, y = 0.30, z = -0.10 },
        rot = { x = 0.0, y = 0.0, z = -90.0 }
    },
}

-- ============================================================================
-- WAGON SETTINGS
-- ============================================================================
Config.Wagon = {
    Model = `LOGWAGON`,
    MaxLogsOnWagon = 5,
    LogStackModel = `p_cedar_log_06x`,
    LoadDistance = 4.0, -- server-side max distance from wagon to load/unload a log
    LogPositions = {
        -- Base layer (3 logs)
        { x = -0.4, y = -0.8, z = 0.25, rotX = 0, rotY = 0, rotZ = 90 },
        { x = 0.0, y = -0.8, z = 0.25, rotX = 0, rotY = 0, rotZ = 90 },
        { x = 0.4, y = -0.8, z = 0.25, rotX = 0, rotY = 0, rotZ = 90 },
        -- Top layer (2 logs stacked above)
        { x = -0.2, y = -0.8, z = 0.65, rotX = 0, rotY = 0, rotZ = 90 },
        { x = 0.2, y = -0.8, z = 0.65, rotX = 0, rotY = 0, rotZ = 90 },
    },
}

-- ============================================================================
-- WAGON SELL LOCATIONS (sell a full wagon load of logs for cash)
-- Add as many locations as you like - each has its own price.
-- Fields: coords, radius, price, blip = { sprite, scale, label (optional) } or blip = false
-- ============================================================================
Config.WagonSellLocations = {
    {
        coords = vector3(-1808.22, -596.15, 154.95),
        radius = 5.0,
        price = 100,
        blip = { sprite = 1904459580, scale = 0.2 } -- label: optional override, defaults to locale 'blip_sell_logs'
    },
    {
        coords = vector3(-1395.34, -223.84, 100.86),
        radius = 5.0,
        price = 100,
        blip = { sprite = 1904459580, scale = 0.2 } -- label: optional override, defaults to locale 'blip_sell_logs'
    },
    {
        coords = vector3(1053.37, -1125.14, 67.89),
        radius = 5.0,
        price = 100,
        blip = { sprite = 1904459580, scale = 0.2 } -- label: optional override, defaults to locale 'blip_sell_logs'
    },
    {
        coords = vector3(2870.63, 1468.58, 68.03),
        radius = 5.0,
        price = 100,
        blip = { sprite = 1904459580, scale = 0.2 } -- label: optional override, defaults to locale 'blip_sell_logs'
    },
}

-- ============================================================================
-- TARGET MODELS (Wild trees that can be chopped)
-- ============================================================================
Config.Trees = {
    -- POPLAR & WILLOW
    `p_tree_poplar_01`, `p_tree_poplar_02`, `p_tree_riv_poplar_01`, `p_tree_riv_poplar_02`,
    `p_tree_willow_01`, `p_tree_willow_02`,

    -- CEDAR & FIR TREES
    `p_sap_fir_ac_sim`, `p_sap_fir_snow_aa_sim`,
    `p_sap_fir_snow_ab_sim`, `p_sap_fir_snow_ac_sim`, `p_tree_cedar_03b_snow`,
    `p_tree_cedar_03b_snow_deep`, `p_tree_cedar_decor_01`, `p_tree_cedar_decor_02`,
    `p_tree_cedar_s_deep_02_c`,

    -- DOUGLAS FIR
    `p_tree_douglasfir_01`, `p_tree_douglasfir_02`,
    `p_tree_douglasfir_05`, `p_tree_douglasfir_snow_01`, `p_tree_douglasfir_snow_01a`,
    `p_tree_douglasfir_snow_02`, `p_tree_douglasfir_snow_03`, `p_tree_douglasfir_snow_03a`,
    `p_tree_douglasfir_snow_03b`, `p_tree_douglasfir_snow_03c`, `p_tree_douglasfir_snow_03d`,
    `p_tree_douglasfir_snow_04`, `p_tree_douglasfir_snow_04a`, `p_tree_douglasfir_snow_05`,
    `p_tree_douglasfir_snow_05a`,

    -- LODGEPOLE PINE
    `p_tree_lodgepole_01`, `p_tree_lodgepole_02`, `p_tree_lodgepole_02_bv`, `p_tree_lodgepole_02_bv_l`,
    `p_tree_lodgepole_02_bv_s`, `p_tree_lodgepole_03`, `p_tree_lodgepole_04`, `p_tree_lodgepole_05`,
    `p_tree_lodgepole_06`, `p_tree_lodgepole_07`, `p_tree_lodgepole_07a`, `p_tree_lodgepole_roots_01`,
    `p_tree_lodgepole_snow_01`, `p_tree_lodgepole_snow_01a`, `p_tree_lodgepole_snow_02`,
    `p_tree_lodgepole_snow_02a`, `p_tree_lodgepole_snow_02b`, `p_tree_lodgepole_snow_03`,
    `p_tree_lodgepole_snow_04`,

    -- LONGLEAF PINE
    `p_tree_longleafpine_01`, `p_tree_longleafpine_02`, `p_tree_longleafpine_03`, `p_tree_longleafpine_04`,

    -- PONDEROSA PINE
    `p_tree_pine_ponderosa_01`, `p_tree_pine_ponderosa_02`, `p_tree_pine_ponderosa_03`,
    `p_tree_pine_ponderosa_04`, `p_tree_pine_ponderosa_05`, `p_tree_pine_ponderosa_06`,
    `p_tree_pine_ponderosa_07`, `p_tree_ponderosa_sap_01`, `p_tree_ponderosa_sap_02`,
    `p_tree_ponderosa_sap_03`,

    -- WHITE PINE
    `p_tree_whitepine_01`, `p_tree_whitepine_02`, `p_tree_whitepine_03`, `p_tree_whitepine_04`,
    `p_tree_whitepine_05`, `p_tree_whitepine_06`, `p_tree_whitepine_07`, `p_tree_whitepine_08`,
    `p_tree_whitepine_09`, `p_tree_whitepine_10`, `p_tree_whitepine_sap_01`, `p_tree_whitepine_sap_02`,
    `p_tree_whitepine_sap_03`,

    -- BURNT/DEAD TREES
    `p_tree_pine_burnt_01`, `p_tree_pine_burnt_01a`, `p_tree_pine_burnt_02`, `p_tree_pine_burnt_02a`,
    `p_tree_pine_burnt_log_aa`, `p_tree_pine_burnt_log_ab`, `p_tree_pine_dead_01`, `p_tree_pine_dead_02`,
    `p_tree_pine_newburnt_01`, `p_tree_pine_newburnt_02`, `p_tree_pine_newburnt_03`, `p_tree_pine_newburnt_04`,
    `p_tree_pine_newburnt_log_01`, `p_tree_pine_newburnt_log_02`, `p_tree_engoak_dead`,
    `p_tree_fallen_pine_01`, `p_tree_fallen_pine_01bc`, `p_tree_fallen_pine_02`,

    -- MAPLE TREES
    `p_tree_maple_02`, `p_tree_maple_03`, `p_tree_maple_03_dead`, `p_tree_maple_03_lg`,
    `p_tree_maple_03_lg_m`, `p_tree_maple_03_lg_os`, `p_tree_maple_03_md`, `p_tree_maple_03_md_bv`,
    `p_tree_maple_03_md_bv_l`, `p_tree_maple_03_md_bv_s`, `p_tree_maple_03_os`, `p_tree_maple_04_md`,
    `p_tree_maple_04_md_m`, `p_tree_maple_05_lg`, `p_tree_maple_05_lg_ch`, `p_tree_maple_05_lg_ch2`,
    `p_tree_maple_05_lg_m`, `p_tree_maple_bent_01`, `p_tree_maple_bent_02`, `p_tree_maple_bent_03`,
    `p_tree_maple_dead_s_01`, `p_tree_maple_s_01`, `p_tree_maple_s_02`, `p_tree_maple_s_03`,
    `p_tree_maple_s_04`, `p_tree_mapleroot_01`, `p_tree_mapleroot_02`, `p_tree_riv_maple_01`,
    `p_tree_riv_maple_04`, `p_sap_maple_aa_sim`, `p_sap_maple_ab_sim`, `p_sap_maple_ac_sim`,
    `p_sap_maple_ad_sim`, `p_sap_maple_ba_sim`, `p_sap_maple_bb_sim`, `p_sap_maple_bc_sim`,

    -- OAK TREES
    `p_tree_angel_oak`, `p_tree_blue_oak_01`, `p_tree_cottonwood_01`, `p_tree_cottonwood_02`,
    `p_tree_cottonwood_03`, `p_tree_cottonwood_04`, `p_tree_engoak_01`, `p_tree_engoak_01_lg`,
    `p_tree_engoak_02`, `p_tree_engoak_moss_01`, `p_tree_engoak_moss_01_os`, `p_tree_engoak_nbx_01`,
    `p_tree_hangingtree_moss`, `p_tree_hangingtreebranch`, `p_tree_hangingtreeoak01`,
    `p_tree_liveoak_01`, `p_tree_liveoak_moss_01`, `p_tree_oak_01`, `p_tree_oak_braith_03`,
    `p_tree_poor_joe_oak`, `p_tree_white_oak_01`, `p_tree_white_oak_01_ch`, `p_tree_white_oak_02`,

    -- REDWOOD
    `p_tree_log_redwood_01`, `p_tree_redwood_05`, `p_tree_redwood_05_lg`, `p_tree_redwood_05_md`,
    `p_tree_redwood_05_mf`, `p_tree_redwood_05_sm`,

    -- TROPICAL/PALM
    `p_tree_bamboo_01`, `p_tree_bamboo_01_crt`, `p_tree_banana_01_crt`, `p_tree_banana_01_lg`,
    `p_tree_banana_01_md_crt`, `p_tree_banana_dead_01_lg`, `p_tree_banyan_01`, `p_tree_magnolia_01`,
    `p_tree_magnolia_02`, `p_tree_magnolia_02_lg`, `p_tree_magnolia_02_lg_os`, `p_tree_magnolia_02_md`,
    `p_tree_magnolia_02_vine`, `p_tree_magnolia_03`, `p_tree_magnolia_03_crt`, `p_tree_magnolia_04`,
    `p_tree_mangrove_02`, `p_tree_mangrove_03`, `p_tree_palm_fan_03a`, `p_tree_palm_fan_04b`,
    `p_tree_palm_fan_06`, `p_tree_palm_fan_bea_03b`, `p_tree_palm_fan_low_ba`, `p_tree_palm_s_01a`,
    `p_tree_palm_s_01d`, `p_tree_palm_s_01e`, `p_tree_palm_s_01f`, `p_sap_magnolia_aa_sim`,

    -- SWAMP TREES
    `p_tree_baldcypress_01_dead`, `p_tree_baldcypress_01a`, `p_tree_baldcypress_01a_os`,
    `p_tree_baldcypress_02`, `p_tree_baldcypress_02_os`, `p_tree_baldcypress_02_sm_a`,
    `p_tree_baldcypress_03`, `p_tree_baldcypress_03_dead`, `p_tree_baldcypress_03_script`,
    `p_tree_baldcypress_04_dead`, `p_tree_baldcypress_04_sm_a`, `p_tree_baldcypress_04a`,
    `p_tree_baldcypress_05`, `p_tree_baldcypress_05_sm_a`, `p_tree_baldcypress_05a`,
    `p_tree_baldcypress_06a`, `p_tree_baldcypress_06b`, `p_tree_baldcypress_07`,
    `p_tree_baldcypress_grave`, `p_tree_baldcypress_knees_01`, `p_tree_baldcypress_knees_02`,
    `p_tree_branch_01_swamp`, `p_tree_branch_02_swamp`, `p_tree_log_01_swamp`,
    `p_tree_log_01_swamp_sim`, `p_tree_stump_01_swamp`, `p_tree_stump_02_swamp`,
    `p_sap_cypress_aa_sim`, `p_sap_cypress_ab_sim`,

    -- MISC TREES
    `p_tree_apple_01`, `p_tree_burntstump_01`, `p_tree_burntstump_03`, `p_tree_hickory_01`,
    `p_tree_hickory_02`, `p_tree_jacada_01`, `p_tree_lightning_01`, `p_tree_lightning_02`,
    `p_tree_lightning_03`, `p_tree_lightning_04`, `p_tree_mesquite_01`, `p_tree_mesquite_01_dead`,
    `p_tree_riodel_01`, `p_tree_rusolive_dead`, `p_tree_rusolive_dead001`, `p_tree_w_r_cedar_dead`,
    `p_tree_w_r_cedar_dead_01`, `p_tree_w_r_cedar_dead_02`, `rdr_nrml_branch_aa_sim`,
    `rdr_pine_branch_aa_sim`, `rdr_pine_branch_ab_sim`, `rdr2_tree_beech`, `rdr2_tree_brokentree`,
    `rdr2_tree_gimlet`, `rdr2_tree_rata01`, `rdr2_tree_rata02`, `rdr2_tree_riverbirch`,
    `rdr2_tree_sycamore`, `rdr2_tree_utahjuniper`
}
