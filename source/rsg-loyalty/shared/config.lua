Config = {}

-- Master switch: set to false to turn the whole loyalty system off
-- (no point earning, no NPCs/blips, no store, no admin commands, no Discord logs).
-- Player points stay saved in the database and come back when re-enabled.
Config.Enabled = true

-- Loyalty Points Settings
Config.Loyalty = {
    -- Passive points from playtime (set to false to keep the store open
    -- while only awarding points via admin commands / exports)
    EnableEarning = true,

    -- Anti-AFK: only award points if the player moved since the last tick (checked server-side)
    RequireMovement = true,
    -- Minimum distance (metres) the player must move between ticks (~1 minute) to earn
    MinMoveDistance = 5.0,

    -- Max distance (metres) from a loyalty NPC to redeem rewards (checked server-side).
    -- Ignored when Config.UI.EnableCommand is true (menu can be opened anywhere).
    MaxRedeemDistance = 5.0,

    -- Points earned per minute of gameplay
    PointsPerMinute = 1,
    
    -- Maximum points a player can earn per session (resets on relog / character switch)
    MaxPointsPerSession = 500,
    
    -- Minimum time (in seconds) before earning points starts
    MinPlaytimeBeforeEarning = 60,
    
    -- Maximum points an admin can award in a single command/event
    MaxAdminAwardPoints = 10000,
}

-- Reward labels and blip names are locale keys (see locales/*.json).
-- Plain text also works if you don't need translations.

-- Loyalty Store Items (for cash redemption)
Config.CashRewards = {
    {
        label = 'reward_cash_small',
        points = 500,
        amount = 50,
        image = 'dollar.png'
    },
    {
        label = 'reward_cash_medium',
        points = 1000,
        amount = 100,
        image = 'dollar.png'
    },
    {
        label = 'reward_cash_large',
        points = 5000,
        amount = 500,
        image = 'dollar.png'
    },
    {
        label = 'reward_cash_jackpot',
        points = 10000,
        amount = 1000,
        image = 'dollar.png'
    },
}

-- Loyalty Store Items (for item redemption)
Config.ItemRewards = {
    {
        label = 'reward_rolling_block',
        points = 4000,
        item = 'weapon_sniperrifle_rollingblock',
        amount = 1,
        image = 'weapon_sniperrifle_rollingblock.png'
    },
    {
        label = 'reward_ammo_revolver',
        points = 1000,
        item = 'ammo_box_revolver',
        amount = 10,
        image = 'ammo_box_revolver.png'
    },
    {
        label = 'reward_ammo_pistol',
        points = 1000,
        item = 'ammo_box_pistol',
        amount = 10,
        image = 'ammo_box_pistol.png'
    },
    {
        label = 'reward_ammo_rifle',
        points = 1000,
        item = 'ammo_box_rifle',
        amount = 10,
        image = 'ammo_box_rifle.png'
    },
    {
        label = 'reward_ammo_repeater',
        points = 1000,
        item = 'ammo_box_repeater',
        amount = 10,
        image = 'ammo_box_repeater.png'
    },
    {
        label = 'reward_ammo_shotgun',
        points = 1000,
        item = 'ammo_box_shotgun',
        amount = 10,
        image = 'ammo_box_shotgun.png'
    },
}

-- UI Settings
Config.UI = {
    -- Command to open loyalty menu
    OpenCommand = 'loyalty',
    
    -- Enable loyalty command (set to false to disable)
    EnableCommand = false,
    
    -- Notification duration (in milliseconds)
    NotificationDuration = 5000,
}

-- Image Settings (path to rsg-inventory images)
Config.Image = 'nui://rsg-inventory/html/images/'

-- Export Security Settings
Config.Exports = {
    -- Restrict mutation exports (addLoyaltyPoints, removeLoyaltyPoints) to specific resources
    -- By default, NO resources are allowed (secure by default)
    -- Add resource names to allow them to use mutation exports
    -- Example: {'my-admin-menu', 'my-other-resource'}
    AllowedResources = {},
    
    -- Set to true to allow all resources (INSECURE - only use for testing)
    AllowAllResources = false,
}

-- Discord Webhook Settings (WebhookURL is set in server/config.lua - server only)
Config.Discord = {
    EnableWebhooks = true,
    
    LogEvents = {
        PointsEarned = false,
        RedemptionSuccess = true,
        RedemptionFailed = true,
        AdminPointAward = true,
    },
    
    Leaderboard = {
        Enable = true,
        IntervalMinutes = 60,
        ShowCurrent = true,
        ShowLifetime = false,
    }
}

-- npc settings
Config.Performance = {
    NpcSpawnDistance = 20.0, -- Distance to spawn/despawn NPCs
    NpcFadeIn = true,        -- Fade NPCs in/out when spawning/despawning
    NpcFadeSpeed = 40,       -- Fade animation speed (ms between steps)
}


-- loyalty npc locations
Config.LoyaltyLocations = {

    {   --valentine
        name = 'Valentine Loyalty',
        coords = vector3(-360.72, 782.02, 116.21),
        npcmodel = `s_m_m_valdealer_01`,
        npccoords = vec4(-360.72, 782.02, 116.21, 281.40),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = {
            blipSprite = 'blip_health',
            blipScale = 0.2,
            blipName = 'blip_valentine',
        },
        showblip = true
    },
    {   --rhodes
        name = 'Rhodes Loyalty',
        coords = vector3(1301.02, -1301.42, 76.46),
        npcmodel = `s_m_m_valdealer_01`,
        npccoords = vec4(1301.02, -1301.42, 76.46, 295.61),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = {
            blipSprite = 'blip_health',
            blipScale = 0.2,
            blipName = 'blip_rhodes',
        },
        showblip = true
    },
    {   --saintdenis
        name = 'Saint Denis Loyalty',
        coords = vector3(2864.47, -1164.81, 46.05),
        npcmodel = `s_m_m_valdealer_01`,
        npccoords = vec4(2864.47, -1164.81, 46.05, 282.30),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = {
            blipSprite = 'blip_health',
            blipScale = 0.2,
            blipName = 'blip_saintdenis',
        },
        showblip = true
    },
    {   --vanhorn
        name = 'Van-Horn Loyalty',
        coords = vector3(2968.61, 558.09, 44.50),
        npcmodel = `s_m_m_valdealer_01`,
        npccoords = vec4(2968.61, 558.09, 44.50, 55.17),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = {
            blipSprite = 'blip_health',
            blipScale = 0.2,
            blipName = 'blip_vanhorn',
        },
        showblip = true
    },
    {   --blackwater
        name = 'Blackwater Loyalty',
        coords = vector3(-741.59, -1331.63, 43.49),
        npcmodel = `s_m_m_valdealer_01`,
        npccoords = vec4(-741.59, -1331.63, 43.49, 94.69),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = {
            blipSprite = 'blip_health',
            blipScale = 0.2,
            blipName = 'blip_blackwater',
        },
        showblip = true
    },
    {   --strawberry
        name = 'Strawberry Loyalty',
        coords = vector3(-1787.66, -433.11, 155.35),
        npcmodel = `s_m_m_valdealer_01`,
        npccoords = vec4(-1787.66, -433.11, 155.35, 5.66),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = {
            blipSprite = 'blip_health',
            blipScale = 0.2,
            blipName = 'blip_strawberry',
        },
        showblip = true
    },
    {   --armadillo
        name = 'Armadillo Loyalty',
        coords = vector3(-3662.26, -2616.17, -13.95),
        npcmodel = `s_m_m_valdealer_01`,
        npccoords = vec4(-3662.26, -2616.17, -13.95, 63.77),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = {
            blipSprite = 'blip_health',
            blipScale = 0.2,
            blipName = 'blip_armadillo',
        },
        showblip = true
    },

}