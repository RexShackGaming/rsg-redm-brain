---------------------------------
-- SERVER-ONLY CONFIG
-- this file is never sent to clients, so webhook URLs stay private.
-- do NOT move these into shared/config.lua
---------------------------------
SvConfig = {}

SvConfig.Webhooks = {
    enabled    = true,
    username   = 'Fishmonger Logs',
    avatar     = '',                -- optional image url for the bot avatar
    footer     = 'rsg-fishmonger',
    serverName = 'My RedM Server',  -- shown in the embed author line
    mentionOnAlert = '',            -- e.g. '<@&ROLE_ID>' to ping staff on suspicious activity

    -- leave a url empty ('') to disable that log type
    urls = {
        sales      = '', -- fish sold for money
        processing = '', -- fish processed into fillets
        suspicious = '', -- possible exploit attempts / tampered requests
        errors     = '', -- script errors & failed transactions
        system     = '', -- resource start / stop
    },

    colors = {
        sales      = 5763719,  -- green
        processing = 3447003,  -- blue
        suspicious = 15548997, -- red
        errors     = 15105570, -- orange
        system     = 9807270,  -- grey
    },

    -- sales at or above this cash value also go to the suspicious channel as a "large sale" alert (0 = off)
    largeSaleAlert = 250.0,
    -- processing at or above this many fish also triggers an alert (0 = off)
    largeProcessAlert = 250,

    -- identifiers to include on every log
    showIdentifiers = { license = true, discord = true, steam = false, ip = false },

    -- queue: discord allows ~5 requests / 2s per webhook
    sendInterval = 500, -- ms between queued requests
    maxQueue     = 200, -- drop oldest logs beyond this to protect the server
}
