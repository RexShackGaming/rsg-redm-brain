-----------------------------------------------------------------------------------------------
-- Discord webhook logger
-- Usage (server side):  Webhook.Log('event_key', src | nil, 'Title', { { 'Field', value }, ... }, opts?)
--   opts = { description?, ping? = role id, inline? = bool (default true) }
-- Batches embeds per channel, respects Discord rate limits (429 retry_after) and never blocks.
-----------------------------------------------------------------------------------------------
Webhook = {}

local RSGCore = exports['rsg-core']:GetCoreObject()
local cfg = SvConfig.Webhooks
local Queues = {} -- [url] = { items = { { embed, ping } }, busyUntil = ms }

local function Truncate(str, max)
    str = tostring(str == nil and locale('wh_na') or str)
    if #str > max then return str:sub(1, max - 3) .. '...' end
    return str
end

local function GetUrl(channel)
    local url = cfg.Channels[channel]
    if not url or url == '' then url = cfg.Channels.default end
    if url and url ~= '' then return url end
end

local function GetIdentifier(src, prefix)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, #prefix + 1) == prefix .. ':' then return id:sub(#prefix + 2) end
    end
end

--- builds the standard "who" fields for a player
local function PlayerFields(src)
    local fields = {}
    local Player = RSGCore.Functions.GetPlayer(src)
    local show = cfg.ShowIdentifiers

    local charName = locale('wh_unknown')
    if Player then
        local ci = Player.PlayerData.charinfo
        charName = ('%s %s'):format(ci.firstname, ci.lastname)
    end
    fields[#fields + 1] = { name = locale('wh_player'), value = locale('wh_player_value', charName, GetPlayerName(src) or '?', src), inline = true }

    if show.citizenid and Player then
        fields[#fields + 1] = { name = locale('wh_citizenid'), value = '`' .. Player.PlayerData.citizenid .. '`', inline = true }
    end
    if show.discord then
        local d = GetIdentifier(src, 'discord')
        fields[#fields + 1] = { name = locale('wh_discord'), value = d and ('<@%s>'):format(d) or locale('wh_na'), inline = true }
    end
    if show.license then
        fields[#fields + 1] = { name = locale('wh_license'), value = '`' .. (GetIdentifier(src, 'license') or locale('wh_na')) .. '`', inline = false }
    end
    if show.steam then
        fields[#fields + 1] = { name = locale('wh_steam'), value = '`' .. (GetIdentifier(src, 'steam') or locale('wh_na')) .. '`', inline = true }
    end
    if show.coords then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local c = GetEntityCoords(ped)
            fields[#fields + 1] = { name = locale('wh_coords'), value = ('`%.2f, %.2f, %.2f`'):format(c.x, c.y, c.z), inline = true }
        end
    end
    return fields
end

local function Flush(url, q)
    if #q.items == 0 or GetGameTimer() < q.busyUntil then return end

    local batch, embeds, pings, seen = {}, {}, {}, {}
    for i = 1, math.min(cfg.MaxEmbedsPerMessage, #q.items) do
        local item = table.remove(q.items, 1)
        batch[i], embeds[i] = item, item.embed
        if item.ping ~= '' and not seen[item.ping] then
            seen[item.ping] = true
            pings[#pings + 1] = ('<@&%s>'):format(item.ping)
        end
    end

    q.busyUntil = GetGameTimer() + cfg.BatchInterval
    PerformHttpRequest(url, function(status, _, _, body)
        if status == 429 then
            -- rate limited: requeue at the front and wait as long as Discord asks
            local retry = 2000
            local ok, data = pcall(json.decode, body or '')
            if ok and type(data) == 'table' and data.retry_after then retry = math.ceil(data.retry_after * 1000) end
            for i = #batch, 1, -1 do table.insert(q.items, 1, batch[i]) end
            q.busyUntil = GetGameTimer() + retry
        elseif status < 200 or status >= 300 then
            print(('[rsg-goldclaim] webhook failed (HTTP %s): %s'):format(status, tostring(body)))
        end
    end, 'POST', json.encode({
        username         = cfg.BotName,
        avatar_url       = cfg.AvatarUrl ~= '' and cfg.AvatarUrl or nil,
        content          = #pings > 0 and table.concat(pings, ' ') or nil,
        embeds           = embeds,
        allowed_mentions = { parse = { 'roles' } },
    }), { ['Content-Type'] = 'application/json' })
end

CreateThread(function()
    while true do
        Wait(500)
        for url, q in pairs(Queues) do Flush(url, q) end
    end
end)

--- main entry point
function Webhook.Log(event, src, title, data, opts)
    if not cfg.Enabled then return end
    local ev = cfg.Events[event]
    if not ev or not ev.enabled then return end
    local url = GetUrl(ev.channel)
    if not url then return end
    opts = opts or {}

    local fields = {}
    if src and src > 0 then
        for _, f in ipairs(PlayerFields(src)) do fields[#fields + 1] = f end
    end
    for _, f in ipairs(data or {}) do
        if #fields >= 25 then break end -- Discord hard limit
        fields[#fields + 1] = {
            name   = Truncate(f[1], 256),
            value  = Truncate(f[2], 1024),
            inline = f[3] ~= nil and f[3] or (opts.inline ~= false),
        }
    end

    local embed = {
        title       = Truncate(title, 256),
        description = opts.description and Truncate(opts.description, 4000) or nil,
        color       = ev.color,
        fields      = fields,
        author      = { name = cfg.ServerName },
        footer      = { text = ('%s • %s'):format(cfg.FooterText, event) },
        timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }

    local q = Queues[url]
    if not q then
        q = { items = {}, busyUntil = 0 }
        Queues[url] = q
    end
    if #q.items >= cfg.MaxQueueSize then table.remove(q.items, 1) end
    q.items[#q.items + 1] = { embed = embed, ping = opts.ping or '' }
end

--- convenience: log a suspicious / likely-exploit request
function Webhook.Suspicious(src, reason, details)
    local data = { { locale('wh_reason'), reason, false } }
    for _, d in ipairs(details or {}) do data[#data + 1] = d end
    Webhook.Log('suspicious', src, locale('wh_title_suspicious'), data, { ping = SvConfig.Webhooks.SecurityPingRole })
end

--- flush everything before the resource stops (best effort)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for url, q in pairs(Queues) do
        q.busyUntil = 0
        Flush(url, q)
    end
end)

-- console test: `goldclaim_webhooktest`
RegisterCommand('goldclaim_webhooktest', function(source)
    if source ~= 0 then return end -- server console only
    for event in pairs(cfg.Events) do
        local ev = cfg.Events[event]
        if ev.enabled and GetUrl(ev.channel) then
            Webhook.Log(event, nil, locale('wh_title_test'), { { locale('wh_event'), event }, { locale('wh_channel'), ev.channel } })
        end
    end
    print('[rsg-goldclaim] queued a test message for every enabled event')
end, true)
