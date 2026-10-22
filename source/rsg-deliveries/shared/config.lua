Config = {}

---------------------------------
-- discord webhook settings
---------------------------------
Config.Webhook = {
    url = '', -- Discord webhook URL (leave empty to disable)
    title = 'RSG Deliveries',
    color = 8531968, -- embed color (decimal)
    footer = 'rsg-deliveries',
}

---------------------------------
-- blip settings
---------------------------------
Config.Blip = {
    blipSprite = 'blip_ambient_delivery',
    blipScale = 0.2,
}

---------------------------------
-- npc settings
---------------------------------
Config.DistanceSpawn = 20.0
Config.FadeIn = true

---------------------------------
-- settings
---------------------------------
Config.SpawnVehDistance = 5.0 -- check to see if another cart has spawned
Config.DestinationMarker = true
Config.UIPosition = "top-center" -- text UI position
Config.ShowDeliveryTimerUI = false -- toggle lib.showTextUI for the delivery timer on/off
Config.FadeIncrement = 51 -- alpha fade increment
Config.DefaultDeliveryTime = 30 -- default delivery time limit in minutes
Config.MaxRewardAmount = 500 -- maximum cash reward to prevent exploitation
Config.InteractionDistance = 2.0 -- NPC interaction distance
Config.CompleteDistance = 10.0 -- how close the wagon must be to the drop-off to complete

---------------------------------
-- anti-exploit settings
---------------------------------
Config.DeliveryCooldown = 60 -- seconds a player must wait between deliveries (0 = off)
Config.MaxAverageSpeed = 25.0 -- m/s; deliveries finished faster than distance / this are rejected (teleport check)
Config.RequireWagonAtDestination = true -- server checks the delivery wagon is actually at the drop-off (needs OneSync)

---------------------------------
-- delivery UI settings
---------------------------------
Config.ShowRewardImages = true -- show reward item images in the delivery UI
Config.ImagePath = 'nui://rsg-inventory/html/images/' -- where item images live (uses the item's image from rsg-core shared items)
-- optional per-item override: add image = 'myimage.png' (or a full nui:// / https:// url) inside any itemreward block

-- friendly wagon names shown in the UI (falls back to the model name)
Config.WagonLabels = {
    cart01 = 'Supply Cart',
}

---------------------------------
-- distance-based reward settings
---------------------------------
Config.RewardPerDistance = 0.01 -- Cash reward per meter traveled (e.g., 0.05 = $0.05 per meter)
Config.BaseReward = 0 -- Base reward given regardless of distance

---------------------------------
-- delivery locations with multiple choice destinations
---------------------------------
Config.DeliveryLocations = {
    {
        label = "Valentine Deliveries",
        npcmodel = "MP_U_M_M_TRADER_01",
        npccoords = vector4(-340.5837, 816.3152, 116.9300, 136.7859),
        cartSpawn = vector4(-347.9996, 815.5305, 116.7226, 168.6349),
        deliveries = {
            {
                label = "Blackwater Delivery",
                description = "From Valentine to Blackwater",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = true,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3 (-748.98, -1226.36, 43.16),
            },
            {
                label = "Strawberry Delivery",
                description = "From Valentine to Strawberry",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-1783.97, -439.35, 155.23),
            },
            {
                label = "Macfarlanes Ranch Delivery",
                description = "From Valentine to Macfarlanes Ranch",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-2381.418, -2384.764, 61.069843),
            },
            {
                label = "Tumbleweed Delivery",
                description = "From Valentine to Tumbleweed",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-5521.942, -2938.532, -1.995861),
            },
            {
                label = "Annesburg Delivery",
                description = "From Valentine to Annesburg",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(3017.0349, 1438.4769, 46.421833),
            },
            {
                label = "SaintDenis Delivery",
                description = "From Valentine to SaintDenis",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(2899.09, -1172.57, 46.11),
            },
        },
    },
    {
        label = "Blackwater Deliveries",
        npcmodel = "MP_U_M_M_TRADER_01",
        npccoords = vector4(-743.7046, -1218.822, 43.29129, 94.302909),
        cartSpawn = vector4(-757.1296, -1225.244, 43.54446, 0.8211954),
        deliveries = {
            {
                label = "Valentine Delivery",
                description = "From Blackwater to Valentine",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = true,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-347.9996, 815.5305, 116.7226),
            },
            {
                label = "Strawberry Delivery",
                description = "From Blackwater to Strawberry",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-1792.688, -434.3452, 155.59338),
            },
            {
                label = "Macfarlanes Ranch Delivery",
                description = "From Blackwater to Macfarlanes Ranch",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-2381.418, -2384.764, 61.069843),
            },
            {
                label = "Tumbleweed Delivery",
                description = "From Blackwater to Tumbleweed",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-5521.942, -2938.532, -1.995861),
            },
            {
                label = "Annesburg Delivery",
                description = "From Blackwater to Annesburg",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(3017.0349, 1438.4769, 46.421833),
            },
            {
                label = "SaintDenis Delivery",
                description = "From Blackwater to SaintDenis",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(2899.09, -1172.57, 46.11),
            },
        },
    },
    {
        label = "Strawberry Deliveries",
        npcmodel = "MP_U_M_M_TRADER_01",
        npccoords = vector4(-1798.899, -425.6275, 156.37739, 352.46316),
        cartSpawn = vector4(-1788.618, -439.5259, 155.18444, 80.844512),
        deliveries = {
            {
                label = "Blackwater Delivery",
                description = "From Strawberry to Blackwater",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = true,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-748.98, -1226.36, 43.16),
            },
            {
                label = "Valentine Delivery",
                description = "From Strawberry to Valentine",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = true,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-347.9996, 815.5305, 116.7226), 
            },
            {
                label = "Macfarlanes Ranch Delivery",
                description = "From Strawberry to Macfarlanes Ranch",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-2381.418, -2384.764, 61.069843),
            },
            {
                label = "Tumbleweed Delivery",
                description = "From Strawberry to Tumbleweed",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-5521.942, -2938.532, -1.995861),
            },
            {
                label = "Annesburg Delivery",
                description = "From Strawberry to Annesburg",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(3017.0349, 1438.4769, 46.421833),
            },
            {
                label = "SaintDenis Delivery",
                description = "From Strawberry to SaintDenis",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(2899.09, -1172.57, 46.11),
            },
        },
    },
    {
        label = "Macfarlanes Ranch Deliveries",
        npcmodel = "MP_U_M_M_TRADER_01",
        npccoords = vector4(-2357.585, -2367.583, 62.18066, 168.52516),
        cartSpawn = vector4(-2352.572, -2398.797, 62.061191, 175.71217),
        deliveries = {
            {
                label = "Blackwater Delivery",
                description = "From Macfarlanes Ranch to Blackwater",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = true,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-748.98, -1226.36, 43.16),
            },
            {
                label = "Strawberry Delivery",
                description = "From Macfarlanes Ranch to Strawberry",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-1792.688, -434.3452, 155.59338),
            },
            {
                label = "Valentine Delivery",
                description = "From Macfarlanes Ranch to Valentine",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = true,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-347.9996, 815.5305, 116.7226),
            },
            {
                label = "Tumbleweed Delivery",
                description = "From Macfarlanes Ranch to Tumbleweed",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-5521.942, -2938.532, -1.995861),
            },
            {
                label = "Annesburg Delivery",
                description = "From Macfarlanes Ranch to Annesburg",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(3017.0349, 1438.4769, 46.421833),
            },
            {
                label = "SaintDenis Delivery",
                description = "From Macfarlanes Ranch to SaintDenis",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(2899.09, -1172.57, 46.11),
            },
        },
    },
    {
        label = "Tumbleweed Deliveries",
        npcmodel = "A_M_M_SDDockForeman_01",
        npccoords = vector4(-5529.143, -2932.52, -1.95342, 212.60365),
        cartSpawn = vector4(-5523.004, -2936.102, -2.007142, 255.0812),
        deliveries = {
            {
                label = "Blackwater Delivery",
                description = "From Tumbleweed to Blackwater",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = true,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-748.98, -1226.36, 43.16),
            },
            {
                label = "Strawberry Delivery",
                description = "From Tumbleweed to Strawberry",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-1792.688, -434.3452, 155.59338),
            },
            {
                label = "Macfarlanes Ranch Delivery",
                description = "From Tumbleweed to Macfarlanes Ranch",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-2381.418, -2384.764, 61.069843),
            },
            {
                label = "Valentine Delivery",
                description = "From Tumbleweed to Valentine",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = true,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-347.9996, 815.5305, 116.7226),
            },
            {
                label = "Annesburg Delivery",
                description = "From Tumbleweed to Annesburg",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(3017.0349, 1438.4769, 46.421833),
            },
            {
                label = "SaintDenis Delivery",
                description = "From Tumbleweed to SaintDenis",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(2899.09, -1172.57, 46.11),
            },
        },
    },
    {
        label = "Annesburg Deliveries",
        npcmodel = "MP_U_M_M_TRADER_01",
        npccoords = vector4(3022.6753, 1441.2214, 46.9519, 73.7268),
        cartSpawn = vector4(3009.5029, 1450.3727, 46.9537, 73.7677),
        deliveries = {
            {
                label = "Blackwater Delivery",
                description = "From Annesburg to Blackwater",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = true,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-748.98, -1226.36, 43.16),
            },
            {
                label = "Strawberry Delivery",
                description = "From Annesburg to Strawberry",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-1792.688, -434.3452, 155.59338),
            },
            {
                label = "Macfarlanes Ranch Delivery",
                description = "From Annesburg to Macfarlanes Ranch",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-2381.418, -2384.764, 61.069843),
            },
            {
                label = "Tumbleweed Delivery",
                description = "From Annesburg to Tumbleweed",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-5521.942, -2938.532, -1.995861),
            },
            {
                label = "Valentine Delivery",
                description = "From Annesburg to Valentine",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = true,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-347.9996, 815.5305, 116.7226),
            },
            {
                label = "SaintDenis Delivery",
                description = "From Annesburg to SaintDenis",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(2899.09, -1172.57, 46.11),
            },
        },
    },
    {
        label = "SaintDenis Deliveries",
        npcmodel = "A_M_M_SDDockForeman_01",
        npccoords = vector4(2904.1989, -1169.292, 46.112228, 96.722068),
        cartSpawn = vector4(2898.8957, -1169.942, 46.093143, 100.06992),
        deliveries = {
            {
                label = "Blackwater Delivery",
                description = "From SaintDenis to Blackwater",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = true,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-748.98, -1226.36, 43.16),
            },
            {
                label = "Strawberry Delivery",
                description = "From SaintDenis to Strawberry",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-1792.688, -434.3452, 155.59338),
            },
            {
                label = "Macfarlanes Ranch Delivery",
                description = "From SaintDenis to Macfarlanes Ranch",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-2381.418, -2384.764, 61.069843),
            },
            {
                label = "Tumbleweed Delivery",
                description = "From SaintDenis to Tumbleweed",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-5521.942, -2938.532, -1.995861),
            },
            {
                label = "Annesburg Delivery",
                description = "From SaintDenis to Annesburg",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = false,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(3017.0349, 1438.4769, 46.421833),
            },
            {
                label = "Valentine Delivery",
                description = "From SaintDenis to Valentine",
                reward = {
                    priceByDistance = {
                        activation = true,
                        multiplier = 0.09,
                    },
                    priceByConfig = {
                        activation = false,
                        price = 10.0,
                    },
                    itemreward = {
                        activation = true,
                        itemname = "bread",
                        itemamount = {1, 4},
                    },
                },
                wagonModel = "cart01",
                cargo = "pg_teamster_cart01_gen",
                light = "pg_teamster_cart01_lightupgrade3",
                deliveryLoc = vector3(-347.9996, 815.5305, 116.7226),
            },
        },
    }
}

-- https://github.com/femga/rdr3_discoveries/blob/f729ba03f75a591ce5c841642dc873345242f612/vehicles/vehicle_modding/vehicle_propsets.lua
-- https://github.com/femga/rdr3_discoveries/blob/f729ba03f75a591ce5c841642dc873345242f612/vehicles/vehicle_modding/vehicle_lantern_propsets.lua
