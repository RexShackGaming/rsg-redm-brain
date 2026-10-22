---------------------------------
-- discord webhook logger (server only)
-- usage:  Webhook.Send('sales', { title=..., description=..., fields={...}, src=playerId })
---------------------------------
local RSGCore = exports['rsg-core']:GetCoreObject()
local Cfg = SvConfig.Webhooks
lib.locale()

Webhook = {}

local queue = {}
local pausedUntil = 0

local function trunc(str, max)
    str = tostring(str or '')
    if #str > max then return str:sub(1, max - 3) .. '...' end
    return str
end

local function isoTime()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

---------------------------------
-- player identity block
---------------------------------
local function getIdentifier(src, kind)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, #kind + 1) == kind .. ':' then return id end
    end
end

function Webhook.PlayerFields(src)
    local fields = {}
    local Player = RSGCore.Functions.GetPlayer(src)
    local name = GetPlayerName(src) or 'unknown'

    fields[#fields + 1] = { name = locale('wh_player'), value = locale('wh_player_value', name, src), inline = true }
    if Player then
        local ci = Player.PlayerData.charinfo or {}
        fields[#fields + 1] = { name = locale('wh_character'), value = ('%s %s'):format(ci.firstname or '?', ci.lastname or '?'), inline = true }
        fields[#fields + 1] = { name = locale('wh_citizenid'), value = tostring(Player.PlayerData.citizenid), inline = true }
    end

    local show, ids = Cfg.showIdentifiers, {}
    if show.license then ids[#ids + 1] = getIdentifier(src, 'license') end
    if show.steam then ids[#ids + 1] = getIdentifier(src, 'steam') end
    if show.ip then ids[#ids + 1] = getIdentifier(src, 'ip') end
    if show.discord then
        local d = getIdentifier(src, 'discord')
        if d then ids[#ids + 1] = ('<@%s>'):format(d:sub(9)) end
    end
    if #ids > 0 then
        fields[#fields + 1] = { name = locale('wh_identifiers'), value = table.concat(ids, '\n'), inline = false }
    end
    return fields
end

---------------------------------
-- public api
---------------------------------
---@param logType string key of Cfg.urls
---@param data { title:string, description?:string, fields?:table, src?:number, alert?:boolean }
function Webhook.Send(logType, data)
    if not Cfg.enabled then return end
    local url = Cfg.urls[logType]
    if not url or url == '' then return end

    local fields = {}
    if data.src then
        for _, f in ipairs(Webhook.PlayerFields(data.src)) do fields[#fields + 1] = f end
    end
    for _, f in ipairs(data.fields or {}) do fields[#fields + 1] = f end

    -- enforce discord limits: 25 fields, 256 name, 1024 value
    local clean = {}
    for i = 1, math.min(#fields, 25) do
        local f = fields[i]
        clean[i] = { name = trunc(f.name, 256), value = trunc(f.value ~= '' and f.value or '-', 1024), inline = f.inline and true or false }
    end

    local payload = {
        username = Cfg.username,
        avatar_url = Cfg.avatar ~= '' and Cfg.avatar or nil,
        content = (data.alert and Cfg.mentionOnAlert ~= '') and Cfg.mentionOnAlert or nil,
        embeds = { {
            title = trunc(data.title, 256),
            description = data.description and trunc(data.description, 4096) or nil,
            color = Cfg.colors[logType] or 9807270,
            author = { name = Cfg.serverName },
            fields = clean,
            footer = { text = Cfg.footer },
            timestamp = isoTime(),
        } },
        allowed_mentions = { parse = { 'roles', 'users' } },
    }

    if #queue >= Cfg.maxQueue then table.remove(queue, 1) end
    queue[#queue + 1] = { url = url, body = json.encode(payload), tries = 0 }
end

---------------------------------
-- queue worker (respects discord rate limits)
---------------------------------
CreateThread(function()
    while true do
        Wait(Cfg.sendInterval)
        if #queue > 0 and GetGameTimer() >= pausedUntil then
            local job = table.remove(queue, 1)
            PerformHttpRequest(job.url, function(status, body, headers)
                if status == 429 then
                    -- rate limited: requeue at the front and back off
                    local retry = 2.0
                    local ok, decoded = pcall(json.decode, body or '')
                    if ok and decoded and decoded.retry_after then retry = tonumber(decoded.retry_after) or retry end
                    pausedUntil = GetGameTimer() + math.ceil(retry * 1000)
                    job.tries = job.tries + 1
                    if job.tries <= 3 then table.insert(queue, 1, job) end
                elseif status < 200 or status >= 300 then
                    print(('^1[%s] webhook failed (HTTP %s)^7'):format(GetCurrentResourceName(), status))
                end
            end, 'POST', job.body, { ['Content-Type'] = 'application/json' })
        end
    end
end)

---------------------------------
-- system logs
---------------------------------
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Webhook.Send('system', { title = locale('wh_started_title'), description = locale('wh_started', res, GetResourceMetadata(res, 'version', 0) or '?') })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- flush whatever we can synchronously-ish before shutdown
    for _, job in ipairs(queue) do
        PerformHttpRequest(job.url, function() end, 'POST', job.body, { ['Content-Type'] = 'application/json' })
    end
    queue = {}
end)

---------------------------------
-- console / admin test command
---------------------------------
lib.addCommand('fishmonger_webhooktest', {
    help = locale('cmd_webhooktest_help'),
    restricted = 'group.admin',
}, function(source)
    for logType, url in pairs(Cfg.urls) do
        if url ~= '' then
            Webhook.Send(logType, { title = locale('wh_test_title'), description = locale('wh_test_desc', logType), src = source > 0 and source or nil })
        end
    end
    print(('[%s] webhook test queued'):format(GetCurrentResourceName()))
end)
