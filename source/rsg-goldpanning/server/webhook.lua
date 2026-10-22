-----------------------------------------------------------------------
-- Discord webhook logging for rsg-goldpanning
-- Loaded before server.lua (see fxmanifest.lua) — functions below are
-- declared as globals so server.lua can call them directly.
-----------------------------------------------------------------------
lib.locale()

-- internal: fire a single embed at the given webhook url
local function PostToDiscord(url, embed)
    if not Config.Webhooks.enabled then return end
    if not url or url == '' then return end -- category disabled

    local payload = {
        username = Config.Webhooks.botName or locale('wh_bot_name'),
        embeds   = { embed }
    }

    if Config.Webhooks.botAvatar and Config.Webhooks.botAvatar ~= '' then
        payload.avatar_url = Config.Webhooks.botAvatar
    end

    PerformHttpRequest(url, function(statusCode, _, _)
        if statusCode ~= 200 and statusCode ~= 204 then
            print(('^1[rsg-goldpanning] Webhook post failed (HTTP %s)^0'):format(tostring(statusCode)))
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

-- internal: standard footer/timestamp used on every embed
local function BaseEmbed(title, color)
    return {
        title     = title,
        color     = color,
        footer    = { text = locale('wh_footer') },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        fields    = {}
    }
end

---Posts a successful gold-find to the rewards webhook.
---@param tier 'small'|'medium'|'large'
---@param playerName string        -- Discord/Rockstar display name (GetPlayerName)
---@param charName string          -- in-game character name
---@param citizenid string
---@param itemLabel string
---@param amount number
---@param coords vector3
function SendGoldPanRewardWebhook(tier, playerName, charName, citizenid, itemLabel, amount, coords)
    local titles = {
        small  = locale('wh_title_small'),
        medium = locale('wh_title_medium'),
        large  = locale('wh_title_large'),
    }

    local embed = BaseEmbed(titles[tier] or titles.small, Config.WebhookColors[tier] or Config.WebhookColors.small)
    embed.fields = {
        { name = locale('wh_player'), value = locale('wh_player_char', charName, playerName), inline = true },
        { name = locale('wh_citizenid'), value = citizenid, inline = true },
        { name = locale('wh_reward'), value = locale('wh_reward_value', amount, itemLabel), inline = true },
    }

    if coords then
        embed.description = locale('wh_location', coords.x, coords.y, coords.z)
    end

    PostToDiscord(Config.Webhooks.rewards, embed)
end

---Posts a suspicious / rejected reward claim to the exploits webhook.
---@param reason string      -- short reason label
---@param playerName string
---@param src number
---@param details string|nil -- optional extra context (e.g. elapsed time)
function SendGoldPanExploitWebhook(reason, playerName, src, details)
    local embed = BaseEmbed(locale('wh_title_exploit'), Config.WebhookColors.exploit)
    embed.fields = {
        { name = locale('wh_player'), value = locale('wh_player_id', playerName, src), inline = true },
        { name = locale('wh_reason'), value = reason, inline = true },
    }

    if details then
        embed.fields[#embed.fields + 1] = { name = locale('wh_details'), value = details, inline = false }
    end

    PostToDiscord(Config.Webhooks.exploits, embed)
end
