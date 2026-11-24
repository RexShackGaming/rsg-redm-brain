Config = {}

---------------------------------
-- general
---------------------------------
Config.Debug               = false
Config.AutoDatabase        = true    -- create the tables on start; set false and import install.sql manually
Config.MaxPlantsPerPlayer  = 20      -- max active plants per character
Config.MinPlantDistance    = 1.2     -- min distance between two plants
Config.PlaceMaxDistance    = 6.0     -- how far from the player the gizmo can place

-- areas where planting is blocked (checked on the server too). radius in metres, e.g.
-- Config.NoPlantZones = { { coords = vector3(0.0, 0.0, 0.0), radius = 150.0 } }
Config.NoPlantZones = {}

-- farmland: set RequirePlantZone = true to only allow planting inside these areas (checked on the server too), e.g.
-- Config.PlantZones = { { coords = vector3(0.0, 0.0, 0.0), radius = 120.0 } }
Config.RequirePlantZone = false
Config.PlantZones = {}

-- item every planter must carry (not consumed), e.g. a hoe. false = no tool needed
Config.PlantTool = false

-- while the tending UI is open, block game controls but keep push-to-talk working
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

-- custom props with no collision: an invisible blocker is spawned with them (and removed with them)
Config.CollisionModel = 'p_emrfencepost02x'
Config.CollisionProps = {
    ['prop_weed_01'] = true,
    ['prop_weed_02'] = true,
}
Config.InteractDistance    = 1.6     -- distance to tend a plant
Config.RenderDistance      = 60.0    -- props spawn / despawn distance
Config.SyncDistance        = 250.0   -- the server only sends other players' plants within this range (your own are always sent); keep well above RenderDistance
Config.OwnerOnlyHarvest    = true    -- only the planter can harvest / destroy
Config.UseKeyMapping       = true    -- UseTarget = false: rebindable key via rsg-core RegisterKey (false = poll InteractKey)
Config.InteractKeyName     = 'G'     -- default key name when UseKeyMapping = true (players can rebind it in the game's key settings)
Config.InteractKey         = 0x760A9C6F -- [G] control hash, only used when UseTarget = false and UseKeyMapping = false
Config.ReopenAfterAction   = true    -- reopen the plant panel after watering / fertilising / treating
Config.UseTarget           = true    -- use rsg-target zones on plants instead of the [G] prompt
Config.TargetRadius        = 0.8     -- sphere zone radius around each plant
Config.TargetIcon          = 'fa-solid fa-seedling'

---------------------------------
-- growth simulation (server)
---------------------------------
Config.TickInterval        = 30      -- seconds between growth ticks
Config.SaveInterval        = 120     -- seconds between DB saves
Config.WaterDecay          = 100 / 60  -- water lost per minute (100 -> 0 in 60 min)
Config.FertilizerDecay     = 100 / 90  -- fertiliser lost per minute
Config.MinWaterToGrow      = 1       -- plant only grows if water above this
Config.DryDamage           = 5       -- health lost per minute with no water
Config.HealthRegen         = 2       -- health gained per minute while watered
Config.DeadPlantRemoveTime = 30      -- minutes before a dead plant is auto-removed

---------------------------------
-- tending items
---------------------------------
Config.WaterItem           = 'fullbucket'  -- consumed when watering
Config.WaterAmount         = 100           -- water added (capped at 100)

-- fertilisers: the first item in this list the player carries is used. A plant keeps the boost of the last one applied.
--   amount = fertiliser added (max 100), boost = growth multiplier while fertilised,
--   soil   = soil fatigue removed from the patch (compost heals worn-out soil; see Config.Soil)
-- add e.g. { item = 'compost', amount = 60, boost = 1.25, soil = 40 } once the item exists in rsg-core shared items
Config.Fertilizers = {
    { item = 'fertilizer', amount = 100, boost = 1.5, soil = 0 },
}

---------------------------------
-- seasons: growth speed by real calendar month of the server (1.0 = normal)
---------------------------------
Config.Seasons = {
    enabled = true,
    months = { [1] = 0.5, [2] = 0.5, [3] = 0.8, [4] = 1.0, [5] = 1.2, [6] = 1.2,
               [7] = 1.2, [8] = 1.2, [9] = 1.0, [10] = 0.8, [11] = 0.6, [12] = 0.5 },
}

---------------------------------
-- weather effects (rsg-weather): applied per minute to every plant while the server weather is the key.
--   waterDecay = multiplier on water loss, growth = growth speed multiplier, healthLoss = health lost per minute
--   cold = true: crops flagged hardy = true ignore the effect. Set Config.WeatherEffects = {} to disable.
---------------------------------
Config.WeatherEffects = {
    snowlight      = { cold = true, growth = 0.7 },
    snow           = { cold = true, growth = 0.5, healthLoss = 1 },
    sleet          = { cold = true, growth = 0.7, healthLoss = 1 },
    blizzard       = { cold = true, growth = 0.3, healthLoss = 3 },
    groundblizzard = { cold = true, growth = 0.3, healthLoss = 3 },
    whiteout       = { cold = true, growth = 0.3, healthLoss = 3 },
    hail           = { healthLoss = 2 },
    sandstorm      = { waterDecay = 2.0, healthLoss = 2 },
    highpressure   = { waterDecay = 1.5 },   -- heat: plants dry out faster
}

---------------------------------
-- rain (rsg-weather): water added per minute to EVERY plant while the server weather is one of these
-- set Config.RainWater = {} to disable
---------------------------------
Config.RainWater = {
    drizzle = 3.0, shower = 5.0, rain = 6.0, thunder = 4.0, thunderstorm = 8.0, hurricane = 8.0,
}

---------------------------------
-- pests (disabled by default: needs the 'pesticide' item in rsg-core shared items)
---------------------------------
Config.Pests = {
    enabled       = false,
    item          = 'pesticide',
    chancePerTick = 0.02,   -- chance per plant per growth tick of an infestation
    healthLoss    = 3,      -- health lost per minute while infested
    growthPenalty = 0.5,    -- growth speed multiplier while infested
}

---------------------------------
-- scarecrow: lowers the pest chance of plants around it (only matters while Config.Pests.enabled = true)
-- needs the 'scarecrow' item in rsg-core shared items
---------------------------------
Config.Scarecrow = {
    enabled       = true,
    item          = 'scarecrow',
    model         = 'p_scarecrow05x',
    radius        = 15.0,    -- plants within this distance are protected
    pestMultiplier = 0.25,   -- pest chance is multiplied by this (0 = full protection)
    maxPerPlayer  = 3,
}

---------------------------------
-- sprinkler: waters plants around it from a nearby rsg-wellpump pump (needs rsg-wellpump 3.1.0+)
-- needs the 'sprinkler' item in rsg-core shared items
-- NOTE: the model is a placeholder (the fence post used as collision blocker); set it to a prop you like
---------------------------------
Config.Sprinkler = {
    enabled       = true,
    item          = 'sprinkler',
    model         = 'p_emrfencepost02x',
    radius        = 8.0,     -- plants within this distance are watered
    startBelow    = 40.0,    -- a plant is sprinkled when its water is below this
    waterAdded    = 30.0,    -- plant water added per growth tick
    pumpCost      = 10,      -- pump water units drawn per plant watered
    linkDistance  = 40.0,    -- max distance from the sprinkler to the pump it draws from
    maxPerPlayer  = 4,
}

---------------------------------
-- harvest quality: healthy plants give extra produce (seeds are never boosted)
---------------------------------
Config.Harvest = {
    qualityHealth = 90,     -- plant health needed for the bonus
    qualityBonus  = 1,      -- extra produce per reward
}

---------------------------------
-- soil: every patch of ground tires when the same crop is harvested from it again and again.
-- Rotate crops or use a fertiliser with soil > 0 (compost) to heal it. Worn soil lowers the harvest yield (never seeds).
-- Kept in the rsg_farming_soil table. enabled = false switches the whole system off.
---------------------------------
Config.Soil = {
    enabled         = true,
    cell            = 3.0,   -- size of one soil patch (m)
    depletion       = 20,    -- fatigue added (0-100) each time the same crop is harvested from a patch
    rotateRecovery  = 40,    -- fatigue removed when a different crop is harvested there
    recoverPerHour  = 10,    -- fatigue that heals by itself per real hour
    maxYieldPenalty = 0.5,   -- yield lost at 100 fatigue (0.5 = half the produce)
    warnAt          = 50,    -- warn the planter about worn soil from this fatigue
}

---------------------------------
-- owner alerts: one notification per type per growth tick, only to the planter and only while online
---------------------------------
Config.Alerts = { enabled = true, ready = true, thirsty = true, pests = true, dead = true }

-- map blips for the plants you can tend (your own, plus shared ones). The sprite name must exist in the game.
Config.Blips = { enabled = true, sprite = 'blip_ambient_companion', scale = 0.4 }

---------------------------------
-- shared farms: members of the planter's gang (or job) can water, fertilise, treat, harvest and remove that plant.
-- mode = 'gang' | 'job'. Plants count towards the planter's limit only.
---------------------------------
Config.Sharing = { enabled = false, mode = 'gang' }

---------------------------------
-- crop theft: when enabled, players who may not tend a plant can still harvest it (instead of OwnerOnlyHarvest blocking them)
---------------------------------
Config.Theft = {
    enabled     = false,
    yield       = 0.5,       -- share of the normal produce a thief gets (no quality / skill bonus)
    notifyOwner = true,      -- tell the planter (if online) that someone is harvesting their crop
    lawAlert    = 0.5,       -- chance (0-1) to alert on-duty lawmen through rsg-lawman; 0 = never. Crops with illegal = true never alert
    alertGap    = 60000,     -- ms between two alerts caused by the same thief
    lawJobType  = 'leo',     -- job type that receives the alert
    reputation  = 'theft',   -- rsg-reputation action applied to the thief (false = none)
}

---------------------------------
-- farming xp and levels (stored per character in player metadata)
-- extraPlants adds to Config.MaxPlantsPerPlayer; bonusYieldChance = % chance of +1 produce on harvest
---------------------------------
Config.XP = { enabled = true, plant = 2, water = 1, fertilize = 1, treat = 1, harvest = 10 }
Config.Levels = {
    { xp = 0,    label = 'Greenhorn',      bonusYieldChance = 0,  extraPlants = 0 },
    { xp = 100,  label = 'Sodbuster',      bonusYieldChance = 5,  extraPlants = 2 },
    { xp = 300,  label = 'Farmhand',       bonusYieldChance = 10, extraPlants = 4 },
    { xp = 700,  label = 'Homesteader',    bonusYieldChance = 15, extraPlants = 6 },
    { xp = 1500, label = 'Cattleman',      bonusYieldChance = 20, extraPlants = 8 },
    { xp = 3000, label = 'Master Farmer',  bonusYieldChance = 25, extraPlants = 10 },
}

---------------------------------
-- action durations (ms)
---------------------------------
Config.PlantTime           = 6000
Config.WaterTime           = 5000
Config.FertilizeTime       = 5000
Config.TreatTime           = 5000
Config.HarvestTime         = 7000

-- scenario clean-up (bucket / feed bag props): 'tracked' removes only the props that were attached to the ped during the
-- action (cheap, never touches other objects); 'sweep' is the old behaviour and deletes any new object within 3 m
Config.ScenarioCleanup  = 'tracked'
Config.ScenarioExitWait = 1000   -- ms to let the exit animation finish before removing props

Config.Scenarios = {
    plant     = 'WORLD_HUMAN_FARMER_WEEDING',
    water     = 'WORLD_HUMAN_BUCKET_POUR_LOW',
    fertilize = 'WORLD_HUMAN_FEED_CHICKEN',
    treat     = 'WORLD_HUMAN_FEED_CHICKEN',
    harvest   = 'WORLD_HUMAN_CROUCH_INSPECT',
}

---------------------------------
-- crops
-- seed     : usable item that plants this crop
-- growTime : minutes from 0% to 100% (unfertilised, watered)
-- stages   : prop per growth stage. 'from' = growth % the stage starts.
--            zOffset sinks the prop to fake a smaller plant if you reuse one model.
-- harvest  : items given { item, min, max }
-- optional : seasons = { [month] = growth multiplier } overrides Config.Seasons for this crop,
--            hardy = true ignores cold weather effects, illegal = true never raises a law alert when stolen
---------------------------------
Config.Crops = {
    corn = {
        label = 'Corn', seed = 'seedcorn', growTime = 45,
        stages = {
            { from = 0,   prop = 'crp_cornstalks_bc_sim', zOffset = -1.4 },
            { from = 35,  prop = 'crp_cornstalks_bc_sim', zOffset = -0.8 },
            { from = 70,  prop = 'crp_cornstalks_bc_sim', zOffset = -0.3 },
            { from = 100, prop = 'crp_cornstalks_bc_sim', zOffset = 0.0 },
        },
        harvest = { { item = 'corn', min = 2, max = 4 }, { item = 'seedcorn', min = 0, max = 1 } },
    },
    carrot = {
        label = 'Carrots', seed = 'seedcarrot', growTime = 30,
        stages = {
            { from = 0,   prop = 'crp_carrots_ba_sim', zOffset = -0.25 },
            { from = 50,  prop = 'crp_carrots_ba_sim', zOffset = -0.1 },
            { from = 100, prop = 'crp_carrots_ba_sim', zOffset = 0.0 },
        },
        harvest = { { item = 'carrot', min = 3, max = 5 }, { item = 'seedcarrot', min = 0, max = 1 } },
    },
    tomato = {
        label = 'Tomatoes', seed = 'seedtomato', growTime = 40,
        stages = {
            { from = 0,   prop = 'crp_tomatoes_aa_sim', zOffset = -0.6 },
            { from = 50,  prop = 'crp_tomatoes_aa_sim', zOffset = -0.3 },
            { from = 100, prop = 'crp_tomatoes_aa_sim', zOffset = 0.0 },
        },
        harvest = { { item = 'tomato', min = 2, max = 5 }, { item = 'seedtomato', min = 0, max = 1 } },
    },
    potato = {
        label = 'Potatoes', seed = 'seedpotato', growTime = 35,
        hardy = true, seasons = { [11] = 0.8, [12] = 0.8, [1] = 0.8, [2] = 0.8 }, -- cold-tolerant: ignores frost effects, slows less in winter
        stages = {
            { from = 0,   prop = 'crp_potato_aa_sim', zOffset = -0.3 },
            { from = 50,  prop = 'crp_potato_aa_sim', zOffset = -0.15 },
            { from = 100, prop = 'crp_potato_aa_sim', zOffset = 0.0 },
        },
        harvest = { { item = 'potato', min = 2, max = 4 }, { item = 'seedpotato', min = 0, max = 1 } },
    },
    tobacco = {
        label = 'Tobacco', seed = 'seedtobacco', growTime = 60,
        seasons = { [11] = 0.3, [12] = 0.2, [1] = 0.2, [2] = 0.2, [3] = 0.5 }, -- warm-season crop
        stages = {
            { from = 0,   prop = 'crp_tobaccoplant_ac_sim', zOffset = -1.0 },
            { from = 50,  prop = 'crp_tobaccoplant_ac_sim', zOffset = -0.5 },
            { from = 100, prop = 'crp_tobaccoplant_ac_sim', zOffset = 0.0 },
        },
        harvest = { { item = 'tobacco_leaf', min = 2, max = 4 }, { item = 'seedtobacco', min = 0, max = 1 } },
    },
    cotton = {
        label = 'Cotton', seed = 'seedcotton', growTime = 60,
        seasons = { [11] = 0.3, [12] = 0.2, [1] = 0.2, [2] = 0.2, [3] = 0.5 }, -- warm-season crop
        stages = {
            { from = 0,   prop = 'crp_cotton_bb_sim', zOffset = -1.0 },
            { from = 50,  prop = 'crp_cotton_bb_sim', zOffset = -0.5 },
            { from = 100, prop = 'crp_cotton_bb_sim', zOffset = 0.0 },
        },
        harvest = { { item = 'cotton', min = 2, max = 4 }, { item = 'seedcotton', min = 0, max = 1 } },
    },
    sugarcane = {
        label = 'Sugarcane', seed = 'seedsugarcane', growTime = 60,
        seasons = { [11] = 0.3, [12] = 0.2, [1] = 0.2, [2] = 0.2, [3] = 0.5 }, -- warm-season crop
        stages = {
            { from = 0,   prop = 'crp_sugarcane_aa_sim', zOffset = 0.0 },
            { from = 50,  prop = 'crp_sugarcane_ab_sim', zOffset = 0.0 },
            { from = 100, prop = 'crp_sugarcane_ac_sim', zOffset = 0.0 },
        },
        harvest = { { item = 'sugarcane', min = 2, max = 4 }, { item = 'seedsugarcane', min = 0, max = 1 } },
    },
    wheat = {
        label = 'Wheat', seed = 'seedwheat', growTime = 60,
        stages = {
            { from = 0,   prop = 'crp_wheat_sap_long_aa_sim', zOffset = -0.3 },
            { from = 50,  prop = 'crp_wheat_sap_long_ab_sim', zOffset = -0.5 },
            { from = 100, prop = 'crp_wheat_dry_long_aa_sim', zOffset = -0.3 },
        },
        harvest = { { item = 'wheat', min = 2, max = 4 }, { item = 'seedwheat', min = 0, max = 1 } },
    },
    weed = {
        label = 'Weed', seed = 'seedweed', growTime = 60,
        illegal = true, -- stealing it never alerts the law (rsg-drugs dries the harvested 'weed')
        stages = {
            { from = 0,   prop = 'prop_weed_01', zOffset = -1.0 },
            { from = 50,  prop = 'prop_weed_01', zOffset = -0.5 },
            { from = 100, prop = 'prop_weed_02', zOffset = 0.0 },
        },
        harvest = { { item = 'weed', min = 2, max = 4 }, { item = 'seedweed', min = 0, max = 1 } },
    },
}

---------------------------------
-- well pump
---------------------------------
-- Well pumps and the water bucket (uses, empty bucket handed back) are handled by rsg-wellpump.
-- Pumps placed with the old farming pump are imported automatically the first time rsg-wellpump starts.

-- rsg-skills integration (optional). Needs the rsg-skills resource.
-- When rsg-skills is started it becomes the farming XP source: XP goes to the shared 'farming' skill,
-- the extra_yield perk replaces the level's bonusYieldChance and every LevelsPerExtraPlant levels adds one plant
-- slot. The Config.XP / Config.Levels above are used when rsg-skills is missing or Enabled = false.
Config.Skills = {
    Enabled            = true,
    Skill              = 'farming', -- skill key in rsg-skills
    XPScale            = 1,         -- rsg-skills XP = the Config.XP amounts x this (rsg-skills applies its own multipliers and cap)
    LevelsPerExtraPlant = 3,        -- one extra plant slot per this many levels above 1 (0 = none)
}
