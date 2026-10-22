-- SERVER ONLY - never add this file to shared_scripts, it holds your webhook URLs.
SvConfig = {}

SvConfig.Webhooks = {
    Enabled    = true,
    BotName    = 'Door Locks',
    AvatarUrl  = '',          -- optional image url for the bot avatar
    ServerName = 'RSG RedM',  -- shown in the embed footer

    -- each log type falls back to Default when its own url is empty
    Urls = {
        Default    = '',
        DoorUse    = '',      -- doors locked / unlocked by players
        Denied     = '',      -- no key / too far
        Admin      = '',      -- editor create / edit / delete / teleport
        Security   = '',      -- suspicious requests (likely cheaters)
        System     = '',      -- resource start, config import
    },

    -- turn individual log types on / off
    Log = {
        DoorUse  = true,
        Denied   = true,
        Admin    = true,
        Security = true,
        System   = true,
    },

    -- ping a role on Security logs, e.g. '<@&123456789012345678>' (empty = no ping)
    SecurityMention = '',

    -- don't spam Denied logs: one per player per door within this many seconds
    DeniedThrottle = 60,

    -- show identifiers in embeds
    ShowLicense = true,
    ShowDiscord = true,
    ShowSteam   = false,
    ShowIp      = false,

    Colors = {
        locked   = 15158332, -- red
        unlocked = 3066993,  -- green
        denied   = 15105570, -- orange
        admin    = 3447003,  -- blue
        delete   = 10038562, -- dark red
        security = 16711680, -- bright red
        system   = 9807270,  -- grey
    },
}
