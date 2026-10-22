---------------------------------------------
-- Discord webhook logging (server only)
---------------------------------------------
local RSGCore = exports['rsg-core']:GetCoreObject()
local cfg = SvConfig.Webhook
lib.locale()

local queues = {}   -- [url] = { items = {}, busy = false, nextAt = 0 }

local function trim(str, max)
    str = tostring(str or '')
    if #str > max then return str:sub(1, max - 3) .. '...' end
    return str
end

local function identifiers(src)
    local out = {}
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        local kind, value = id:match('^(%w+):(.+)$')
        if kind and cfg.ShowIdentifiers[kind] then
            out[#out + 1] = kind == 'discord' and ('discord: <@%s>'):format(value) or id
        end
    end
    return table.concat(out, '\n')
end

local function playerFields(src)
    local Player = src and RSGCore.Functions.GetPlayer(src)
    if not Player then
        return { { name = locale('wh_player'), value = locale('wh_offline', tostring(src)), inline = true } }
    end
    local c = Player.PlayerData.charinfo or {}
    local fields = {
        { name = locale('wh_character'), value = trim(('%s %s'):format(c.firstname or '?', c.lastname or '?'), 1024), inline = true },
        { name = locale('wh_citizenid'), value = tostring(Player.PlayerData.citizenid), inline = true },
        { name = locale('wh_server_id'), value = tostring(src), inline = true },
        { name = locale('wh_steam_name'), value = trim(GetPlayerName(src) or '?', 1024), inline = true },
    }
    local ids = identifiers(src)
    if ids ~= '' then fields[#fields + 1] = { name = locale('wh_identifiers'), value = trim(ids, 1024), inline = false } end
    return fields
end

local function processQueue(url)
    local q = queues[url]
    if q.busy then return end
    q.busy = true
    CreateThread(function()
        while #q.items > 0 do
            local wait = q.nextAt - GetGameTimer()
            if wait > 0 then Wait(wait) end

            local payload = table.remove(q.items, 1)
            local p = promise.new()
            PerformHttpRequest(url, function(status, _, headers)
                if status == 429 then
                    -- rate limited: put it back and honour Retry-After
                    table.insert(q.items, 1, payload)
                    local retry = tonumber(headers and (headers['Retry-After'] or headers['retry-after'])) or 2
                    q.nextAt = GetGameTimer() + math.ceil(retry * 1000)
                elseif status < 200 or status >= 300 then
                    print(('^3[rsg-crafting] Webhook failed (HTTP %s)^7'):format(status))
                    q.nextAt = GetGameTimer() + cfg.RateLimit
                else
                    q.nextAt = GetGameTimer() + cfg.RateLimit
                end
                p:resolve()
            end, 'POST', payload, { ['Content-Type'] = 'application/json' })
            Citizen.Await(p)
        end
        q.busy = false
    end)
end

---Send a log to Discord.
---@param logType 'craft'|'failed'|'cancelled'|'suspicious'|'xp'
---@param title string
---@param description string
---@param src number|nil player source to attach character info
---@param extra table|nil extra embed fields { { name, value, inline } }
local function SendLog(logType, title, description, src, extra)
    if cfg.UseRsgLog and logType ~= 'cancelled' and GetResourceState('rsg-log') == 'started' then
        local colorName = ({ craft = 'green', failed = 'orange', suspicious = 'red', xp = 'blue' })[logType] or 'default'
        TriggerEvent('rsg-log:server:CreateLog', 'crafting', title, colorName, description)
    end

    if not cfg.Enabled then return end
    local url = cfg.Urls[logType]
    if not url or url == '' then return end

    local fields = src and playerFields(src) or {}
    for _, f in ipairs(extra or {}) do
        fields[#fields + 1] = { name = trim(f.name or f[1], 256), value = trim(f.value or f[2], 1024), inline = f.inline ~= false }
    end
    while #fields > 25 do table.remove(fields) end

    local payload = json.encode({
        username = cfg.Username,
        avatar_url = cfg.Avatar ~= '' and cfg.Avatar or nil,
        content = (logType == 'suspicious' and cfg.SuspiciousMention ~= '') and cfg.SuspiciousMention or nil,
        allowed_mentions = { parse = { 'roles', 'users' } },
        embeds = { {
            title = trim(title, 256),
            description = trim(description, 4000),
            color = cfg.Colors[logType] or 0,
            fields = fields,
            footer = { text = cfg.Footer },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    })

    queues[url] = queues[url] or { items = {}, busy = false, nextAt = 0 }
    local q = queues[url]
    if #q.items >= cfg.MaxQueue then table.remove(q.items, 1) end
    q.items[#q.items + 1] = payload
    processQueue(url)
end

CraftLog = SendLog
exports('SendCraftingLog', SendLog)
