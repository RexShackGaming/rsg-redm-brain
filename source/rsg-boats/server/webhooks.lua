---------------------------------------------------------------------
-- Discord webhooks
-- Usage (server): BoatLog(event, src, title, fields, description)
--   event  = key in SvConfig.Webhooks.events
--   src    = player server id (or nil for system messages)
--   fields = { { 'Name', 'value' }, ... } (inline) or { name =, value =, inline = }
---------------------------------------------------------------------
local RSGCore = exports['rsg-core']:GetCoreObject()
local W = SvConfig.Webhooks

local queue, sending = {}, false
local resetAt = 0 -- os.time() until which Discord asked us to wait (429)

local function trim(s, max)
    s = tostring(s == nil and '-' or s)
    if s == '' then s = '-' end
    return #s > max and (s:sub(1, max - 3) .. '...') or s
end

local function playerFields(src)
    if not src then return {} end
    local out = {}
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then
        local ci = Player.PlayerData.charinfo or {}
        out[#out + 1] = { name = locale('wh_f_character'), value = trim(('%s %s'):format(ci.firstname or '?', ci.lastname or '?'), 256), inline = true }
        out[#out + 1] = { name = locale('wh_f_citizenid'), value = trim(Player.PlayerData.citizenid, 256), inline = true }
    end
    out[#out + 1] = { name = locale('wh_f_player'), value = trim(locale('wh_player_value', GetPlayerName(src) or '?', src), 256), inline = true }
    if W.showIdentifiers then
        local ids = {}
        for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
            local kind = id:match('^(%w+):')
            if kind == 'license' then ids[#ids + 1] = id
            elseif kind == 'discord' then ids[#ids + 1] = ('<@%s>'):format(id:sub(9)) end
        end
        if #ids > 0 then out[#out + 1] = { name = locale('wh_f_identifiers'), value = trim(table.concat(ids, '\n'), 1024), inline = false } end
    end
    return out
end

local function processQueue()
    if sending then return end
    sending = true
    CreateThread(function()
        while #queue > 0 do
            local wait = resetAt - os.time()
            if wait > 0 then Wait(wait * 1000) end
            local job = table.remove(queue, 1)
            local p = promise.new()
            PerformHttpRequest(job.url, function(status, _, headers)
                if status == 429 then
                    -- rate limited: put it back and wait as long as Discord says
                    local after = tonumber(headers and (headers['Retry-After'] or headers['retry-after'])) or 2
                    resetAt = os.time() + math.ceil(after)
                    table.insert(queue, 1, job)
                elseif status < 200 or status >= 300 then
                    print(('^1[rsg-boats]^7 webhook failed (%s) for event %s'):format(status, job.event))
                end
                p:resolve()
            end, 'POST', json.encode(job.body), { ['Content-Type'] = 'application/json' })
            Citizen.Await(p)
            Wait(500) -- stay well under 5 requests / 2 seconds per webhook
        end
        sending = false
    end)
end

function BoatLog(event, src, title, fields, description)
    if not W or not W.enabled then return end
    local ev = W.events[event]
    if not ev or not ev.enabled then return end
    local url = (ev.url ~= '' and ev.url) or W.default
    if not url or url == '' then return end

    local list = {}
    for _, f in ipairs(fields or {}) do
        if f.name then
            list[#list + 1] = { name = trim(f.name, 256), value = trim(f.value, 1024), inline = f.inline ~= false }
        else
            list[#list + 1] = { name = trim(f[1], 256), value = trim(f[2], 1024), inline = f[3] ~= false }
        end
    end
    for _, f in ipairs(playerFields(src)) do list[#list + 1] = f end
    while #list > 25 do table.remove(list) end -- Discord embed limit

    local body = {
        username = W.username,
        avatar_url = W.avatar ~= '' and W.avatar or nil,
        content = (event == 'exploit' and W.mentionOnExploit ~= '') and W.mentionOnExploit or nil,
        embeds = { {
            title = trim(title, 256),
            description = description and trim(description, 4000) or nil,
            color = ev.color,
            fields = list,
            footer = { text = ('%s • %s'):format(W.footer, GetCurrentResourceName()) },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    }
    queue[#queue + 1] = { url = url, body = body, event = event }
    processQueue()
end

-- quick test from the server console: boatwebhooktest
RegisterCommand('boatwebhooktest', function(src)
    if src ~= 0 then return end
    for event in pairs(W.events) do
        BoatLog(event, nil, locale('wh_test_title', event), { { locale('wh_f_event'), event } }, locale('wh_test_desc'))
    end
    print('^2[rsg-boats]^7 webhook test queued for every enabled event')
end, true)
