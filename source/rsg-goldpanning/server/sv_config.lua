-- server-only config: kept out of shared/ so webhook URLs are never sent to clients

---------------------------------
-- discord webhook logging
---------------------------------
Config.Webhooks = {
    enabled   = true, -- master toggle
    botName   = nil, -- nil uses the 'wh_bot_name' locale
    botAvatar = 'https://i.imgur.com/1jJKGZs.png', -- optional, leave '' for default
    rewards   = '', -- posts every successful gold find, '' to disable
    exploits  = '', -- posts suspicious / blocked reward claims, '' to disable
}

-- embed side-bar colours (decimal, not hex)
Config.WebhookColors = {
    small   = 3066993,  -- green
    medium  = 15844367, -- gold
    large   = 15105570, -- orange
    exploit = 15158332, -- red
}
