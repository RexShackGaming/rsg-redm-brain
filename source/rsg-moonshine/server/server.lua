local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- [id] = { id, citizenid, coords, heading, recipe, hopper = {item=count}, output, fuel, batch_left, last_tick }
local Stills = {}
local Recipes = {}
for _, r in ipairs(Config.Recipes) do Recipes[r.key] = r end
local Fuels = {}
for _, f in ipairs(Config.Fuels) do Fuels[f.item] = f end

---------------------------------
-- helpers
---------------------------------
local function notify(src, desc, ntype)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('cl_still'), description = desc, type = ntype or 'inform', duration = 5000 })
end

local function isBrewing(s) return s.batch_left ~= nil and s.fuel > 0 end

local WORLD = 'world' -- citizenid used for static map stills

local function publicStill(s)
    return { id = s.id, coords = s.coords, heading = s.heading, brewing = isBrewing(s), world = s.citizenid == WORLD or nil }
end

local function itemInfo(name)
    local i = RSGCore.Shared.Items[name]
    return (i and i.label or name), (i and i.image or (name .. '.png'))
end

-- recipe names come from locales (recipe_<key>), falling back to the label in config
local function recipeLabel(r)
    local key = 'recipe_' .. r.key
    local l = locale(key)
    return (l and l ~= key) and l or r.label
end

local function getXp(Player)
    local rep = Player.PlayerData.metadata.rep or {}
    return tonumber(rep[Config.XpName]) or 0
end

local function getLevel(xp)
    local level = 1
    for lvl, need in ipairs(Config.Levels) do
        if xp >= need then level = lvl end
    end
    return level
end

local function isNear(src, coords, dist)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= (dist or Config.InteractDist)
end

-- per-player throttles: throttled('action', src, 300) is true if called again within 300ms
local Throttle = { action = {}, state = {}, destroy = {}, world = {} }
local function throttled(bucket, src, ms)
    local now, last = GetGameTimer(), Throttle[bucket][src]
    if last and now - last < ms then return true end
    Throttle[bucket][src] = now
    return false
end
AddEventHandler('playerDropped', function()
    for _, b in pairs(Throttle) do b[source] = nil end
end)

local function isLaw(Player)
    local job = Player.PlayerData.job
    for _, j in ipairs(Config.LawJobs) do
        if job.name == j then return (not Config.LawRequireDuty) or job.onduty end
    end
    return false
end

local function canUse(Player, still)
    return (not Config.OwnerOnly) or still.citizenid == WORLD or still.citizenid == Player.PlayerData.citizenid
end

local function countOwned(cid)
    local n = 0
    for _, s in pairs(Stills) do if s.citizenid == cid then n = n + 1 end end
    return n
end

local function hopperEmpty(s)
    for _, c in pairs(s.hopper) do if c > 0 then return false end end
    return true
end

local function saveStill(s)
    MySQL.update('UPDATE rsg_moonshine_stills SET recipe = ?, hopper = ?, output = ?, fuel = ?, batch_left = ?, last_tick = ? WHERE id = ?',
        { s.recipe, json.encode(s.hopper), s.output, s.fuel, s.batch_left, s.last_tick, s.id })
end

---------------------------------
-- brewing logic (lazy, restart safe)
---------------------------------
local function canStartBatch(s, r)
    if s.output + r.output.amount > Config.OutputCap then return false end
    for _, ing in ipairs(r.ingredients) do
        if (s.hopper[ing.item] or 0) < ing.amount then return false end
    end
    return true
end

local function consumeBatch(s, r)
    for _, ing in ipairs(r.ingredients) do
        s.hopper[ing.item] = s.hopper[ing.item] - ing.amount
        if s.hopper[ing.item] <= 0 then s.hopper[ing.item] = nil end
    end
end

-- advances a still to "now". Time only counts while there is fuel in the firebox.
-- The simulation is deterministic from (saved state + last_tick), so the background
-- tick never needs to write to the DB; only player actions persist.
local function simulate(s, now)
    local elapsed = math.max(0, now - (s.last_tick or now))
    s.last_tick = now

    local r = s.recipe and Recipes[s.recipe]
    if not r then
        s.batch_left = nil
        return
    end

    while true do
        if not s.batch_left then
            -- start a new batch only if there is fuel, ingredients and tank room
            if s.fuel <= 0 or not canStartBatch(s, r) then break end
            consumeBatch(s, r)
            s.batch_left = r.time
        end
        if elapsed <= 0 or s.fuel <= 0 then break end

        local step = math.min(elapsed, s.batch_left, s.fuel)
        s.batch_left = s.batch_left - step
        s.fuel = s.fuel - step
        elapsed = elapsed - step

        if s.batch_left <= 0 then
            s.output = math.min(Config.OutputCap, s.output + r.output.amount)
            s.batch_left = nil
        end
    end
end

-- advances in memory and syncs the brewing flag (fx) to clients; callers save when needed
local function processStill(s, now)
    local wasBrewing = isBrewing(s)
    simulate(s, now)
    if isBrewing(s) ~= wasBrewing then
        TriggerClientEvent('rsg-moonshine:client:syncStill', -1, publicStill(s))
    end
end

local function queuedBatches(s, r)
    local n = math.huge
    for _, ing in ipairs(r.ingredients) do
        n = math.min(n, (s.hopper[ing.item] or 0) // ing.amount)
    end
    return n == math.huge and 0 or n
end

---------------------------------
-- state for the NUI
---------------------------------
local function buildState(src, s)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    processStill(s, os.time())

    local counts = {}
    local function have(item)
        if not counts[item] then counts[item] = exports['rsg-inventory']:GetItemCount(src, item) or 0 end
        return counts[item]
    end
    local xp = getXp(Player)

    local state = {
        id = s.id,
        isOwner = s.citizenid == Player.PlayerData.citizenid,
        canUse = canUse(Player, s),
        recipe = s.recipe,
        output = s.output,
        outputCap = Config.OutputCap,
        maxBatches = Config.MaxBatches,
        hopperEmpty = hopperEmpty(s),
        fuel = s.fuel,
        maxFuel = Config.MaxFuel,
        xp = xp,
        level = getLevel(xp),
        maxLevel = #Config.Levels,
        jugs = have(Config.EmptyJug),
        jugLabel = (itemInfo(Config.EmptyJug)),
        fuels = {},
        recipes = {},
    }

    local nextNeed = Config.Levels[state.level + 1]
    state.levelXp = Config.Levels[state.level] or 0
    state.nextXp = nextNeed -- nil at max level

    for _, f in ipairs(Config.Fuels) do
        local label, img = itemInfo(f.item)
        state.fuels[#state.fuels + 1] = {
            item = f.item, label = label, image = img, burnTime = f.burnTime,
            have = have(f.item),
        }
    end

    for _, r in ipairs(Config.Recipes) do
        local outLabel, outImg = itemInfo(r.output.item)
        local rec = {
            key = r.key, label = recipeLabel(r), time = r.time, level = r.level or 1,
            output = { item = r.output.item, label = outLabel, image = outImg, amount = r.output.amount },
            ingredients = {},
        }
        for _, ing in ipairs(r.ingredients) do
            local label, img = itemInfo(ing.item)
            rec.ingredients[#rec.ingredients + 1] = {
                item = ing.item, label = label, image = img, perBatch = ing.amount,
                loaded = (r.key == s.recipe) and (s.hopper[ing.item] or 0) or 0,
                capacity = ing.amount * Config.MaxBatches,
                have = have(ing.item),
            }
        end
        state.recipes[#state.recipes + 1] = rec
    end

    if s.recipe and Recipes[s.recipe] then
        local r = Recipes[s.recipe]
        state.queued = queuedBatches(s, r)
        if s.batch_left then
            state.batch = { remaining = s.batch_left, total = r.time, running = s.fuel > 0 }
            state.status = s.fuel > 0 and 'brewing' or 'nofuel'
        elseif s.output + r.output.amount > Config.OutputCap then
            state.status = 'full'
        elseif canStartBatch(s, r) and s.fuel <= 0 then
            state.status = 'nofuel'
        else
            state.status = 'waiting'
        end
    else
        state.status = 'idle'
    end
    return state
end

---------------------------------
-- startup
---------------------------------
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rsg_moonshine_stills` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0,
            `recipe` VARCHAR(50) DEFAULT NULL,
            `hopper` LONGTEXT DEFAULT NULL,
            `output` INT NOT NULL DEFAULT 0,
            `fuel` INT NOT NULL DEFAULT 0,
            `batch_left` INT DEFAULT NULL,
            `last_tick` INT DEFAULT NULL,
            PRIMARY KEY (`id`)
        )
    ]])
    -- upgrade tables created by earlier versions (MariaDB syntax; on MySQL 8 run the ALTERs in installation/rsg-moonshine.sql)
    for _, col in ipairs({
        '`hopper` LONGTEXT DEFAULT NULL', '`output` INT NOT NULL DEFAULT 0', '`fuel` INT NOT NULL DEFAULT 0',
        '`batch_left` INT DEFAULT NULL', '`last_tick` INT DEFAULT NULL',
    }) do
        pcall(MySQL.query.await, 'ALTER TABLE `rsg_moonshine_stills` ADD COLUMN IF NOT EXISTS ' .. col)
    end

    local rows = MySQL.query.await('SELECT * FROM rsg_moonshine_stills') or {}
    for _, r in ipairs(rows) do
        Stills[r.id] = {
            id = r.id, citizenid = r.citizenid, coords = vector3(r.x, r.y, r.z), heading = r.heading,
            recipe = r.recipe, hopper = (r.hopper and json.decode(r.hopper)) or {}, output = r.output or 0, fuel = r.fuel or 0, batch_left = r.batch_left, last_tick = r.last_tick,
        }
    end
    print(('[rsg-moonshine] loaded %d stills'):format(#rows))

    RSGCore.Functions.CreateUseableItem(Config.StillItem, function(source)
        TriggerClientEvent('rsg-moonshine:client:placeStill', source)
    end)

    -- keep stills brewing while nobody is looking at them
    while true do
        Wait(Config.TickInterval * 1000)
        local now = os.time()
        for _, s in pairs(Stills) do processStill(s, now) end
    end
end)

-- persist simulated progress on stop so a config change between restarts can't rewrite history
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local now = os.time()
    for _, s in pairs(Stills) do processStill(s, now) saveStill(s) end
end)

lib.callback.register('rsg-moonshine:server:getStills', function()
    local list = {}
    for _, s in pairs(Stills) do list[#list + 1] = publicStill(s) end
    return list
end)

lib.callback.register('rsg-moonshine:server:getState', function(src, id)
    local s = Stills[id]
    if not s or throttled('state', src, 250) or not isNear(src, s.coords) then return nil end
    return buildState(src, s)
end)

---------------------------------
-- NUI actions
---------------------------------
local Actions = {}

Actions.selectRecipe = function(src, Player, s, data)
    local r = Recipes[data.recipe]
    if not r then return end
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    if s.recipe == r.key then return end
    if getLevel(getXp(Player)) < (r.level or 1) then return notify(src, locale('sv_level_low'):format(r.level or 1), 'error') end
    if not hopperEmpty(s) or s.batch_left or s.output > 0 then return notify(src, locale('sv_empty_first'), 'error') end
    s.recipe = r.key
    saveStill(s)
    WebhookLog('recipe', src, locale('wh_recipe_title'), locale('wh_recipe_desc'):format(s.id, recipeLabel(r)),
        { { locale('wh_field_still_id'), s.id }, { locale('wh_field_owner'), s.citizenid }, CoordsField(s.coords) })
end

Actions.load = function(src, Player, s, data)
    local r = s.recipe and Recipes[s.recipe]
    if not r then return end
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    local ing
    for _, i in ipairs(r.ingredients) do if i.item == data.item then ing = i break end end
    if not ing then return end

    local amount = math.floor(tonumber(data.amount) or 0)
    local space = ing.amount * Config.MaxBatches - (s.hopper[ing.item] or 0)
    local have = exports['rsg-inventory']:GetItemCount(src, ing.item) or 0
    amount = math.min(amount, space, have)
    if amount <= 0 then return notify(src, locale(space <= 0 and 'sv_hopper_full' or 'sv_missing'), 'error') end

    if not exports['rsg-inventory']:RemoveItem(src, ing.item, amount, nil, 'moonshine-load') then return end
    s.hopper[ing.item] = (s.hopper[ing.item] or 0) + amount
    processStill(s, os.time())
    saveStill(s)
    local label = itemInfo(ing.item)
    notify(src, locale('sv_loaded'):format(amount, label), 'success')
    WebhookLog('load', src, locale('wh_load_title'), locale('wh_load_desc'):format(amount, label, s.id),
        { { locale('wh_field_still_id'), s.id }, { locale('wh_field_owner'), s.citizenid }, { locale('wh_field_hopper'), s.hopper[ing.item] or 0 } })
end

Actions.loadFuel = function(src, Player, s, data)
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    local f = Fuels[data.item]
    if not f then return end
    local room = (Config.MaxFuel - s.fuel) // f.burnTime
    local have = exports['rsg-inventory']:GetItemCount(src, f.item) or 0
    local amount = math.min(math.floor(tonumber(data.amount) or 0), room, have)
    if amount <= 0 then return notify(src, locale(room <= 0 and 'sv_fuel_full' or 'sv_missing'), 'error') end
    if not exports['rsg-inventory']:RemoveItem(src, f.item, amount, nil, 'moonshine-fuel') then return end
    s.fuel = s.fuel + amount * f.burnTime
    processStill(s, os.time())
    saveStill(s)
    notify(src, locale('sv_fuel_loaded'):format(amount, (itemInfo(f.item))), 'success')
    WebhookLog('fuel', src, locale('wh_fuel_title'), locale('wh_fuel_desc'):format(amount, (itemInfo(f.item)), s.id),
        { { locale('wh_field_still_id'), s.id }, { locale('wh_field_owner'), s.citizenid }, { locale('wh_field_fuel'), s.fuel } })
end

Actions.unload = function(src, Player, s, data)
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    if type(data.item) ~= 'string' then return end
    local amount = s.hopper[data.item] or 0
    if amount <= 0 then return end
    if not exports['rsg-inventory']:CanAddItem(src, data.item, amount) then return notify(src, locale('sv_no_space'), 'error') end
    s.hopper[data.item] = nil
    saveStill(s)
    exports['rsg-inventory']:AddItem(src, data.item, amount, nil, nil, 'moonshine-unload')
    notify(src, locale('sv_unloaded'):format(amount, (itemInfo(data.item))), 'success')
    WebhookLog('unload', src, locale('wh_unload_title'), locale('wh_unload_desc'):format(amount, (itemInfo(data.item)), s.id),
        { { locale('wh_field_still_id'), s.id }, { locale('wh_field_owner'), s.citizenid } })
end

Actions.collect = function(src, Player, s)
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    local r = s.recipe and Recipes[s.recipe]
    if not r or s.output <= 0 then return notify(src, locale('sv_not_ready'), 'error') end

    -- one empty jug per bottle, collect as many as the player has jugs for
    local jugs = exports['rsg-inventory']:GetItemCount(src, Config.EmptyJug) or 0
    if jugs <= 0 then return notify(src, locale('sv_no_jugs'):format((itemInfo(Config.EmptyJug))), 'error') end
    local amount = math.min(s.output, jugs)
    if not exports['rsg-inventory']:CanAddItem(src, r.output.item, amount) then return notify(src, locale('sv_no_space'), 'error') end
    if not exports['rsg-inventory']:RemoveItem(src, Config.EmptyJug, amount, nil, 'moonshine-bottle') then return end

    if not exports['rsg-inventory']:AddItem(src, r.output.item, amount, nil, nil, 'moonshine-collect') then
        exports['rsg-inventory']:AddItem(src, Config.EmptyJug, amount, nil, nil, 'moonshine-refund')
        return notify(src, locale('sv_no_space'), 'error')
    end
    s.output = s.output - amount
    processStill(s, os.time()) -- tank had room freed, may start the next batch
    saveStill(s)
    notify(src, locale('sv_collected'):format(amount, (itemInfo(r.output.item))), 'success')
    WebhookLog('collect', src, locale('wh_collect_title'), locale('wh_collect_desc'):format(amount, (itemInfo(r.output.item)), s.id),
        { { locale('wh_field_still_id'), s.id }, { locale('wh_field_owner'), s.citizenid }, { locale('wh_field_jugs'), amount }, { locale('wh_field_left'), s.output }, CoordsField(s.coords) })

    -- moonshiner xp
    local before = getLevel(getXp(Player))
    local xp = amount * (r.xpPerBottle or Config.XpPerBottle)
    if xp > 0 then
        Player.Functions.AddRep(Config.XpName, xp)
        local after = getLevel(getXp(Player))
        if after > before then
            notify(src, locale('sv_level_up'):format(after), 'success')
            WebhookLog('levelup', src, locale('wh_levelup_title'), locale('wh_levelup_desc'):format(after),
                { { locale('wh_field_total_xp'), getXp(Player) } })
        else notify(src, locale('sv_xp_gain'):format(xp), 'inform') end
    end
end

Actions.clearRecipe = function(src, Player, s)
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    if not hopperEmpty(s) or s.batch_left or s.output > 0 then return notify(src, locale('sv_empty_first'), 'error') end
    s.recipe = nil
    saveStill(s)
end

Actions.pickup = function(src, Player, s)
    if s.citizenid ~= Player.PlayerData.citizenid then return notify(src, locale('sv_not_owner'), 'error') end
    if not hopperEmpty(s) or s.batch_left or s.output > 0 then return notify(src, locale('sv_empty_first'), 'error') end
    if not exports['rsg-inventory']:CanAddItem(src, Config.StillItem, 1) then return notify(src, locale('sv_no_space'), 'error') end
    Stills[s.id] = nil
    MySQL.query('DELETE FROM rsg_moonshine_stills WHERE id = ?', { s.id })
    TriggerClientEvent('rsg-moonshine:client:removeStill', -1, s.id)
    exports['rsg-inventory']:AddItem(src, Config.StillItem, 1, nil, nil, 'moonshine-pickup')
    notify(src, locale('sv_picked_up'), 'success')
    WebhookLog('pickup', src, locale('wh_pickup_title'), locale('wh_pickup_desc'):format(s.id), { { locale('wh_field_still_id'), s.id }, CoordsField(s.coords) })
    return 'closed'
end

lib.callback.register('rsg-moonshine:server:action', function(src, id, action, data)
    local Player = RSGCore.Functions.GetPlayer(src)
    local s = Stills[id]
    if not Player or not s or type(action) ~= 'string' or not Actions[action] then return nil end
    if not isNear(src, s.coords) then
        notify(src, locale('sv_too_far'), 'error')
        WebhookLog('suspicious', src, locale('wh_range_title'), locale('wh_range_desc'):format(action, s.id), { CoordsField(s.coords) })
        return nil
    end
    if throttled('action', src, 300) then return buildState(src, s) end
    processStill(s, os.time())
    if Actions[action](src, Player, s, type(data) == 'table' and data or {}) == 'closed' then return nil end
    return buildState(src, s)
end)

---------------------------------
-- static world stills (map props) - find or create the saved still for a prop
---------------------------------
local creatingWorld = false
lib.callback.register('rsg-moonshine:server:getWorldStill', function(src, coords)
    if not Config.WorldStills.enabled or type(coords) ~= 'vector3' then return nil end
    if not RSGCore.Functions.GetPlayer(src) or not isNear(src, coords) then return nil end
    for _, s in pairs(Stills) do
        if s.citizenid == WORLD and #(s.coords - coords) < 1.5 then return publicStill(s) end
    end
    if creatingWorld or throttled('world', src, 1000) then return nil end
    creatingWorld = true
    local id = MySQL.insert.await('INSERT INTO rsg_moonshine_stills (citizenid, x, y, z, heading, hopper, output) VALUES (?, ?, ?, ?, ?, ?, 0)',
        { WORLD, coords.x, coords.y, coords.z, 0.0, '{}' })
    creatingWorld = false
    if not id then return nil end
    Stills[id] = { id = id, citizenid = WORLD, coords = coords, heading = 0.0, hopper = {}, output = 0, fuel = 0, last_tick = os.time() }
    TriggerClientEvent('rsg-moonshine:client:syncStill', -1, publicStill(Stills[id]))
    return publicStill(Stills[id])
end)

---------------------------------
-- place
---------------------------------
local placing = {} -- [citizenid] = true while a placement DB insert is in flight

RegisterNetEvent('rsg-moonshine:server:placeStill', function(coords, heading)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(coords) ~= 'vector3' or type(heading) ~= 'number' or heading ~= heading then return end
    heading = heading % 360.0
    local cid = Player.PlayerData.citizenid
    if placing[cid] then return end

    if not isNear(src, coords, Config.PlaceDist) then
        WebhookLog('suspicious', src, locale('wh_remote_title'), locale('wh_remote_desc'), { CoordsField(coords) })
        return notify(src, locale('sv_too_far'), 'error')
    end
    if countOwned(cid) >= Config.MaxStills then return notify(src, locale('sv_max'), 'error') end
    for _, z in ipairs(Config.BlockedZones) do
        if #(coords - z.coords) < z.radius then return notify(src, locale('sv_blocked'):format(z.name), 'error') end
    end
    for _, s in pairs(Stills) do
        if #(coords - s.coords) < Config.MinStillDist then return notify(src, locale('sv_too_close'), 'error') end
    end
    if not exports['rsg-inventory']:RemoveItem(src, Config.StillItem, 1, nil, 'moonshine-place') then return end

    placing[cid] = true
    local id = MySQL.insert.await('INSERT INTO rsg_moonshine_stills (citizenid, x, y, z, heading, hopper, output) VALUES (?, ?, ?, ?, ?, ?, 0)',
        { cid, coords.x, coords.y, coords.z, heading, '{}' })
    placing[cid] = nil
    if not id then
        exports['rsg-inventory']:AddItem(src, Config.StillItem, 1, nil, nil, 'moonshine-place-failed')
        return
    end
    Stills[id] = { id = id, citizenid = cid, coords = coords, heading = heading, hopper = {}, output = 0, fuel = 0, last_tick = os.time() }
    TriggerClientEvent('rsg-moonshine:client:syncStill', -1, publicStill(Stills[id]))
    notify(src, locale('sv_placed'), 'success')
    WebhookLog('place', src, locale('wh_place_title'), locale('wh_place_desc'):format(id), { { locale('wh_field_still_id'), id }, { locale('wh_field_heading'), ('%.1f'):format(heading) }, CoordsField(coords) })
end)

---------------------------------
-- law destroy
---------------------------------
RegisterNetEvent('rsg-moonshine:server:destroy', function(id)
    local src = source
    if type(id) ~= 'number' then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    local still = Stills[id]
    if not Player or not still or still.citizenid == WORLD then return end
    if not isNear(src, still.coords) then return notify(src, locale('sv_too_far'), 'error') end
    -- a raid takes Config.DestroyTime on the client; refuse faster repeats (skipped progress bar)
    if throttled('destroy', src, Config.DestroyTime) then return end
    if not isLaw(Player) then
        WebhookLog('suspicious', src, locale('wh_nonlaw_title'), locale('wh_nonlaw_desc'):format(id), { { locale('wh_field_owner'), still.citizenid }, CoordsField(still.coords) })
        return notify(src, locale('sv_not_law'), 'error')
    end

    Stills[id] = nil
    MySQL.query('DELETE FROM rsg_moonshine_stills WHERE id = ?', { id })
    TriggerClientEvent('rsg-moonshine:client:removeStill', -1, id)
    local reward = (still.citizenid ~= Player.PlayerData.citizenid) and Config.DestroyReward or 0
    if reward > 0 then
        Player.Functions.AddMoney('cash', reward, 'moonshine-raid')
        notify(src, locale('sv_destroyed'):format(reward), 'success')
    else
        notify(src, locale('sv_destroyed_own'), 'inform')
    end
    WebhookLog('destroy', src, locale('wh_destroy_title'), locale('wh_destroy_desc'):format(id, still.citizenid),
        { { locale('wh_field_still_id'), id }, { locale('wh_field_owner'), still.citizenid }, { locale('wh_field_reward'), '$' .. reward }, { locale('wh_field_recipe'), still.recipe and Recipes[still.recipe] and recipeLabel(Recipes[still.recipe]) or locale('wh_none') },
          { locale('wh_field_lost'), still.output }, CoordsField(still.coords) })
end)
