-- Discord webhook logging for rsg-loyalty
lib.locale()

local COLORS = {
    green  = 65280,
    blue   = 3447003,
    yellow = 16776960,
    red    = 16711680,
    teal   = 5763719,
}

function IsWebhookConfigured()
    return Config.Discord.EnableWebhooks and type(Config.Discord.WebhookURL) == 'string' and Config.Discord.WebhookURL ~= ''
end

local function post(embeds, onSuccess)
    if not IsWebhookConfigured() then return end
    PerformHttpRequest(Config.Discord.WebhookURL, function(status)
        if status ~= 204 and status ~= 200 then
            print(('^3[rsg-loyalty] Discord webhook error:^7 %s'):format(tostring(status)))
        elseif onSuccess then
            onSuccess()
        end
    end, 'POST', json.encode({ embeds = embeds }), { ['Content-Type'] = 'application/json' })
end

local function field(nameKey, value, inline)
    return { name = locale(nameKey), value = tostring(value), inline = inline ~= false }
end

local function sendEmbed(title, description, color, fields, footerKey)
    post({{
        title = title,
        description = description,
        color = color,
        fields = fields,
        footer = { text = locale(footerKey or 'discord_footer_default') },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }})
end

local function enabled(event)
    return IsWebhookConfigured() and Config.Discord.LogEvents[event]
end

function LogPointsEarned(citizenid, charname, points)
    if not enabled('PointsEarned') then return end
    sendEmbed(locale('discord_title_points_earned'), locale('discord_desc_earned', points), COLORS.green, {
        field('discord_field_player', charname),
        field('discord_field_citizenid', citizenid),
        field('discord_field_points', points),
    })
end

function LogRedemptionSuccess(citizenid, charname, rewardType, rewardLabel, amount, points)
    if not enabled('RedemptionSuccess') then return end
    local isCash = rewardType == 'cash'
    sendEmbed(
        locale(isCash and 'discord_title_cash_redeemed' or 'discord_title_item_redeemed'),
        locale('discord_desc_redeemed', rewardLabel),
        COLORS.green,
        {
            field('discord_field_player', charname),
            field('discord_field_citizenid', citizenid),
            field('discord_field_reward', rewardLabel),
            field(isCash and 'discord_field_cash_amount' or 'discord_field_amount', isCash and (locale('currency_symbol') .. amount) or amount),
            field('discord_field_points_deducted', points),
        }
    )
end

function LogRedemptionFailed(citizenid, charname, rewardType, rewardLabel, reason)
    if not enabled('RedemptionFailed') then return end
    sendEmbed(locale('discord_title_redemption_failed'), locale('discord_desc_redemption_failed'), COLORS.red, {
        field('discord_field_player', charname),
        field('discord_field_citizenid', citizenid),
        field('discord_field_reward_type', rewardType:upper()),
        field('discord_field_reward', rewardLabel),
        field('discord_field_reason', reason or locale('discord_lb_unknown'), false),
    })
end

function LogAdminPointAward(adminName, targetName, points)
    if not enabled('AdminPointAward') then return end
    sendEmbed(locale('discord_title_admin_award'), locale('discord_desc_admin_award'), COLORS.yellow, {
        field('discord_field_admin', adminName),
        field('discord_field_target', targetName),
        field('discord_field_points_awarded', points),
    }, 'discord_footer_admin')
end

function LogAdminPointRemoval(adminName, targetName, points)
    if not enabled('AdminPointAward') then return end
    sendEmbed(locale('discord_title_admin_removal'), locale('discord_desc_admin_removal'), COLORS.red, {
        field('discord_field_admin', adminName),
        field('discord_field_target', targetName),
        field('discord_field_points_removed', points),
    }, 'discord_footer_admin')
end

---------------------------------------------------------------------
-- Leaderboard
---------------------------------------------------------------------
local RANK_KEYS = { 'discord_rank_first', 'discord_rank_second', 'discord_rank_third' }

local function buildLeaderboardEmbed(column, titleKey, descKey, color)
    local rows = GetLoyaltyLeaderboard(column)
    if not rows or #rows == 0 then return nil end

    local fields = {}
    for i, row in ipairs(rows) do
        local name = row.charname or locale('discord_lb_unknown')
        fields[i] = {
            name = RANK_KEYS[i] and locale(RANK_KEYS[i], name) or locale('discord_rank_other', i, name),
            value = locale('discord_lb_points', row[column]),
            inline = false,
        }
    end

    return {
        title = locale(titleKey),
        description = locale(descKey),
        color = color,
        fields = fields,
        footer = { text = locale('discord_footer_default') },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
end

function SendLeaderboardWebhook()
    if not Config.Enabled then return end
    if not IsWebhookConfigured() then return end
    local lb = Config.Discord.Leaderboard
    local embeds = {}

    if lb.ShowCurrent then
        embeds[#embeds + 1] = buildLeaderboardEmbed('loyalty_points', 'discord_lb_title_current', 'discord_lb_desc_current', COLORS.blue)
    end
    if lb.ShowLifetime then
        embeds[#embeds + 1] = buildLeaderboardEmbed('lifetime_points', 'discord_lb_title_lifetime', 'discord_lb_desc_lifetime', COLORS.teal)
    end

    if #embeds == 0 then return end
    post(embeds, function()
        print('^2[rsg-loyalty]^7 Leaderboard webhook sent.')
    end)
end

CreateThread(function()
    local lb = Config.Discord.Leaderboard
    if not Config.Enabled or not lb or not lb.Enable then return end

    local intervalMs = (lb.IntervalMinutes or 60) * 60000
    while true do
        Wait(intervalMs)
        SendLeaderboardWebhook()
    end
end)
