Config = {}

-- items must exist in rsg-core shared items
Config.CommonItems = { 'bread', 'water' }
Config.RareItems   = { 'weapon_revolver_cattleman', 'ammo_box_revolver' }

Config.RareChance  = 5            -- % chance of rare loot
Config.CommonCash  = { 1, 5 }     -- min / max cash with common loot
Config.RareCash    = { 5, 10 }    -- min / max cash with rare loot

-- 'native' = use the game's own hold-to-loot prompt on bodies
-- 'target' = ox_target option with a progress bar
Config.LootMethod   = 'native'

Config.LootTime     = 3000        -- ms searching the body (target mode only)
Config.LootDistance = 3.0         -- max distance to the body (server checked)
Config.LootCooldown = 3           -- seconds between loot rewards per player
Config.LawAlert     = true        -- alert lawmen when a body is looted

-- robbing players
Config.RobDistance  = 2.5
Config.RobCooldown  = 60          -- seconds before the same victim can be robbed again
Config.TakeCash       = true
Config.TakeBloodMoney = true

-- outlaw status added on success (0 = disabled)
Config.OutlawLoot = 10
Config.OutlawRob  = 50
