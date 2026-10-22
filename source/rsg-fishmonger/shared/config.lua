Config = {}

---------------------------------
-- general
---------------------------------
Config.NpcModel       = `cs_fishcollector`
Config.SpawnDistance  = 50.0   -- npc spawns / despawns at this range
Config.TargetDistance = 2.5    -- ox_target interaction distance
Config.MaxUseDistance = 5.0    -- server-side distance check to the npc
Config.Cooldown       = 2000   -- ms between checkouts per player (anti-spam)
Config.MoneyType      = 'cash' -- 'cash' | 'bank' | 'bloodmoney'
Config.FilletItem     = 'raw_fish'
Config.ImagePath      = 'nui://rsg-inventory/html/images/'

---------------------------------
-- blip
---------------------------------
Config.Blip = {
    enabled = true,
    sprite  = `blip_mg_fishing`,
    style   = 1664425300,
}

---------------------------------
-- fishmonger locations (x, y, z, heading)
-- key = locale entry 'loc_<key>' used for the display name
---------------------------------
Config.Locations = {
    { key = 'saint_denis', coords = vector4(2661.7463, -1506.055, 45.968948, 321.56686) },
    { key = 'blackwater', coords = vector4(-723.9387, -1254.361, 44.734092, 49.674472) },
    { key = 'valentine', coords = vector4(-335.4444, 762.00537, 116.5845, 45.516292) },
    { key = 'rhodes', coords = vector4(1292.9885, -1273.963, 75.870391, 181.20063) },
    { key = 'annesburg', coords = vector4(3018.2368, 1352.096, 42.713443, 23.409223) },
    { key = 'van_horn', coords = vector4(2991.539, 558.93402, 44.357906, 4.9385623) },
    { key = 'tumbleweed', coords = vector4(-5513.404, -2944.167, -2.001027, 29.520355) },
    { key = 'river', coords = vector4(-1452.24, -2684.517, 41.256187, 221.86631) },
}

---------------------------------
-- fish that can be sold / processed
-- label comes from the item's label in rsg-core shared items
-- price   = cash paid per fish
-- fillets = amount of Config.FilletItem given per fish when processed
---------------------------------
Config.Fish = {
    ['a_c_fishbluegil_01_sm']           = { price = 0.40, fillets = 1 },
    ['a_c_fishbluegil_01_ms']           = { price = 0.75, fillets = 1 },
    ['a_c_fishbullheadcat_01_sm']       = { price = 0.45, fillets = 1 },
    ['a_c_fishbullheadcat_01_ms']       = { price = 0.85, fillets = 1 },
    ['a_c_fishchainpickerel_01_sm']     = { price = 0.50, fillets = 1 },
    ['a_c_fishchainpickerel_01_ms']     = { price = 0.95, fillets = 2 },
    ['a_c_fishperch_01_sm']             = { price = 0.40, fillets = 1 },
    ['a_c_fishperch_01_ms']             = { price = 0.80, fillets = 1 },
    ['a_c_fishredfinpickerel_01_sm']    = { price = 0.50, fillets = 1 },
    ['a_c_fishredfinpickerel_01_ms']    = { price = 0.95, fillets = 2 },
    ['a_c_fishrockbass_01_sm']          = { price = 0.45, fillets = 1 },
    ['a_c_fishrockbass_01_ms']          = { price = 0.90, fillets = 2 },
    ['a_c_fishlargemouthbass_01_ms']    = { price = 1.50, fillets = 2 },
    ['a_c_fishsmallmouthbass_01_ms']    = { price = 1.40, fillets = 2 },
    ['a_c_fishrainbowtrout_01_ms']      = { price = 1.50, fillets = 2 },
    ['a_c_fishsalmonsockeye_01_ms']     = { price = 1.75, fillets = 2 },
    ['a_c_fishchannelcatfish_01_lg']    = { price = 3.00, fillets = 4 },
    ['a_c_fishlakesturgeon_01_lg']      = { price = 3.50, fillets = 5 },
    ['a_c_fishlongnosegar_01_lg']       = { price = 3.00, fillets = 4 },
    ['a_c_fishmuskie_01_lg']            = { price = 3.25, fillets = 4 },
    ['a_c_fishnorthernpike_01_lg']      = { price = 3.25, fillets = 4 },
    ['a_c_fishchannelcatfish_01_xl']    = { price = 4.00, fillets = 5 },
    ['a_c_fishlargemouthbass_01_lg']    = { price = 2.25, fillets = 3 },
    ['a_c_fishrainbowtrout_01_lg']      = { price = 2.25, fillets = 3 },
    ['a_c_fishsalmonsockeye_01_ml']     = { price = 2.25, fillets = 3 },
    ['a_c_fishsalmonsockeye_01_lg']     = { price = 2.75, fillets = 3 },
    ['a_c_fishsmallmouthbass_01_lg']    = { price = 2.25, fillets = 3 },
}
