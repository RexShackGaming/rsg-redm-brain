-- Discord webhook system for rsg-bountyhunter (server only)
-- Usage from server.lua: BountyLog.Event(eventName, src, fields, extraDescription)

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()
local W = SvConfig.Webhooks

BountyLog = {}

local EVENT_CATEGORY = {
    accepted = 'contracts', abandoned = 'contracts', expired = 'contracts', failed = 'contracts',
    completed = 'payouts',
    exploit = 'exploits',
    started = 'system', boardRefresh = 'system', test = 'system',
}

-- embed titles are locale keys
local EVENT_TITLE = {
    accepted = 'wh_title_accepted', abandoned = 'wh_title_abandoned', expired = 'wh_title_expired',
    failed = 'wh_title_failed', completed = 'wh_title_completed', exploit = 'wh_title_exploit',
    started = 'wh_title_started', boardRefresh = 'wh_title_board', test = 'wh_title_test',
}

local function title(event)
    return EVENT_TITLE[event] and locale(EVENT_TITLE[event]) or event
end

---------------------------------
-- rate-limited queue (one queue per url, honours Discord 429 retry_after)
---------------------------------
local queues = {}   -- [url] = { items = {}, busyUntil = ms }

local function sendNow(url, payload, q)
    PerformHttpRequest(url, function(status, result, _, errorData)
        local body = result or errorData
        if status == 429 then
            local retry = 2000
            local ok, data = pcall(json.decode, body or '')
            if ok and type(data) == 'table' and tonumber(data.retry_after) then
                retry = math.ceil(tonumber(data.retry_after) * 1000) + 250 -- retry_after is in seconds
            end
            table.insert(q.items, 1, payload) -- put it back at the front
            q.busyUntil = GetGameTimer() + retry
        elseif status < 200 or status >= 300 then
            print(('^1[rsg-bountyhunter] webhook failed (%s): %s^7'):format(status, tostring(body)))
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

CreateThread(function()
    while true do
        local now = GetGameTimer()
        for url, q in pairs(queues) do
            if #q.items > 0 and now >= q.busyUntil then
                local payload = table.remove(q.items, 1)
                q.busyUntil = now + 1200 -- ~50/min max, under Discord's limit
                sendNow(url, payload, q)
            end
        end
        Wait(250)
    end
end)

local function enqueue(url, payload)
    local q = queues[url]
    if not q then
        q = { items = {}, busyUntil = 0 }
        queues[url] = q
    end
    if #q.items >= 100 then table.remove(q.items, 1) end -- never grow unbounded
    q.items[#q.items + 1] = payload
end

---------------------------------
-- player info
---------------------------------
local function playerFields(src)
    local fields = {}
    if not src or src <= 0 then return fields end

    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then
        local ci = Player.PlayerData.charinfo
        fields[#fields + 1] = { name = locale('wh_character'), value = ('%s %s'):format(ci.firstname, ci.lastname), inline = true }
        fields[#fields + 1] = { name = locale('wh_citizenid'), value = Player.PlayerData.citizenid, inline = true }
        fields[#fields + 1] = { name = locale('wh_job'), value = Player.PlayerData.job and Player.PlayerData.job.label or locale('wh_none'), inline = true }
    end
    fields[#fields + 1] = { name = locale('wh_player'), value = ('%s (ID %s)'):format(GetPlayerName(src) or '?', src), inline = true }

    if W.ShowIdentifiers then
        local license = GetPlayerIdentifierByType(src, 'license')
        local discord = GetPlayerIdentifierByType(src, 'discord')
        if license then fields[#fields + 1] = { name = locale('wh_license'), value = ('`%s`'):format(license), inline = false } end
        if discord then fields[#fields + 1] = { name = locale('wh_discord'), value = ('<@%s>'):format(discord:gsub('discord:', '')), inline = true } end
    end

    if W.ShowCoords then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local c = GetEntityCoords(ped)
            fields[#fields + 1] = { name = locale('wh_coords'), value = ('`%.1f, %.1f, %.1f`'):format(c.x, c.y, c.z), inline = true }
        end
    end
    return fields
end

---------------------------------
-- public API
---------------------------------
--- @param event string key from EVENT_CATEGORY
--- @param src number|nil player source (nil for system events)
--- @param fields table|nil extra { name, value, inline } fields
--- @param description string|nil
function BountyLog.Event(event, src, fields, description)
    if W.UseRsgLog then
        TriggerEvent('rsg-log:server:CreateLog', W.RsgLogChannel, title(event),
            event == 'exploit' and 'red' or 'green', description or '')
    end

    if not W.Enabled or (W.Events[event] == false and event ~= 'test') then return end
    local url = W.Urls[EVENT_CATEGORY[event] or 'system']
    if not url or url == '' then return end

    local all = {}
    for _, f in ipairs(fields or {}) do
        all[#all + 1] = { name = tostring(f.name), value = tostring(f.value):sub(1, 1024), inline = f.inline ~= false }
    end
    for _, f in ipairs(playerFields(src)) do all[#all + 1] = f end
    while #all > 25 do table.remove(all) end -- Discord embed field limit

    local payload = {
        username = W.BotName,
        avatar_url = W.AvatarUrl ~= '' and W.AvatarUrl or nil,
        content = (event == 'exploit' and W.PingOnExploit ~= '') and W.PingOnExploit or nil,
        embeds = { {
            author = { name = W.ServerName },
            title = title(event),
            description = description and description:sub(1, 4000) or nil,
            color = W.Colors[event] or W.Colors.system,
            fields = all,
            footer = { text = W.FooterText },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    }
    enqueue(url, payload)
end

-- helper for the common contract fields
function BountyLog.ContractFields(poster, extra)
    local f = {
        { name = locale('wh_target'), value = poster.name },
        { name = locale('wh_tier'), value = locale(Config.Tiers[poster.tier].label) },
        { name = locale('wh_crime'), value = locale(poster.crime) },
        { name = locale('wh_reward'), value = locale('wh_reward_value', poster.rewardAlive, poster.rewardDead) },
    }
    for _, e in ipairs(extra or {}) do f[#f + 1] = e end
    return f
end

---------------------------------
-- admin test command
---------------------------------
if W.TestCommand then
    RSGCore.Commands.Add(W.TestCommand, locale('cmd_webhook_test'), {}, false, function(source)
        local sent = 0
        for category, url in pairs(W.Urls) do
            if url ~= '' then
                enqueue(url, {
                    username = W.BotName,
                    avatar_url = W.AvatarUrl ~= '' and W.AvatarUrl or nil,
                    embeds = { {
                        title = title('test'),
                        description = locale('wh_test_desc', category),
                        color = W.Colors.system,
                        footer = { text = W.FooterText },
                        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
                    } },
                })
                sent = sent + 1
            end
        end
        TriggerClientEvent('ox_lib:notify', source, { title = locale('title'), description = locale('webhook_test_sent', sent), type = sent > 0 and 'success' or 'error' })
    end, 'admin')
end

CreateThread(function()
    Wait(2000)
    BountyLog.Event('started', nil, nil, locale('wh_started_desc', #Config.Offices, #Config.Hideouts))
end)
