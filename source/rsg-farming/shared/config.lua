Config = {}

---------------------------------
-- general
---------------------------------
Config.Debug               = false
Config.MaxPlantsPerPlayer  = 20      -- max active plants per character
Config.MinPlantDistance    = 1.2     -- min distance between two plants
Config.PlaceMaxDistance    = 6.0     -- how far from the player the gizmo can place

-- custom props with no collision: an invisible blocker is spawned with them (and removed with them)
Config.CollisionModel = 'p_emrfencepost02x'
Config.CollisionProps = {
    ['prop_weed_01'] = true,
    ['prop_weed_02'] = true,
}
Config.InteractDistance    = 1.6     -- distance to tend a plant
Config.RenderDistance      = 60.0    -- props spawn / despawn distance
Config.OwnerOnlyHarvest    = true    -- only the planter can harvest / destroy
Config.InteractKey         = 0x760A9C6F -- [G] (only used when UseTarget = false)
Config.UseTarget           = true    -- use ox_target zones on plants instead of the [G] prompt
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
Config.FertilizerBoost     = 1.5     -- growth multiplier while fertilised
Config.DryDamage           = 5       -- health lost per minute with no water
Config.HealthRegen         = 2       -- health gained per minute while watered
Config.DeadPlantRemoveTime = 30      -- minutes before a dead plant is auto-removed

---------------------------------
-- tending items
---------------------------------
Config.WaterItem           = 'fullbucket'  -- consumed when watering
Config.WaterReturnItem     = 'bucket'      -- given back after watering (false to disable)
Config.WaterAmount         = 100           -- water added (capped at 100)
Config.FertilizerItem      = 'fertilizer'
Config.FertilizerAmount    = 100

---------------------------------
-- action durations (ms)
---------------------------------
Config.PlantTime           = 6000
Config.WaterTime           = 5000
Config.FertilizeTime       = 5000
Config.HarvestTime         = 7000

Config.Scenarios = {
    plant     = 'WORLD_HUMAN_FARMER_WEEDING',
    water     = 'WORLD_HUMAN_BUCKET_POUR_LOW',
    fertilize = 'WORLD_HUMAN_FEED_CHICKEN',
    harvest   = 'WORLD_HUMAN_CROUCH_INSPECT',
}

---------------------------------
-- crops
-- seed     : usable item that plants this crop
-- growTime : minutes from 0% to 100% (unfertilised, watered)
-- stages   : prop per growth stage. 'from' = growth % the stage starts.
--            zOffset sinks the prop to fake a smaller plant if you reuse one model.
-- harvest  : items given { item, min, max }
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
        stages = {
            { from = 0,   prop = 'crp_potato_aa_sim', zOffset = -0.3 },
            { from = 50,  prop = 'crp_potato_aa_sim', zOffset = -0.15 },
            { from = 100, prop = 'crp_potato_aa_sim', zOffset = 0.0 },
        },
        harvest = { { item = 'potato', min = 2, max = 4 }, { item = 'seedpotato', min = 0, max = 1 } },
    },
    tobacco = {
        label = 'Tobacco', seed = 'seedtobacco', growTime = 60,
        stages = {
            { from = 0,   prop = 'crp_tobaccoplant_ac_sim', zOffset = -1.0 },
            { from = 50,  prop = 'crp_tobaccoplant_ac_sim', zOffset = -0.5 },
            { from = 100, prop = 'crp_tobaccoplant_ac_sim', zOffset = 0.0 },
        },
        harvest = { { item = 'tobacco', min = 2, max = 4 }, { item = 'seedtobacco', min = 0, max = 1 } },
    },
    cotton = {
        label = 'Cotton', seed = 'seedcotton', growTime = 60,
        stages = {
            { from = 0,   prop = 'crp_cotton_bb_sim', zOffset = -1.0 },
            { from = 50,  prop = 'crp_cotton_bb_sim', zOffset = -0.5 },
            { from = 100, prop = 'crp_cotton_bb_sim', zOffset = 0.0 },
        },
        harvest = { { item = 'cotton', min = 2, max = 4 }, { item = 'seedcotton', min = 0, max = 1 } },
    },
    sugarcane = {
        label = 'Sugarcane', seed = 'seedsugarcane', growTime = 60,
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
Config.WellPump = {
    item            = 'tool_wellpump',      -- usable item that places the pump
    prop            = 'p_wellpumpnbx01x',
    emptyItem       = 'bucket',             -- required to fill
    fullItem        = 'fullbucket',         -- given after filling
    bucketUses      = 5,                    -- waterings a full bucket gives before it turns back into 'bucket'
    fillTime        = 6000,                 -- ms
    packTime        = 4000,                 -- ms
    fillScenario    = 'WORLD_HUMAN_BUCKET_FILL',
    packScenario    = 'WORLD_HUMAN_CROUCH_INSPECT',
    maxPerPlayer    = 2,
    minDistance     = 2.0,                  -- min distance between two pumps
    interactDist    = 2.0,
    ownerOnlyPackup = true,                 -- only the placer can pack it up
}
