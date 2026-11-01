Config = {}

-- Voice ranges (metres). The entry with default = true is used on spawn.
Config.Ranges = {
    { name = 'whisper', range = 2.5 },
    { name = 'normal',  range = 8.0, default = true },
    { name = 'shout',   range = 20.0 },
    { name = 'trail',   range = 35.0 },
}

Config.CycleKey     = 0xA5BDCD3C -- RIGHTBRACKET
Config.CycleCommand = 'voice'
Config.SaveRange    = true -- remember each player's last range between sessions (client KVP)

-- Ground ring shown when changing range
Config.ShowRangeRing = true
Config.RingDuration  = 1500
Config.RingColour    = { r = 255, g = 255, b = 255, a = 90 }

-- HUD
Config.ShowHud        = true
Config.HudEditCommand = 'voicehud' -- drag the HUD box to move it
Config.HudToggleCommand = 'togglevoicehud' -- players can hide/show their own HUD (saved per client)

-- Auto-mute (rsg-core metadata)
Config.MuteWhenDead   = true
Config.MuteWhenCuffed = false

-- Admin mute (server-enforced, saved in the database: rsg_voice_mutes)
-- /voicemute [id] [minutes] [reason]  (minutes 0 or blank = permanent)
-- /voiceunmute [id]
Config.AdminMuteCommand   = 'voicemute'
Config.AdminUnmuteCommand = 'voiceunmute'
Config.AdminPermission    = 'admin'
Config.MuteExpiryCheck    = 30 -- seconds between checks for expired mutes

-- Muffled voices: players in a different interior (inside vs outside, another building) sound quieter
Config.Muffle = {
    Enabled  = true,
    Volume   = 0.35, -- 0.0 - 1.0
    Interval = 500,  -- ms between checks
}

-- Speaker icon above nearby players while they talk
-- Texture: overhead / overhead_speaker (rdr3_discoveries textures/overhead)
Config.TalkIcon = {
    Enabled  = true,
    Distance = 15.0, -- metres
    ShowSelf = false, -- also show the icon above yourself while you talk
    Dict     = 'overhead',
    Texture  = 'overhead_speaker',
    Size     = 0.022,
    ZOffset  = 1.05, -- above the ped's root
    Colour      = { r = 255, g = 255, b = 255, a = 220 },
    PartyColour = { r = 217, g = 164, b = 65,  a = 230 }, -- party member using party talk
}

-- Riding party (group voice chat)
-- Party members within TalkRange hear each other while holding the party talk key.
Config.Party = {
    Enabled      = true,
    Command      = 'party',      -- opens the party menu
    TalkKey      = 0x430593AA,   -- hold to talk to your party (default: [ LEFTBRACKET)
    TalkRange    = 100.0,        -- metres: party members further away than this can't hear party talk
    InviteRange  = 10.0,         -- metres: how close a player must be to be invited
    MaxMembers   = 8,            -- including the leader
    InviteTimeout = 30,          -- seconds an invite stays valid

    -- Map blips for your party members
    Blips = {
        Enabled  = true,
        Interval = 3000,                         -- ms between position updates
        Sprite   = 'blip_ambient_companion',     -- textures/blips
        Scale    = 0.7,
        Modifier = 'BLIP_MODIFIER_MP_COLOR_8',   -- blip_modifiers
    },

    -- Share your map waypoint with the party (/partywaypoint, run again with no waypoint to clear)
    Waypoint = {
        Enabled       = true,
        Command       = 'partywaypoint',
        Cooldown      = 5,             -- seconds between shares
        Sprite        = 'blip_code_waypoint',
        GpsColour     = 'COLOR_YELLOW',
        ArriveDistance = 20.0,         -- shared waypoint clears when you get this close
    },
}
