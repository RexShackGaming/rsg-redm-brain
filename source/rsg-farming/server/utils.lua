-- shared server helpers for rsg-farming (loaded before server.lua)
local RSGCore = exports['rsg-core']:GetCoreObject()

Utils = {}

-- rsg-core callback that lets handlers `return ok, msg` like before.
-- A handler error is logged and answered with a failure, so the client never waits for the timeout.
function Utils.callback(name, fn)
    RSGCore.Functions.CreateCallback(name, function(source, cb, ...)
        local res = table.pack(pcall(fn, source, ...))
        if not res[1] then
            print(('^1[rsg-farming] callback %s failed: %s^7'):format(name, tostring(res[2])))
            return cb(false, locale('action_invalid'))
        end
        cb(table.unpack(res, 2, res.n))
    end)
end

function Utils.notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('farming'), description = desc, type = ntype or 'inform', duration = 4000,
    })
end

function Utils.getPlayer(src)
    return RSGCore.Functions.GetPlayer(src)
end

function Utils.distanceTo(src, x, y, z)
    return #(GetEntityCoords(GetPlayerPed(src)) - vector3(x, y, z))
end

local function finite(v) return v and v == v and v ~= math.huge and v ~= -math.huge end

-- accepts a vector3/table from the client, rejects NaN/inf and non-numbers
function Utils.toCoords(c)
    local t = type(c)
    if t ~= 'vector3' and t ~= 'table' then return nil end
    local x, y, z = tonumber(c.x), tonumber(c.y), tonumber(c.z)
    if not (finite(x) and finite(y) and finite(z)) then return nil end
    return vector3(x, y, z)
end

function Utils.toHeading(h)
    h = tonumber(h)
    if not finite(h) then return 0.0 end
    return h % 360
end

---------------------------------
-- items
---------------------------------
function Utils.hasItem(src, item)
    return (exports['rsg-inventory']:GetItemCount(src, item) or 0) > 0
end

function Utils.canAdd(src, item, amount)
    if not RSGCore.Shared.Items[item] then return false end
    local ok, res = pcall(function() return exports['rsg-inventory']:CanAddItem(src, item, amount or 1) end)
    return ok and res ~= false
end

-- strict check that ALL items fit together (combined weight + free slots), not just one at a time
-- list = { { item = 'corn', amount = 3 }, ... }
function Utils.canAddAll(src, list)
    local inv = exports['rsg-inventory']
    local weight, slotsNeeded, seen = 0, 0, {}
    for _, r in ipairs(list) do
        local shared = RSGCore.Shared.Items[r.item]
        if not shared or not Utils.canAdd(src, r.item, r.amount) then return false end
        weight = weight + (tonumber(shared.weight) or 0) * r.amount
        if shared.unique then
            slotsNeeded = slotsNeeded + r.amount
        elseif not seen[r.item] then
            seen[r.item] = true
            if (inv:GetItemCount(src, r.item) or 0) <= 0 then slotsNeeded = slotsNeeded + 1 end
        end
    end
    if weight > (inv:GetFreeWeight(src) or 0) then return false end
    local _, freeSlots = inv:GetSlots(src)
    return slotsNeeded <= (freeSlots or 0)
end

-- rsg-inventory shows the ItemBox itself, so no manual ItemBox events here
function Utils.removeItem(src, item, amount, slot, reason)
    return exports['rsg-inventory']:RemoveItem(src, item, amount or 1, slot, reason) and true or false
end

function Utils.addItem(src, item, amount, info, reason, slot)
    amount = amount or 1
    if amount <= 0 or not Utils.canAdd(src, item, amount) then return false end
    return exports['rsg-inventory']:AddItem(src, item, amount, info, slot, reason) and true or false
end

-- gives the item, or drops it at the player's feet if it no longer fits (never silently lost)
function Utils.giveOrDrop(src, item, amount, info, reason, slot)
    if Utils.addItem(src, item, amount, info, reason, slot) then return true end
    exports['rsg-inventory']:ForceDropItem(src, item, amount, nil, reason)
    return false
end

---------------------------------
-- action tokens: the server starts a timer at the pre-check and only
-- accepts the action once the progress bar could really have finished.
-- Stops clients from skipping the animation / spamming callbacks.
---------------------------------
local Pending = {}

function Utils.startAction(src, key, durationMs)
    Pending[src] = { key = key, t = GetGameTimer(), min = math.floor((durationMs or 0) * 0.8) }
end

function Utils.finishAction(src, key)
    local p = Pending[src]
    Pending[src] = nil
    return p ~= nil and p.key == key and (GetGameTimer() - p.t) >= p.min
end

AddEventHandler('playerDropped', function()
    Pending[source] = nil
end)

---------------------------------
-- database (Config.AutoDatabase = false -> import install.sql manually)
---------------------------------
local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `rsg_farming_plants` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `crop` VARCHAR(50) NOT NULL,
        `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL, `h` FLOAT NOT NULL DEFAULT 0,
        `growth` FLOAT NOT NULL DEFAULT 0,
        `water` FLOAT NOT NULL DEFAULT 0,
        `fertilizer` FLOAT NOT NULL DEFAULT 0,
        `health` FLOAT NOT NULL DEFAULT 100,
        `dead` TINYINT(1) NOT NULL DEFAULT 0,
        `dead_time` INT(11) NOT NULL DEFAULT 0,
        `share_key` VARCHAR(80) NOT NULL DEFAULT '',
        `planted_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]],
    [[CREATE TABLE IF NOT EXISTS `rsg_farming_props` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `kind` VARCHAR(20) NOT NULL,
        `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL, `h` FLOAT NOT NULL DEFAULT 0,
        `pump_id` INT(11) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]],
    [[CREATE TABLE IF NOT EXISTS `rsg_farming_soil` (
        `cell_x` INT(11) NOT NULL,
        `cell_y` INT(11) NOT NULL,
        `crop` VARCHAR(50) NOT NULL,
        `fatigue` FLOAT NOT NULL DEFAULT 0,
        `updated` INT(11) NOT NULL DEFAULT 0,
        PRIMARY KEY (`cell_x`, `cell_y`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]],
}

-- columns added after 3.4.0: existing tables get them without touching any data
local COLUMNS = {
    { 'rsg_farming_plants', 'share_key', "`share_key` VARCHAR(80) NOT NULL DEFAULT '' AFTER `dead_time`" },
}

local function ensureDatabase()
    for _, sql in ipairs(SCHEMA) do
        local ok, err = pcall(MySQL.query.await, sql)
        if not ok then
            print(('^1[rsg-farming] database setup failed: %s^7'):format(tostring(err)))
            return false
        end
    end
    for _, c in ipairs(COLUMNS) do
        local ok, count = pcall(MySQL.scalar.await,
            'SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
            { c[1], c[2] })
        if not ok then
            print(('^1[rsg-farming] database setup failed: %s^7'):format(tostring(count)))
            return false
        end
        if (tonumber(count) or 0) == 0 then
            local ok2, err = pcall(MySQL.query.await, ('ALTER TABLE `%s` ADD COLUMN %s'):format(c[1], c[3]))
            if not ok2 then
                print(('^1[rsg-farming] database setup failed: %s^7'):format(tostring(err)))
                return false
            end
        end
    end
    print('^2[rsg-farming] database tables ready^7')
    return true
end

-- nil = still starting, true = ready, false = failed (server.lua waits on this)
CreateThread(function()
    if Config.AutoDatabase then
        Utils.DBReady = ensureDatabase()
    else
        Utils.DBReady = true
    end
end)

---------------------------------
-- config sanity check: warn about items that don't exist in rsg-core
---------------------------------
CreateThread(function()
    Wait(3000)
    local missing = {}
    local function chk(name)
        if name and not RSGCore.Shared.Items[name] then missing[name] = true end
    end
    for _, crop in pairs(Config.Crops) do
        chk(crop.seed)
        for _, r in ipairs(crop.harvest) do chk(r.item) end
    end
    chk(Config.WaterItem); chk(Config.PlantTool)
    for _, f in ipairs(Config.Fertilizers or {}) do chk(f.item) end
    if Config.Pests.enabled then chk(Config.Pests.item) end
    if Config.Scarecrow and Config.Scarecrow.enabled then chk(Config.Scarecrow.item) end
    if Config.Sprinkler and Config.Sprinkler.enabled then chk(Config.Sprinkler.item) end

    local names = {}
    for name in pairs(missing) do names[#names + 1] = name end
    table.sort(names)
    if #names > 0 then
        print(('^3[rsg-farming] items missing from rsg-core shared items: %s^7'):format(table.concat(names, ', ')))
    end
end)
