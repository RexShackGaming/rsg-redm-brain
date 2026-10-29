local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

---------------------------------------------------------------
-- discord webhooks: queued, rate limited, retried on 429
---------------------------------------------------------------
HuntingWebhook = {}

local Cfg = SVConfig and SVConfig.Webhooks or { Enabled = false, Channels = {} }
local queues = {}        -- [url] = { payload, ... }
local busy = {}          -- [url] = true while a request is in flight
local SEND_GAP = 2100    -- ms between requests per webhook (discord: ~30/min)
local MAX_QUEUE = 100

local function channelUrl(channel)
    local ch = Cfg.Channels[channel]
    if not ch or ch.enabled == false then return nil end
    local url = (ch.url and ch.url ~= '') and ch.url or Cfg.DefaultUrl
    if not url or url == '' then return nil end
    return url, ch.colour
end

local function process(url)
    if busy[url] then return end
    local q = queues[url]
    if not q or #q == 0 then return end
    busy[url] = true

    local payload = table.remove(q, 1)
    PerformHttpRequest(url, function(status, body, headers)
        local wait = SEND_GAP
        if status == 429 then
            -- rate limited: put it back and wait what discord asks
            table.insert(q, 1, payload)
            local ok, data = pcall(json.decode, body or '')
            local retry = ok and data and tonumber(data.retry_after)
            wait = math.floor((retry and (retry < 100 and retry * 1000 or retry) or 5000) + 250)
        elseif status < 200 or status >= 300 then
            print(('[rsg-hunting] webhook failed (%s): %s'):format(tostring(status), tostring(body)))
        end
        SetTimeout(wait, function()
            busy[url] = nil
            process(url)
        end)
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

local function trim(s, n)
    s = tostring(s or '')
    return #s > n and (s:sub(1, n - 3) .. '...') or s
end

-- player block for embeds
function HuntingWebhook.PlayerFields(src)
    local fields = {}
    local Player = src and RSGCore.Functions.GetPlayer(src)
    if not Player then
        if src == 0 then fields[1] = { name = locale('wh_player'), value = locale('wh_server_console'), inline = true } end
        return fields
    end
    local ci = Player.PlayerData.charinfo or {}
    fields[#fields + 1] = { name = locale('wh_character'), value = ('%s %s'):format(ci.firstname or '?', ci.lastname or ''), inline = true }
    fields[#fields + 1] = { name = locale('wh_player'), value = ('%s (ID %s)'):format(GetPlayerName(src) or '?', src), inline = true }
    fields[#fields + 1] = { name = locale('wh_citizenid'), value = Player.PlayerData.citizenid or '?', inline = true }
    if Cfg.ShowIdentifiers then
        local license = GetPlayerIdentifierByType(src, 'license')
        local discord = GetPlayerIdentifierByType(src, 'discord')
        if license then fields[#fields + 1] = { name = locale('wh_license'), value = '`' .. license .. '`', inline = false } end
        if discord then fields[#fields + 1] = { name = 'Discord', value = '<@' .. discord:gsub('discord:', '') .. '>', inline = true } end
    end
    return fields
end

---------------------------------------------------------------
-- HuntingWebhook.Send(channel, {
--     title = '', description = '', src = playerId?, fields = {{name, value, inline}},
--     colour = number?, content = 'plain text above embed'?
-- })
---------------------------------------------------------------
function HuntingWebhook.Send(channel, data)
    if not Cfg.Enabled then return end
    local url, colour = channelUrl(channel)
    if not url then return end

    local fields = {}
    for _, f in ipairs(data.fields or {}) do
        fields[#fields + 1] = { name = trim(f.name, 256), value = trim(f.value, 1024), inline = f.inline ~= false }
    end
    if data.src then
        for _, f in ipairs(HuntingWebhook.PlayerFields(data.src)) do fields[#fields + 1] = f end
    end
    while #fields > 25 do table.remove(fields) end

    local payload = {
        username = Cfg.BotName,
        avatar_url = (Cfg.BotAvatar ~= '' and Cfg.BotAvatar) or nil,
        content = data.content,
        embeds = { {
            author = Cfg.ServerName and { name = Cfg.ServerName } or nil,
            title = trim(data.title, 256),
            description = data.description and trim(data.description, 4000) or nil,
            color = data.colour or colour,
            fields = fields,
            footer = { text = Cfg.FooterText },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
        allowed_mentions = { parse = { 'roles', 'users' } },
    }

    queues[url] = queues[url] or {}
    if #queues[url] >= MAX_QUEUE then table.remove(queues[url], 1) end
    queues[url][#queues[url] + 1] = payload
    process(url)
end

---------------------------------------------------------------
-- skinning batches (one summary per player per window)
---------------------------------------------------------------
local skinBatch = {} -- [src] = { animals = {name = count}, items = {item = count}, xp = n, total = n }

function HuntingWebhook.Skin(src, animalName, items, xp)
    if not Cfg.Enabled or not channelUrl('skinning') then return end
    local window = Cfg.SkinningBatchSeconds or 0

    if window <= 0 then
        HuntingWebhook.Send('skinning', {
            title = locale('wh_skinned_one'), src = src,
            fields = {
                { name = locale('wh_skin'), value = animalName },
                { name = locale('wh_items'), value = #items > 0 and table.concat(items, ', ') or '-' },
                { name = locale('wh_xp'), value = tostring(xp or 0) },
            }
        })
        return
    end

    local b = skinBatch[src]
    if not b then
        b = { animals = {}, items = {}, xp = 0, total = 0 }
        skinBatch[src] = b
        SetTimeout(window * 1000, function() HuntingWebhook.FlushSkins(src) end)
    end
    b.total = b.total + 1
    b.xp = b.xp + (xp or 0)
    b.animals[animalName] = (b.animals[animalName] or 0) + 1
    for _, item in ipairs(items) do b.items[item] = (b.items[item] or 0) + 1 end
end

local function countList(t)
    local out = {}
    for k, v in pairs(t) do out[#out + 1] = ('%sx %s'):format(v, k) end
    table.sort(out)
    return #out > 0 and table.concat(out, '\n') or '-'
end

function HuntingWebhook.FlushSkins(src)
    local b = skinBatch[src]
    if not b then return end
    skinBatch[src] = nil
    HuntingWebhook.Send('skinning', {
        title = locale('wh_skinned_batch', b.total),
        description = locale('wh_skinned_batch_desc', Cfg.SkinningBatchSeconds),
        src = src,
        fields = {
            { name = locale('wh_skins'), value = countList(b.animals) },
            { name = locale('wh_items'), value = countList(b.items) },
            { name = locale('wh_xp'), value = tostring(b.xp) },
        }
    })
end

AddEventHandler('playerDropped', function()
    HuntingWebhook.FlushSkins(source)
end)

---------------------------------------------------------------
-- sales + security helpers
---------------------------------------------------------------
function HuntingWebhook.Sale(channel, src, title, fields, cash)
    HuntingWebhook.Send(channel, { title = title, src = src, fields = fields })
    if Cfg.HighValueSale and Cfg.HighValueSale > 0 and (cash or 0) >= Cfg.HighValueSale then
        HuntingWebhook.Send('security', {
            title = locale('wh_high_value_title'),
            description = locale('wh_high_value_desc', title, ('%.2f'):format(cash), ('%.2f'):format(Cfg.HighValueSale)),
            src = src, colour = 15105570,
        })
    end
end

local alertThrottle = {} -- ["src:reason"] = os.time()
function HuntingWebhook.Security(src, source_, reason)
    local key = ('%s:%s'):format(src, reason)
    local now = os.time()
    if alertThrottle[key] and now - alertThrottle[key] < (Cfg.SecurityThrottleSeconds or 60) then return end
    alertThrottle[key] = now
    HuntingWebhook.Send('security', {
        title = locale('wh_security_title'),
        content = (Cfg.MentionOnAlert ~= '' and Cfg.MentionOnAlert) or nil,
        src = src,
        fields = {
            { name = locale('wh_where'), value = source_ },
            { name = locale('wh_reason'), value = reason, inline = false },
        }
    })
end

CreateThread(function()
    while true do
        Wait(600000)
        local now = os.time()
        for k, t in pairs(alertThrottle) do
            if now - t > 3600 then alertThrottle[k] = nil end
        end
    end
end)

---------------------------------------------------------------
-- admin test command: /huntingwebhooktest
---------------------------------------------------------------
RSGCore.Commands.Add('huntingwebhooktest', locale('wh_test_help'), {}, false, function(source)
    for channel in pairs(Cfg.Channels) do
        HuntingWebhook.Send(channel, {
            title = locale('wh_test_title'),
            description = locale('wh_test_desc', channel),
            src = source,
        })
    end
    if source > 0 then
        TriggerClientEvent('ox_lib:notify', source, { title = locale('hunting_xp_title'), description = locale('wh_test_sent'), type = 'success' })
    else
        print('[rsg-hunting] webhook test sent')
    end
end, 'admin')

exports('SendWebhook', HuntingWebhook.Send)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(skinBatch) do HuntingWebhook.FlushSkins(src) end
end)
