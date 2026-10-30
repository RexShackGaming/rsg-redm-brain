local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Channels, Order = {}, {}      -- id -> channel, ordered ids
local registeredCommands = {}       -- command names already registered this session
local lastMessage, lastSync = {}, {}

local RANGES = { global = true, ['local'] = true, regional = true, group = true }
local PERMS = {}
for _, p in ipairs(Config.PermissionLevels) do PERMS[p] = true end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function notify(src, key, ntype, ...)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('chat_title'),
        description = locale(key, ...),
        type = ntype or 'error',
        duration = 4000,
    })
end

local function cleanStr(v, max)
    if type(v) ~= 'string' then return '' end
    v = (v:gsub('[%c<>]', ''))
    v = v:match('^%s*(.-)%s*$') or ''
    return v:sub(1, max)
end

local function cleanList(v)
    local out = {}
    if type(v) == 'string' then
        local t = {}
        for part in v:gmatch('[^,]+') do t[#t + 1] = part end
        v = t
    end
    if type(v) ~= 'table' then return out end
    for _, s in ipairs(v) do
        s = cleanStr(s, 50):lower()
        if s ~= '' and s:match('^[%w_%-]+$') and #out < 50 then out[#out + 1] = s end
    end
    return out
end

local function clampNum(v, min, max, def)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return def end
    return math.floor(math.max(min, math.min(max, v)))
end

local function inList(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

-- Turns untrusted input (admin panel or config) into a valid channel, or nil + error key
local function SanitizeChannel(d)
    if type(d) ~= 'table' then return nil, 'admin_invalid' end
    local id = cleanStr(d.id, 24):lower()
    if not id:match('^[%a][%w_]+$') or #id < 2 then return nil, 'admin_bad_id' end

    local command = cleanStr(d.command, 20):lower()
    if command ~= '' and not command:match('^[%a][%w_]*$') then return nil, 'admin_bad_command' end

    local color = cleanStr(d.color, 7):lower()
    if not color:match('^#%x%x%x%x%x%x$') then return nil, 'admin_bad_color' end

    local range = RANGES[d.range] and d.range or 'global'
    local permission = (type(d.permission) == 'string' and PERMS[d.permission]) and d.permission or ''

    local label = cleanStr(d.label, 24)
    if label == '' then return nil, 'admin_bad_label' end

    return {
        id = id,
        label = label,
        command = command,
        prefix = cleanStr(d.prefix, 16),
        showPrefix = d.showPrefix == true,
        color = color,
        range = range,
        distance = (range == 'local' or range == 'regional')
            and clampNum(d.distance, Config.DistanceLimits.min, Config.DistanceLimits.max, 20) or 0,
        maxLength = clampNum(d.maxLength, 1, Config.HardMaxLength, 256),
        jobs = range == 'group' and cleanList(d.jobs) or {},
        gangs = range == 'group' and cleanList(d.gangs) or {},
        requireDuty = range == 'group' and d.requireDuty == true or false,
        permission = permission,
        enabled = d.enabled ~= false,
    }
end

-- Can this player see and send in this channel?
local function CanUse(src, ch)
    if not ch or not ch.enabled then return false end
    if ch.permission ~= '' and not RSGCore.Functions.HasPermission(src, ch.permission) then return false end
    if ch.range ~= 'group' or (#ch.jobs == 0 and #ch.gangs == 0) then return true end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local job, gang = Player.PlayerData.job, Player.PlayerData.gang
    if job and inList(ch.jobs, job.name) and (not ch.requireDuty or job.onduty) then return true end
    if gang and inList(ch.gangs, gang.name) then return true end
    return false
end

local function GetCharacterName(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    local info = Player and Player.PlayerData.charinfo
    if info and info.firstname and info.lastname then
        return ('%s %s'):format(info.firstname, info.lastname)
    end
    return GetPlayerName(src) or locale('unknown_player')
end

---------------------------------------------------------------------
-- Sync channel list to players
---------------------------------------------------------------------
local function PublicList(src)
    local out = {}
    for _, id in ipairs(Order) do
        local ch = Channels[id]
        if CanUse(src, ch) then
            out[#out + 1] = {
                id = ch.id, label = ch.label, color = ch.color, prefix = ch.prefix,
                command = ch.command, maxLength = ch.maxLength, range = ch.range,
            }
        end
    end
    return out
end

local function SyncPlayer(src)
    src = tonumber(src)
    if not src or src <= 0 then return end
    TriggerClientEvent('rsg-chat:client:syncChannels', src, PublicList(src), Config.DefaultChannel)
end

local function SyncAll()
    for _, id in ipairs(GetPlayers()) do SyncPlayer(id) end
end

local function AdminList()
    local out = {}
    for _, id in ipairs(Order) do out[#out + 1] = Channels[id] end
    return out
end

---------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------
local function GetRecipients(src, ch)
    if ch.range == 'global' and ch.permission == '' then return { -1 } end
    local list = {}
    local origin
    if ch.range == 'local' or ch.range == 'regional' then
        origin = GetEntityCoords(GetPlayerPed(src))
    end
    for _, sid in ipairs(GetPlayers()) do
        local t = tonumber(sid)
        if CanUse(t, ch) then
            if not origin or t == src or #(GetEntityCoords(GetPlayerPed(t)) - origin) <= ch.distance then
                list[#list + 1] = t
            end
        end
    end
    return list
end

local function ValidateMessage(src, message, maxLength)
    if type(message) ~= 'string' then return end
    message = message:match('^%s*(.-)%s*$')
    if message == '' then return end

    local now = GetGameTimer()
    if lastMessage[src] and now - lastMessage[src] < Config.MessageCooldown then
        notify(src, 'slow_down')
        return
    end
    lastMessage[src] = now

    return message:sub(1, math.min(maxLength or Config.HardMaxLength, Config.HardMaxLength))
end

local function SendToChannel(src, channelId, message)
    local ch = Channels[channelId]
    if not CanUse(src, ch) then
        notify(src, 'channel_unavailable')
        SyncPlayer(src)
        return
    end
    message = ValidateMessage(src, message, ch.maxLength)
    if not message then return end

    local name = GetCharacterName(src)
    TriggerEvent('chatMessage', src, name, message) -- lets other resources hook/cancel
    if WasEventCanceled() then return end

    local payload = {
        channel = ch.id,
        color = ch.color,
        prefix = ch.showPrefix and ch.prefix ~= '' and ch.prefix or nil,
        author = name,
        text = message,
    }
    for _, target in ipairs(GetRecipients(src, ch)) do
        TriggerClientEvent('rsg-chat:client:channelMessage', target, payload)
    end
    print(('[%s] %s^7: %s^7'):format(ch.id, name, message))
end

local function FindByCommand(cmd)
    for _, id in ipairs(Order) do
        if Channels[id].command == cmd then return Channels[id] end
    end
end

local function RegisterChannelCommands()
    for _, id in ipairs(Order) do
        local cmd = Channels[id].command
        if cmd ~= '' and not registeredCommands[cmd] then
            registeredCommands[cmd] = true
            RegisterCommand(cmd, function(source, _, rawCommand)
                if source == 0 then return end
                local ch = FindByCommand(cmd) -- looked up live, so edits/deletes apply
                if not ch then return notify(source, 'channel_unavailable') end
                SendToChannel(source, ch.id, rawCommand:sub(#cmd + 2))
            end, false)
        end
    end
end

---------------------------------------------------------------------
-- Database
---------------------------------------------------------------------
local function SaveOrder()
    local queries = {}
    for i, id in ipairs(Order) do
        queries[#queries + 1] = { query = 'UPDATE rsg_chat_channels SET sort = ? WHERE id = ?', values = { i, id } }
    end
    if #queries > 0 then MySQL.transaction.await(queries) end
end

local function LoadChannels()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rsg_chat_channels` (
            `id` VARCHAR(32) NOT NULL,
            `data` LONGTEXT NOT NULL,
            `sort` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`)
        )
    ]])

    local rows = MySQL.query.await('SELECT id, data FROM rsg_chat_channels ORDER BY sort ASC, id ASC') or {}
    if #rows == 0 then
        for i, def in ipairs(Config.Channels) do
            local ch, err = SanitizeChannel(def)
            if ch then
                MySQL.insert.await('INSERT INTO rsg_chat_channels (id, data, sort) VALUES (?, ?, ?)', { ch.id, json.encode(ch), i })
                rows[#rows + 1] = { id = ch.id, data = json.encode(ch) }
            else
                print(('^3[rsg-chat] seed channel #%d skipped (%s)^7'):format(i, err))
            end
        end
    end

    Channels, Order = {}, {}
    for _, row in ipairs(rows) do
        local ok, data = pcall(json.decode, row.data)
        local ch = ok and SanitizeChannel(data)
        if ch and not Channels[ch.id] then
            Channels[ch.id] = ch
            Order[#Order + 1] = ch.id
        end
    end
    RegisterChannelCommands()
end

MySQL.ready(function()
    LoadChannels()
    SyncAll()
end)

---------------------------------------------------------------------
-- Player events
---------------------------------------------------------------------
RegisterNetEvent('rsg-chat:server:send', function(channelId, message)
    local src = source
    if type(channelId) ~= 'string' then return end
    SendToChannel(src, channelId, message)
end)

-- Legacy: plain chat from older clients/resources goes to the default channel
RegisterNetEvent('_chat:messageEntered', function(_, _, message)
    local src = source
    local id = Channels[Config.DefaultChannel] and Config.DefaultChannel or Order[1]
    if id then SendToChannel(src, id, message) end
end)

RegisterNetEvent('rsg-chat:server:requestChannels', function()
    local src = source
    local now = GetGameTimer()
    if lastSync[src] and now - lastSync[src] < 1000 then return end
    lastSync[src] = now
    SyncPlayer(src)
end)

AddEventHandler('RSGCore:Server:OnJobUpdate', function(src) SyncPlayer(src) end)
AddEventHandler('RSGCore:Server:OnGangUpdate', function(src) SyncPlayer(src) end)
AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    if Player and Player.PlayerData then SyncPlayer(Player.PlayerData.source) end
end)

RegisterNetEvent('__cfx_internal:commandFallback', function(command)
    local src = source
    CancelEvent()
    if type(command) ~= 'string' then return end
    notify(src, 'unknown_command', 'error', (command:match('^(%S+)') or ''):sub(1, 32))
end)

-- Server-wide announcement. Usable from other server scripts, or by admins only from a client.
RegisterNetEvent('chat:server:ServerPSA', function(message)
    local src = tonumber(source) or 0
    if src > 0 and not RSGCore.Functions.HasPermission(src, Config.PSAPermission) then
        notify(src, 'no_permission')
        return
    end
    if type(message) ~= 'string' or message == '' then return end

    TriggerClientEvent('chat:addMessage', -1, {
        template = '<div class="chat-message server">{1}: {0}</div>',
        args = { message:sub(1, Config.HardMaxLength), locale('server_prefix') },
    })
end)

AddEventHandler('playerDropped', function()
    lastMessage[source] = nil
    lastSync[source] = nil
end)

---------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------
RegisterCommand('clearchat', function(source)
    if source > 0 then TriggerClientEvent('chat:clear', source) end
end, false)

RSGCore.Commands.Add('chatadmin', locale('help_chatadmin'), {}, false, function(source)
    TriggerClientEvent('rsg-chat:client:openAdmin', source)
end, Config.AdminPermission)

---------------------------------------------------------------------
-- Admin panel callbacks (every one re-checks permission)
---------------------------------------------------------------------
local function isAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.AdminPermission)
end

local function adminResult(ok, err)
    return { ok = ok, err = err and locale(err) or nil, channels = AdminList() }
end

lib.callback.register('rsg-chat:server:adminGetChannels', function(src)
    if not isAdmin(src) then return nil end
    return AdminList()
end)

lib.callback.register('rsg-chat:server:adminSave', function(src, data, originalId)
    if not isAdmin(src) then return adminResult(false, 'no_permission') end
    local ch, err = SanitizeChannel(data)
    if not ch then return adminResult(false, err) end

    originalId = type(originalId) == 'string' and Channels[originalId] and originalId or nil

    -- id clash with a different channel
    if Channels[ch.id] and ch.id ~= originalId then return adminResult(false, 'admin_id_taken') end
    -- command clash
    if ch.command ~= '' then
        local other = FindByCommand(ch.command)
        if other and other.id ~= originalId then return adminResult(false, 'admin_command_taken') end
    end

    if originalId and originalId ~= ch.id then
        -- renamed: replace row and keep position
        MySQL.update.await('UPDATE rsg_chat_channels SET id = ?, data = ? WHERE id = ?', { ch.id, json.encode(ch), originalId })
        Channels[originalId] = nil
        for i, id in ipairs(Order) do if id == originalId then Order[i] = ch.id end end
    elseif originalId then
        MySQL.update.await('UPDATE rsg_chat_channels SET data = ? WHERE id = ?', { json.encode(ch), ch.id })
    else
        MySQL.insert.await('INSERT INTO rsg_chat_channels (id, data, sort) VALUES (?, ?, ?)', { ch.id, json.encode(ch), #Order + 1 })
        Order[#Order + 1] = ch.id
    end
    Channels[ch.id] = ch

    RegisterChannelCommands()
    SyncAll()
    TriggerEvent('rsg-log:server:CreateLog', 'chat', 'Chat channel saved', 'white',
        ('%s saved channel "%s"'):format(GetPlayerName(src) or src, ch.id))
    return adminResult(true)
end)

lib.callback.register('rsg-chat:server:adminDelete', function(src, id)
    if not isAdmin(src) then return adminResult(false, 'no_permission') end
    if type(id) ~= 'string' or not Channels[id] then return adminResult(false, 'admin_invalid') end

    MySQL.query.await('DELETE FROM rsg_chat_channels WHERE id = ?', { id })
    Channels[id] = nil
    for i, cid in ipairs(Order) do if cid == id then table.remove(Order, i) break end end
    SaveOrder()
    SyncAll()
    TriggerEvent('rsg-log:server:CreateLog', 'chat', 'Chat channel deleted', 'red',
        ('%s deleted channel "%s"'):format(GetPlayerName(src) or src, id))
    return adminResult(true)
end)

lib.callback.register('rsg-chat:server:adminToggle', function(src, id)
    if not isAdmin(src) then return adminResult(false, 'no_permission') end
    local ch = type(id) == 'string' and Channels[id]
    if not ch then return adminResult(false, 'admin_invalid') end

    ch.enabled = not ch.enabled
    MySQL.update.await('UPDATE rsg_chat_channels SET data = ? WHERE id = ?', { json.encode(ch), ch.id })
    SyncAll()
    return adminResult(true)
end)

lib.callback.register('rsg-chat:server:adminMove', function(src, id, dir)
    if not isAdmin(src) then return adminResult(false, 'no_permission') end
    if type(id) ~= 'string' or (dir ~= -1 and dir ~= 1) then return adminResult(false, 'admin_invalid') end

    for i, cid in ipairs(Order) do
        if cid == id then
            local j = i + dir
            if j >= 1 and j <= #Order then
                Order[i], Order[j] = Order[j], Order[i]
                SaveOrder()
                SyncAll()
            end
            break
        end
    end
    return adminResult(true)
end)

---------------------------------------------------------------------
-- Exports for other resources
---------------------------------------------------------------------
-- exports['rsg-chat']:SendChannelMessage('staff', 'Server', 'Restart in 5 minutes')
exports('SendChannelMessage', function(channelId, author, text)
    local ch = Channels[channelId]
    if not ch or type(text) ~= 'string' then return false end
    local payload = {
        channel = ch.id, color = ch.color,
        prefix = ch.showPrefix and ch.prefix ~= '' and ch.prefix or nil,
        author = tostring(author or locale('console_name')), text = text:sub(1, Config.HardMaxLength),
    }
    for _, sid in ipairs(GetPlayers()) do
        local t = tonumber(sid)
        if CanUse(t, ch) then TriggerClientEvent('rsg-chat:client:channelMessage', t, payload) end
    end
    return true
end)

exports('GetChannels', function() return AdminList() end)
