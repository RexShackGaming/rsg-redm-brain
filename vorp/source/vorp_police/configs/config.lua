---@class vorp_police_config
local Config = {}

Config.DevMode = false

Config.Align = "top-left"                      -- menu alignment

Config.Lang = "English"                        -- language you want to use please make sure its in the translation.lua

Config.Dragcommand = "Drag"                    -- Comand to drag players

Config.PoliceMenuCommand = 'policeMenu'        -- Open the police menu to go on duty, or access other functionalities.

Config.alertPolice = "callpolice"              -- Call for police assistance.

Config.cancelpolicealert = "cancelPoliceAlert" --Cancel a police alert.

Config.finishpolicelert = "finishPoliceAlert"  -- Finish a police alert.

Config.AllowOnlyDeadToAlert = true             -- if true only dead players can alert police if false anyone can alert police

Config.Keys = {                                -- prompts
    B = 0x4CC0E2FE
}


Config.jail = {
    JailCenterCoords = vector3(3339.23, -670.12, 45.83),  -- center of the circle
    JailRadius = 50.0,                                    -- make radius bigger  you can allow players go outside the island or just inside the prison
    JailSpawnCoords = vector3(3339.07, -669.41, 45.83),   -- spawn coords
    JailSpawnHeading = 194.42,                            -- spawn heading
    FreedSpawnCoords = vector3(2518.42, -1308.34, 49.01), -- freed spawn coords
    FreedSpawnHeading = 275.49,                           -- freed spawn heading
    Commands = {
        Jail = "jail",                                    -- jail player /jail <player id> <time in minutes>
        Unjail = "unjail",                                -- unjail player /unjail <player id>
        ChangeJailTime = "changejailtime",                -- change jail time /changejailtime <player id> <time in minutes> to reduce time use negative numbers like -10 will reduce 10 minutes
        CheckJailTime = "checkjailtime"                   -- check jail time /checkjailtime  for jailed players to check how long they have left
    }
}


Config.PoliceJobs = {
    Police = {
        [0] = {
            label = "Sheriff",
            allowAll = true, -- allows all
        },
        [1] = {
            label = "Deputy",
            canHire = true, -- allows open sheriff menu to hire and fire players
            canJail = true, -- allows jail commands
        }
    }
}

Config.AllowEveryoneToUseCuffs = false -- if true anyone can use cuffs if false only police can use cuffs and on duty

-- items
Config.CuffItem = "handcuffs"   -- can only uncuff if theres a key for the handcuffs

Config.KeysItem = "handcuffkey" -- when using this will get you handcuffs if you dont have one already

Config.CuffDelete = true        -- If true the handcuffs are removed from the inventory after use and when you unlock someone with the key the handcuffs are added back to your inventory

Config.ShareStorage = true      -- if true storage for every police station will be shared if false they will be unique
-- storage locations
Config.Storage = {

    Valentine = {
        Name = "Storage",
        Limit = 1000,
        Coords = vector3(-276.97, 810.83, 119.38)
    },
    Strawberry = {
        Name = "Storage",
        Limit = 1000,
        Coords = vector3(-1814.17, -354.75, 164.65)
    },
    Blackwater = {
        Name = "Armoury",
        Limit = 1000,
        Coords = vector3(-765.12, -1272.37, 44.04)
    },
    Rhodes = {
        Name = "Armoury",
        Limit = 1000,
        Coords = vector3(1361.17, -1305.83, 77.76)

    },
    SaintDenis = {
        Name = "Armoury",
        Limit = 1000,
        Coords = vector3(2494.62, -1304.3, 48.95)

    },
    Tumbleweed = {
        Name = "Armoury",
        Limit = 1000,
        Coords = vector3(-5526.59, -2928.51, -1.36)
    },
    Annesburg = {
        Name = "Armoury",
        Limit = 1000,
        Coords = vector3(2904.03, 1309.86, 44.94)
    },
    Armadillo = {
        Name = "Armoury",
        Limit = 1000,
        Coords = vector3(-3622.69, -2600.0, -13.34)
    }
}

-- if true players can use teleport from the police menu if false only from locations
Config.UseTeleportsMenu = true

-- set up locations to teleport to or from
Config.Teleports = {

    Valentine = {
        Name = " Valentine",
        Coords = vector3(-278.17, 814.88, 119.28)
    },
    Strawberry = {
        Name = "Strawberry",
        Coords = vector3(-1805.13, -355.05, 164.14)
    },
    Blackwater = {
        Name = "Blackwater",
        Coords = vector3(-752.53, -1266.1, 43.43)
    },
    Rhodes = {
        Name = "Rhodes",
        Coords = vector3(1354.9, -1306.85, 76.94)

    },
    SaintDenis = {
        Name = "Saint Denis",
        Coords = vector3(2510.0, -1318.0, 48.53)

    },
    Tumbleweed = {
        Name = "Tumbleweed",
        Coords = vector3(-5531.39, -2935.31, -1.91)
    },
    Annesburg = {
        Name = "Annesburg",
        Coords = vector3(2916.59, 1317.09, 44.35)
    },
    Armadillo = {
        Name = "Armadillo",
        Coords = vector3(-3610.4, -2599.16, -13.88)
    }
}

-- blips for stations
Config.Blips = {
    Sprite = "blip_mp_bounty_hunter_introduction",
    Color = "COLOR_WHITE",
    Style = "BLIP_STYLE_FRIENDLY_ON_RADAR"
}

Config.AlertBlips = {
    Name = "Police Alert",
    Color = "COLOR_RED",
    Style = "BLIP_STYLE_CHALLENGE_OBJECTIVE",
    Sprite = "blip_mp_bounty_hunter_introduction"
}

-- police stations  boss menu locations
Config.Stations = {

    Valentine = {
        Name = "Valentine",
        Coords = vector3(-277.73, 804.84, 119.38),
        Teleports = Config.Teleports,
        Storage = Config.Storage
    },
    Strawberry = {
        Name = "Strawberry",
        Coords = vector3(-1807.03, -348.47, 164.65),
        Teleports = Config.Teleports,
        Storage = Config.Storage
    },
    Blackwater = {
        Name = "Blackwater",
        Coords = vector3(-761.95, -1272.62, 44.05),
        Teleports = Config.Teleports,
        Storage = Config.Storage
    },
    Rhodes = {
        Name = "Rhodes",
        Coords = vector3(1361.57, -1303.4, 77.77),
        Teleports = Config.Teleports,
        Storage = Config.Storage
    },
    SaintDenis = {
        Name = "Saint Denis",
        Coords = vector3(2508.46, -1308.56, 48.95),
        Teleports = Config.Teleports,
        Storage = Config.Storage
    },
    Tumbleweed = {
        Name = "Tumbleweed",
        Coords = vector3(-5529.55, -2929.25, -1.36),
        Teleports = Config.Teleports,
        Storage = Config.Storage
    },
    Annesburg = {
        Name = "Annesburg",
        Coords = vector3(2907.11, 1313.93, 44.94),
        Teleports = Config.Teleports,
        Storage = Config.Storage
    },
    Armadillo = {
        Name = "Armadillo",
        Coords = vector3(-3624.7, -2601.96, -13.34),
        Teleports = Config.Teleports,
        Storage = Config.Storage
    }
}

return {
    Config = Config
}
