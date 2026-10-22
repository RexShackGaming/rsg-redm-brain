local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Saved = {}      -- [hash] = { label = string|nil, state = 1|0|nil }
local lastWrite = {}  -- [src] = GetGameTimer() of last write (spam guard)
local WRITE_COOLDOWN = 250

local INT32_MIN, INT32_MAX = -2147483648, 2147483647

local function isAdmin(src)
    if not Config.OnlyAdmins then return true end
    return RSGCore.Functions.HasPermission(src, Config.AdminPerm) or IsPlayerAceAllowed(src, 'command')
end

local function savedList()
    local list = {}
    for hash, v in pairs(Saved) do list[#list + 1] = { hash = hash, label = v.label, state = v.state } end
    return list
end

-- validates the common args of every write event; returns hash, name or nil
local function validateWrite(src, hash, name)
    if not RSGCore.Functions.GetPlayer(src) or not isAdmin(src) then return end
    local now = GetGameTimer()
    if lastWrite[src] and now - lastWrite[src] < WRITE_COOLDOWN then return end
    lastWrite[src] = now
    hash = math.tointeger(tonumber(hash))
    if not hash or hash < INT32_MIN or hash > INT32_MAX then return end
    return hash, type(name) == 'string' and name:sub(1, 128) or nil
end

AddEventHandler('playerDropped', function() lastWrite[source] = nil end)

lib.callback.register('rsg-mapping:server:canUse', function(source) return isAdmin(source) end)
lib.callback.register('rsg-mapping:server:getSaved', function() return savedList() end)

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `rsg_imaps` (
            `hash` INT NOT NULL, `name` VARCHAR(128) NULL, `label` VARCHAR(100) NULL,
            `state` TINYINT(1) NULL, `updated_by` VARCHAR(64) NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`hash`))]])
        local rows = MySQL.query.await('SELECT hash, label, state FROM rsg_imaps') or {}
        for _, r in ipairs(rows) do
            Saved[r.hash] = { label = r.label, state = r.state }
        end
        print(('[rsg-mapping] loaded %d saved IMAP entries'):format(#rows))
        TriggerClientEvent('rsg-mapping:client:syncAll', -1, savedList())
    end)
    if not ok then print('^1[rsg-mapping] database error: ' .. tostring(err) .. '^7') end
end)

local function persist(src, hash, name)
    local e = Saved[hash]
    if not e or (e.label == nil and e.state == nil) then
        Saved[hash] = nil
        MySQL.query('DELETE FROM rsg_imaps WHERE hash = ?', { hash })
    else
        MySQL.query([[INSERT INTO rsg_imaps (hash, name, label, state, updated_by) VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE name = COALESCE(VALUES(name), name), label = VALUES(label),
            state = VALUES(state), updated_by = VALUES(updated_by)]],
            { hash, name, e.label, e.state, GetPlayerName(src) or tostring(src) })
    end
    TriggerClientEvent('rsg-mapping:client:update', -1, hash, Saved[hash] or false)
end

RegisterNetEvent('rsg-mapping:server:setLabel', function(hash, name, label)
    local src = source
    local h, n = validateWrite(src, hash, name)
    if not h then return end
    if type(label) ~= 'string' then label = nil end
    if label then
        label = label:gsub('[%c]', ''):match('^%s*(.-)%s*$'):sub(1, 100)
        if label == '' then label = nil end
    end
    Saved[h] = Saved[h] or {}
    Saved[h].label = label
    persist(src, h, n)
end)

RegisterNetEvent('rsg-mapping:server:setState', function(hash, name, state)
    local src = source
    local h, n = validateWrite(src, hash, name)
    if not h then return end
    if state ~= nil then state = state and 1 or 0 end
    Saved[h] = Saved[h] or {}
    Saved[h].state = state
    persist(src, h, n)
end)
