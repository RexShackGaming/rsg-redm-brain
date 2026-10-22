local RSGCore = exports['rsg-core']:GetCoreObject()
local cfg = WebhookConfig
lib.locale()

-----------------------------------------------------------------------
-- queue: Discord allows ~30 requests/min per webhook, so send one at a time
-----------------------------------------------------------------------
local queue, sending = {}, false

local function processQueue()
    if sending then return end
    sending = true
    CreateThread(function()
        while #queue > 0 do
            local job = table.remove(queue, 1)
            local p = promise.new()
            PerformHttpRequest(job.url, function(status, _, headers)
                if status == 429 then
                    local retry = tonumber(headers and (headers['retry-after'] or headers['Retry-After'])) or 2
                    table.insert(queue, 1, job)
                    SetTimeout(math.ceil(retry * 1000), function() p:resolve() end)
                    return
                elseif status < 200 or status >= 300 then
                    print(('^1[rsg-looting] webhook failed (%s)^7'):format(status))
                end
                p:resolve()
            end, 'POST', job.body, { ['Content-Type'] = 'application/json' })
            Citizen.Await(p)
            Wait(250)
        end
        sending = false
    end)
end

-----------------------------------------------------------------------
-- helpers
-----------------------------------------------------------------------
local function playerField(src, label)
    local Player = RSGCore.Functions.GetPlayer(src)
    local lines = {}
    if Player then
        local c = Player.PlayerData.charinfo
        lines[#lines + 1] = ('**%s %s** (%s)'):format(c.firstname, c.lastname, Player.PlayerData.citizenid)
    end
    lines[#lines + 1] = ('%s [ID %s]'):format(GetPlayerName(src) or locale('wh_unknown'), src)

    if cfg.ShowIdentifiers then
        local license = GetPlayerIdentifierByType(src, 'license')
        local discord = GetPlayerIdentifierByType(src, 'discord')
        if license then lines[#lines + 1] = '`' .. license .. '`' end
        if discord then lines[#lines + 1] = ('<@%s>'):format(discord:gsub('discord:', '')) end
    end
    return { name = label, value = table.concat(lines, '\n'), inline = true }
end

local function coordsField(src)
    local c = GetEntityCoords(GetPlayerPed(src))
    return { name = locale('wh_field_location'), value = ('`%.1f, %.1f, %.1f`'):format(c.x, c.y, c.z), inline = false }
end

---@param channel 'loot'|'rob'|'exploit'
---@param embed table discord embed (title, description, color, fields)
local function send(channel, embed)
    if not cfg.Enabled then return end
    local url = cfg.Webhooks[channel]
    if not url or url == '' then return end

    embed.timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    embed.footer = { text = cfg.Footer }

    queue[#queue + 1] = {
        url = url,
        body = json.encode({
            username = cfg.BotName,
            avatar_url = cfg.AvatarUrl ~= '' and cfg.AvatarUrl or nil,
            embeds = { embed },
        }),
    }
    processQueue()
end

-----------------------------------------------------------------------
-- public API (used by server.lua, also usable by other resources)
-----------------------------------------------------------------------
Webhooks = {}

function Webhooks.Loot(src, itemLabel, amount, cash, rare)
    if not rare and not cfg.LogCommonLoot then return end
    send('loot', {
        title = locale(rare and 'wh_loot_rare_title' or 'wh_loot_title'),
        color = rare and cfg.Colors.rare or cfg.Colors.common,
        fields = {
            playerField(src, locale('wh_field_player')),
            { name = locale('wh_field_reward'), value = locale('wh_reward_value', amount, itemLabel or locale('wh_none'), cash), inline = true },
            coordsField(src),
        },
    })
end

function Webhooks.Rob(src, targetId, reason, cash, bloodmoney)
    send('rob', {
        title = locale('wh_rob_title'),
        description = locale('wh_rob_desc', reason),
        color = cfg.Colors.rob,
        fields = {
            playerField(src, locale('wh_field_robber')),
            playerField(targetId, locale('wh_field_victim')),
            { name = locale('wh_field_taken'), value = locale('wh_taken_value', cash or 0, bloodmoney or 0), inline = false },
            coordsField(src),
        },
    })
end

function Webhooks.Exploit(src, event, reason)
    send('exploit', {
        title = locale('wh_exploit_title'),
        description = locale('wh_exploit_desc', event, reason),
        color = cfg.Colors.exploit,
        fields = { playerField(src, locale('wh_field_player')), coordsField(src) },
    })
end

exports('SendWebhook', send)
