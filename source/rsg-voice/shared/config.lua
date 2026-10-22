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

-- Admin mute (server-enforced)
Config.AdminMuteCommand = 'voicemute'

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
}
