Config = {}
-- build the database tables automatically on start (set false and import the SQL file for a manual install)
Config.AutoDatabase = true

---------------------------------------------------------------------
-- General
---------------------------------------------------------------------
Config.AdminPermission   = 'admin'  -- rsg-core permission for /chatadmin (channel manager)
Config.PSAPermission     = 'admin'  -- rsg-core permission needed to send a SERVER PSA
Config.MessageCooldown   = 1000     -- ms between chat messages per player (all channels)
Config.HardMaxLength     = 512      -- absolute cap; a channel's own limit can't go above this
Config.DefaultChannel    = 'ooc'    -- channel players start on (falls back to the first one they can use)
Config.ConsoleLog        = true     -- print every channel message to the server console
Config.UseKeyMapping     = true     -- open chat with a rebindable key (game key settings); false = old per-frame control check
Config.OpenKey           = 'T'      -- default key name for opening chat (players can rebind it)
Config.ModPermission     = 'mod'    -- rsg-core permission for /chatmute and /chatunmute (also exempt from the word filter)
Config.Mentions          = true     -- "@First_Last" or "@First" in a message highlights it for that player (click a name to mention)
Config.NobodyHeardHint   = true     -- tell players when nobody is close enough to hear a local/regional message

-- Private messages: /pm <id or First_Last> <message>, /r <message>
Config.PM = {
    Enabled      = true,
    Command      = 'pm',
    ReplyCommand = 'r',
    AllowById    = true,        -- false = players can only be messaged by character name
    Color        = '#c39bd3',
}

-- /do <text> and /roll [sides]: range-limited lines in chat (/me comes from rsg-core)
Config.Roleplay = {
    Enabled          = true,
    DoCommand        = 'do',
    RollCommand      = 'roll',
    Distance         = 20,      -- metres
    MaxLength        = 200,
    DoColor          = '#d9a441',
    RollColor        = '#7fb3d5',
    RollDefaultSides = 100,
    RollMaxSides     = 1000,
}

-- Staff moderation: /chatmute <id> <minutes, 0 = permanent> [reason], /chatunmute <id>
Config.Moderation = {
    MaxMuteMinutes = 10080,     -- one week; 0 (permanent) is always allowed
}

-- Word filter. words are matched as whole words, case-insensitive, with simple leetspeak (5 = s, 0 = o ...)
Config.WordFilter = {
    enabled     = true,
    mode        = 'mask',       -- 'mask' = replace with ****, 'block' = reject the whole message
    exemptStaff = true,         -- players with Config.ModPermission are not filtered
    words       = {             -- add your own, lowercase
        -- 'example',
    },
}

-- Chat logs (searchable in /chatlog). Stored in rsg_chat_logs.
Config.Logging = {
    Enabled       = true,
    RetentionDays = 30,         -- older entries are deleted automatically (0 = keep forever)
    LogPrivate    = true,       -- also log /pm messages (staff can read them in /chatlog)
    SearchLimit   = 100,        -- rows returned per search
    RsgLogChannel = false,      -- set a channel name (e.g. 'chat') to also forward public messages to rsg-log / Discord
}
Config.MaxHistoryCap     = 250      -- highest "message history" value players can pick

-- Distance limits the admin panel will accept (metres)
Config.DistanceLimits = { min = 2, max = 5000 }

-- Permission levels offered in the admin panel dropdown ('' = everyone)
Config.PermissionLevels = { '', 'helper', 'mod', 'admin', 'headadmin', 'developer', 'god' }

---------------------------------------------------------------------
-- Default player layout (players change these in the chat settings
-- panel; "Reset layout" puts them back to these values)
---------------------------------------------------------------------
Config.DefaultSettings = {
    x = 1.5,          -- left edge, % of screen width
    y = 2.5,          -- top edge, % of screen height
    w = 30,           -- width, % of screen width
    h = 32,           -- height, % of screen height
    fontSize = 15,    -- px
    opacity = 55,     -- background opacity, 0-100
    timestamps = false,
    history = 100,    -- messages kept / scrollable
    autoHide = 'fade',-- 'fade' | 'hide' | 'never'
    hideDelay = 10,   -- seconds of inactivity before fading/hiding
    chatOff = false,  -- player turned the chat box off completely (/togglechat)
    aimHide = true,   -- fade the chat while aiming or in a cinematic camera
}

---------------------------------------------------------------------
-- Seed channels: only used the FIRST time the resource starts (when
-- the rsg_chat_channels table is empty). After that, manage channels
-- in-game with /chatadmin.
--
-- range: 'global'   - everyone
--        'local'    - players within `distance` metres
--        'regional' - same as local but meant for a wider radius
--        'group'    - only players in `jobs` / `gangs` (and/or with `permission`)
---------------------------------------------------------------------
Config.Channels = {
    {
        id = 'ooc', label = 'OOC', command = 'ooc', prefix = 'OOC', showPrefix = true,
        color = '#bfbfbf', range = 'global', distance = 0, maxLength = 256,
        jobs = {}, gangs = {}, requireDuty = false, permission = '', enabled = true,
    },
    {
        id = 'local', label = 'Local', command = 'l', prefix = 'Local', showPrefix = false,
        color = '#ffffff', range = 'local', distance = 20, maxLength = 256,
        jobs = {}, gangs = {}, requireDuty = false, permission = '', enabled = true,
    },
    {
        id = 'trade', label = 'Trade', command = 'trade', prefix = 'Trade', showPrefix = true,
        color = '#d9a441', range = 'regional', distance = 750, maxLength = 200,
        jobs = {}, gangs = {}, requireDuty = false, permission = '', enabled = true,
    },
    {
        id = 'staff', label = 'Staff', command = 'staff', prefix = 'Staff', showPrefix = true,
        color = '#e0554f', range = 'group', distance = 0, maxLength = 512,
        jobs = {}, gangs = {}, requireDuty = false, permission = 'helper', enabled = true,
    },
}
