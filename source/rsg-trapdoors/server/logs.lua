-- Discord webhook logging for rsg-trapdoors (server only)
local RSGCore = exports['rsg-core']:GetCoreObject()
local cfg = WebhookConfig
lib.locale()

local queues   = {} -- channel -> { embeds }
local throttle = {} -- 'src:reason' -> game timer

---------------------------------------------------------------------
-- player info
---------------------------------------------------------------------
local function identifier(src, kind)
    local id = GetPlayerIdentifierByType(src, kind)
    return id and id:gsub('^' .. kind .. ':', '') or nil
end

local function playerFields(src)
    local fields = {}
    if not src or src <= 0 then return fields end

    local name = GetPlayerName(src) or locale('log_unknown')
    local Player = RSGCore.Functions.GetPlayer(src)
    local charName, cid = locale('log_na'), locale('log_na')
    if Player then
        local ci = Player.PlayerData.charinfo or {}
        charName = ('%s %s'):format(ci.firstname or '', ci.lastname or '')
        cid = Player.PlayerData.citizenid or cid
    end

    local discord = identifier(src, 'discord')
    local playerLine = locale('log_player_line', name, src)
    if cfg.MentionDiscord and discord then
        playerLine = playerLine .. ('\n<@%s>'):format(discord)
    end

    fields[#fields + 1] = { name = locale('log_field_player'), value = playerLine, inline = true }
    fields[#fields + 1] = { name = locale('log_field_character'), value = ('%s\n`%s`'):format(charName, cid), inline = true }

    if cfg.ShowIdentifiers then
        local ids = {}
        for _, kind in ipairs({ 'license', 'steam', 'discord' }) do
            local v = identifier(src, kind)
            if v then ids[#ids + 1] = ('**%s:** `%s`'):format(kind, v) end
        end
        if #ids > 0 then
            fields[#fields + 1] = { name = locale('log_field_identifiers'), value = table.concat(ids, '\n'), inline = false }
        end
    end

    if cfg.ShowCoords then
        local ped = GetPlayerPed(src)
        if ped ~= 0 then
            local c = GetEntityCoords(ped)
            fields[#fields + 1] = { name = locale('log_field_coords'), value = ('`%.2f, %.2f, %.2f`'):format(c.x, c.y, c.z), inline = false }
        end
    end

    return fields
end

---------------------------------------------------------------------
-- sending
---------------------------------------------------------------------
local function post(url, embeds, attempt)
    local body = json.encode({
        username = locale('log_bot_name'),
        avatar_url = cfg.AvatarUrl ~= '' and cfg.AvatarUrl or nil,
        embeds = embeds,
        allowed_mentions = { parse = {} }, -- never actually ping anyone
    })

    PerformHttpRequest(url, function(status, _, headers, response)
        if status >= 200 and status < 300 then return end

        attempt = (attempt or 0) + 1
        if attempt > cfg.MaxRetries then
            print(('^1[rsg-trapdoors] webhook failed (HTTP %s), dropping %d embed(s)^7'):format(status, #embeds))
            return
        end

        local wait = 2000
        if status == 429 then
            local ok, data = pcall(json.decode, response or '')
            if ok and data and data.retry_after then
                wait = math.ceil(tonumber(data.retry_after) * 1000) + 250
            end
        end
        SetTimeout(wait, function() post(url, embeds, attempt) end)
    end, 'POST', body, { ['Content-Type'] = 'application/json' })
end

-- one worker drains all queues, batching up to 10 embeds per request
CreateThread(function()
    while true do
        Wait(cfg.SendInterval)
        for channel, queue in pairs(queues) do
            if #queue > 0 then
                local url = cfg.Channels[channel]
                local batch = {}
                for i = 1, math.min(#queue, cfg.MaxEmbedsPerMsg) do
                    batch[i] = table.remove(queue, 1)
                end
                post(url, batch)
            end
        end
    end
end)

---------------------------------------------------------------------
-- public API
---------------------------------------------------------------------
--- Queue a log entry.
--- @param event string key of WebhookConfig.Events
--- @param src number|nil player server id (nil for system events)
--- @param data table|nil { door = id, description = string, fields = { {name,value,inline} } }
function TrapdoorLog(event, src, data)
    if not cfg.Enabled then return end
    local ev = cfg.Events[event]
    if not ev or not ev.enabled then return end

    local url = cfg.Channels[ev.channel]
    if not url or url == '' then return end

    data = data or {}

    -- stop exploiters flooding the webhook
    if event == 'suspicious' and src then
        local key = ('%s:%s'):format(src, data.description or '')
        local now = GetGameTimer()
        if (throttle[key] or 0) > now then return end
        throttle[key] = now + cfg.SuspiciousThrottle
    end

    local fields = {}
    if data.door then
        local door = Config.Trapdoors[data.door]
        fields[#fields + 1] = {
            name = locale('log_field_trapdoor'),
            value = ('%s\n`%s`'):format(door and locale(door.label) or data.door, data.door),
            inline = true,
        }
    end
    for _, f in ipairs(playerFields(src)) do fields[#fields + 1] = f end
    for _, f in ipairs(data.fields or {}) do fields[#fields + 1] = f end

    queues[ev.channel] = queues[ev.channel] or {}
    local queue = queues[ev.channel]
    if #queue >= 100 then table.remove(queue, 1) end -- hard cap so a flood can't eat memory

    queue[#queue + 1] = {
        title = locale('log_title_' .. event),
        description = data.description,
        color = ev.color,
        fields = fields,
        footer = { text = ('%s • %s'):format(cfg.ServerName, GetCurrentResourceName()) },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
end

--- Formats a passcode for logs, respecting LogPasscodes.
function TrapdoorLogCode(code)
    if cfg.LogPasscodes and code then return ('||%s||'):format(code) end
    return ('`%s`'):format(locale('log_hidden'))
end

AddEventHandler('playerDropped', function()
    local prefix = tostring(source) .. ':'
    for key in pairs(throttle) do
        if key:sub(1, #prefix) == prefix then throttle[key] = nil end
    end
end)

-- let other resources use the same logger if they want
exports('Log', TrapdoorLog)
