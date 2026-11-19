local RSGCore = exports['rsg-core']:GetCoreObject()

local Plants   = {}   -- [id] = plant
local Dirty    = {}   -- [id] = true when needs saving
local Loaded   = false
local Reserved = {}   -- [src] = vector3, spots held while a plant insert is awaiting the DB

---------------------------------
-- helpers
---------------------------------
local function clamp(v, mn, mx) return math.max(mn, math.min(mx, v)) end
local function round(v) return math.floor(v * 10 + 0.5) / 10 end

---------------------------------
-- seasons / growth rate
---------------------------------
local function seasonMult()
    local s = Config.Seasons
    if not s or not s.enabled then return 1.0 end
    return s.months[tonumber(os.date('%m'))] or 1.0
end

local SeasonNow = seasonMult() -- refreshed every growth tick

-- growth in % per minute for a plant right now (season, fertiliser and pests included)
local function growthRate(p, crop)
    local rate = (100 / crop.growTime) * SeasonNow
    if p.fertilizer > 0 then rate = rate * Config.FertilizerBoost end
    if p.pest then rate = rate * (Config.Pests.growthPenalty or 0.5) end
    return rate
end

local function etaMinutes(p)
    if p.dead or p.growth >= 100 then return 0 end
    local rate = growthRate(p, Config.Crops[p.crop])
    if rate <= 0 then return 0 end
    return math.ceil((100 - p.growth) / rate)
end

-- what clients may see: no citizenid (ownership is sent separately per player)
local function publicPlant(p)
    return {
        id = p.id, crop = p.crop,
        x = p.x, y = p.y, z = p.z, h = p.h,
        growth = round(p.growth), water = round(p.water), fertilizer = round(p.fertilizer),
        health = round(p.health), dead = p.dead, pest = p.pest == true, eta = etaMinutes(p),
    }
end

local function buildSync()
    local out = {}
    for _, p in pairs(Plants) do out[#out + 1] = publicPlant(p) end
    return out
end

local function ownerMap()
    local m = {}
    for id, p in pairs(Plants) do m[id] = p.citizenid end
    return m
end

local function syncAll()
    Utils.broadcastOwned('rsg-farming:client:sync', buildSync(), ownerMap())
end

-- single-plant deltas: cheap, used after player actions
local function pushPlant(p) TriggerClientEvent('rsg-farming:client:plantUpdate', -1, publicPlant(p)) end
local function pushRemove(id) TriggerClientEvent('rsg-farming:client:plantRemove', -1, id) end

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
    pushRemove(id)
end

---------------------------------
-- farming xp / levels (stored in player metadata)
---------------------------------
-- rsg-skills (optional): when started it replaces the built-in XP and levels
local function useSkills()
    return Config.Skills.Enabled and GetResourceState('rsg-skills') == 'started'
end

local function xpOf(Player)
    local v = Player.Functions.GetMetaData('farmingxp')
    return tonumber(v) or 0
end

local function levelOf(xp)
    local lvl = 1
    for i, l in ipairs(Config.Levels) do
        if xp >= l.xp then lvl = i end
    end
    return lvl
end

local function perkOf(Player)
    if useSkills() then
        local src = Player.PlayerData.source
        local per = Config.Skills.LevelsPerExtraPlant or 0
        local level = exports['rsg-skills']:GetLevel(src, Config.Skills.Skill) or 1
        return {
            bonusYieldChance = tonumber(exports['rsg-skills']:GetPerk(src, Config.Skills.Skill, 'extra_yield')) or 0,
            extraPlants = per > 0 and math.floor((level - 1) / per) or 0,
        }
    end
    if not Config.XP.enabled then return Config.Levels[1] end
    return Config.Levels[levelOf(xpOf(Player))]
end

local function maxPlantsFor(Player)
    return Config.MaxPlantsPerPlayer + (perkOf(Player).extraPlants or 0)
end

local function addXP(src, Player, amount)
    if useSkills() then
        if amount and amount > 0 then
            exports['rsg-skills']:AddXP(src, Config.Skills.Skill, math.max(1, math.floor(amount * (Config.Skills.XPScale or 1) + 0.5)), 'farming')
        end
        return -- rsg-skills sends its own level-up notification
    end
    if not Config.XP.enabled or not amount or amount <= 0 then return end
    local old = xpOf(Player)
    local new = old + amount
    Player.Functions.SetMetaData('farmingxp', new)
    local newLevel = levelOf(new)
    if newLevel > levelOf(old) then
        Utils.notify(src, locale('level_up', Config.Levels[newLevel].label), 'success')
    end
end

RSGCore.Commands.Add('farmlevel', 'Show your farming level', {}, false, function(source)
    local Player = Utils.getPlayer(source)
    if not Player then return end
    if useSkills() then
        local pr = exports['rsg-skills']:GetProgress(source, Config.Skills.Skill)
        if pr then
            return Utils.notify(source, pr.nextXP
                and locale('level_info_skills_next', pr.level, pr.xp, pr.nextXP)
                or locale('level_info_skills', pr.level, pr.xp), 'inform')
        end
    end
    local xp = xpOf(Player)
    local lvl = levelOf(xp)
    local nextLevel = Config.Levels[lvl + 1]
    local msg = nextLevel
        and locale('level_info_next', lvl, Config.Levels[lvl].label, xp, nextLevel.xp)
        or locale('level_info', lvl, Config.Levels[lvl].label, xp)
    Utils.notify(source, msg, 'inform')
end)

---------------------------------
-- rules per action (shared by pre-check and the action itself)
---------------------------------
local Rules = {
    water = function(Player, plant)
        if plant.dead then return locale('plant_dead') end
        if plant.water >= 95 then return locale('already_full') end
        if not Utils.hasItem(Player.PlayerData.source, Config.WaterItem) then return locale('no_water') end
    end,
    fertilize = function(Player, plant)
        if plant.dead then return locale('plant_dead') end
        if plant.growth >= 100 then return locale('fully_grown') end
        if plant.fertilizer >= 95 then return locale('already_full') end
        if not Utils.hasItem(Player.PlayerData.source, Config.FertilizerItem) then return locale('no_fertilizer') end
    end,
    treat = function(Player, plant)
        if plant.dead then return locale('plant_dead') end
        if not plant.pest then return locale('no_pests') end
        if not Utils.hasItem(Player.PlayerData.source, Config.Pests.item) then return locale('no_pesticide') end
    end,
    harvest = function(Player, plant)
        if Config.OwnerOnlyHarvest and plant.citizenid ~= Player.PlayerData.citizenid then return locale('not_owner') end
        if plant.dead then return locale('plant_dead') end
        if plant.growth < 100 then return locale('not_ready') end
    end,
}

local Durations = { water = Config.WaterTime, fertilize = Config.FertilizeTime, treat = Config.TreatTime, harvest = Config.HarvestTime }

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
-- load from database
---------------------------------
CreateThread(function()
    while Utils.DBReady == nil do Wait(100) end

    local count = 0
    if Utils.DBReady then
        local ok, rows = pcall(MySQL.query.await, 'SELECT * FROM rsg_farming_plants')
        if ok then
            for _, r in ipairs(rows or {}) do
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
        else
            print(('^1[rsg-farming] could not load plants: %s^7'):format(tostring(rows)))
        end
    end
    Loaded = true
    print(('[rsg-farming] loaded %d plants'):format(count))
    syncAll()
end)

-- writes changed plants; on failure they stay dirty and are retried next save
local function saveDirty()
    local queries, ids = {}, {}
    for id in pairs(Dirty) do
        local p = Plants[id]
        if p then
            queries[#queries + 1] = {
                query = 'UPDATE rsg_farming_plants SET growth = ?, water = ?, fertilizer = ?, health = ?, dead = ?, dead_time = ? WHERE id = ?',
                values = { p.growth, p.water, p.fertilizer, p.health, p.dead and 1 or 0, p.deadTime or 0, id },
            }
            ids[#ids + 1] = id
        end
    end
    Dirty = {}
    if #queries == 0 then return end

    local ok, res = pcall(MySQL.transaction.await, queries)
    if not ok or res == false then
        for _, id in ipairs(ids) do Dirty[id] = true end
        print('^1[rsg-farming] saving plants failed, will retry^7')
    end
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
        SeasonNow = seasonMult()

        -- rain from rsg-weather waters every plant (GlobalState.rsgWeather.weather is a lowercase weather name)
        local weather = GlobalState.rsgWeather
        local rain = (Config.RainWater and weather and Config.RainWater[weather.weather]) or 0

        for id, p in pairs(Plants) do
            local crop = Config.Crops[p.crop]
            if p.dead then
                if Config.DeadPlantRemoveTime > 0 and now - (p.deadTime or now) >= Config.DeadPlantRemoveTime * 60 then
                    deletePlant(id)
                end
            elseif crop then
                local w, f, h, g = p.water, p.fertilizer, p.health, p.growth

                p.water      = clamp(p.water - Config.WaterDecay * mins + rain * mins, 0, 100)
                p.fertilizer = clamp(p.fertilizer - Config.FertilizerDecay * mins, 0, 100)

                if Config.Pests.enabled and not p.pest and math.random() < (Config.Pests.chancePerTick or 0.02) then
                    p.pest = true
                end

                if p.water > Config.MinWaterToGrow then
                    p.health = clamp(p.health + Config.HealthRegen * mins, 0, 100)
                    if p.growth < 100 then
                        p.growth = clamp(p.growth + growthRate(p, crop) * mins, 0, 100)
                    end
                else
                    p.health = clamp(p.health - Config.DryDamage * mins, 0, 100)
                end

                if p.pest then
                    p.health = clamp(p.health - (Config.Pests.healthLoss or 3) * mins, 0, 100)
                end

                if p.health <= 0 then
                    p.dead = true
                    p.deadTime = now
                    p.pest = false
                end

                if p.dead or p.pest or p.water ~= w or p.fertilizer ~= f or p.health ~= h or p.growth ~= g then
                    Dirty[id] = true
                end
            end
        end

        if next(Plants) then syncAll() end

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
        local limit = maxPlantsFor(Player)
        if countPlants(Player.PlayerData.citizenid) >= limit then
            return Utils.notify(source, locale('max_plants', limit), 'error')
        end
        TriggerClientEvent('rsg-farming:client:startPlacing', source, cropKey)
    end)
end

---------------------------------
-- callbacks
---------------------------------
Utils.callback('rsg-farming:server:getPlants', function(source)
    while not Loaded do Wait(100) end
    return buildSync(), Utils.idsOwnedBy(source, ownerMap())
end)

Utils.callback('rsg-farming:server:plant', function(source, cropKey, coords, heading)
    local src = source
    local Player = Utils.getPlayer(src)
    local crop = type(cropKey) == 'string' and Config.Crops[cropKey]
    coords = Utils.toCoords(coords)
    if not Player or not crop or not coords then return false, locale('place_invalid') end

    if not exports['rsg-gizmo']:IsPlacementValid(src, coords, Config.PlaceMaxDistance) then
        return false, locale('place_too_far')
    end
    if Utils.inBlockedZone(coords) then return false, locale('place_blocked_zone') end

    local cid = Player.PlayerData.citizenid
    local limit = maxPlantsFor(Player)
    if countPlants(cid) >= limit then
        return false, locale('max_plants', limit)
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
    local ok, id = pcall(MySQL.insert.await,
        'INSERT INTO rsg_farming_plants (citizenid, crop, x, y, z, h, growth, water, fertilizer, health) VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 100)',
        { cid, cropKey, coords.x, coords.y, coords.z, h })
    Reserved[src] = nil

    if not ok or not id then
        Utils.giveOrDrop(src, crop.seed, 1, nil, 'rsg-farming:plant-refund')
        return false, locale('place_invalid')
    end

    Plants[id] = {
        id = id, citizenid = cid, crop = cropKey,
        x = coords.x, y = coords.y, z = coords.z, h = h,
        growth = 0, water = 0, fertilizer = 0, health = 100, dead = false, deadTime = 0,
    }
    pushPlant(Plants[id])
    TriggerClientEvent('rsg-farming:client:plantMine', src, id)
    addXP(src, Player, Config.XP.plant)
    return true, locale('planted')
end)

-- pre-check: runs before the client plays the animation and starts the action timer
Utils.callback('rsg-farming:server:precheck', function(source, action, plantId)
    if type(action) ~= 'string' or not Rules[action] then return false, locale('action_invalid') end
    local Player, plant, err = validate(source, plantId)
    if not Player then return false, err end
    err = Rules[action](Player, plant)
    if err then return false, err end
    Utils.startAction(source, ('%s:%s'):format(action, plant.id), Durations[action])
    return true
end)

Utils.callback('rsg-farming:server:water', function(source, plantId)
    local Player, plant, err = checkAction(source, 'water', plantId)
    if not Player then return false, err end

    -- a full bucket has limited uses, stored in item metadata
    local bucket = exports['rsg-inventory']:GetItemByName(source, Config.WaterItem)
    if not bucket then return false, locale('no_water') end
    local maxUses = Config.WellPump.bucketUses or 5
    local info = bucket.info or {}
    local uses = tonumber(info.uses) or maxUses

    if not Utils.removeItem(source, Config.WaterItem, 1, bucket.slot, 'rsg-farming:water') then
        return false, locale('no_water')
    end
    if uses <= 1 then
        if Config.WaterReturnItem then
            Utils.giveOrDrop(source, Config.WaterReturnItem, 1, nil, 'rsg-farming:water-empty')
        end
    else
        local newInfo = {}
        for k, v in pairs(info) do newInfo[k] = v end
        newInfo.uses = uses - 1
        newInfo.description = locale('bucket_uses', newInfo.uses, maxUses)
        Utils.giveOrDrop(source, Config.WaterItem, 1, newInfo, 'rsg-farming:water-use', bucket.slot)
    end

    plant.water = clamp(plant.water + Config.WaterAmount, 0, 100)
    Dirty[plant.id] = true
    pushPlant(plant)
    if plant.citizenid == Player.PlayerData.citizenid then addXP(source, Player, Config.XP.water) end
    return true, locale('watered')
end)

Utils.callback('rsg-farming:server:fertilize', function(source, plantId)
    local Player, plant, err = checkAction(source, 'fertilize', plantId)
    if not Player then return false, err end
    if not Utils.removeItem(source, Config.FertilizerItem, 1, nil, 'rsg-farming:fertilize') then
        return false, locale('no_fertilizer')
    end

    plant.fertilizer = clamp(plant.fertilizer + Config.FertilizerAmount, 0, 100)
    Dirty[plant.id] = true
    pushPlant(plant)
    if plant.citizenid == Player.PlayerData.citizenid then addXP(source, Player, Config.XP.fertilize) end
    return true, locale('fertilized')
end)

Utils.callback('rsg-farming:server:treat', function(source, plantId)
    local Player, plant, err = checkAction(source, 'treat', plantId)
    if not Player then return false, err end
    if not Utils.removeItem(source, Config.Pests.item, 1, nil, 'rsg-farming:treat') then
        return false, locale('no_pesticide')
    end

    plant.pest = false
    pushPlant(plant)
    if plant.citizenid == Player.PlayerData.citizenid then addXP(source, Player, Config.XP.treat) end
    return true, locale('treated')
end)

Utils.callback('rsg-farming:server:harvest', function(source, plantId)
    local Player, plant, err = checkAction(source, 'harvest', plantId)
    if not Player then return false, err end

    -- roll rewards and make sure they all fit BEFORE removing the plant
    -- bonus produce (never extra seeds): healthy plant and/or farming level perk
    local crop = Config.Crops[plant.crop]
    local quality = plant.health >= (Config.Harvest.qualityHealth or 90)
    local skilled = math.random(100) <= (perkOf(Player).bonusYieldChance or 0)
    local rewards = {}
    for _, r in ipairs(crop.harvest) do
        local amount = math.random(r.min, r.max)
        if amount > 0 and r.item ~= crop.seed then
            if quality then amount = amount + (Config.Harvest.qualityBonus or 1) end
            if skilled then amount = amount + 1 end
        end
        if amount > 0 then rewards[#rewards + 1] = { item = r.item, amount = amount } end
    end
    if not Utils.canAddAll(source, rewards) then return false, locale('inv_full') end

    deletePlant(plant.id) -- remove first to stop double-harvest
    for _, r in ipairs(rewards) do
        -- satchel filled up between the check and now: drop it at their feet instead of losing it
        Utils.giveOrDrop(source, r.item, r.amount, nil, 'rsg-farming:harvest')
    end
    if plant.citizenid == Player.PlayerData.citizenid then addXP(source, Player, Config.XP.harvest) end
    return true, locale((quality or skilled) and 'harvested_bonus' or 'harvested')
end)

Utils.callback('rsg-farming:server:destroy', function(source, plantId)
    local Player, plant, err = validate(source, plantId)
    if not Player then return false, err end
    if plant.citizenid ~= Player.PlayerData.citizenid and not plant.dead then
        return false, locale('not_owner')
    end
    deletePlant(plant.id)
    return true, locale('destroyed')
end)
