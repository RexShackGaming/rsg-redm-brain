Config = {}

---------------------------------------------
-- general
---------------------------------------------
Config.BookItem    = 'craftingbook'                -- usable item that opens the crafting UI
Config.XPType      = 'crafting'                    -- rep type used with Player.Functions.AddRep / GetRep
Config.Image       = 'rsg-inventory/html/images/'  -- item image path
Config.MaxBatch    = 10                            -- max of one recipe crafted in a single go (time scales with qty)
Config.ShowLocked  = true                          -- show locked recipes (greyed out with the XP needed)

-- animation played while crafting
Config.Anim = {
    dict = 'mech_inventory@crafting@fallbacks',
    clip = 'full_craft_and_stow',
    flag = 27,
}

-- keep push-to-talk working while the book is open (the game's other controls are blocked)
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

-- build the database tables on start; set false and import install.sql by hand instead
Config.AutoDatabase = true

---------------------------------------------
-- queue: line up several crafts that run back to back
---------------------------------------------
Config.Queue = {
    Enabled   = true,
    MaxLength = 5,     -- crafts waiting behind the active one
}

---------------------------------------------
-- category tabs
-- label = locale key shown to players, image = item image used as the tab icon
-- (a category not listed here shows its own name, without an icon)
---------------------------------------------
Config.Categories = {
    Basics = { label = 'category_basics', image = 'resource_cloth.png' },
    Tools  = { label = 'category_tools',  image = 'pickaxe.png' },
}

---------------------------------------------
-- failure chance
-- a recipe opts in with failchance = <percent>. Every unit in a batch is rolled on its own.
-- A failed unit uses up its ingredients, except for the refunded share, and earns reduced XP.
---------------------------------------------
Config.Failure = {
    Enabled       = true,
    RefundPercent = 50,   -- % of a failed unit's ingredients that come back
    XPPercent     = 25,   -- % of the recipe's XP a failed unit still earns
    ReducePerXP   = 100,  -- every N crafting XP lowers the fail chance by 1 percentage point (0 = off)
    MinChance     = 0,    -- the chance never drops below this for a recipe that has one
}

---------------------------------------------
-- quality
-- a recipe opts in with quality = true. The crafted item gets info.quality
-- (rsg-inventory's quality meter; for decaying items and weapons it is the starting condition).
-- Quality rises with crafting XP from Min to Max, plus a little random spread.
-- Note: items with different quality do not stack.
---------------------------------------------
Config.Quality = {
    Enabled  = true,
    Min      = 55,     -- quality at 0 XP
    Max      = 100,    -- quality at XPForMax and above
    XPForMax = 500,    -- crafting XP needed for the top quality
    Variance = 5,      -- random +/- added to every craft
}

---------------------------------------------
-- blueprints (recipe discovery)
-- a recipe with blueprint = 'item_name' is hidden until the player uses that item once;
-- the item is consumed and the recipe is remembered for the character (database)
---------------------------------------------
Config.Blueprints = {
    ShowUnknown = false,  -- true shows unlearned blueprint recipes greyed out instead of hiding them
}

---------------------------------------------
-- crafting stations
-- a recipe with station = 'forge' can only be crafted close to a station of that type.
-- Types:  label = locale key, radius = how close the player must stand (checked by the server),
--         model = prop to spawn (leave nil for an invisible target zone), icon = target icon,
--         zoneRadius = size of the target zone when there is no prop
-- Stations come from Static (below) and from the admin command /craftstation <type> (saved in the database).
---------------------------------------------
Config.Stations = {
    Enabled       = true,
    SpawnDistance = 60.0,   -- props spawn/despawn around the player at this range
    MaxPlaced     = 100,    -- most admin-placed stations allowed
    Types = {
        forge     = { label = 'station_forge',     radius = 3.0, model = nil, icon = 'fa-solid fa-fire',   zoneRadius = 1.5 },
        workbench = { label = 'station_workbench', radius = 3.0, model = nil, icon = 'fa-solid fa-hammer', zoneRadius = 1.5 },
    },
    -- fixed stations that need no database: { type = 'forge', coords = vector3(x, y, z), heading = 0.0 }
    Static = {},
}

---------------------------------------------
-- shared crafting: a nearby player can help with a craft that is in progress
-- (target the crafting player). Each helper cuts the remaining time and earns a share of the XP.
---------------------------------------------
Config.Assist = {
    Enabled          = true,
    Distance         = 3.0,   -- how close the helper must be
    ReductionPercent = 25,    -- % of the remaining time each helper removes
    MaxHelpers       = 2,
    XPSharePercent   = 50,    -- % of the recipe XP each helper earns (needs to stay close until the end)
    RequireBook      = true,  -- the helper needs a crafting book too
    Cooldown         = 30,    -- seconds before the same helper can help again
}

---------------------------------------------
-- recipes
-- receive      = item given
-- giveamount   = how many per craft
-- crafttime    = ms per craft
-- requiredxp   = crafting XP needed to unlock
-- xpreward     = crafting XP earned per craft
-- requiredjob  = (optional) job name or job type
-- failchance   = (optional) base % chance for a unit to fail (see Config.Failure)
-- quality      = (optional) true: the crafted item gets a quality value (see Config.Quality)
-- station      = (optional) station type needed nearby (see Config.Stations)
-- blueprint    = (optional) item that teaches the recipe when used (see Config.Blueprints)
-- ingredients  = { { item = 'name', amount = n }, ... }   (removed when crafting)
-- requireditems = (optional) { { item = 'name', amount = n }, ... }  tools that must be in the
--                 inventory but are NOT removed, e.g. a hammer. amount defaults to 1
---------------------------------------------
Config.Crafting = {
    -- Basics
    {
        category = 'Basics',
        receive = 'resource_cloth', giveamount = 1,
        crafttime = 10000, requiredxp = 0, xpreward = 1,
        ingredients = {
            { item = 'cotton', amount = 5 },
        },
    },
    {
        category = 'Basics',
        receive = 'resource_string', giveamount = 1,
        crafttime = 10000, requiredxp = 0, xpreward = 1,
        ingredients = {
            { item = 'cotton', amount = 10 },
        },
    },
    {
        category = 'Basics',
        receive = 'bandage', giveamount = 1,
        crafttime = 10000, requiredxp = 0, xpreward = 1,
        ingredients = {
            { item = 'resource_cloth', amount = 1 },
        },
    },
    -- Tools
    {
        category = 'Tools',
        receive = 'pickaxe', giveamount = 1, failchance = 10, quality = true,
        crafttime = 30000, requiredxp = 25, xpreward = 3,
        ingredients = {
            { item = 'resource_wood',      amount = 1 },
            { item = 'resource_steel_bar', amount = 1 },
            { item = 'resource_string',    amount = 1 },
        },
    },
    {
        category = 'Tools',
        receive = 'axe', giveamount = 1, failchance = 10, quality = true,
        crafttime = 30000, requiredxp = 30, xpreward = 3,
        ingredients = {
            { item = 'resource_wood',      amount = 1 },
            { item = 'resource_steel_bar', amount = 1 },
            { item = 'resource_string',    amount = 1 },
        },
    },
    {
        category = 'Tools',
        receive = 'shovel', giveamount = 1, failchance = 10, quality = true,
        crafttime = 30000, requiredxp = 35, xpreward = 3,
        ingredients = {
            { item = 'resource_wood',      amount = 1 },
            { item = 'resource_steel_bar', amount = 1 },
            { item = 'resource_string',    amount = 1 },
        },
    },
    -- examples (add the items first):
    -- {
    --     category = 'Tools', receive = 'hammer', giveamount = 1, failchance = 15, quality = true,
    --     station = 'forge', blueprint = 'blueprint_hammer', requiredjob = 'blacksmith',
    --     crafttime = 45000, requiredxp = 50, xpreward = 5,
    --     ingredients = { { item = 'resource_steel_bar', amount = 2 }, { item = 'resource_wood', amount = 1 } },
    --     requireditems = { { item = 'pickaxe', amount = 1 } },
    -- },
}

-- rsg-skills integration (optional). Needs the rsg-skills resource; does nothing when it is not started.
-- The crafting XP above keeps working; this also awards XP to the shared rsg-skills skill.
Config.Skills = {
    Enabled    = true,
    Skill      = 'crafting', -- skill key in rsg-skills
    XPScale    = 5,          -- rsg-skills XP = crafting XP earned x this (rsg-skills applies its own multipliers and cap)
    SaveChance = true,       -- the skill's save_chance perk (%) is the chance a craft does not use up its ingredients
    SpeedBonus = true,       -- the skill's speed_bonus perk (%) shortens every craft
}
