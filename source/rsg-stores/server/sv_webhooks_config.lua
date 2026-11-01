-- ============================================
-- DISCORD WEBHOOKS (SERVER ONLY)
-- This file is loaded server-side only, so webhook URLs are never sent to clients.
-- Leave a URL empty ('') to disable that channel.
-- ============================================
WebhookConfig = {
    Enabled = true,

    -- Name/avatar shown on every message
    BotName   = 'RSG Stores',
    AvatarUrl = '',

    -- One URL per log channel (can all be the same URL)
    Urls = {
        purchases = '',  -- cart purchases
        sales     = '',  -- items sold to shops
        admin     = '',  -- NPC / blip / shop edits
        security  = '',  -- exploit attempts, denied admin access, out-of-range trades
        system    = '',  -- resource start, DB load failures
    },

    -- Role/user pings for security alerts, e.g. '<@&123456789012345678>'. '' = no ping
    SecurityPing = '',

    -- Purchases/sales at or above this cash value are flagged as "Large" and also copied to security
    LargeTransaction = 500.0,

    -- Queue tuning (stays under Discord's 5 req / 2s per-webhook limit)
    FlushInterval  = 2000, -- ms between queue flushes
    EmbedsPerPost  = 10,   -- Discord max is 10
    MaxQueue       = 500,  -- oldest entries dropped beyond this

    -- Player identifiers shown in embeds
    ShowIdentifiers = { license = true, discord = true, steam = false, ip = false },

    Colors = {
        purchases = 0x6FBF73,
        sales     = 0xD9A441,
        admin     = 0x5A8DEE,
        security  = 0xE0554F,
        system    = 0x9A9A9A,
    },
}
