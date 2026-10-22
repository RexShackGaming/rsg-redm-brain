Config = {}

-- Security / anti-abuse (server side)
Config.ActionCooldown   = 1000                              -- ms between backpack open requests per player
Config.AutoCreateTable  = true                              -- build / upgrade the `player_backpack` table on start (no manual SQL needed)
Config.BlockNestedBackpacks = true                          -- backpacks can not be stored inside another backpack stash
Config.OneBackpackOnly  = true                              -- a player can only carry ONE backpack item at a time

-- backpack models (item names / stash sizes). Stash name is always 'backpack_<serial>'
Config.backpackType = {
    { model = 'p_cs_baglevin01x',           item = 'backpack_ammo',     maxweight = 22000, slots = 24,  position = vector3(0.13, -0.20, -0.05), rotation = vector3(0.0, 70.0, 0.0), },
    { model = 'p_fishcolectorsatchel01x',   item = 'backpack_fish',     maxweight = 32000, slots = 24,  position = vector3(0.5, 0.3, 0.5),      rotation = vector3(0.0, 90.0, 0.0), },
    { model = 'p_ambpack01x',               item = 'backpack_nat',      maxweight = 42000, slots = 32,  position = vector3(-0.5, 0.0, 0.08),    rotation = vector3(-80.0, 0.0, -90.0), },
    { model = 'p_ambpack04x',               item = 'backpack_big',      maxweight = 62000, slots = 128, position = vector3(-0.2, -0.10, 0.00),  rotation = vector3(0.0, -20.0, -90.0), },
    { model = 'p_ambpack02x',               item = 'backpack_normal',   maxweight = 52000, slots = 64,  position = vector3(-0.35, 0.0, 0.08),   rotation = vector3(-80.0, 0.0, -90.0), },
    { model = 'p_ambpack05x',               item = 'backpack_simple',   maxweight = 22000, slots = 32,  position = vector3(-0.5, 0.0, 0.08),    rotation = vector3(-80.0, 0.0, -90.0), },
    { model = 'p_trapperbackpack01x',       item = 'backpack_trapper',  maxweight = 22000, slots = 64,  position = vector3(-0.0, 0.0, -0.00),   rotation = vector3(0.0, -20.0, 90.0), },
}

-- lookup by item name (built automatically)
Config.backpackByItem = {}
for _, cfg in ipairs(Config.backpackType) do
    Config.backpackByItem[cfg.item] = cfg
end

-------------------------------------------------------------------------------
-- BELT / BACK ATTACHMENTS (merged from bln_belt_attachments)
-- Shows weapons/items on the character when owned but not in hand.
-------------------------------------------------------------------------------
Config.Belt = {
    enabled      = true,
    debounceTime = 1000,  -- ms minimum between attach/detach changes per item
    categories = {
        lanterns = {
            {
                alwaysAttached = false, -- If true, the item is always attached while owned, even when in hand.
                hashName = 'WEAPON_MELEE_LANTERN',
                model = `s_interact_lantern01x`,
                bone = {
                    male = 'PH_Lantern',
                    female = false, -- `false` = use the male setting
                },
                offset = {
                    male = { x = 0.0, y = 0.0, z = 0.0, pitch = 0.0, roll = 0.0, yaw = 0.0 },
                    female = false,
                },
            },
            {
                alwaysAttached = false,
                hashName = 'WEAPON_MELEE_DAVY_LANTERN',
                model = `s_interact_lantern02x`,
                bone = {
                    male = 'PH_Lantern',
                    female = false,
                },
                offset = {
                    male = { x = -0.05, y = 0.0, z = 0.0, pitch = 0.0, roll = 0.0, yaw = 0.0 },
                    female = false,
                },
            },
            {
                alwaysAttached = false,
                hashName = 'WEAPON_KIT_METAL_DETECTOR',
                model = `mp005_s_interact_detectorm01x`,
                bone = {
                    male = 'PH_Lantern',
                    female = false,
                },
                offset = {
                    male = { x = 0.0, y = 0.0, z = 0.0, pitch = 0.0, roll = 0.0, yaw = 0.0 },
                    female = false,
                },
            },
        },
        lasso = {
            {
                alwaysAttached = false,
                hashName = 'WEAPON_LASSO',
                model = `p_cs_melee_lasso01`,
                bone = {
                    male = 'SKEL_L_Thigh',
                    female = 'skel_l_thigh',
                },
                offset = {
                    male = { x = 0.0, y = 0.0, z = -0.11, pitch = -83.0, roll = 0.0, yaw = 80.0 },
                    female = false,
                },
            },
            {
                alwaysAttached = false,
                hashName = 'WEAPON_LASSO_REINFORCED',
                model = `p_cs_melee_lasso01`,
                bone = {
                    male = 'SKEL_L_Thigh',
                    female = 'skel_l_thigh',
                },
                offset = {
                    male = { x = 0.0, y = 0.0, z = -0.11, pitch = -83.0, roll = 0.0, yaw = 80.0 },
                    female = false,
                },
            },
        },
        machete = {
            {
                alwaysAttached = false,
                hashName = 'WEAPON_MELEE_MACHETE',
                model = `p_machete01x`,
                bone = {
                    male = 'SKEL_L_Thigh',
                    female = 'skel_l_thigh',
                },
                offset = {
                    male = { x = 0.0, y = 0.0, z = -0.11, pitch = 0.0, roll = 0.0, yaw = 120.0 },
                    female = false,
                },
            },
        },
        quiver = {
            {
                alwaysAttached = true,
                hashName = { 'weapon_bow', 'weapon_bow_improved' },
                model = `p_arrowbundle01x`,
                bone = {
                    male = 'CP_Back',
                    female = 'CP_Back',
                },
                offset = {
                    male = { x = -0.30, y = 0.0, z = 0.0, pitch = 0.0, roll = -10.0, yaw = 100.0 },
                    female = false,
                },
            },
        },
    },
}
