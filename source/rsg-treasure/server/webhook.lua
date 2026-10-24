-- Discord webhook logging (queued so bursts never hit Discord's rate limit)
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()
local W = SvConfig.Webhooks
local queue = {}
local running = false

local function urlFor(channel)
    local url = W[channel]
    if not url or url == '' then url = W.Default end
    return url ~= '' and url or nil
end

local function process()
    running = true
    while #queue > 0 do
        local job = table.remove(queue, 1)
        PerformHttpRequest(job.url, function(code, _, headers)
            if code == 429 then -- rate limited: put it back and back off
                table.insert(queue, 1, job)
                local retry = headers and tonumber(headers['retry-after'] or headers['Retry-After'])
                CreateThread(function() -- never Wait() inside an HTTP callback
                    Wait(math.floor((retry or 2) * 1000))
                    if not running then process() end
                end)
            elseif code < 200 or code >= 300 then
                print(('^1[rsg-treasure] webhook failed (%s)^7'):format(code))
            end
        end, 'POST', json.encode(job.payload), { ['Content-Type'] = 'application/json' })
        Wait(W.QueueDelay)
    end
    running = false
end

local function playerFields(src)
    local fields = {}
    local Player = src and RSGCore.Functions.GetPlayer(src)
    if Player then
        local ci = Player.PlayerData.charinfo or {}
        fields[#fields + 1] = { name = locale('log_character'), value = ('%s %s'):format(ci.firstname or '?', ci.lastname or '?'), inline = true }
        fields[#fields + 1] = { name = locale('log_citizenid'), value = Player.PlayerData.citizenid, inline = true }
    end
    if src then
        fields[#fields + 1] = { name = locale('log_player'), value = locale('log_player_value', GetPlayerName(src) or '?', src), inline = true }
        local ids = {}
        for _, id in ipairs(GetPlayerIdentifiers(src)) do
            if id:find('^license:') or id:find('^discord:') then
                ids[#ids + 1] = id:find('^discord:') and ('<@%s>'):format(id:sub(9)) or id
            end
        end
        if #ids > 0 then fields[#fields + 1] = { name = locale('log_identifiers'), value = table.concat(ids, '\n') } end
    end
    return fields
end

---@param channel 'Hunts'|'Rewards'|'Security'
---@param title string
---@param description string
---@param color string key of W.Colors
---@param src? number player source to attach details for
---@param extra? table extra embed fields { {name=, value=, inline=} }
function SendLog(channel, title, description, color, src, extra)
    if not W.Enabled then return end
    local url = urlFor(channel)
    if not url then return end

    local fields = playerFields(src)
    for _, f in ipairs(extra or {}) do fields[#fields + 1] = f end

    queue[#queue + 1] = {
        url = url,
        payload = {
            username = W.Name,
            avatar_url = W.Avatar ~= '' and W.Avatar or nil,
            content = (color == 'alert' and W.MentionOnAlert ~= '') and W.MentionOnAlert or nil,
            embeds = { {
                title = title,
                description = description,
                color = W.Colors[color] or W.Colors.hunt,
                fields = fields,
                footer = { text = W.Footer },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            } },
        },
    }
    if not running then CreateThread(process) end
end

exports('SendLog', SendLog)
