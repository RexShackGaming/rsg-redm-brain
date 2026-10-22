local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Plants = {}   -- [id] = plant
local Dirty  = {}   -- [id] = true when needs saving
local Loaded = false
local Reserved = {} -- [src] = vector3, spots held while a plant insert is awaiting the DB

---------------------------------
-- helpers
---------------------------------
local function clamp(v, mn, mx) return math.max(mn, math.min(mx, v)) end
local function round(v) return math.floor(v * 10 + 0.5) / 10 end

local function buildSync()
    local out = {}
    for _, p in pairs(Plants) do
        out[#out + 1] = {
            id = p.id, crop = p.crop, owner = p.citizenid,
            x = p.x, y = p.y, z = p.z, h = p.h,
            growth = round(p.growth), water = round(p.water), fertilizer = round(p.fertilizer),
            health = round(p.health), dead = p.dead,
        }
    end
    return out
end

local function syncAll()
    TriggerClientEvent('rsg-farming:client:sync', -1, buildSync())
end

local function countPlants(citizenid)
    local n = 0
    for _, p in pairs(Plants) do
        if p.citizenid == citizenid then n = n + 1 end
    end
    return n
end

-- validates player + plant + distance -> Player, plant | nil, nil, err
local function validate(src, plantId)
    local Player = Utils.getPlayer(src)
    if not Player then return nil, nil, locale('no_player') end
    local plant = Plants[tonumber(plantId)]
    if not plant then return nil, nil, locale('plant_missing') end
    if Utils.distanceTo(src, plant.x, plant.y, plant.z) > Config.InteractDistance + 2.5 then
        return nil, nil, locale('too_far')
    end
    return Player, plant
end

local function deletePlant(id)
    Plants[id] = nil
    Dirty[id] = nil
    MySQL.query('DELETE FROM rsg_farming_plants WHERE id = ?', { id })
end

---------------------------------
-- rules per action (shared by pre-check and the action itself)
---------------------------------
local Rules = {
    water = function(Player, plant)
        if plant.dead then return locale('plant_dead') end
        if plant.water >= 95 then return locale('already_full') end
        if not Utils.hasItem(Player, Config.WaterItem) then return locale('no_water') end
    end,
    fertilize = function(Player, plant)
        if plant.dead then return locale('plant_dead') end
        if plant.growth >= 100 then return locale('fully_grown') end
        if plant.fertilizer >= 95 then return locale('already_full') end
        if not Utils.hasItem(Player, Config.FertilizerItem) then return locale('no_fertilizer') end
    end,
    harvest = function(Player, plant)
        if Config.OwnerOnlyHarvest and plant.citizenid ~= Player.PlayerData.citizenid then return locale('not_owner') end
        if plant.dead then return locale('plant_dead') end
        if plant.growth < 100 then return locale('not_ready') end
    end,
}

local Durations = { water = Config.WaterTime, fertilize = Config.FertilizeTime, harvest = Config.HarvestTime }

-- full validation for a timed action, consumes the action token
local function checkAction(src, action, plantId)
    local Player, plant, err = validate(src, plantId)
    if not Player then return nil, nil, err end
    if not Utils.finishAction(src, ('%s:%s'):format(action, plant.id)) then return nil, nil, locale('action_invalid') end
    err = Rules[action](Player, plant)
    if err then return nil, nil, err end
    return Player, plant
end

---------------------------------
-- database
---------------------------------
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rsg_farming_plants` (
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
            `planted_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    local count = 0
    for _, r in ipairs(MySQL.query.await('SELECT * FROM rsg_farming_plants') or {}) do
        if Config.Crops[r.crop] then
            Plants[r.id] = {
                id = r.id, citizenid = r.citizenid, crop = r.crop,
                x = r.x, y = r.y, z = r.z, h = r.h,
                growth = r.growth, water = r.water, fertilizer = r.fertilizer,
                health = r.health, dead = r.dead == 1 or r.dead == true, deadTime = r.dead_time or 0,
            }
            count = count + 1
        end
    end
    Loaded = true
    print(('[rsg-farming] loaded %d plants'):format(count))
    syncAll()
end)

local function saveDirty()
    local queries = {}
    for id in pairs(Dirty) do
        local p = Plants[id]
        if p then
            queries[#queries + 1] = {
                query = 'UPDATE rsg_farming_plants SET growth = ?, water = ?, fertilizer = ?, health = ?, dead = ?, dead_time = ? WHERE id = ?',
                values = { p.growth, p.water, p.fertilizer, p.health, p.dead and 1 or 0, p.deadTime or 0, id },
            }
        end
    end
    Dirty = {}
    if #queries > 0 then MySQL.transaction(queries) end
end

---------------------------------
-- growth tick
---------------------------------
CreateThread(function()
    while not Loaded do Wait(500) end
    local lastSave = os.time()
    local mins = Config.TickInterval / 60
    while true do
        Wait(Config.TickInterval * 1000)
        local now = os.time()

        for id, p in pairs(Plants) do
            local crop = Config.Crops[p.crop]
            if p.dead then
                if Config.DeadPlantRemoveTime > 0 and now - (p.deadTime or now) >= Config.DeadPlantRemoveTime * 60 then
                    deletePlant(id)
                end
            elseif crop then
                p.water      = clamp(p.water - Config.WaterDecay * mins, 0, 100)
                p.fertilizer = clamp(p.fertilizer - Config.FertilizerDecay * mins, 0, 100)

                if p.water > Config.MinWaterToGrow then
                    p.health = clamp(p.health + Config.HealthRegen * mins, 0, 100)
                    if p.growth < 100 then
                        local rate = 100 / crop.growTime -- % per minute
                        if p.fertilizer > 0 then rate = rate * Config.FertilizerBoost end
                        p.growth = clamp(p.growth + rate * mins, 0, 100)
                    end
                else
                    p.health = clamp(p.health - Config.DryDamage * mins, 0, 100)
                    if p.health <= 0 then
                        p.dead = true
                        p.deadTime = now
                    end
                end
                Dirty[id] = true
            end
        end

        syncAll()

        if now - lastSave >= Config.SaveInterval then
            saveDirty()
            lastSave = now
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then saveDirty() end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', saveDirty)

---------------------------------
-- usable seeds
---------------------------------
for cropKey, crop in pairs(Config.Crops) do
    RSGCore.Functions.CreateUseableItem(crop.seed, function(source)
        local Player = Utils.getPlayer(source)
        if not Player then return end
        if countPlants(Player.PlayerData.citizenid) >= Config.MaxPlantsPerPlayer then
            return Utils.notify(source, locale('max_plants', Config.MaxPlantsPerPlayer), 'error')
        end
        TriggerClientEvent('rsg-farming:client:startPlacing', source, cropKey)
    end)
end

---------------------------------
-- callbacks
---------------------------------
lib.callback.register('rsg-farming:server:getPlants', function()
    while not Loaded do Wait(100) end
    return buildSync()
end)

lib.callback.register('rsg-farming:server:plant', function(source, cropKey, coords, heading)
    local src = source
    local Player = Utils.getPlayer(src)
    local crop = Config.Crops[cropKey]
    coords = Utils.toCoords(coords)
    if not Player or not crop or not coords then return false, locale('place_invalid') end

    if Utils.distanceTo(src, coords.x, coords.y, coords.z) > Config.PlaceMaxDistance + 2.0 then
        return false, locale('place_too_far')
    end

    local cid = Player.PlayerData.citizenid
    if countPlants(cid) >= Config.MaxPlantsPerPlayer then
        return false, locale('max_plants', Config.MaxPlantsPerPlayer)
    end
    if Reserved[src] then return false, locale('action_invalid') end
    for _, p in pairs(Plants) do
        if #(vector3(p.x, p.y, p.z) - coords) < Config.MinPlantDistance then
            return false, locale('place_too_close')
        end
    end
    for _, r in pairs(Reserved) do
        if #(r - coords) < Config.MinPlantDistance then return false, locale('place_too_close') end
    end
    if not Utils.removeItem(src, crop.seed, 1, nil, 'rsg-farming:plant') then return false, locale('no_seed') end

    local h = Utils.toHeading(heading)
    Reserved[src] = coords -- hold the spot while we wait on the DB
    local id = MySQL.insert.await(
        'INSERT INTO rsg_farming_plants (citizenid, crop, x, y, z, h, growth, water, fertilizer, health) VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 100)',
        { cid, cropKey, coords.x, coords.y, coords.z, h })
    Reserved[src] = nil

    if not id then
        Utils.addItem(src, crop.seed, 1, nil, 'rsg-farming:plant-refund')
        return false, locale('place_invalid')
    end

    Plants[id] = {
        id = id, citizenid = cid, crop = cropKey,
        x = coords.x, y = coords.y, z = coords.z, h = h,
        growth = 0, water = 0, fertilizer = 0, health = 100, dead = false, deadTime = 0,
    }
    syncAll()
    return true, locale('planted')
end)

-- pre-check: runs before the client plays the animation and starts the action timer
lib.callback.register('rsg-farming:server:precheck', function(source, action, plantId)
    if not Rules[action] then return false, locale('action_invalid') end
    local Player, plant, err = validate(source, plantId)
    if not Player then return false, err end
    err = Rules[action](Player, plant)
    if err then return false, err end
    Utils.startAction(source, ('%s:%s'):format(action, plant.id), Durations[action])
    return true
end)

lib.callback.register('rsg-farming:server:water', function(source, plantId)
    local Player, plant, err = checkAction(source, 'water', plantId)
    if not Player then return false, err end

    -- a full bucket has limited uses, stored in item metadata
    local bucket = Player.Functions.GetItemByName(Config.WaterItem)
    if not bucket then return false, locale('no_water') end
    local maxUses = Config.WellPump.bucketUses or 5
    local info = bucket.info or {}
    local uses = tonumber(info.uses) or maxUses

    if not Utils.removeItem(source, Config.WaterItem, 1, bucket.slot, 'rsg-farming:water') then
        return false, locale('no_water')
    end
    if uses <= 1 then
        if Config.WaterReturnItem then Utils.addItem(source, Config.WaterReturnItem, 1, nil, 'rsg-farming:water-empty') end
    else
        local newInfo = {}
        for k, v in pairs(info) do newInfo[k] = v end
        newInfo.uses = uses - 1
        newInfo.description = locale('bucket_uses', newInfo.uses, maxUses)
        exports['rsg-inventory']:AddItem(source, Config.WaterItem, 1, bucket.slot, newInfo, 'rsg-farming:water-use')
    end

    plant.water = clamp(plant.water + Config.WaterAmount, 0, 100)
    Dirty[plant.id] = true
    syncAll()
    return true, locale('watered')
end)

lib.callback.register('rsg-farming:server:fertilize', function(source, plantId)
    local Player, plant, err = checkAction(source, 'fertilize', plantId)
    if not Player then return false, err end
    if not Utils.removeItem(source, Config.FertilizerItem, 1, nil, 'rsg-farming:fertilize') then
        return false, locale('no_fertilizer')
    end

    plant.fertilizer = clamp(plant.fertilizer + Config.FertilizerAmount, 0, 100)
    Dirty[plant.id] = true
    syncAll()
    return true, locale('fertilized')
end)

lib.callback.register('rsg-farming:server:harvest', function(source, plantId)
    local Player, plant, err = checkAction(source, 'harvest', plantId)
    if not Player then return false, err end

    -- roll rewards and make sure they all fit BEFORE removing the plant
    local rewards = {}
    for _, r in ipairs(Config.Crops[plant.crop].harvest) do
        local amount = math.random(r.min, r.max)
        if amount > 0 then
            if not Utils.canAdd(source, r.item, amount) then return false, locale('inv_full') end
            rewards[#rewards + 1] = { item = r.item, amount = amount }
        end
    end

    deletePlant(plant.id) -- remove first to stop double-harvest
    syncAll()
    for _, r in ipairs(rewards) do
        Utils.addItem(source, r.item, r.amount, nil, 'rsg-farming:harvest')
    end
    return true, locale('harvested')
end)

lib.callback.register('rsg-farming:server:destroy', function(source, plantId)
    local Player, plant, err = validate(source, plantId)
    if not Player then return false, err end
    if plant.citizenid ~= Player.PlayerData.citizenid and not plant.dead then
        return false, locale('not_owner')
    end
    deletePlant(plant.id)
    syncAll()
    return true, locale('destroyed')
end)
