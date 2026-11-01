---------------------------------------------------------------------
-- SERVER ONLY config (never sent to clients, so webhook URLs stay secret)
---------------------------------------------------------------------
SvConfig = {}

SvConfig.Webhooks = {
    enabled  = true,
    username = 'Boat Yard',
    avatar   = '',            -- optional image URL for the webhook avatar
    footer   = 'rsg-boats',
    showIdentifiers = true,   -- add license / discord / server id to player fields
    mentionOnExploit = '',    -- e.g. '<@&ROLE_ID>' to ping staff on exploit alerts

    -- default channel used when an event has no url of its own ('' = off)
    default = '',

    -- one entry per event: enabled, channel url ('' = use default), embed colour (decimal)
    events = {
        buy        = { enabled = true, url = '', color = 5763719 },  -- green
        sell       = { enabled = true, url = '', color = 15105570 }, -- orange
        launch     = { enabled = true, url = '', color = 3447003 },  -- blue
        store      = { enabled = true, url = '', color = 10181046 }, -- purple
        transfer   = { enabled = true, url = '', color = 15844367 }, -- gold
        storage    = { enabled = false, url = '', color = 9807270 }, -- grey (noisy, off by default)
        admin      = { enabled = true, url = '', color = 1752220 },  -- teal (yards, docks, models)
        exploit    = { enabled = true, url = '', color = 15548997 }, -- red (rejected / suspicious requests)
    },
}
