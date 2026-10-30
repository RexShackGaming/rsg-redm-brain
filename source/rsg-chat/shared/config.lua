Config = {}

---------------------------------------------------------------------
-- General
---------------------------------------------------------------------
Config.AdminPermission   = 'admin'  -- rsg-core permission for /chatadmin (channel manager)
Config.PSAPermission     = 'admin'  -- rsg-core permission needed to send a SERVER PSA
Config.MessageCooldown   = 1000     -- ms between chat messages per player (all channels)
Config.HardMaxLength     = 512      -- absolute cap; a channel's own limit can't go above this
Config.DefaultChannel    = 'ooc'    -- channel players start on (falls back to the first one they can use)
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
