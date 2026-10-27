-- Server-only config: never put webhooks in shared/config.lua (clients can read it)
SvConfig = {}

SvConfig.Webhooks = {
    Enabled  = true,
    Name     = 'rsg-ambush',           -- bot display name
    Avatar   = '',                     -- optional avatar URL
    Footer   = 'rsg-ambush logs',

    -- leave a URL empty to disable that channel; empty channels fall back to Default
    Default  = '',
    Ambush   = '',   -- ambush started / ended
    Loot     = '',   -- bodies searched
    Security = '',   -- rejected / suspicious requests
}

-- which events are logged
SvConfig.Log = {
    AmbushStart = true,
    AmbushEnd   = true,
    Loot        = true,
    Security    = true,
}

SvConfig.Colours = {
    start    = 15105570, -- orange
    finish   = 3447003,  -- blue
    loot     = 3066993,  -- green
    security = 15158332, -- red
}

-- seconds between identical security alerts from the same player (stops log spam)
SvConfig.SecurityThrottle = 30
