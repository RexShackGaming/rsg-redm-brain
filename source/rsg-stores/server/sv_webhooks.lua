-- ============================================
-- DISCORD WEBHOOK LOGGER
-- Usage (server): Webhook.Send(channel, title, description, src, fields, opts)
--   channel : 'purchases' | 'sales' | 'admin' | 'security' | 'system'
--   src     : player server id (adds player block) or nil
--   fields  : { { name = 'Item', value = 'Bread', inline = true }, ... }
--   opts    : { ping = true, color = 0xFFFFFF }
-- Other resources: exports['rsg-stores']:SendWebhook(channel, title, description, src, fields)
-- ============================================
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()
local cfg = WebhookConfig or { Enabled = false, Urls = {} }

Webhook = {}

local queues = {}        -- url -> { payload entries }
local blockedUntil = {}  -- url -> GetGameTimer() ms (429 back-off)
local queued = 0

local function trim(s, max)
    s = tostring(s == nil and '-' or s)
    if s == '' then s = '-' end
    if #s > max then s = s:sub(1, max - 3) .. '...' end
    return s
end

local function money(n) return ('$%.2f'):format(tonumber(n) or 0) end
Webhook.Money = money

local function playerBlock(src)
    local lines = {}
    local P = RSGCore.Functions.GetPlayer(src)
    if P then
        local ci = P.PlayerData.charinfo or {}
        lines[#lines + 1] = ('**%s:** %s %s'):format(locale('wh_f_character'), ci.firstname or '?', ci.lastname or '')
        lines[#lines + 1] = ('**%s:** `%s`'):format(locale('wh_f_citizenid'), P.PlayerData.citizenid or '?')
    end
    lines[#lines + 1] = ('**%s:** %s (ID %s)'):format(locale('wh_f_name'), GetPlayerName(src) or '?', src)

    local show = cfg.ShowIdentifiers or {}
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        local kind, val = id:match('^(%w+):(.+)$')
        if kind and show[kind] then
            if kind == 'discord' then
                lines[#lines + 1] = ('**%s:** <@%s>'):format(locale('wh_f_discord'), val)
            else
                lines[#lines + 1] = ('**%s:** `%s`'):format((kind:gsub('^%l', string.upper)), val)
            end
        end
    end
    return table.concat(lines, '\n')
end

local function enqueue(url, embed, content)
    if queued >= (cfg.MaxQueue or 500) then return end
    queues[url] = queues[url] or {}
    table.insert(queues[url], { embed = embed, content = content })
    queued = queued + 1
end

function Webhook.Send(channel, title, description, src, fields, opts)
    if not cfg.Enabled then return end
    local url = cfg.Urls and cfg.Urls[channel]
    if not url or url == '' then return end
    opts = opts or {}

    local embed = {
        title       = trim(title, 256),
        description = description and trim(description, 4000) or nil,
        color       = opts.color or (cfg.Colors and cfg.Colors[channel]) or 0x9A9A9A,
        timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer      = { text = ('%s • %s'):format(GetCurrentResourceName(), channel) },
        fields      = {},
    }
    if src and src > 0 then
        embed.fields[#embed.fields + 1] = { name = locale('wh_f_player'), value = trim(playerBlock(src), 1024), inline = false }
    end
    for i, f in ipairs(fields or {}) do
        if #embed.fields >= 25 then break end
        embed.fields[#embed.fields + 1] = { name = trim(f.name, 256), value = trim(f.value, 1024), inline = f.inline ~= false }
    end

    local content = (opts.ping and cfg.SecurityPing ~= '' and cfg.SecurityPing) or nil
    enqueue(url, embed, content)
end

-- ============================================
-- QUEUE FLUSH (batches up to 10 embeds per POST, honours 429 retry_after)
-- ============================================
local function post(url, batch)
    local embeds, content = {}, nil
    for _, e in ipairs(batch) do
        embeds[#embeds + 1] = e.embed
        if e.content and not content then content = e.content end
    end
    local body = json.encode({
        username   = cfg.BotName,
        avatar_url = (cfg.AvatarUrl ~= '' and cfg.AvatarUrl) or nil,
        content    = content,
        embeds     = embeds,
        allowed_mentions = { parse = { 'roles', 'users' } },
    })
    PerformHttpRequest(url, function(status, body, _, err)
        if status == 429 then
            local retry = 5.0
            local ok, data = pcall(json.decode, body or err or "")
            if ok and type(data) == 'table' and data.retry_after then retry = tonumber(data.retry_after) or retry end
            blockedUntil[url] = GetGameTimer() + math.ceil(retry * 1000)
            -- put the batch back at the front
            queues[url] = queues[url] or {}
            for i = #batch, 1, -1 do table.insert(queues[url], 1, batch[i]) end
            queued = queued + #batch
        elseif status < 200 or status >= 300 then
            print(('[rsg-stores] webhook failed (%s): %s'):format(status, tostring(err)))
        end
    end, 'POST', body, { ['Content-Type'] = 'application/json' })
end

CreateThread(function()
    while true do
        Wait(cfg.FlushInterval or 2000)
        local now = GetGameTimer()
        for url, q in pairs(queues) do
            if #q > 0 and (blockedUntil[url] or 0) <= now then
                local batch = {}
                for _ = 1, math.min(cfg.EmbedsPerPost or 10, #q) do
                    batch[#batch + 1] = table.remove(q, 1)
                end
                queued = queued - #batch
                post(url, batch)
            end
        end
    end
end)

-- ============================================
-- CONVENIENCE LOGGERS
-- ============================================
local secThrottle = {} -- one alert per player+reason per 10s (stops spam from looping cheaters)
function Webhook.Security(src, reason, fields)
    local key, now = tostring(src) .. reason, GetGameTimer()
    if secThrottle[key] and now - secThrottle[key] < 10000 then return end
    secThrottle[key] = now
    Webhook.Send('security', locale('wh_t_security'), reason, src, fields, { ping = true })
end

function Webhook.IsLarge(amount)
    return (tonumber(amount) or 0) >= (cfg.LargeTransaction or math.huge)
end

exports('SendWebhook', function(channel, title, description, src, fields)
    Webhook.Send(channel, title, description, src, fields)
end)

-- Test from server console: storeswebhooktest
RegisterCommand('storeswebhooktest', function(src)
    if src ~= 0 then return end
    for channel in pairs(cfg.Urls or {}) do
        Webhook.Send(channel, locale('wh_t_test'), locale('wh_d_test'):format(channel))
    end
    print('[rsg-stores] test webhooks queued')
end, true)
