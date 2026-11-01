Config = {}

---------------------------------
-- general
---------------------------------
Config.PanItem  = 'tool_goldpan' -- useable item that starts panning (must match rsg-core/shared/items.lua)
Config.Cooldown = 10             -- seconds between pans (counted from the start of a pan)

---------------------------------
-- pan duration (decided by the server, in ms)
---------------------------------
Config.PanTime = {
    crouch = 6000,  -- crouch / scoop animation before shaking
    min    = 18000, -- total pan time (crouch included)
    max    = 34000,
}

---------------------------------
-- rewards
---------------------------------
Config.RewardItems = {
    'resource_gold_nugget',
}

Config.GoldChance = 65 -- % chance to find anything at all

-- tiers are rolled after a successful find; chances should add up to 100
Config.RewardTiers = {
    { tier = 'small',  chance = 50, amount = 1 },
    { tier = 'medium', chance = 30, amount = 2 },
    { tier = 'large',  chance = 20, amount = 3 },
}

---------------------------------
-- movement / anti-farm (enforced server-side)
---------------------------------
Config.MinMovementDistance = 1.5    -- metres a player must move from their last pan spot
Config.SpotMemoryTime      = 300000 -- ms before a used spot can be panned again (5 minutes)
Config.MaxDriftDistance    = 3.0    -- max metres the player may move during a pan before the claim is rejected

---------------------------------
-- water bodies where panning is allowed
---------------------------------
Config.WaterTypes = {
    { name = 'San Luis River',       waterhash = -1504425495 },
    { name = 'Upper Montana River',  waterhash = -1781130443 },
    { name = 'Owanjila',             waterhash = -1300497193 },
    { name = 'HawkEye Creek',        waterhash = -1276586360 },
    { name = 'Little Creek River',   waterhash = -1410384421 },
    { name = 'Dakota River',         waterhash = 370072007   },
    { name = 'Beartooth Beck',       waterhash = 650214731   },
    { name = 'Deadboot Creek',       waterhash = 1245451421  },
    { name = 'Spider Gorge',         waterhash = -218679770  },
    { name = 'Roanoke Valley',       waterhash = -1229593481 },
    { name = 'Lannahechee River',    waterhash = -2040708515 },
    { name = 'Random1',              waterhash = 231313522   },
    { name = 'Random2',              waterhash = 2005774838  },
    { name = 'Random3',              waterhash = -1287619521 },
    { name = 'Random4',              waterhash = -1308233316 },
    { name = 'Random5',              waterhash = -196675805  },
    { name = 'Arroyo De La Vibora',  waterhash = -49694339   },
}
