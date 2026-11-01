-- Rate-limited, retrying Discord webhook dispatcher for rsg-poison.
-- Logging only: it never blocks or changes gameplay, and every failure is contained.

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()
local cfg = WebhookConfig
local resourceName = GetCurrentResourceName()

local queues, draining = {}, {}

local function debugPrint(msg, ...)
    if cfg.Debug then print(('[%s] ' .. msg):format(resourceName, ...)) end
end

-------------------------------------------------------------------------------
-- Transport
-------------------------------------------------------------------------------

--- Sends one payload and waits for the response. Returns ok, retryAfterMs.
local function post(url, body)
    local p = promise.new()
    PerformHttpRequest(url, function(status, respBody)
        if status == 200 or status == 204 then
            return p:resolve({ true })
        end
        local retryMs
        if status == 429 then
            local ok, data = pcall(json.decode, respBody or '')
            retryMs = (ok and data and tonumber(data.retry_after) or 1) * 1000
        elseif status >= 500 or status == 0 then
            retryMs = 2000
        end
        debugPrint('Webhook HTTP %s%s', status, retryMs and (' (retrying in %dms)'):format(retryMs) or '')
        p:resolve({ false, retryMs })
    end, 'POST', body, { ['Content-Type'] = 'application/json' })
    local r = Citizen.Await(p)
    return r[1], r[2]
end

local function drain(url)
    if draining[url] then return end
    draining[url] = true

    CreateThread(function()
        local q = queues[url]
        while q and #q > 0 do
            local job = q[1]
            local ok, retryMs = post(url, job.body)

            if ok or not retryMs or job.tries >= cfg.MaxRetries then
                table.remove(q, 1)
                if not ok then
                    print(('[%s] ^1Discord webhook send failed after %d attempt(s), dropping log.^7'):format(resourceName, job.tries + 1))
                end
                Wait(cfg.SendIntervalMs)
            else
                job.tries = job.tries + 1
                Wait(math.max(retryMs, cfg.SendIntervalMs))
            end
        end
        draining[url] = nil
    end)
end

local function enqueue(url, payload)
    local ok, body = pcall(json.encode, payload)
    if not ok then
        print(('[%s] ^1Failed to encode webhook payload, skipping.^7'):format(resourceName))
        return
    end

    queues[url] = queues[url] or {}
    if #queues[url] >= cfg.MaxQueue then
        debugPrint('Queue full for a webhook URL, dropping log.')
        return
    end
    queues[url][#queues[url] + 1] = { body = body, tries = 0 }
    drain(url)
end

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function isEventEnabled(eventName)
    local v = cfg.Events[eventName]
    if v == nil then v = cfg.Events.default end
    return v == true
end

local function resolveUrl(eventName)
    local url = cfg.Urls[eventName]
    if not url or url == '' then url = cfg.Urls.default end
    if url and url ~= '' then return url end
end

local function truncate(str, max)
    str = tostring(str or '')
    return #str > max and (str:sub(1, max - 3) .. '...') or str
end

local function field(name, value, inline)
    return { name = truncate(name, 256), value = truncate(value ~= '' and value or '-', 1024), inline = inline ~= false }
end

--- Builds the standard player-info fields for an embed.
function GetPoisonPlayerFields(src)
    local inc = cfg.Include
    local fields = {
        field(locale('wh_field_player'), locale('wh_player_value', GetPlayerName(src) or locale('wh_unknown'), src)),
    }

    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then
        local pd = Player.PlayerData
        if inc.CharacterName and pd.charinfo then
            fields[#fields + 1] = field(locale('wh_field_character'), ('%s %s'):format(pd.charinfo.firstname or '', pd.charinfo.lastname or ''))
        end
        if inc.CitizenId then
            fields[#fields + 1] = field(locale('wh_field_citizenid'), ('`%s`'):format(pd.citizenid or locale('wh_unknown')))
        end
        if inc.Job and pd.job then
            fields[#fields + 1] = field(locale('wh_field_job'), ('%s (%s)'):format(pd.job.label or pd.job.name or '-', pd.job.grade and pd.job.grade.name or '-'))
        end
    end

    if inc.Discord then
        local id = GetPlayerIdentifierByType(src, 'discord')
        if id then fields[#fields + 1] = field(locale('wh_field_discord'), ('<@%s>'):format(id:gsub('discord:', ''))) end
    end
    if inc.License then
        local id = GetPlayerIdentifierByType(src, 'license')
        if id then fields[#fields + 1] = field(locale('wh_field_license'), ('`%s`'):format(id), false) end
    end
    if inc.Steam then
        local id = GetPlayerIdentifierByType(src, 'steam')
        if id then fields[#fields + 1] = field(locale('wh_field_steam'), ('`%s`'):format(id), false) end
    end

    local ped = GetPlayerPed(src)
    if ped ~= 0 then
        if inc.Health then
            fields[#fields + 1] = field(locale('wh_field_health'), tostring(GetEntityHealth(ped)))
        end
        if inc.Coords then
            local c = GetEntityCoords(ped)
            fields[#fields + 1] = field(locale('wh_field_coords'), ('`vec3(%.2f, %.2f, %.2f)`'):format(c.x, c.y, c.z), false)
        end
    end

    return fields
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- Sends a log embed.
--- eventName : key in WebhookConfig.Events / Urls / Colors
--- data      : { title, description, src (player to attach info for), fields = {{name, value, inline}}, color }
function SendPoisonLog(eventName, data)
    if not cfg.Enabled or not isEventEnabled(eventName) then return end
    local url = resolveUrl(eventName)
    if not url then return end

    local fields = data.src and GetPoisonPlayerFields(data.src) or {}
    for _, f in ipairs(data.fields or {}) do
        fields[#fields + 1] = field(f.name, f.value, f.inline)
    end
    while #fields > 25 do table.remove(fields) end -- Discord limit

    local mention = cfg.Mentions[eventName]
    enqueue(url, {
        username   = cfg.BotName ~= '' and cfg.BotName or nil,
        avatar_url = cfg.AvatarUrl ~= '' and cfg.AvatarUrl or nil,
        content    = (mention and mention ~= '') and mention or nil,
        allowed_mentions = { parse = { 'roles' } }, -- don't ping players named in fields
        embeds = {{
            title       = truncate(data.title, 256),
            description = truncate(data.description, 4096),
            color       = data.color or cfg.Colors[eventName] or cfg.Colors.system,
            fields      = fields,
            footer      = { text = ('%s • %s'):format(cfg.ServerName, resourceName) },
            timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        }},
    })
end

-- Other server resources can log through the same queue:
-- exports['rsg-poison']:SendPoisonLog('poisoned', { title = '...', description = '...', src = source })
exports('SendPoisonLog', SendPoisonLog)

-------------------------------------------------------------------------------
-- Test command & lifecycle logs
-------------------------------------------------------------------------------

lib.addCommand('poisonwebhooktest', {
    help = locale('cmd_webhooktest_help'),
    restricted = cfg.TestCommandAce,
}, function(source)
    local sent = {}
    for eventName in pairs(cfg.Urls) do
        local url = resolveUrl(eventName)
        if url and not sent[url] then
            sent[url] = true
            enqueue(url, {
                username = cfg.BotName ~= '' and cfg.BotName or nil,
                embeds = {{
                    title = locale('wh_test_title'),
                    description = locale('wh_test_desc', resourceName, eventName),
                    color = cfg.Colors.system,
                    fields = source > 0 and GetPoisonPlayerFields(source) or nil,
                    footer = { text = ('%s • %s'):format(cfg.ServerName, resourceName) },
                    timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
                }},
            })
        end
    end
    local msg = next(sent) and locale('cmd_webhooktest_sent') or locale('cmd_webhooktest_none')
    if source > 0 then
        TriggerClientEvent('ox_lib:notify', source, { title = locale('cmd_webhooktest_title'), description = msg, type = 'inform', duration = 5000 })
    else
        print(('[%s] %s'):format(resourceName, msg))
    end
end)

CreateThread(function()
    SendPoisonLog('system', { title = locale('wh_started_title'), description = locale('wh_started_desc', resourceName) })
end)
