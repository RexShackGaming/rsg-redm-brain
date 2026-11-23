local RSGCore = exports['rsg-core']:GetCoreObject()

-- Doors[id] = { id, name, doors = { {hash, coords}, ... }, textCoords, jobs = {}, distance, locked }
local Doors = {}
local lastUse = {}
local lastPick = {}   -- [src] = ms of the last lockpick request
local picking = {}    -- [src] = GetGameTimer() when the running lockpick attempt started
local PICK_TIMEOUT = 120000 -- ms after which a silent attempt is considered dead
local relockToken = {} -- [doorID] = counter; a pending auto-relock only runs if it still matches
local lastAccess = {}  -- [src] = ms of the last access check (client prompt)
local scheduled = {}   -- [doorID] = last open/closed state the schedule applied
local ready = false
local hasOptColumns = false -- every optional column below exists in rsg_doorlocks

-- columns added after 3.0 (name, definition); added automatically while Config.AutoDatabase = true
local OPTIONAL_COLUMNS = {
    { 'lockpick',   'VARCHAR(16) NULL DEFAULT NULL' },
    { 'region',     'VARCHAR(32) NULL DEFAULT NULL' },
    { 'key_item',   'VARCHAR(64) NULL DEFAULT NULL' },
    { 'gangs',      'LONGTEXT NULL' },
    { 'group_name', 'VARCHAR(32) NULL DEFAULT NULL' },
    { 'open_from',  'TINYINT NULL DEFAULT NULL' },
    { 'open_to',    'TINYINT NULL DEFAULT NULL' },
}

---------------------------------------------
-- helpers
---------------------------------------------
local function notify(src, key, ntype, ...)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('door_title'),
        description = locale(key, ...),
        type = ntype or 'error',
        duration = 4000
    })
end

local function vec(t) return vector3(t.x + 0.0, t.y + 0.0, t.z + 0.0) end
local function plain(v) return { x = v.x, y = v.y, z = v.z } end

local function isAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.AdminPermission)
end

local function rowToDoor(row)
    local doors = {}
    for _, d in ipairs(json.decode(row.doors) or {}) do
        doors[#doors + 1] = { hash = math.tointeger(d.hash) or d.hash, coords = vec(d.coords), object = math.tointeger(d.object), heading = tonumber(d.heading) }
    end
    return {
        id = row.id,
        name = row.name,
        doors = doors,
        textCoords = vec(json.decode(row.text_coords)),
        jobs = json.decode(row.jobs) or {},
        distance = row.distance,
        locked = row.locked == 1 or row.locked == true,
        lockpick = (type(row.lockpick) == 'string' and row.lockpick ~= '') and row.lockpick or nil,
        region = (type(row.region) == 'string' and row.region ~= '') and row.region or nil,
        keyItem = (type(row.key_item) == 'string' and row.key_item ~= '') and row.key_item or nil,
        gangs = (type(row.gangs) == 'string' and row.gangs ~= '') and json.decode(row.gangs) or {},
        group = (type(row.group_name) == 'string' and row.group_name ~= '') and row.group_name or nil,
        openFrom = tonumber(row.open_from),
        openTo = tonumber(row.open_to)
    }
end

local function encodeDoors(doors)
    local out = {}
    for i, d in ipairs(doors) do out[i] = { hash = d.hash, coords = plain(d.coords), object = d.object, heading = d.heading } end
    return json.encode(out)
end

-- does the player belong to one of these gangs? (PlayerData.gang, then rsg-society)
local function inGang(src, Player, gangs)
    local gang = Player.PlayerData.gang
    for _, name in ipairs(gangs) do
        if gang and gang.name == name then return true end
    end
    if GetResourceState('rsg-society') == 'started' then
        local ok, g = pcall(function() return exports['rsg-society']:GetPlayerGang(src) end)
        if ok and g then
            for _, name in ipairs(gangs) do
                if g.name == name then return true end
            end
        end
    end
    return false
end

-- access = admin bypass, OR a listed job, OR a listed gang, OR carrying the key item
local function isAuthorized(src, Player, door)
    if Config.AdminBypass and isAdmin(src) then return true end
    local job = Player.PlayerData.job
    if job and #door.jobs > 0 and (job.onduty or not Config.RequireOnDuty) then
        for _, name in ipairs(door.jobs) do
            if name == job.name then return true end
        end
    end
    if #door.gangs > 0 and inGang(src, Player, door.gangs) then return true end
    if door.keyItem and exports['rsg-inventory']:HasItem(src, door.keyItem, 1) then return true end
    return false
end

-- dead or handcuffed players can't use doors (the client hides the prompt in these states too)
local function isIncapacitated(Player)
    local meta = Player.PlayerData.metadata or {}
    return meta.isdead or meta.ishandcuffed
end

-- server-side proximity check. Returns true when the player is close enough; logs and notifies when not.
local function checkDistance(src, doorID, door, logDenied)
    local dist = #(GetEntityCoords(GetPlayerPed(src)) - door.textCoords)
    if dist <= door.distance + Config.DistanceTolerance then return true end
    -- far beyond any latency margin = almost certainly a triggered event
    if dist > door.distance + 25.0 then
        Webhook.Security(src, locale('wh_sec_far', door.name, ('%.0f'):format(dist)), ('doorID = %d, distance = %.1fm'):format(doorID, dist))
    elseif logDenied then
        Webhook.Denied(src, door, locale('wh_reason_far'), dist)
    end
    notify(src, 'sv_too_far')
    return false
end

---------------------------------------------
-- database bootstrap + one-time config import
---------------------------------------------
local function importConfigDoors()
    local count = 0
    for _, c in ipairs(SeedDoors or {}) do
        local doors = {}
        if c.doors then
            for _, d in ipairs(c.doors) do
                doors[#doors + 1] = { hash = d.doorid, coords = d.objCoords or c.textCoords }
            end
        else
            doors[1] = { hash = c.doorid, coords = c.objCoords or c.textCoords }
        end
        MySQL.insert.await('INSERT INTO rsg_doorlocks (name, doors, text_coords, jobs, distance, locked) VALUES (?, ?, ?, ?, ?, ?)', {
            c.name or locale('imported_door_name', doors[1].hash),
            encodeDoors(doors),
            json.encode(plain(c.textCoords)),
            json.encode(c.authorizedJobs or {}),
            c.distance or Config.DefaultDistance,
            c.locked and 1 or 0
        })
        count = count + 1
    end
    if count > 0 then
        print(('[rsg-doorlock] imported %d seed doors into the database'):format(count))
        Webhook.System(locale('wh_imported'), locale('wh_imported_desc', count))
    end
end

CreateThread(function()
    if Config.AutoDatabase ~= false then
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `rsg_doorlocks` (
                `id` INT NOT NULL AUTO_INCREMENT,
                `name` VARCHAR(64) NOT NULL,
                `doors` LONGTEXT NOT NULL,
                `text_coords` LONGTEXT NOT NULL,
                `jobs` LONGTEXT NOT NULL,
                `distance` FLOAT NOT NULL DEFAULT 1.25,
                `locked` TINYINT(1) NOT NULL DEFAULT 1,
                `lockpick` VARCHAR(16) NULL DEFAULT NULL,
                `region` VARCHAR(32) NULL DEFAULT NULL,
                `key_item` VARCHAR(64) NULL DEFAULT NULL,
                `gangs` LONGTEXT NULL,
                `group_name` VARCHAR(32) NULL DEFAULT NULL,
                `open_from` TINYINT NULL DEFAULT NULL,
                `open_to` TINYINT NULL DEFAULT NULL,
                PRIMARY KEY (`id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]])
        -- tables made by an older version: add the new columns once (never destructive)
        for _, col in ipairs(OPTIONAL_COLUMNS) do
            local ok, err = pcall(function()
                if (MySQL.scalar.await('SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?', { 'rsg_doorlocks', col[1] }) or 0) == 0 then
                    MySQL.query.await(('ALTER TABLE `rsg_doorlocks` ADD COLUMN `%s` %s'):format(col[1], col[2]))
                    print(('[rsg-doorlock] added column rsg_doorlocks.%s'):format(col[1]))
                end
            end)
            if not ok then print(('^1[rsg-doorlock] could not add column %s: %s^7'):format(col[1], tostring(err))) end
        end
    end

    hasOptColumns = (MySQL.scalar.await('SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME IN (?, ?, ?, ?, ?, ?, ?)', {
        'rsg_doorlocks', 'lockpick', 'region', 'key_item', 'gangs', 'group_name', 'open_from', 'open_to' }) or 0) == #OPTIONAL_COLUMNS
    if not hasOptColumns then
        print('^3[rsg-doorlock] optional columns are missing, so lockpicking, key items, gangs, groups and schedules are off; run the ALTER TABLE lines at the top of installation/rsg_doorlocks.sql^7')
    end

    if Config.ImportConfigDoors and (MySQL.scalar.await('SELECT COUNT(*) FROM rsg_doorlocks') or 0) == 0 then
        importConfigDoors()
    end

    for _, row in ipairs(MySQL.query.await('SELECT * FROM rsg_doorlocks') or {}) do
        Doors[row.id] = rowToDoor(row)
    end
    ready = true
    local total = 0
    for _ in pairs(Doors) do total = total + 1 end
    Webhook.System(locale('wh_started'), locale('wh_started_desc', total))
    TriggerClientEvent('rsg-doorlock:client:syncAll', -1, Doors)
end)

RSGCore.Functions.CreateCallback('rsg-doorlock:server:getDoors', function(_, cb)
    local waited = 0
    while not ready and waited < 60000 do Wait(100) waited = waited + 100 end
    cb(ready and Doors or nil)
end)

-- the client prompt asks this so players without access see "No key" instead of a prompt that fails
RSGCore.Functions.CreateCallback('rsg-doorlock:server:canUse', function(src, cb, doorID)
    local door = type(doorID) == 'number' and Doors[doorID]
    local Player = door and RSGCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end
    local now = GetGameTimer()
    if lastAccess[src] and now - lastAccess[src] < 200 then return cb(nil) end -- nil = unknown, the client asks again
    lastAccess[src] = now
    cb(isAuthorized(src, Player, door))
end)

---------------------------------------------
-- lock state (used by players, groups, the schedule, lockpicking and exports)
---------------------------------------------
-- persist = write the state to the database; delay = ms before clients see it (key animation)
local function setLockState(doorID, locked, persist, delay)
    local door = Doors[doorID]
    if not door then return false end
    door.locked = locked
    relockToken[doorID] = (relockToken[doorID] or 0) + 1 -- cancels a pending auto-relock
    if persist then MySQL.update('UPDATE rsg_doorlocks SET locked = ? WHERE id = ?', { locked and 1 or 0, doorID }) end
    local function push()
        local d = Doors[doorID]
        if not d then return end
        TriggerClientEvent('rsg-doorlock:client:setState', -1, doorID, d.locked)
        TriggerEvent('rsg-doorlock:server:stateChanged', doorID, d.locked)
    end
    if delay and delay > 0 then SetTimeout(delay, push) else push() end
    return true
end

-- every lock id that shares this group (the lock itself when it has none)
local function groupMembers(doorID, door)
    if not door.group then return { doorID } end
    local out = {}
    for id, d in pairs(Doors) do
        if d.group == door.group then out[#out + 1] = id end
    end
    return out
end

---------------------------------------------
-- using doors
---------------------------------------------
RegisterNetEvent('rsg-doorlock:server:requestToggle', function(doorID)
    local src = source
    if not ready then return end
    local door = type(doorID) == 'number' and Doors[doorID]
    if not door then
        return Webhook.Security(src, locale('wh_sec_nodoor'), ('doorID = %s (%s)'):format(tostring(doorID), type(doorID)))
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = GetGameTimer()
    if lastUse[src] and now - lastUse[src] < Config.Cooldown then return end
    lastUse[src] = now

    if isIncapacitated(Player) then return end
    if not checkDistance(src, doorID, door, true) then return end
    if not isAuthorized(src, Player, door) then
        Webhook.Denied(src, door, locale('wh_reason_nokey'))
        return notify(src, 'sv_nokey')
    end

    -- locks in the same group follow the lock that was used
    local newState = not door.locked
    for _, id in ipairs(groupMembers(doorID, door)) do setLockState(id, newState, true, 1000) end
    Webhook.DoorUsed(src, door, newState)
    TriggerClientEvent('rsg-doorlock:client:playKeyAnim', src, doorID)
    notify(src, newState and 'sv_locked' or 'sv_unlocked', 'success')
end)

---------------------------------------------
-- lockpicking (rsg-lockpick)
---------------------------------------------
-- a picked door is unlocked in memory only (the database keeps the saved state), then locks again by itself
local function scheduleRelock(doorID)
    local token = (relockToken[doorID] or 0) + 1
    relockToken[doorID] = token
    local secs = tonumber(Config.Lockpick.RelockAfter) or 0
    if secs <= 0 then return end
    SetTimeout(secs * 1000, function()
        local d = Doors[doorID]
        if d and relockToken[doorID] == token and not d.locked then setLockState(doorID, true, false) end
    end)
end

RegisterNetEvent('rsg-doorlock:server:requestLockpick', function(doorID)
    local src = source
    if not ready or not Config.Lockpick.Enabled or not hasOptColumns then return end
    local door = type(doorID) == 'number' and Doors[doorID]
    if not door then
        return Webhook.Security(src, locale('wh_sec_nodoor'), ('doorID = %s (%s)'):format(tostring(doorID), type(doorID)))
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local now = GetGameTimer()
    -- an attempt that never reported back (client crash, expired ticket) must not block the player forever
    if picking[src] and now - picking[src] < PICK_TIMEOUT then return end
    if lastPick[src] and now - lastPick[src] < Config.Lockpick.Cooldown then return end
    lastPick[src] = now

    if isIncapacitated(Player) then return end

    if not door.lockpick or not door.locked then return notify(src, 'sv_pick_notpickable') end
    if GetResourceState('rsg-lockpick') ~= 'started' then return notify(src, 'sv_pick_unavailable') end

    if not checkDistance(src, doorID, door, false) then return end
    -- someone with a key just uses the door
    if isAuthorized(src, Player, door) then return notify(src, 'sv_pick_haskey', 'inform') end

    local data = {
        preset = door.lockpick,
        coords = door.textCoords,
        radius = door.distance + Config.DistanceTolerance,
    }
    if Config.Lockpick.Alert ~= nil then data.alert = Config.Lockpick.Alert end -- lawman alert chance (false = none)
    if Config.Lockpick.Reputation then
        data.reputation = { action = Config.Lockpick.Reputation, region = door.region }
    end

    picking[src] = now
    local ok, err = pcall(function()
        exports['rsg-lockpick']:StartAttempt(src, data, function(success, reason)
            picking[src] = nil
            local d = Doors[doorID] -- may have been edited or deleted while picking
            if not d then return end
            if success then
                if not d.locked then return end -- someone with a key opened it first
                setLockState(doorID, false, false)
                scheduleRelock(doorID)
                Webhook.Lockpick(src, d, true)
                notify(src, 'sv_pick_success', 'success')
            elseif reason == 'fail' or reason == 'too_fast' or reason == 'too_far' then
                Webhook.Lockpick(src, d, false)
                notify(src, 'sv_pick_fail')
            end
        end)
    end)
    if not ok then
        picking[src] = nil
        print(('^1[rsg-doorlock] rsg-lockpick StartAttempt failed: %s^7'):format(tostring(err)))
    end
end)

---------------------------------------------
-- opening hours (open_from .. open_to, game hours)
---------------------------------------------
local function isOpenAt(door, hour)
    local from, to = door.openFrom, door.openTo
    if from < to then return hour >= from and hour < to end
    return hour >= from or hour < to -- window runs past midnight
end

local function currentHour()
    if Config.Schedule.UseGameTime and GetResourceState('rsg-weather') == 'started' then
        local ok, tm = pcall(function() return exports['rsg-weather']:getTime() end)
        if ok and type(tm) == 'table' and tm.hour then return tm.hour end
    end
    return tonumber(os.date('%H'))
end

CreateThread(function()
    while not ready do Wait(500) end
    while true do
        if Config.Schedule.Enabled and hasOptColumns then
            local hour = currentHour()
            for id, door in pairs(Doors) do
                if door.openFrom and door.openTo then
                    local open = isOpenAt(door, hour)
                    -- only act when the schedule changes, so a manual toggle holds until the next opening or closing
                    if scheduled[id] ~= open then
                        scheduled[id] = open
                        if door.locked == open then setLockState(id, not open, false) end
                    end
                end
            end
        end
        Wait((tonumber(Config.Schedule.CheckInterval) or 20) * 1000)
    end
end)

---------------------------------------------
-- exports for other resources (server only)
---------------------------------------------
local function summary(id, d)
    return { id = id, name = d.name, locked = d.locked, group = d.group, jobs = d.jobs, gangs = d.gangs, keyItem = d.keyItem, openFrom = d.openFrom, openTo = d.openTo }
end

exports('GetDoors', function()
    local out = {}
    for id, d in pairs(Doors) do out[#out + 1] = summary(id, d) end
    return out
end)

exports('GetDoor', function(id)
    id = tonumber(id)
    local d = id and Doors[id]
    return d and summary(id, d) or nil
end)

--- GetDoorIdByName('Valentine Sheriff - Front Door') -> id | nil (case-insensitive)
exports('GetDoorIdByName', function(name)
    if type(name) ~= 'string' then return nil end
    name = name:lower()
    for id, d in pairs(Doors) do
        if d.name:lower() == name then return id end
    end
end)

exports('IsLocked', function(id)
    local d = Doors[tonumber(id) or -1]
    return d and d.locked or nil
end)

--- SetLocked(id, locked, persist?) -> boolean. persist = also save the state to the database.
exports('SetLocked', function(id, locked, persist)
    id = tonumber(id)
    if not id or type(locked) ~= 'boolean' then return false end
    return setLockState(id, locked, persist == true)
end)
exports('LockDoor',   function(id, persist) return setLockState(tonumber(id) or -1, true,  persist == true) end)
exports('UnlockDoor', function(id, persist) return setLockState(tonumber(id) or -1, false, persist == true) end)

--- SetGroupLocked('valentine_sheriff', true, persist?) -> number of locks changed
exports('SetGroupLocked', function(group, locked, persist)
    if type(group) ~= 'string' or type(locked) ~= 'boolean' then return 0 end
    group = group:lower()
    local n = 0
    for id, d in pairs(Doors) do
        if d.group == group and setLockState(id, locked, persist == true) then n = n + 1 end
    end
    return n
end)

--- HasAccess(src, id) -> boolean (admin bypass, job, gang or key item)
exports('HasAccess', function(src, id)
    local d = Doors[tonumber(id) or -1]
    local Player = d and RSGCore.Functions.GetPlayer(src)
    return Player ~= nil and isAuthorized(src, Player, d)
end)

---------------------------------------------
-- admin editor
---------------------------------------------
RSGCore.Commands.Add(Config.AdminCommand, locale('cmd_help'), {}, false, function(source)
    TriggerClientEvent('rsg-doorlock:client:openEditor', source)
end, Config.AdminPermission)

RSGCore.Functions.CreateCallback('rsg-doorlock:server:admin:check', function(src, cb)
    cb(isAdmin(src))
end)

-- finite number inside the map bounds (rejects NaN / inf / absurd values)
local function validCoord(n)
    return type(n) == 'number' and n == n and math.abs(n) < 20000.0
end

-- returns the lock (other than ignoreId) that already uses one of these hashes
local function findHashOwner(doors, ignoreId)
    for id, lock in pairs(Doors) do
        if id ~= ignoreId then
            for _, a in ipairs(lock.doors) do
                for _, b in ipairs(doors) do
                    if a.hash == b.hash then return lock, b.hash end
                end
            end
        end
    end
end

-- validates and normalises a door coming from the NUI; returns door or nil, errorKey
local function sanitise(data)
    if type(data) ~= 'table' then return nil, 'err_invalid' end

    local name = type(data.name) == 'string' and data.name:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if #name < 1 or #name > 64 then return nil, 'err_name' end

    if type(data.doors) ~= 'table' or #data.doors < 1 then return nil, 'err_no_doors' end
    if #data.doors > Config.MaxDoorsPerLock then return nil, 'err_too_many' end

    local doors, sum, seen = {}, vector3(0, 0, 0), {}
    for _, d in ipairs(data.doors) do
        local c = type(d) == 'table' and d.coords
        local hash = type(d) == 'table' and math.tointeger(d.hash)
        if not hash or type(c) ~= 'table' or not validCoord(c.x) or not validCoord(c.y) or not validCoord(c.z) then
            return nil, 'err_invalid'
        end
        if not seen[hash] then
            seen[hash] = true
            local v = vec(c)
            local object = math.tointeger(d.object)
            local heading = tonumber(d.heading)
            if heading and (heading ~= heading or heading < -360.0 or heading > 360.0) then heading = nil end
            if object and not Config.AllowCustomDoors then return nil, 'err_invalid' end
            doors[#doors + 1] = { hash = hash, coords = v, object = object, heading = object and heading or nil }
            sum = sum + v
        end
    end

    local function nameList(list)
        local out = {}
        if type(list) == 'table' then
            for _, j in ipairs(list) do
                if type(j) == 'string' and j:match('^[%w_%-]+$') and #j <= 50 and #out < 25 then out[#out + 1] = j end
            end
        end
        return out
    end
    local jobs, gangs = nameList(data.jobs), nameList(data.gangs)

    -- optional key item: anyone carrying it can use the lock
    local keyItem
    if type(data.keyItem) == 'string' then
        local k = data.keyItem:gsub('^%s+', ''):gsub('%s+$', ''):lower()
        if k ~= '' then
            if not RSGCore.Shared.Items[k] then return nil, 'err_key_item' end
            keyItem = k
        end
    end

    -- optional group: locks sharing a name lock and unlock together
    local group
    if type(data.group) == 'string' then
        local g = data.group:gsub('^%s+', ''):gsub('%s+$', ''):lower()
        if g ~= '' then
            if #g > 32 or not g:match('^[%w_%-]+$') then return nil, 'err_group' end
            group = g
        end
    end

    -- optional opening hours: both set, two different whole hours 0-23
    local openFrom, openTo
    local function isSet(v) return v ~= nil and tostring(v) ~= '' end
    if isSet(data.openFrom) or isSet(data.openTo) then
        openFrom, openTo = math.tointeger(tonumber(data.openFrom)), math.tointeger(tonumber(data.openTo))
        if not openFrom or not openTo or openFrom == openTo or openFrom < 0 or openFrom > 23 or openTo < 0 or openTo > 23 then
            return nil, 'err_schedule'
        end
    end

    local distance = tonumber(data.distance) or Config.DefaultDistance
    distance = math.min(math.max(distance, 0.5), 10.0)

    -- lockpick difficulty: empty = not pickable, otherwise one of Config.Lockpick.Presets
    local lockpick
    if data.lockpick ~= nil and data.lockpick ~= '' then
        local allowed = false
        for _, p in ipairs(Config.Lockpick.Presets) do if p == data.lockpick then allowed = true break end end
        if type(data.lockpick) ~= 'string' or not allowed then return nil, 'err_lockpick' end
        lockpick = data.lockpick
    end

    -- rsg-reputation region that sees a picked lock as theft (optional)
    local region
    if type(data.region) == 'string' then
        local r = data.region:gsub('^%s+', ''):gsub('%s+$', ''):lower()
        if r ~= '' then
            if #r > 32 or not r:match('^[%l%d_]+$') then return nil, 'err_region' end
            if GetResourceState('rsg-reputation') == 'started' then
                local ok, regions = pcall(function() return exports['rsg-reputation']:GetRegions() end)
                if ok and type(regions) == 'table' and not regions[r] then return nil, 'err_region' end
            end
            region = r
        end
    end

    return {
        name = name,
        doors = doors,
        textCoords = sum / #doors + vector3(0.0, 0.0, 1.0),
        jobs = jobs,
        gangs = gangs,
        keyItem = keyItem,
        group = group,
        openFrom = openFrom,
        openTo = openTo,
        distance = distance,
        locked = data.locked == true,
        lockpick = lockpick,
        region = region
    }
end

local function saveDoor(src, data)
    if not isAdmin(src) then
        Webhook.Security(src, locale('wh_sec_save'), json.encode(data) or '?')
        return false, 'err_perm'
    end
    local door, err = sanitise(data)
    if not door then return false, err end

    local id = tonumber(data.id)
    if id and not Doors[id] then return false, 'err_invalid' end

    local owner, hash = findHashOwner(door.doors, id)
    if owner then return false, 'err_door_in_use', hash, owner.name end

    -- nil can't sit inside a parameter list, so empty values travel as '' / -1 and NULLIF turns them back into NULL
    local cols = { 'name', 'doors', 'text_coords', 'jobs', 'distance', 'locked' }
    local marks = { '?', '?', '?', '?', '?', '?' }
    local params = {
        door.name, encodeDoors(door.doors), json.encode(plain(door.textCoords)),
        json.encode(door.jobs), door.distance, door.locked and 1 or 0
    }
    if hasOptColumns then
        for _, c in ipairs({
            { 'lockpick',   "NULLIF(?, '')", door.lockpick or '' },
            { 'region',     "NULLIF(?, '')", door.region or '' },
            { 'key_item',   "NULLIF(?, '')", door.keyItem or '' },
            { 'gangs',      '?',             json.encode(door.gangs) },
            { 'group_name', "NULLIF(?, '')", door.group or '' },
            { 'open_from',  'NULLIF(?, -1)', door.openFrom or -1 },
            { 'open_to',    'NULLIF(?, -1)', door.openTo or -1 },
        }) do
            cols[#cols + 1], marks[#marks + 1], params[#params + 1] = c[1], c[2], c[3]
        end
    else
        -- columns missing: the optional features stay off
        door.lockpick, door.region, door.keyItem, door.group, door.openFrom, door.openTo = nil, nil, nil, nil, nil, nil
        door.gangs = {}
    end
    if id then
        local sets = {}
        for i, col in ipairs(cols) do sets[i] = ('%s = %s'):format(col, marks[i]) end
        params[#params + 1] = id
        MySQL.update.await('UPDATE rsg_doorlocks SET ' .. table.concat(sets, ', ') .. ' WHERE id = ?', params)
    else
        id = MySQL.insert.await(('INSERT INTO rsg_doorlocks (%s) VALUES (%s)'):format(table.concat(cols, ', '), table.concat(marks, ', ')), params)
        if not id then return false, 'err_invalid' end
    end

    door.id = id
    local old = Doors[id]
    Doors[id] = door
    relockToken[id] = (relockToken[id] or 0) + 1
    scheduled[id] = nil -- re-apply the opening hours on the next check
    TriggerClientEvent('rsg-doorlock:client:syncDoor', -1, id, door, old)
    print(('[rsg-doorlock] %s (%s) saved door #%d "%s"'):format(GetPlayerName(src), src, id, door.name))
    Webhook.AdminSaved(src, door, old)
    return true, id
end

RSGCore.Functions.CreateCallback('rsg-doorlock:server:admin:save', function(src, cb, data)
    cb(saveDoor(src, data))
end)

local function deleteDoor(src, id)
    if not isAdmin(src) then
        Webhook.Security(src, locale('wh_sec_delete'), ('id = %s'):format(tostring(id)))
        return false
    end
    id = tonumber(id)
    local old = id and Doors[id]
    if not old then return false end
    MySQL.query.await('DELETE FROM rsg_doorlocks WHERE id = ?', { id })
    Doors[id] = nil
    relockToken[id] = nil
    scheduled[id] = nil
    TriggerClientEvent('rsg-doorlock:client:syncDoor', -1, id, nil, old)
    print(('[rsg-doorlock] %s (%s) deleted door #%d "%s"'):format(GetPlayerName(src), src, id, old.name))
    Webhook.AdminDeleted(src, old)
    return true
end

RSGCore.Functions.CreateCallback('rsg-doorlock:server:admin:delete', function(src, cb, id)
    cb(deleteDoor(src, id))
end)

-- teleport is done client side; this only logs it (admins only)
RegisterNetEvent('rsg-doorlock:server:admin:teleported', function(id)
    local src = source
    if not isAdmin(src) then
        return Webhook.Security(src, locale('wh_sec_teleport'), ('id = %s'):format(tostring(id)))
    end
    local door = Doors[tonumber(id) or -1]
    if door then Webhook.AdminTeleport(src, door) end
end)

AddEventHandler('playerDropped', function()
    lastUse[source] = nil
    lastPick[source] = nil
    picking[source] = nil
    lastAccess[source] = nil
end)
