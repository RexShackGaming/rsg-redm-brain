-- Discord webhook logger: queued and rate limited so Discord never returns 429
lib.locale()

local Queue, Busy = {}, false
local SecSeen = {} -- [src..reason] = os.time()

local function urlFor(channel)
    local w = SvConfig.Webhooks
    local url = w[channel]
    if not url or url == '' then url = w.Default end
    return (url and url ~= '') and url or nil
end

local function playerFields(src)
    local fields = {}
    local Player = RSGCore.Functions.GetPlayer(src)
    local name = GetPlayerName(src) or locale('log_unknown')
    fields[#fields + 1] = { name = locale('log_field_player'), value = locale('log_player_value', name, src), inline = true }
    if Player then
        local ci = Player.PlayerData.charinfo or {}
        fields[#fields + 1] = { name = locale('log_field_character'), value = ('%s %s'):format(ci.firstname or '?', ci.lastname or '?'), inline = true }
        fields[#fields + 1] = { name = locale('log_field_citizenid'), value = Player.PlayerData.citizenid or '?', inline = true }
    end
    local license = RSGCore.Functions.GetIdentifier(src, 'license')
    if license then fields[#fields + 1] = { name = locale('log_field_license'), value = '`' .. license .. '`', inline = false } end
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local c = GetEntityCoords(ped)
        fields[#fields + 1] = { name = locale('log_field_coords'), value = ('`vec3(%.1f, %.1f, %.1f)`'):format(c.x, c.y, c.z), inline = false }
    end
    return fields
end

local function process()
    if Busy then return end
    Busy = true
    CreateThread(function()
        while #Queue > 0 do
            local job = table.remove(Queue, 1)
            local waitMs = 1100 -- ~1 msg/sec keeps us under Discord's per-webhook limit
            local done = false
            PerformHttpRequest(job.url, function(status, _, headers)
                if status == 429 then
                    table.insert(Queue, 1, job) -- retry after backoff
                    waitMs = 5000
                elseif status ~= 200 and status ~= 204 then
                    print('^1' .. locale('log_webhook_failed', status) .. '^7')
                end
                done = true
            end, 'POST', json.encode(job.payload), { ['Content-Type'] = 'application/json' })
            local t = GetGameTimer() + 10000
            while not done and GetGameTimer() < t do Wait(50) end
            Wait(waitMs)
        end
        Busy = false
    end)
end

--- Send an embed. channel = 'Ambush' | 'Loot' | 'Security'
function SendLog(channel, title, colour, src, description, extraFields)
    if not SvConfig.Webhooks.Enabled then return end
    local url = urlFor(channel)
    if not url then return end

    local fields = src and playerFields(src) or {}
    for _, f in ipairs(extraFields or {}) do fields[#fields + 1] = f end

    Queue[#Queue + 1] = {
        url = url,
        payload = {
            username = SvConfig.Webhooks.Name,
            avatar_url = SvConfig.Webhooks.Avatar ~= '' and SvConfig.Webhooks.Avatar or nil,
            embeds = { {
                title = title,
                description = description,
                color = colour,
                fields = fields,
                footer = { text = SvConfig.Webhooks.Footer },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            } },
        },
    }
    process()
end

--- Security alert, throttled per player + reason
function SecurityLog(src, reason, details)
    if not SvConfig.Log.Security then return end
    local key = ('%s:%s'):format(src, reason)
    local now = os.time()
    if SecSeen[key] and now - SecSeen[key] < SvConfig.SecurityThrottle then return end
    SecSeen[key] = now
    SendLog('Security', locale('log_security_title'), SvConfig.Colours.security, src, reason,
        details and { { name = locale('log_field_details'), value = details, inline = false } } or nil)
end

AddEventHandler('playerDropped', function()
    local prefix = tostring(source) .. ':'
    for k in pairs(SecSeen) do
        if k:sub(1, #prefix) == prefix then SecSeen[k] = nil end
    end
end)
