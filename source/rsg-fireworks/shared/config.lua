Config = {}

Config.EnableSound = true
Config.BigFireworkTime = 30 -- seconds
Config.SmallFireworkTime = 30 -- seconds

-- Placement
Config.PlacementDistance = 6.0        -- max metres between the player and the placed firework
Config.FuseTime = 5000                -- ms between placing the firework and it igniting
Config.AllowInteriorPlacement = false -- false = fireworks can only be placed outside (rsg-gizmo interior rule)

-- Security / anti-abuse
Config.PendingFireworkTimeout = 30000 -- ms after using an item in which the client may finish placing it
Config.BroadcastCooldown = 1000       -- ms between ignited fireworks per player
Config.DisplayCooldown = 5000         -- ms between display commands per admin

-- Fireworks Displays Configuration
Config.Displays = {
    {
        name = 'Valentine Display',
        command = 'valfireworkdisplay',
        fireworks = {
            { type = 'small', coords = vector3(-377.75, 783.47, 116.15), delay = 0 },
            { type = 'small', coords = vector3(-217.21, 811.89, 124.43), delay = 0 },
            { type = 'small', coords = vector3(-210.29, 651.33, 112.97), delay = 0 },
            { type = 'big',   coords = vector3(-462.07, 855.64, 126.35), delay = 30000 },
            { type = 'small', coords = vector3(-377.75, 783.47, 116.15), delay = 35000 },
            { type = 'big',   coords = vector3(-101.37, 908.84, 202.16), delay = 30000 },
            { type = 'small', coords = vector3(-217.21, 811.89, 124.43), delay = 35000 },
            { type = 'big',   coords = vector3(20.68, 499.01, 163.41),   delay = 30000 },
            { type = 'small', coords = vector3(-210.29, 651.33, 112.97), delay = 35000 },
        }
    },
    -- add more displays here
}
