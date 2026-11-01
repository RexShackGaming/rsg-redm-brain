Config = {}

-- item
Config.CanteenItem    = 'canteen'
Config.MaxUses        = 10      -- uses after filling
Config.ThirstAmount   = 25      -- thirst restored per drink
Config.MaxThirst      = 100

-- timings (ms)
Config.FillTime       = 5000
Config.DrinkTime      = 3000

-- targeting
Config.TargetDistance = 2.0
Config.PumpModels = {
    'p_waterpump01x',
    'p_wellpumpnbx01x',
}

-- river / lake filling (stand in shallow water and press the prompt)
Config.WaterFill = {
    Enabled      = true,
    Key          = 0x760A9C6F, -- G
    CheckEvery   = 500,        -- ms between water checks
    -- optional: only allow these water zone hashes (GetWaterMapZoneAtCoords); empty = any water
    AllowedZones = {},
}

-- animations
Config.FillAnim  = { dict = 'amb_work@world_human_crouch_inspect@male_c@idle_a', clip = 'idle_a' }
Config.DrinkAnim = { dict = 'amb_rest_drunk@world_human_drinking@male_a@idle_a', clip = 'idle_a' }

-- canteen prop held while drinking
Config.CanteenProp  = 'p_cs_canteen_hercule'
Config.PropBone     = 'SKEL_R_HAND'
Config.PropOffset   = vector3(0.10, 0.0, -0.05)
Config.PropRotation = vector3(-90.0, 0.0, 0.0)
