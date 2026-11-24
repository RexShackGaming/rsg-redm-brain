local RSGCore = exports['rsg-core']:GetCoreObject()

local Pumps    = {}   -- [id] = { id, citizenid, x, y, z, h }
local Reserved = {}   -- [src] = vector3 while a placement insert is awaiting the database
local Pending  = {}   -- [src] = { key, t, min } action timer started by the pre-check
local DrinkedAt = {}  -- [src] = GetGameTimer() of the last drink
local Loaded   = false

---------------------------------
-- helpers
---------------------------------
local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('title'), description = desc, type = ntype or 'inform', duration = 4000,
    })
end

local function debugPrint(msg)
    if Config.Debug then print(('^3[rsg-wellpump]^7 %s'):format(msg)) end
end

local function toCoords(c)
    if type(c) ~= 'vector3' and type(c) ~= 'table' then return nil end
    local x, y, z = tonumber(c.x), tonumber(c.y), tonumber(c.z)
    for _, v in ipairs({ x, y, z }) do
        if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    end
    return vector3(x, y, z)
end

local function toHeading(h)
    h = tonumber(h)
    if not h or h ~= h or h == math.huge or h == -math.huge then return 0.0 end
    return h % 360
end

local function distanceTo(src, x, y, z)
    return #(GetEntityCoords(GetPlayerPed(src)) - vector3(x, y, z))
end

local function hasItem(src, item)
    return exports['rsg-inventory']:HasItem(src, item, 1) == true
end

local function canAdd(src, item, amount)
    if not RSGCore.Shared.Items[item] then return false end
    local ok, res = pcall(function() return exports['rsg-inventory']:CanAddItem(src, item, amount or 1) end)
    return not ok or res ~= false
end

local function removeItem(src, item, amount, slot, reason)
    return exports['rsg-inventory']:RemoveItem(src, item, amount or 1, slot, reason) == true
end

local function addItem(src, item, amount, info, reason, slot)
    amount = amount or 1
    if amount <= 0 or not canAdd(src, item, amount) then return false end
    return exports['rsg-inventory']:AddItem(src, item, amount, info, slot, reason) == true
end

-- gives the item, or drops it at the player's feet if it no longer fits (never silently lost)
local function giveOrDrop(src, item, amount, info, reason, slot)
    if addItem(src, item, amount, info, reason, slot) then return true end
    exports['rsg-inventory']:ForceDropItem(src, item, amount, nil, reason)
    return false
end

-- the item info a filled bucket carries; rsg-farming, rsg-ranch and anything else use these two fields
local function bucketInfo(uses)
    return { uses = uses, description = locale('bucket_uses', uses, Config.BucketUses) }
end

---------------------------------
-- bucket API (used by the exports below)
---------------------------------
-- Gives one empty bucket's worth of water: removes Config.EmptyItem, adds Config.FullItem with full uses.
local function fillBucket(src)
    if not RSGCore.Functions.GetPlayer(src) then return false, locale('action_invalid') end
    if not hasItem(src, Config.EmptyItem) then return false, locale('no_bucket') end
    if not canAdd(src, Config.FullItem, 1) then return false, locale('inv_full') end
    if not removeItem(src, Config.EmptyItem, 1, nil, 'rsg-wellpump:fill') then return false, locale('no_bucket') end

    if not addItem(src, Config.FullItem, 1, bucketInfo(Config.BucketUses), 'rsg-wellpump:fill') then
        giveOrDrop(src, Config.EmptyItem, 1, nil, 'rsg-wellpump:fill-refund')
        return false, locale('inv_full')
    end
    return true, locale('filled')
end

-- Step 1 of using water: takes the player's full bucket out of the inventory and returns a ticket.
local function takeBucketUse(src)
    local bucket = exports['rsg-inventory']:GetItemByName(src, Config.FullItem)
    if not bucket then return false, locale('no_water') end
    local info = bucket.info or {}
    local uses = tonumber(info.uses) or Config.BucketUses
    if not removeItem(src, Config.FullItem, 1, bucket.slot, 'rsg-wellpump:use') then return false, locale('no_water') end
    return true, { slot = bucket.slot, info = info, uses = uses }
end

-- Step 2a: the use succeeded. Gives the bucket back with one use less, or an empty bucket when it ran out.
local function commitBucketUse(src, ticket)
    if type(ticket) ~= 'table' then return false, 0 end
    local uses = tonumber(ticket.uses) or 1
    if uses <= 1 then
        if Config.EmptyItem then giveOrDrop(src, Config.EmptyItem, 1, nil, 'rsg-wellpump:use-empty') end
        return true, 0
    end
    local info = {}
    for k, v in pairs(ticket.info or {}) do info[k] = v end
    info.uses = uses - 1
    info.description = locale('bucket_uses', info.uses, Config.BucketUses)
    giveOrDrop(src, Config.FullItem, 1, info, 'rsg-wellpump:use', ticket.slot)
    return true, info.uses
end

-- Step 2b: the use failed. Gives the bucket back exactly as it was.
local function refundBucketUse(src, ticket)
    if type(ticket) ~= 'table' then return false end
    giveOrDrop(src, Config.FullItem, 1, ticket.info, 'rsg-wellpump:use-refund', ticket.slot)
    return true
end

---------------------------------
-- drinking
---------------------------------
local function drinkOnCooldown(src)
    local last = DrinkedAt[src]
    return last ~= nil and (GetGameTimer() - last) < Config.Drink.cooldown
end

-- Server side of a drink: enforces the cooldown, picks the thirst amount and tells the client to apply it.
local function drink(src)
    if not Config.Drink.enabled then return false, locale('action_invalid') end
    if not RSGCore.Functions.GetPlayer(src) then return false, locale('action_invalid') end
    if drinkOnCooldown(src) then return false, locale('drink_wait') end
    DrinkedAt[src] = GetGameTimer()
    local amount = math.random(Config.Drink.thirst.min, Config.Drink.thirst.max)
    TriggerClientEvent('rsg-wellpump:client:thirst', src, amount)
    return true, locale('drank'), amount
end

---------------------------------
-- action tokens: the server starts a timer at the pre-check and only accepts the action once
-- the progress bar could really have finished (stops animation skipping)
---------------------------------
local function startAction(src, key, durationMs)
    Pending[src] = { key = key, t = GetGameTimer(), min = math.floor((durationMs or 0) * 0.8) }
end

local function finishAction(src, key)
    local p = Pending[src]
    Pending[src] = nil
    return p ~= nil and p.key == key and (GetGameTimer() - p.t) >= p.min
end

AddEventHandler('playerDropped', function()
    local src = source
    Pending[src] = nil
    Reserved[src] = nil
    DrinkedAt[src] = nil
end)

---------------------------------
-- pumps
---------------------------------
local function list()
    local out = {}
    for _, p in pairs(Pumps) do out[#out + 1] = { id = p.id, x = p.x, y = p.y, z = p.z, h = p.h } end
    return out
end

local function idsOwnedBy(src)
    local out = {}
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return out end
    local cid = Player.PlayerData.citizenid
    for id, p in pairs(Pumps) do
        if p.citizenid == cid then out[#out + 1] = id end
    end
    return out
end

-- clients never receive citizenids: everyone gets the shared list, each player also gets the ids they own
local function syncPlayer(src)
    TriggerClientEvent('rsg-wellpump:client:sync', src, list(), idsOwnedBy(src))
end

local function syncAll()
    for _, src in ipairs(GetPlayers()) do syncPlayer(tonumber(src)) end
end

local function countPumps(cid)
    local n = 0
    for _, p in pairs(Pumps) do if p.citizenid == cid then n = n + 1 end end
    return n
end

local function validate(src, pumpId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil, nil, locale('action_invalid') end
    local pump = Pumps[tonumber(pumpId)]
    if not pump then return nil, nil, locale('missing') end
    if distanceTo(src, pump.x, pump.y, pump.z) > Config.InteractDist + 2.0 then
        return nil, nil, locale('too_far')
    end
    return Player, pump
end

local Rules = {
    fill = function(src)
        if not hasItem(src, Config.EmptyItem) then return locale('no_bucket') end
        if not canAdd(src, Config.FullItem, 1) then return locale('inv_full') end
    end,
    drink = function(src)
        if not Config.Drink.enabled then return locale('action_invalid') end
        if drinkOnCooldown(src) then return locale('drink_wait') end
    end,
    pack = function(src, Player, pump)
        if Config.OwnerOnlyPackup and pump.citizenid ~= Player.PlayerData.citizenid then return locale('not_owner') end
        if not canAdd(src, Config.Item, 1) then return locale('inv_full') end
    end,
}
local Durations = { fill = Config.FillTime, pack = Config.PackTime, drink = Config.Drink.time }

local function checkAction(src, action, pumpId)
    local Player, pump, err = validate(src, pumpId)
    if not Player then return nil, nil, err end
    if not finishAction(src, ('%s:%s'):format(action, pump.id)) then return nil, nil, locale('action_invalid') end
    err = Rules[action](src, Player, pump)
    if err then return nil, nil, err end
    return Player, pump
end

---------------------------------
-- database
---------------------------------
local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `rsg_wellpumps` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL, `h` FLOAT NOT NULL DEFAULT 0,
        `placed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]],
    [[CREATE TABLE IF NOT EXISTS `rsg_wellpump_migrations` (
        `source` VARCHAR(64) NOT NULL,
        `migrated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`source`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]],
}

local function ensureDatabase()
    for _, sql in ipairs(SCHEMA) do
        local ok, err = pcall(MySQL.query.await, sql)
        if not ok then
            print(('^1[rsg-wellpump] database setup failed: %s^7'):format(tostring(err)))
            return false
        end
    end
    print('^2[rsg-wellpump] database tables ready^7')
    return true
end

-- Copies pumps from the old per-script tables once. The old tables are never changed or dropped.
local function migrateLegacy()
    local cfg = Config.Migration
    if not cfg or not cfg.Enabled then return end

    for _, src in ipairs(cfg.Sources or {}) do
        local tbl = tostring(src.table or '')
        if tbl:match('^[%w_]+$') and src.name then
            local done = MySQL.scalar.await('SELECT 1 FROM rsg_wellpump_migrations WHERE source = ?', { src.name })
            local exists = MySQL.scalar.await(
                'SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { tbl })
            if not done and exists then
                local ok, res = pcall(MySQL.update.await, ([[INSERT INTO rsg_wellpumps (citizenid, x, y, z, h, placed_at)
                    SELECT citizenid, x, y, z, h, placed_at FROM `%s`]]):format(tbl))
                if ok then
                    MySQL.insert.await('INSERT INTO rsg_wellpump_migrations (source) VALUES (?)', { src.name })
                    print(('^2[rsg-wellpump] imported %s well pump(s) from %s^7'):format(tostring(res or 0), tbl))
                else
                    print(('^1[rsg-wellpump] could not import %s: %s^7'):format(tbl, tostring(res)))
                end
            end
        end
    end
end

local function checkItems()
    local function chk(item)
        if item and not RSGCore.Shared.Items[item] then
            print(('^3[rsg-wellpump] item "%s" does not exist in your rsg-core items^7'):format(item))
        end
    end
    chk(Config.Item); chk(Config.EmptyItem); chk(Config.FullItem)
end

CreateThread(function()
    if Config.AutoDatabase and not ensureDatabase() then return end
    migrateLegacy()

    local rows = MySQL.query.await('SELECT * FROM rsg_wellpumps') or {}
    for _, r in ipairs(rows) do
        Pumps[r.id] = { id = r.id, citizenid = r.citizenid, x = r.x, y = r.y, z = r.z, h = r.h }
    end
    Loaded = true
    checkItems()
    debugPrint(('loaded %d well pumps'):format(#rows))
    syncAll()
end)

RSGCore.Functions.CreateCallback('rsg-wellpump:server:getPumps', function(source, cb)
    while not Loaded do Wait(100) end
    cb(list(), idsOwnedBy(source))
end)

---------------------------------
-- usable items
---------------------------------
local function useItem(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    if countPumps(Player.PlayerData.citizenid) >= Config.MaxPerPlayer then
        return notify(source, locale('max_pumps', Config.MaxPerPlayer), 'error')
    end
    TriggerClientEvent('rsg-wellpump:client:place', source)
end

CreateThread(function()
    RSGCore.Functions.CreateUseableItem(Config.Item, useItem)
    for _, item in ipairs(Config.ExtraItems or {}) do
        RSGCore.Functions.CreateUseableItem(item, useItem)
    end
end)

---------------------------------
-- place
---------------------------------
RSGCore.Functions.CreateCallback('rsg-wellpump:server:placePump', function(source, cb, coords, heading)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    coords = toCoords(coords)
    if not Player or not coords then return cb(false, locale('place_invalid')) end
    if Reserved[src] then return cb(false, locale('action_invalid')) end

    local okPlace = exports['rsg-gizmo']:IsPlacementValid(src, coords, Config.PlaceMaxDistance)
    if not okPlace then return cb(false, locale('too_far')) end

    local cid = Player.PlayerData.citizenid
    if countPumps(cid) >= Config.MaxPerPlayer then return cb(false, locale('max_pumps', Config.MaxPerPlayer)) end
    for _, p in pairs(Pumps) do
        if #(vector3(p.x, p.y, p.z) - coords) < Config.MinDistance then return cb(false, locale('too_close')) end
    end
    for _, r in pairs(Reserved) do
        if #(r - coords) < Config.MinDistance then return cb(false, locale('too_close')) end
    end

    -- take whichever pump item the player is carrying
    local taken = false
    for _, item in ipairs({ Config.Item, table.unpack(Config.ExtraItems or {}) }) do
        if hasItem(src, item) and removeItem(src, item, 1, nil, 'rsg-wellpump:place') then taken = item break end
    end
    if not taken then return cb(false, locale('no_item')) end

    local h = toHeading(heading)
    Reserved[src] = coords
    local id = MySQL.insert.await('INSERT INTO rsg_wellpumps (citizenid, x, y, z, h) VALUES (?, ?, ?, ?, ?)',
        { cid, coords.x, coords.y, coords.z, h })
    Reserved[src] = nil

    if not id then
        giveOrDrop(src, taken, 1, nil, 'rsg-wellpump:place-refund')
        return cb(false, locale('place_invalid'))
    end
    Pumps[id] = { id = id, citizenid = cid, x = coords.x, y = coords.y, z = coords.z, h = h }
    syncAll()
    cb(true, locale('placed'))
end)

---------------------------------
-- pre-check (starts the action timer)
---------------------------------
RSGCore.Functions.CreateCallback('rsg-wellpump:server:precheck', function(source, cb, action, pumpId)
    if type(action) ~= 'string' or not Rules[action] then return cb(false, locale('action_invalid')) end
    local Player, pump, err = validate(source, pumpId)
    if not Player then return cb(false, err) end
    err = Rules[action](source, Player, pump)
    if err then return cb(false, err) end
    startAction(source, ('%s:%s'):format(action, pump.id), Durations[action])
    cb(true)
end)

---------------------------------
-- fill / pack
---------------------------------
RSGCore.Functions.CreateCallback('rsg-wellpump:server:fill', function(source, cb, pumpId)
    local Player, _, err = checkAction(source, 'fill', pumpId)
    if not Player then return cb(false, err) end
    cb(fillBucket(source))
end)

RSGCore.Functions.CreateCallback('rsg-wellpump:server:drink', function(source, cb, pumpId)
    local Player, _, err = checkAction(source, 'drink', pumpId)
    if not Player then return cb(false, err) end
    cb(drink(source))
end)

RSGCore.Functions.CreateCallback('rsg-wellpump:server:pack', function(source, cb, pumpId)
    local Player, pump, err = checkAction(source, 'pack', pumpId)
    if not Player then return cb(false, err) end

    Pumps[pump.id] = nil
    TriggerEvent('rsg-wellpump:internal:pumpRemoved', pump.id)
    MySQL.query('DELETE FROM rsg_wellpumps WHERE id = ?', { pump.id })
    giveOrDrop(source, Config.Item, 1, nil, 'rsg-wellpump:pack') -- never lose the pump item
    syncAll()
    cb(true, locale('packed'))
end)

---------------------------------
-- exports for other resources
---------------------------------
-- FillBucket(src) -> ok, message
--   swaps one empty bucket for a full one (full uses). The caller checks access and distance first.
exports('FillBucket', fillBucket)

-- UseBucket(src) -> ok, usesLeft | message
--   uses one charge of the player's full bucket; an empty bucket comes back when it runs out.
exports('UseBucket', function(src)
    local ok, ticket = takeBucketUse(src)
    if not ok then return false, ticket end
    local _, left = commitBucketUse(src, ticket)
    return true, left
end)

-- TakeBucketUse(src) -> ok, ticket | message
-- CommitBucketUse(src, ticket) -> ok, usesLeft      (after your own work succeeded)
-- RefundBucketUse(src, ticket) -> ok                (if your own work failed: hands the bucket back unchanged)
exports('TakeBucketUse', takeBucketUse)
exports('CommitBucketUse', commitBucketUse)
exports('RefundBucketUse', refundBucketUse)

-- Drink(src) -> ok, message, thirstAmount
--   enforces Config.Drink.cooldown, picks the amount and tells the player's client to raise thirst.
--   The caller checks access and distance first (and the client calls PlayDrink() before asking you).
exports('Drink', drink)

-- GetBucketUses(itemInfo) -> uses left on a full bucket's item info (full uses when it has none)
exports('GetBucketUses', function(info)
    return tonumber(type(info) == 'table' and info.uses or nil) or Config.BucketUses
end)

exports('GetMaxUses', function() return Config.BucketUses end)
exports('GetFillTime', function() return Config.FillTime end)

-- GetPumps() -> list of { id, x, y, z, h } for every placed pump
exports('GetPumps', list)

-- IsNearPump(src, distance?) -> true when the player stands within `distance` (default Config.InteractDist + 2) of a placed pump
exports('IsNearPump', function(src, distance)
    distance = tonumber(distance) or (Config.InteractDist + 2.0)
    for _, p in pairs(Pumps) do
        if distanceTo(src, p.x, p.y, p.z) <= distance then return true end
    end
    return false
end)

---------------------------------
-- water supply exports (sprinklers / irrigation)
---------------------------------
local Reservoir = {}  -- [pumpId] = { level, t } refilled lazily from the time of the last read

local function waterOf(id)
    local S = Config.Sprinkler
    if not S or not S.Enabled or not Pumps[id] then return 0 end
    local now = GetGameTimer()
    local r = Reservoir[id]
    if not r then r = { level = S.Capacity + 0.0, t = now }; Reservoir[id] = r end
    local add = (now - r.t) / 60000.0 * S.RefillPerMinute
    r.level = math.min(S.Capacity + 0.0, r.level + math.max(0.0, add))
    r.t = now
    return r.level
end

local function pumpInfo(p)
    return { id = p.id, x = p.x, y = p.y, z = p.z, h = p.h, water = math.floor(waterOf(p.id)) }
end

-- GetPump(id) -> { id, x, y, z, h, water } or nil
exports('GetPump', function(id)
    local p = Pumps[tonumber(id)]
    return p and pumpInfo(p) or nil
end)

-- GetNearestPump(coords, maxDistance?) -> pump info (+ distance) or nil
exports('GetNearestPump', function(coords, maxDistance)
    local c = toCoords(coords)
    if not c then return nil end
    maxDistance = tonumber(maxDistance) or (Config.Sprinkler and Config.Sprinkler.MaxLinkDistance) or 60.0
    local best, bd
    for _, p in pairs(Pumps) do
        local d = #(c - vector3(p.x, p.y, p.z))
        if d <= maxDistance and (not bd or d < bd) then best, bd = p, d end
    end
    if not best then return nil end
    local info = pumpInfo(best)
    info.distance = bd
    return info
end)

-- GetPumpWater(id) -> units of water in the pump's reservoir (0 when missing or disabled)
exports('GetPumpWater', function(id) return math.floor(waterOf(tonumber(id))) end)

-- DrawWater(id, amount) -> ok, drawn
--   takes up to `amount` units (partial draws allowed); the caller checks distance and ownership first.
exports('DrawWater', function(id, amount)
    id, amount = tonumber(id), tonumber(amount)
    if not id or not amount or amount ~= amount or amount <= 0 then return false, 0 end
    local have = waterOf(id)
    if have < 1 then return false, 0 end
    local take = math.min(have, amount)
    Reservoir[id].level = have - take
    return true, take
end)

AddEventHandler('rsg-wellpump:internal:pumpRemoved', function(id) Reservoir[id] = nil end)
