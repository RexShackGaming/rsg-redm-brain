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
    flag = 1,
}

---------------------------------------------
-- recipes
-- receive      = item given
-- giveamount   = how many per craft
-- crafttime    = ms per craft
-- requiredxp   = crafting XP needed to unlock
-- xpreward     = crafting XP earned per craft
-- requiredjob  = (optional) job name or job type
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
        receive = 'pickaxe', giveamount = 1,
        crafttime = 30000, requiredxp = 25, xpreward = 3,
        ingredients = {
            { item = 'resource_wood',      amount = 1 },
            { item = 'resource_steel_bar', amount = 1 },
            { item = 'resource_string',    amount = 1 },
        },
    },
    {
        category = 'Tools',
        receive = 'axe', giveamount = 1,
        crafttime = 30000, requiredxp = 30, xpreward = 3,
        ingredients = {
            { item = 'resource_wood',      amount = 1 },
            { item = 'resource_steel_bar', amount = 1 },
            { item = 'resource_string',    amount = 1 },
        },
    },
    {
        category = 'Tools',
        receive = 'shovel', giveamount = 1,
        crafttime = 30000, requiredxp = 35, xpreward = 3,
        ingredients = {
            { item = 'resource_wood',      amount = 1 },
            { item = 'resource_steel_bar', amount = 1 },
            { item = 'resource_string',    amount = 1 },
        },
    },

}
