-- rsg-stables: horse training (ride XP + paid stable sessions)
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local T = Config.Training
if not (T and T.enabled) then return end

-- ===================== DATABASE =====================
MySQL.ready(function()
    local has = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rsg_stables_horses' AND COLUMN_NAME = 'training'
    ]])
    if (tonumber(has) or 0) == 0 then
        local ok, err = pcall(MySQL.query.await, 'ALTER TABLE `rsg_stables_horses` ADD COLUMN `training` TEXT DEFAULT NULL AFTER `bonding`')
        if not ok then print(('^1[rsg-stables] Failed to add column training: %s^7'):format(tostring(err))) end
    end
end)

-- ===================== HELPERS =====================
local MAX_LEVEL = #T.levelXp

local function levelFor(xp)
    local lvl = 0
    for i, need in ipairs(T.levelXp) do
        if xp >= need then lvl = i else break end
    end
    return lvl
end

local function decode(raw)
    local data = {}
    if type(raw) == 'string' and raw ~= '' then
        local ok, parsed = pcall(json.decode, raw)
        if ok and type(parsed) == 'table' then data = parsed end
    end
    data.stats = type(data.stats) == 'table' and data.stats or {}
    for _, key in ipairs(T.statOrder) do
        data.stats[key] = math.max(0, tonumber(data.stats[key]) or 0)
    end
    data.lastSession = tonumber(data.lastSession) or 0
    return data
end

-- what the client needs: xp + level per stat
local function summary(data)
    local out = { stats = {}, maxLevel = MAX_LEVEL, lastSession = data.lastSession }
    for _, key in ipairs(T.statOrder) do
        local xp = data.stats[key]
        local lvl = levelFor(xp)
        out.stats[key] = {
            xp = math.floor(xp),
            level = lvl,
            prevXp = T.levelXp[lvl] or 0,
            nextXp = T.levelXp[lvl + 1],
        }
    end
    return out
end

local function getActiveHorse(citizenid)
    return MySQL.single.await('SELECT id, name, training FROM rsg_stables_horses WHERE citizenid = ? AND active = 1 AND alive = 1 LIMIT 1', { citizenid })
end

-- adds xp per stat, saves, returns the level-ups
local function addXp(horse, data, gains)
    local ups = {}
    for key, amount in pairs(gains) do
        if T.stats[key] and amount > 0 then
            local before = levelFor(data.stats[key])
            data.stats[key] = math.min(T.levelXp[MAX_LEVEL], data.stats[key] + amount)
            local after = levelFor(data.stats[key])
            if after > before then ups[#ups + 1] = { stat = key, level = after } end
        end
    end
    MySQL.update.await('UPDATE rsg_stables_horses SET training = ? WHERE id = ?', { json.encode(data), horse.id })
    return ups
end

local function notifyLevelUps(src, horseName, ups)
    for _, u in ipairs(ups) do
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('training_title'),
            description = locale('training_level_up', horseName, locale('training_' .. u.stat), u.level),
            type = 'success', duration = 7000,
        })
    end
end

local function nearAnyStable(src, maxDist)
    local coords = GetEntityCoords(GetPlayerPed(src))
    for _, stable in ipairs(Config.Stables) do
        for _, p in ipairs({ stable.pedCoords, stable.storeCoords, stable.previewCoords }) do
            if p and #(coords - vector3(p.x, p.y, p.z)) <= maxDist then return true end
        end
    end
    return false
end

local function chargePlayer(Player, amount)
    if amount <= 0 then return true end
    local account = Config.PaymentAccount
    if (Player.PlayerData.money[account] or 0) < amount then return false end
    return Player.Functions.RemoveMoney(account, amount, 'rsg-stables-training') ~= false
end

-- ===================== CALLBACKS =====================
lib.callback.register('rsg-stables:server:getTraining', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return nil end
    local horse = getActiveHorse(Player.PlayerData.citizenid)
    if not horse then return nil end
    local s = summary(decode(horse.training))
    s.horseId = horse.id
    s.name = horse.name
    s.prices = T.session.price
    s.cooldownLeft = math.max(0, (s.lastSession + T.session.cooldown) - os.time())
    return s
end)

local pending = {} -- [src] = { token, stat, horseId, startedAt, rounds }

lib.callback.register('rsg-stables:server:startTraining', function(source, stat, horseNetId)
    local src = source
    if not T.session.enabled then return false, locale('training_disabled') end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false, locale('player_not_found') end
    if type(stat) ~= 'string' or not T.stats[stat] then return false, locale('training_invalid_stat') end
    if pending[src] then return false, locale('training_in_progress') end

    local horse = getActiveHorse(Player.PlayerData.citizenid)
    if not horse then return false, locale('no_active_horse') end
    if not nearAnyStable(src, T.session.stableDistance) then return false, locale('training_not_at_stable') end

    local ent = NetworkGetEntityFromNetworkId(tonumber(horseNetId) or 0)
    if not ent or ent == 0 or not DoesEntityExist(ent)
        or #(GetEntityCoords(ent) - GetEntityCoords(GetPlayerPed(src))) > T.session.horseDistance then
        return false, locale('training_too_far')
    end

    local data = decode(horse.training)
    if os.time() < data.lastSession + T.session.cooldown then
        return false, locale('training_cooldown', math.ceil(((data.lastSession + T.session.cooldown) - os.time()) / 60))
    end
    if levelFor(data.stats[stat]) >= MAX_LEVEL then return false, locale('training_max_level') end

    local price = math.max(0, math.floor(tonumber(T.session.price[stat]) or 0))
    if not chargePlayer(Player, price) then return false, locale('training_no_money') end

    -- cooldown starts on payment so cancelling can't be used to skip it
    data.lastSession = os.time()
    MySQL.update.await('UPDATE rsg_stables_horses SET training = ? WHERE id = ?', { json.encode(data), horse.id })

    local token = ('%d-%d-%d'):format(src, GetGameTimer(), math.random(100000, 999999))
    pending[src] = { token = token, stat = stat, horseId = horse.id, startedAt = GetGameTimer(), rounds = T.session.rounds }
    return true, { token = token, rounds = T.session.rounds, roundMs = T.session.roundMs }
end)

lib.callback.register('rsg-stables:server:finishTraining', function(source, token, hits)
    local src = source
    local p = pending[src]
    if not p or p.token ~= token then return false, locale('training_expired') end
    pending[src] = nil

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local horse = getActiveHorse(Player.PlayerData.citizenid)
    if not horse or horse.id ~= p.horseId then return false, locale('no_active_horse') end

    hits = math.floor(tonumber(hits) or 0)
    hits = math.max(0, math.min(p.rounds, hits))
    -- each round lasts a full sweep in the NUI; a faster finish means a tampered client
    if GetGameTimer() - p.startedAt < p.rounds * T.session.roundMs * 0.9 then hits = 0 end

    local gain = T.session.baseXp + hits * T.session.xpPerHit
    local data = decode(horse.training)
    local ups = addXp(horse, data, { [p.stat] = gain })
    notifyLevelUps(src, horse.name, ups)
    return true, { gain = gain, stat = p.stat, hits = hits, training = summary(data) }
end)

-- ===================== RIDE XP =====================
local rideState = {} -- [src] = { coords, at }

RegisterNetEvent('rsg-stables:server:trainingRideTick', function()
    local src = source
    local R = T.riding
    if not R.enabled then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = os.time()
    local coords = GetEntityCoords(GetPlayerPed(src))
    local st = rideState[src]
    if not st then rideState[src] = { coords = coords, at = now } return end

    local elapsed = now - st.at
    if elapsed < R.interval * 0.8 then return end -- too frequent, ignore (keep old anchor)
    local dist = #(coords - st.coords)
    rideState[src] = { coords = coords, at = now }
    if dist > R.maxSpeed * elapsed then return end -- teleport / fast travel

    local xp = math.min(R.maxXpPerTick, dist / R.metersPerXp)
    if xp < 0.1 then return end

    local horse = getActiveHorse(Player.PlayerData.citizenid)
    if not horse then return end
    local gains = {}
    for key, share in pairs(R.split) do gains[key] = math.floor(xp * share * 10) / 10 end
    local data = decode(horse.training)
    local ups = addXp(horse, data, gains)
    if #ups > 0 then
        notifyLevelUps(src, horse.name, ups)
        TriggerClientEvent('rsg-stables:client:trainingUpdate', src, horse.id, summary(data))
    end
    if T.debug then print(('[rsg-stables] ride tick %s: %.0fm -> %.1f xp'):format(src, dist, xp)) end
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
    rideState[source] = nil
end)
