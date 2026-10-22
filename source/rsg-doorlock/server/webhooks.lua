local RSGCore = exports['rsg-core']:GetCoreObject()
local W = SvConfig.Webhooks
lib.locale()

Webhook = {}

---------------------------------------------
-- queue: batches up to 10 embeds per message per url, respects Discord rate limits
---------------------------------------------
local queues = {}      -- [url] = { embeds... }
local blockedUntil = {} -- [url] = GetGameTimer() ms

local function urlFor(logType)
    local u = W.Urls[logType]
    if not u or u == '' then u = W.Urls.Default end
    return (u and u ~= '') and u or nil
end

local function send(url, embeds, content)
    PerformHttpRequest(url, function(status, _, headers)
        if status == 429 then
            local retry = tonumber(headers and (headers['Retry-After'] or headers['retry-after'])) or 2
            blockedUntil[url] = GetGameTimer() + math.ceil(retry * 1000)
            -- requeue at the front
            local q = queues[url] or {}
            for i = #embeds, 1, -1 do table.insert(q, 1, embeds[i]) end
            queues[url] = q
        elseif status < 200 or status >= 300 then
            print(('[rsg-doorlock] webhook failed (HTTP %s) - check your url in server/sv_config.lua'):format(status))
        end
    end, 'POST', json.encode({
        username = W.BotName,
        avatar_url = W.AvatarUrl ~= '' and W.AvatarUrl or nil,
        content = content,
        embeds = embeds,
        allowed_mentions = { parse = { 'roles', 'users' } }
    }), { ['Content-Type'] = 'application/json' })
end

local pendingMention = {}

CreateThread(function()
    while true do
        Wait(2000)
        local now = GetGameTimer()
        for url, q in pairs(queues) do
            if #q > 0 and (blockedUntil[url] or 0) <= now then
                local batch = {}
                for i = 1, math.min(10, #q) do batch[i] = table.remove(q, 1) end
                send(url, batch, pendingMention[url])
                pendingMention[url] = nil
            end
        end
    end
end)

---------------------------------------------
-- player info
---------------------------------------------
local function trim(s, n)
    s = tostring(s or '')
    return #s > n and (s:sub(1, n - 3) .. '...') or s
end

function Webhook.PlayerField(src)
    if not src or src == 0 then return { name = locale('wh_f_player'), value = locale('wh_console'), inline = false } end
    local lines = {}
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then
        local ci = Player.PlayerData.charinfo or {}
        local job = Player.PlayerData.job or {}
        lines[#lines + 1] = ('**%s %s** (%s)'):format(ci.firstname or '?', ci.lastname or '', Player.PlayerData.citizenid)
        lines[#lines + 1] = locale('wh_job_line', job.name or locale('wh_none'), job.grade and job.grade.level or 0, job.onduty and (' (' .. locale('wh_onduty') .. ')') or '')
    end
    lines[#lines + 1] = locale('wh_server_id', src, GetPlayerName(src) or '?')
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if W.ShowLicense and id:find('^license:') then lines[#lines + 1] = '`' .. id .. '`'
        elseif W.ShowDiscord and id:find('^discord:') then lines[#lines + 1] = ('Discord: <@%s>'):format(id:sub(9))
        elseif W.ShowSteam and id:find('^steam:') then lines[#lines + 1] = '`' .. id .. '`'
        elseif W.ShowIp and id:find('^ip:') then lines[#lines + 1] = '||' .. id .. '||'
        end
    end
    return { name = locale('wh_f_player'), value = trim(table.concat(lines, '\n'), 1024), inline = false }
end

function Webhook.DoorField(door, id)
    if not door then return { name = locale('wh_f_door'), value = ('#%s'):format(id or '?'), inline = false } end
    local hashes = {}
    for i, d in ipairs(door.doors or {}) do hashes[i] = tostring(d.hash) end
    local c = door.textCoords
    return {
        name = locale('wh_f_door'),
        value = trim(locale('wh_door_value',
            door.name, door.id or id or '?',
            #door.jobs > 0 and ('`' .. table.concat(door.jobs, '`, `') .. '`') or ('*' .. locale('wh_none') .. '*'),
            table.concat(hashes, ', '), ('%.2f, %.2f, %.2f'):format(c.x, c.y, c.z)), 1024),
        inline = false
    }
end

---------------------------------------------
-- core
---------------------------------------------
--- @param logType string DoorUse | Denied | Admin | Security | System
--- @param data table { title, description, color, fields = {} }
function Webhook.Send(logType, data)
    if not W.Enabled or not W.Log[logType] then return end
    local url = urlFor(logType)
    if not url then return end

    local fields = {}
    for i, f in ipairs(data.fields or {}) do
        if i > 25 then break end
        fields[i] = { name = trim(f.name, 256), value = trim(f.value ~= '' and f.value or '-', 1024), inline = f.inline }
    end

    queues[url] = queues[url] or {}
    local q = queues[url]
    if #q >= 100 then table.remove(q, 1) end -- never let the queue grow unbounded
    q[#q + 1] = {
        title = trim(data.title, 256),
        description = data.description and trim(data.description, 4000) or nil,
        color = data.color or W.Colors.system,
        fields = fields,
        footer = { text = ('%s · %s'):format(W.ServerName, GetCurrentResourceName()) },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }
    if logType == 'Security' and W.SecurityMention ~= '' then pendingMention[url] = W.SecurityMention end
end

---------------------------------------------
-- helpers used by server/main.lua
---------------------------------------------
local deniedSeen = {}

function Webhook.DoorUsed(src, door, locked)
    Webhook.Send('DoorUse', {
        title = locale(locked and 'wh_locked' or 'wh_unlocked'),
        color = locked and W.Colors.locked or W.Colors.unlocked,
        fields = { Webhook.PlayerField(src), Webhook.DoorField(door) }
    })
end

function Webhook.Denied(src, door, reason, distance)
    local key = ('%s:%s'):format(src, door.id)
    local now = os.time()
    if deniedSeen[key] and now - deniedSeen[key] < W.DeniedThrottle then return end
    deniedSeen[key] = now
    local fields = { Webhook.PlayerField(src), Webhook.DoorField(door), { name = locale('wh_f_reason'), value = reason, inline = true } }
    if distance then fields[#fields + 1] = { name = locale('wh_f_distance'), value = locale('wh_distance_val', ('%.1f'):format(distance), ('%.1f'):format(door.distance)), inline = true } end
    Webhook.Send('Denied', { title = locale('wh_denied'), color = W.Colors.denied, fields = fields })
end

local securitySeen = {}
function Webhook.Security(src, what, detail)
    -- max one security log per player every 10s so a cheater can't flood the channel
    local now = os.time()
    if securitySeen[src] and now - securitySeen[src] < 10 then return end
    securitySeen[src] = now
    Webhook.Send('Security', {
        title = locale('wh_security'),
        description = what,
        color = W.Colors.security,
        fields = { Webhook.PlayerField(src), { name = locale('wh_f_details'), value = '```' .. trim(detail or '-', 1000) .. '```', inline = false } }
    })
end

local function diff(old, new)
    local out = {}
    local function j(t) return #t > 0 and table.concat(t, ', ') or locale('wh_none') end
    local function h(t) local r = {} for i, d in ipairs(t) do r[i] = tostring(d.hash) end return j(r) end
    if old.name ~= new.name then out[#out + 1] = ('%s: %s → %s'):format(locale('ui_name'), old.name, new.name) end
    if j(old.jobs) ~= j(new.jobs) then out[#out + 1] = ('%s: %s → %s'):format(locale('ui_jobs'), j(old.jobs), j(new.jobs)) end
    if old.distance ~= new.distance then out[#out + 1] = ('%s: %.2f → %.2f'):format(locale('ui_range'), old.distance, new.distance) end
    if old.locked ~= new.locked then out[#out + 1] = ('%s: %s → %s'):format(locale('ui_state'), locale(old.locked and 'ui_locked' or 'ui_unlocked'), locale(new.locked and 'ui_locked' or 'ui_unlocked')) end
    if h(old.doors) ~= h(new.doors) then out[#out + 1] = ('%s: %s → %s'):format(locale('wh_hashes'), h(old.doors), h(new.doors)) end
    return #out > 0 and table.concat(out, '\n') or locale('wh_no_changes')
end

function Webhook.AdminSaved(src, door, old)
    local fields = { Webhook.PlayerField(src), Webhook.DoorField(door) }
    if old then fields[#fields + 1] = { name = locale('wh_f_changes'), value = '```' .. diff(old, door) .. '```', inline = false } end
    Webhook.Send('Admin', {
        title = locale(old and 'wh_edited' or 'wh_created'),
        color = W.Colors.admin,
        fields = fields
    })
end

function Webhook.AdminDeleted(src, door)
    Webhook.Send('Admin', {
        title = locale('wh_deleted'),
        color = W.Colors.delete,
        fields = { Webhook.PlayerField(src), Webhook.DoorField(door) }
    })
end

function Webhook.AdminTeleport(src, door)
    Webhook.Send('Admin', {
        title = locale('wh_teleport'),
        color = W.Colors.admin,
        fields = { Webhook.PlayerField(src), Webhook.DoorField(door) }
    })
end

function Webhook.System(title, description)
    Webhook.Send('System', { title = title, description = description, color = W.Colors.system })
end

AddEventHandler('playerDropped', function()
    securitySeen[source] = nil
    local prefix = tostring(source) .. ':'
    for k in pairs(deniedSeen) do
        if k:sub(1, #prefix) == prefix then deniedSeen[k] = nil end
    end
end)
