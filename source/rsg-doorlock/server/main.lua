local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- Doors[id] = { id, name, doors = { {hash, coords}, ... }, textCoords, jobs = {}, distance, locked }
local Doors = {}
local lastUse = {}
local ready = false

---------------------------------------------
-- helpers
---------------------------------------------
local function notify(src, key, ntype, ...)
    TriggerClientEvent('ox_lib:notify', src, {
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
        locked = row.locked == 1 or row.locked == true
    }
end

local function encodeDoors(doors)
    local out = {}
    for i, d in ipairs(doors) do out[i] = { hash = d.hash, coords = plain(d.coords), object = d.object, heading = d.heading } end
    return json.encode(out)
end

local function isAuthorized(src, Player, door)
    if Config.AdminBypass and isAdmin(src) then return true end
    local job = Player.PlayerData.job
    if not job then return false end
    if Config.RequireOnDuty and not job.onduty then return false end
    for _, name in ipairs(door.jobs) do
        if name == job.name then return true end
    end
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
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rsg_doorlocks` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(64) NOT NULL,
            `doors` LONGTEXT NOT NULL,
            `text_coords` LONGTEXT NOT NULL,
            `jobs` LONGTEXT NOT NULL,
            `distance` FLOAT NOT NULL DEFAULT 1.25,
            `locked` TINYINT(1) NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

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

lib.callback.register('rsg-doorlock:server:getDoors', function()
    while not ready do Wait(100) end
    return Doors
end)

---------------------------------------------
-- using doors
---------------------------------------------
RegisterNetEvent('rsg-doorlock:server:requestToggle', function(doorID)
    local src = source
    if not ready then return end
    local door = type(doorID) == 'number' and Doors[doorID]
    if not door then
        return Webhook.Security(source, locale('wh_sec_nodoor'), ('doorID = %s (%s)'):format(tostring(doorID), type(doorID)))
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = GetGameTimer()
    if lastUse[src] and now - lastUse[src] < Config.Cooldown then return end
    lastUse[src] = now

    local dist = #(GetEntityCoords(GetPlayerPed(src)) - door.textCoords)
    if dist > door.distance + Config.DistanceTolerance then
        -- far beyond any latency margin = almost certainly a triggered event
        if dist > door.distance + 25.0 then
            Webhook.Security(src, locale('wh_sec_far', door.name, ('%.0f'):format(dist)), ('doorID = %d, distance = %.1fm'):format(doorID, dist))
        else
            Webhook.Denied(src, door, locale('wh_reason_far'), dist)
        end
        return notify(src, 'sv_too_far')
    end
    if not isAuthorized(src, Player, door) then
        Webhook.Denied(src, door, locale('wh_reason_nokey'))
        return notify(src, 'sv_nokey')
    end

    local newState = not door.locked
    door.locked = newState
    MySQL.update('UPDATE rsg_doorlocks SET locked = ? WHERE id = ?', { newState and 1 or 0, doorID })
    Webhook.DoorUsed(src, door, newState)
    TriggerClientEvent('rsg-doorlock:client:playKeyAnim', src, doorID)
    notify(src, newState and 'sv_locked' or 'sv_unlocked', 'success')
    SetTimeout(1000, function()
        TriggerClientEvent('rsg-doorlock:client:setState', -1, doorID, newState)
    end)
end)

---------------------------------------------
-- admin editor
---------------------------------------------
RSGCore.Commands.Add(Config.AdminCommand, locale('cmd_help'), {}, false, function(source)
    TriggerClientEvent('rsg-doorlock:client:openEditor', source)
end, Config.AdminPermission)

lib.callback.register('rsg-doorlock:server:admin:check', function(src)
    return isAdmin(src)
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

    local jobs = {}
    if type(data.jobs) == 'table' then
        for _, j in ipairs(data.jobs) do
            if type(j) == 'string' and j:match('^[%w_%-]+$') and #j <= 50 and #jobs < 25 then
                jobs[#jobs + 1] = j
            end
        end
    end

    local distance = tonumber(data.distance) or Config.DefaultDistance
    distance = math.min(math.max(distance, 0.5), 10.0)

    return {
        name = name,
        doors = doors,
        textCoords = sum / #doors + vector3(0.0, 0.0, 1.0),
        jobs = jobs,
        distance = distance,
        locked = data.locked == true
    }
end

lib.callback.register('rsg-doorlock:server:admin:save', function(src, data)
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

    local params = {
        door.name, encodeDoors(door.doors), json.encode(plain(door.textCoords)),
        json.encode(door.jobs), door.distance, door.locked and 1 or 0
    }
    if id then
        params[#params + 1] = id
        MySQL.update.await('UPDATE rsg_doorlocks SET name = ?, doors = ?, text_coords = ?, jobs = ?, distance = ?, locked = ? WHERE id = ?', params)
    else
        id = MySQL.insert.await('INSERT INTO rsg_doorlocks (name, doors, text_coords, jobs, distance, locked) VALUES (?, ?, ?, ?, ?, ?)', params)
        if not id then return false, 'err_invalid' end
    end

    door.id = id
    local old = Doors[id]
    Doors[id] = door
    TriggerClientEvent('rsg-doorlock:client:syncDoor', -1, id, door, old)
    print(('[rsg-doorlock] %s (%s) saved door #%d "%s"'):format(GetPlayerName(src), src, id, door.name))
    Webhook.AdminSaved(src, door, old)
    return true, id
end)

lib.callback.register('rsg-doorlock:server:admin:delete', function(src, id)
    if not isAdmin(src) then
        Webhook.Security(src, locale('wh_sec_delete'), ('id = %s'):format(tostring(id)))
        return false
    end
    id = tonumber(id)
    local old = id and Doors[id]
    if not old then return false end
    MySQL.query.await('DELETE FROM rsg_doorlocks WHERE id = ?', { id })
    Doors[id] = nil
    TriggerClientEvent('rsg-doorlock:client:syncDoor', -1, id, nil, old)
    print(('[rsg-doorlock] %s (%s) deleted door #%d "%s"'):format(GetPlayerName(src), src, id, old.name))
    Webhook.AdminDeleted(src, old)
    return true
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
end)
