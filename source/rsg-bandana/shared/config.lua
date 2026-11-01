Config = {}

Config.Command      = 'bandana'   -- /bandana toggles up/down
Config.UseItem      = false       -- true = also toggle by using an inventory item
Config.ItemName     = 'bandana'   -- item to register as useable (must exist in rsg-core items)
Config.Cooldown     = 2500        -- ms between toggles
Config.AnimTime     = 1200        -- ms into the animation before the state swaps
Config.PlayAnim     = true        -- play the RDR2 hand-to-face animation
Config.Debug        = false       -- print neckwear state to F8 when toggling

-- Values below come from RDR3 decompiled scripts (build 1436, short_update.c / abigail2_1.c)
-- and femga/rdr3_discoveries clothes/cloth_hash_names.lua. Do not change.
Config.NeckwearCategory = 0x5FC29285           -- "neckwear" (same for male and female MP peds)
Config.StateUp          = -1829635046          -- wearable state: bandana over face
Config.StateDown        = joaat('BASE')        -- wearable state: bandana round neck
Config.Anims = {
    up   = { foot = `BANDANA_ON_RIGHT_HAND`,  mounted = `BANDANA_ON_LEFT_HAND`  },
    down = { foot = `BANDANA_OFF_RIGHT_HAND`, mounted = `BANDANA_OFF_LEFT_HAND` },
}
