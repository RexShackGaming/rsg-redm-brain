----------------------------------------------------------------------------
-- Discord webhook logging engine
--
-- Everything here is passive infrastructure: it builds embeds and queues
-- them off to Discord, and never touches gameplay state itself (no items,
-- no money, no inventory). server/server.lua and server/mysterybox.lua call
-- into the Webhook.* functions below at the points where something
-- log-worthy already happened (or was rejected) - this file just decides
-- whether/where to report it, per Config.Webhook.
--
-- Loaded first in server_scripts (see fxmanifest.lua) so every other server
-- file, including versionchecker.lua's synchronous CheckVersion() call at
-- load time, can rely on the Webhook global already existing.
----------------------------------------------------------------------------

Webhook = {}

local RSGCore = exports['rsg-core']:GetCoreObject()
local cfg = Config.Webhook

local function Debug(msg)
    if Config.Debug then
        print('[rsg-herbalist:webhook] ' .. msg)
    end
end

----------------------------------------------------------------------------
-- Queue + delivery
--
-- One shared FIFO queue for every category rather than one per category -
-- simpler, and since categories normally point at different channels
-- anyway, Discord's per-webhook-URL rate limit is naturally spread across
-- them regardless of how the queue itself is ordered.
----------------------------------------------------------------------------

local queue = {}
local draining = false

local function EnqueueRaw(url, payload, attempt)
    queue[#queue + 1] = { url = url, payload = payload, attempt = attempt or 1 }
end

local function DrainQueue()
    if draining then return end
    draining = true
    CreateThread(function()
        while #queue > 0 do
            local job = table.remove(queue, 1)
            PerformHttpRequest(job.url, function(statusCode, response, headers)
                if statusCode == 200 or statusCode == 204 then
                    return
                end

                if statusCode == 429 then
                    -- Rate-limited: Discord tells us how long to back off for.
                    -- Re-queue the same job after that delay rather than
                    -- dropping it, up to maxRetries.
                    local retryAfterMs = 1000
                    local ok, decoded = pcall(json.decode, response)
                    if ok and decoded and decoded.retry_after then
                        retryAfterMs = math.floor(decoded.retry_after * 1000) + 50
                    end
                    if job.attempt < (cfg.maxRetries or 3) then
                        Debug(('rate limited, retrying in %dms (attempt %d)'):format(retryAfterMs, job.attempt))
                        SetTimeout(retryAfterMs, function()
                            EnqueueRaw(job.url, job.payload, job.attempt + 1)
                            DrainQueue()
                        end)
                    else
                        Debug('rate limited, giving up after ' .. job.attempt .. ' attempts')
                    end
                    return
                end

                Debug(('webhook post failed, status=%s response=%s'):format(tostring(statusCode), tostring(response)))
            end, 'POST', json.encode(job.payload), { ['Content-Type'] = 'application/json' })

            Wait(cfg.queueIntervalMs or 350)
        end
        draining = false
    end)
end

local function Enqueue(url, payload)
    EnqueueRaw(url, payload)
    DrainQueue()
end

----------------------------------------------------------------------------
-- Embed helpers
----------------------------------------------------------------------------

local COLORS = {
    craft = 3066993,      -- green
    mysterybox = 15844367, -- gold
    anticheat = 15158332,  -- red
    gather = 5763719,      -- light green
    resource = 3447003,    -- blurple
    version = 10181046,    -- purple
}

local function BuildEmbed(title, description, color, fields)
    return {
        title = title,
        description = description,
        color = color,
        fields = fields,
        footer = { text = 'rsg-herbalist' },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
end

local function AddField(fields, name, value, inline)
    fields[#fields + 1] = { name = name, value = tostring(value), inline = inline ~= false }
end

-- Resolves everything an embed might want to show about a player: character
-- name/citizenid (best-effort - falls back to the source id if the player
-- object or PlayerData isn't available, e.g. a very early-connection edge
-- case), plus a Discord mention if configured and available.
local function GetPlayerInfo(src)
    local info = { citizenid = 'n/a', charName = ('src %s'):format(src), discordMention = nil }

    local Player = RSGCore.Functions.GetPlayer(src)
    if Player and Player.PlayerData then
        info.citizenid = Player.PlayerData.citizenid or info.citizenid
        local charinfo = Player.PlayerData.charinfo
        if charinfo then
            info.charName = ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
            if info.charName == '' then info.charName = ('src %s'):format(src) end
        end
    end

    if cfg.identifiers and cfg.identifiers.showDiscord then
        local discordId = GetPlayerIdentifierByType(src, 'discord')
        if discordId then
            info.discordMention = ('<@%s>'):format(discordId:gsub('^discord:', ''))
        end
    end

    return info
end

local function PlayerFieldValue(src)
    local info = GetPlayerInfo(src)
    local lines = {
        ('**%s**'):format(info.charName),
        ('citizenid: `%s`'):format(info.citizenid),
        ('server id: `%s`'):format(src),
    }
    if info.discordMention then lines[#lines + 1] = info.discordMention end

    if cfg.identifiers then
        if cfg.identifiers.showSteam then
            local steam = GetPlayerIdentifierByType(src, 'steam')
            if steam then lines[#lines + 1] = ('steam: `%s`'):format(steam) end
        end
        if cfg.identifiers.showLicense then
            local license = GetPlayerIdentifierByType(src, 'license')
            if license then lines[#lines + 1] = ('license: `%s`'):format(license) end
        end
    end

    return table.concat(lines, '\n')
end

-- Central gate every Webhook.Log* function goes through: master switch,
-- per-category switch, and a configured (non-blank) URL. Anything failing
-- this check is a silent no-op, by design - a blank Config.Webhook doesn't
-- spam the console on every gather/craft.
local function CategoryTarget(category)
    if not cfg.enabled then return nil end
    local c = cfg.categories and cfg.categories[category]
    if not c or not c.enabled then return nil end
    if not c.url or c.url == '' then return nil end
    return c
end

local function Send(category, embed, content)
    local target = CategoryTarget(category)
    if not target then return end

    Enqueue(target.url, {
        username = cfg.botName,
        avatar_url = (cfg.botAvatar ~= '' and cfg.botAvatar) or nil,
        content = content,
        embeds = { embed },
    })
end

----------------------------------------------------------------------------
-- Public logging functions - called from server/server.lua,
-- server/mysterybox.lua and server/versionchecker.lua.
----------------------------------------------------------------------------

function Webhook.LogGather(src, itemLabel, coordKey)
    local fields = {}
    AddField(fields, 'Player', PlayerFieldValue(src), false)
    AddField(fields, 'Item', itemLabel)
    AddField(fields, 'Node', coordKey)
    Send('gather', BuildEmbed('Herb gathered', nil, COLORS.gather, fields))
end

function Webhook.LogCraft(src, tonic, outcome)
    local title = outcome == 'success' and 'Tonic crafted' or 'Tonic craft refunded'
    local fields = {}
    AddField(fields, 'Player', PlayerFieldValue(src), false)
    AddField(fields, 'Recipe', locale(tonic.label))
    if outcome == 'success' then
        AddField(fields, 'Yield', ('%dx %s'):format(tonic.output.amount, tonic.output.item))
    else
        AddField(fields, 'Reason', 'Inventory full - ingredients refunded, no output granted')
    end
    Send('craft', BuildEmbed(title, nil, COLORS.craft, fields))
end

function Webhook.LogMysteryBox(src, lootItems)
    local fields = {}
    AddField(fields, 'Player', PlayerFieldValue(src), false)
    AddField(fields, 'Loot', table.concat(lootItems, ', '), false)
    Send('mysterybox', BuildEmbed('Mystery box opened', nil, COLORS.mysterybox, fields))
end

function Webhook.LogResourceEvent(state)
    Send('resource', BuildEmbed(
        state == 'started' and 'rsg-herbalist started' or 'rsg-herbalist stopped',
        nil, COLORS.resource, {}
    ))
end

function Webhook.LogVersionCheck(status, message)
    -- status: 'outdated' | 'newer' | 'error'
    local titles = {
        outdated = 'rsg-herbalist is outdated',
        newer = 'rsg-herbalist is running a newer-than-remote build',
        error = 'rsg-herbalist version check failed',
    }
    local colors = { outdated = COLORS.anticheat, newer = COLORS.version, error = COLORS.anticheat }
    Send('version', BuildEmbed(titles[status] or 'rsg-herbalist version check', message, colors[status] or COLORS.version, {}))
end

----------------------------------------------------------------------------
-- Anti-cheat violation tracking
--
-- See Config.Webhook.antiCheat for the reasoning: individual violations are
-- always Debug-logged, but only escalate to a Discord alert once a player
-- racks up violationThreshold of them inside violationWindowMs - and again
-- every violationThreshold after that, so a repeat offender keeps
-- generating alerts instead of just the first one.
----------------------------------------------------------------------------

local violations = {} -- src -> { count = n, windowStartedAt = GameTimer, lastReason = str }

AddEventHandler('playerDropped', function()
    violations[source] = nil
end)

function Webhook.FlagSuspicious(src, reason, details)
    Debug(('suspicious activity src=%s reason=%s details=%s'):format(src, reason, details or ''))

    local now = GetGameTimer()
    local window = (Config.Webhook.antiCheat and Config.Webhook.antiCheat.violationWindowMs) or 60000
    local threshold = (Config.Webhook.antiCheat and Config.Webhook.antiCheat.violationThreshold) or 3

    local v = violations[src]
    if not v or (now - v.windowStartedAt) > window then
        v = { count = 0, windowStartedAt = now }
        violations[src] = v
    end
    v.count = v.count + 1
    v.lastReason = reason

    if v.count % threshold ~= 0 then return end

    local target = CategoryTarget('anticheat')
    if not target then return end

    local fields = {}
    AddField(fields, 'Player', PlayerFieldValue(src), false)
    AddField(fields, 'Reason', reason)
    if details then AddField(fields, 'Details', details, false) end
    AddField(fields, 'Violations in window', ('%d in the last %ds'):format(v.count, math.floor(window / 1000)))

    local content
    if target.mentionRoleId and target.mentionRoleId ~= '' then
        content = ('<@&%s>'):format(target.mentionRoleId)
    end

    Send('anticheat', BuildEmbed('Suspicious activity detected', nil, COLORS.anticheat, fields), content)
end
