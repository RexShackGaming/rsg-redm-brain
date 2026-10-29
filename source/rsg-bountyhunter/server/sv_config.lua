-- SERVER ONLY. Never add this file to shared_scripts: webhook URLs are secrets.
SvConfig = {}

SvConfig.Webhooks = {
    Enabled   = true,
    BotName   = 'Bounty Office',
    AvatarUrl = '',                -- optional image url for the bot avatar
    FooterText = 'rsg-bountyhunter',
    ServerName = 'My RedM Server', -- shown in the embed author line

    -- one url per channel; leave a category '' to disable it, or point several at the same url
    Urls = {
        contracts = '',  -- accepted / abandoned / expired / failed
        payouts   = '',  -- bounties turned in + money paid
        exploits  = '',  -- suspicious or blocked actions
        system    = '',  -- resource start, database, board refresh, test command
    },

    -- per-event switches (category in brackets)
    Events = {
        accepted     = true,   -- [contracts]
        abandoned    = true,   -- [contracts]
        expired      = true,   -- [contracts]
        failed       = true,   -- [contracts] target lost
        completed    = true,   -- [payouts]
        exploit      = true,   -- [exploits]
        started      = true,   -- [system]
        boardRefresh = false,  -- [system] noisy, off by default
    },

    -- embed colours (decimal)
    Colors = {
        accepted  = 3447003,   -- blue
        abandoned = 10070709,  -- grey
        expired   = 15105570,  -- orange
        failed    = 15158332,  -- red
        completed = 3066993,   -- green
        exploit   = 10038562,  -- dark red
        system    = 9807270,   -- light grey
    },

    PingOnExploit  = '',       -- e.g. '<@&123456789012345678>' to ping a staff role on exploit logs
    ShowCoords     = true,     -- include player coords in embeds
    ShowIdentifiers = true,    -- include license / discord id in embeds

    TestCommand    = 'bountywebhooktest', -- admin command that sends a test embed to every configured url, false to disable

    UseRsgLog      = false,    -- also send to rsg-log (TriggerEvent('rsg-log:server:CreateLog', ...))
    RsgLogChannel  = 'bountyhunter',
}
