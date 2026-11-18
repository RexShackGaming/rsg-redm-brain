local RSGCore = exports['rsg-core']:GetCoreObject()

local Factories = {} -- [id] = { id, name, ped_model, x, y, z, h, recipes = {...} }
local Loaded = false

---------------------------------------------------------------------
-- Database
---------------------------------------------------------------------
local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `rsg_factories` (
      `id` INT NOT NULL AUTO_INCREMENT,
      `name` VARCHAR(64) NOT NULL,
      `ped_model` VARCHAR(64) NOT NULL,
      `x` DOUBLE NOT NULL,
      `y` DOUBLE NOT NULL,
      `z` DOUBLE NOT NULL,
      `h` DOUBLE NOT NULL DEFAULT 0,
      `recipes` LONGTEXT NOT NULL,
      `created_by` VARCHAR(50) DEFAULT NULL,
      `owner` VARCHAR(50) DEFAULT NULL,
      `owner_name` VARCHAR(64) DEFAULT NULL,
      `price` INT NOT NULL DEFAULT 5000,
      `fuel` INT NOT NULL DEFAULT 0,
      `water` INT NOT NULL DEFAULT 0,
      `bank` INT NOT NULL DEFAULT 0,
      `settings` LONGTEXT DEFAULT NULL,
      PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_factory_queue` (
      `id` INT NOT NULL AUTO_INCREMENT,
      `factory_id` INT NOT NULL,
      `citizenid` VARCHAR(50) NOT NULL,
      `label` VARCHAR(64) NOT NULL,
      `outputs` LONGTEXT NOT NULL,
      `finish_at` BIGINT NOT NULL,
      `stages` LONGTEXT DEFAULT NULL,
      `notified` TINYINT NOT NULL DEFAULT 0,
      PRIMARY KEY (`id`),
      KEY `idx_factory_citizen` (`factory_id`, `citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local function ensureDatabase()
    for i = 1, #SCHEMA do
        local ok, err = pcall(MySQL.query.await, SCHEMA[i])
        if not ok then
            print(('^1[rsg-factory] database setup failed: %s^7'):format(tostring(err)))
            return false
        end
    end
    -- safe upgrades for tables created by older versions (only ever adds missing columns)
    local COLUMNS = {
        { 'rsg_factory_queue', 'stages', 'LONGTEXT DEFAULT NULL' },
        { 'rsg_factories', 'owner', 'VARCHAR(50) DEFAULT NULL' },
        { 'rsg_factories', 'owner_name', 'VARCHAR(64) DEFAULT NULL' },
        { 'rsg_factories', 'price', 'INT NOT NULL DEFAULT 5000' },
        { 'rsg_factories', 'fuel', 'INT NOT NULL DEFAULT 0' },
        { 'rsg_factories', 'water', 'INT NOT NULL DEFAULT 0' },
        { 'rsg_factories', 'bank', 'INT NOT NULL DEFAULT 0' },
        { 'rsg_factories', 'settings', 'LONGTEXT DEFAULT NULL' },
        { 'rsg_factory_queue', 'notified', 'TINYINT NOT NULL DEFAULT 0' },
    }
    local ok, err = pcall(function()
        for _, c in ipairs(COLUMNS) do
            local has = MySQL.scalar.await(
                'SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
                { c[1], c[2] })
            if (has or 0) == 0 then
                MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(c[1], c[2], c[3]))
            end
        end
    end)
    if not ok then
        print(('^1[rsg-factory] database upgrade failed: %s^7'):format(tostring(err)))
        return false
    end
    print('^2[rsg-factory] database tables ready^7')
    return true
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function notify(src, key, ntype, ...)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('notify_title'),
        description = locale(key, ...),
        type = ntype or 'inform',
    })
end

local function isAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.AdminPermission) and true or false
end

local function nearFactory(src, f, extra)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - vector3(f.x, f.y, f.z)) <= (Config.InteractDistance + (extra or 2.0))
end

local function cleanText(s, max)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('%c', '')
    s = s:gsub('^%s+', '')
    s = s:gsub('%s+$', '')
    if #s < 1 or #s > max then return nil end
    return s
end

local function itemLabel(name)
    local it = RSGCore.Shared.Items[name]
    return it and it.label or name
end

-- picture file name for an item (rsg-core's `image` field, else <name>.png)
local function itemImage(name)
    local it = RSGCore.Shared.Items[name]
    return (it and it.image and it.image ~= '') and it.image or (tostring(name) .. '.png')
end

local function decorate(list)
    local out = {}
    for i = 1, #list do
        out[i] = { item = list[i].item, amount = list[i].amount, label = itemLabel(list[i].item), image = itemImage(list[i].item) }
    end
    return out
end

local function sanitizeList(list)
    if type(list) ~= 'table' or #list < 1 or #list > Config.MaxItemsPerRecipe then return nil end
    local out, seen = {}, {}
    for i = 1, #list do
        local e = list[i]
        if type(e) ~= 'table' or type(e.item) ~= 'string' then return nil end
        local amount = math.floor(tonumber(e.amount) or 0)
        if not RSGCore.Shared.Items[e.item] or seen[e.item] or amount < 1 or amount > Config.MaxAmount then
            return nil
        end
        seen[e.item] = true
        out[#out + 1] = { item = e.item, amount = amount }
    end
    return out
end

-- returns recipes, or nil + reason ('data' | 'chain')
local function sanitizeRecipes(raw)
    if type(raw) ~= 'table' or #raw > Config.MaxRecipes then return nil, 'data' end
    local out = {}
    for i = 1, #raw do
        local r = raw[i]
        if type(r) ~= 'table' then return nil, 'data' end
        local label = cleanText(r.label, 48)
        local inputs = sanitizeList(r.inputs)
        local outputs = sanitizeList(r.outputs)
        local time = math.floor(tonumber(r.time) or 0)
        local nextIdx = math.floor(tonumber(r.next) or 0)
        local fuel = r.fuel == nil and Config.DefaultFuelPerBatch or math.floor(tonumber(r.fuel) or -1)
        local water = r.water == nil and Config.DefaultWaterPerBatch or math.floor(tonumber(r.water) or -1)
        if fuel < 0 or fuel > Config.MaxUtilityPerBatch or water < 0 or water > Config.MaxUtilityPerBatch then
            return nil, 'data'
        end
        if not label or not inputs or not outputs or nextIdx < 0 then return nil, 'data' end
        if time < Config.MinTime or time > Config.MaxTime then return nil, 'data' end
        local job = nil
        if type(r.job) == 'string' and r.job ~= '' then
            if #r.job > 32 or not r.job:match('^[%w_%-]+$') then return nil, 'data' end
            job = r.job
        end
        out[#out + 1] = {
            label = label, inputs = inputs, outputs = outputs, time = time, job = job,
            fuel = fuel, water = water,
            next = nextIdx > 0 and nextIdx or nil,
        }
    end

    -- chains: next must exist, differ from itself and consume something the line outputs
    for i, r in ipairs(out) do
        if r.next then
            local nxt = out[r.next]
            if not nxt or r.next == i then return nil, 'chain' end
            local shares = false
            for _, o in ipairs(r.outputs) do
                for _, inp in ipairs(nxt.inputs) do
                    if o.item == inp.item then shares = true end
                end
            end
            if not shares then return nil, 'chain' end
        end
    end
    -- no loops, and chains no longer than Config.MaxChainLength
    for i = 1, #out do
        local seen, count, cur = {}, 0, i
        while cur do
            if seen[cur] then return nil, 'chain' end
            seen[cur] = true
            count = count + 1
            if count > Config.MaxChainLength then return nil, 'chain' end
            cur = out[cur].next
        end
    end
    return out
end

---------------------------------------------------------------------
-- Owner settings, access, alerts
---------------------------------------------------------------------
local function clampInt(v, lo, hi)
    return math.max(lo, math.min(hi, math.floor(tonumber(v) or 0)))
end

-- always returns a clean, complete settings table
local function normSettings(raw)
    raw = type(raw) == 'table' and raw or {}
    local s = {
        fee = clampInt(raw.fee, 0, Config.Fees.MaxPerBatch),
        access = (raw.access == 'trusted' or raw.access == 'owner') and raw.access or 'public',
        staffed = raw.staffed == true,
        paused = raw.paused == true,
        broken = raw.broken == true,
        tank = clampInt(raw.tank, 0, Config.Upgrades.tank.maxLevel),
        speed = clampInt(raw.speed, 0, Config.Upgrades.speed.maxLevel),
        trusted = {},
    }
    if type(raw.trusted) == 'table' then
        for _, t in ipairs(raw.trusted) do
            if #s.trusted >= Config.TrustedMax then break end
            if type(t) == 'table' and type(t.cid) == 'string' and #t.cid <= 50 and type(t.name) == 'string' then
                s.trusted[#s.trusted + 1] = { cid = t.cid, name = t.name:sub(1, 64) }
            end
        end
    end
    return s
end

local function capFuel(f) return Config.MaxFuel + f.settings.tank * Config.Upgrades.tank.bonus end
local function capWater(f) return Config.MaxWater + f.settings.tank * Config.Upgrades.tank.bonus end
local function speedPercent(f) return math.min(90, f.settings.speed * Config.Upgrades.speed.percent) end
local function speedMul(f) return 1 - speedPercent(f) / 100 end

local function isTrusted(f, cid)
    for _, t in ipairs(f.settings.trusted) do
        if t.cid == cid then return true end
    end
    return false
end

local function staffOnline(f)
    if RSGCore.Functions.GetPlayerByCitizenId(f.owner) then return true end
    for _, t in ipairs(f.settings.trusted) do
        if RSGCore.Functions.GetPlayerByCitizenId(t.cid) then return true end
    end
    return false
end

-- nil when the player may start production here, otherwise the locale key that says why not
local function usageBlock(f, Player)
    if not f.owner then return 'no_owner' end
    local cid = Player.PlayerData.citizenid
    local own = f.owner == cid
    local staff = own or isTrusted(f, cid)
    local s = f.settings
    if s.access == 'owner' and not own then return 'no_access' end
    if s.access == 'trusted' and not staff then return 'no_access' end
    if s.paused then return 'paused' end
    if s.broken then return 'broken' end
    if s.staffed and not staff and not staffOnline(f) then return 'not_staffed' end
    return nil
end

local function saveStock(f)
    MySQL.update.await('UPDATE `rsg_factories` SET `fuel` = ?, `water` = ?, `bank` = ? WHERE `id` = ?', { f.fuel, f.water, f.bank, f.id })
end

local function saveSettings(f)
    MySQL.update.await('UPDATE `rsg_factories` SET `settings` = ? WHERE `id` = ?', { json.encode(f.settings), f.id })
end

-- online: rsg-core notify; offline: telegram (when rsg-telegram is running)
local function alertCid(cid, key, ntype, ...)
    local P = RSGCore.Functions.GetPlayerByCitizenId(cid)
    if P then return notify(P.PlayerData.source, key, ntype, ...) end
    if Config.Alerts.telegram and GetResourceState('rsg-telegram') == 'started' then
        local args = table.pack(...)
        pcall(function()
            exports['rsg-telegram']:SendTelegram(cid, locale('notify_title'), locale(key, table.unpack(args, 1, args.n)), { senderName = locale('notify_title') })
        end)
    end
end

local function checkLowStock(f)
    local pct = Config.Alerts.lowStockPercent or 0
    if not f.owner or pct <= 0 then return end
    local low = f.fuel < capFuel(f) * pct / 100 or f.water < capWater(f) * pct / 100
    if not low then f.lowAt = nil return end
    local now = os.time()
    if f.lowAt and now - f.lowAt < Config.Alerts.lowStockCooldown then return end
    f.lowAt = now
    alertCid(f.owner, 'low_stock', 'warning', f.name, f.fuel, f.water)
end

-- Works out a whole chained run up front.
-- Stage 1 runs `batches`; every later stage runs as many batches as the previous
-- stage's output can feed. Inputs a later stage needs that the previous stage does
-- not make are taken from the player at the start. Surplus and by-products are
-- paid out with the final products.
-- returns { stages = {{label,time,job}}, upfront = {item=amount}, outputs = {{item,amount}}, total, fuel, water } or nil, 'chain'
-- fuel / water are the units the whole run burns from the factory's stock.
local function buildPlan(f, startIndex, batches)
    local stages, upfront, extra = {}, {}, {}
    local carry, total = nil, 0
    local fuelNeed, waterNeed = 0, 0
    local mul = speedMul(f)
    local idx, b = startIndex, batches
    local guard = 0

    while idx do
        guard = guard + 1
        local r = f.recipes[idx]
        if not r or guard > Config.MaxChainLength then return nil, 'chain' end

        local runs = b
        if carry then
            runs = math.huge
            local shared = false
            for _, e in ipairs(r.inputs) do
                if carry[e.item] then
                    shared = true
                    runs = math.min(runs, math.floor(carry[e.item] / e.amount))
                end
            end
            if not shared or runs < 1 then return nil, 'chain' end
        end

        for _, e in ipairs(r.inputs) do
            if not (carry and carry[e.item]) then
                upfront[e.item] = (upfront[e.item] or 0) + e.amount * runs
            end
        end
        if carry then
            for item, amt in pairs(carry) do
                local used = 0
                for _, e in ipairs(r.inputs) do
                    if e.item == item then used = e.amount * runs end
                end
                if amt - used > 0 then extra[item] = (extra[item] or 0) + (amt - used) end
            end
        end

        local stageTime = math.max(1, math.floor(r.time * runs * mul + 0.5))
        stages[#stages + 1] = { label = r.label, time = stageTime, job = r.job }
        total = total + stageTime
        fuelNeed = fuelNeed + (r.fuel or 0) * runs
        waterNeed = waterNeed + (r.water or 0) * runs

        carry = {}
        for _, o in ipairs(r.outputs) do carry[o.item] = o.amount * runs end
        idx = r.next
    end

    for item, amt in pairs(extra) do carry[item] = (carry[item] or 0) + amt end
    local outputs = {}
    for item, amt in pairs(carry) do outputs[#outputs + 1] = { item = item, amount = amt } end
    table.sort(outputs, function(a, b2) return a.item < b2.item end)
    return { stages = stages, upfront = upfront, outputs = outputs, total = total, fuel = fuelNeed, water = waterNeed }
end

-- One request at a time per player for anything that spends items, money or stock.
-- Callback handlers return true/false; errors are caught so the lock can never get stuck.
local busy = {}
local function lockedCallback(name, handler)
    RSGCore.Functions.CreateCallback(name, function(source, cb, ...)
        if busy[source] then return cb(false) end
        busy[source] = true
        local ok, res = pcall(handler, source, ...)
        busy[source] = nil
        if not ok then
            print(('^1[rsg-factory] %s failed: %s^7'):format(name, tostring(res)))
            return cb(false)
        end
        cb(res and true or false)
    end)
end

AddEventHandler('playerDropped', function() busy[source] = nil end)

local function supplyByKey(key)
    if type(key) ~= 'string' then return nil end
    for _, s in ipairs(Config.Supplies) do
        if s.key == key then return s end
    end
    return nil
end

-- status for this player: 'mine' | 'sale' | 'owned' (someone else's)
local function publicList(src)
    local P = src and RSGCore.Functions.GetPlayer(src)
    local cid = P and P.PlayerData.citizenid
    local list = {}
    for id, f in pairs(Factories) do
        local status = not f.owner and 'sale' or (f.owner == cid and 'mine' or 'owned')
        list[#list + 1] = { id = id, name = f.name, ped_model = f.ped_model, x = f.x, y = f.y, z = f.z, h = f.h, status = status }
    end
    return list
end

local function broadcast()
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        TriggerClientEvent('rsg-factory:client:sync', src, publicList(src))
    end
end

local function decorateRecipes(recipes)
    local out = {}
    for i = 1, #recipes do
        local r = recipes[i]
        out[i] = {
            label = r.label, time = r.time, job = r.job, next = r.next or 0,
            fuel = r.fuel or 0, water = r.water or 0,
            inputs = decorate(r.inputs), outputs = decorate(r.outputs),
        }
    end
    return out
end

local function getQueue(citizenid, factoryId)
    local rows = MySQL.query.await(
        'SELECT `id`, `label`, `outputs`, `finish_at`, `stages` FROM `rsg_factory_queue` WHERE `factory_id` = ? AND `citizenid` = ? ORDER BY `finish_at`',
        { factoryId, citizenid }) or {}
    local now = os.time()
    local out = {}
    for i = 1, #rows do
        local outputs = json.decode(rows[i].outputs) or {}

        -- chained runs: when each stage ends (seconds from now)
        local stages, raw = {}, rows[i].stages and json.decode(rows[i].stages) or {}
        local total = 0
        for _, s in ipairs(raw) do total = total + s.time end
        local cursor = rows[i].finish_at - total
        for _, s in ipairs(raw) do
            cursor = cursor + s.time
            stages[#stages + 1] = { label = s.label, endsIn = math.max(0, cursor - now) }
        end

        out[i] = {
            id = rows[i].id,
            label = rows[i].label,
            outputs = decorate(outputs),
            remaining = math.max(0, rows[i].finish_at - now),
            stages = stages,
        }
    end
    return out
end

local function factoryState(src, Player, f)
    local citizenid = Player.PlayerData.citizenid
    local mgmt = nil
    if f.owner and f.owner == citizenid then
        local s = f.settings
        local repairItem = Config.Breakdown.repairItem
        mgmt = {
            bank = f.bank, trusted = s.trusted,
            tank = s.tank, tankMax = Config.Upgrades.tank.maxLevel,
            tankCost = s.tank < Config.Upgrades.tank.maxLevel and Config.Upgrades.tank.cost * (s.tank + 1) or nil,
            speed = s.speed, speedMax = Config.Upgrades.speed.maxLevel,
            speedCost = s.speed < Config.Upgrades.speed.maxLevel and Config.Upgrades.speed.cost * (s.speed + 1) or nil,
            repairCost = (not repairItem) and Config.Breakdown.repairCost or nil,
            repairItem = repairItem and itemLabel(repairItem) or nil,
            sellValue = math.floor(f.price * Config.SellbackPercent / 100),
            feeMax = Config.Fees.MaxPerBatch,
        }
    end
    local supplies = {}
    for _, sp in ipairs(Config.Supplies) do
        supplies[#supplies + 1] = { key = sp.key, item = sp.item, image = itemImage(sp.item), label = itemLabel(sp.item), units = sp.units, stock = sp.stock }
    end
    return {
        id = f.id,
        name = f.name,
        ped_model = f.ped_model,
        owned = f.owner ~= nil,
        isOwner = f.owner ~= nil and f.owner == citizenid,
        ownerName = f.owner_name,
        price = f.price,
        fuel = f.fuel, water = f.water,
        maxFuel = capFuel(f), maxWater = capWater(f),
        fee = f.settings.fee, paused = f.settings.paused, broken = f.settings.broken, staffed = f.settings.staffed,
        access = f.settings.access, speedPct = speedPercent(f),
        blocked = usageBlock(f, Player),
        mgmt = mgmt,
        supplies = supplies,
        recipes = decorateRecipes(f.recipes),
        queue = getQueue(Player.PlayerData.citizenid, f.id),
        isAdmin = isAdmin(src),
        maxBatches = Config.MaxBatches,
        defaults = { fuel = Config.DefaultFuelPerBatch, water = Config.DefaultWaterPerBatch },
        limits = {
            recipes = Config.MaxRecipes, items = Config.MaxItemsPerRecipe, amount = Config.MaxAmount,
            minTime = Config.MinTime, maxTime = Config.MaxTime,
            utility = Config.MaxUtilityPerBatch, maxPrice = Config.MaxPrice,
        },
    }
end

---------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------
CreateThread(function()
    if Config.AutoDatabase and not ensureDatabase() then return end
    local rows = MySQL.query.await('SELECT * FROM `rsg_factories`') or {}
    for i = 1, #rows do
        local row = rows[i]
        local recipes, why = sanitizeRecipes(json.decode(row.recipes) or {})
        if not recipes then
            print(('^3[rsg-factory] factory #%d "%s": production lines rejected (%s), e.g. an item no longer exists. It loads with no lines; the saved lines stay in the database until you save this factory in the editor.^7')
                :format(row.id, row.name, why or 'data'))
            recipes = {}
        end
        Factories[row.id] = {
            id = row.id, name = row.name, ped_model = row.ped_model,
            x = row.x, y = row.y, z = row.z, h = row.h, recipes = recipes,
            owner = row.owner, owner_name = row.owner_name,
            price = row.price or Config.DefaultPrice, fuel = row.fuel or 0, water = row.water or 0,
            bank = row.bank or 0, settings = normSettings(row.settings and json.decode(row.settings) or nil),
        }
    end
    Loaded = true
    print(('^2[rsg-factory] loaded %d factories^7'):format(#rows))
end)

---------------------------------------------------------------------
-- Admin command: creates the factory where the admin stands
---------------------------------------------------------------------
RSGCore.Commands.Add(Config.CommandName, 'Create a factory at your position (admin)',
    { { name = 'name', help = 'Factory name' } }, false, function(source, args)
        local src = source
        if not isAdmin(src) then return notify(src, 'no_permission', 'error') end
        if not Loaded then return end
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return end

        local name = cleanText(table.concat(args or {}, ' '), 64)
        if not name then return notify(src, 'usage_create', 'error') end

        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)

        local id = MySQL.insert.await(
            'INSERT INTO `rsg_factories` (`name`, `ped_model`, `x`, `y`, `z`, `h`, `recipes`, `created_by`, `price`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { name, Config.DefaultPedModel, coords.x, coords.y, coords.z, heading, '[]', Player.PlayerData.citizenid, Config.DefaultPrice })
        if not id then return notify(src, 'invalid_data', 'error') end

        Factories[id] = {
            id = id, name = name, ped_model = Config.DefaultPedModel,
            x = coords.x, y = coords.y, z = coords.z, h = heading, recipes = {},
            price = Config.DefaultPrice, fuel = 0, water = 0, bank = 0, settings = normSettings(nil),
        }
        notify(src, 'factory_created', 'success', name)
        broadcast()
        TriggerClientEvent('rsg-factory:client:openAdmin', src, id)
    end, Config.AdminPermission)

---------------------------------------------------------------------
-- Callbacks
---------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-factory:server:getFactories', function(source, cb)
    if not Loaded then return cb(nil) end
    cb({ factories = publicList(source), isAdmin = isAdmin(source) })
end)

RSGCore.Functions.CreateCallback('rsg-factory:server:getFactory', function(source, cb, factoryId)
    local Player = RSGCore.Functions.GetPlayer(source)
    local f = Player and Factories[tonumber(factoryId)]
    if not f then return cb(nil) end
    if not nearFactory(source, f, 8.0) then
        notify(source, 'too_far', 'error')
        return cb(nil)
    end
    cb(factoryState(source, Player, f))
end)

RSGCore.Functions.CreateCallback('rsg-factory:server:getItems', function(source, cb)
    if not isAdmin(source) then return cb(nil) end
    local list = {}
    for name, it in pairs(RSGCore.Shared.Items) do
        list[#list + 1] = { name = name, label = it.label or name, image = itemImage(name) }
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    cb(list)
end)

RSGCore.Functions.CreateCallback('rsg-factory:server:saveFactory', function(source, cb, factoryId, data)
    if not isAdmin(source) then notify(source, 'no_permission', 'error') return cb(false) end
    local f = Factories[tonumber(factoryId)]
    if not f then notify(source, 'not_found', 'error') return cb(false) end
    if not nearFactory(source, f, 8.0) then notify(source, 'too_far', 'error') return cb(false) end
    if type(data) ~= 'table' then notify(source, 'invalid_data', 'error') return cb(false) end

    local name = cleanText(data.name, 64)
    local model = cleanText(data.ped_model or '', 64) or Config.DefaultPedModel
    local recipes, why = sanitizeRecipes(data.recipes)
    local price = math.floor(tonumber(data.price) or -1)
    if price < 0 or price > Config.MaxPrice then notify(source, 'invalid_data', 'error') return cb(false) end
    if not name or not model:match('^[%w_]+$') or not recipes then
        notify(source, why == 'chain' and 'chain_invalid' or 'invalid_data', 'error')
        return cb(false)
    end

    MySQL.update.await('UPDATE `rsg_factories` SET `name` = ?, `ped_model` = ?, `recipes` = ?, `price` = ? WHERE `id` = ?',
        { name, model, json.encode(recipes), price, f.id })
    f.name, f.ped_model, f.recipes, f.price = name, model, recipes, price
    notify(source, 'factory_saved', 'success')
    broadcast()
    cb(true)
end)

RSGCore.Functions.CreateCallback('rsg-factory:server:deleteFactory', function(source, cb, factoryId)
    if not isAdmin(source) then notify(source, 'no_permission', 'error') return cb(false) end
    local f = Factories[tonumber(factoryId)]
    if not f then notify(source, 'not_found', 'error') return cb(false) end
    if not nearFactory(source, f, 8.0) then notify(source, 'too_far', 'error') return cb(false) end

    MySQL.update.await('DELETE FROM `rsg_factory_queue` WHERE `factory_id` = ?', { f.id })
    MySQL.update.await('DELETE FROM `rsg_factories` WHERE `id` = ?', { f.id })
    Factories[f.id] = nil
    notify(source, 'factory_deleted', 'success')
    broadcast()
    cb(true)
end)

lockedCallback('rsg-factory:server:buyFactory', function(source, factoryId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local f = Player and Factories[tonumber(factoryId)]
    if not f then notify(src, 'not_found', 'error') return false end
    if not nearFactory(src, f) then notify(src, 'too_far', 'error') return false end
    if f.owner then notify(src, 'already_owned', 'error') return false end

    local citizenid = Player.PlayerData.citizenid
    local owned = 0
    for _, other in pairs(Factories) do
        if other.owner == citizenid then owned = owned + 1 end
    end
    if owned >= Config.MaxFactoriesPerPlayer then notify(src, 'max_owned', 'error') return false end

    if f.price > 0 and not Player.Functions.RemoveMoney('cash', f.price, 'rsg-factory:buy') then
        notify(src, 'cannot_afford', 'error')
        return false
    end
    -- claim straight away (no waits since the owner check) so two buyers can't both get it
    local ci = Player.PlayerData.charinfo or {}
    f.owner = citizenid
    f.owner_name = cleanText(((ci.firstname or '') .. ' ' .. (ci.lastname or '')), 64) or citizenid

    local saved = MySQL.update.await('UPDATE `rsg_factories` SET `owner` = ?, `owner_name` = ? WHERE `id` = ?', { f.owner, f.owner_name, f.id })
    if not saved or saved < 1 then
        f.owner, f.owner_name = nil, nil
        if f.price > 0 then Player.Functions.AddMoney('cash', f.price, 'rsg-factory:buy-refund') end
        notify(src, 'invalid_data', 'error')
        return false
    end
    notify(src, 'factory_bought', 'success', f.name)
    broadcast()
    return true
end)

lockedCallback('rsg-factory:server:addSupply', function(source, factoryId, key, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local f = Player and Factories[tonumber(factoryId)]
    if not f then notify(src, 'not_found', 'error') return false end
    if f.owner ~= Player.PlayerData.citizenid then notify(src, 'not_owner', 'error') return false end
    if not nearFactory(src, f) then notify(src, 'too_far', 'error') return false end

    local supply = supplyByKey(key)
    amount = math.floor(tonumber(amount) or 0)
    if not supply or amount < 1 then notify(src, 'invalid_data', 'error') return false end
    amount = math.min(amount, Config.MaxSupplyAtOnce)

    local cap = supply.stock == 'fuel' and capFuel(f) or capWater(f)
    local room = math.floor((cap - f[supply.stock]) / supply.units)
    if room < 1 then notify(src, 'storage_full', 'error') return false end
    amount = math.min(amount, room)

    if not exports['rsg-inventory']:HasItem(src, supply.item, amount) then
        notify(src, 'missing_supply', 'error')
        return false
    end
    if not exports['rsg-inventory']:RemoveItem(src, supply.item, amount, nil, 'rsg-factory:supply') then
        notify(src, 'missing_supply', 'error')
        return false
    end
    f[supply.stock] = f[supply.stock] + amount * supply.units
    if supply.returnItem and RSGCore.Shared.Items[supply.returnItem]
        and exports['rsg-inventory']:CanAddItem(src, supply.returnItem, amount) then
        exports['rsg-inventory']:AddItem(src, supply.returnItem, amount, nil, nil, 'rsg-factory:supply_return')
    end
    saveStock(f)

    notify(src, 'supply_added', 'success', amount, itemLabel(supply.item))
    return true
end)

lockedCallback('rsg-factory:server:startProduction', function(source, factoryId, recipeIndex, batches)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local f = Player and Factories[tonumber(factoryId)]
    local recipe = f and f.recipes[math.floor(tonumber(recipeIndex) or 0)]
    if not recipe then notify(src, 'not_found', 'error') return false end

    batches = math.floor(tonumber(batches) or 0)
    if batches < 1 or batches > Config.MaxBatches then notify(src, 'invalid_data', 'error') return false end
    if not nearFactory(src, f) then notify(src, 'too_far', 'error') return false end

    local block = usageBlock(f, Player)
    if block then notify(src, block, 'error') return false end

    local plan, perr = buildPlan(f, math.floor(tonumber(recipeIndex)), batches)
    if not plan then
        notify(src, perr == 'chain' and 'chain_too_small' or 'invalid_data', 'error')
        return false
    end

    -- every stage's job lock must be met
    for _, stage in ipairs(plan.stages) do
        if stage.job then
            local held = exports['rsg-core']:HasPlayerJob(src, stage.job)
            if not held and Player.PlayerData.job.name ~= stage.job then
                notify(src, 'job_required', 'error')
                return false
            end
        end
    end

    local citizenid = Player.PlayerData.citizenid
    local running = MySQL.scalar.await(
        'SELECT COUNT(*) FROM `rsg_factory_queue` WHERE `factory_id` = ? AND `citizenid` = ?', { f.id, citizenid }) or 0
    if running >= Config.MaxQueuePerPlayer then notify(src, 'queue_full', 'error') return false end

    for item, amount in pairs(plan.upfront) do
        if not exports['rsg-inventory']:HasItem(src, item, amount) then
            notify(src, 'missing_items', 'error')
            return false
        end
    end

    -- the factory's own fuel and water (stocked by the owner) pay for the run.
    -- checked and taken in the same step (no waits in between) so two players can't spend the same stock.
    if f.fuel < plan.fuel then notify(src, 'no_fuel', 'error') return false end
    if f.water < plan.water then notify(src, 'no_water', 'error') return false end

    -- the owner's fee (other players only), paid into the factory's earnings
    local fee = 0
    if f.owner ~= citizenid and f.settings.fee > 0 then fee = f.settings.fee * batches end
    if fee > 0 and not Player.Functions.RemoveMoney('cash', fee, 'rsg-factory:fee') then
        notify(src, 'cannot_afford_fee', 'error', fee)
        return false
    end
    f.bank = f.bank + fee
    f.fuel = f.fuel - plan.fuel
    f.water = f.water - plan.water

    local removed = {}
    local function undo()
        for _, r in ipairs(removed) do
            exports['rsg-inventory']:AddItem(src, r.item, r.amount, nil, nil, 'rsg-factory:rollback')
        end
        f.fuel = f.fuel + plan.fuel
        f.water = f.water + plan.water
        if fee > 0 then
            f.bank = f.bank - fee
            Player.Functions.AddMoney('cash', fee, 'rsg-factory:fee-refund')
        end
    end
    for item, amount in pairs(plan.upfront) do
        if exports['rsg-inventory']:RemoveItem(src, item, amount, nil, 'rsg-factory:input') then
            removed[#removed + 1] = { item = item, amount = amount }
        else
            undo()
            notify(src, 'missing_items', 'error')
            return false
        end
    end
    saveStock(f)

    local stages = {}
    for i, s in ipairs(plan.stages) do stages[i] = { label = s.label, time = s.time } end
    local rowId = MySQL.insert.await(
        'INSERT INTO `rsg_factory_queue` (`factory_id`, `citizenid`, `label`, `outputs`, `finish_at`, `stages`) VALUES (?, ?, ?, ?, ?, ?)',
        { f.id, citizenid, recipe.label, json.encode(plan.outputs), os.time() + plan.total, json.encode(stages) })
    if not rowId then
        -- nothing was queued: give the inputs and the fuel/water back
        undo()
        saveStock(f)
        notify(src, 'invalid_data', 'error')
        return false
    end

    notify(src, 'production_started', 'success', recipe.label, batches)

    -- chance of a breakdown (this run still finishes), then the low stock warning
    if Config.Breakdown.enabled and math.random() * 100 < Config.Breakdown.chance then
        f.settings.broken = true
        saveSettings(f)
        alertCid(f.owner, 'factory_broke', 'error', f.name)
    end
    checkLowStock(f)
    return true
end)

---------------------------------------------------------------------
-- Payout (manual collect and auto delivery)
---------------------------------------------------------------------
-- Pays finished queue rows to an online player. A row is only paid when all its products fit.
-- Returns collected, blocked.
local function payoutRows(src, Player, rows)
    local collected, blocked = false, false
    for _, row in ipairs(rows) do
        local outputs = json.decode(row.outputs) or {}
        local canAll = true
        for _, e in ipairs(outputs) do
            if not exports['rsg-inventory']:CanAddItem(src, e.item, e.amount) then canAll = false break end
        end

        if not canAll then
            blocked = true
        else
            -- delete first so a row can never be paid out twice
            local affected = MySQL.update.await('DELETE FROM `rsg_factory_queue` WHERE `id` = ?', { row.id })
            if affected and affected > 0 then
                local leftover = {}
                for _, e in ipairs(outputs) do
                    if not exports['rsg-inventory']:AddItem(src, e.item, e.amount, nil, nil, 'rsg-factory:output') then
                        leftover[#leftover + 1] = e
                    end
                end
                if #leftover > 0 then
                    MySQL.insert.await(
                        'INSERT INTO `rsg_factory_queue` (`factory_id`, `citizenid`, `label`, `outputs`, `finish_at`, `notified`) VALUES (?, ?, ?, ?, ?, 1)',
                        { row.factory_id, Player.PlayerData.citizenid, locale('leftover_label'), json.encode(leftover), os.time() })
                    blocked = true
                end
                collected = true
            end
        end
    end
    return collected, blocked
end

lockedCallback('rsg-factory:server:collect', function(source, factoryId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local f = Player and Factories[tonumber(factoryId)]
    if not f then return false end
    if not nearFactory(src, f) then notify(src, 'too_far', 'error') return false end

    local rows = MySQL.query.await(
        'SELECT `id`, `factory_id`, `outputs` FROM `rsg_factory_queue` WHERE `factory_id` = ? AND `citizenid` = ? AND `finish_at` <= ?',
        { f.id, Player.PlayerData.citizenid, os.time() }) or {}
    if #rows == 0 then notify(src, 'nothing_ready', 'error') return false end

    local collected, blocked = payoutRows(src, Player, rows)
    if blocked then notify(src, 'inventory_full', 'error') end
    if collected then notify(src, 'collected', 'success') end
    return collected
end)

---------------------------------------------------------------------
-- Finished productions: auto delivery + "ready" alerts
---------------------------------------------------------------------
local function handleFinished(row)
    local P = RSGCore.Functions.GetPlayerByCitizenId(row.citizenid)
    local f = Factories[row.factory_id]
    if P and Config.AutoDeliver then
        local src = P.PlayerData.source
        if not busy[src] then
            local collected, blocked = payoutRows(src, P, { row })
            if collected and not blocked then
                return notify(src, 'auto_delivered', 'success', row.label)
            end
        end
    end
    if not Config.Alerts.ready then return end
    if P then
        notify(P.PlayerData.source, 'production_ready', 'inform', row.label)
    elseif Config.Alerts.telegram and GetResourceState('rsg-telegram') == 'started' then
        pcall(function()
            exports['rsg-telegram']:SendTelegram(row.citizenid, locale('notify_title'),
                locale('production_ready_msg', row.label, f and f.name or locale('notify_title')),
                { senderName = locale('notify_title') })
        end)
    end
end

CreateThread(function()
    while not Loaded do Wait(1000) end
    while true do
        Wait(math.max(5, Config.Alerts.interval) * 1000)
        local rows = MySQL.query.await(
            'SELECT `id`, `factory_id`, `citizenid`, `label`, `outputs` FROM `rsg_factory_queue` WHERE `finish_at` <= ? AND `notified` = 0',
            { os.time() }) or {}
        for _, row in ipairs(rows) do
            -- claim the row first so it is handled exactly once
            local claimed = MySQL.update.await('UPDATE `rsg_factory_queue` SET `notified` = 1 WHERE `id` = ? AND `notified` = 0', { row.id })
            if claimed and claimed > 0 then
                local ok, err = pcall(handleFinished, row)
                if not ok then print(('^1[rsg-factory] finished-production handling failed: %s^7'):format(tostring(err))) end
            end
        end
    end
end)

---------------------------------------------------------------------
-- Owner panel actions
---------------------------------------------------------------------
local pendingTransfer = {} -- [receiver src] = { factoryId, fromCid, expires }
AddEventHandler('playerDropped', function() pendingTransfer[source] = nil end)

local function countOwned(cid)
    local n = 0
    for _, other in pairs(Factories) do
        if other.owner == cid then n = n + 1 end
    end
    return n
end

local function displayName(Player)
    local ci = Player.PlayerData.charinfo or {}
    return cleanText(((ci.firstname or '') .. ' ' .. (ci.lastname or '')), 64) or Player.PlayerData.citizenid
end

local function charName(charinfo, cid)
    if type(charinfo) == 'string' then
        local ok, d = pcall(json.decode, charinfo)
        charinfo = ok and d or {}
    end
    charinfo = type(charinfo) == 'table' and charinfo or {}
    return cleanText(((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')), 64) or cid
end

-- an online player (by citizenid) standing at the factory (used for transfers)
local function playerAtFactory(f, cid)
    if type(cid) ~= 'string' or #cid > 32 then return nil end
    local T = RSGCore.Functions.GetPlayerByCitizenId(cid)
    if not T then return nil end
    local tsrc = T.PlayerData.source
    if not nearFactory(tsrc, f, 10.0) then return nil end
    return T, tsrc
end

-- player picker for the owner panel: online players first, then a database lookup of every character
-- mode 'transfer' lists online players only (the buyer has to accept in person)
local searchAt = {}
RSGCore.Functions.CreateCallback('rsg-factory:server:findPlayers', function(source, cb, factoryId, query, mode)
    local Player = RSGCore.Functions.GetPlayer(source)
    local f = Player and Factories[tonumber(factoryId)]
    if not f or f.owner ~= Player.PlayerData.citizenid then return cb({}) end
    local now = GetGameTimer()
    if searchAt[source] and now - searchAt[source] < 300 then return cb({}) end
    searchAt[source] = now

    local q = type(query) == 'string' and query:sub(1, 32):lower():gsub('^%s+', ''):gsub('%s+$', '') or ''
    local onlineOnly = mode == 'transfer'
    local skip = { [f.owner] = true }
    if not onlineOnly then
        for _, t in ipairs(f.settings.trusted) do skip[t.cid] = true end
    end

    local out, seen = {}, {}
    local function add(cid, name, online)
        if seen[cid] or skip[cid] or #out >= 30 then return end
        seen[cid] = true
        out[#out + 1] = { cid = cid, name = name, online = online }
    end

    for _, id in ipairs(RSGCore.Functions.GetPlayers()) do
        local P = RSGCore.Functions.GetPlayer(id)
        if P then
            local cid = P.PlayerData.citizenid
            local name = displayName(P)
            if q == '' or name:lower():find(q, 1, true) or cid:lower():find(q, 1, true) or tostring(id) == q then
                add(cid, name, true)
            end
        end
    end

    if not onlineOnly and #q >= 2 then
        local like = '%' .. q:gsub('[%%_\\]', '\\%0') .. '%'
        local ok, rows = pcall(MySQL.query.await,
            "SELECT citizenid, charinfo FROM players WHERE citizenid LIKE ? OR LOWER(CONCAT_WS(' ', JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')))) LIKE ? LIMIT 30",
            { like, like })
        if ok and rows then
            for _, r in ipairs(rows) do add(r.citizenid, charName(r.charinfo, r.citizenid), false) end
        end
    end

    cb(out)
end)

AddEventHandler('playerDropped', function() searchAt[source] = nil end)

lockedCallback('rsg-factory:server:ownerAction', function(source, factoryId, action, data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local f = Player and Factories[tonumber(factoryId)]
    if not f then notify(src, 'not_found', 'error') return false end
    local cid = Player.PlayerData.citizenid
    if f.owner ~= cid then notify(src, 'not_owner', 'error') return false end
    if not nearFactory(src, f, 8.0) then notify(src, 'too_far', 'error') return false end
    if type(action) ~= 'string' then return false end
    data = type(data) == 'table' and data or {}
    local s = f.settings

    if action == 'setFee' then
        local fee = math.floor(tonumber(data.value) or -1)
        if fee < 0 or fee > Config.Fees.MaxPerBatch then notify(src, 'invalid_data', 'error') return false end
        s.fee = fee
        saveSettings(f)
        notify(src, 'factory_saved', 'success')
        return true

    elseif action == 'setAccess' then
        if data.value ~= 'public' and data.value ~= 'trusted' and data.value ~= 'owner' then
            notify(src, 'invalid_data', 'error') return false
        end
        s.access = data.value
        saveSettings(f)
        return true

    elseif action == 'setStaffed' then
        s.staffed = data.value == true
        saveSettings(f)
        return true

    elseif action == 'setPaused' then
        s.paused = data.value == true
        saveSettings(f)
        return true

    elseif action == 'addTrusted' then
        if #s.trusted >= Config.TrustedMax then notify(src, 'trusted_full', 'error') return false end
        local tcid = data.cid
        if type(tcid) ~= 'string' or #tcid > 32 or tcid == cid then notify(src, 'player_not_found', 'error') return false end
        if isTrusted(f, tcid) then return true end
        local T = RSGCore.Functions.GetPlayerByCitizenId(tcid)
        local name
        if T then
            name = displayName(T)
        else
            local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { tcid })
            if not row then notify(src, 'player_not_found', 'error') return false end
            name = charName(row.charinfo, tcid)
        end
        s.trusted[#s.trusted + 1] = { cid = tcid, name = name }
        saveSettings(f)
        notify(src, 'trusted_added', 'success', name)
        return true

    elseif action == 'removeTrusted' then
        if type(data.cid) ~= 'string' then return false end
        for i, t in ipairs(s.trusted) do
            if t.cid == data.cid then
                table.remove(s.trusted, i)
                saveSettings(f)
                notify(src, 'trusted_removed', 'success')
                return true
            end
        end
        return false

    elseif action == 'withdraw' then
        local amount = f.bank
        if amount < 1 then notify(src, 'nothing_to_withdraw', 'error') return false end
        f.bank = 0
        Player.Functions.AddMoney('cash', amount, 'rsg-factory:earnings')
        saveStock(f)
        notify(src, 'withdrawn', 'success', amount)
        return true

    elseif action == 'upgrade' then
        local kind = data.kind
        if kind ~= 'tank' and kind ~= 'speed' then notify(src, 'invalid_data', 'error') return false end
        local up = Config.Upgrades[kind]
        local level = s[kind]
        if level >= up.maxLevel then notify(src, 'upgrade_max', 'error') return false end
        if not Player.Functions.RemoveMoney('cash', up.cost * (level + 1), 'rsg-factory:upgrade') then
            notify(src, 'not_enough_money', 'error')
            return false
        end
        s[kind] = level + 1
        saveSettings(f)
        notify(src, 'upgraded', 'success', level + 1)
        return true

    elseif action == 'repair' then
        if not s.broken then notify(src, 'invalid_data', 'error') return false end
        local item = Config.Breakdown.repairItem
        if item then
            if not RSGCore.Shared.Items[item] or not exports['rsg-inventory']:HasItem(src, item, 1)
                or not exports['rsg-inventory']:RemoveItem(src, item, 1, nil, 'rsg-factory:repair') then
                notify(src, 'missing_supply', 'error')
                return false
            end
        elseif not Player.Functions.RemoveMoney('cash', Config.Breakdown.repairCost, 'rsg-factory:repair') then
            notify(src, 'not_enough_money', 'error')
            return false
        end
        s.broken = false
        saveSettings(f)
        notify(src, 'repaired', 'success')
        return true

    elseif action == 'sell' then
        local payout = math.floor(f.price * Config.SellbackPercent / 100) + f.bank
        local ns = normSettings(s)
        ns.fee, ns.access, ns.staffed, ns.paused, ns.trusted = 0, 'public', false, false, {}
        -- save first; only pay out when the sale is really stored
        local affected = MySQL.update.await(
            'UPDATE `rsg_factories` SET `owner` = NULL, `owner_name` = NULL, `bank` = 0, `fuel` = 0, `water` = 0, `settings` = ? WHERE `id` = ? AND `owner` = ?',
            { json.encode(ns), f.id, cid })
        if not affected or affected < 1 then notify(src, 'invalid_data', 'error') return false end
        f.owner, f.owner_name, f.bank, f.fuel, f.water, f.settings = nil, nil, 0, 0, 0, ns
        if payout > 0 then Player.Functions.AddMoney('cash', payout, 'rsg-factory:sell') end
        notify(src, 'factory_sold', 'success', payout)
        broadcast()
        return true

    elseif action == 'transfer' then
        local T, tsrc = playerAtFactory(f, data.cid)
        if not T or T.PlayerData.citizenid == cid then notify(src, 'player_not_found', 'error') return false end
        pendingTransfer[tsrc] = { factoryId = f.id, fromCid = cid, expires = os.time() + Config.TransferExpiry }
        notify(src, 'transfer_sent', 'inform', displayName(T), Config.TransferExpiry)
        notify(tsrc, 'transfer_offer', 'inform', displayName(Player), f.name)
        return true
    end

    notify(src, 'invalid_data', 'error')
    return false
end)

RSGCore.Commands.Add('acceptfactory', 'Accept a factory transfer offer', {}, false, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or busy[src] then return end
    local offer = pendingTransfer[src]
    pendingTransfer[src] = nil
    if not offer or offer.expires < os.time() then return notify(src, 'transfer_none', 'error') end

    local f = Factories[offer.factoryId]
    local cid = Player.PlayerData.citizenid
    local old = RSGCore.Functions.GetPlayerByCitizenId(offer.fromCid)
    if not f or f.owner ~= offer.fromCid or not old or not nearFactory(src, f, 10.0)
        or countOwned(cid) >= Config.MaxFactoriesPerPlayer then
        return notify(src, 'transfer_failed', 'error')
    end

    busy[src] = true
    local name = displayName(Player)
    local ns = normSettings(f.settings)
    ns.trusted = {}
    local affected = MySQL.update.await(
        'UPDATE `rsg_factories` SET `owner` = ?, `owner_name` = ?, `bank` = 0, `settings` = ? WHERE `id` = ? AND `owner` = ?',
        { cid, name, json.encode(ns), f.id, offer.fromCid })
    busy[src] = nil
    if not affected or affected < 1 then return notify(src, 'transfer_failed', 'error') end

    local earnings = f.bank
    f.owner, f.owner_name, f.bank, f.settings = cid, name, 0, ns
    if earnings > 0 then old.Functions.AddMoney('cash', earnings, 'rsg-factory:transfer-earnings') end
    notify(old.PlayerData.source, 'transfer_done_owner', 'success', name)
    notify(src, 'transfer_done_target', 'success', f.name)
    broadcast()
end, 'user')
