-- server-only settings (never sent to clients)
SvConfig = {}

---------------------------------
-- discord webhook settings
---------------------------------
SvConfig.Webhook = {
    url = '', -- Discord webhook URL (leave empty to disable)
    title = 'RSG Deliveries',
    color = 8531968, -- embed color (decimal)
    footer = 'rsg-deliveries',
}
