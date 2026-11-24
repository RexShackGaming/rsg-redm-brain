Config = {}

-- settings
Config.Difficulty = 500 -- ms each reel pull lasts; re-issued while the reel key is held (lower = fish stops sooner when you let go)
Config.ReelInSpeed = 1.5 -- how fast a hooked fish swims towards you while reeling (higher = quicker catch)
Config.ReelSpeed = 0.025 -- how fast the hook reels in towards the player
Config.Debug = false
Config.StruggleChance = 0.3 -- chance (0.0-1.0) per tick that a hooked fish struggles
Config.FishWeightMultiplier = 54.25 -- converts internal game weight units into displayed KG
Config.CatchCooldown = 3000 -- ms a player must wait between accepted fish catches (anti-spam/anti-exploit)
Config.MaxRawFishWeight = 0.15 -- sanity cap on the raw (pre-multiplier) weight value accepted from clients
Config.GroundPickup = true -- picking a fish up off the ground stores it (no bait needed, weight 0). Set false to close this off
Config.GroundPickupLimit = { Max = 10, Window = 3600 } -- max ground pickups per player per Window seconds (the server cannot verify a carried fish, so it is capped)
Config.MinCatchTime = 8000 -- ms that must pass between putting bait on the rod and an accepted catch (cast + wait + reel cannot be faster)
Config.EnforceBaitList = true -- true = a fish only bites, and the server only accepts it, when it is in Config.BaitsPerFish for the bait used
Config.BiteChance = 0.3 -- chance (0.0-1.0) per second that a fish next to the hook bites
Config.Log = true -- send catches to rsg-log ('fishing' channel)

-- line tension / snapping: reeling while a fish struggles strains the line; at 100% it snaps (fish and bait lost)
Config.LineSnap = {
    Enabled = true,
    Gain    = 0.004, -- tension added per frame while reeling a struggling fish (scaled up for bigger fish)
    Recover = 0.006, -- tension lost per frame otherwise
}

-- fishing sounds (soundset and names from RDR3 decompiled fishing_core.c, build 1436). Set a name to '' to mute it
Config.Sounds = {
    Enabled  = true,
    Soundset = 'MGFSH_Sounds',
    Names = {
        Hooked   = 'LARGE_BITE_FISH_HOOKED',
        Struggle = 'STRUGGLE',
        Snap     = 'Snap',
        Caught   = 'Caught',
    },
}

-- controller rumble { duration ms, frequency 0-255 } (SET_CONTROL_SHAKE)
Config.Rumble = {
    Enabled  = true,
    Bite     = { 250, 180 },
    Struggle = { 120, 90 },
    Snap     = { 500, 255 },
    Caught   = { 200, 120 },
}

-- fishing music (music events from fishing_core.c)
Config.Music = {
    Enabled = true,
    Start   = 'BOB_FISHING_START',
    Stop    = 'BOB_FISHING_STOP',
}

-- key labels shown in the top-left controls HUD (display only)
Config.ControlKeys = {
    UseBait   = 'TAB',  -- shown when the rod has no bait (open inventory)
    Prepare   = 'RMB',
    Cast      = 'LMB',
    Hook      = 'LMB',
    ResetCast = 'SHIFT',
    ReelLure  = 'CTRL',
    ReelIn    = 'SPACE',
    KeepFish  = 'LMB',
    ThrowFish = 'RMB',
}

-- controls watched for the live "pressed" highlight in the HUD (hash or "INPUT_NAME")
Config.ControlInputs = {
    Prepare   = 'INPUT_AIM',
    Cast      = 0x07CE1E61,
    Hook      = 'INPUT_ATTACK',
    ResetCast = 0x8FFC75D6,
    ReelLure  = 'INPUT_DUCK',
    ReelIn    = 0xFBD7B3E6,
    KeepFish  = 'INPUT_ATTACK',
    ThrowFish = 'INPUT_AIM',
}

-- bobber visibility (helps players see where their float is)
Config.BobberMarker = {
    Enabled    = true,
    ScreenIcon = true,   -- on-screen float image that follows the bobber (turns into a fish when hooked)
    ScreenIconSize = 46, -- px
}

-- fishing baits
Config.Baits = {
    "p_baitbread01x",
    "p_baitcorn01x",
    "p_baitcheese01x",
    "p_baitcricket01x",
    "p_baitworm01x",
    "p_crawdad01x",
    "p_finishedragonfly01x",
    "p_finisdfishlure01x",
    "p_finishdcrawd01x",
    "p_finishedragonflylegendary01x",
    "p_finisdfishlurelegendary01x",
    "p_finishdcrawdlegendary01x",
    "p_lgoc_spinner_v4",
    "p_lgoc_spinner_v6",
}

-- bait to catch fish
Config.BaitsPerFish = {
    ["p_baitbread01x"] = {
        "A_C_FISHBLUEGIL_01_MS",
        "A_C_FISHBLUEGIL_01_SM",
        "A_C_FISHPERCH_01_MS",
        "A_C_FISHPERCH_01_SM",
        "A_C_FISHBULLHEADCAT_01_MS",
        "A_C_FISHBULLHEADCAT_01_SM",
        "A_C_FISHRAINBOWTROUT_01_MS",
        "A_C_FISHLARGEMOUTHBASS_01_MS",
        "A_C_FISHREDFINPICKEREL_01_MS",
        "A_C_FISHREDFINPICKEREL_01_SM",
    },
    ["p_baitcorn01x"] = {
        "A_C_FISHBLUEGIL_01_MS",
        "A_C_FISHBLUEGIL_01_SM",
        "A_C_FISHPERCH_01_MS",
        "A_C_FISHPERCH_01_SM",
        "A_C_FISHBULLHEADCAT_01_MS",
        "A_C_FISHBULLHEADCAT_01_SM",
        "A_C_FISHRAINBOWTROUT_01_MS",
        "A_C_FISHLARGEMOUTHBASS_01_MS",
        "A_C_FISHREDFINPICKEREL_01_MS",
        "A_C_FISHREDFINPICKEREL_01_SM",
    },
    ["p_baitcheese01x"] = {
        "A_C_FISHBLUEGIL_01_MS",
        "A_C_FISHBLUEGIL_01_SM",
        "A_C_FISHPERCH_01_MS",
        "A_C_FISHPERCH_01_SM",
        "A_C_FISHBULLHEADCAT_01_MS",
        "A_C_FISHBULLHEADCAT_01_SM",
        "A_C_FISHRAINBOWTROUT_01_MS",
        "A_C_FISHLARGEMOUTHBASS_01_MS",
        "A_C_FISHREDFINPICKEREL_01_MS",
        "A_C_FISHREDFINPICKEREL_01_SM",
    },
    ["p_baitcricket01x"] = {
        "A_C_FISHBLUEGIL_01_MS",
        "A_C_FISHBLUEGIL_01_SM",
        "A_C_FISHLAKESTURGEON_01_LG",
        "A_C_FISHLARGEMOUTHBASS_01_LG",
        "A_C_FISHLARGEMOUTHBASS_01_MS",
        "A_C_FISHMUSKIE_01_LG",
        "A_C_FISHPERCH_01_MS",
        "A_C_FISHPERCH_01_SM",
        "A_C_FISHRAINBOWTROUT_01_LG",
        "A_C_FISHRAINBOWTROUT_01_MS",
        "A_C_FISHREDFINPICKEREL_01_MS",
        "A_C_FISHREDFINPICKEREL_01_SM",
        "A_C_FISHSMALLMOUTHBASS_01_LG",
    },
    ["p_baitworm01x"] = {
        "A_C_FISHBLUEGIL_01_MS",
        "A_C_FISHBLUEGIL_01_SM",
        "A_C_FISHCHAINPICKEREL_01_MS",
        "A_C_FISHCHAINPICKEREL_01_SM",
        "A_C_FISHLAKESTURGEON_01_LG",
        "A_C_FISHLARGEMOUTHBASS_01_LG",
        "A_C_FISHLARGEMOUTHBASS_01_MS",
        "A_C_FISHPERCH_01_MS",
        "A_C_FISHPERCH_01_SM",
        "A_C_FISHRAINBOWTROUT_01_MS",
        "A_C_FISHREDFINPICKEREL_01_MS",
        "A_C_FISHREDFINPICKEREL_01_SM",
        "A_C_FISHROCKBASS_01_MS",
        "A_C_FISHSALMONSOCKEYE_01_ML",
        "A_C_FISHSALMONSOCKEYE_01_MS",
        "A_C_FISHSMALLMOUTHBASS_01_MS",
    },
    ["p_crawdad01x"] = {
        "A_C_FISHBLUEGIL_01_MS",
        "A_C_FISHBLUEGIL_01_SM",
        "A_C_FISHMUSKIE_01_LG",
        "A_C_FISHPERCH_01_MS",
        "A_C_FISHPERCH_01_SM",
        "A_C_FISHREDFINPICKEREL_01_MS",
        "A_C_FISHREDFINPICKEREL_01_SM",
    },
    ["p_finishedragonfly01x"] = {
        "A_C_FISHBLUEGIL_01_MS",
        "A_C_FISHBLUEGIL_01_SM",
        "A_C_FISHBULLHEADCAT_01_MS",
        "A_C_FISHBULLHEADCAT_01_SM",
        "A_C_FISHLAKESTURGEON_01_LG",
        "A_C_FISHNORTHERNPIKE_01_LG",
        "A_C_FISHPERCH_01_MS",
        "A_C_FISHPERCH_01_SM",
        "A_C_FISHREDFINPICKEREL_01_MS",
        "A_C_FISHREDFINPICKEREL_01_SM",
        "A_C_FISHSALMONSOCKEYE_01_LG",
        "A_C_FISHSALMONSOCKEYE_01_ML",
        "A_C_FISHSALMONSOCKEYE_01_MS",
        "A_C_FISHSMALLMOUTHBASS_01_MS",
    },
    ["p_finisdfishlure01x"] = {
        "A_C_FISHBLUEGIL_01_MS",
        "A_C_FISHBLUEGIL_01_SM",
        "A_C_FISHBULLHEADCAT_01_MS",
        "A_C_FISHBULLHEADCAT_01_SM",
        "A_C_FISHLAKESTURGEON_01_LG",
        "A_C_FISHLONGNOSEGAR_01_LG",
        "A_C_FISHNORTHERNPIKE_01_LG",
        "A_C_FISHPERCH_01_MS",
        "A_C_FISHPERCH_01_SM",
        "A_C_FISHREDFINPICKEREL_01_MS",
        "A_C_FISHREDFINPICKEREL_01_SM",
        "A_C_FISHSALMONSOCKEYE_01_LG",
        "A_C_FISHSALMONSOCKEYE_01_ML",
        "A_C_FISHSALMONSOCKEYE_01_MS",
        "A_C_FISHSMALLMOUTHBASS_01_MS",
    },
    ["p_finishdcrawd01x"] = {
        "A_C_FISHBLUEGIL_01_MS",
        "A_C_FISHBLUEGIL_01_SM",
        "A_C_FISHBULLHEADCAT_01_MS",
        "A_C_FISHBULLHEADCAT_01_SM",
        "A_C_FISHCHAINPICKEREL_01_SM",
        "A_C_FISHLAKESTURGEON_01_LG",
        "A_C_FISHLONGNOSEGAR_01_LG",
        "A_C_FISHNORTHERNPIKE_01_LG",
        "A_C_FISHPERCH_01_MS",
        "A_C_FISHPERCH_01_SM",
        "A_C_FISHREDFINPICKEREL_01_MS",
        "A_C_FISHREDFINPICKEREL_01_SM",
        "A_C_FISHSALMONSOCKEYE_01_LG",
        "A_C_FISHSALMONSOCKEYE_01_ML",
        "A_C_FISHSALMONSOCKEYE_01_MS",
        "A_C_FISHSMALLMOUTHBASS_01_MS",
    },
    ["p_finishedragonflylegendary01x"] = {
        "A_C_FISHBLUEGIL_01_MS",
        "A_C_FISHBLUEGIL_01_SM",
        "A_C_FISHBULLHEADCAT_01_MS",
        "A_C_FISHBULLHEADCAT_01_SM",
        "A_C_FISHCHAINPICKEREL_01_MS",
        "A_C_FISHCHAINPICKEREL_01_SM",
        "A_C_FISHCHANNELCATFISH_01_LG",
        "A_C_FISHCHANNELCATFISH_01_XL",
        "A_C_FISHLAKESTURGEON_01_LG",
        "A_C_FISHNORTHERNPIKE_01_LG",
        "A_C_FISHLONGNOSEGAR_01_LG",
        "A_C_FISHPERCH_01_MS",
        "A_C_FISHPERCH_01_SM",
        "A_C_FISHREDFINPICKEREL_01_MS",
        "A_C_FISHREDFINPICKEREL_01_SM",
        "A_C_FISHSALMONSOCKEYE_01_LG",
        "A_C_FISHSALMONSOCKEYE_01_ML",
        "A_C_FISHSALMONSOCKEYE_01_MS",
        "A_C_FISHSMALLMOUTHBASS_01_MS",
    },
    ["p_finisdfishlurelegendary01x"] = {
        "A_C_FISHBLUEGIL_01_MS",
        "A_C_FISHBULLHEADCAT_01_MS",
        "A_C_FISHCHAINPICKEREL_01_MS",
        "A_C_FISHCHANNELCATFISH_01_LG",
        "A_C_FISHCHANNELCATFISH_01_XL",
        "A_C_FISHLAKESTURGEON_01_LG",
        "A_C_FISHLONGNOSEGAR_01_LG",
        "A_C_FISHNORTHERNPIKE_01_LG",
        "A_C_FISHPERCH_01_MS",
        "A_C_FISHREDFINPICKEREL_01_MS",
        "A_C_FISHSALMONSOCKEYE_01_LG",
        "A_C_FISHSALMONSOCKEYE_01_ML",
        "A_C_FISHSALMONSOCKEYE_01_MS",
        "A_C_FISHSMALLMOUTHBASS_01_LG",
        "A_C_FISHSMALLMOUTHBASS_01_MS",
    },
    ["p_finishdcrawdlegendary01x"] = {
        "A_C_FISHBLUEGIL_01_MS",
        "A_C_FISHBULLHEADCAT_01_MS",
        "A_C_FISHCHAINPICKEREL_01_MS",
        "A_C_FISHCHANNELCATFISH_01_LG",
        "A_C_FISHCHANNELCATFISH_01_XL",
        "A_C_FISHLAKESTURGEON_01_LG",
        "A_C_FISHLONGNOSEGAR_01_LG",
        "A_C_FISHNORTHERNPIKE_01_LG",
        "A_C_FISHPERCH_01_MS",
        "A_C_FISHREDFINPICKEREL_01_MS",
        "A_C_FISHSALMONSOCKEYE_01_LG",
        "A_C_FISHSALMONSOCKEYE_01_ML",
        "A_C_FISHSALMONSOCKEYE_01_MS",
        "A_C_FISHSMALLMOUTHBASS_01_LG",
        "A_C_FISHSMALLMOUTHBASS_01_MS",
    },
    ["p_lgoc_spinner_v4"] = {
        "A_C_FISHBLUEGIL_01_MS",
        "A_C_FISHBLUEGIL_01_SM",
        "A_C_FISHBULLHEADCAT_01_SM",
        "A_C_FISHCHAINPICKEREL_01_MS",
        "A_C_FISHCHAINPICKEREL_01_SM",
        "A_C_FISHLARGEMOUTHBASS_01_LG",
        "A_C_FISHLARGEMOUTHBASS_01_MS",
        "A_C_FISHLONGNOSEGAR_01_LG",
        "A_C_FISHNORTHERNPIKE_01_LG",
        "A_C_FISHPERCH_01_MS",
        "A_C_FISHPERCH_01_SM",
        "A_C_FISHREDFINPICKEREL_01_MS",
        "A_C_FISHREDFINPICKEREL_01_SM",
        "A_C_FISHROCKBASS_01_MS",
        "A_C_FISHROCKBASS_01_SM",
        "A_C_FISHSALMONSOCKEYE_01_LG",
        "A_C_FISHSALMONSOCKEYE_01_ML",
        "A_C_FISHSALMONSOCKEYE_01_MS",
        "A_C_FISHSMALLMOUTHBASS_01_LG",
        "A_C_FISHSMALLMOUTHBASS_01_MS",
    },
    ["p_lgoc_spinner_v6"] = {
        "A_C_FISHBLUEGIL_01_MS",
        "A_C_FISHBLUEGIL_01_SM",
        "A_C_FISHBULLHEADCAT_01_MS",
        "A_C_FISHBULLHEADCAT_01_SM",
        "A_C_FISHCHAINPICKEREL_01_MS",
        "A_C_FISHCHAINPICKEREL_01_SM",
        "A_C_FISHLARGEMOUTHBASS_01_LG",
        "A_C_FISHLARGEMOUTHBASS_01_MS",
        "A_C_FISHLONGNOSEGAR_01_LG",
        "A_C_FISHNORTHERNPIKE_01_LG",
        "A_C_FISHPERCH_01_MS",
        "A_C_FISHPERCH_01_SM",
        "A_C_FISHREDFINPICKEREL_01_MS",
        "A_C_FISHREDFINPICKEREL_01_SM",
        "A_C_FISHROCKBASS_01_MS",
        "A_C_FISHROCKBASS_01_SM",
        "A_C_FISHSALMONSOCKEYE_01_LG",
        "A_C_FISHSALMONSOCKEYE_01_ML",
        "A_C_FISHSALMONSOCKEYE_01_MS",
        "A_C_FISHSMALLMOUTHBASS_01_LG",
        "A_C_FISHSMALLMOUTHBASS_01_MS",
    }
}

-- weight bands: raw min/max kg (before the 0.25 factor) and the fish size (0-1) used for sound and line tension
Config.WeightBands = {
    small  = { 0.5, 3.0, size = 0.2 },
    medium = { 4.0, 6.0, size = 0.5 },
    large  = { 14.0, 20.0, size = 1.0 },
}
Config.WeightFactor = 0.25 -- applied to the rolled band weight (kept from the original tuning)

-- species families (journal and records are kept per family; sizes of one fish share a family)
Config.Species = {
    bluegill                = 'Blue Gil',
    bullheadcat             = 'Bullhead Catfish',
    chainpickerel           = 'Chain Pickerel',
    channelcatfish          = 'Channel Catfish',
    lakesturgeon            = 'Lake Sturgeon',
    largemouthbass          = 'Large Mouth Bass',
    longnosegar             = 'Long Nose Gar',
    muskie                  = 'Muskie',
    northernpike            = 'Northern Pike',
    perch                   = 'Perch',
    rainbowtrout            = 'Rainbow Trout',
    redfinpickerel          = 'Red Fin Pickerel',
    rockbass                = 'Rock Bass',
    salmonsockeye           = 'Salmon Sockeye',
    smallmouthbass          = 'Small Mouth Bass',
    salmonsockeye_legendary = 'Legendary Salmon Sockeye',
}
Config.SpeciesOrder = { 'bluegill', 'perch', 'rockbass', 'bullheadcat', 'chainpickerel', 'redfinpickerel', 'largemouthbass',
    'smallmouthbass', 'rainbowtrout', 'salmonsockeye', 'channelcatfish', 'longnosegar', 'muskie', 'northernpike',
    'lakesturgeon', 'salmonsockeye_legendary' }

-- fish data: model = { display name, weight band, species family }. The inventory item is the model name in lower case
Config.fishData = {
    A_C_FISHBLUEGIL_01_MS        = { "Blue Gil (Medium)", 'small', 'bluegil' },
    A_C_FISHBLUEGIL_01_SM        = { "Blue Gil (Small)", 'small', 'bluegil' },
    A_C_FISHBULLHEADCAT_01_MS    = { "Bullhead Cat (Medium)", 'small', 'bullheadcat' },
    A_C_FISHBULLHEADCAT_01_SM    = { "Bullhead Cat (Small)", 'small', 'bullheadcat' },
    A_C_FISHCHAINPICKEREL_01_MS  = { "Chain Pickerel (Medium)", 'small', 'chainpickerel' },
    A_C_FISHCHAINPICKEREL_01_SM  = { "Chain Pickerel (Small)", 'small', 'chainpickerel' },
    A_C_FISHCHANNELCATFISH_01_LG = { "Channel Catfish (Large)", 'large', 'channelcatfish' },
    A_C_FISHCHANNELCATFISH_01_XL = { "Channel Catfish (Extra Large)", 'large', 'channelcatfish' },
    A_C_FISHLAKESTURGEON_01_LG   = { "Lake Sturgeon (Large)", 'large', 'lakesturgeon' },
    A_C_FISHLARGEMOUTHBASS_01_LG = { "Large Mouth Bass (Large)", 'medium', 'largemouthbass' },
    A_C_FISHLARGEMOUTHBASS_01_MS = { "Large Mouth Bass (Medium)", 'medium', 'largemouthbass' },
    A_C_FISHLONGNOSEGAR_01_LG    = { "Long Nose Gar (Large)", 'large', 'longnosegar' },
    A_C_FISHMUSKIE_01_LG         = { "Muskie (Large)", 'large', 'muskie' },
    A_C_FISHNORTHERNPIKE_01_LG   = { "Northern Pike (Large)", 'large', 'northernpike' },
    A_C_FISHPERCH_01_MS          = { "Perch (Medium)", 'small', 'perch' },
    A_C_FISHPERCH_01_SM          = { "Perch (Small)", 'small', 'perch' },
    A_C_FISHRAINBOWTROUT_01_LG   = { "Rainbow Trout (Large)", 'medium', 'rainbowtrout' },
    A_C_FISHRAINBOWTROUT_01_MS   = { "Rainbow Trout (Medium)", 'medium', 'rainbowtrout' },
    A_C_FISHREDFINPICKEREL_01_MS = { "Red Fin Pickerel (Medium)", 'small', 'redfinpickerel' },
    A_C_FISHREDFINPICKEREL_01_SM = { "Red Fin Pickerel (Small)", 'small', 'redfinpickerel' },
    A_C_FISHROCKBASS_01_MS       = { "Rock Bass (Medium)", 'small', 'rockbass' },
    A_C_FISHROCKBASS_01_SM       = { "Rock Bass (Small)", 'small', 'rockbass' },
    A_C_FISHSALMONSOCKEYE_01_LG  = { "Salmon Sockeye (Large)", 'medium', 'salmonsockeye_legendary' },
    A_C_FISHSALMONSOCKEYE_01_ML  = { "Salmon Sockeye (Medium-Large)", 'medium', 'salmonsockeye' },
    A_C_FISHSALMONSOCKEYE_01_MS  = { "Salmon Sockeye (Medium)", 'medium', 'salmonsockeye' },
    A_C_FISHSMALLMOUTHBASS_01_LG = { "Small Mouth Bass (Large)", 'medium', 'smallmouthbass' },
    A_C_FISHSMALLMOUTHBASS_01_MS = { "Small Mouth Bass (Medium)", 'medium', 'smallmouthbass' },
}

-- rsg-skills integration (optional). Needs the rsg-skills resource; does nothing when it is not started.
Config.Skills = {
    Enabled = true,
    Skill   = 'fishing', -- skill key in rsg-skills
    CatchXP = 10,        -- XP per fish caught (rsg-skills applies its own multipliers and cap)
}

-- =========================================================
-- Regions: which fish can be hooked where
-- =========================================================
-- The game spawns the fish; this decides which of them will bite. The state is read from the water under the hook.
-- State keys on the left are the game's zone names (same as rsg-zonenotify); the value is the region id, which is also
-- the rsg-reputation / rsg-economy region id. Set Enabled = false to let every fish bite everywhere.
Config.Regions = {
    Enabled = true,
    StateZones = {
        Ambarino = 'ambarino', lemoyne = 'lemoyne', NewHanover = 'new_hanover', NewAustin = 'new_austin', Guarma = 'guarma',
        WestElizabeth = 'west_elizabeth', LowerWestElizabeth = 'west_elizabeth', UpperWestElizabeth = 'west_elizabeth',
    },
    -- species families that can bite per region. A region that is not listed has no limit.
    -- These are a starting point: change them to suit your server.
    Pools = {
        ambarino       = { 'rainbowtrout', 'salmonsockeye', 'northernpike', 'lakesturgeon', 'perch', 'rockbass', 'smallmouthbass' },
        new_hanover    = { 'bluegill', 'bullheadcat', 'chainpickerel', 'channelcatfish', 'largemouthbass', 'muskie', 'northernpike',
                           'perch', 'rainbowtrout', 'redfinpickerel', 'rockbass', 'smallmouthbass', 'lakesturgeon' },
        lemoyne        = { 'bluegill', 'bullheadcat', 'chainpickerel', 'channelcatfish', 'largemouthbass', 'longnosegar', 'perch',
                           'redfinpickerel', 'rockbass' },
        west_elizabeth = { 'bluegill', 'perch', 'rainbowtrout', 'salmonsockeye', 'smallmouthbass', 'largemouthbass', 'rockbass',
                           'lakesturgeon', 'channelcatfish' },
        new_austin     = { 'bluegill', 'bullheadcat', 'channelcatfish', 'largemouthbass', 'perch' },
    },
    -- the legendary salmon only bites at these waters (zone names as in rsg-zonenotify). Add `coords` and `radius`
    -- to a spot and the server also checks the player is that close when the fish is stored.
    LegendarySpots = {
        { zone = 'WATER_UPPER_MONTANA_RIVER' },
        { zone = 'WATER_LOWER_MONTANA_RIVER' },
        -- { zone = 'WATER_DAKOTA_RIVER', coords = vector3(0.0, 0.0, 0.0), radius = 150.0 },
    },
}

-- =========================================================
-- Bite conditions: time of day and weather
-- =========================================================
-- Config.BiteChance is multiplied by the time and weather factors (and the rsg-skills bite_chance perk).
-- The controls HUD shows the result as Poor / Fair / Good.
Config.BiteModifiers = {
    Enabled = true,
    MinChance = 0.05, MaxChance = 0.85, -- final chance is kept between these
    Time = { -- game hours, from <= hour < to. A range with from > to wraps past midnight
        { from = 5,  to = 9,  mult = 1.30 }, -- dawn
        { from = 17, to = 21, mult = 1.30 }, -- dusk
        { from = 11, to = 15, mult = 0.80 }, -- midday glare
        { from = 22, to = 5,  mult = 0.90 }, -- night
    },
    Weather = { -- rsg-weather names. Anything not listed counts as 1.0
        drizzle = 1.20, rain = 1.30, shower = 1.20, overcast = 1.10, overcastdark = 1.10, misty = 1.10, fog = 1.10,
        sunny = 0.90, thunder = 0.70, thunderstorm = 0.50, hurricane = 0.40,
    },
    PoorBelow = 0.85, -- total factor below this is shown as Poor, at or above GoodFrom as Good
    GoodFrom  = 1.15,
}

-- =========================================================
-- rsg-skills perks (optional; perks are defined in rsg-skills/shared/config.lua under fishing)
-- =========================================================
Config.Perks = {
    BiteChance   = 'bite_chance',   -- % added to the bite chance
    LineStrength = 'line_strength', -- % less line tension gained while reeling a struggling fish
    Trophy       = 'rare_chance',   -- % chance that a hooked fish is rolled from the heavier half of its weight band
}

-- =========================================================
-- Angler's journal, records and leaderboard
-- =========================================================
Config.AutoDatabase = true -- create the tables automatically; set false to import install.sql manually

Config.Journal = {
    Command = 'fishjournal', -- opens the journal / records / leaderboard; false = no command
    Key     = false,         -- optional rebindable key name (e.g. 'J'); needs rsg-core 3.5.0+; false = no key
}

Config.Records = {
    Enabled  = true,
    Announce = true,  -- tell everyone when a server record is beaten
    Reward   = 0,     -- cash paid to the player who beats a record (0 = none)
    TopCount = 10,    -- rows on the top anglers board
}

-- rsg-reputation actions (optional; the actions are defined in rsg-reputation/shared/config.lua)
Config.Reputation = {
    Enabled = true,
    NewSpecies = 'fishing_discovery', -- first catch of a species
    Record     = 'fishing_record',    -- beat a server record
    Complete   = 'fishing_master',    -- journal complete
}

-- while the journal is open: block game controls but keep push-to-talk working
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}
