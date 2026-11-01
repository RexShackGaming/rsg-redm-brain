-- SERVER ONLY. Webhook URLs live here so they are never downloaded by clients.
-- Do NOT move this into shared/ or list it under shared_scripts.

WebhookConfig = {}

WebhookConfig.Enabled = true

-- Channels. Any event can point at any channel; an empty URL disables that channel.
WebhookConfig.Channels = {
    doors    = '', -- open / close / auto-close
    passcode = '', -- set / changed / admin reset
    security = '', -- wrong codes, lockouts, exploit attempts
}

-- bot name, embed titles, field names and descriptions come from locales (log_* keys)
WebhookConfig.AvatarUrl = '' -- optional image url for the webhook avatar
WebhookConfig.ServerName = 'RSG Server' -- shown in the embed footer

-- what to include about the player
WebhookConfig.ShowIdentifiers = true  -- license / steam / discord
WebhookConfig.MentionDiscord  = true  -- <@id> ping-free mention in the player field
WebhookConfig.ShowCoords      = false -- player coords at time of the action
WebhookConfig.LogPasscodes    = false -- include actual codes (as spoilers). Leave off unless you really need it.

-- sending / rate limiting (Discord allows ~5 requests per 2s per webhook)
WebhookConfig.SendInterval    = 2000 -- ms between batches per channel
WebhookConfig.MaxEmbedsPerMsg = 10   -- Discord max is 10
WebhookConfig.MaxRetries      = 3
WebhookConfig.SuspiciousThrottle = 10000 -- ms: same player + same reason only logged once per window

-- colours are decimal (0xRRGGBB)
WebhookConfig.Events = {
    door_open      = { enabled = true, channel = 'doors',    color = 0x6fbf73 },
    door_close     = { enabled = true, channel = 'doors',    color = 0x9a9a9a },
    door_autoclose = { enabled = false, channel = 'doors',   color = 0x5a5a5a },
    code_set       = { enabled = true, channel = 'passcode', color = 0x5a7d4f },
    code_changed   = { enabled = true, channel = 'passcode', color = 0xd9a441 },
    code_reset     = { enabled = true, channel = 'passcode', color = 0xe0554f },
    code_wrong     = { enabled = true, channel = 'security', color = 0xd9a441 },
    code_lockout   = { enabled = true, channel = 'security', color = 0xe0554f },
    suspicious     = { enabled = true, channel = 'security', color = 0xb00020 },
}

-- DATABASE
-- When true the resource builds and upgrades its own tables on start (recommended).
-- Set to false only if you manage the schema yourself with rsg_trapdoors.sql.
DatabaseConfig = {
    AutoInstall = true,
}
