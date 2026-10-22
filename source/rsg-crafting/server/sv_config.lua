-- SERVER ONLY. Never move this into shared/ or webhook URLs will be sent to every client.
SvConfig = {}

SvConfig.Webhook = {
    Enabled    = true,
    Username   = 'RSG Crafting',
    Avatar     = '',            -- optional avatar image URL
    Footer     = 'rsg-crafting',
    UseRsgLog  = true,          -- also send to rsg-log (if running)
    RateLimit  = 1200,          -- ms between requests per webhook URL (Discord allows ~30/min)
    MaxQueue   = 200,           -- drop oldest logs beyond this to protect memory

    -- one URL per log type; leave '' to disable that type. Use the same URL for all if you like.
    Urls = {
        craft      = '',   -- successful crafts
        failed     = '',   -- craft failed after timing passed (inventory full, refund, etc.)
        cancelled  = '',   -- player cancelled a craft (noisy, off by default)
        suspicious = '',   -- possible exploit: finished too fast, invalid session
        xp         = '',   -- XP given through the GivePlayerCraftingXP export
    },

    Colors = {
        craft      = 5763719,   -- green
        failed     = 15105570,  -- orange
        cancelled  = 9807270,   -- grey
        suspicious = 15548997,  -- red
        xp         = 3447003,   -- blue
    },

    -- role/user ping for suspicious logs, e.g. '<@&123456789012345678>' (leave '' for none)
    SuspiciousMention = '',

    -- player identifiers included in embeds
    ShowIdentifiers = { license = true, discord = true, steam = false },
}
