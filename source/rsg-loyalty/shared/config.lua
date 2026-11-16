Config = {}

-- Master switch: set to false to turn the whole loyalty system off
-- (no point earning, no NPCs/blips, no store, no admin commands, no Discord logs).
-- Player points stay saved in the database and come back when re-enabled.
Config.Enabled = true

-- Create the `rsg_loyalty` table automatically on start.
-- Set to false to import installation/rsg_loyalty.sql manually instead.
Config.AutoDatabase = true

-- While the loyalty menu is open, block game controls but keep push-to-talk working.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

-- Loyalty Points Settings
Config.Loyalty = {
    -- Passive points from playtime, awarded by the server once a minute
    -- (set to false to keep the store open while only awarding points via admin commands / exports)
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

-- Loyalty tiers, based on LIFETIME points (keep sorted, lowest first).
-- discount   = % off every reward cost    earnMultiplier = multiplies passive and activity points
-- label is a locale key. Remove the table entries (or set discount = 0, earnMultiplier = 1.0) to turn perks off.
Config.Tiers = {
    { key = 'bronze',   label = 'tier_bronze',   minLifetime = 0,     discount = 0,  earnMultiplier = 1.0  },
    { key = 'silver',   label = 'tier_silver',   minLifetime = 2500,  discount = 5,  earnMultiplier = 1.1  },
    { key = 'gold',     label = 'tier_gold',     minLifetime = 10000, discount = 10, earnMultiplier = 1.25 },
    { key = 'platinum', label = 'tier_platinum', minLifetime = 25000, discount = 15, earnMultiplier = 1.5  },
}

-- Daily login bonus and streak (claimed once per calendar day, database date)
Config.Daily = {
    Enabled = true,
    BasePoints = 25,        -- day 1
    PerStreakDay = 5,       -- added for each extra day in a row
    MaxPoints = 100,        -- cap for the daily amount (milestones are extra)
    Milestones = {          -- extra points on a streak day
        [7] = 100,
        [14] = 250,
        [30] = 1000,
    },
}

-- Admin points boost: /loyaltyboost [multiplier] [minutes]  or  /loyaltyboost off
-- (applies to passive and activity points, not to admin awards or the daily bonus)
Config.Boost = {
    MaxMultiplier = 5.0,
    MaxMinutes = 240,
}

-- Activity points for other resources. A script calls (server side):
--   exports['rsg-loyalty']:awardActivity(source, 'hunting')
-- The calling resource must be listed in Config.Exports.AllowedResources.
-- points = base points, cooldown = seconds between awards per player,
-- dailyCap = max points per player per day for that activity (counted after tier/boost multipliers).
Config.Activities = {
    hunting  = { points = 10, cooldown = 30,  dailyCap = 200 },
    delivery = { points = 25, cooldown = 120, dailyCap = 250 },
    fishing  = { points = 5,  cooldown = 20,  dailyCap = 100 },
    bounty   = { points = 50, cooldown = 300, dailyCap = 300 },
}

-- Points history shown in the menu
Config.History = {
    Rows = 20,      -- entries shown (max 50)
    KeepDays = 30,  -- older entries are deleted
}

-- Notifications
Config.Notify = {
    AffordableReward = true, -- "You can now afford: <reward>" when passive earning reaches a reward cost
}

-- Special rewards tab: entries with rotating = true share Count slots that change every Period ('day' or 'week').
-- Entries with rotating = false are always available.
Config.Rotation = {
    Count = 2,
    Period = 'week',
}

-- Optional fields on ANY reward (cash, item or special):
--   minTier = 'gold'            tier key from Config.Tiers
--   jobs    = { 'vallaw' }      job names allowed to redeem (the player's active job)
--   stock   = 10                total available (all players) per period
--   limit   = 1                 per player per period
--   period  = 'day' | 'week' | 'month'   (leave out for lifetime stock/limit)
--   id      = 'my_reward'       stable id for stock/limit tracking (default: type_index)
-- Special reward types: 'cash', 'item' and 'custom'. A custom reward calls a server export in
-- another resource: export = { resource = 'rsg-x', func = 'GiveVoucher' } is called as
-- func(source, unpack(args)); returning false (or erroring) refunds the points.
Config.SpecialRewards = {
    {
        id = 'special_cash_week', type = 'cash', rotating = true,
        label = 'reward_special_cash', points = 2500, amount = 300, image = 'dollar.png',
        limit = 1, period = 'week',
    },
    {
        id = 'special_ammo_bundle', type = 'item', rotating = true,
        label = 'reward_special_ammo', points = 1500, item = 'ammo_box_rifle', amount = 20,
        image = 'ammo_box_rifle.png', limit = 2, period = 'week',
    },
    {
        id = 'special_rolling_block', type = 'item', rotating = true,
        label = 'reward_special_sniper', points = 3500, item = 'weapon_sniperrifle_rollingblock', amount = 1,
        image = 'weapon_sniperrifle_rollingblock.png', minTier = 'gold', stock = 5, period = 'week',
    },
    {
        id = 'special_cash_silver', type = 'cash', rotating = true,
        label = 'reward_special_cash_silver', points = 4000, amount = 600, image = 'dollar.png',
        minTier = 'silver', limit = 1, period = 'week',
    },
    -- custom reward example (needs a locale key for the label and a resource that exports the function):
    -- {
    --     id = 'voucher_horse', type = 'custom', rotating = false,
    --     label = 'reward_voucher_horse', points = 8000, image = 'horse_voucher.png',
    --     export = { resource = 'my-resource', func = 'GiveHorseVoucher' }, args = { 'horse_voucher' },
    --     minTier = 'gold', limit = 1, period = 'month',
    -- },
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
    -- PointsEarned logs are sent as one summary embed per batch instead of one message per tick
    PointsBatchMinutes = 10,
    
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
