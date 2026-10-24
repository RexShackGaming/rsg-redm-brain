Config = {}

Config.MapItem      = 'treasure_map'   -- usable item that starts a hunt
Config.RequiredItem = nil              -- e.g. 'shovel' to require a tool, nil = none
Config.Detector     = `WEAPON_KIT_METAL_DETECTOR`   -- femga weapons/weapons.lua
Config.DetectorItem = 'weapon_kit_metal_detector'   -- inventory item name (server check)
Config.DetectRange  = 40.0             -- detector starts picking up signal at this distance
Config.PinpointDistance = 2.5          -- signal maxes out & strongbox can be dug here
-- Bleep (played via NUI so volume can scale with distance)
Config.Bleep = {
    minVolume = 0.05,   -- at edge of DetectRange (0.0 - 1.0)
    maxVolume = 0.6,    -- when pinpointed
    minPitch  = 600,    -- Hz far away
    maxPitch  = 1400,   -- Hz close
    length    = 0.08,   -- seconds per bleep
    slowest   = 1500,   -- ms between bleeps far away
    fastest   = 150,    -- ms between bleeps close
}
Config.SearchRadius = 120.0            -- size of the search circle on the map
Config.DigKey       = 0xF3830D8E       -- [J] INPUT_OPEN_JOURNAL
Config.DigDistance  = 3.0              -- server-checked max distance to dig
Config.DigTime      = 10000            -- ms (length of the dig-up-chest anim scene)
Config.ChestRevealDelay = 3000         -- ms into the dig before the strongbox becomes visible
Config.Cooldown     = 10               -- seconds between digs per player (anti-spam)
Config.ChestModel   = `p_strongbox_muddy_01x`          -- femga objects/object_list.lua
Config.DigAnim      = { dict = 'script@mech@treasure_hunting@chest', playlist = 'PBL_CHEST_01' } -- anim scene (old rsg-treasure)
Config.BlipSprite   = `BLIP_RC_TREASURE_HUNTER`        -- 1491.50 treasure_hunter.c

-- Cash reward (server rolls this)
Config.Cash = { min = 15, max = 60 }

-- Item rewards: each has its own chance (0-100)
Config.Rewards = {
    { item = 'resource_gold_bar',   min = 1, max = 1, chance = 10 },
    { item = 'resource_gold_ore',   min = 1, max = 3, chance = 35 },
    { item = 'resource_silver_bar', min = 1, max = 1, chance = 20 },
}

-- Possible treasure spots (exact dig points; the blip circle is offset so it isn't given away)
Config.Locations = {
    vector3(-1737.50, -519.14, 158.81),
    vector3(-1129.11, 805.51, 119.36),
    vector3(-221.27, 1620.06, 169.18),
    vector3(508.53, 2210.83, 247.44),
    vector3(1587.73, 2002.40, 320.20),
    vector3(2860.59, 1663.55, 126.34),
    vector3(3224.78, 1477.42, 52.49),
    vector3(2992.75, 764.23, 49.28),
    vector3(2472.06, 118.57, 45.25),
    vector3(2371.52, -533.86, 41.95),
    vector3(2219.85, -500.21, 42.10),
    vector3(2033.62, -643.49, 42.49),
    vector3(1716.41, -1167.69, 41.76),
    vector3(1837.98, -1901.84, 42.10),
    vector3(916.05, -2014.79, 45.97),
    vector3(915.52, -1946.49, 45.23),
    vector3(-6039.75, -3309.39, -22.15),
    vector3(-5817.16, -2855.30, -20.36),
    vector3(-5628.01, -2571.07, -2.43),
    vector3(-5166.47, -2127.11, 12.21),
    vector3(-4449.51, -2295.45, 33.78),
    vector3(-1498.44, 2875.25, 465.75),
    vector3(-1412.75, 1162.92, 226.57),
}
