Config = {}

---------------------------------
-- database
---------------------------------
Config.AutoDatabase = true   -- create tables on start; set false and import install.sql to install manually

---------------------------------
-- general
---------------------------------
Config.Debug          = false
Config.ServerName     = 'My RSG Server'   -- shown at the top of the queue card
Config.CardImage      = ''                -- optional banner image url (https) for the queue card, '' = none
Config.UpdateInterval = 1000              -- ms between queue card refreshes (keep at 1000 so the card clock ticks every second)
Config.MinCardTime    = 15                 -- seconds the queue card always shows, even with a free slot (0 = join instantly)
Config.ConnectTimeout = 180               -- seconds an admitted player may take to load in before their slot is freed
Config.VipRefresh     = 300               -- seconds between VIP cache reloads from the database (expiry)
Config.EstimateWindow = 20                -- recent admits used to estimate the wait time on the card

---------------------------------
-- slots
---------------------------------
-- slots kept free for VIP/staff only. Public players can fill (sv_maxclients - ReservedSlots)
Config.ReservedSlots = 4

---------------------------------
-- permissions
---------------------------------
Config.AdminPermission = 'admin'           -- rsg-core permission for /queue, /vipadd, /vipremove
Config.StaffAce        = 'rsgqueue.staff'  -- ace that gives staff top priority + reserved slot access
Config.StaffPriority   = 100

---------------------------------
-- crash grace period
---------------------------------
-- players who drop keep a priority boost for a few minutes so they can rejoin quickly
Config.Grace = {
    enabled  = true,
    minutes  = 5,
    priority = 50,   -- added on top of any VIP priority
}

---------------------------------
-- VIP tiers (key is stored in the database)
---------------------------------
-- priority: higher goes first | reserved: may use reserved slots
Config.Tiers = {
    bronze = { label = 'Bronze', priority = 10, reserved = true },
    silver = { label = 'Silver', priority = 20, reserved = true },
    gold   = { label = 'Gold',   priority = 30, reserved = true },
}

---------------------------------
-- buttons shown on the queue card
---------------------------------
Config.Links = {
    { title = 'Discord',      url = 'https://discord.gg/yourinvite' },
    { title = 'Become a VIP', url = 'https://yourstore.tebex.io' },
}

---------------------------------
-- maintenance mode (toggle with /queuemaint or the admin panel, survives restarts)
---------------------------------
Config.Maintenance = {
    allowVip = true,   -- true = staff + VIPs may join during maintenance, false = staff only
}

---------------------------------
-- discord role priority
---------------------------------
-- the bot token is NOT stored here (config is sent to clients). put it in server.cfg:
--   set rsgqueue_discord_token "your-bot-token"
-- the bot must be in your guild with the Server Members intent enabled
Config.Discord = {
    enabled  = false,
    guildId  = '',
    cacheMinutes = 5,   -- how long a player's roles are cached
    timeout  = 3000,    -- ms to wait for discord before carrying on without it
    roles = {
        -- ['discord role id'] = 'tier key' (or 'staff')
        -- ['123456789012345678'] = 'gold',
    },
}

---------------------------------
-- logging (rsg-log). add the channel below to rsg-log's webhook config
---------------------------------
Config.Log = {
    enabled = true,
    channel = 'queue',
}

---------------------------------
-- VIP rewards: cash paid once per cooldown when a VIP loads a character (per Rockstar license)
---------------------------------
Config.VipRewards = {
    enabled = false,
    cooldownHours = 24,
    tiers = {
        bronze = { cash = 1 },
        silver = { cash = 2 },
        gold   = { cash = 5 },
    },
}
