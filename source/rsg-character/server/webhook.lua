
RSGCore = RSGCore or exports['rsg-core']:GetCoreObject()

local queue = {}
local sending = false

local function processQueue()
    if sending or #queue == 0 then return end
    sending = true

    local job = table.remove(queue, 1)
    PerformHttpRequest(job.url, function(statusCode, _, headers)
        if statusCode == 429 and headers and headers['Retry-After'] then
            local retryAfter = tonumber(headers['Retry-After']) or 1
            table.insert(queue, 1, job)
            SetTimeout(math.floor((retryAfter * 1000) + 250), function()
                sending = false
                processQueue()
            end)
            return
        end

        if statusCode ~= 200 and statusCode ~= 204 then
            print(('[rsg-character:webhook] Discord returned status %s for a "%s" webhook'):format(tostring(statusCode), job.category))
        end

        sending = false
        processQueue()
    end, 'POST', json.encode(job.payload), { ['Content-Type'] = 'application/json' })
end

local warnedCategories = {}

function RSG.SendWebhook(category, embed)
    local cfg = RSG.Webhooks and RSG.Webhooks[category]
    if not cfg or not cfg.enabled then return end

    if not cfg.url or cfg.url == '' or cfg.url:find('discord.com/api/webhooks/XXXXXXXX') then
        if not warnedCategories[category] then
            warnedCategories[category] = true
            print(('[rsg-character:webhook] Category "%s" is enabled but has no webhook URL configured in config.lua - skipping (this warning will not repeat).'):format(category))
        end
        return
    end

    embed = embed or {}
    embed.color = embed.color or cfg.color or 3447003
    embed.timestamp = embed.timestamp or os.date('!%Y-%m-%dT%H:%M:%SZ')
    embed.footer = embed.footer or { text = ('rsg-character \226\128\162 %s'):format(category) }

    local payload = {
        username = cfg.name or locale('webhooks.common.username'),
        avatar_url = (cfg.avatar and cfg.avatar ~= '') and cfg.avatar or nil,
        embeds = { embed },
    }

    table.insert(queue, { url = cfg.url, payload = payload, category = category })
    processQueue()
end

function RSG.WebhookIdentityFields(_source)
    local discordId = RSGCore.Functions.GetIdentifier(_source, 'discord')
    local discordValue = locale('webhooks.common.na')
    if discordId then
        local rawId = discordId:gsub('discord:', '')
        discordValue = ('<@%s> (`%s`)'):format(rawId, rawId)
    end

    return {
        { name = locale('webhooks.common.player_field'), value = ('%s (Server ID: `%s`)'):format(GetPlayerName(_source) or locale('webhooks.common.unknown'), _source), inline = false },
        { name = locale('webhooks.common.discord_field'), value = discordValue, inline = false },
    }
end
