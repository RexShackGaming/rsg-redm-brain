-- SERVER-ONLY config: never move this into shared/ (clients would download your webhook URLs).
-- You can also set URLs in server.cfg instead of here (convar wins over this file):
--   set rsg_weather_webhook        "https://discord.com/api/webhooks/..."   (default for every category)
--   set rsg_weather_webhook_admin  "https://discord.com/api/webhooks/..."   (per category: admin, security, patterns, season, weather, forecast, system)

WebhookConfig = {
    Enabled    = true,
    BotName    = 'Weather Office',
    AvatarUrl  = '',                       -- optional image url for the bot avatar
    ServerName = nil,                      -- shown in embed footers (nil = sv_projectName / sv_hostname)
    DefaultWebhook = '',                   -- used by any category without its own url

    ShowDiscordMention = true,             -- show <@discordid> for the actor
    ShowLicense        = false,            -- show rockstar license identifier (keep off for privacy)

    -- per category: enabled, own webhook (optional), embed colour (decimal), ping (optional role/user mention text)
    Categories = {
        admin    = { enabled = true,  webhook = '', color = 3447003,  ping = '' },          -- weather/time/wind/timescale/sync/reset changes
        security = { enabled = true,  webhook = '', color = 15158332, ping = '' },          -- unauthorised attempts, spam
        patterns = { enabled = true,  webhook = '', color = 10181046, ping = '' },          -- pattern saved/deleted/applied
        season   = { enabled = true,  webhook = '', color = 15105570, ping = '' },          -- seasonal event start/end/mode
        weather  = { enabled = false, webhook = '', color = 9807270,  ping = '' },          -- every natural weather change (noisy)
        forecast = { enabled = true,  webhook = '', color = 3066993,  ping = '' },          -- scheduled forecast bulletin
        system   = { enabled = true,  webhook = '', color = 9807270,  ping = '' },          -- resource start/stop
    },

    -- scheduled forecast bulletin (posted to the 'forecast' category)
    Forecast = {
        IntervalMinutes = 180,             -- 0 = only via /weatherwebhook forecast
        Hours           = 12,              -- how many forecast entries to include
        PostOnStart     = false,
    },
}
