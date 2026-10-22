local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local WP       = Config.WellPump
local Pumps    = {}   -- [id] = { id, citizenid, x, y, z, h }
local Reserved = {}   -- [src] = vector3 while a placement insert is awaiting the DB
local Loaded   = false

local function list()
    local out = {}
    for _, p in pairs(Pumps) do out[#out + 1] = p end
    return out
end

local function syncAll()
    TriggerClientEvent('rsg-farming:client:syncPumps', -1, list())
end

local function countPumps(cid)
    local n = 0
    for _, p in pairs(Pumps) do if p.citizenid == cid then n = n + 1 end end
    return n
end

-- player + pump + distance check -> Player, pump | nil, nil, err
local function validate(src, pumpId)
    local Player = Utils.getPlayer(src)
    if not Player then return nil, nil, locale('no_player') end
    local pump = Pumps[tonumber(pumpId)]
    if not pump then return nil, nil, locale('pump_missing') end
    if Utils.distanceTo(src, pump.x, pump.y, pump.z) > WP.interactDist + 2.0 then
        return nil, nil, locale('too_far')
    end
    return Player, pump
end

---------------------------------
-- rules per action (shared by pre-check and the action itself)
---------------------------------
local Rules = {
    fill = function(src, Player)
        if not Utils.hasItem(Player, WP.emptyItem) then return locale('pump_no_bucket') end
        if not Utils.canAdd(src, WP.fullItem, 1) then return locale('inv_full') end
    end,
    pack = function(src, Player, pump)
        if WP.ownerOnlyPackup and pump.citizenid ~= Player.PlayerData.citizenid then return locale('pump_not_owner') end
        if not Utils.canAdd(src, WP.item, 1) then return locale('inv_full') end
    end,
}
local Durations = { fill = WP.fillTime, pack = WP.packTime }

local function checkAction(src, action, pumpId)
    local Player, pump, err = validate(src, pumpId)
    if not Player then return nil, nil, err end
    if not Utils.finishAction(src, ('pump_%s:%s'):format(action, pump.id)) then return nil, nil, locale('action_invalid') end
    err = Rules[action](src, Player, pump)
    if err then return nil, nil, err end
    return Player, pump
end

---------------------------------
-- database
---------------------------------
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rsg_farming_wellpumps` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL, `h` FLOAT NOT NULL DEFAULT 0,
            `placed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    local rows = MySQL.query.await('SELECT * FROM rsg_farming_wellpumps') or {}
    for _, r in ipairs(rows) do
        Pumps[r.id] = { id = r.id, citizenid = r.citizenid, x = r.x, y = r.y, z = r.z, h = r.h }
    end
    Loaded = true
    print(('[rsg-farming] loaded %d well pumps'):format(#rows))
    syncAll()
end)

lib.callback.register('rsg-farming:server:getPumps', function()
    while not Loaded do Wait(100) end
    return list()
end)

---------------------------------
-- usable item
---------------------------------
RSGCore.Functions.CreateUseableItem(WP.item, function(source)
    local Player = Utils.getPlayer(source)
    if not Player then return end
    if countPumps(Player.PlayerData.citizenid) >= WP.maxPerPlayer then
        return Utils.notify(source, locale('pump_max', WP.maxPerPlayer), 'error')
    end
    TriggerClientEvent('rsg-farming:client:placePump', source)
end)

---------------------------------
-- place
---------------------------------
lib.callback.register('rsg-farming:server:placePump', function(source, coords, heading)
    local src = source
    local Player = Utils.getPlayer(src)
    coords = Utils.toCoords(coords)
    if not Player or not coords then return false, locale('pump_place_invalid') end
    if Reserved[src] then return false, locale('action_invalid') end

    if Utils.distanceTo(src, coords.x, coords.y, coords.z) > Config.PlaceMaxDistance + 2.0 then
        return false, locale('place_too_far')
    end
    local cid = Player.PlayerData.citizenid
    if countPumps(cid) >= WP.maxPerPlayer then return false, locale('pump_max', WP.maxPerPlayer) end
    for _, p in pairs(Pumps) do
        if #(vector3(p.x, p.y, p.z) - coords) < WP.minDistance then return false, locale('pump_too_close') end
    end
    for _, r in pairs(Reserved) do
        if #(r - coords) < WP.minDistance then return false, locale('pump_too_close') end
    end
    if not Utils.removeItem(src, WP.item, 1, nil, 'rsg-farming:pump-place') then return false, locale('pump_no_item') end

    local h = Utils.toHeading(heading)
    Reserved[src] = coords
    local id = MySQL.insert.await('INSERT INTO rsg_farming_wellpumps (citizenid, x, y, z, h) VALUES (?, ?, ?, ?, ?)',
        { cid, coords.x, coords.y, coords.z, h })
    Reserved[src] = nil

    if not id then
        Utils.addItem(src, WP.item, 1, nil, 'rsg-farming:pump-refund')
        return false, locale('pump_place_invalid')
    end
    Pumps[id] = { id = id, citizenid = cid, x = coords.x, y = coords.y, z = coords.z, h = h }
    syncAll()
    return true, locale('pump_placed')
end)

---------------------------------
-- pre-check (starts the action timer)
---------------------------------
lib.callback.register('rsg-farming:server:pumpPrecheck', function(source, action, pumpId)
    if not Rules[action] then return false, locale('action_invalid') end
    local Player, pump, err = validate(source, pumpId)
    if not Player then return false, err end
    err = Rules[action](source, Player, pump)
    if err then return false, err end
    Utils.startAction(source, ('pump_%s:%s'):format(action, pump.id), Durations[action])
    return true
end)

---------------------------------
-- fill bucket
---------------------------------
lib.callback.register('rsg-farming:server:fillBucket', function(source, pumpId)
    local Player, _, err = checkAction(source, 'fill', pumpId)
    if not Player then return false, err end
    if not Utils.removeItem(source, WP.emptyItem, 1, nil, 'rsg-farming:fill') then return false, locale('pump_no_bucket') end

    local uses = WP.bucketUses or 5
    if not Utils.addItem(source, WP.fullItem, 1, { uses = uses, description = locale('bucket_uses', uses, uses) }, 'rsg-farming:fill') then
        Utils.addItem(source, WP.emptyItem, 1, nil, 'rsg-farming:fill-refund')
        return false, locale('inv_full')
    end
    return true, locale('pump_filled')
end)

---------------------------------
-- pack up
---------------------------------
lib.callback.register('rsg-farming:server:packPump', function(source, pumpId)
    local Player, pump, err = checkAction(source, 'pack', pumpId)
    if not Player then return false, err end

    Pumps[pump.id] = nil
    MySQL.query('DELETE FROM rsg_farming_wellpumps WHERE id = ?', { pump.id })
    Utils.addItem(source, WP.item, 1, nil, 'rsg-farming:pump-pack')
    syncAll()
    return true, locale('pump_packed')
end)
