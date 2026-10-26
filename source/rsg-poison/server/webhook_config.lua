-- Discord webhook configuration for rsg-poison.
-- SERVER-ONLY: never move this into shared_scripts/client_scripts — webhook
-- URLs are credentials and anything shared to the client can be read by players.

WebhookConfig = {
    Enabled = true,           -- master switch for all webhook logging
    Debug   = false,          -- print every send/failure to the server console

    ServerName = 'My RedM Server', -- shown in every embed footer
    BotName    = 'RSG Poison',     -- webhook display name ('' = use the webhook's own)
    AvatarUrl  = '',               -- webhook avatar URL ('' = use the webhook's own)

    -- Paste your Discord webhook URLs. Any event left as '' falls back to
    -- `default`; leave everything blank to safely disable logging.
    Urls = {
        default         = '',
        poisoned        = '', -- player poisoned (snake bite / poison ammo / poison weapon)
        resumed         = '', -- poison restored on login / resource restart
        antidoteUsed    = '', -- antidote consumed and cure accepted
        antidoteWasted  = '', -- antidote consumed but drinking was interrupted (death)
        antidoteDenied  = '', -- antidote use refused (not poisoned / already drinking)
        death           = '', -- died while poisoned
        cured           = '', -- cured by another resource (exports.CurePlayer, e.g. medic)
        exploitAttempt  = '', -- forged cure / invalid data from a client (use a private staff channel)
        system          = '', -- resource start and /poisonwebhooktest
    },

    -- Per-event switches. Events not listed use `default`.
    Events = {
        default         = true,
        poisoned        = true,
        resumed         = true,
        antidoteUsed    = true,
        antidoteWasted  = true,
        antidoteDenied  = false, -- noisy, off by default
        death           = true,
        cured           = true,
        exploitAttempt  = true,
        system          = true,
    },

    -- Optional role pings per event, e.g. exploitAttempt = '<@&123456789012345678>'
    Mentions = {
        exploitAttempt = '',
    },

    -- What player info to include in embeds
    Include = {
        CharacterName = true,
        CitizenId     = true,
        Job           = true,
        Discord       = true, -- clickable <@id> mention when the player has Discord linked
        License       = true,
        Steam         = false,
        Coords        = true,
        Health        = true,
    },

    -- Embed side colours (decimal)
    Colors = {
        poisoned        = 15548997, -- red
        resumed         = 15105570, -- orange
        antidoteUsed    = 3066993,  -- green
        antidoteWasted  = 16776960, -- yellow
        antidoteDenied  = 9807270,  -- grey
        death           = 2303786,  -- dark grey
        cured           = 3066993,  -- green
        exploitAttempt  = 10038562, -- dark red
        system          = 3447003,  -- blue
    },

    -- Queue tuning. Discord allows ~5 requests / 2s per webhook.
    SendIntervalMs = 400,
    MaxQueue       = 100, -- per URL; newest logs are dropped past this
    MaxRetries     = 3,   -- retries on 429 / 5xx

    -- Who can run /poisonwebhooktest (ox_lib restricted value, e.g. 'group.admin')
    TestCommandAce = 'group.admin',
}
