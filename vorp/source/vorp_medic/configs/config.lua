---@class vorp_medic
local Config = {}

Config.DevMode = false

Config.Align = "top-left"                -- menu alignment

Config.Lang = "English"                  -- language you want to use please make sure its in the translation.lua

Config.AllowOnlyDeadToAlert = true       -- if true only dead players can alert doctors

Config.AlertDoctorCommand = "calldoctor" -- command to alert doctors
Config.cancelalert = "cancelDoctorAlert" -- command to cancel alert
Config.finishalert = "finishDoctorAlert" -- command to finish alert
Config.DoctorMenuCommand = 'doctormenu'  -- Command to go on duty and teleport


Config.Keys = { -- prompts
    B = 0x4CC0E2FE
}


-- jobs that can open hire menu
Config.DoctorJobs = {
    doctor = {
        [0] = {
            label = "Doctor",
            allowAll = true, -- allows all
        },
        [1] = {
            label = "Nurse",
            CanHire = false, -- can hire players?
        },
    }
}

-- if true storage for every doctor station will be shared if false they will be unique
Config.ShareStorage = true

-- storage locations
-- check the server.lua for webhook url location line 21 in server.lua
Config.Storage = {

    Valentine = {
        Name = "Medical storage",
        Limit = 1000,
        Coords = vector3(-288.74, 808.77, 119.44),
    },
    Strawberry = {
        Name = "Medical storage",
        Limit = 1000,
        Coords = vector3(-1803.33, -432.59, 158.83),
    },
    SaintDenis = {
        Name = "Medical storage",
        Limit = 1000,
        Coords = vector3(2733.1, -1230.26, 50.42),
    },

    -- add more locations here

}

-- if true players can use teleport from the doctor menu if false only from locations
Config.UseTeleportsMenu = true

-- set up locations to teleport to or from
Config.Teleports = {

    Valentine = {
        Name = " Teleport",
        Coords = vector3(-280.38, 817.81, 119.38)
    },
    Strawberry = {
        Name = "Teleport",
        Coords = vector3(-1793.37, -422.81, 155.97)
    },
    SaintDenis = {
        Name = "Teleport",
        Coords = vector3(2723.1, -1238.92, 49.95)

    },

    -- add more locations here
}

-- blips for stations
Config.Blips = {
    Color = "COLOR_WHITE",
    Style = "BLIP_STYLE_FRIENDLY_ON_RADAR",
    Sprite = "blip_mp_travelling_saleswoman"
}

Config.AlertBlips = {
    Color = "COLOR_RED",
    Style = "BLIP_STYLE_CHALLENGE_OBJECTIVE",
    Sprite = "blip_mp_travelling_saleswoman"
}

-- doctor stations  boss menu locations
Config.Stations = {

    Valentine = {
        Name = "Boss Menu",
        Coords = vector3(-288.82, 808.44, 119.43),
        Teleports = Config.Teleports,
        Storage = Config.Storage
    },
    Strawberry = {
        Name = "Boss Menu",
        Coords = vector3(-1807.87, -430.77, 158.83),
        Teleports = Config.Teleports,
        Storage = Config.Storage
    },
    SaintDenis = {
        Name = "Boss Menu",
        Coords = vector3(2721.29, -1233.11, 50.37),
        Teleports = Config.Teleports,
        Storage = Config.Storage
    },

    -- add more locations here
}

-- usable items
Config.Items = {
    bandage = {              -- item name
        health = 50,         -- health to add dont use decimals
        stamina = 100,       -- stamina to add dont use decimals
        revive = false,      -- if true will revive player,
        mustBeOnDuty = false -- if true player must be on duty to use this item /have the job
    },
    potion = {
        health = 100,
        stamina = 0,
        revive = false,
        mustBeOnDuty = false
    },
    syringe = {
        health = 0,
        stamina = 0,
        revive = true,
        mustBeOnDuty = true
    },

}

return {
    Config = Config,
}
