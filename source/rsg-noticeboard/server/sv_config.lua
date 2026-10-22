-- SERVER ONLY: never add this file to shared_scripts, the webhook URLs would be sent to every client
SvConfig = {}

SvConfig.Webhooks = {
    Enabled  = true,
    BotName  = 'Notice Board',
    Avatar   = '',                 -- optional image url for the bot avatar
    Footer   = 'rsg-noticeboard',
    Default  = '',                 -- fallback url used by any event whose url is empty

    IncludeIdentifiers = true,     -- add license / discord / server id to player embeds
    ShowNoticeImage    = true,     -- show the poster image in notice embeds
    BodyPreviewLength  = 300,      -- characters of the notice text shown in the embed

    -- mention added to exploit alerts, e.g. '<@&ROLE_ID>' or '@here' (empty = none)
    ExploitMention = '',
    ExploitCooldown = 60,          -- seconds between exploit alerts for the same player

    -- embed titles come from locales (wh_ev_<event>)
    -- each event can have its own channel; leave url empty to use Default, set enabled = false to mute
    Events = {
        noticePosted   = { enabled = true, url = '', color = 5763719 },
        noticeRenewed  = { enabled = true, url = '', color = 3447003 },
        noticeRemoved  = { enabled = true, url = '', color = 15105570 },
        noticeExpired  = { enabled = true, url = '', color = 9807270 },
        adminDelete    = { enabled = true, url = '', color = 15548997 },
        adminExtend    = { enabled = true, url = '', color = 10181046 },
        boardPlaced    = { enabled = true, url = '', color = 5763719 },
        boardRenamed   = { enabled = true, url = '', color = 3447003 },
        boardDeleted   = { enabled = true, url = '', color = 15548997 },
        exploit        = { enabled = true, url = '', color = 10038562 },
    },
}
