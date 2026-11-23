local RSGCore = exports['rsg-core']:GetCoreObject()

-- server-side action state: [src] = { type, slot?, coords?, target?, fromWater?, started }
local pending = {}
local pumps = {} -- registered map pumps: [id] = { coords = vector3, model = string }
local MAX_PUMP_DIST = Config.TargetDistance + 1.5
local TIME_GRACE = 500 -- ms allowed under the progress duration
local PENDING_TIMEOUT = 15000 -- ms after the duration before a pending action is dropped

-- the fee only works when pumps are verified, otherwise the server cannot trust where the player is filling
local FEE_ACTIVE = Config.PumpFee.Enabled and Config.PumpVerify.Enabled

local function durationOf(actionType)
    if actionType == 'drink' then return Config.DrinkTime end
    if actionType == 'purify' then return Config.Purify.Time end
    if actionType == 'share' then return Config.Share.Time end
    return Config.FillTime
end

---------------------------------
-- helpers
---------------------------------
local function notify(src, msg, typ)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('notify_title'), description = msg, type = typ or 'inform' })
end

local function getUses(item)
    return item and item.info and tonumber(item.info.uses) or 0
end

local function isDirty(item)
    return item and item.info and item.info.dirty == true
end

local function isCanteen(item)
    return item and Config.Canteens[item.name] ~= nil
end

-- writes a fresh info table (never shares a reference with the inventory). `changes.dirty = false` clears the flag.
-- info.quality mirrors the water level so the inventory shows it as a bar.
local function updateCanteen(src, item, changes)
    local cfg = Config.Canteens[item.name]
    if not cfg then return false end
    local info = {}
    for k, v in pairs(item.info or {}) do info[k] = v end
    for k, v in pairs(changes) do info[k] = v end
    if info.dirty == false then info.dirty = nil end
    info.quality = math.floor((tonumber(info.uses) or 0) / cfg.maxUses * 100 + 0.5)
    return exports['rsg-inventory']:SetItemInfo(src, item.slot, info)
end

-- canteen with the lowest fill level (so filling tops up the emptiest one first),
-- plus whether the player carries any canteen at all
local function findFillable(Player)
    local best, bestRatio, carrying
    for _, item in pairs(Player.PlayerData.items) do
        if isCanteen(item) then
            carrying = true
            local max = Config.Canteens[item.name].maxUses
            local ratio = getUses(item) / max
            if getUses(item) < max and (not best or ratio < bestRatio) then
                best, bestRatio = item, ratio
            end
        end
    end
    return best, carrying
end

-- canteen to drink from: clean water first, then the fullest one
local function findDrinkable(Player)
    local best
    for _, item in pairs(Player.PlayerData.items) do
        if isCanteen(item) and getUses(item) > 0 then
            if not best
                or (isDirty(best) and not isDirty(item))
                or (isDirty(best) == isDirty(item) and getUses(item) > getUses(best)) then
                best = item
            end
        end
    end
    return best
end

local function playerCoords(src)
    return GetEntityCoords(GetPlayerPed(src))
end

local function charName(Player)
    local ci = Player.PlayerData.charinfo or {}
    return ('%s %s'):format(ci.firstname or '', ci.lastname or '')
end

-- rsg-hud owns the live thirst value (server-authoritative), so read it from the state bag
local function getThirst(src)
    return tonumber(Player(src).state.thirst)
end

-- trusted server write through rsg-hud (a client-side write is capped per minute and can be reverted)
local function addThirst(src, amount)
    local value = math.max(0, math.min(Config.MaxThirst, (getThirst(src) or 0) + amount))
    if GetResourceState('rsg-hud') == 'started' then
        exports['rsg-hud']:SetNeed(src, 'thirst', value)
    else
        TriggerClientEvent('hud:client:UpdateThirst', src, value)
    end
end

local function weatherFactor()
    local cfg = Config.WeatherThirst
    if not cfg.Enabled then return 1.0 end
    local w = GlobalState.rsgWeather
    return w and cfg.Multipliers[w.weather] or 1.0
end

-- thirst + side effects of one drink for `target` (weather, dirty water)
local function applyDrink(target, canteenCfg, dirty)
    local dirtyActive = dirty and Config.DirtyWater.Enabled
    local factor = weatherFactor()
    local amount = canteenCfg.thirst * factor
    if dirtyActive then amount = amount * Config.DirtyWater.ThirstFactor end
    addThirst(target, math.floor(amount + 0.5))

    if factor < 1.0 then notify(target, locale('hot_drink')) end
    if dirtyActive and math.random() < Config.DirtyWater.SickChance then
        TriggerClientEvent('rsg-canteen:client:sick', target, Config.DirtyWater.Damage, Config.DirtyWater.MinHealth)
        notify(target, locale('sick'), 'error')
    end
end

-- a pending action whose finish event never arrived (crash, resource restart) must not lock the player out
local function isPending(src)
    local action = pending[src]
    if not action then return false end
    if GetGameTimer() - action.started > durationOf(action.type) + PENDING_TIMEOUT then
        pending[src] = nil
        return false
    end
    return true
end

local function takePending(src, actionType)
    local action = pending[src]
    pending[src] = nil
    if not action or action.type ~= actionType then return nil end
    if GetGameTimer() - action.started < durationOf(actionType) - TIME_GRACE then return nil end
    return action
end

---------------------------------
-- registered pumps (optional verification)
---------------------------------
local function ensureDatabase()
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `rsg_canteen_pumps` (
                `id` INT(11) NOT NULL AUTO_INCREMENT,
                `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
                `model` VARCHAR(64) NOT NULL DEFAULT '',
                `added_by` VARCHAR(50) NOT NULL DEFAULT '',
                `added_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
    end)
    if not ok then
        print(('^1[rsg-canteen] database setup failed: %s^7'):format(tostring(err)))
        return false
    end
    print('^2[rsg-canteen] database tables ready^7')
    return true
end

local function loadPumps()
    local rows = MySQL.query.await('SELECT id, x, y, z, model FROM rsg_canteen_pumps') or {}
    pumps = {}
    for _, r in ipairs(rows) do
        pumps[r.id] = { coords = vector3(r.x, r.y, r.z), model = r.model }
    end
end

-- is `coords` at a registered map pump or a player-placed rsg-wellpump pump?
local function atKnownPump(coords)
    local radius = Config.PumpVerify.Radius
    for _, p in pairs(pumps) do
        if #(coords - p.coords) <= radius then return true end
    end
    if Config.PumpVerify.UseWellpump and GetResourceState('rsg-wellpump') == 'started' then
        local ok, list = pcall(function() return exports['rsg-wellpump']:GetPumps() end)
        if ok and type(list) == 'table' then
            for _, p in ipairs(list) do
                if #(coords - vector3(p.x, p.y, p.z)) <= radius then return true end
            end
        end
    end
    return false
end

local function isPumpAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.PumpVerify.Permission)
end

RSGCore.Commands.Add('canteenaddpump', 'Register the pump you are standing next to for canteen verification', {}, false, function(source)
    TriggerClientEvent('rsg-canteen:client:addPump', source)
end, Config.PumpVerify.Permission)

RSGCore.Commands.Add('canteenremovepump', 'Remove the nearest registered canteen pump', {}, false, function(source)
    local src = source
    local here = playerCoords(src)
    local nearestId, nearestDist
    for id, p in pairs(pumps) do
        local d = #(here - p.coords)
        if d <= 5.0 and (not nearestDist or d < nearestDist) then nearestId, nearestDist = id, d end
    end
    if not nearestId then return notify(src, locale('pump_none_near'), 'error') end
    MySQL.query.await('DELETE FROM rsg_canteen_pumps WHERE id = ?', { nearestId })
    pumps[nearestId] = nil
    notify(src, locale('pump_removed', nearestId), 'success')
end, Config.PumpVerify.Permission)

RegisterNetEvent('rsg-canteen:server:addPump', function(coords, model)
    local src = source
    if not isPumpAdmin(src) then return end
    if type(coords) ~= 'vector3' or type(model) ~= 'string' or #model > 64 then return end
    if #(playerCoords(src) - coords) > 6.0 then return end
    local known = false
    for _, m in ipairs(Config.PumpModels) do
        if m == model then known = true break end
    end
    if not known then return end
    for _, p in pairs(pumps) do
        if #(coords - p.coords) <= 1.0 then return notify(src, locale('pump_exists'), 'error') end
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    local id = MySQL.insert.await('INSERT INTO rsg_canteen_pumps (x, y, z, model, added_by) VALUES (?, ?, ?, ?, ?)', {
        coords.x, coords.y, coords.z, model, Player and Player.PlayerData.citizenid or '',
    })
    if not id then return end
    pumps[id] = { coords = coords, model = model }
    notify(src, locale('pump_added', id), 'success')
end)

---------------------------------
-- drink
---------------------------------
local function onUse(source, item)
    local src = source
    if not isCanteen(item) then return end
    if isPending(src) then
        return notify(src, locale('busy'), 'error')
    end
    if getUses(item) <= 0 then
        return notify(src, locale('canteen_empty'), 'error')
    end
    -- don't waste a use when thirst is already full
    local thirst = getThirst(src)
    if thirst and thirst >= Config.MaxThirst then
        return notify(src, locale('not_thirsty'))
    end
    if isDirty(item) and Config.DirtyWater.Enabled then
        notify(src, locale('dirty_water'), 'warning')
    end
    pending[src] = { type = 'drink', slot = item.slot, started = GetGameTimer() }
    TriggerClientEvent('rsg-canteen:client:drink', src)
end

for name in pairs(Config.Canteens) do
    if RSGCore.Shared.Items[name] then
        RSGCore.Functions.CreateUseableItem(name, onUse)
    else
        print(('^3[rsg-canteen] item "%s" is not in rsg-core shared items, skipping^7'):format(name))
    end
end

RegisterNetEvent('rsg-canteen:server:finishDrink', function(completed)
    local src = source
    local action = takePending(src, 'drink')
    if not completed or not action then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local item = Player.PlayerData.items[action.slot]
    if not isCanteen(item) then return end
    local uses = getUses(item)
    if uses <= 0 then
        return notify(src, locale('canteen_empty'), 'error')
    end

    uses = uses - 1
    if not updateCanteen(src, item, { uses = uses }) then return end

    applyDrink(src, Config.Canteens[item.name], isDirty(item))
    notify(src, locale('drank', uses, Config.Canteens[item.name].maxUses), 'success')
end)

---------------------------------
-- fill
---------------------------------
-- NOTE: pumpCoords / fromWater come from the client. The server cannot see map props or water, so without
-- Config.PumpVerify it only checks that the player is next to the position they claim (see DOCS.md, Security).
RSGCore.Functions.CreateCallback('rsg-canteen:server:startFill', function(source, cb, pumpCoords, fromWater)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or isPending(src) or type(pumpCoords) ~= 'vector3' then return cb(false) end
    fromWater = fromWater == true
    if fromWater and not Config.WaterFill.Enabled then return cb(false) end

    if #(playerCoords(src) - pumpCoords) > MAX_PUMP_DIST then
        notify(src, locale('too_far'), 'error')
        return cb(false)
    end
    if not fromWater and Config.PumpVerify.Enabled and not atKnownPump(pumpCoords) then
        notify(src, locale('pump_unavailable'), 'error')
        return cb(false)
    end

    local fillable, carrying = findFillable(Player)
    if not carrying then
        notify(src, locale('no_canteen'), 'error')
        return cb(false)
    end
    if not fillable then
        notify(src, locale('canteens_full'), 'error')
        return cb(false)
    end
    if FEE_ACTIVE and not fromWater and Player.Functions.GetMoney(Config.PumpFee.Account) < Config.PumpFee.Price then
        notify(src, locale('not_enough_money', ('%.2f'):format(Config.PumpFee.Price)), 'error')
        return cb(false)
    end

    pending[src] = { type = 'fill', coords = pumpCoords, fromWater = fromWater, started = GetGameTimer() }
    cb(true)
end)

RegisterNetEvent('rsg-canteen:server:finishFill', function(completed)
    local src = source
    local action = takePending(src, 'fill')
    if not completed or not action then return end

    if #(playerCoords(src) - action.coords) > MAX_PUMP_DIST then
        return notify(src, locale('too_far'), 'error')
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local item = findFillable(Player)
    if not item then
        return notify(src, locale('canteens_full'), 'error')
    end

    local charged = FEE_ACTIVE and not action.fromWater
    if charged and not Player.Functions.RemoveMoney(Config.PumpFee.Account, Config.PumpFee.Price, 'canteen-fill') then
        return notify(src, locale('not_enough_money', ('%.2f'):format(Config.PumpFee.Price)), 'error')
    end

    local maxUses = Config.Canteens[item.name].maxUses
    local dirty = action.fromWater and Config.DirtyWater.Enabled
    if not updateCanteen(src, item, { uses = maxUses, dirty = dirty and true or false }) then return end

    if dirty then
        notify(src, locale('canteen_filled_dirty', maxUses), 'warning')
    elseif charged then
        notify(src, locale('canteen_filled_fee', maxUses, ('%.2f'):format(Config.PumpFee.Price)), 'success')
    else
        notify(src, locale('canteen_filled', maxUses), 'success')
    end
end)

---------------------------------
-- purify (boil dirty water over a fire)
---------------------------------
RSGCore.Functions.CreateCallback('rsg-canteen:server:startPurify', function(source, cb, fireCoords)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or isPending(src) or type(fireCoords) ~= 'vector3' then return cb(false) end
    if not (Config.Purify.Enabled and Config.DirtyWater.Enabled) then return cb(false) end

    if #(playerCoords(src) - fireCoords) > MAX_PUMP_DIST then
        notify(src, locale('fire_too_far'), 'error')
        return cb(false)
    end
    local anyDirty = false
    for _, item in pairs(Player.PlayerData.items) do
        if isCanteen(item) and isDirty(item) then anyDirty = true break end
    end
    if not anyDirty then
        notify(src, locale('no_dirty'), 'error')
        return cb(false)
    end

    pending[src] = { type = 'purify', coords = fireCoords, started = GetGameTimer() }
    cb(true)
end)

RegisterNetEvent('rsg-canteen:server:finishPurify', function(completed)
    local src = source
    local action = takePending(src, 'purify')
    if not completed or not action then return end

    if #(playerCoords(src) - action.coords) > MAX_PUMP_DIST then
        return notify(src, locale('fire_too_far'), 'error')
    end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- snapshot first: updating an item rewrites the inventory while we iterate
    local dirty = {}
    for _, item in pairs(Player.PlayerData.items) do
        if isCanteen(item) and isDirty(item) then dirty[#dirty + 1] = item end
    end
    if #dirty == 0 then return notify(src, locale('no_dirty'), 'error') end
    for _, item in ipairs(dirty) do updateCanteen(src, item, { dirty = false }) end
    notify(src, locale('purified'), 'success')
end)

---------------------------------
-- give another player a drink
---------------------------------
local function shareTargetOk(src, target)
    if target == src or not RSGCore.Functions.GetPlayer(target) then return false end
    return #(playerCoords(src) - playerCoords(target)) <= Config.Share.Distance + 1.0
end

RSGCore.Functions.CreateCallback('rsg-canteen:server:startShare', function(source, cb, targetId)
    local src = source
    targetId = math.tointeger(tonumber(targetId))
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not targetId or isPending(src) or not Config.Share.Enabled then return cb(false) end

    if not shareTargetOk(src, targetId) then
        notify(src, locale('target_too_far'), 'error')
        return cb(false)
    end
    if not findDrinkable(Player) then
        notify(src, locale('canteen_empty'), 'error')
        return cb(false)
    end
    local thirst = getThirst(targetId)
    if thirst and thirst >= Config.MaxThirst then
        notify(src, locale('share_full'))
        return cb(false)
    end

    pending[src] = { type = 'share', target = targetId, started = GetGameTimer() }
    cb(true)
end)

RegisterNetEvent('rsg-canteen:server:finishShare', function(completed)
    local src = source
    local action = takePending(src, 'share')
    if not completed or not action then return end

    local target = action.target
    if not shareTargetOk(src, target) then
        return notify(src, locale('target_too_far'), 'error')
    end
    local Player = RSGCore.Functions.GetPlayer(src)
    local TargetPlayer = RSGCore.Functions.GetPlayer(target)
    if not Player or not TargetPlayer then return end

    local thirst = getThirst(target)
    if thirst and thirst >= Config.MaxThirst then
        return notify(src, locale('share_full'))
    end
    local item = findDrinkable(Player)
    if not item then
        return notify(src, locale('canteen_empty'), 'error')
    end

    local uses = getUses(item) - 1
    if not updateCanteen(src, item, { uses = uses }) then return end

    applyDrink(target, Config.Canteens[item.name], isDirty(item))
    notify(src, locale('share_given', charName(TargetPlayer), uses), 'success')
    notify(target, locale('share_received', charName(Player)), 'success')
end)

---------------------------------
-- exports
---------------------------------
-- ConsumeUse(src) -> boolean: takes one use from the player's best canteen (used by rsg-stables to water a horse)
exports('ConsumeUse', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local item = findDrinkable(Player)
    if not item then return false end
    return updateCanteen(src, item, { uses = getUses(item) - 1 }) == true
end)

---------------------------------
-- startup + cleanup
---------------------------------
CreateThread(function()
    if Config.PumpFee.Enabled and not Config.PumpVerify.Enabled then
        print('^3[rsg-canteen] Config.PumpFee needs Config.PumpVerify.Enabled = true, the fee is disabled^7')
    end
    if Config.AutoDatabase and not ensureDatabase() then return end
    loadPumps()
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)
