---------------------------------------------------------------
-- rsg-hunting server-only config (never sent to clients)
-- keep your webhook urls here, NOT in config.lua
---------------------------------------------------------------
SVConfig = {}

SVConfig.Webhooks = {
    Enabled    = true,
    BotName    = 'RSG Hunting',
    BotAvatar  = '',                 -- image url, '' = webhook default
    FooterText = 'rsg-hunting',
    ServerName = 'My RedM Server',   -- shown in embed author line
    ShowIdentifiers = true,          -- add license + discord mention to embeds
    MentionOnAlert  = '',            -- e.g. '<@&ROLE_ID>' pinged on security alerts

    -- each channel: url ('' = off), colour (decimal), enabled
    Channels = {
        skinning = { url = '', colour = 5763719,  enabled = true },  -- skins (batched, see below)
        trapper  = { url = '', colour = 15844367, enabled = true },  -- trapper basket sales
        butcher  = { url = '', colour = 15105570, enabled = true },  -- butcher carcass sales
        levelup  = { url = '', colour = 3447003,  enabled = true },  -- hunting level ups
        security = { url = '', colour = 15548997, enabled = true },  -- rejected/suspicious requests
        admin    = { url = '', colour = 9807270,  enabled = true },  -- admin/console actions
    },

    -- any channel left empty falls back to this url ('' = drop)
    DefaultUrl = '',

    -- skinning happens a lot: summarise per player every X seconds (0 = send every skin)
    SkinningBatchSeconds = 120,

    -- trapper/butcher sales at or above this cash value also go to the security channel
    HighValueSale = 75,

    -- security: only alert once per player per reason within this many seconds
    SecurityThrottleSeconds = 60,
}
