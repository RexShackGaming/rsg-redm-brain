local RSGCore = exports['rsg-core']:GetCoreObject()

local Plants       = {}   -- [id] = plant
local Dirty        = {}   -- [id] = true when needs saving
local Loaded       = false
local Props        = {}   -- [id] = { id, citizenid, kind, x, y, z, h, pump } scarecrows and sprinklers
local Reserved     = {}   -- [src] = vector3, spots held while a plant insert is awaiting the DB
local LastPlant    = {}   -- [src] = GetGameTimer() of the last accepted plant (stops animation-skip spam)
local SyncPos      = {}   -- [src] = position of the player at their last plant sync
local LastLawAlert = {}   -- [src] = GetGameTimer() of the last law alert this thief caused
local Soil         = {}   -- ['cx:cy'] = { crop, fatigue, updated }

---------------------------------
-- helpers
---------------------------------
local function clamp(v, mn, mx) return math.max(mn, math.min(mx, v)) end
local function round(v) return math.floor(v * 10 + 0.5) / 10 end

---------------------------------
-- seasons / growth rate
---------------------------------
local SeasonMonth = tonumber(os.date('%m')) -- refreshed every growth tick

-- growth multiplier for a crop this month: the crop's own table, else Config.Seasons, else 1.0
local function seasonFor(crop)
    local s = Config.Seasons
    if not s or not s.enabled then return 1.0 end
    return (crop.seasons and crop.seasons[SeasonMonth]) or s.months[SeasonMonth] or 1.0
end

local function boostOf(p)
    local first = Config.Fertilizers[1]
    return p.fertBoost or (first and first.boost) or 1.0
end

-- growth in % per minute for a plant right now (season, fertiliser and pests included)
local function growthRate(p, crop)
    local rate = (100 / crop.growTime) * seasonFor(crop)
    if p.fertilizer > 0 then rate = rate * boostOf(p) end
    if p.pest then rate = rate * (Config.Pests.growthPenalty or 0.5) end
    return rate
end

local function etaMinutes(p)
    if p.dead or p.growth >= 100 then return 0 end
    local rate = growthRate(p, Config.Crops[p.crop])
    if rate <= 0 then return 0 end
    return math.ceil((100 - p.growth) / rate)
end

---------------------------------
-- soil: patches of ground tire when the same crop keeps being harvested from them
---------------------------------
local function cellKey(x, y)
    local size = Config.Soil.cell or 3.0
    local cx, cy = math.floor(x / size), math.floor(y / size)
    return cx .. ':' .. cy, cx, cy
end

-- fatigue 0-100 of the patch under (x, y), after natural recovery
local function soilFatigue(x, y)
    if not Config.Soil.enabled then return 0 end
    local s = Soil[(cellKey(x, y))]
    if not s then return 0 end
    local rested = (os.time() - s.updated) / 3600 * (Config.Soil.recoverPerHour or 0)
    return clamp(s.fatigue - rested, 0, 100)
end

local function setSoil(x, y, crop, fatigue)
    local key, cx, cy = cellKey(x, y)
    if fatigue <= 1 then -- healed: forget the patch
        if Soil[key] then
            Soil[key] = nil
            MySQL.query('DELETE FROM rsg_farming_soil WHERE cell_x = ? AND cell_y = ?', { cx, cy })
        end
        return
    end
    local now = os.time()
    Soil[key] = { crop = crop, fatigue = fatigue, updated = now }
    MySQL.query('INSERT INTO rsg_farming_soil (cell_x, cell_y, crop, fatigue, updated) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE crop = VALUES(crop), fatigue = VALUES(fatigue), updated = VALUES(updated)',
        { cx, cy, crop, fatigue, now })
end

-- yield multiplier for harvesting this plant from its patch
local function soilMultiplier(plant)
    if not Config.Soil.enabled then return 1.0 end
    return 1 - (soilFatigue(plant.x, plant.y) / 100) * (Config.Soil.maxYieldPenalty or 0.5)
end

-- after a harvest: same crop again tires the patch, a different crop (rotation) rests it
local function soilHarvested(plant)
    local c = Config.Soil
    if not c.enabled then return end
    local fatigue = soilFatigue(plant.x, plant.y)
    local s = Soil[(cellKey(plant.x, plant.y))]
    if not s or s.crop == plant.crop then
        fatigue = clamp(fatigue + (c.depletion or 20), 0, 100)
    else
        fatigue = clamp(fatigue - (c.rotateRecovery or 40), 0, 100)
    end
    setSoil(plant.x, plant.y, plant.crop, fatigue)
end

-- compost: removes fatigue from the patch
local function soilHealed(plant, amount)
    if not Config.Soil.enabled or not amount or amount <= 0 then return end
    local s = Soil[(cellKey(plant.x, plant.y))]
    if not s then return end
    setSoil(plant.x, plant.y, s.crop, clamp(soilFatigue(plant.x, plant.y) - amount, 0, 100))
end

-- what clients may see: no citizenid (ownership is sent separately per player)
local function publicPlant(p)
    return {
        id = p.id, crop = p.crop,
        x = p.x, y = p.y, z = p.z, h = p.h,
        growth = round(p.growth), water = round(p.water), fertilizer = round(p.fertilizer),
        health = round(p.health), dead = p.dead, pest = p.pest == true, eta = etaMinutes(p),
        soil = Config.Soil.enabled and round(100 - soilFatigue(p.x, p.y)) or nil,
    }
end

---------------------------------
-- who may tend a plant: the planter, or (Config.Sharing) members of the planter's gang / job
---------------------------------
local function shareKeyOf(Player)
    local S = Config.Sharing
    if not S or not S.enabled then return '' end
    local isJob = S.mode == 'job'
    local data = isJob and Player.PlayerData.job or Player.PlayerData.gang
    local name = data and data.name
    if not name or name == 'none' or name == 'unemployed' then return '' end
    return (isJob and 'job:' or 'gang:') .. name
end

local function canManage(Player, plant)
    if plant.citizenid == Player.PlayerData.citizenid then return true end
    return plant.share ~= '' and plant.share == shareKeyOf(Player)
end

---------------------------------
-- sync: plants a player needs = everything they can tend (for the My Crops list) plus anything within
-- Config.SyncDistance. Other players' far-away plants are never sent, so a modified client
-- cannot map every farm on the server, and the sync stays small on busy servers.
---------------------------------
local function buildFor(src, pos)
    local Player = Utils.getPlayer(src)
    local cid = Player and Player.PlayerData.citizenid
    local key = Player and shareKeyOf(Player) or ''
    pos = pos or GetEntityCoords(GetPlayerPed(src))
    local range2 = Config.SyncDistance * Config.SyncDistance
    local list, mine = {}, {}
    for id, p in pairs(Plants) do
        local own = cid ~= nil and (p.citizenid == cid or (key ~= '' and p.share == key))
        local dx, dy = p.x - pos.x, p.y - pos.y
        if own or (dx * dx + dy * dy) <= range2 then
            list[#list + 1] = publicPlant(p)
            if own then mine[#mine + 1] = id end
        end
    end
    return list, mine, pos
end

local function syncTo(src, pos)
    local list, mine, at = buildFor(src, pos)
    SyncPos[src] = at
    TriggerClientEvent('rsg-farming:client:sync', src, list, mine)
end

local function syncAll()
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        if src then syncTo(src) end
    end
end

-- single-plant delta (after a player action): only people who tend it and players in range get it
local function pushPlant(p)
    local pub = publicPlant(p)
    local range2 = Config.SyncDistance * Config.SyncDistance
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        if src then
            local pos = GetEntityCoords(GetPlayerPed(src))
            local dx, dy = p.x - pos.x, p.y - pos.y
            local Player = Utils.getPlayer(src)
            local own = Player and canManage(Player, p)
            if own or (dx * dx + dy * dy) <= range2 then
                TriggerClientEvent('rsg-farming:client:plantUpdate', src, pub)
            end
        end
    end
end

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
-- fertilisers (Config.Fertilizers, first one the player carries wins)
---------------------------------
local function pickFertilizer(src)
    for _, f in ipairs(Config.Fertilizers) do
        if Utils.hasItem(src, f.item) then return f end
    end
end

local function toolLabel()
    local item = RSGCore.Shared.Items[Config.PlantTool]
    return item and item.label or tostring(Config.PlantTool)
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

RSGCore.Commands.Add('farmlevel', locale('cmd_farmlevel'), {}, false, function(source)
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
        if not pickFertilizer(Player.PlayerData.source) then return locale('no_fertilizer') end
    end,
    treat = function(Player, plant)
        if plant.dead then return locale('plant_dead') end
        if not plant.pest then return locale('no_pests') end
        if not Utils.hasItem(Player.PlayerData.source, Config.Pests.item) then return locale('no_pesticide') end
    end,
    harvest = function(Player, plant)
        -- with Config.Theft the planter's rule is replaced by consequences (see onTheft)
        if Config.OwnerOnlyHarvest and not Config.Theft.enabled and not canManage(Player, plant) then return locale('not_owner') end
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
                        share = r.share_key or '',
                    }
                    count = count + 1
                end
            end
        else
            print(('^1[rsg-farming] could not load plants: %s^7'):format(tostring(rows)))
        end

        local okSoil, soilRows = pcall(MySQL.query.await, 'SELECT * FROM rsg_farming_soil')
        if okSoil then
            for _, r in ipairs(soilRows or {}) do
                Soil[r.cell_x .. ':' .. r.cell_y] = { crop = r.crop, fatigue = r.fatigue, updated = r.updated }
            end
        else
            print(('^1[rsg-farming] could not load soil: %s^7'):format(tostring(soilRows)))
        end
        local okP, propRows = pcall(MySQL.query.await, 'SELECT * FROM rsg_farming_props')
        if okP then
            for _, r in ipairs(propRows or {}) do
                if r.kind == 'scarecrow' or r.kind == 'sprinkler' then
                    Props[r.id] = { id = r.id, citizenid = r.citizenid, kind = r.kind, x = r.x, y = r.y, z = r.z, h = r.h,
                        pump = (r.pump_id or 0) > 0 and r.pump_id or nil }
                end
            end
        else
            print(('^1[rsg-farming] could not load props: %s^7'):format(tostring(propRows)))
        end
    end
    Loaded = true
    print(('[rsg-farming] loaded %d plants'):format(count))
    syncAll()
end)

-- writes changed plants in batches (one UPDATE per 100 plants); on failure they stay dirty and are retried next save.
-- Only UPDATE is used, so a plant that was harvested in the meantime can never come back.
local SAVE_COLUMNS = { 'growth', 'water', 'fertilizer', 'health', 'dead', 'dead_time' }
local SAVE_CHUNK = 100

local function columnValue(p, col)
    if col == 'dead' then return p.dead and 1 or 0 end
    if col == 'dead_time' then return p.deadTime or 0 end
    return p[col]
end

local function batchQuery(chunk)
    local sets, values = {}, {}
    for _, col in ipairs(SAVE_COLUMNS) do
        local whens = {}
        for _, id in ipairs(chunk) do
            whens[#whens + 1] = 'WHEN ? THEN ?'
            values[#values + 1] = id
            values[#values + 1] = columnValue(Plants[id], col)
        end
        sets[#sets + 1] = ('`%s` = CASE `id` %s END'):format(col, table.concat(whens, ' '))
    end
    local marks = {}
    for _, id in ipairs(chunk) do
        marks[#marks + 1] = '?'
        values[#values + 1] = id
    end
    return {
        query = ('UPDATE `rsg_farming_plants` SET %s WHERE `id` IN (%s)'):format(table.concat(sets, ', '), table.concat(marks, ',')),
        values = values,
    }
end

local function saveDirty()
    local ids = {}
    for id in pairs(Dirty) do
        if Plants[id] then ids[#ids + 1] = id end
    end
    Dirty = {}
    if #ids == 0 then return end

    local queries = {}
    for i = 1, #ids, SAVE_CHUNK do
        local chunk = {}
        for j = i, math.min(i + SAVE_CHUNK - 1, #ids) do chunk[#chunk + 1] = ids[j] end
        queries[#queries + 1] = batchQuery(chunk)
    end

    local ok, res = pcall(MySQL.transaction.await, queries)
    if not ok or res == false then
        for _, id in ipairs(ids) do Dirty[id] = true end
        print('^1[rsg-farming] saving plants failed, will retry^7')
    end
end

---------------------------------
-- owner alerts (one notification per type per tick, only while the planter is online)
---------------------------------
local function collectAlerts(p, out)
    local a = Config.Alerts
    if not a.enabled then return end
    local f = p.alerted
    if not f then f = {}; p.alerted = f end

    local function add(kind)
        local t = out[p.citizenid]
        if not t then t = {}; out[p.citizenid] = t end
        local list = t[kind]
        if not list then list = {}; t[kind] = list end
        list[#list + 1] = p
    end

    if p.dead then
        if a.dead and not f.dead then add('dead') end
        return
    end
    if a.ready and p.growth >= 100 and not f.ready then add('ready') end
    if p.water > 20 then f.thirsty = nil end
    if a.thirsty and p.water <= Config.MinWaterToGrow and not f.thirsty then add('thirsty') end
    if not p.pest then f.pests = nil end
    if a.pests and p.pest and not f.pests then add('pests') end
end

local function deliverAlerts(out)
    for cid, kinds in pairs(out) do
        local owner = RSGCore.Functions.GetPlayerByCitizenId(cid)
        if owner then
            local src = owner.PlayerData.source
            for kind, list in pairs(kinds) do
                Utils.notify(src, locale('alert_' .. kind, #list), kind == 'ready' and 'success' or 'warning')
                for _, p in ipairs(list) do p.alerted[kind] = true end
            end
        end
    end
end

---------------------------------
-- growth tick
---------------------------------

local function scarecrowFactor(p)
    local C = Config.Scarecrow
    if not C or not C.enabled then return 1.0 end
    local r2 = C.radius * C.radius
    for _, pr in pairs(Props) do
        if pr.kind == 'scarecrow' then
            local dx, dy = pr.x - p.x, pr.y - p.y
            if dx * dx + dy * dy <= r2 then return C.pestMultiplier or 0.25 end
        end
    end
    return 1.0
end

local function wellpumpUp()
    return GetResourceState('rsg-wellpump') == 'started'
end

-- waters a plant from the sprinkler's pump when it is dry (called once per plant per growth tick)
local function sprinklePlant(p)
    local C = Config.Sprinkler
    if not C or not C.enabled or p.water >= (C.startBelow or 40.0) or not wellpumpUp() then return end
    local r2 = C.radius * C.radius
    for _, pr in pairs(Props) do
        if pr.kind == 'sprinkler' then
            local dx, dy = pr.x - p.x, pr.y - p.y
            if dx * dx + dy * dy <= r2 then
                local pump = pr.pump
                if not pump or not exports['rsg-wellpump']:GetPump(pump) then
                    local np = exports['rsg-wellpump']:GetNearestPump(vector3(pr.x, pr.y, pr.z), C.linkDistance)
                    pr.pump = np and np.id or nil
                    pump = pr.pump
                end
                if pump then
                    local ok = exports['rsg-wellpump']:DrawWater(pump, C.pumpCost or 10)
                    if ok then
                        p.water = clamp(p.water + (C.waterAdded or 30.0), 0, 100)
                        return
                    end
                end
            end
        end
    end
end

CreateThread(function()
    while not Loaded do Wait(500) end
    local lastSave = os.time()
    local mins = Config.TickInterval / 60
    while true do
        Wait(Config.TickInterval * 1000)
        local now = os.time()
        SeasonMonth = tonumber(os.date('%m'))

        -- weather from rsg-weather (GlobalState.rsgWeather.weather is a lowercase weather name)
        local weather = GlobalState.rsgWeather
        local name = weather and weather.weather
        local rain = (Config.RainWater and name and Config.RainWater[name]) or 0
        local fx = Config.WeatherEffects and name and Config.WeatherEffects[name]
        local alerts = {}

        for id, p in pairs(Plants) do
            local crop = Config.Crops[p.crop]
            if p.dead then
                if Config.DeadPlantRemoveTime > 0 and now - (p.deadTime or now) >= Config.DeadPlantRemoveTime * 60 then
                    deletePlant(id)
                end
            elseif crop then
                local w, f, h, g = p.water, p.fertilizer, p.health, p.growth

                local waterDecay, fxGrow, fxHealth = Config.WaterDecay, 1.0, 0
                if fx and not (fx.cold and crop.hardy) then
                    waterDecay = waterDecay * (fx.waterDecay or 1.0)
                    fxGrow = fx.growth or 1.0
                    fxHealth = fx.healthLoss or 0
                end

                p.water      = clamp(p.water - waterDecay * mins + rain * mins, 0, 100)
                sprinklePlant(p)
                p.fertilizer = clamp(p.fertilizer - Config.FertilizerDecay * mins, 0, 100)

                if Config.Pests.enabled and not p.pest and math.random() < (Config.Pests.chancePerTick or 0.02) * scarecrowFactor(p) then
                    p.pest = true
                end

                if p.water > Config.MinWaterToGrow then
                    p.health = clamp(p.health + Config.HealthRegen * mins, 0, 100)
                    if p.growth < 100 then
                        p.growth = clamp(p.growth + growthRate(p, crop) * fxGrow * mins, 0, 100)
                    end
                else
                    p.health = clamp(p.health - Config.DryDamage * mins, 0, 100)
                end

                if p.pest then
                    p.health = clamp(p.health - (Config.Pests.healthLoss or 3) * mins, 0, 100)
                end
                if fxHealth > 0 then
                    p.health = clamp(p.health - fxHealth * mins, 0, 100)
                end

                if p.health <= 0 then
                    p.dead = true
                    p.deadTime = now
                    p.pest = false
                end

                if p.dead or p.water ~= w or p.fertilizer ~= f or p.health ~= h or p.growth ~= g then
                    Dirty[id] = true
                end
                collectAlerts(p, alerts)
            end
        end

        deliverAlerts(alerts)
        if next(Plants) then syncAll() end

        if now - lastSave >= Config.SaveInterval then
            saveDirty()
            lastSave = now
        end
    end
end)

-- players who walked far since their last sync get the plants around their new position
CreateThread(function()
    while not Loaded do Wait(500) end
    while true do
        Wait(5000)
        if next(Plants) then
            for _, sid in ipairs(GetPlayers()) do
                local src = tonumber(sid)
                if src then
                    local pos = GetEntityCoords(GetPlayerPed(src))
                    local last = SyncPos[src]
                    if not last or #(pos - last) > Config.SyncDistance * 0.4 then syncTo(src, pos) end
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Reserved[src], LastPlant[src], SyncPos[src], LastLawAlert[src] = nil, nil, nil, nil
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
        if Config.PlantTool and not Utils.hasItem(source, Config.PlantTool) then
            return Utils.notify(source, locale('need_tool', toolLabel()), 'error')
        end
        TriggerClientEvent('rsg-farming:client:startPlacing', source, cropKey)
    end)
end

---------------------------------
-- crop theft: consequences for harvesting a plant you may not tend (Config.Theft)
---------------------------------
local function onTheft(src, plant, crop)
    local T = Config.Theft

    if T.notifyOwner then
        local owner = RSGCore.Functions.GetPlayerByCitizenId(plant.citizenid)
        if owner then Utils.notify(owner.PlayerData.source, locale('alert_theft', crop.label), 'warning') end
    end

    if T.reputation and GetResourceState('rsg-reputation') == 'started' then
        pcall(function() exports['rsg-reputation']:ApplyAction(src, T.reputation) end)
    end

    local chance = tonumber(T.lawAlert) or 0
    if chance > 0 and not crop.illegal and GetResourceState('rsg-lawman') == 'started' and math.random() <= chance then
        local now = GetGameTimer()
        if LastLawAlert[src] and now - LastLawAlert[src] < (T.alertGap or 60000) then return end
        LastLawAlert[src] = now
        local coords = GetEntityCoords(GetPlayerPed(src))
        local text = locale('law_alert_theft')
        for _, v in pairs(RSGCore.Functions.GetRSGPlayers()) do
            local job = v.PlayerData.job
            if job and job.type == (T.lawJobType or 'leo') and job.onduty then
                TriggerClientEvent('rsg-lawman:client:lawmanAlert', v.PlayerData.source, coords, text)
            end
        end
    end
end

---------------------------------
-- callbacks
---------------------------------
Utils.callback('rsg-farming:server:getPlants', function(source)
    while not Loaded do Wait(100) end
    local list, mine, pos = buildFor(source)
    SyncPos[source] = pos
    return list, mine
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
    if Zones.blocked(coords) then return false, locale('place_blocked_zone') end
    if not Zones.farmland(coords) then return false, locale('place_not_farmland') end
    if Config.PlantTool and not Utils.hasItem(src, Config.PlantTool) then
        return false, locale('need_tool', toolLabel())
    end

    local cid = Player.PlayerData.citizenid
    local limit = maxPlantsFor(Player)
    if countPlants(cid) >= limit then
        return false, locale('max_plants', limit)
    end
    if Reserved[src] then return false, locale('action_invalid') end
    -- planting takes Config.PlantTime on the client; refuse callbacks that arrive faster than that
    local now = GetGameTimer()
    if LastPlant[src] and now - LastPlant[src] < Config.PlantTime * 0.8 then return false, locale('action_invalid') end
    for _, p in pairs(Plants) do
        if #(vector3(p.x, p.y, p.z) - coords) < Config.MinPlantDistance then
            return false, locale('place_too_close')
        end
    end
    for _, r in pairs(Reserved) do
        if #(r - coords) < Config.MinPlantDistance then return false, locale('place_too_close') end
    end
    if not Utils.removeItem(src, crop.seed, 1, nil, 'rsg-farming:plant') then return false, locale('no_seed') end

    LastPlant[src] = now
    local h = Utils.toHeading(heading)
    local share = shareKeyOf(Player)
    Reserved[src] = coords -- hold the spot while we wait on the DB
    local ok, id = pcall(MySQL.insert.await,
        'INSERT INTO rsg_farming_plants (citizenid, crop, x, y, z, h, growth, water, fertilizer, health, share_key) VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 100, ?)',
        { cid, cropKey, coords.x, coords.y, coords.z, h, share })
    Reserved[src] = nil

    if not ok or not id then
        Utils.giveOrDrop(src, crop.seed, 1, nil, 'rsg-farming:plant-refund')
        return false, locale('place_invalid')
    end

    Plants[id] = {
        id = id, citizenid = cid, crop = cropKey,
        x = coords.x, y = coords.y, z = coords.z, h = h,
        growth = 0, water = 0, fertilizer = 0, health = 100, dead = false, deadTime = 0,
        share = share,
    }
    pushPlant(Plants[id])
    TriggerClientEvent('rsg-farming:client:plantMine', src, id)
    addXP(src, Player, Config.XP.plant)
    if soilFatigue(coords.x, coords.y) >= (Config.Soil.warnAt or 50) then
        Utils.notify(src, locale('soil_poor'), 'warning')
    end
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

    -- rsg-wellpump owns the bucket: it takes one use and hands back the bucket (or an empty one)
    local usedOk = exports['rsg-wellpump']:UseBucket(source)
    if not usedOk then return false, locale('no_water') end

    plant.water = clamp(plant.water + Config.WaterAmount, 0, 100)
    Dirty[plant.id] = true
    pushPlant(plant)
    if plant.citizenid == Player.PlayerData.citizenid then addXP(source, Player, Config.XP.water) end
    return true, locale('watered')
end)

Utils.callback('rsg-farming:server:fertilize', function(source, plantId)
    local Player, plant, err = checkAction(source, 'fertilize', plantId)
    if not Player then return false, err end
    local fert = pickFertilizer(source)
    if not fert or not Utils.removeItem(source, fert.item, 1, nil, 'rsg-farming:fertilize') then
        return false, locale('no_fertilizer')
    end

    plant.fertilizer = clamp(plant.fertilizer + fert.amount, 0, 100)
    plant.fertBoost = fert.boost
    soilHealed(plant, fert.soil)
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
    -- bonus produce (never extra seeds): healthy plant and/or farming level perk; worn soil lowers it; thieves get a share
    local crop = Config.Crops[plant.crop]
    local thief = Config.Theft.enabled and not canManage(Player, plant)
    local quality = not thief and plant.health >= (Config.Harvest.qualityHealth or 90)
    local skilled = not thief and math.random(100) <= (perkOf(Player).bonusYieldChance or 0)
    local scale = soilMultiplier(plant) * (thief and (Config.Theft.yield or 1.0) or 1.0)
    local rewards = {}
    for _, r in ipairs(crop.harvest) do
        local amount = math.random(r.min, r.max)
        if amount > 0 and r.item ~= crop.seed then
            if quality then amount = amount + (Config.Harvest.qualityBonus or 1) end
            if skilled then amount = amount + 1 end
            amount = math.max(1, math.floor(amount * scale + 0.5))
        end
        if amount > 0 then rewards[#rewards + 1] = { item = r.item, amount = amount } end
    end
    if not Utils.canAddAll(source, rewards) then return false, locale('inv_full') end

    deletePlant(plant.id) -- remove first to stop double-harvest
    soilHarvested(plant)
    for _, r in ipairs(rewards) do
        -- satchel filled up between the check and now: drop it at their feet instead of losing it
        Utils.giveOrDrop(source, r.item, r.amount, nil, 'rsg-farming:harvest')
    end
    if thief then onTheft(source, plant, crop) end
    if plant.citizenid == Player.PlayerData.citizenid then addXP(source, Player, Config.XP.harvest) end
    return true, locale((quality or skilled) and 'harvested_bonus' or 'harvested')
end)

Utils.callback('rsg-farming:server:destroy', function(source, plantId)
    local Player, plant, err = validate(source, plantId)
    if not Player then return false, err end
    if not canManage(Player, plant) and not plant.dead then
        return false, locale('not_owner')
    end
    deletePlant(plant.id)
    return true, locale('destroyed')
end)

---------------------------------
-- scarecrows and sprinklers (Config.Scarecrow / Config.Sprinkler)
---------------------------------
local PropLast = {}   -- [src] = last place/pack time

local function propCfg(kind)
    local c = kind == 'scarecrow' and Config.Scarecrow or kind == 'sprinkler' and Config.Sprinkler or nil
    return c and c.enabled and c or nil
end

local function publicProp(pr) return { id = pr.id, kind = pr.kind, x = pr.x, y = pr.y, z = pr.z, h = pr.h } end

local function countProps(cid, kind)
    local n = 0
    for _, pr in pairs(Props) do
        if pr.citizenid == cid and pr.kind == kind then n = n + 1 end
    end
    return n
end

for _, kind in ipairs({ 'scarecrow', 'sprinkler' }) do
    local c = propCfg(kind)
    if c then
        RSGCore.Functions.CreateUseableItem(c.item, function(source)
            local Player = Utils.getPlayer(source)
            if not Player then return end
            if countProps(Player.PlayerData.citizenid, kind) >= c.maxPerPlayer then
                return Utils.notify(source, locale('prop_max', c.maxPerPlayer), 'error')
            end
            TriggerClientEvent('rsg-farming:client:startPlacingProp', source, kind)
        end)
    end
end

Utils.callback('rsg-farming:server:getProps', function(source)
    while not Loaded do Wait(100) end
    local Player = Utils.getPlayer(source)
    local cid = Player and Player.PlayerData.citizenid
    local list, mine = {}, {}
    for id, pr in pairs(Props) do
        list[#list + 1] = publicProp(pr)
        if pr.citizenid == cid then mine[#mine + 1] = id end
    end
    return list, mine
end)

Utils.callback('rsg-farming:server:placeProp', function(source, kind, coords, heading)
    local src = source
    local Player = Utils.getPlayer(src)
    local c = type(kind) == 'string' and propCfg(kind)
    coords = Utils.toCoords(coords)
    if not Player or not c or not coords then return false, locale('place_invalid') end
    if not exports['rsg-gizmo']:IsPlacementValid(src, coords, Config.PlaceMaxDistance) then
        return false, locale('place_too_far')
    end
    if Zones.blocked(coords) then return false, locale('place_blocked_zone') end

    local now = GetGameTimer()
    if PropLast[src] and now - PropLast[src] < Config.PlantTime * 0.8 then return false, locale('action_invalid') end
    local cid = Player.PlayerData.citizenid
    if countProps(cid, kind) >= c.maxPerPlayer then return false, locale('prop_max', c.maxPerPlayer) end
    for _, pr in pairs(Props) do
        if #(vector3(pr.x, pr.y, pr.z) - coords) < 1.5 then return false, locale('place_too_close') end
    end

    local pumpId
    if kind == 'sprinkler' then
        if not wellpumpUp() then return false, locale('sprinkler_no_pump') end
        local np = exports['rsg-wellpump']:GetNearestPump(coords, c.linkDistance)
        if not np then return false, locale('sprinkler_no_pump') end
        pumpId = np.id
    end

    if not Utils.removeItem(src, c.item, 1, nil, 'rsg-farming:place-' .. kind) then return false, locale('action_invalid') end
    PropLast[src] = now
    local h = Utils.toHeading(heading)
    local ok, id = pcall(MySQL.insert.await,
        'INSERT INTO rsg_farming_props (citizenid, kind, x, y, z, h, pump_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { cid, kind, coords.x, coords.y, coords.z, h, pumpId or 0 })
    if not ok or not id then
        Utils.giveOrDrop(src, c.item, 1, nil, 'rsg-farming:place-refund')
        return false, locale('place_invalid')
    end
    Props[id] = { id = id, citizenid = cid, kind = kind, x = coords.x, y = coords.y, z = coords.z, h = h, pump = pumpId }
    TriggerClientEvent('rsg-farming:client:propAdd', -1, publicProp(Props[id]))
    TriggerClientEvent('rsg-farming:client:propMine', src, id)
    return true, locale('prop_placed', locale('prop_' .. kind))
end)

Utils.callback('rsg-farming:server:packProp', function(source, propId)
    local src = source
    local Player = Utils.getPlayer(src)
    propId = tonumber(propId)
    local pr = propId and Props[propId]
    if not Player or not pr then return false, locale('action_invalid') end
    if pr.citizenid ~= Player.PlayerData.citizenid then return false, locale('prop_not_yours') end
    if #(GetEntityCoords(GetPlayerPed(src)) - vector3(pr.x, pr.y, pr.z)) > Config.InteractDistance + 2.0 then
        return false, locale('place_too_far')
    end
    local now = GetGameTimer()
    if PropLast[src] and now - PropLast[src] < 1000 then return false, locale('action_invalid') end
    PropLast[src] = now

    Props[propId] = nil
    pcall(MySQL.query.await, 'DELETE FROM rsg_farming_props WHERE id = ?', { propId })
    local c = Config[pr.kind == 'scarecrow' and 'Scarecrow' or 'Sprinkler']
    Utils.giveOrDrop(src, c.item, 1, nil, 'rsg-farming:pack-' .. pr.kind)
    TriggerClientEvent('rsg-farming:client:propRemove', -1, propId)
    return true, locale('prop_packed', locale('prop_' .. pr.kind))
end)

AddEventHandler('playerDropped', function() PropLast[source] = nil end)
