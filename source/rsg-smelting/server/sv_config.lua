-- Server-only config: never put webhook URLs in shared/config.lua (clients can read shared files)
SVConfig = {}

SVConfig.Webhooks = {
    Enabled    = true,
    BotName    = 'RSG Smelting',
    AvatarUrl  = '',                -- optional image URL for the bot avatar
    Footer     = 'rsg-smelting',
    ShowCoords = true,              -- include player coords in embeds

    -- Channels. Events pick one by name; empty URL = that channel is off.
    Urls = {
        smelting = '',              -- normal activity (start / complete / cancel)
        security = '',              -- suspicious activity & failures
        refunds  = '',              -- refunds on disconnect / resource stop / failed refunds
    },

    -- Role/user to ping on security events, e.g. '<@&123456789012345678>' (leave '' for none)
    SecurityPing = '',

    -- Per-event settings: enabled, channel, embed colour (decimal)
    Events = {
        smelt_start     = { enabled = true,  channel = 'smelting', color = 3447003  }, -- blue
        smelt_complete  = { enabled = true,  channel = 'smelting', color = 5763719  }, -- green
        smelt_cancel    = { enabled = true,  channel = 'smelting', color = 16776960 }, -- yellow
        smelt_nospace   = { enabled = true,  channel = 'smelting', color = 15105570 }, -- orange
        smelt_failed    = { enabled = true,  channel = 'security', color = 15548997 }, -- red
        suspicious      = { enabled = true,  channel = 'security', color = 10038562 }, -- dark red
        take_failed     = { enabled = true,  channel = 'security', color = 15105570 },
        refund_failed   = { enabled = true,  channel = 'refunds',  color = 15548997 },
        player_dropped  = { enabled = true,  channel = 'refunds',  color = 9807270  }, -- grey
        rejoin_refund   = { enabled = true,  channel = 'refunds',  color = 5763719  },
        resource_stop   = { enabled = true,  channel = 'refunds',  color = 9807270  },
    },

    -- Discord allows ~5 requests / 2s per webhook; messages are queued and sent at this interval
    SendInterval = 500,             -- ms between sends
    MaxQueue     = 200,             -- drop oldest when exceeded (protects against spam floods)
}
