-- SERVER ONLY: never put webhook URLs in a shared/client file, clients can read those.
WebhookConfig = {
    Enabled   = true,
    BotName   = 'RSG Looting',
    AvatarUrl = '',            -- optional image url
    Footer    = 'rsg-looting',
    ShowIdentifiers = true,    -- license / discord / citizenid in embeds

    -- leave a url empty ('') to disable that channel
    Webhooks = {
        loot    = '',          -- NPC loot (common + rare)
        rob     = '',          -- player robberies
        exploit = '',          -- failed server validations / suspected cheating
    },

    LogCommonLoot = true,      -- set false to only log rare loot

    Colors = {
        common  = 0x9A9A9A,
        rare    = 0xD9A441,
        rob     = 0xE0554F,
        exploit = 0x8B0000,
    },
}
