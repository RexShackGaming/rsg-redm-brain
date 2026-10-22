Config = {}

-- Smelter NPCs
Config.Smelters = {
    {
        id       = 'valentine_smelter',
        label    = 'smelter_valentine',   -- locale key (or plain text)
        model    = 'a_m_m_asbminer_01',
        coords   = vector4(499.53, 678.62, 117.44, 114.44),
        scenario = 'WORLD_HUMAN_SMOKE',   -- set nil for idle
        blip     = { enabled = true, sprite = 'blip_shop_blacksmith', name = 'blip_smelter' },
    },
}

Config.SpawnDistance  = 50.0   -- NPC spawns when player is within this range
Config.TargetDistance = 2.5    -- ox_target interaction range

-- Props that can be targeted to open the smelter (ox_target addModel)
Config.SmeltProps = {
    enabled = true,
    label   = 'prop_smelter',
    models  = { 'p_bucketore03x', 'p_horseprops03x' },
    -- Recommended: list the coords of the props you allow. When this list has entries,
    -- the server only accepts a prop smelt at one of them (stops smelting anywhere).
    -- Leave empty to accept any prop the player stands next to (not verifiable server-side).
    locations = {
        -- vector3(0.0, 0.0, 0.0),
    },
    locationTolerance = 2.0, -- metres between the reported prop and a listed location
}
Config.MaxUseDistance = 5.0    -- server-side anti-exploit distance check
Config.MaxBatch       = 20     -- max bars per smelt

-- Inventory image folder used for item icons in the UI
Config.ImagePath = 'nui://rsg-inventory/html/images/'

-- Recipes: inputs are consumed per 1 bar; time is ms per bar
-- label is a locale key (falls back to the text itself if no key exists)
Config.Recipes = {
    { output = 'resource_gold_bar',
        label = 'recipe_gold_bar',
        time = 30000,
        inputs = {
            { item = 'resource_coal',     amount = 10 },
            { item = 'resource_gold_ore', amount = 50 }
        }
    },
    { output = 'resource_gold_bar',
        label = 'recipe_gold_bar',
        time = 30000,
        inputs = {
            { item = 'resource_coal',        amount = 10 },
            { item = 'resource_gold_nugget', amount = 100 }
        }
    },
    { output = 'resource_silver_bar',
        label = 'recipe_silver_bar',
        time = 30000,
        inputs = {
            { item = 'resource_coal',       amount = 10 },
            { item = 'resource_silver_ore', amount = 50 }
        }
    },
    { output = 'resource_copper_bar',
        label = 'recipe_copper_bar',
        time = 30000,
        inputs = {
            { item = 'resource_coal',       amount = 10 },
            { item = 'resource_copper_ore', amount = 50 }
        }
    },
    { output = 'resource_iron_bar',
        label = 'recipe_iron_bar',
        time = 30000,
        inputs = {
            { item = 'resource_coal',       amount = 10 },
            { item = 'resource_iron_ore',   amount = 50 }
        }
    },
    { output = 'resource_lead_bar',
        label = 'recipe_lead_bar',
        time = 30000,
        inputs = {
            { item = 'resource_coal',       amount = 10 },
            { item = 'resource_lead_ore',   amount = 50 }
        }
    },
    { output = 'resource_zinc_bar',
        label = 'recipe_zinc_bar',
        time = 30000,
        inputs = {
            { item = 'resource_coal',       amount = 10 },
            { item = 'resource_zink_ore',   amount = 50 }
        }
    },
    { output = 'resource_brass_bar',
        label = 'recipe_brass_bar',
        time = 30000,
        inputs = {
            { item = 'resource_coal',       amount = 10 },
            { item = 'resource_copper_ore', amount = 25 },
            { item = 'resource_zink_ore',   amount = 25 },
        }
    },
    { output = 'resource_bronze_bar',
        label = 'recipe_bronze_bar',
        time = 30000,
        inputs = {
            { item = 'resource_coal',       amount = 10 },
            { item = 'resource_copper_ore', amount = 25 },
            { item = 'resource_lead_ore',   amount = 25 },
        }
    },
    { output = 'resource_steel_bar',
        label = 'recipe_steel_bar',
        time = 30000,
        inputs = {
            { item = 'resource_coal',       amount = 10 },
            { item = 'resource_iron_ore',    amount = 20 },
            { item = 'resource_sulfur_ore',  amount = 20 },
            { item = 'resource_nitrate_ore', amount = 10 },
        }
    },
}
