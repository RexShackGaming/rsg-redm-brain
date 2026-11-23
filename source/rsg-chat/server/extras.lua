---------------------------------------------------------------------
-- rsg-chat extras: mutes, word filter, chat logs + search, private
-- messages, /do and /roll, @mentions.
-- Loads after server/main.lua and fills in the ChatCore hooks it uses.
---------------------------------------------------------------------
local RSGCore = exports['rsg-core']:GetCoreObject()
local C = ChatCore

local dbReady = false

-- Console feedback for commands that can be run from the server console (source 0)
local function reply(src, key, ntype, ...)
    if src > 0 then return C.notify(src, key, ntype, ...) end
    print(('[rsg-chat] %s'):format(locale(key, ...)))
end

local function rsgLog(title, color, text)
    TriggerEvent('rsg-log:server:CreateLog', 'chat', title, color, text)
end

---------------------------------------------------------------------
-- Database
---------------------------------------------------------------------
local function ensureDatabase()
    if Config.AutoDatabase == false then return true end
    local statements = {
        [[CREATE TABLE IF NOT EXISTS `rsg_chat_mutes` (
            `citizenid` VARCHAR(50) NOT NULL,
            `expires` BIGINT NOT NULL DEFAULT 0,
            `reason` VARCHAR(200) NOT NULL DEFAULT '',
            `muted_by` VARCHAR(100) NOT NULL DEFAULT '',
            PRIMARY KEY (`citizenid`)
        ) DEFAULT CHARSET=utf8mb4]],
        [[CREATE TABLE IF NOT EXISTS `rsg_chat_logs` (
            `id` BIGINT NOT NULL AUTO_INCREMENT,
            `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `channel` VARCHAR(32) NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL DEFAULT '',
            `name` VARCHAR(100) NOT NULL DEFAULT '',
            `player_id` INT NOT NULL DEFAULT 0,
            `message` VARCHAR(768) NOT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_created` (`created`),
            KEY `idx_citizenid` (`citizenid`)
        ) DEFAULT CHARSET=utf8mb4]],
    }
    for _, sql in ipairs(statements) do
        local ok, err = pcall(MySQL.query.await, sql)
        if not ok then
            print(('^1[rsg-chat] could not create a database table: %s^7'):format(tostring(err)))
            return false
        end
    end
    print('^2[rsg-chat] extra database tables ready^7')
    return true
end

---------------------------------------------------------------------
-- Mutes (stored by citizenid, so they survive relogs and restarts)
---------------------------------------------------------------------
local mutes = {} -- citizenid -> { expires = unix seconds (0 = permanent), reason }

local function loadMutes()
    local rows = MySQL.query.await('SELECT citizenid, expires, reason FROM rsg_chat_mutes WHERE expires = 0 OR expires > ?', { os.time() }) or {}
    for _, r in ipairs(rows) do mutes[r.citizenid] = { expires = tonumber(r.expires) or 0, reason = r.reason } end
end

local function clearMute(citizenid)
    mutes[citizenid] = nil
    MySQL.update('DELETE FROM rsg_chat_mutes WHERE citizenid = ?', { citizenid })
end

-- Returns true (and tells the player) when this player may not chat
function C.CheckMute(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    local m = Player and mutes[Player.PlayerData.citizenid]
    if not m then return false end
    if m.expires == 0 then
        C.notify(src, 'muted_permanent')
        return true
    end
    local left = m.expires - os.time()
    if left <= 0 then
        clearMute(Player.PlayerData.citizenid)
        return false
    end
    C.notify(src, 'muted_timed', 'error', math.ceil(left / 60))
    return true
end

local function canModerate(src)
    return src == 0 or RSGCore.Functions.HasPermission(src, Config.ModPermission)
end

RSGCore.Commands.Add('chatmute', locale('help_chatmute'), {
    { name = locale('param_id'), help = locale('param_id_help') },
    { name = locale('param_minutes'), help = locale('param_minutes_help') },
    { name = locale('param_reason'), help = locale('param_reason_help') },
}, false, function(source, args)
    if not canModerate(source) then return reply(source, 'no_permission') end
    local targetId, minutes = tonumber(args[1]), tonumber(args[2])
    if not targetId or not minutes or minutes < 0 then return reply(source, 'missing_args') end

    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target then return reply(source, 'player_not_found') end
    -- staff can't mute staff of the same level
    if source ~= 0 and RSGCore.Functions.HasPermission(targetId, Config.ModPermission) then
        return reply(source, 'no_permission')
    end

    minutes = math.min(math.floor(minutes), Config.Moderation.MaxMuteMinutes)
    local reason = C.cleanStr(table.concat(args, ' ', 3), 200)
    local expires = minutes == 0 and 0 or (os.time() + minutes * 60)
    local by = source == 0 and 'Console' or C.GetCharacterName(source)
    local cid = Target.PlayerData.citizenid

    MySQL.insert('INSERT INTO rsg_chat_mutes (citizenid, expires, reason, muted_by) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE expires = VALUES(expires), reason = VALUES(reason), muted_by = VALUES(muted_by)',
        { cid, expires, reason, by })
    mutes[cid] = { expires = expires, reason = reason }

    local name = C.GetCharacterName(targetId)
    if minutes == 0 then
        C.notify(targetId, 'muted_permanent')
        reply(source, 'mute_done_perm', 'success', name)
    else
        C.notify(targetId, 'muted_timed', 'error', minutes)
        reply(source, 'mute_done', 'success', name, minutes)
    end
    rsgLog('Chat mute', 'orange', ('%s muted **%s** (%s) for %s min. Reason: %s'):format(by, name, cid, minutes, reason ~= '' and reason or '-'))
end, Config.ModPermission)

RSGCore.Commands.Add('chatunmute', locale('help_chatunmute'), {
    { name = locale('param_id'), help = locale('param_id_help') },
}, false, function(source, args)
    if not canModerate(source) then return reply(source, 'no_permission') end
    local targetId = tonumber(args[1])
    if not targetId then return reply(source, 'missing_args') end
    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target then return reply(source, 'player_not_found') end
    local cid = Target.PlayerData.citizenid
    if not mutes[cid] then return reply(source, 'not_muted') end

    clearMute(cid)
    local name = C.GetCharacterName(targetId)
    C.notify(targetId, 'unmuted_notice', 'success')
    reply(source, 'unmute_done', 'success', name)
    rsgLog('Chat unmute', 'green', ('%s unmuted **%s** (%s)'):format(source == 0 and 'Console' or C.GetCharacterName(source), name, cid))
end, Config.ModPermission)

---------------------------------------------------------------------
-- Word filter (whole words, simple leetspeak normalisation)
-- mode 'mask'  -> the word is replaced with ****
-- mode 'block' -> the whole message is dropped and the player is told
---------------------------------------------------------------------
local LEET = { ['0'] = 'o', ['1'] = 'i', ['3'] = 'e', ['4'] = 'a', ['5'] = 's', ['7'] = 't', ['@'] = 'a', ['$'] = 's' }
local LEET_CLASS = '[013457@$]'
local filterWords = {}

local function normalise(s)
    return (s:lower():gsub(LEET_CLASS, LEET)) -- ASCII-only swaps: byte positions stay aligned with the original
end

for _, w in ipairs((Config.WordFilter and Config.WordFilter.words) or {}) do
    w = normalise(tostring(w))
    if w ~= '' then filterWords[#filterWords + 1] = w end
end

local function isWordChar(c)
    return c ~= '' and c:find('[%w_\128-\255]') ~= nil
end

function C.Filter(message, src)
    local wf = Config.WordFilter
    if not wf or not wf.enabled or #filterWords == 0 then return message end
    if src and wf.exemptStaff and RSGCore.Functions.HasPermission(src, Config.ModPermission) then return message end

    local norm = normalise(message)
    local ranges = {}
    for _, w in ipairs(filterWords) do
        local init = 1
        while true do
            local s, e = norm:find(w, init, true)
            if not s then break end
            if not isWordChar(s > 1 and norm:sub(s - 1, s - 1) or '') and not isWordChar(norm:sub(e + 1, e + 1)) then
                ranges[#ranges + 1] = { s, e }
            end
            init = e + 1
        end
    end
    if #ranges == 0 then return message end
    if wf.mode == 'block' then return nil, true end

    table.sort(ranges, function(a, b) return a[1] < b[1] end)
    local out, pos = {}, 1
    for _, r in ipairs(ranges) do
        if r[1] >= pos then
            out[#out + 1] = message:sub(pos, r[1] - 1)
            out[#out + 1] = ('*'):rep(utf8.len(message:sub(r[1], r[2])) or (r[2] - r[1] + 1))
            pos = r[2] + 1
        end
    end
    out[#out + 1] = message:sub(pos)
    return table.concat(out)
end

---------------------------------------------------------------------
-- @mentions: "@First_Last" or "@First" highlights the message for that player
---------------------------------------------------------------------
function C.FindMentions(message, recipients, src)
    if not Config.Mentions then return nil end
    local tokens = {}
    for token in message:gmatch('@([^%s,.!?;:]+)') do tokens[token:lower()] = true end
    if not next(tokens) then return nil end

    local found
    local list = recipients
    if recipients[1] == -1 then -- global channel: everyone is a recipient
        list = {}
        for _, sid in ipairs(GetPlayers()) do list[#list + 1] = tonumber(sid) end
    end
    for _, t in ipairs(list) do
        if t ~= src then
            local P = RSGCore.Functions.GetPlayer(t)
            local ci = P and P.PlayerData.charinfo
            if ci and ci.firstname then
                local first = ci.firstname:lower()
                local full = ('%s_%s'):format(first, (ci.lastname or ''):lower()):gsub('%s+', '_')
                if tokens[first] or tokens[full] then
                    found = found or {}
                    found[t] = true
                end
            end
        end
    end
    return found
end

---------------------------------------------------------------------
-- Chat logs (batched inserts) + admin search
---------------------------------------------------------------------
local buffer = {}

local function flush(wait)
    if #buffer == 0 or not dbReady then return end
    local rows = buffer
    buffer = {}
    local placeholders, values = {}, {}
    for i, r in ipairs(rows) do
        placeholders[i] = '(?, ?, ?, ?, ?)'
        for j = 1, 5 do values[#values + 1] = r[j] end
    end
    local query = 'INSERT INTO rsg_chat_logs (channel, citizenid, name, player_id, message) VALUES ' .. table.concat(placeholders, ', ')
    if wait then MySQL.insert.await(query, values) else MySQL.insert(query, values) end
end

function C.Log(src, channel, name, message)
    local cfg = Config.Logging
    if not cfg or not cfg.Enabled then return end
    if (channel == 'pm') and not cfg.LogPrivate then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    local len = utf8.len(message)
    if not len then return end -- not valid UTF-8: the database would reject it
    if len > 700 then message = message:sub(1, utf8.offset(message, 701) - 1) end -- cut by characters, never mid-character
    buffer[#buffer + 1] = { channel, Player and Player.PlayerData.citizenid or '', name, src, message }
    if #buffer >= 50 then flush() end

    if cfg.RsgLogChannel and channel ~= 'pm' then
        TriggerEvent('rsg-log:server:CreateLog', cfg.RsgLogChannel, 'Chat', 'white',
            ('**%s** [%s]: %s'):format(name, channel, message))
    end
end

CreateThread(function()
    local ticks = 0
    while true do
        Wait(5000)
        flush()
        ticks = ticks + 1
        -- purge old entries about once an hour
        if dbReady and ticks % 720 == 0 and Config.Logging and Config.Logging.RetentionDays > 0 then
            MySQL.update('DELETE FROM rsg_chat_logs WHERE created < (NOW() - INTERVAL ? DAY)', { Config.Logging.RetentionDays })
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then flush() end
end)

local function likePattern(s)
    return '%' .. (s:gsub('[\\%%_]', '\\%0')) .. '%'
end

C.AdminCallback('adminSearchLogs', function(src, filters)
    if not C.isAdmin(src) then return { ok = false, err = locale('no_permission') } end
    if type(filters) ~= 'table' then filters = {} end

    local text = C.cleanStr(filters.text, 100)
    local player = C.cleanStr(filters.player, 60)
    local channel = C.cleanStr(filters.channel, 32)

    flush(true) -- so results include the last few seconds
    local rows = MySQL.query.await([[
        SELECT id, UNIX_TIMESTAMP(created) AS ts, channel, citizenid, name, message
        FROM rsg_chat_logs
        WHERE (? = '' OR message LIKE ?)
          AND (? = '' OR name LIKE ? OR citizenid = ?)
          AND (? = '' OR channel = ?)
        ORDER BY id DESC LIMIT ?
    ]], { text, likePattern(text), player, likePattern(player), player, channel, channel, Config.Logging.SearchLimit }) or {}
    return { ok = true, rows = rows }
end)

RSGCore.Commands.Add('chatlog', locale('help_chatlog'), {}, false, function(source)
    if source > 0 then TriggerClientEvent('rsg-chat:client:openAdmin', source, 'logs') end
end, Config.AdminPermission)

---------------------------------------------------------------------
-- Private messages: /pm <id or First_Last> <message>, /r <message>
---------------------------------------------------------------------
local lastPartner = {} -- src -> { src, citizenid }

local function resolveTarget(token)
    token = tostring(token or '')
    local id = tonumber(token)
    if id then
        if Config.PM.AllowById and RSGCore.Functions.GetPlayer(id) then return id end
        return nil, 'player_not_found'
    end

    local want = (token:lower():gsub('_', ' '))
    local exact, byFirst = {}, {}
    for _, sid in ipairs(GetPlayers()) do
        local t = tonumber(sid)
        local P = RSGCore.Functions.GetPlayer(t)
        local ci = P and P.PlayerData.charinfo
        if ci and ci.firstname then
            local first = ci.firstname:lower()
            if ('%s %s'):format(first, (ci.lastname or ''):lower()) == want then exact[#exact + 1] = t end
            if first == want then byFirst[#byFirst + 1] = t end
        end
    end
    if #exact == 1 then return exact[1] end
    if #exact > 1 then return nil, 'pm_ambiguous' end
    if #byFirst == 1 then return byFirst[1] end
    if #byFirst > 1 then return nil, 'pm_ambiguous' end
    return nil, 'player_not_found'
end

local function sendPM(src, targetId, rawMessage)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if C.OnCooldown(src) or C.CheckMute(src) then return end
    if targetId == src then return C.notify(src, 'pm_self') end
    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target then return C.notify(src, 'player_not_found') end

    local message = C.CleanMessage(rawMessage, Config.HardMaxLength)
    if not message then return C.notify(src, 'missing_args') end
    local blocked
    message, blocked = C.Filter(message, src)
    if blocked or not message then return C.notify(src, 'message_blocked') end

    local myName, theirName = C.GetCharacterName(src), C.GetCharacterName(targetId)
    TriggerClientEvent('rsg-chat:client:channelMessage', targetId, {
        channel = 'pm', color = Config.PM.Color, prefix = locale('pm_prefix'),
        author = myName, text = message, mention = true, replyTo = myName,
    })
    TriggerClientEvent('rsg-chat:client:channelMessage', src, {
        channel = 'pm', color = Config.PM.Color, prefix = locale('pm_to_prefix', theirName),
        author = myName, text = message, replyTo = theirName,
    })

    lastPartner[src] = { src = targetId, citizenid = Target.PlayerData.citizenid }
    lastPartner[targetId] = { src = src, citizenid = Player.PlayerData.citizenid }
    C.Log(src, 'pm', myName, ('-> %s: %s'):format(theirName, message))
end

if Config.PM.Enabled then
    RegisterCommand(Config.PM.Command, function(source, args)
        if source == 0 then return end
        if #args < 2 then return C.notify(source, 'missing_args') end
        local targetId, err = resolveTarget(args[1])
        if not targetId then return C.notify(source, err) end
        sendPM(source, targetId, table.concat(args, ' ', 2))
    end, false)

    RegisterCommand(Config.PM.ReplyCommand, function(source, args)
        if source == 0 then return end
        if #args < 1 then return C.notify(source, 'missing_args') end
        local last = lastPartner[source]
        local P = last and RSGCore.Functions.GetPlayer(last.src)
        -- the id may have been reused by someone else since: compare the character too
        if not P or P.PlayerData.citizenid ~= last.citizenid then return C.notify(source, 'reply_none') end
        sendPM(source, last.src, table.concat(args, ' '))
    end, false)
end

---------------------------------------------------------------------
-- /do and /roll: range-limited roleplay lines (/me is provided by rsg-core)
---------------------------------------------------------------------
local function sendNearby(src, color, prefix, name, text)
    local origin = GetEntityCoords(GetPlayerPed(src))
    local payload = { channel = 'rp', color = color, prefix = prefix, author = name, text = text }
    for _, sid in ipairs(GetPlayers()) do
        local t = tonumber(sid)
        if t == src or #(GetEntityCoords(GetPlayerPed(t)) - origin) <= Config.Roleplay.Distance then
            TriggerClientEvent('rsg-chat:client:channelMessage', t, payload)
        end
    end
end

if Config.Roleplay.Enabled then
    RegisterCommand(Config.Roleplay.DoCommand, function(source, args)
        if source == 0 then return end
        if not RSGCore.Functions.GetPlayer(source) then return end
        if C.OnCooldown(source) or C.CheckMute(source) then return end
        local message = C.CleanMessage(table.concat(args, ' '), Config.Roleplay.MaxLength)
        if not message then return C.notify(source, 'missing_args') end
        local blocked
        message, blocked = C.Filter(message, source)
        if blocked or not message then return C.notify(source, 'message_blocked') end

        local name = C.GetCharacterName(source)
        sendNearby(source, Config.Roleplay.DoColor, locale('prefix_do'), name, message)
        C.Log(source, 'rp', name, '/do ' .. message)
    end, false)

    RegisterCommand(Config.Roleplay.RollCommand, function(source, args)
        if source == 0 then return end
        if not RSGCore.Functions.GetPlayer(source) then return end
        if C.OnCooldown(source) or C.CheckMute(source) then return end
        local sides = math.floor(tonumber(args[1]) or Config.Roleplay.RollDefaultSides)
        sides = math.max(2, math.min(sides, Config.Roleplay.RollMaxSides))
        local result = math.random(1, sides) -- decided on the server

        local name = C.GetCharacterName(source)
        local text = locale('roll_result', sides, result)
        sendNearby(source, Config.Roleplay.RollColor, locale('prefix_roll'), name, text)
        C.Log(source, 'rp', name, '/roll ' .. text)
    end, false)
end

---------------------------------------------------------------------
-- Cleanup + start
---------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    lastPartner[source] = nil
end)

MySQL.ready(function()
    if not ensureDatabase() then return end
    dbReady = true
    loadMutes()
    flush()
end)
