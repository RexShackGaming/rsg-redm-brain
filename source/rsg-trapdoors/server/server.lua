local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local states      = {} -- id -> bool (open)
local busyUntil   = {} -- id -> game timer
local autoToken   = {} -- id -> int, invalidates stale auto-close timers
local lastRequest = {} -- src -> game timer
local codes       = {} -- id -> { code = '1234', owner = citizenid }
local dbReady     = false -- passcodes loaded from SQL
local failures    = {} -- citizenid -> id -> { count, lockUntil } (survives relogging)

---------------------------------------------------------------------
-- state
---------------------------------------------------------------------
local function setState(id, open)
    states[id] = open
    GlobalState['trapdoor:' .. id] = open

    autoToken[id] = (autoToken[id] or 0) + 1
    if open and Config.AutoCloseTime > 0 then
        local token = autoToken[id]
        SetTimeout(Config.AutoCloseTime, function()
            if autoToken[id] == token and states[id] then
                busyUntil[id] = GetGameTimer() + Config.MoveDuration
                setState(id, false)
                TrapdoorLog('door_autoclose', nil, { door = id })
            end
        end)
    end
end

-- passcodes persist in the `rsg_trapdoors` SQL table (server only, never sent to clients).
-- Clients only learn whether a door has a code and who owns it.
local function publishCode(id)
    GlobalState['trapdoorCode:' .. id] = codes[id] and codes[id].owner or false
end

local function saveCode(id, data)
    codes[id] = data
    publishCode(id)
    if data then
        MySQL.insert('INSERT INTO rsg_trapdoors (door_id, passcode, owner) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE passcode = VALUES(passcode), owner = VALUES(owner)',
            { id, data.code, data.owner })
    else
        MySQL.update('DELETE FROM rsg_trapdoors WHERE door_id = ?', { id })
    end
end

for id in pairs(Config.Trapdoors) do
    setState(id, false) -- every door starts closed on resource start
    publishCode(id)     -- unlocked until the database has loaded
end

MySQL.ready(function()
    if not TrapdoorDB.Install() then return end

    local rows = MySQL.query.await('SELECT door_id, passcode, owner FROM rsg_trapdoors') or {}
    for _, row in ipairs(rows) do
        if Config.Trapdoors[row.door_id] then
            codes[row.door_id] = { code = row.passcode, owner = row.owner }
            publishCode(row.door_id)
        end
    end

    dbReady = true
end)

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
local function notify(src, text, nType)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('notify_title'),
        description = text,
        type = nType or 'error',
        duration = 4000,
    })
end

local function isValidCode(code)
    return type(code) == 'string' and code:match('^%d%d%d%d$') ~= nil
end

-- shared validation for every client request. returns door, Player or nil, errorText
local function validate(src, id)
    if type(id) ~= 'string' or not Config.Trapdoors[id] then
        TrapdoorLog('suspicious', src, {
            description = locale('log_desc_invalid_id'),
            fields = { { name = locale('log_field_sent_id'), value = ('`%s`'):format(tostring(id):sub(1, 64)), inline = false } },
        })
        return
    end
    local door = Config.Trapdoors[id]

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not dbReady then return end

    local now = GetGameTimer()
    if (lastRequest[src] or 0) > now then return end
    lastRequest[src] = now + Config.PlayerCooldown

    local ped = GetPlayerPed(src)
    local dist = ped ~= 0 and #(GetEntityCoords(ped) - door.closedPosition) or -1
    if ped == 0 or dist > door.interactDistance + 3.0 then
        TrapdoorLog('suspicious', src, {
            door = id,
            description = locale('log_desc_too_far'),
            fields = { { name = locale('log_field_distance'), value = ('%.1fm'):format(dist), inline = true } },
        })
        return nil, nil, locale('too_far')
    end

    return door, Player
end

local function lockoutRemaining(cid, id)
    local f = failures[cid] and failures[cid][id]
    if not f then return 0 end
    return math.max(f.lockUntil - GetGameTimer(), 0)
end

local function registerFailure(cid, id)
    failures[cid] = failures[cid] or {}
    local f = failures[cid][id] or { count = 0, lockUntil = 0 }
    f.count = f.count + 1
    if f.count >= Config.MaxCodeAttempts then
        f.count = 0
        f.lockUntil = GetGameTimer() + Config.CodeLockoutTime
    end
    failures[cid][id] = f
end

local function lockedOutText(ms)
    return locale('locked_out', math.ceil(ms / 1000))
end

---------------------------------------------------------------------
-- open (callback so the keypad can react to a wrong code)
---------------------------------------------------------------------
lib.callback.register('rsg-trapdoors:server:open', function(src, id, code)
    local door, Player, err = validate(src, id)
    if not door then return false, err end
    if states[id] then return false end
    local cid = Player.PlayerData.citizenid

    local lock = codes[id]
    if lock then
        local remaining = lockoutRemaining(cid, id)
        if remaining > 0 then return false, lockedOutText(remaining) end
        if not isValidCode(code) then return false, locale('invalid_code') end
        if code ~= lock.code then
            registerFailure(cid, id)
            remaining = lockoutRemaining(cid, id)
            TrapdoorLog(remaining > 0 and 'code_lockout' or 'code_wrong', src, {
                door = id,
                fields = { { name = locale('log_field_entered'), value = TrapdoorLogCode(code), inline = true } },
            })
            return false, remaining > 0 and lockedOutText(remaining) or locale('wrong_code')
        end
        if failures[cid] then failures[cid][id] = nil end
    end

    if (busyUntil[id] or 0) > GetGameTimer() then return false, locale('trapdoor_busy') end
    busyUntil[id] = GetGameTimer() + Config.MoveDuration
    setState(id, true)
    TrapdoorLog('door_open', src, {
        door = id,
        fields = { { name = locale('log_field_method'), value = lock and locale('log_method_passcode') or locale('log_method_none'), inline = true } },
    })
    return true
end)

-- closing never needs a code
RegisterNetEvent('rsg-trapdoors:server:close', function(id)
    local src = source
    local door, _, err = validate(src, id)
    if not door then
        if err then notify(src, err) end
        return
    end
    if not states[id] then return end
    if (busyUntil[id] or 0) > GetGameTimer() then
        return notify(src, locale('trapdoor_busy'), 'inform')
    end
    busyUntil[id] = GetGameTimer() + Config.MoveDuration
    setState(id, false)
    TrapdoorLog('door_close', src, { door = id })
end)

---------------------------------------------------------------------
-- passcode management
---------------------------------------------------------------------
lib.callback.register('rsg-trapdoors:server:setCode', function(src, id, newCode)
    local door, Player, err = validate(src, id)
    if not door then return false, err end
    if codes[id] then
        TrapdoorLog('suspicious', src, { door = id, description = locale('log_desc_already_set') })
        return false, locale('code_already_set')
    end
    if not isValidCode(newCode) then return false, locale('invalid_code') end

    saveCode(id, { code = newCode, owner = Player.PlayerData.citizenid })
    TrapdoorLog('code_set', src, {
        door = id,
        fields = { { name = locale('log_field_passcode'), value = TrapdoorLogCode(newCode), inline = true } },
    })
    return true, locale('code_set')
end)

lib.callback.register('rsg-trapdoors:server:changeCode', function(src, id, current, newCode)
    local door, Player, err = validate(src, id)
    if not door then return false, err end

    local lock = codes[id]
    if not lock then return false end
    if lock.owner ~= Player.PlayerData.citizenid then
        TrapdoorLog('suspicious', src, {
            door = id,
            description = locale('log_desc_not_owner'),
            fields = { { name = locale('log_field_owner'), value = ('`%s`'):format(lock.owner), inline = true } },
        })
        return false, locale('not_owner')
    end

    local cid = Player.PlayerData.citizenid
    local remaining = lockoutRemaining(cid, id)
    if remaining > 0 then return false, lockedOutText(remaining) end
    if not isValidCode(current) or not isValidCode(newCode) then return false, locale('invalid_code') end
    if current ~= lock.code then
        registerFailure(cid, id)
        TrapdoorLog(lockoutRemaining(cid, id) > 0 and 'code_lockout' or 'code_wrong', src, {
            door = id,
            description = locale('log_desc_wrong_current'),
            fields = { { name = locale('log_field_entered'), value = TrapdoorLogCode(current), inline = true } },
        })
        return false, locale('wrong_code')
    end

    saveCode(id, { code = newCode, owner = lock.owner })
    TrapdoorLog('code_changed', src, {
        door = id,
        fields = {
            { name = locale('log_field_old'), value = TrapdoorLogCode(current), inline = true },
            { name = locale('log_field_new'), value = TrapdoorLogCode(newCode), inline = true },
        },
    })
    return true, locale('code_changed')
end)

lib.addCommand(Config.AdminResetCommand, {
    help = locale('admin_reset_help'),
    params = { { name = 'id', type = 'string', help = locale('admin_reset_arg') } },
    restricted = 'group.admin',
}, function(src, args)
    if not Config.Trapdoors[args.id] then
        return notify(src, locale('admin_reset_unknown'))
    end
    local previousOwner = codes[args.id] and codes[args.id].owner
    saveCode(args.id, nil)
    notify(src, locale('admin_reset_done', args.id), 'success')
    TrapdoorLog('code_reset', src > 0 and src or nil, {
        door = args.id,
        description = src > 0 and nil or locale('log_desc_console_reset'),
        fields = { { name = locale('log_field_previous_owner'), value = previousOwner and ('`%s`'):format(previousOwner) or locale('log_none'), inline = true } },
    })
end)

AddEventHandler('playerDropped', function()
    lastRequest[source] = nil
end)
