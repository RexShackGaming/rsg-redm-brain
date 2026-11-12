Config = {}

---------------------------------
-- settings
---------------------------------
Config.MiningTime              = 10000
Config.CooldownTime            = 180000 -- personal cooldown after mining a node
Config.RequiredItem            = 'pickaxe'
Config.GemChance               = 15
Config.NotificationDuration    = 5000
Config.DrillTime               = 10000
Config.DrillBatchPause         = 500   -- ms pause between rocks when batch drilling (each rock takes DrillTime)
Config.DrillMaxBatch           = 50    -- most rocks drilled in one batch
-- rocks listed in the foreman's drill menu
Config.DrillableRocks = {
    { item = 'resource_rock',      label = 'rock_label' },
    { item = 'resource_salt_rock', label = 'saltrock_label' },
}

-- While the drill menu is open, block game controls but allow push-to-talk.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}
Config.AdminPermission         = 'admin'
Config.AdminDeleteDistance     = 5.0
Config.AdminPlaceDistance      = 15.0 -- max distance from the admin when placing a rock with rsg-gizmo
Config.AdminPlaceAllowInterior = true -- allow placing rocks inside interiors (mines count as interiors)
Config.AutoCreateDatabase      = true  -- create rsg_rocks_zones table on start
Config.AutoSeedDefaultZones    = true  -- insert default Annesburg/Gaptooth/Grizzlies rocks if table empty

-- Global node deplete: after anyone mines a rock, it is empty for everyone for this long
Config.GlobalDepleteEnabled    = true
Config.GlobalDepleteTime       = 120000 -- ms (2 minutes)

-- Pickaxe durability (uses item metadata `quality`, 0-100)
Config.PickaxeDurability       = true
Config.PickaxeMaxQuality       = 100
Config.PickaxeDegradeMin       = 1
Config.PickaxeDegradeMax       = 3
Config.PickaxeBreakAtZero      = true  -- false = keep the pickaxe at 0 quality; it can't mine until its quality is raised again (repair / sharpening script)

-- Mining XP (stored in player metadata)
Config.MiningXP = {
    enabled = true,
    metaKey = 'miningxp',
    perMine = 5,
    perDrill = 3,
    perSmelt = 2,
    -- level = minimum total XP
    levels = {
        [1] = 0,
        [2] = 50,
        [3] = 150,
        [4] = 350,
        [5] = 700,
        [6] = 1200,
        [7] = 2000,
        [8] = 3200,
        [9] = 5000,
        [10] = 7500,
    },
    -- bonus to max reward amount per level above 1 (0.1 = +10% per level)
    yieldBonusPerLevel = 0.1,
}

Config.MineDistanceTolerance     = 3.0
Config.WorkshopDistanceTolerance = 10.0
Config.MiningTimeTolerance       = 750
Config.DrillTimeTolerance        = 500
Config.MiningSessionGrace        = 30000

---------------------------------
-- props / models / animations
---------------------------------
Config.SpawnRockProps    = true
Config.DebugTarget       = false
Config.RockSpawnDistance = 120.0
Config.RockModel         = 'mp_sca_rock_grp_l_03'
Config.PickaxeModel      = 'p_pickaxe01x'
Config.WorkshopPropset   = 'pg_mp_workshop03x'
Config.BlipStyle         = 1664425300

Config.MiningScenario    = 'WORLD_HUMAN_PICKAXE_WALL'
Config.MiningAnimDict    = 'amb_work@world_human_pickaxe@wall@male_d@base'
Config.MiningAnimClip    = 'base'
Config.DrillAnimDict     = 'mech_inventory@crafting@fallbacks'
Config.DrillAnimClip     = 'full_craft_and_stow'
Config.DrillAnimFlag     = 27

---------------------------------
-- miner's hat (needs the item; worn near mining rocks and/or toggled by using the item,
-- original hat restored when it comes off)
---------------------------------
Config.MiningHat = {
    enabled        = true,
    requireItem    = true,        -- hat only works while this item is in the inventory
    item           = 'mininghat', -- useable item: use it to put the hat on / take it off
    autoWear       = true,        -- put the hat on automatically near mining rocks
    enterDistance  = 12.0, -- metres from the nearest mining rock to put the hat on
    exitDistance   = 20.0, -- metres to take it off again (must be > enterDistance)
    debug          = false, -- print nearest rock distance + hat on/off to the F8 console
    useProjector   = true, -- projector lamp prop on the hat (has its own white light; not used while light.enabled = true)
    bone           = 'HairScale_B',
    hatModel       = 's_hat_miner01x',
    projectorModel = 's_movieprojection01x',
    -- offsets: x, y, z, rotX, rotY, rotZ
    hatOffset       = { 0.0, -0.03, 0.01, -9.0, 4.0, 0.0 },
    projectorOffset = { 0.01, -0.070, 0.09, -80.0, 16.0, 4.0 },

    -- hat lamp light + settings panel (hidden until /minerlight is used, drag to move)
    light = {
        enabled       = true,
        command       = 'minerlight', -- /minerlight: focus the panel to change the light
        defaultColor  = '#ffd9a0',
        defaultBright = 60,   -- 0-100 %
        defaultSpread = 8.0,  -- metres (light radius)
        minSpread     = 2.0,
        maxSpread     = 20.0,
        maxIntensity  = 12.0, -- intensity at 100 % brightness
        forward       = 1.0,  -- metres ahead of the head the light sits (spread only changes its radius)
        height        = 0.10, -- metres above the head bone
        syncToOthers  = true, -- other players see your lamp (state bag)
        drawDistance  = 60.0, -- metres to draw other players' lamps
    },
}

Config.DistanceSpawn = 20.0
Config.FadeIn        = true

--------------------------------
-- Mining locations: DB table rsg_rocks_zones
-- Admin: /rockadmin /addrock /delrock /togglerock /nearbrocks /reloadrocks
--------------------------------

Config.WorkshopTents = {
    {
        name       = 'Annesburg Mining Camp',
        coords     = vector4(2818.82, 1359.12, 70.62, 236.61),
        blipcoords = vector3(2818.82, 1359.12, 70.62),
        blipsprite = 'blip_region_caravan',
        blipscale  = 0.2,
        blipname   = 'Annesburg Mining Camp',
        npcmodel   = `u_m_m_bht_mineforeman`,
        npccoords  = vector4(2818.06, 1360.32, 70.68, 45.27),
        scenario   = 'WORLD_HUMAN_CLIPBOARD',
        showblip   = true
    },
    {
        name       = 'Gaptooth Mining Camp',
        coords     = vector4(-5972.25, -3240.97, -21.65, 156.29),
        blipcoords = vector3(-5972.25, -3240.97, -21.65),
        blipsprite = 'blip_region_caravan',
        blipscale  = 0.2,
        blipname   = 'Gaptooth Mining Camp',
        npcmodel   = `u_m_m_bht_mineforeman`,
        npccoords  = vector4(-5970.84, -3240.00, -21.65, 339.70),
        scenario   = 'WORLD_HUMAN_CLIPBOARD',
        showblip   = true
    },
    {
        name       = 'Grizzlies Mining Camp',
        coords     = vector4(-1403.07, 1125.83, 228.33, 229.09),
        blipcoords = vector3(-1403.07, 1125.83, 228.33),
        blipsprite = 'blip_region_caravan',
        blipscale  = 0.2,
        blipname   = 'Grizzlies Mining Camp',
        npcmodel   = `u_m_m_bht_mineforeman`,
        npccoords  = vector4(-1404.16, 1125.72, 228.53, 40.30),
        scenario   = 'WORLD_HUMAN_CLIPBOARD',
        showblip   = true
    },
}

Config.Rewards = {
    -- oreType keys stay rock/saltrock (zone type); item names match shared items.lua
    ['rock']     = { item = 'resource_rock',      minAmount = 1, maxAmount = 3 },
    ['saltrock'] = { item = 'resource_salt_rock', minAmount = 1, maxAmount = 2 },
}

-- Weighted drill outputs (higher weight = more common)
Config.RockOutputs = {
    { item = 'resource_clay',        weight = 25 },
    { item = 'resource_coal',        weight = 22 },
    { item = 'resource_copper_ore',  weight = 15 },
    { item = 'resource_iron_ore',    weight = 14 },
    { item = 'resource_nitrate_ore', weight = 8 },
    { item = 'resource_sulfur_ore',  weight = 8 },
    { item = 'resource_zink_ore',    weight = 6 }, -- note: items.lua uses zink spelling
    { item = 'resource_lead_ore',    weight = 5 },
    { item = 'resource_silver_ore',  weight = 3 },
    { item = 'resource_gold_ore',    weight = 2 },
}

Config.SaltRockOutputs = {
    { item = 'resource_salt',        weight = 60 },
    { item = 'resource_nitrate_ore', weight = 25 },
    { item = 'resource_sulfur_ore',  weight = 15 },
}

Config.GemOutputs = {
    { item = 'resource_diamond_uncut',  weight = 10 },
    { item = 'resource_ruby_uncut',     weight = 20 },
    { item = 'resource_emerald_uncut',  weight = 20 },
    { item = 'resource_opal_uncut',     weight = 25 },
    { item = 'resource_sapphire_uncut', weight = 25 },
}

-- Camp smelting recipes (input ore -> bar). Items must exist in shared items.
Config.SmeltingEnabled = true
Config.SmeltRecipes = {
    { input = 'resource_iron_ore',   inputAmount = 5, output = 'resource_iron_bar',   outputAmount = 1, time = 8000 },
    { input = 'resource_copper_ore', inputAmount = 5, output = 'resource_copper_bar', outputAmount = 1, time = 8000 },
    { input = 'resource_gold_ore',   inputAmount = 5, output = 'resource_gold_bar',   outputAmount = 1, time = 12000 },
    { input = 'resource_silver_ore', inputAmount = 5, output = 'resource_silver_bar', outputAmount = 1, time = 10000 },
    { input = 'resource_lead_ore',   inputAmount = 5, output = 'resource_lead_bar',   outputAmount = 1, time = 8000 },
    { input = 'resource_zink_ore',   inputAmount = 5, output = 'resource_zinc_bar',   outputAmount = 1, time = 8000 },
}
