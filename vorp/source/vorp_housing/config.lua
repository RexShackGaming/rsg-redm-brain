---@class vorp_housing_config
local CONFIG = {}
-- WEBHOOK TO MONITOR STORAGES IS FOUND ON THE SERVER.LUA FILE

CONFIG.DEV_MODE = false       -- set to true when you need to restart script to do your tests

CONFIG.COMMAND = "showHouses" -- command to be used while in dev mode to show all houses to keep track of what you added

CONFIG.TRANSLATION = {
    not_owner = "You are not the owner of this house",
    not_admin = "You are not an admin to use this command",
    press = "press",
}


-- DOORS ARE HANDLED IN VORP DOORLOCKS
CONFIG.HOUSES = {
    -- Widows Rock House 1
    {
        POSITION = vector3(-397.7, 1727.66, 216.49), -- POSITION OF THE CENTER OF THE HOUSE and for blip
        BLIP = {
            ENABLE = true,                           -- Will display the blip of this house if player owns it
            SPRITE = `blip_mp_base`,
            STYLE = `BLIP_STYLE_PROPERTY_OWNER`,
            NAME = "My House",
        },

        WARDROBE = {
            ENABLE = true,
            LOCATION = vector3(-397.22, 1728.51, 216.54),
            LABEL = "Wardrobe",
        },

        OWNERS = {
            [1] = {                  -- CHARACTER ID'S for the owners this player can only own one house
                DOOR = true,         -- CAN OPEN AND CLOSE DOORS?
                STORAGE = true,      -- CAN ACCESS STORAGES?
                BLIP_VISIBLE = true, -- CAN SEE THE BLIP OF THE HOUSE?
                WARDROBE = true,     -- CAN ACCESS WARDROBE?
            },
        },

        -- ONE HOUSE CAN HAVE MORE THAN ONE STORAGE
        STORAGES = {
            {
                ID = 1,                                       -- STORAGE ID MUST BE UNIQUE FOR EACH STORAGE
                MAX_SLOTS = 100,                              -- MAX SLOTS FOR THE STORAGE
                LOCATION = vector3(-391.28, 1728.72, 216.44), -- LOCATION OF THE STORAGE
                LABEL = "Food Storage",
                WEAPONS = true,
                SHARED = true,        -- IF FALSE EACH OWNER WILL HAVE THEIR OWN INVENTORY
                BLACKLISTED_ITEMS = { -- BLACKLIST ITEMS OR WEAPONS , TO DISABLE JUST LEAVE AN EMPTY TABLE
                    "water",
                    "bread",
                },
            },
            {
                ID = 2,
                MAX_SLOTS = 100,
                LOCATION = vector3(-396.38, 1732.76, 216.43),
                LABEL = "Tools Storage",
                WEAPONS = true,
                SHARED = true,
                BLACKLISTED_ITEMS = {},
            }
        },
        DOORS = {       -- DOOR IDS, MUST BE IN VORP DOORLOCKS TO BE DETECTED THESE DOORS DONT NEED PERMISSIONS IN VORP DOORLOCKS SCRIPT
            4070066247, -- Front Door
            3444471262  -- Front Door
        }
    },

    -- Cabin at Braithwaite Manor
    {
        POSITION = vector3(1118.0621, -1987.8922, 55.3475),
        BLIP = {
            ENABLE = true,
            SPRITE = `blip_mp_base`,
            STYLE = `BLIP_STYLE_PROPERTY_OWNER`,
            NAME = "My House",
        },

        WARDROBE = {
            ENABLE = true,
            LOCATION = vector3(1118.96, -1989.63, 55.42),
            LABEL = "Wardrobe",
        },

        OWNERS = {
            [1] = {
                DOOR = true,
                STORAGE = true,
                BLIP_VISIBLE = true,
                WARDROBE = true,
            },
        },

        STORAGES = { -- You can add more than one storage
            {
                ID = 3,
                MAX_SLOTS = 100,
                LOCATION = vector3(1119.0345, -1985.6793, 55.3500),
                LABEL = "Storage",
                WEAPONS = true,
                SHARED = true,
                BLACKLISTED_ITEMS = {},
            }
        },
        DOORS = {      -- DOOR IDS, MUST BE IN VORP DOORLOCKS TO BE DETECTED THESE DOORS DONT NEED PERMISSIONS IN VORP DOORLOCKS SCRIPT
            3921310299 -- Front Door
        }
    },

    -- Cabin at Lake O'Creagh's
    {
        POSITION = vector3(1700.6041, 1511.0630, 147.8734),
        BLIP = {
            ENABLE = true,
            SPRITE = `blip_mp_base`,
            STYLE = `BLIP_STYLE_PROPERTY_OWNER`,
            NAME = "My House",
        },


        WARDROBE = {
            ENABLE = true,
            LOCATION = vector3(1702.66, 1512.67, 147.92),
            LABEL = "Wardrobe",
        },


        OWNERS = {
            [1] = {
                DOOR = true,
                STORAGE = true,
                BLIP_VISIBLE = true,
                WARDROBE = true,
            },
        },

        STORAGES = { -- You can add more than one storage
            {
                ID = 4,
                MAX_SLOTS = 100,
                LOCATION = vector3(1701.4554, 1509.2227, 147.8706),
                LABEL = "Storage",
                WEAPONS = true,
                SHARED = true,
                BLACKLISTED_ITEMS = {},
            }
        },
        DOORS = {      -- DOOR IDS, MUST BE IN VORP DOORLOCKS TO BE DETECTED THESE DOORS DONT NEED PERMISSIONS IN VORP DOORLOCKS SCRIPT
            868379185, -- Front Door
            640077562  -- Back Door
        }
    },

    -- Cabin on the Southfield Plains
    {
        POSITION = vector3(1134.9661, -979.6726, 69.3992),
        BLIP = {
            ENABLE = true,
            SPRITE = `blip_mp_base`,
            STYLE = `BLIP_STYLE_PROPERTY_OWNER`,
            NAME = "My House",
        },

        WARDROBE = {
            ENABLE = true,
            LOCATION = vector3(1132.72, -980.94, 69.45),
            LABEL = "Wardrobe",
        },

        OWNERS = {
            [1] = {
                DOOR = true,
                STORAGE = true,
                BLIP_VISIBLE = true,
                WARDROBE = true,
            },
        },

        STORAGES = { -- You can add more than one storage
            {
                ID = 5,
                MAX_SLOTS = 100,
                LOCATION = vector3(1133.7925, -981.4205, 69.4031),
                LABEL = "Storage",
                WEAPONS = true,
                SHARED = true,
                BLACKLISTED_ITEMS = {},
            }
        },
        DOORS = {      -- DOOR IDS, MUST BE IN VORP DOORLOCKS TO BE DETECTED THESE DOORS DONT NEED PERMISSIONS IN VORP DOORLOCKS SCRIPT
            3929468747 -- Front Door
        }
    },

    -- Cabin in the Roanoke Valley
    {
        POSITION = vector3(2625.1238, 1695.9159, 115.6895),
        BLIP = {
            ENABLE = true,
            SPRITE = `blip_mp_base`,
            STYLE = `BLIP_STYLE_PROPERTY_OWNER`,
            NAME = "My House",
        },

        WARDROBE = {
            ENABLE = true,
            LOCATION = vector3(2624.99, 1692.77, 115.75),
            LABEL = "Wardrobe",
        },

        OWNERS = {
            [1] = {
                DOOR = true,
                STORAGE = true,
                BLIP_VISIBLE = true,
                WARDROBE = true,
            },
        },

        STORAGES = { -- You can add more than one storage
            {
                ID = 6,
                MAX_SLOTS = 100,
                LOCATION = vector3(2624.1274, 1696.4465, 115.7027),
                LABEL = "Storage",
                WEAPONS = true,
                SHARED = true,
                BLACKLISTED_ITEMS = {},
            }
        },
        DOORS = {      -- DOOR IDS, MUST BE IN VORP DOORLOCKS TO BE DETECTED THESE DOORS DONT NEED PERMISSIONS IN VORP DOORLOCKS SCRIPT
            1574473390 -- Front Door
        }
    },

    -- House in Rhodes
    {
        POSITION = vector3(1112.8748, -1301.4908, 66.4053),
        BLIP = {
            ENABLE = true,
            SPRITE = `blip_mp_base`,
            STYLE = `BLIP_STYLE_PROPERTY_OWNER`,
            NAME = "My House",
        },

        WARDROBE = {
            ENABLE = true,
            LOCATION = vector3(1107.6, -1302.6, 66.46),
            LABEL = "Wardrobe",
        },

        OWNERS = {
            [1] = {
                DOOR = true,
                STORAGE = true,
                BLIP_VISIBLE = true,
                WARDROBE = true,
            },
        },

        STORAGES = { -- You can add more than one storage
            {
                ID = 7,
                MAX_SLOTS = 100,
                LOCATION = vector3(1116.5450, -1297.7770, 66.3814),
                LABEL = "Storage",
                WEAPONS = true,
                SHARED = true,
                BLACKLISTED_ITEMS = {},
            }
        },
        DOORS = {       -- DOOR IDS, MUST BE IN VORP DOORLOCKS TO BE DETECTED THESE DOORS DONT NEED PERMISSIONS IN VORP DOORLOCKS SCRIPT
            1485561723, -- Front Door
            4276865168, -- Room 1 Door
            1532575796, -- Room 2 Door
            1151226872, -- Room 3 Door
            3544613794  -- Back Door
        }
    },

    -- House in the snow town
    {
        POSITION = vector3(-1351.5906, 2439.3948, 308.4406),
        BLIP = {
            ENABLE = true,
            SPRITE = `blip_mp_base`,
            STYLE = `BLIP_STYLE_PROPERTY_OWNER`,
            NAME = "My House",
        },

        WARDROBE = {
            ENABLE = true,
            LOCATION = vector3(-1357.44, 2443.98, 308.47),
            LABEL = "Wardrobe",
        },

        OWNERS = {
            [1] = {
                DOOR = true,
                STORAGE = true,
                BLIP_VISIBLE = true,
                WARDROBE = true,
            },
        },

        STORAGES = { -- You can add more than one storage
            {
                ID = 8,
                MAX_SLOTS = 100,
                LOCATION = vector3(-1354.6299, 2443.4001, 308.4202),
                LABEL = "Storage",
                WEAPONS = true,
                SHARED = true,
                BLACKLISTED_ITEMS = {},
            }
        },
        DOORS = {       -- DOOR IDS, MUST BE IN VORP DOORLOCKS TO BE DETECTED THESE DOORS DONT NEED PERMISSIONS IN VORP DOORLOCKS SCRIPT
            2183007198, -- Front Door
            4288310487  -- Back Door
        }
    },

    -- House in the snow
    {
        POSITION = vector3(-554.4449, 2703.8315, 320.4272),
        BLIP = {
            ENABLE = true,
            SPRITE = `blip_mp_base`,
            STYLE = `BLIP_STYLE_PROPERTY_OWNER`,
            NAME = "My House",
        },

        WARDROBE = {
            ENABLE = true,
            LOCATION = vector3(-555.6, 2710.54, 320.46),
            LABEL = "Wardrobe",
        },

        OWNERS = {
            [1] = {
                DOOR = true,
                STORAGE = true,
                BLIP_VISIBLE = true,
                WARDROBE = true,
            },
        },

        STORAGES = { -- You can add more than one storage
            {
                ID = 9,
                MAX_SLOTS = 100,
                LOCATION = vector3(-553.2963, 2701.4446, 320.4149),
                LABEL = "Storage",
                WEAPONS = true,
                SHARED = true,
                BLACKLISTED_ITEMS = {},
            }
        },
        DOORS = {      -- DOOR IDS, MUST BE IN VORP DOORLOCKS TO BE DETECTED THESE DOORS DONT NEED PERMISSIONS IN VORP DOORLOCKS SCRIPT
            872775928, -- Front Door
            2385374047 -- Back Door
        }
    },

    -- House in Valentine
    {
        POSITION = vector3(774.8596, 847.4821, 118.9179),
        BLIP = {
            ENABLE = true,
            SPRITE = `blip_mp_base`,
            STYLE = `BLIP_STYLE_PROPERTY_OWNER`,
            NAME = "My House",
        },

        WARDROBE = {
            ENABLE = true,
            LOCATION = vector3(779.44, 844.47, 121.97),
            LABEL = "Wardrobe",
        },

        OWNERS = {
            [1] = {
                DOOR = true,
                STORAGE = true,
                BLIP_VISIBLE = true,
                WARDROBE = true,
            },
        },

        STORAGES = { -- You can add more than one storage
            {
                ID = 10,
                MAX_SLOTS = 100,
                LOCATION = vector3(776.3958, 845.6426, 121.9363),
                LABEL = "Storage",
                WEAPONS = true,
                SHARED = true,
                BLACKLISTED_ITEMS = {},
            }
        },
        DOORS = {       -- DOOR IDS, MUST BE IN VORP DOORLOCKS TO BE DETECTED THESE DOORS DONT NEED PERMISSIONS IN VORP DOORLOCKS SCRIPT
            4123766266, -- Front Door
            1002666274, -- Room 1 Door
            417362979   -- Back Door
        }
    },

    -- Cabin on the Dakota River
    {
        POSITION = vector3(-689.8939, 1044.0026, 135.0041),
        BLIP = {
            ENABLE = true,
            SPRITE = `blip_mp_base`,
            STYLE = `BLIP_STYLE_PROPERTY_OWNER`,
            NAME = "My House",
        },

        WARDROBE = {
            ENABLE = true,
            LOCATION = vector3(-690.71, 1045.72, 135.13),
            LABEL = "Wardrobe",
        },

        OWNERS = {
            [1] = {
                DOOR = true,
                STORAGE = true,
                BLIP_VISIBLE = true,
                WARDROBE = true,
            },
        },

        STORAGES = { -- You can add more than one storage
            {
                ID = 11,
                MAX_SLOTS = 100,
                LOCATION = vector3(-689.4321, 1040.9478, 135.0034),
                LABEL = "Storage",
                WEAPONS = true,
                SHARED = true,
                BLACKLISTED_ITEMS = {},
            }
        },
        DOORS = {      -- DOOR IDS, MUST BE IN VORP DOORLOCKS TO BE DETECTED THESE DOORS DONT NEED PERMISSIONS IN VORP DOORLOCKS SCRIPT
            1434140379 -- Front Door
        }
    },

    -- House on the Dakota River
    {
        POSITION = vector3(-612.9479, -27.5009, 85.9752),
        BLIP = {
            ENABLE = true,
            SPRITE = `blip_mp_base`,
            STYLE = `BLIP_STYLE_PROPERTY_OWNER`,
            NAME = "My House",
        },

        WARDROBE = {
            ENABLE = true,
            LOCATION = vector3(-614.13, -29.92, 86.02),
            LABEL = "Wardrobe",
        },

        OWNERS = {
            [1] = {
                DOOR = true,
                STORAGE = true,
                BLIP_VISIBLE = true,
                WARDROBE = true,
            },
        },

        STORAGES = { -- You can add more than one storage
            {
                ID = 12,
                MAX_SLOTS = 100,
                LOCATION = vector3(-613.2334, -35.0650, 85.9820),
                LABEL = "Storage",
                WEAPONS = true,
                SHARED = true,
                BLACKLISTED_ITEMS = {},
            }
        },
        DOORS = {       -- DOOR IDS, MUST BE IN VORP DOORLOCKS TO BE DETECTED THESE DOORS DONT NEED PERMISSIONS IN VORP DOORLOCKS SCRIPT
            1189146288, -- Front Door
            365712512,  -- Room 1 Door
            138361190,  -- Room 2 Door
            906448125   -- Back Door
        }
    },

    -- Big Valley Farm House
    {
        POSITION = vector3(-2594.6492, 457.3839, 146.9972),
        BLIP = {
            ENABLE = true,
            SPRITE = `blip_mp_base`,
            STYLE = `BLIP_STYLE_PROPERTY_OWNER`,
            NAME = "My House",
        },

        WARDROBE = {
            ENABLE = true,
            LOCATION = vector3(-2595.87, 460.92, 147.05),
            LABEL = "Wardrobe",
        },

        OWNERS = {
            [1] = {
                DOOR = true,
                STORAGE = true,
                BLIP_VISIBLE = true,
                WARDROBE = true,
            },
        },

        STORAGES = { -- You can add more than one storage
            {
                ID = 13,
                MAX_SLOTS = 100,
                LOCATION = vector3(-2595.0100, 453.5163, 146.9974),
                LABEL = "Storage",
                WEAPONS = true,
                SHARED = true,
                BLACKLISTED_ITEMS = {},
            }
        },
        DOORS = {       -- DOOR IDS, MUST BE IN VORP DOORLOCKS TO BE DETECTED THESE DOORS DONT NEED PERMISSIONS IN VORP DOORLOCKS SCRIPT
            1535511805, -- Front Door
            2395304827  -- Back Door
        }
    },

    -- House on the Little Creek River
    {
        POSITION = vector3(-2177.1870, 718.3368, 122.6199),
        BLIP = {
            ENABLE = true,
            SPRITE = `blip_mp_base`,
            STYLE = `BLIP_STYLE_PROPERTY_OWNER`,
            NAME = "My House",
        },

        WARDROBE = {
            ENABLE = true,
            LOCATION = vector3(-2181.22, 721.0, 126.25),
            LABEL = "Wardrobe",
        },

        OWNERS = {
            [1] = {
                DOOR = true,
                STORAGE = true,
                BLIP_VISIBLE = true,
                WARDROBE = true,
            },
        },

        STORAGES = { -- You can add more than one storage
            {
                ID = 14,
                MAX_SLOTS = 100,
                LOCATION = vector3(-2173.4402, 715.4520, 122.6186),
                LABEL = "Storage",
                WEAPONS = true,
                SHARED = true,
                BLACKLISTED_ITEMS = {},
            }
        },
        DOORS = {       -- DOOR IDS, MUST BE IN VORP DOORLOCKS TO BE DETECTED THESE DOORS DONT NEED PERMISSIONS IN VORP DOORLOCKS SCRIPT
            2212914984, -- Front Door
            2670400201  -- Room 1 Door
        }
    },

    -- Farm House on the outskirts of Blackwater
    {
        POSITION = vector3(-1641.7750, -1360.7200, 84.4027),
        BLIP = {
            ENABLE = true,
            SPRITE = `blip_mp_base`,
            STYLE = `BLIP_STYLE_PROPERTY_OWNER`,
            NAME = "My House",
        },

        WARDROBE = {
            ENABLE = true,
            LOCATION = vector3(-1645.93, -1359.01, 87.5),
            LABEL = "Wardrobe",
        },

        OWNERS = {
            [1] = {
                DOOR = true,
                STORAGE = true,
                BLIP_VISIBLE = true,
                WARDROBE = true,
            },
        },

        STORAGES = { -- You can add more than one storage
            {
                ID = 15,
                MAX_SLOTS = 100,
                LOCATION = vector3(-1642.6538, -1351.1543, 84.4032),
                LABEL = "Storage",
                WEAPONS = true,
                SHARED = true,
                BLACKLISTED_ITEMS = {},
            }
        },
        DOORS = {       -- DOOR IDS, MUST BE IN VORP DOORLOCKS TO BE DETECTED THESE DOORS DONT NEED PERMISSIONS IN VORP DOORLOCKS SCRIPT
            1606546482, -- Front Door
            1309495497, -- Room 1 Door
            1063695460, -- Room 2 Door
            1731691513, -- Bathroom Door
            2310818050  -- Back Door
        }
    },

}


return {
    CONFIG = CONFIG,
}
