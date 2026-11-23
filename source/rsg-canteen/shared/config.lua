Config = {}

-- database
Config.AutoDatabase = true   -- create the pump table automatically; set false to import install.sql manually

-- canteens (tiers). Every key must exist in rsg-core shared items with unique = true and useable = true.
-- maxUses = uses after filling, thirst = thirst restored per drink. Add more tiers by adding lines.
Config.Canteens = {
    canteen       = { maxUses = 10, thirst = 25 },
    canteen_large = { maxUses = 20, thirst = 25 },
}
Config.MaxThirst = 100

-- derived list of canteen item names (do not edit)
Config.CanteenNames = {}
for name in pairs(Config.Canteens) do Config.CanteenNames[#Config.CanteenNames + 1] = name end
table.sort(Config.CanteenNames)

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

-- dirty water: river/lake water is unsafe until purified over a fire; pump water is always clean
Config.DirtyWater = {
    Enabled      = true,
    SickChance   = 0.6,   -- chance (0-1) that drinking dirty water makes you sick
    Damage       = 15,    -- health lost when sick
    MinHealth    = 40,    -- sickness never takes health below this
    ThirstFactor = 0.5,   -- dirty water restores this share of the normal thirst
}

-- purify dirty water by boiling it at a fire (target the fire prop)
Config.Purify = {
    Enabled = true,
    Time    = 8000,                          -- ms
    Models  = { 'p_campfirecombined01x' },   -- fire props (rsg-cooking campfire); add more fire models here
}

-- give another player a drink from your canteen
Config.Share = {
    Enabled  = true,
    Distance = 3.0,   -- max distance between the two players (checked on the server)
    Time     = 3000,  -- ms
}

-- hot or dry weather restores less thirst per drink (multiplier of the normal amount, rsg-weather names)
Config.WeatherThirst = {
    Enabled = true,
    Multipliers = {
        highpressure = 0.85,
        sandstorm    = 0.8,
    },
}

-- pump verification: the server only accepts pump fills at registered pumps.
-- Register map pumps in game with /canteenaddpump (admin); player-placed rsg-wellpump pumps count automatically.
Config.PumpVerify = {
    Enabled      = false,
    Radius       = 3.0,    -- how close the claimed pump position must be to a registered pump
    UseWellpump  = true,   -- also accept pumps placed with rsg-wellpump
    Permission   = 'admin',-- who may use /canteenaddpump and /canteenremovepump
}

-- pump fee: charged per pump fill (needs PumpVerify.Enabled, otherwise the server cannot trust the pump)
Config.PumpFee = {
    Enabled = false,
    Price   = 0.25,
    Account = 'cash',
}

-- animations
Config.FillAnim  = { dict = 'amb_work@world_human_crouch_inspect@male_c@idle_a', clip = 'idle_a' }
Config.DrinkAnim = { dict = 'amb_rest_drunk@world_human_drinking@male_a@idle_a', clip = 'idle_a' }

-- canteen prop held while drinking
Config.CanteenProp  = 'p_cs_canteen_hercule'
Config.PropBone     = 'SKEL_R_HAND'
Config.PropOffset   = vector3(0.10, 0.0, -0.05)
Config.PropRotation = vector3(-90.0, 0.0, 0.0)
