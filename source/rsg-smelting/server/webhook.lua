local RSGCore = exports['rsg-core']:GetCoreObject()
local cfg = SVConfig.Webhooks

Webhook = {}


---------------------------------------------------------------------
-- Queue (respects Discord rate limits, handles 429 retry_after)
---------------------------------------------------------------------
local queue = {}
local pausedUntil = 0

local function enqueue(url, payload)
    if #queue >= cfg.MaxQueue then table.remove(queue, 1) end
    queue[#queue + 1] = { url = url, body = json.encode(payload), tries = 0 }
end

CreateThread(function()
    while true do
        local item = queue[1]
        if item and GetGameTimer() >= pausedUntil then
            table.remove(queue, 1)
            PerformHttpRequest(item.url, function(status, body, headers)
                if status == 429 and item.tries < 3 then
                    local ok, data = pcall(json.decode, body or '')
                    local retry = (ok and data and tonumber(data.retry_after)) or 2
                    pausedUntil = GetGameTimer() + math.ceil(retry * 1000)
                    item.tries = item.tries + 1
                    table.insert(queue, 1, item)
                elseif status < 200 or status >= 300 then
                    print(('[rsg-smelting] webhook error HTTP %s: %s'):format(status, body or ''))
                end
            end, 'POST', item.body, { ['Content-Type'] = 'application/json' })
        end
        Wait(item and cfg.SendInterval or 1000)
    end
end)

---------------------------------------------------------------------
-- Player info helpers
---------------------------------------------------------------------
local function getIdentifier(src, prefix)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, #prefix + 1) == prefix .. ':' then return id end
    end
end

-- Snapshot player info (call before a player fully drops if you need it after)
function Webhook.PlayerInfo(src)
    local info = { id = src, name = GetPlayerName(src) or locale('wh_unknown') }
    local Player = src and RSGCore.Functions.GetPlayer(src)
    if Player then
        local ci = Player.PlayerData.charinfo or {}
        info.character = ('%s %s'):format(ci.firstname or '?', ci.lastname or '?')
        info.citizenid = Player.PlayerData.citizenid
    end
    info.license = getIdentifier(src, 'license')
    local discord = getIdentifier(src, 'discord')
    info.discord = discord and ('<@%s>'):format(discord:sub(9)) or nil
    if cfg.ShowCoords then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local c = GetEntityCoords(ped)
            info.coords = ('%.2f, %.2f, %.2f'):format(c.x, c.y, c.z)
        end
    end
    return info
end

local function trim(s, max)
    s = tostring(s)
    return #s > max and (s:sub(1, max - 3) .. '...') or s
end

---------------------------------------------------------------------
-- Public API
-- Webhook.Send(event, srcOrInfo, fields[, description])
--   event      key from SVConfig.Webhooks.Events
--   srcOrInfo  server id, a table from Webhook.PlayerInfo, or nil
--   fields     array of { name, value, inline } (or { name = value } map)
---------------------------------------------------------------------
function Webhook.Send(event, srcOrInfo, fields, description)
    if not cfg.Enabled then return end
    local ev = cfg.Events[event]
    if not ev or not ev.enabled then return end
    local url = cfg.Urls[ev.channel]
    if not url or url == '' then return end

    local embedFields = {}
    local p = type(srcOrInfo) == 'table' and srcOrInfo or (srcOrInfo and Webhook.PlayerInfo(srcOrInfo))
    if p then
        embedFields[#embedFields + 1] = { name = locale('wh_f_player'), value = trim(locale('wh_player_val', p.name, p.id), 1024), inline = true }
        if p.character then embedFields[#embedFields + 1] = { name = locale('wh_f_character'), value = trim(p.character, 1024), inline = true } end
        if p.citizenid then embedFields[#embedFields + 1] = { name = locale('wh_f_citizenid'), value = p.citizenid, inline = true } end
        if p.discord then embedFields[#embedFields + 1] = { name = locale('wh_f_discord'), value = p.discord, inline = true } end
        if p.license then embedFields[#embedFields + 1] = { name = locale('wh_f_license'), value = '`' .. p.license .. '`', inline = false } end
        if p.coords then embedFields[#embedFields + 1] = { name = locale('wh_f_coords'), value = '`' .. p.coords .. '`', inline = true } end
    end

    if fields then
        if fields[1] then
            for _, f in ipairs(fields) do
                embedFields[#embedFields + 1] = { name = trim(f.name or f[1], 256), value = trim(f.value or f[2] or '-', 1024), inline = f.inline ~= false }
            end
        else
            for k, v in pairs(fields) do
                embedFields[#embedFields + 1] = { name = trim(k, 256), value = trim(v, 1024), inline = true }
            end
        end
    end
    while #embedFields > 25 do table.remove(embedFields) end -- Discord limit

    local payload = {
        username = cfg.BotName,
        avatar_url = cfg.AvatarUrl ~= '' and cfg.AvatarUrl or nil,
        embeds = { {
            title = locale('wh_title_' .. event),
            description = description and trim(description, 4000) or nil,
            color = ev.color,
            fields = embedFields,
            footer = { text = ('%s • %s'):format(cfg.Footer, GetConvar('sv_hostname', 'RedM')):sub(1, 2048) },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    }
    if ev.channel == 'security' and cfg.SecurityPing ~= '' then
        payload.content = cfg.SecurityPing
        payload.allowed_mentions = { parse = { 'roles', 'users' } }
    else
        payload.allowed_mentions = { parse = {} } -- never ping from normal logs
    end

    enqueue(url, payload)
end

-- Describe a recipe's inputs for a batch, e.g. "500x Gold Ore, 100x Coal"
function Webhook.Inputs(recipe, amount)
    local parts = {}
    for _, inp in ipairs(recipe.inputs) do
        local def = RSGCore.Shared.Items[inp.item]
        parts[#parts + 1] = ('%dx %s'):format(inp.amount * amount, def and def.label or inp.item)
    end
    return table.concat(parts, ', ')
end

function Webhook.SmelterName(smelter)
    if smelter == 'prop' then return locale(Config.SmeltProps.label) end
    local s = Config.Smelters[smelter]
    return s and locale(s.label) or tostring(smelter)
end

-- Send everything queued right now (best effort, used on resource stop)
function Webhook.Flush()
    for _, item in ipairs(queue) do
        PerformHttpRequest(item.url, function() end, 'POST', item.body, { ['Content-Type'] = 'application/json' })
    end
    queue = {}
end

-- Allow other resources to log through this system
exports('SendWebhook', Webhook.Send)
