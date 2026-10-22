-- Discord webhook logging for rsg-mining (server only)
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

Webhook = {}

local queues = {}   -- [url] = { list = {}, running = bool }
local pump

local function isValidUrl(url)
    return type(url) == 'string' and url:find('^https://[%w%.]*discord%.com/api/webhooks/') ~= nil
end

local function trim(v, max)
    v = tostring(v == nil and '-' or v)
    if v == '' then v = '-' end
    return #v > max and (v:sub(1, max - 3) .. '...') or v
end

local function identifier(src, prefix)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, #prefix) == prefix then return id:sub(#prefix + 1) end
    end
end

-- player block shown on every player-triggered embed
local function playerFields(src, citizenid)
    local fields = {}
    local Player = src and RSGCore.Functions.GetPlayer(src)
        or (citizenid and RSGCore.Functions.GetPlayerByCitizenId(citizenid))
    if Player then
        local ci = Player.PlayerData.charinfo or {}
        local s  = Player.PlayerData.source
        fields[#fields + 1] = { name = locale('wh_character'), value = ('%s %s'):format(ci.firstname or '?', ci.lastname or '?'), inline = true }
        fields[#fields + 1] = { name = locale('wh_citizenid'), value = Player.PlayerData.citizenid, inline = true }
        fields[#fields + 1] = { name = locale('wh_server_id'), value = tostring(s), inline = true }
        if WebhookConfig.ShowIdentifiers then
            local discord = identifier(s, 'discord:')
            fields[#fields + 1] = { name = locale('wh_player'), value = ('%s%s'):format(GetPlayerName(s) or '?', discord and (' (<@' .. discord .. '>)') or ''), inline = true }
            fields[#fields + 1] = { name = locale('wh_license'), value = identifier(s, 'license:') or '-', inline = false }
        end
    elseif citizenid then
        fields[#fields + 1] = { name = locale('wh_citizenid'), value = locale('wh_offline', citizenid), inline = true }
    end
    return fields
end

local function post(url, entry)
    PerformHttpRequest(url, function(status)
        if status == 429 and entry.tries < 3 then
            -- rate limited: retry it on the next send
            entry.tries = entry.tries + 1
            table.insert(queues[url].list, 1, entry)
            pump(url) -- the send loop may already have finished
        elseif status < 200 or status >= 300 then
            print(('[rsg-mining] ^1webhook failed (%s)^7'):format(status))
        end
    end, 'POST', json.encode(entry.payload), { ['Content-Type'] = 'application/json' })
end

pump = function(url)
    local q = queues[url]
    if q.running then return end
    q.running = true
    CreateThread(function()
        while #q.list > 0 do
            post(url, table.remove(q.list, 1))
            Wait(WebhookConfig.SendInterval)
        end
        q.running = false
    end)
end

local function enqueue(url, payload)
    local q = queues[url]
    if not q then q = { list = {}, running = false }; queues[url] = q end
    if #q.list >= WebhookConfig.MaxQueue then table.remove(q.list, 1) end
    q.list[#q.list + 1] = { payload = payload, tries = 0 }
    pump(url)
end

--[[
  Webhook.Log(event, opts)
    opts.src        player source (optional)
    opts.citizenid  used when the player may be offline (optional)
    opts.mine       mine label
    opts.fields     extra { name, value, inline } rows
    opts.value      number checked against alertAbove
    opts.description optional text
]]
function Webhook.Log(event, opts)
    if not WebhookConfig.Enabled then return end
    local ev = WebhookConfig.Events[event]
    if not ev or not ev.enabled then return end
    local url = (ev.url ~= '' and ev.url) or WebhookConfig.DefaultUrl
    if not isValidUrl(url) then return end
    opts = opts or {}

    local fields = {}
    if opts.mine then
        fields[1] = { name = locale('wh_mine'), value = opts.mine, inline = true }
    end
    for _, f in ipairs(opts.fields or {}) do fields[#fields + 1] = f end
    for _, f in ipairs(playerFields(opts.src, opts.citizenid)) do fields[#fields + 1] = f end

    -- Discord limits: 25 fields, 256 name, 1024 value
    local clean = {}
    for i = 1, math.min(#fields, 25) do
        clean[i] = { name = trim(fields[i].name, 256), value = trim(fields[i].value, 1024), inline = fields[i].inline and true or false }
    end

    local alert = ev.alertAbove and opts.value and opts.value >= ev.alertAbove
    local embed = {
        title       = (alert and '⚠ ' or '') .. locale('wh_' .. event),
        description = opts.description and trim(opts.description, 4000) or nil,
        color       = WebhookConfig.Colors[alert and 'red' or ev.color] or WebhookConfig.Colors.grey,
        fields      = clean,
        footer      = { text = WebhookConfig.Footer },
        timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }

    enqueue(url, {
        username   = WebhookConfig.BotName,
        avatar_url = WebhookConfig.Avatar ~= '' and WebhookConfig.Avatar or nil,
        content    = (alert and WebhookConfig.AlertMention ~= '') and WebhookConfig.AlertMention or nil,
        embeds     = { embed },
    })
end

-- console / admin test: rsgmining_webhooktest
RegisterCommand('rsgmining_webhooktest', function(src)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'command.rsgmining_webhooktest') then return end
    local sent = {}
    for event, ev in pairs(WebhookConfig.Events) do
        local url = (ev.url ~= '' and ev.url) or WebhookConfig.DefaultUrl
        if ev.enabled and isValidUrl(url) and not sent[url] then
            sent[url] = true
            enqueue(url, { username = WebhookConfig.BotName, embeds = { {
                title = locale('wh_test_title'), description = locale('wh_test_desc', event),
                color = WebhookConfig.Colors.green, footer = { text = WebhookConfig.Footer },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            } } })
        end
    end
    local n = 0 for _ in pairs(sent) do n = n + 1 end
    print(('[rsg-mining] sent webhook test to %d url(s)'):format(n))
end, true)
