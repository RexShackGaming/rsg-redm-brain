-- Discord webhook logger for rsg-legendary (server only)
local RSGCore = exports['rsg-core']:GetCoreObject()
local W = SvConfig.Webhooks

-- event -> { channel, color, title locale key }
local EVENTS = {
    map_bought   = { 'Shop', 'info',    'log_t_map_bought' },
    sold         = { 'Shop', 'success', 'log_t_sold' },
    hunt_started = { 'Hunt', 'info',    'log_t_hunt_started' },
    clue_found   = { 'Hunt', 'info',    'log_t_clue_found' },
    animal_spawn = { 'Hunt', 'warning', 'log_t_animal_spawn' },
    abandoned    = { 'Hunt', 'warning', 'log_t_abandoned' },
    expired      = { 'Hunt', 'warning', 'log_t_expired' },
    skinned      = { 'Kill', 'success', 'log_t_skinned' },
    admin        = { 'Admin', 'admin',  'log_t_admin' },
    suspicious   = { 'Suspicious', 'danger', 'log_t_suspicious' },
}

local queue, sending = {}, false

local function urlFor(channel)
    local u = W.Urls[channel]
    if u and u ~= '' then return u end
    if W.Urls.Default ~= '' then return W.Urls.Default end
end

local function processQueue()
    if sending then return end
    sending = true
    CreateThread(function()
        while #queue > 0 do
            local job = table.remove(queue, 1)
            PerformHttpRequest(job.url, function(code, _, headers)
                if code == 429 then   -- rate limited: put it back and wait
                    table.insert(queue, 1, job)
                elseif code < 200 or code >= 300 then
                    print(('^1[rsg-legendary]^7 webhook failed (%s)'):format(tostring(code)))
                end
            end, 'POST', job.body, { ['Content-Type'] = 'application/json' })
            Wait(W.QueueDelay)
        end
        sending = false
    end)
end

local function playerFields(src)
    if not src or src <= 0 then return {} end
    local Player = RSGCore.Functions.GetPlayer(src)
    local ci = Player and Player.PlayerData.charinfo
    local discord = GetPlayerIdentifierByType(src, 'discord')
    local fields = {
        { name = locale('log_f_player'), value = ('%s (ID %d)'):format(GetPlayerName(src) or locale('log_unknown'), src), inline = true },
        { name = locale('log_f_character'), value = ci and ('%s %s'):format(ci.firstname, ci.lastname) or locale('log_unknown'), inline = true },
        { name = locale('log_f_citizenid'), value = Player and Player.PlayerData.citizenid or locale('log_unknown'), inline = true },
        { name = 'Discord', value = discord and ('<@%s>'):format((discord:gsub('discord:', ''))) or locale('log_not_linked'), inline = true },
        { name = locale('log_f_license'), value = GetPlayerIdentifierByType(src, 'license') or locale('log_unknown'), inline = false },
    }
    if W.ShowCoords then
        local c = GetEntityCoords(GetPlayerPed(src))
        fields[#fields + 1] = { name = locale('log_f_coords'), value = ('vector3(%.2f, %.2f, %.2f)'):format(c.x, c.y, c.z), inline = false }
    end
    return fields
end

--- Log an event to Discord.
--- @param event string key from EVENTS
--- @param src number|nil player source
--- @param description string
--- @param extra table|nil extra embed fields { {name=, value=, inline=} }
function LegendaryLog(event, src, description, extra)
    if not W.Enabled or not W.Events[event] then return end
    local def = EVENTS[event]
    if not def then return end
    local url = urlFor(def[1])
    if not url then return end

    local fields = {}
    for _, f in ipairs(extra or {}) do fields[#fields + 1] = { name = f.name, value = tostring(f.value), inline = f.inline ~= false } end
    for _, f in ipairs(playerFields(src)) do fields[#fields + 1] = f end

    local content
    if event == 'suspicious' and W.SuspiciousRoleId ~= '' then content = ('<@&%s>'):format(W.SuspiciousRoleId) end

    queue[#queue + 1] = { url = url, body = json.encode({
        username = W.BotName,
        avatar_url = W.AvatarUrl ~= '' and W.AvatarUrl or nil,
        content = content,
        embeds = { {
            title = locale(def[3]),
            description = description,
            color = W.Colors[def[2]],
            fields = fields,
            footer = { text = W.Footer },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    }) }
    processQueue()
end
