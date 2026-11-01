Config = {}

Config.Debug = false -- leave off in production; verbose per-gather/per-craft tracing

-- Where the crafting UI loads item icons from (rsg-inventory's image folder).
Config.InventoryImagePath = 'nui://rsg-inventory/html/images/'

-- Streaming / scope-loading ranges (world units)
Config.ScopeRangeLoad = 100.0          -- distance at which a herb node starts streaming in
Config.ScopeRangeUnload = 120.0        -- distance at which a loaded node streams back out
Config.NearbyRange = 15.0              -- radius refreshed once/sec for interaction checks
Config.PickupRange = 3.0               -- client-side distance within which a node can be picked
Config.CompositeLoadTimeoutMs = 10000  -- max time to wait for a composite asset to stream in

-- Gathering
Config.GatherDurationMs = 3000            -- length of the gather progress bar

-- When true, gathering herbs and opening the mystery box show an ox_lib
-- progress circle (cancellable) for GatherDurationMs. When false, the bar is
-- hidden - the action still takes GatherDurationMs, just isn't shown or
-- cancellable.
Config.GatherProgressBarEnabled = false
Config.GatherCooldownMs = 2500            -- server-side minimum time between gather attempts per player
Config.ScopeRangeGather = 3.5             -- server-side distance check before a gather is accepted
Config.SuppressionWearoffSeconds = 10 * 60 -- how long a gathered node stays empty before it regrows

-- Tonic crafting
-- The menu has a single entry point: using the 'mortarpestle' item from the
-- inventory (RSGCore.Functions.CreateUseableItem in server/server.lua).
-- There is no command and no client export - that's intentional, so the
-- item is the only way in.
Config.TonicCraftingEnabled = true        -- master switch for the tonic crafting system
Config.TonicCraftCooldownMs = 1500        -- server-side minimum time between craft requests per player

-- When true, crafting shows an ox_lib progress circle (cancellable) for the
-- recipe's durationMs. When false, the bar is skipped entirely - crafting
-- still takes the full durationMs (the animation sequence below still
-- plays out over it), it just isn't shown or cancellable, and the craft
-- always completes once that time passes.
Config.TonicCraftProgressBarEnabled = false

-- Animation(s) played on the player during crafting. dict is streamed in on
-- demand and released again once the sequence finishes. clips are played
-- back to back, in order, each one run to completion (not looped, not
-- gated by a fixed Wait() timer - the next clip only starts once the
-- current one actually finishes), and the ped's tasks are cleared right
-- after the last clip ends. Set enabled = false to skip this entirely and
-- always use the generic standing scenario instead.
Config.TonicCraftAnim = {
    enabled = true,
    dict = 'script_re@herbalistcamp@leadin@rc1',
    clips = { 'enter_herbalist', 'exit_herbalist' },
    animDictLoadTimeoutMs = 5000, -- give up and fall back to a scenario if the dict never streams in
}

-- Scripted camera shown for the duration of the crafting animation, framed
-- on the player's ped (positioned out in front of them, pointed back at
-- them) rather than the normal follow/third-person cam. Positioned relative
-- to the ped each time crafting starts, so it works regardless of which way
-- the player is facing or where they are.
Config.TonicCraftCamera = {
    enabled = true,
    distance = 3.5,     -- how far in front of the ped (world units) the camera sits
    height = 0.55,      -- how far above the ped's base coord the camera sits
    fov = 40.0,
    transitionMs = 500, -- ease in/out time when the cam activates/deactivates
}

-- Health/stamina boost applied when a finished tonic is consumed (used from
-- the inventory), via the ENABLE_ATTRIBUTE_OVERPOWER native (0xF6A7C08DF2E28B28)
-- - the same one the game's own tonics/bitters use for the golden "overpower"
-- top-up on the health/stamina core, which then depletes naturally like the
-- rest of the core. attributeIndex constants below (PA_HEALTH/PA_STAMINA)
-- match the RDR3 ePedAttributes enum ordering; adjust if a game build ever
-- changes that ordering. value is 0.0-1.0 (fraction of the core topped up).
Config.TonicAttributeIndex = {
    health = 0,  -- PA_HEALTH
    stamina = 1, -- PA_STAMINA
}

-- Animation played on the player when a tonic is actually drunk (consumed
-- from the inventory), ported from rsg-consume's bottle-drinking animation.
-- clips play back to back in order, each held for its own duration (ms)
-- before the next starts; the ped's tasks are cleared once the last one
-- ends. Skipped (falls through with no animation) if the player is mounted
-- or in a vehicle, or if the dict fails to stream in within the timeout.
-- prop is the bottle model attached to the ped's right hand for the
-- duration of the animation (the anim dict only poses the hand as if
-- gripping a bottle - it doesn't render one on its own). boneName/offsets
-- position it in the grip, matching rsg-consume's generic "Drink" case.
-- Deleted automatically once the clips finish.
Config.TonicDrinkAnim = {
    enabled = true,
    dict = 'mech_inventory@drinking@bottle_cylinder_d1-3_h30-5_neck_a13_b2-5',
    clips = {
        { anim = 'uncork', duration = 1000 },
        { anim = 'chug_a', duration = 3000 },
    },
    animDictLoadTimeoutMs = 5000,
    prop = 's_craftedtonic_02x',
    propBone = 'PH_R_HAND',
    propOffset = { x = 0.0, y = 0.0, z = 0.04 },
    propRotation = { x = 0.0, y = 0.0, z = 0.0 },
}

-- Keyed by the tonic's inventory item name (Config.Tonics[n].output.item).
-- Omit healthBoost/staminaBoost on an entry to skip that core for that
-- tonic. Tonics not listed here do nothing extra when consumed.
Config.TonicEffects = {
    tonic_healing  = { healthBoost = 0.5 },
    tonic_stamina  = { staminaBoost = 0.5 },
    tonic_antidote = { healthBoost = 0.3 },
    tonic_energy   = { staminaBoost = 0.35, healthBoost = 0.1 },
}

-- Minimum time (ms) a player must wait between drinking tonics, enforced
-- server-side (authoritative - can't be bypassed by a modified client) and
-- shared across every tonic in Config.TonicEffects, so stacking different
-- tonics back to back can't skip the wait. Set to 0 to disable.
Config.TonicUseCooldownMs = 5 * 60 * 1000 -- 5 minutes

-- When true, only players whose current job matches Config.TonicCraftingJobName
-- (any grade) can open/use the crafting menu. Both the client (for UX - hides
-- the menu instead of letting a non-herbalist open it) and the server (for
-- security - the actual check that can't be bypassed by a modified client)
-- enforce this.
Config.LockTonicCraftingToJob = false
Config.TonicCraftingJobName = 'herbalist'

Config.MysteryBox = {
    enabled = true,
    prop = 'mp005_p_mp_collectorbox01x', -- the physical prop players see/interact with on the map

    -- Every possible spawn location. Only one of these is "live" (has a box
    -- sitting on it) at any given time - the rest sit empty until the box
    -- relocates onto them. Fill this in with real in-game coordinates.
    coords = {
        vec3(-254.20, 636.64, 118.60),
        vec3(-1298.23, 408.43, 95.38),
        vec3(-1766.23, -371.10, 159.58),
        vec3(-1776.60, -2324.62, 42.68),
        vec3(-3346.78, -2854.35, -6.09),
        vec3(-3979.85, -2147.21, -6.46),
        vec3(-5212.60, -2151.88, 11.99),
        vec3(-5631.24, -2950.89, 5.88),
        vec3(3029.51, 556.37, 44.74),
        vec3(2957.99, 1335.68, 44.06),
        vec3(2960.58, 2233.29, 159.54),
        vec3(2891.67, 2371.94, 157.65),
        vec3(2622.62, 2101.64, 174.02),
        vec3(2470.72, 1747.47, 86.85),
        vec3(2533.60, 1197.74, 163.97),
        vec3(2145.75, -498.19, 41.63),
        vec3(2095.67, -611.86, 45.13),
        vec3(1882.47, -772.91, 42.46),
        vec3(2744.68, -1397.48, 46.18),
        vec3(2725.44, -1067.40, 47.40),
        vec3(2268.82, -1367.36, 41.84),
        vec3(2093.37, -1811.94, 42.88),
    },

    -- How long (seconds) a box stays at its current location before it's
    -- removed and a new location (different from the current one, if more
    -- than one coord is configured) is picked and a fresh box spawned there.
    -- Picking up the box also triggers an immediate relocation rather than
    -- waiting out the rest of this timer.
    relocateAfterSeconds = 45 * 60,

    pickupRange = 3.0,       -- client-side distance within which the box can be opened
    scopeRangeGather = 3.5,  -- server-side distance check before an open request is accepted
    scopeRangeLoad = 100.0,  -- distance at which the box prop starts streaming in
    scopeRangeUnload = 120.0, -- distance at which the box prop streams back out

    -- Regular herbs the box can contain, and how many of them (picked with
    -- repetition, so the same herb can turn up more than once) are rewarded
    -- alongside the guaranteed rare orchid below.
    herbCountMin = 3,
    herbCountMax = 6,
    herbPool = {
        'herb_agarita', 'herb_alaskan_ginseng', 'herb_american_ginseng', 'herb_bay_boletus',
        'herb_bitterweed', 'blackberry', 'herb_black_current', 'herb_bloodflower',
        'herb_burdock_root', 'herb_cardinal_flower', 'herb_chanterelles', 'herb_choc_daisy',
        'herb_common_bullrush', 'herb_creek_plum', 'herb_creeping_thyme', 'herb_crows_garlic',
        'herb_desert_sage', 'herb_english_mace', 'herb_evergreen_huckleberry', 'herb_golden_currant',
        'herb_hummingbird_sage', 'herb_indian_tobacco', 'herb_milkweed', 'herb_oleander_sage',
        'herb_oregano', 'herb_parasol_mushroom', 'herb_prairie_poppy', 'raspberry',
        'herb_red_sage', 'herb_wild_feverfew', 'herb_wild_mint',
        'herb_wild_rhubarb', 'herb_wintergreen_berry', 'herb_wisteria', 'herb_yarrow',
    },

    -- Every box always contains exactly one of these, picked at random -
    -- this is the "rare orchid" the box is built around.
    orchidPool = {
        'herb_acuna_star_orchid', 'herb_cigar_orchid', 'herb_clam_shell_orchid',
        'herb_dragons_mouth_orchid', 'herb_ghost_orchid', 'herb_lady_of_the_night_orchid',
        'herb_moccasin_flower_orchid', 'herb_night_scented_orchid', 'herb_queens_orchid',
        'herb_rat_tail_orchid', 'herb_sparrows_egg_orchid', 'herb_spider_orchid',
        'herb_vanilla_orchid',
    },
}

-- Tonic recipes. Each entry:
--   id          unique recipe identifier
--   label       locale key (locales/*.json) for the display name shown in the crafting UI
--   description locale key (locales/*.json) for the short flavour/help text shown in the UI
--   image       filename (in rsg-inventory's image folder) used for the output preview
--   durationMs  how long the crafting progress bar takes
--   ingredients list of { item = <inventory item name>, amount = <required count> }
--   output      { item = <inventory item name>, amount = <amount granted> }
Config.Tonics = {
    {
        id = 'tonic_healing',
        label = 'tonic_healing_label', -- locale key (locales/*.json)
        description = 'tonic_healing_description', -- locale key (locales/*.json)
        image = 'tonic_healing.png',
        durationMs = 8000,
        ingredients = {
            { item = 'herb_yarrow',    amount = 2 },
            { item = 'herb_wild_mint', amount = 1 },
        },
        output = { item = 'tonic_healing', amount = 1 },
    },
    {
        id = 'tonic_stamina',
        label = 'tonic_stamina_label', -- locale key (locales/*.json)
        description = 'tonic_stamina_description', -- locale key (locales/*.json)
        image = 'tonic_stamina.png',
        durationMs = 10000,
        ingredients = {
            { item = 'herb_american_ginseng', amount = 2 },
            { item = 'herb_alaskan_ginseng',  amount = 1 },
        },
        output = { item = 'tonic_stamina', amount = 1 },
    },
    {
        id = 'tonic_antidote',
        label = 'tonic_antidote_label', -- locale key (locales/*.json)
        description = 'tonic_antidote_description', -- locale key (locales/*.json)
        image = 'tonic_antidote.png',
        durationMs = 12000,
        ingredients = {
            { item = 'herb_desert_sage',    amount = 2 },
            { item = 'herb_wild_feverfew',  amount = 2 },
            { item = 'herb_indian_tobacco', amount = 1 },
        },
        output = { item = 'tonic_antidote', amount = 1 },
    },
    {
        id = 'tonic_energy',
        label = 'tonic_energy_label', -- locale key (locales/*.json)
        description = 'tonic_energy_description', -- locale key (locales/*.json)
        image = 'tonic_energy.png',
        durationMs = 6000,
        ingredients = {
            { item = 'herb_bitterweed',    amount = 1 },
            { item = 'blackberry', amount = 2 },
            { item = 'herb_golden_currant', amount = 1 },
        },
        output = { item = 'tonic_energy', amount = 1 },
    },
}
