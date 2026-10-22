-----------------------------------------------------------------------------------------------
-- SERVER ONLY CONFIG - never add this file to shared_scripts (webhook URLs would leak to clients)
-----------------------------------------------------------------------------------------------
SvConfig = {}

SvConfig.Webhooks = {
    Enabled    = true,
    BotName    = 'Gold Claim Logs',
    AvatarUrl  = '',                -- optional bot avatar image url
    FooterText = 'rsg-goldclaim',
    ServerName = 'My RedM Server',  -- shown as the embed author

    -- what player identifiers to include in every log
    ShowIdentifiers = {
        citizenid = true,
        license   = true,
        discord   = true,   -- also pings as <@id> inside the embed
        steam     = false,
        coords    = true,
    },

    -- channels: one webhook url per channel. Leave '' to disable that channel.
    -- an event falls back to 'default' if its own channel has no url.
    Channels = {
        default   = '',
        placement = '',     -- rocker placed / packed up / lost
        processing= '',     -- processing started, gold & paydirt pickups
        law       = '',     -- illegal claim placed / LEO destroyed
        claims    = '',     -- claim renamed
        security  = '',     -- suspicious / exploit attempts
    },

    -- per event: channel, embed colour (decimal) and on/off toggle
    Events = {
        rocker_placed       = { channel = 'placement',  color = 5763719,  enabled = true },
        rocker_packed       = { channel = 'placement',  color = 15105570, enabled = true },
        rocker_lost         = { channel = 'placement',  color = 15548997, enabled = true },
        processing_started  = { channel = 'processing', color = 3447003,  enabled = true },
        gold_pickup         = { channel = 'processing', color = 15844367, enabled = true },
        paydirt_pickup      = { channel = 'processing', color = 9807270,  enabled = false },
        illegal_placed      = { channel = 'law',        color = 15548997, enabled = true },
        leo_destroyed       = { channel = 'law',        color = 3447003,  enabled = true },
        claim_renamed       = { channel = 'claims',     color = 10181046, enabled = true },
        suspicious          = { channel = 'security',   color = 15548997, enabled = true },
    },

    -- suspicious activity: ping a role (e.g. '123456789012345678') or '' for none
    SecurityPingRole = '',

    -- queue / rate limiting (Discord allows ~5 requests per 2s per webhook)
    BatchInterval = 2000,   -- ms between flushes per channel
    MaxEmbedsPerMessage = 10,
    MaxQueueSize = 200,     -- per channel, oldest dropped beyond this
}
