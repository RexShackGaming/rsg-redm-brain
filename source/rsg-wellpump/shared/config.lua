Config = {}

---------------------------------
-- general
---------------------------------
Config.Debug        = false
Config.AutoDatabase = true   -- create the tables on start; set false and import install.sql manually

---------------------------------
-- items
---------------------------------
Config.Item       = 'tool_wellpump'       -- usable item that places a pump (also what packing a pump gives back)
Config.ExtraItems = { 'ranch_wellpump' }  -- more items that also place a pump (kept so old rsg-ranch pump items still work)
Config.EmptyItem  = 'bucket'              -- needed to fill, and handed back when a full bucket runs out of uses
Config.FullItem   = 'fullbucket'          -- given after filling
Config.BucketUses = 5                     -- uses a filled bucket starts with (stored in the item info as `uses`)

---------------------------------
-- pump
---------------------------------
Config.Prop            = 'p_wellpumpnbx01x'
Config.FillTime        = 6000    -- ms
Config.PackTime        = 4000    -- ms (also used for the place animation)
Config.FillScenario    = 'WORLD_HUMAN_BUCKET_FILL'
Config.PackScenario    = 'WORLD_HUMAN_CROUCH_INSPECT'
Config.MaxPerPlayer    = 2       -- pumps one character can have placed
Config.MinDistance     = 2.0     -- min distance between two pumps
Config.InteractDist    = 2.0     -- target distance
Config.PlaceMaxDistance = 6.0    -- how far from the player the gizmo can place
Config.RenderDistance  = 60.0    -- prop spawn / despawn distance
Config.OwnerOnlyPackup = true    -- only the placer can pack a pump up
Config.TargetIcons     = { fill = 'fa-solid fa-droplet', pack = 'fa-solid fa-box', drink = 'fa-solid fa-glass-water' }

---------------------------------
-- drinking from the pump
---------------------------------
Config.Drink = {
    enabled        = true,
    time           = 10000,                  -- ms (enforced by the server)
    cooldown       = 20000,                  -- ms between drinks for one player (server-enforced)
    thirst         = { min = 40, max = 70 }, -- thirst restored per drink; the server picks the amount
    notThirstyAbove = 95,                    -- the Drink option is refused client-side above this thirst
    -- scenarios from rsg-essentials' river drinking
    scenarioMale   = 'WORLD_HUMAN_BUCKET_DRINK_GROUND',
    scenarioFemale = 'WORLD_HUMAN_CROUCH_INSPECT',
}

---------------------------------
-- water supply for other resources (sprinklers, irrigation); see the GetPumpWater / DrawWater exports
-- each pump holds a reservoir that refills over time; it lives in memory and starts full after a restart
---------------------------------
Config.Sprinkler = {
    Enabled         = true,
    Capacity        = 400,    -- units of water one pump can hold
    RefillPerMinute = 40,     -- units a pump regains per minute
    MaxLinkDistance = 60.0,   -- default max distance between a pump and the thing drawing from it
}

---------------------------------
-- one-time import of pumps placed by the old per-script pump code
-- (each source is imported once and recorded in rsg_wellpump_migrations; the old tables are left untouched)
---------------------------------
Config.Migration = {
    Enabled = true,
    Sources = {
        { name = 'farming', table = 'rsg_farming_wellpumps' },
        { name = 'ranch',   table = 'rsg_ranch_wellpumps' },
    },
}
