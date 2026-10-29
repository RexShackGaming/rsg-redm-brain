-- Server-only config: never add this file to shared_scripts (webhook URLs must not reach clients)
SvConfig = {}

SvConfig.Webhooks = {
    Enabled    = true,
    BotName    = 'Legendary Hunts',
    AvatarUrl  = '',                 -- optional image URL for the bot
    Footer     = 'rsg-legendary',
    ShowCoords = true,               -- add the player's coords to each log
    QueueDelay = 600,                -- ms between sends (Discord allows ~5 per 2s per webhook)

    -- one URL per channel. Leave a URL empty to fall back to Default; leave Default empty to disable that log.
    Urls = {
        Default    = '',
        Shop       = '',             -- maps bought, pelts sold
        Hunt       = '',             -- hunt started, clues, legendary appeared, abandoned, expired
        Kill       = '',             -- legendary skinned + rewards
        Admin      = '',             -- /legendpreview
        Suspicious = '',             -- failed server checks that suggest cheating
    },

    -- turn individual log types on/off
    Events = {
        map_bought   = true,
        sold         = true,
        hunt_started = true,
        clue_found   = false,        -- chatty: one log per clue
        animal_spawn = true,
        skinned      = true,
        abandoned    = true,
        expired      = true,
        admin        = true,
        suspicious   = true,
    },

    -- ping this Discord role ID on suspicious logs ('' = no ping)
    SuspiciousRoleId = '',

    Colors = {
        success = 5763719, info = 3447003, warning = 16776960, danger = 15548997, admin = 10181046,
    },
}
