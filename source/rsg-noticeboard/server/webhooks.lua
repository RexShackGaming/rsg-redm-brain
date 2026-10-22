-- Discord webhook sender: per-url queue, respects Discord rate limits (429 retry_after)
Webhook = {}

local Cfg = SvConfig.Webhooks
local Queues = {}   -- [url] = { items = {}, running = bool }
local Cooldowns = {} -- [key] = os.time() of last send, stops one player flooding a channel

local function truncate(s, n)
    s = tostring(s or '')
    if #s <= n then return s end
    return s:sub(1, n - 3) .. '...'
end

local function processQueue(url)
    local q = Queues[url]
    if q.running then return end
    q.running = true
    CreateThread(function()
        while #q.items > 0 do
            local payload = q.items[1]
            local p = promise.new()
            PerformHttpRequest(url, function(status, body)
                if status == 429 then
                    local data = body and json.decode(body)
                    p:resolve(math.ceil(((data and data.retry_after) or 2) * 1000) + 250)
                else
                    if status < 200 or status >= 300 then
                        print(('[rsg-noticeboard] ^1webhook failed (%s)^7 %s'):format(status, body or ''))
                    end
                    table.remove(q.items, 1)
                    p:resolve(1100) -- ~1 message per second per webhook stays well under the limit
                end
            end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
            Wait(Citizen.Await(p))
        end
        q.running = false
    end)
end

local function enqueue(url, payload)
    Queues[url] = Queues[url] or { items = {}, running = false }
    local q = Queues[url]
    if #q.items >= 50 then table.remove(q.items, 1) end -- never let a dead webhook grow forever
    q.items[#q.items + 1] = payload
    processQueue(url)
end

-- player fields for an embed
function Webhook.PlayerFields(src, Player)
    local fields = {}
    if Player then
        local ci = Player.PlayerData.charinfo
        fields[#fields + 1] = { name = locale('wh_character'), value = ('%s %s'):format(ci.firstname or '', ci.lastname or ''), inline = true }
        fields[#fields + 1] = { name = locale('wh_citizenid'), value = Player.PlayerData.citizenid, inline = true }
    end
    if src and src > 0 then
        fields[#fields + 1] = { name = locale('wh_player'), value = locale('wh_player_value'):format(GetPlayerName(src) or '?', src), inline = true }
        if Cfg.IncludeIdentifiers then
            local license = GetPlayerIdentifierByType(src, 'license') or locale('wh_na')
            local discord = GetPlayerIdentifierByType(src, 'discord')
            fields[#fields + 1] = { name = locale('wh_license'), value = license, inline = false }
            if discord then
                fields[#fields + 1] = { name = locale('wh_discord'), value = ('<@%s>'):format(discord:gsub('discord:', '')), inline = true }
            end
        end
    end
    return fields
end

-- notice fields for an embed
function Webhook.NoticeFields(n)
    local f = {
        { name = locale('wh_notice_id'), value = tostring(n.id or '?'), inline = true },
        { name = locale('wh_category'), value = tostring(n.category or '?'), inline = true },
        { name = locale('wh_town'), value = tostring(n.town or locale('sv_all_towns')), inline = true },
        { name = locale('wh_title'), value = truncate(n.title, 256), inline = false },
    }
    if n.body then f[#f + 1] = { name = locale('wh_text'), value = truncate(n.body, Cfg.BodyPreviewLength), inline = false } end
    if n.author then f[#f + 1] = { name = locale('wh_author'), value = n.author, inline = true } end
    if n.expires_at then f[#f + 1] = { name = locale('wh_expires'), value = ('<t:%d:F> (<t:%d:R>)'):format(n.expires_at, n.expires_at), inline = false } end
    return f
end

-- Webhook.Send('noticePosted', { description = '...', fields = {...}, image = url, cooldownKey = 'x' })
function Webhook.Send(event, data)
    if not Cfg.Enabled then return end
    if data.cooldownKey then
        local now = os.time()
        if Cooldowns[data.cooldownKey] and now - Cooldowns[data.cooldownKey] < Cfg.ExploitCooldown then return end
        Cooldowns[data.cooldownKey] = now
    end
    local ev = Cfg.Events[event]
    if not ev or not ev.enabled then return end
    local url = (ev.url ~= '' and ev.url) or Cfg.Default
    if not url or url == '' then return end

    local fields = {}
    for i = 1, math.min(#(data.fields or {}), 25) do
        local fl = data.fields[i]
        fields[i] = { name = truncate(fl.name, 256), value = truncate(fl.value ~= '' and fl.value or '-', 1024), inline = fl.inline }
    end

    local embed = {
        title = locale('wh_ev_' .. event),
        description = data.description and truncate(data.description, 4000) or nil,
        color = ev.color,
        fields = fields,
        footer = { text = Cfg.Footer },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
    if data.image and Cfg.ShowNoticeImage then embed.thumbnail = { url = data.image } end

    enqueue(url, {
        username = Cfg.BotName,
        avatar_url = Cfg.Avatar ~= '' and Cfg.Avatar or nil,
        content = (event == 'exploit' and Cfg.ExploitMention ~= '') and Cfg.ExploitMention or nil,
        embeds = { embed },
    })
end
