-- SERVER ONLY. This file is never sent to clients, so webhook URLs stay private.
-- Do NOT move these settings into shared/config.lua.

WebhookConfig = {}

WebhookConfig.Enabled    = true
WebhookConfig.DefaultUrl = ''                       -- used by any event without its own url
WebhookConfig.BotName    = 'Mine Foreman'
WebhookConfig.Avatar     = ''                       -- optional image url for the bot
WebhookConfig.Footer     = 'rsg-mining'

WebhookConfig.ShowIdentifiers = true                -- add license + discord mention to player embeds
WebhookConfig.SendInterval    = 2100                -- ms between posts per webhook (Discord allows ~30/min)
WebhookConfig.MaxQueue        = 200                 -- per webhook; oldest entries dropped beyond this

-- colours are decimal (0x hex works too)
WebhookConfig.Colors = {
    green  = 0x5A7D4F,
    red    = 0xE0554F,
    amber  = 0xD9A441,
    grey   = 0x5A5A5A,
    white  = 0xF2F2F2,
}

--[[
  Per event:
    enabled     = log this event at all
    url         = optional webhook for just this event (falls back to DefaultUrl)
    color       = key from Colors
    alertAbove  = optional; when the event's value (money / item count) is >= this, the
                  post pings alertMention (e.g. '<@&ROLE_ID>' or '@here') for staff review
]]
WebhookConfig.Events = {
    lease_bought    = { enabled = true, url = '', color = 'green' },
    lease_renewed   = { enabled = true, url = '', color = 'green' },
    lease_expired   = { enabled = true, url = '', color = 'grey'  },
    worker_hired    = { enabled = true, url = '', color = 'white' },
    worker_fired    = { enabled = true, url = '', color = 'grey'  },
    supplies_added  = { enabled = true, url = '', color = 'white' },
    ore_collected   = { enabled = true, url = '', color = 'green', alertAbove = 200 },
    wages_added     = { enabled = true, url = '', color = 'green', alertAbove = 2000 },
    wages_withdrawn = { enabled = true, url = '', color = 'amber', alertAbove = 2000 },
    workers_strike  = { enabled = true, url = '', color = 'red'   },
}

WebhookConfig.AlertMention = ''                     -- e.g. '<@&123456789012345678>'
