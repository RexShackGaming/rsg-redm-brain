Config = {}
-- build the database tables automatically on start (set false and import the SQL file for a manual install)
Config.AutoDatabase = true

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
    RadioColour = { r = 111, g = 191, b = 115, a = 230 }, -- player transmitting on your radio channel
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

-- Radio channels (audio only)
-- rsg-voice only carries the voice. Who may join which frequency is decided by another resource
-- (rsg-radio) through the server exports JoinRadio / LeaveRadio.
-- While you hold the talk key, everyone on your channel hears you at full volume, at any distance.
Config.Radio = {
    Enabled    = true,
    UseKeyMapping = true,    -- bind the transmit key by name with RegisterKeyMapping (recommended; players can rebind it in the game's key settings)
    Key        = 'O',        -- default key for the key mapping (hold to transmit)
    TalkKey    = 0xF1301666, -- only used when UseKeyMapping = false: control hash of O (RSGCore.Shared.Keybinds). Some setups never report it
    NearbyHear = true,       -- players inside your voice range also hear you while you transmit
    MaxMembers = 64,         -- players per channel
    MaxTransmitSeconds = 0,  -- longest single transmission in seconds (0 = unlimited). At the limit the key must be released
    TransmitCooldown   = 3,  -- seconds before the player can transmit again after hitting the limit
    Debug      = false,      -- print the transmit key state and what blocks it in the F8 console (set true to troubleshoot)

    -- Radio static, synthesised in the HUD page (no game sounds needed)
    Static = {
        Enabled  = true,
        Volume   = 0.3,   -- 0.0 - 1.0
        Hiss     = true,  -- low static while someone transmits on your channel
        Squelch  = true,  -- short noise burst when a transmission starts and ends
        SelfHiss = false, -- also hear static while you transmit (you always hear the squelch)
    },
}

-- Who wins when voice channels overlap
Config.Priority = {
    -- When the radio key and the party talk key are held together:
    -- 'first' = whichever was pressed first keeps the line, 'radio' = radio takes over, 'party' = riding-party voice takes over
    RadioVsParty = 'first',

    -- A phone call (rsg-telephone) takes priority over radio and party voice while it is running
    Call = {
        Enabled            = true,
        BlockRadioTransmit = true, -- cannot transmit on the radio during a call
        BlockPartyTransmit = true, -- cannot talk to the riding party during a call
        MuteIncomingRadio  = true, -- radio transmissions are not heard during a call
        MutePartyVoice     = true, -- party talk is not heard during a call
    },
}
