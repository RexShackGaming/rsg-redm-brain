local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()
math.randomseed(os.time()) -- foal stat variance (collectFoal's inherit()) shouldn't repeat the same sequence every server restart

-- ===================== AUTO DATABASE INSTALL =====================
-- Creates every table in one go on start (same schema as installation/install.sql,
-- which is kept for manual installs).

local SCHEMA = {
    [[
CREATE TABLE IF NOT EXISTS `rsg_stables_horses` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `stable` VARCHAR(50) DEFAULT NULL,
  `model` VARCHAR(100) NOT NULL,
  `breed_label` VARCHAR(100) NOT NULL,
  `gender` VARCHAR(6) DEFAULT NULL,
  `breed_cooldown` BIGINT(20) NOT NULL DEFAULT 0,
  `died_of_age` TINYINT(1) NOT NULL DEFAULT 0,
  `name` VARCHAR(50) NOT NULL DEFAULT 'Unnamed Horse',
  `outfit` INT(11) NOT NULL DEFAULT 0,
  `tack` TEXT DEFAULT NULL,
  `coat` TEXT DEFAULT NULL,
  `health` FLOAT NOT NULL DEFAULT 100,
  `stamina` FLOAT NOT NULL DEFAULT 100,
  `hunger` FLOAT NOT NULL DEFAULT 100,
  `thirst` FLOAT NOT NULL DEFAULT 100,
  `bonding` FLOAT NOT NULL DEFAULT 0,
  `speed` INT(11) NOT NULL DEFAULT 50,
  `accel` INT(11) NOT NULL DEFAULT 50,
  `handling` INT(11) NOT NULL DEFAULT 50,
  `maxhealth` INT(11) NOT NULL DEFAULT 50,
  `alive` TINYINT(1) NOT NULL DEFAULT 1,
  `insured` TINYINT(1) NOT NULL DEFAULT 0,
  `active` TINYINT(1) NOT NULL DEFAULT 0,
  `pos_x` FLOAT DEFAULT NULL,
  `pos_y` FLOAT DEFAULT NULL,
  `pos_z` FLOAT DEFAULT NULL,
  `pos_h` FLOAT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `stable` (`stable`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
CREATE TABLE IF NOT EXISTS `rsg_stables_breeding` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `stable` VARCHAR(50) NOT NULL,
  `parent_a` INT(11) NOT NULL,
  `parent_b` INT(11) NOT NULL,
  `ready_at` BIGINT(20) NOT NULL,
  `collected` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `stable` (`stable`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
}

-- columns added after the first release; ensures older databases get them too
local MIGRATION_COLUMNS = { 'pos_x', 'pos_y', 'pos_z', 'pos_h' }

local function ensureDatabase()
    local ok, err = pcall(MySQL.transaction.await, SCHEMA)
    if not ok or err == false then
        print(('^1[rsg-stables] Failed to create database tables: %s - import installation/install.sql manually.^7'):format(tostring(err)))
        return
    end

    local existing = {}
    local rows = MySQL.query.await([[
        SELECT COLUMN_NAME AS col FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rsg_stables_horses'
    ]]) or {}
    for _, r in ipairs(rows) do existing[r.col] = true end

    for _, col in ipairs(MIGRATION_COLUMNS) do
        if not existing[col] then
            local okCol, errCol = pcall(MySQL.query.await, ('ALTER TABLE `rsg_stables_horses` ADD COLUMN `%s` FLOAT DEFAULT NULL'):format(col))
            if not okCol then
                print(('^1[rsg-stables] Failed to add column %s: %s^7'):format(col, tostring(errCol)))
            end
        end
    end

    if not existing.coat then
        local okCoat, errCoat = pcall(MySQL.query.await, 'ALTER TABLE `rsg_stables_horses` ADD COLUMN `coat` TEXT DEFAULT NULL AFTER `tack`')
        if not okCoat then
            print(('^1[rsg-stables] Failed to add column coat: %s^7'):format(tostring(errCoat)))
        end
    end

    if not existing.gender then
        pcall(MySQL.query.await, 'ALTER TABLE `rsg_stables_horses` ADD COLUMN `gender` VARCHAR(6) DEFAULT NULL AFTER `breed_label`')
    end
    if not existing.breed_cooldown then
        pcall(MySQL.query.await, 'ALTER TABLE `rsg_stables_horses` ADD COLUMN `breed_cooldown` BIGINT(20) NOT NULL DEFAULT 0 AFTER `gender`')
    end
    if not existing.died_of_age then
        pcall(MySQL.query.await, 'ALTER TABLE `rsg_stables_horses` ADD COLUMN `died_of_age` TINYINT(1) NOT NULL DEFAULT 0 AFTER `breed_cooldown`')
    end
    -- horses bought before genders existed get a random one
    pcall(MySQL.query.await, "UPDATE `rsg_stables_horses` SET `gender` = IF(RAND() < 0.5, 'male', 'female') WHERE `gender` IS NULL")

    print('^2[rsg-stables] Database ready.^7')
end

MySQL.ready(ensureDatabase)


-- ===================== HELPERS =====================

local function getStableConfig(stableName)
    for _, s in ipairs(Config.Stables) do
        if s.name == stableName then return s end
    end
    return nil
end

-- breed handling class -> stored 0..100 handling value (unknown classes fall back to 50)
local HandlingMap = {
    Heavy = 35,
    Standard = 50,
    Race = 65,
    Elite = 80,
}

local function breedHandlingValue(breed)
    return HandlingMap[breed.handling] or tonumber(breed.handling) or 50
end

-- Server-side proximity check so stable actions can't be fired remotely by a modified client
local STABLE_INTERACT_DISTANCE = 15.0

local function isNearStable(src, stable, maxDist)
    if not stable then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    maxDist = maxDist or STABLE_INTERACT_DISTANCE
    for _, point in ipairs({ stable.pedCoords, stable.storeCoords, stable.previewCoords }) do
        if point and #(coords - vector3(point.x, point.y, point.z)) <= maxDist then
            return true
        end
    end
    return false
end

local function nearStableByName(src, stableName)
    return isNearStable(src, getStableConfig(stableName))
end

local function nearAnyStable(src, maxDist)
    for _, stable in ipairs(Config.Stables) do
        if isNearStable(src, stable, maxDist) then return true end
    end
    return false
end

local function toId(v)
    v = tonumber(v)
    if not v or v < 1 or v ~= math.floor(v) then return nil end
    return v
end

local function randomGender()
    return math.random(1, 2) == 1 and 'male' or 'female'
end

-- true while the horse is a parent in a breeding whose foal hasn't been collected
local function isHorseBreeding(horseId)
    if not (Config.Breeding.enabled and Config.Breeding.lockParents) then return false end
    return MySQL.single.await('SELECT id FROM rsg_stables_breeding WHERE (parent_a = ? OR parent_b = ?) AND collected = 0', { horseId, horseId }) ~= nil
end

-- 'young' | 'adult' | 'old' from days owned (nil when aging is disabled)
local function horseStage(ageDays)
    local cfg = Config.HorseAging
    if not (cfg and cfg.enabled) then return nil end
    ageDays = tonumber(ageDays) or 0
    if ageDays < (cfg.youngUntilDays or 7) then return 'young' end
    if ageDays >= (cfg.oldFromDays or 60) then return 'old' end
    return 'adult'
end

local AGE_SQL = 'DATEDIFF(NOW(), created_at) AS age_days'

local function getBreedConfig(model)
    for _, b in ipairs(Config.Breeds) do
        if tostring(b.model) == tostring(model) then return b end
    end
    return nil
end

local function chargePlayer(Player, amount)
    local account = Config.PaymentAccount
    local funds = Player.PlayerData.money[account] or 0
    if funds < amount then return false end
    local removed = Player.Functions.RemoveMoney(account, amount, 'rsg-stables')
    if removed == false then return false end
    return true
end

local locks = {}
local function withLock(key, fn)
    while locks[key] do Wait(25) end
    locks[key] = true
    local ok, r1, r2 = pcall(fn)
    locks[key] = nil
    if not ok then
        print(('[rsg-stables] ERROR in locked section (%s): %s'):format(key, tostring(r1)))
        return false, locale('generic_error')
    end
    return r1, r2
end

local function countOwnedHorses(citizenid)
    local result = MySQL.prepare.await('SELECT COUNT(*) FROM rsg_stables_horses WHERE citizenid = ?', { citizenid })
    return result or 0
end

local function isTrue(v)
    return v == true or v == 1
end

local tackItemIndex = {}
for categoryKey, items in pairs(Config.TackItems) do
    tackItemIndex[categoryKey] = {}
    for _, item in ipairs(items) do
        tackItemIndex[categoryKey][tostring(item.hash)] = item
    end
end

local function getTackItem(categoryKey, itemHash)
    local byHash = tackItemIndex[categoryKey]
    if not byHash then return nil end
    return byHash[tostring(itemHash)]
end

local function sanitizeName(name)
    if type(name) ~= 'string' then return nil end
    -- strip control chars and markup characters (names are shown in markdown/NUI dialogs to other players)
    name = name:gsub('[%c<>%[%]%*_`#|\\]', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then return nil end
    return name
end

local function decodeTack(raw)
    if not raw or raw == '' then return {} end
    local ok, t = pcall(json.decode, raw)
    if ok and type(t) == 'table' then return t end
    return {}
end

-- ===================== ACTIVE HORSE SESSIONS (server-authoritative needs) =====================

local CARE_COOLDOWN = 60000 -- ms; mirrors client.lua's CARE_COOLDOWN, enforced here too so a
                             -- modified client can't spam feed/water/brush via direct server events
local activeSessions = {}

local function startSession(citizenid, horseId, hunger, thirst, bonding)
    activeSessions[citizenid] = {
        horseId = horseId,
        hunger = math.max(0, math.min(100, tonumber(hunger) or 100)),
        thirst = math.max(0, math.min(100, tonumber(thirst) or 100)),
        bonding = math.max(0, math.min(100, tonumber(bonding) or 0)),
        lastDecayAt = os.time() * 1000,
        lastFeedAt = 0, lastWaterAt = 0, lastBrushAt = 0,
    }
end

local function endSession(citizenid)
    activeSessions[citizenid] = nil
end

local function applyDecay(session)
    if not (Config.HorseNeeds and Config.HorseNeeds.enabled) then return end
    local now = os.time() * 1000
    local interval = Config.HorseNeeds.decayInterval or 60000
    local elapsed = now - (session.lastDecayAt or now)
    local ticks = math.floor(elapsed / interval)
    if ticks <= 0 then return end
    session.hunger = math.max(0, session.hunger - ticks * (Config.HorseNeeds.hungerDecayPerTick or 0))
    session.thirst = math.max(0, session.thirst - ticks * (Config.HorseNeeds.thirstDecayPerTick or 0))
    session.lastDecayAt = session.lastDecayAt + ticks * interval
end

-- Writes the in-memory needs of an active horse back to the DB (horse stays active = 1)
local function persistSession(citizenid)
    local session = activeSessions[citizenid]
    if not session then return end
    applyDecay(session)
    MySQL.update('UPDATE rsg_stables_horses SET hunger = ?, thirst = ?, bonding = ? WHERE id = ? AND citizenid = ? AND active = 1', {
        session.hunger, session.thirst, session.bonding, session.horseId, citizenid
    })
end

-- ===================== PLAYER CLEANUP =====================
-- The horse is NOT stored on logout: it stays active in the DB at its last saved position
-- so the player can whistle for it when they come back.

AddEventHandler('playerDropped', function()
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player then
        persistSession(Player.PlayerData.citizenid)
        endSession(Player.PlayerData.citizenid)
    end
end)

-- Server-only event (fired by rsg-core). Previously a RegisterNetEvent, which let any client
-- pass another player's id and wipe their horse session.
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then
        persistSession(Player.PlayerData.citizenid)
        endSession(Player.PlayerData.citizenid)
    end
end)

-- ===================== ACTIVE HORSE POSITION =====================

RegisterNetEvent('rsg-stables:server:saveHorsePosition', function(horseId, x, y, z, h, health)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    local session = activeSessions[citizenid]
    horseId = tonumber(horseId)
    if not session or not horseId or session.horseId ~= horseId then return end

    x, y, z, h = tonumber(x), tonumber(y), tonumber(z), tonumber(h) or 0.0
    if not (x and y and z) then return end
    if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 2000 then return end

    local now = GetGameTimer()
    if session.lastPosSaveAt and (now - session.lastPosSaveAt) < 2000 then return end
    session.lastPosSaveAt = now

    applyDecay(session)
    health = math.max(0, math.min(100, tonumber(health) or 100))

    MySQL.update('UPDATE rsg_stables_horses SET pos_x = ?, pos_y = ?, pos_z = ?, pos_h = ?, health = ?, hunger = ?, thirst = ?, bonding = ? WHERE id = ? AND citizenid = ? AND active = 1', {
        x, y, z, h, health, session.hunger, session.thirst, session.bonding, horseId, citizenid
    })
end)

-- ===================== CALLBACKS =====================

lib.callback.register('rsg-stables:server:getStableHorses', function(source, stableName)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not getStableConfig(stableName) then return {} end
    local rows = MySQL.query.await('SELECT *, ' .. AGE_SQL .. ' FROM rsg_stables_horses WHERE citizenid = ? AND stable = ? AND active = 0', {
        Player.PlayerData.citizenid, stableName
    }) or {}
    for _, r in ipairs(rows) do r.stage = horseStage(r.age_days) end
    return rows
end)

-- Called on login: if the player left a horse out, keep it out and hand its data (incl. last
-- saved position) back to the client so a whistle can bring it to them.
lib.callback.register('rsg-stables:server:restoreActiveHorse', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return nil end
    local citizenid = Player.PlayerData.citizenid

    return withLock('citizen:' .. citizenid, function()
        local row = MySQL.single.await('SELECT *, ' .. AGE_SQL .. ' FROM rsg_stables_horses WHERE citizenid = ? AND active = 1 LIMIT 1', { citizenid })
        if not row then
            endSession(citizenid)
            return nil
        end

        if not isTrue(row.alive) then
            MySQL.update.await('UPDATE rsg_stables_horses SET active = 0, pos_x = NULL, pos_y = NULL, pos_z = NULL, pos_h = NULL WHERE id = ?', { row.id })
            endSession(citizenid)
            return nil
        end

        -- keep an existing session for this horse: re-calling this callback must not reset
        -- the feed/water/brush cooldowns or roll hunger/thirst back to stale DB values
        local session = activeSessions[citizenid]
        if session and session.horseId == row.id then
            applyDecay(session)
            row.hunger, row.thirst, row.bonding = session.hunger, session.thirst, session.bonding
        else
            startSession(citizenid, row.id, row.hunger, row.thirst, row.bonding)
        end
        return row
    end)
end)

-- ===================== HORSE FEED ITEMS =====================
for _, feedItem in ipairs(Config.HorseFeedItems) do
    RSGCore.Functions.CreateUseableItem(feedItem.item, function(source)
        TriggerClientEvent('rsg-stables:client:useFeed', source, feedItem.item)
    end)
end

-- ===================== HORSE BRUSH ITEM =====================
RSGCore.Functions.CreateUseableItem(Config.HorseBrushItem or 'horse_brush', function(source)
    TriggerClientEvent('rsg-stables:client:useBrush', source)
end)

-- ===================== HORSE STIMULANT =====================
if Config.HorseStimulant and Config.HorseStimulant.enabled then
    RSGCore.Functions.CreateUseableItem(Config.HorseStimulant.item, function(source)
        TriggerClientEvent('rsg-stables:client:useStimulant', source)
    end)
end

lib.callback.register('rsg-stables:server:useStimulant', function(source)
    local cfg = Config.HorseStimulant
    if not (cfg and cfg.enabled) then return false, locale('stimulant_disabled') end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end

    local session = activeSessions[Player.PlayerData.citizenid]
    if not session then return false, locale('no_active_horse') end

    local now = os.time()
    if not cfg.allowReuse and (session.stimulantUntil or 0) > now then
        local left = session.stimulantUntil - now
        return false, locale('stimulant_already_active', left // 60, left % 60)
    end

    if not Player.Functions.GetItemByName(cfg.item) then
        return false, locale('missing_item', cfg.label)
    end
    if not Player.Functions.RemoveItem(cfg.item, 1, nil, 'rsg-stables-stimulant') then
        return false, locale('item_use_failed')
    end
    TriggerClientEvent('rsg-inventory:client:ItemBox', source, RSGCore.Shared.Items[cfg.item], 'remove', 1)

    session.stimulantUntil = now + cfg.duration
    return true, { duration = cfg.duration }
end)

lib.callback.register('rsg-stables:server:feedHorse', function(source, preferredItem)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end

    local session = activeSessions[Player.PlayerData.citizenid]
    if not session then return false, locale('no_active_horse') end

    local now = os.time() * 1000
    if now - (session.lastFeedAt or 0) < CARE_COOLDOWN then
        return false, locale('not_hungry')
    end

    -- item used from the inventory is tried first, then any other feed item the player carries
    local feedList = {}
    for _, feedItem in ipairs(Config.HorseFeedItems) do
        if feedItem.item == preferredItem then table.insert(feedList, 1, feedItem) else feedList[#feedList + 1] = feedItem end
    end

    for _, feedItem in ipairs(feedList) do
        local owned = Player.Functions.GetItemByName(feedItem.item)
        if owned and (owned.amount or 0) > 0 then
            local removed = Player.Functions.RemoveItem(feedItem.item, 1, nil, 'rsg-stables-feed')
            if removed then
                TriggerClientEvent('rsg-inventory:client:ItemBox', source, RSGCore.Shared.Items[feedItem.item], 'remove', 1)
                applyDecay(session)
                session.hunger = math.max(0, math.min(100, session.hunger + (feedItem.hunger or 0)))
                if Config.HorseBonding.enabled then
                    session.bonding = math.max(0, math.min(100, session.bonding + (Config.HorseBonding.feedGain or 0)))
                end
                session.lastFeedAt = now
                return true, {
                    label = feedItem.label,
                    health = feedItem.health,
                    stamina = feedItem.stamina,
                    hunger = session.hunger,
                    bonding = session.bonding,
                }
            end
        end
    end

    return false, locale('need_feed')
end)

lib.callback.register('rsg-stables:server:waterHorse', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end

    local session = activeSessions[Player.PlayerData.citizenid]
    if not session then return false, locale('no_active_horse') end

    local now = os.time() * 1000
    if now - (session.lastWaterAt or 0) < CARE_COOLDOWN then
        return false, locale('not_thirsty')
    end

    for _, drinkItem in ipairs(Config.HorseDrinkItems) do
        local owned = Player.Functions.GetItemByName(drinkItem.item)
        if owned and (owned.amount or 0) > 0 then
            local removed = Player.Functions.RemoveItem(drinkItem.item, 1, nil, 'rsg-stables-water')
            if removed then
                TriggerClientEvent('rsg-inventory:client:ItemBox', source, RSGCore.Shared.Items[drinkItem.item], 'remove', 1)
                applyDecay(session)
                session.thirst = math.max(0, math.min(100, session.thirst + (drinkItem.thirst or 0)))
                if Config.HorseBonding.enabled then
                    session.bonding = math.max(0, math.min(100, session.bonding + (Config.HorseBonding.waterGain or 0)))
                end
                session.lastWaterAt = now
                return true, {
                    label = drinkItem.label,
                    stamina = drinkItem.stamina,
                    thirst = session.thirst,
                    bonding = session.bonding,
                }
            end
        end
    end

    return false, locale('need_water')
end)

-- Horse drank from a river/lake/trough on its own (no item needed)
lib.callback.register('rsg-stables:server:naturalDrink', function(source)
    local cfg = Config.HorseNaturalDrink
    if not (cfg and cfg.enabled) then return false end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end
    local session = activeSessions[Player.PlayerData.citizenid]
    if not session then return false end

    local now = os.time() * 1000
    if now - (session.lastNaturalDrinkAt or 0) < (cfg.cooldown or 120000) then return false end

    applyDecay(session)
    if session.thirst > (cfg.thirstThreshold or 40) then return false end

    session.thirst = math.max(session.thirst, math.min(100, cfg.thirstRestore or 100))
    session.lastNaturalDrinkAt = now
    return true, { thirst = session.thirst }
end)

lib.callback.register('rsg-stables:server:naturalGraze', function(source)
    local cfg = Config.HorseNaturalGraze
    if not (cfg and cfg.enabled) then return false end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end
    local session = activeSessions[Player.PlayerData.citizenid]
    if not session then return false end

    local now = os.time() * 1000
    if now - (session.lastNaturalGrazeAt or 0) < (cfg.cooldown or 120000) then return false end

    applyDecay(session)
    if session.hunger > (cfg.hungerThreshold or 40) then return false end

    session.hunger = math.max(session.hunger, math.min(100, cfg.hungerRestore or 100))
    session.lastNaturalGrazeAt = now
    return true, { hunger = session.hunger }
end)

lib.callback.register('rsg-stables:server:brushHorse', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end

    local session = activeSessions[Player.PlayerData.citizenid]
    if not session then return false, locale('no_active_horse') end

    local now = os.time() * 1000
    if now - (session.lastBrushAt or 0) < CARE_COOLDOWN then
        return false, locale('already_clean')
    end

    local brushItem = Config.HorseBrushItem or 'horse_brush'
    local brush = Player.Functions.GetItemByName(brushItem)
    if not brush or (brush.amount or 0) < 1 then
        return false, locale('need_brush')
    end

    session.lastBrushAt = now
    if Config.HorseBonding.enabled then
        applyDecay(session)
        session.bonding = math.max(0, math.min(100, session.bonding + (Config.HorseBonding.brushGain or 0)))
    end

    return true, { bonding = session.bonding }
end)

lib.callback.register('rsg-stables:server:buyHorse', function(source, stableName, model, horseName, outfit, gender)
    if gender ~= 'male' and gender ~= 'female' then gender = randomGender() end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end

    local stable = getStableConfig(stableName)
    if not stable then return false, locale('invalid_stable') end

    if not isNearStable(source, stable) then return false, locale('not_close_to_stable') end

    local breed = getBreedConfig(model)
    if not breed then return false, locale('invalid_breed') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local owned = countOwnedHorses(Player.PlayerData.citizenid)
        if owned >= Config.MaxOwnedHorses then
            return false, locale('max_horses_owned', Config.MaxOwnedHorses)
        end

        return withLock('stable:' .. stableName, function()
            local atStable = MySQL.prepare.await('SELECT COUNT(*) FROM rsg_stables_horses WHERE citizenid = ? AND stable = ?', { Player.PlayerData.citizenid, stableName })
            if atStable and atStable >= Config.MaxHorsesPerStable then
                return false, locale('stable_full')
            end

            if not chargePlayer(Player, breed.price) then
                return false, locale('insufficient_funds')
            end

            local safeName = sanitizeName(horseName) or locale('unnamed_horse')
            safeName = safeName:sub(1, 40)

            local maxOutfits = breed.outfits or 1
            local safeOutfit = math.floor(tonumber(outfit) or 0)
            if safeOutfit < 0 or safeOutfit >= maxOutfits then safeOutfit = 0 end

            local ok, insertId = pcall(function()
                return MySQL.insert.await([[
                    INSERT INTO rsg_stables_horses
                        (citizenid, stable, model, breed_label, gender, name, outfit, tack, health, stamina, speed, accel, handling, maxhealth, alive, insured, active)
                    VALUES (?, ?, ?, ?, ?, ?, ?, '{}', 100, 100, ?, ?, ?, ?, 1, 0, 0)
                ]], {
                    Player.PlayerData.citizenid, stableName, breed.model, breed.label, gender, safeName, safeOutfit,
                    breed.speed, breed.acceleration, breedHandlingValue(breed), breed.health
                })
            end)

            if not ok or not insertId or insertId == 0 then
                print(('[rsg-stables] ERROR: buyHorse insert failed for citizenid %s: %s'):format(
                    Player.PlayerData.citizenid, tostring(insertId)
                ))
                Player.Functions.AddMoney(Config.PaymentAccount, breed.price, 'rsg-stables-refund')
                return false, locale('buy_save_failed')
            end

            return true, insertId
        end)
    end)
end)

-- ===================== WILD HORSE CLAIM =====================
-- brokenWild[src] = { netId = int, at = os.time() }  (one pending horse per player)
local brokenWild = {}
local POP_MISSION = 7 -- population type of script-created peds (owned / spawned horses)

local function isClaimableEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if GetEntityType(entity) ~= 1 then return false end -- must be a ped
    if GetEntityPopulationType and GetEntityPopulationType(entity) == POP_MISSION then return false end
    if IsPedAPlayer(entity) then return false end
    return true
end

RegisterNetEvent('rsg-stables:server:wildHorseBroken', function(netId)
    local src = source
    if not (Config.WildHorse and Config.WildHorse.enabled) then return end
    netId = toId(netId)
    if not netId then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not isClaimableEntity(entity) then return end
    if not getBreedConfig(GetEntityModel(entity)) then return end
    -- must be next to the horse when it's broken
    local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(entity))
    if dist > 5.0 then return end
    -- the same horse can't be registered by two players
    for other, rec in pairs(brokenWild) do
        if other ~= src and rec.netId == netId then return end
    end
    brokenWild[src] = { netId = netId, at = os.time() }
end)

AddEventHandler('playerDropped', function()
    brokenWild[source] = nil
end)

lib.callback.register('rsg-stables:server:claimWildHorse', function(source, stableName, netId, horseName)
    local cfg = Config.WildHorse
    if not (cfg and cfg.enabled) then return false, locale('wild_not_claimable') end

    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end

    local stable = getStableConfig(stableName)
    if not stable then return false, locale('invalid_stable') end
    if not isNearStable(source, stable) then return false, locale('not_close_to_stable') end

    netId = toId(netId)
    local rec = brokenWild[source]
    if not netId or not rec or rec.netId ~= netId then return false, locale('wild_not_broken') end
    if os.time() - rec.at > (cfg.claimWindow or 1800) then
        brokenWild[source] = nil
        return false, locale('wild_expired')
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not isClaimableEntity(entity) then
        brokenWild[source] = nil
        return false, locale('wild_not_claimable')
    end

    local model = GetEntityModel(entity)
    local breed = getBreedConfig(model)
    if not breed then return false, locale('wild_not_claimable') end

    local horseCoords = GetEntityCoords(entity)
    local maxDist = cfg.horseDistance or 15.0
    if #(GetEntityCoords(GetPlayerPed(source)) - horseCoords) > maxDist
        or not isNearStable(source, stable, STABLE_INTERACT_DISTANCE + maxDist) then
        return false, locale('wild_too_far')
    end

    local citizenid = Player.PlayerData.citizenid
    return withLock('citizen:' .. citizenid, function()
        if countOwnedHorses(citizenid) >= Config.MaxOwnedHorses then
            return false, locale('max_horses_owned', Config.MaxOwnedHorses)
        end
        return withLock('stable:' .. stableName, function()
            local atStable = MySQL.prepare.await('SELECT COUNT(*) FROM rsg_stables_horses WHERE citizenid = ? AND stable = ?', { citizenid, stableName })
            if atStable and atStable >= Config.MaxHorsesPerStable then
                return false, locale('stable_full')
            end

            local fee = tonumber(cfg.claimFee) or 0
            if fee > 0 and not chargePlayer(Player, fee) then
                return false, locale('insufficient_funds')
            end

            local safeName = (sanitizeName(horseName) or locale('unnamed_horse')):sub(1, 40)

            local ok, insertId = pcall(function()
                return MySQL.insert.await([[
                    INSERT INTO rsg_stables_horses
                        (citizenid, stable, model, breed_label, gender, name, outfit, tack, health, stamina, speed, accel, handling, maxhealth, alive, insured, active)
                    VALUES (?, ?, ?, ?, ?, ?, 0, '{}', 100, 100, ?, ?, ?, ?, 1, 0, 0)
                ]], {
                    citizenid, stableName, breed.model, breed.label, randomGender(), safeName,
                    breed.speed, breed.acceleration, breedHandlingValue(breed), breed.health
                })
            end)

            if not ok or not insertId or insertId == 0 then
                print(('[rsg-stables] ERROR: claimWildHorse insert failed for citizenid %s: %s'):format(citizenid, tostring(insertId)))
                if fee > 0 then Player.Functions.AddMoney(Config.PaymentAccount, fee, 'rsg-stables-refund') end
                return false, locale('buy_save_failed')
            end

            brokenWild[source] = nil
            -- the wild horse goes into the stable: remove the world entity
            if DoesEntityExist(entity) then DeleteEntity(entity) end
            return true, safeName
        end)
    end)
end)

lib.callback.register('rsg-stables:server:retrieveHorse', function(source, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horse = MySQL.single.await('SELECT *, ' .. AGE_SQL .. ' FROM rsg_stables_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if isTrue(horse.active) then return false, locale('horse_already_out') end
        if not isTrue(horse.alive) then return false, locale('horse_dead_revive_first') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end
        if isHorseBreeding(horseId) then return false, locale('horse_is_breeding') end

        local existingActive = MySQL.single.await('SELECT id FROM rsg_stables_horses WHERE citizenid = ? AND active = 1', {
            Player.PlayerData.citizenid
        })
        if existingActive then return false, locale('already_have_horse') end

        MySQL.update.await('UPDATE rsg_stables_horses SET active = 1 WHERE id = ?', { horseId })
        startSession(Player.PlayerData.citizenid, horse.id, horse.hunger, horse.thirst, horse.bonding)

        return true, horse
    end)
end)

-- Shared by normal store (must be at a stable) and flee-store (Config.HorseFlee.storeOnFlee)
local function storeActive(source, horseId, health, stamina, requireStable)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_out') end
    if requireStable and not nearAnyStable(source, (Config.StoreDistance or 8.0) + 10.0) then
        return false, locale('not_close_to_stable')
    end
    local citizenid = Player.PlayerData.citizenid

    return withLock('citizen:' .. citizenid, function()
        local horse = MySQL.single.await('SELECT id FROM rsg_stables_horses WHERE id = ? AND citizenid = ? AND active = 1', {
            horseId, citizenid
        })
        if not horse then return false, locale('horse_not_out') end

        health = math.max(0, math.min(100, tonumber(health) or 100))
        stamina = math.max(0, math.min(100, tonumber(stamina) or 100))

        local session = activeSessions[citizenid]
        local hunger, thirst, bonding = 100, 100, 0
        if session then
            applyDecay(session)
            hunger, thirst, bonding = session.hunger, session.thirst, session.bonding
        end

        MySQL.update.await('UPDATE rsg_stables_horses SET active = 0, pos_x = NULL, pos_y = NULL, pos_z = NULL, pos_h = NULL, health = ?, stamina = ?, hunger = ?, thirst = ?, bonding = ? WHERE id = ?', {
            health, stamina, hunger, thirst, bonding, horseId
        })
        endSession(citizenid)
        return true
    end)
end

lib.callback.register('rsg-stables:server:storeHorse', function(source, horseId, health, stamina)
    return storeActive(source, horseId, health, stamina, true)
end)

lib.callback.register('rsg-stables:server:fleeStoreHorse', function(source, horseId, health, stamina)
    if not (Config.HorseFlee.enabled and Config.HorseFlee.storeOnFlee) then return false end
    return storeActive(source, horseId, health, stamina, false)
end)

lib.callback.register('rsg-stables:server:horseDied', function(source, horseId, netId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end
    horseId = toId(horseId)
    if not horseId then return false end

    -- a living horse can't be reported dead (stops a free insured heal + store-from-anywhere)
    netId = toId(netId)
    local entity = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if entity ~= 0 and DoesEntityExist(entity) and GetEntityHealth(entity) > 0 then
        return false
    end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        -- only the horse that is actually out can die (stops a client killing/"insurance-healing" stabled horses)
        local horse = MySQL.single.await('SELECT * FROM rsg_stables_horses WHERE id = ? AND citizenid = ? AND active = 1', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false end

        endSession(Player.PlayerData.citizenid)

        if isTrue(horse.insured) then
            MySQL.update.await('UPDATE rsg_stables_horses SET active = 0, pos_x = NULL, pos_y = NULL, pos_z = NULL, pos_h = NULL, alive = 1, insured = 0, health = 100, stamina = 100, hunger = 100, thirst = 100 WHERE id = ?', { horseId })
            lib.notify(source, { description = locale('horse_insured_returned'), type = 'inform' })
            return true, 'insured'
        else
            MySQL.update.await('UPDATE rsg_stables_horses SET active = 0, pos_x = NULL, pos_y = NULL, pos_z = NULL, pos_h = NULL, alive = 0 WHERE id = ?', { horseId })
            lib.notify(source, { description = locale('horse_dead'), type = 'error' })
            return true, 'dead'
        end
    end)
end)

lib.callback.register('rsg-stables:server:renameHorse', function(source, horseId, newName)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    newName = sanitizeName(newName)
    if not newName then return false, locale('invalid_name') end
    newName = newName:sub(1, 40)
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horse = MySQL.single.await('SELECT id, stable FROM rsg_stables_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end

        if not chargePlayer(Player, Config.RenameCost) then return false, locale('insufficient_funds') end

        MySQL.update.await('UPDATE rsg_stables_horses SET name = ? WHERE id = ?', { newName, horseId })
        return true, newName
    end)
end)

lib.callback.register('rsg-stables:server:insureHorse', function(source, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horse = MySQL.single.await('SELECT * FROM rsg_stables_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if isTrue(horse.insured) then return false, locale('already_insured') end
        if not isTrue(horse.alive) then return false, locale('horse_is_dead') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end

        if not chargePlayer(Player, Config.InsuranceCost) then return false, locale('insufficient_funds') end

        MySQL.update.await('UPDATE rsg_stables_horses SET insured = 1 WHERE id = ?', { horseId })
        return true
    end)
end)

lib.callback.register('rsg-stables:server:reviveHorse', function(source, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horse = MySQL.single.await('SELECT * FROM rsg_stables_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if isTrue(horse.alive) then return false, locale('horse_not_dead') end
        if isTrue(horse.died_of_age) then return false, locale('horse_died_of_age_final') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end

        if not chargePlayer(Player, Config.ReviveCost) then return false, locale('insufficient_funds') end

        MySQL.update.await('UPDATE rsg_stables_horses SET alive = 1, health = 100, stamina = 100, hunger = 100, thirst = 100, insured = 0 WHERE id = ?', { horseId })
        return true
    end)
end)

-- Remove a dead horse for good (frees the owned-horse slot; horses that died of old age can never be revived)
lib.callback.register('rsg-stables:server:releaseHorse', function(source, horseId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horse = MySQL.single.await('SELECT id, stable, alive FROM rsg_stables_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if isTrue(horse.alive) then return false, locale('horse_not_dead') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end

        local deleted = MySQL.update.await('DELETE FROM rsg_stables_horses WHERE id = ? AND citizenid = ? AND alive = 0', { horseId, Player.PlayerData.citizenid })
        if not deleted or deleted == 0 then return false, locale('release_failed') end
        return true
    end)
end)

lib.callback.register('rsg-stables:server:transferHorse', function(source, horseId, newStable)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end

    local stable = getStableConfig(newStable)
    if not stable then return false, locale('invalid_stable') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
      return withLock('stable:' .. newStable, function()
        local horse = MySQL.single.await('SELECT * FROM rsg_stables_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if isTrue(horse.active) then return false, locale('store_horse_first') end
        if horse.stable == newStable then return false, locale('already_stabled_there') end
        if isHorseBreeding(horseId) then return false, locale('horse_is_breeding') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end

        local atStable = MySQL.prepare.await('SELECT COUNT(*) FROM rsg_stables_horses WHERE citizenid = ? AND stable = ?', { Player.PlayerData.citizenid, newStable })
        if atStable and atStable >= Config.MaxHorsesPerStable then
            return false, locale('destination_full')
        end

        MySQL.update.await('UPDATE rsg_stables_horses SET stable = ? WHERE id = ?', { newStable, horseId })
        return true
      end)
    end)
end)

-- ===================== GIVE HORSE TO ANOTHER PLAYER =====================
local function charName(P)
    local ci = P.PlayerData.charinfo or {}
    return ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
end

local function nearbyPlayers(src, maxDist)
    local list = {}
    local myPed = GetPlayerPed(src)
    if not myPed or myPed == 0 then return list end
    local myCoords = GetEntityCoords(myPed)
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= src then
            local ped = GetPlayerPed(id)
            local P = RSGCore.Functions.GetPlayer(id)
            if P and ped and ped ~= 0 and #(GetEntityCoords(ped) - myCoords) <= maxDist then
                list[#list + 1] = { id = id, name = charName(P) }
            end
        end
    end
    return list
end

local pendingOffers = {}

lib.callback.register('rsg-stables:server:getNearbyPlayers', function(source)
    if not (Config.HorseGive and Config.HorseGive.enabled) then return {} end
    return nearbyPlayers(source, Config.HorseGive.distance or 5.0)
end)

lib.callback.register('rsg-stables:server:giveHorse', function(source, horseId, targetId, price)
    local cfg = Config.HorseGive
    if not (cfg and cfg.enabled) then return false, locale('give_disabled') end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId, targetId = toId(horseId), toId(targetId)
    if not horseId then return false, locale('horse_not_found') end
    if not targetId or targetId == source then return false, locale('give_target_invalid') end
    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target then return false, locale('give_target_invalid') end

    price = math.floor(tonumber(price) or 0)
    if price < 0 or price > (cfg.maxPrice or 100000) then return false, locale('give_price_invalid', cfg.maxPrice or 100000) end
    local function targetCanPay(T)
        return price == 0 or (T.PlayerData.money[Config.PaymentAccount] or 0) >= price
    end
    if not targetCanPay(Target) then return false, locale('give_target_cant_afford', price) end

    local function targetNearby()
        for _, p in ipairs(nearbyPlayers(source, cfg.distance or 5.0)) do
            if p.id == targetId then return true end
        end
        return false
    end

    -- pre-checks before bothering the other player
    local horse = MySQL.single.await('SELECT * FROM rsg_stables_horses WHERE id = ? AND citizenid = ?', { horseId, Player.PlayerData.citizenid })
    if not horse then return false, locale('horse_not_found') end
    if not isTrue(horse.alive) then return false, locale('horse_is_dead') end
    if isTrue(horse.active) then return false, locale('store_horse_first') end
    if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end
    if not targetNearby() then return false, locale('give_target_too_far') end

    -- ask the receiver (one offer at a time per receiver, so popups can't stack or be spammed)
    if pendingOffers[targetId] then return false, locale('give_target_busy') end
    pendingOffers[targetId] = true
    local okAsk, accepted = pcall(lib.callback.await, 'rsg-stables:client:confirmHorseGift', targetId, charName(Player), horse.name, horse.breed_label, price)
    pendingOffers[targetId] = nil
    if not okAsk or accepted ~= true then return false, locale('give_declined') end

    local giverCid, targetCid = Player.PlayerData.citizenid, Target.PlayerData.citizenid
    -- lock both players in a fixed order so two simultaneous gifts can't deadlock
    local first, second = giverCid, targetCid
    if second < first then first, second = second, first end

    return withLock('citizen:' .. first, function()
      return withLock('citizen:' .. second, function()
        -- re-check everything: state may have changed while the receiver was deciding
        local h = MySQL.single.await('SELECT * FROM rsg_stables_horses WHERE id = ? AND citizenid = ?', { horseId, giverCid })
        if not h then return false, locale('horse_not_found') end
        if not isTrue(h.alive) then return false, locale('horse_is_dead') end
        if isTrue(h.active) then return false, locale('store_horse_first') end
        if isHorseBreeding(horseId) then return false, locale('horse_is_breeding') end
        if not nearStableByName(source, h.stable) then return false, locale('not_close_to_stable') end
        Target = RSGCore.Functions.GetPlayer(targetId)
        if not Target or Target.PlayerData.citizenid ~= targetCid or not targetNearby() then return false, locale('give_target_too_far') end

        if countOwnedHorses(targetCid) >= Config.MaxOwnedHorses then return false, locale('give_target_full') end
        local atStable = MySQL.prepare.await('SELECT COUNT(*) FROM rsg_stables_horses WHERE citizenid = ? AND stable = ?', { targetCid, h.stable })
        if atStable and atStable >= Config.MaxHorsesPerStable then return false, locale('give_target_stable_full') end

        if not targetCanPay(Target) then
            lib.notify(targetId, { description = locale('give_you_cant_afford', price), type = 'error' })
            return false, locale('give_target_cant_afford', price)
        end
        if (cfg.fee or 0) > 0 and not chargePlayer(Player, cfg.fee) then return false, locale('insufficient_funds') end
        if price > 0 and not chargePlayer(Target, price) then
            if (cfg.fee or 0) > 0 then Player.Functions.AddMoney(Config.PaymentAccount, cfg.fee, 'rsg-stables-refund') end
            return false, locale('give_target_cant_afford', price)
        end

        local changed = MySQL.update.await('UPDATE rsg_stables_horses SET citizenid = ?, bonding = 0 WHERE id = ? AND citizenid = ? AND active = 0', { targetCid, horseId, giverCid })
        if not changed or changed == 0 then
            if (cfg.fee or 0) > 0 then Player.Functions.AddMoney(Config.PaymentAccount, cfg.fee, 'rsg-stables-refund') end
            if price > 0 then Target.Functions.AddMoney(Config.PaymentAccount, price, 'rsg-stables-refund') end
            return false, locale('give_failed')
        end

        if price > 0 then
            Player.Functions.AddMoney(Config.PaymentAccount, price, 'rsg-stables-horse-sale')
            lib.notify(targetId, { description = locale('give_bought', h.name, charName(Player), price), type = 'success' })
        else
            lib.notify(targetId, { description = locale('give_received', h.name, charName(Player)), type = 'success' })
        end
        return true, price
      end)
    end)
end)

-- ===================== TACK =====================

lib.callback.register('rsg-stables:server:applyHorseTack', function(source, horseId, selections)
    if not Config.Tack.enabled then return false, locale('tack_disabled') end
    if type(selections) ~= 'table' then return false, locale('invalid_selections') end

    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horse = MySQL.single.await('SELECT * FROM rsg_stables_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if not isTrue(horse.alive) then return false, locale('horse_is_dead') end
        if isTrue(horse.active) then return false, locale('store_horse_first') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end

        local tack = decodeTack(horse.tack)
        local total = 0
        local changes = {} -- categoryKey -> new hash-or-nil, applied only after every pick validates

        for _, category in ipairs(Config.TackCategories) do
            local sel = selections[category.key]
            if sel ~= nil then
                sel = math.floor(tonumber(sel) or 0)
                if sel == 0 then
                    if category.required then return false, locale('tack_required', category.label) end
                    if tack[category.key] then
                        changes[category.key] = false -- false = explicit removal, distinct from "untouched"
                    end
                else
                    local item = getTackItem(category.key, sel)
                    if not item then return false, locale('invalid_tack_item', category.label) end
                    if tostring(tack[category.key]) ~= tostring(sel) then
                        total = total + item.price
                        changes[category.key] = sel
                    end
                end
            end
        end

        for _, category in ipairs(Config.TackCategories) do
            if category.required and not (changes[category.key] or tack[category.key]) then
                return false, locale('tack_required', category.label)
            end
        end

        if next(changes) == nil then
            return false, locale('no_tack_changes')
        end

        if total > 0 and not chargePlayer(Player, total) then
            return false, locale('insufficient_funds')
        end

        for key, value in pairs(changes) do
            tack[key] = value or nil
        end

        MySQL.update.await('UPDATE rsg_stables_horses SET tack = ? WHERE id = ?', { json.encode(tack), horseId })
        return true, { tack = tack, charged = total }
    end)
end)

-- ===================== COAT =====================

local COAT_LIMITS = { tint0 = 254, tint1 = 255, tint2 = 255, mane = 254, tail = 254 }

local function normalizeCoat(raw)
    if type(raw) == 'string' then
        local ok, decoded = pcall(json.decode, raw)
        raw = ok and decoded or nil
    end
    if type(raw) ~= 'table' then return nil end
    local coat = {}
    for key, max in pairs(COAT_LIMITS) do
        local v = tonumber(raw[key])
        if not v then return nil end
        v = math.floor(v)
        if v < 0 or v > max then return nil end
        coat[key] = v
    end
    return coat
end

local function sameCoat(a, b)
    if not a or not b then return false end
    for key in pairs(COAT_LIMITS) do
        if a[key] ~= b[key] then return false end
    end
    return true
end

-- rawCoat = { tint0, tint1, tint2, mane, tail } or the string 'reset' to restore the natural coat
lib.callback.register('rsg-stables:server:applyHorseCoat', function(source, horseId, rawCoat)
    if not (Config.Coat and Config.Coat.enabled) then return false, locale('coat_disabled') end

    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    horseId = toId(horseId)
    if not horseId then return false, locale('horse_not_found') end

    local reset = rawCoat == 'reset'
    local coat = not reset and normalizeCoat(rawCoat) or nil
    if not reset and not coat then return false, locale('invalid_coat') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horse = MySQL.single.await('SELECT * FROM rsg_stables_horses WHERE id = ? AND citizenid = ?', {
            horseId, Player.PlayerData.citizenid
        })
        if not horse then return false, locale('horse_not_found') end
        if not isTrue(horse.alive) then return false, locale('horse_is_dead') end
        if isTrue(horse.active) then return false, locale('store_horse_first') end
        if not nearStableByName(source, horse.stable) then return false, locale('not_close_to_stable') end

        if reset then
            if not horse.coat or horse.coat == '' then return false, locale('no_coat_changes') end
            MySQL.update.await('UPDATE rsg_stables_horses SET coat = NULL WHERE id = ?', { horseId })
            return true, { coat = nil, charged = 0 }
        end

        if sameCoat(coat, normalizeCoat(horse.coat)) then
            return false, locale('no_coat_changes')
        end

        local price = tonumber(Config.Coat.price) or 0
        if price > 0 and not chargePlayer(Player, price) then
            return false, locale('insufficient_funds')
        end

        MySQL.update.await('UPDATE rsg_stables_horses SET coat = ? WHERE id = ?', { json.encode(coat), horseId })
        return true, { coat = coat, charged = price }
    end)
end)

-- ===================== BREEDING =====================

lib.callback.register('rsg-stables:server:startBreeding', function(source, stableName, idA, idB)
    if not Config.Breeding.enabled then return false, locale('breeding_disabled') end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    idA, idB = toId(idA), toId(idB)
    if not idA or not idB then return false, locale('horse_not_found') end
    if idA == idB then return false, locale('breed_choose_different') end

    local stable = getStableConfig(stableName)
    if not stable then return false, locale('invalid_stable') end
    if not isNearStable(source, stable) then return false, locale('not_close_to_stable') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local horseA = MySQL.single.await('SELECT *, ' .. AGE_SQL .. ' FROM rsg_stables_horses WHERE id = ? AND citizenid = ?', { idA, Player.PlayerData.citizenid })
        local horseB = MySQL.single.await('SELECT *, ' .. AGE_SQL .. ' FROM rsg_stables_horses WHERE id = ? AND citizenid = ?', { idB, Player.PlayerData.citizenid })
        if not horseA or not horseB then return false, locale('horse_not_found') end
        local stA, stB = horseStage(horseA.age_days), horseStage(horseB.age_days)
        if stA == 'young' or stB == 'young' then return false, locale('breed_too_young') end
        if stA == 'old' or stB == 'old' then return false, locale('breed_too_old') end
        if not isTrue(horseA.alive) or not isTrue(horseB.alive) then return false, locale('breed_both_alive') end
        if isTrue(horseA.active) or isTrue(horseB.active) then return false, locale('breed_both_stabled') end
        if Config.Breeding.sameStableOnly ~= false and (horseA.stable ~= stableName or horseB.stable ~= stableName) then
            return false, locale('breed_both_stabled_here')
        end

        if Config.Breeding.requireOppositeGender ~= false and (not horseA.gender or horseA.gender == horseB.gender) then
            return false, locale('breed_need_opposite_gender')
        end

        local pending = MySQL.single.await('SELECT id FROM rsg_stables_breeding WHERE (parent_a = ? OR parent_b = ? OR parent_a = ? OR parent_b = ?) AND collected = 0', {
            idA, idA, idB, idB
        })
        if pending then return false, locale('breed_already_breeding') end

        local now = os.time() * 1000
        if (tonumber(horseA.breed_cooldown) or 0) > now or (tonumber(horseB.breed_cooldown) or 0) > now then
            return false, locale('breed_parent_cooldown')
        end

        if not chargePlayer(Player, Config.Breeding.cost) then return false, locale('insufficient_funds') end

        local readyAt = now + Config.Breeding.time
        if (Config.Breeding.parentCooldown or 0) > 0 then
            MySQL.update.await('UPDATE rsg_stables_horses SET breed_cooldown = ? WHERE id IN (?, ?)', { now + Config.Breeding.parentCooldown, idA, idB })
        end
        MySQL.insert.await([[
            INSERT INTO rsg_stables_breeding (citizenid, stable, parent_a, parent_b, ready_at, collected)
            VALUES (?, ?, ?, ?, ?, 0)
        ]], { Player.PlayerData.citizenid, stableName, idA, idB, readyAt })

        return true, readyAt
    end)
end)

lib.callback.register('rsg-stables:server:getBreedingJobs', function(source, stableName)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not getStableConfig(stableName) then return {} end
    local rows = MySQL.query.await('SELECT * FROM rsg_stables_breeding WHERE citizenid = ? AND stable = ? AND collected = 0', {
        Player.PlayerData.citizenid, stableName
    }) or {}
    -- send remaining time from the SERVER clock (client clocks can't be trusted / differ)
    local now = os.time() * 1000
    for _, r in ipairs(rows) do
        r.ms_left = math.max(0, (tonumber(r.ready_at) or 0) - now)
        r.ready = r.ms_left == 0
    end
    return rows
end)

lib.callback.register('rsg-stables:server:collectFoal', function(source, breedingId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false, locale('player_not_found') end
    breedingId = toId(breedingId)
    if not breedingId then return false, locale('breed_job_not_found') end

    return withLock('citizen:' .. Player.PlayerData.citizenid, function()
        local job = MySQL.single.await('SELECT * FROM rsg_stables_breeding WHERE id = ? AND citizenid = ? AND collected = 0', {
            breedingId, Player.PlayerData.citizenid
        })
        if not job then return false, locale('breed_job_not_found') end
        if (os.time() * 1000) < job.ready_at then return false, locale('foal_not_ready') end
        if not nearStableByName(source, job.stable) then return false, locale('not_close_to_stable') end

        local owned = countOwnedHorses(Player.PlayerData.citizenid)
        if owned >= Config.MaxOwnedHorses then return false, locale('horse_limit_reached') end

        local atStable = MySQL.prepare.await('SELECT COUNT(*) FROM rsg_stables_horses WHERE citizenid = ? AND stable = ?', { Player.PlayerData.citizenid, job.stable })
        if atStable and atStable >= Config.MaxHorsesPerStable then
            return false, locale('foal_stable_full')
        end

        local parentA = MySQL.single.await('SELECT * FROM rsg_stables_horses WHERE id = ?', { job.parent_a })
        local parentB = MySQL.single.await('SELECT * FROM rsg_stables_horses WHERE id = ?', { job.parent_b })
        if not parentA or not parentB then return false, locale('parent_data_missing') end

        -- inherit stats on the breed's 1..BreedStatMax scale (handling uses its own 0..100 scale)
        local cfgB = Config.Breeding
        local function inherit(a, b, lo, hi, variance)
            a, b = tonumber(a) or lo, tonumber(b) or lo
            local value
            if math.random(1, 100) <= (cfgB.betterParentChance or 0) then
                value = math.max(a, b)
            else
                value = math.floor((a + b) / 2 + 0.5)
            end
            value = value + math.random(-variance, variance)
            return math.max(lo, math.min(hi, value))
        end
        local statMax = Config.BreedStatMax or 10
        local v = cfgB.statVariance or 1

        -- foal takes the model/breed of a random parent
        local foalParent = math.random(1, 2) == 1 and parentA or parentB

        -- claim the job first so a double-click / second request can't create two foals
        local claimed = MySQL.update.await('UPDATE rsg_stables_breeding SET collected = 1 WHERE id = ? AND collected = 0', { breedingId })
        if not claimed or claimed == 0 then return false, locale('breed_job_not_found') end

        local ok, insertId = pcall(function()
            return MySQL.insert.await([[
                INSERT INTO rsg_stables_horses
                    (citizenid, stable, model, breed_label, gender, name, outfit, tack, health, stamina, speed, accel, handling, maxhealth, alive, insured, active)
                VALUES (?, ?, ?, ?, ?, ?, ?, '{}', 100, 100, ?, ?, ?, ?, 1, 0, 0)
            ]], {
                Player.PlayerData.citizenid, job.stable, foalParent.model, foalParent.breed_label, randomGender(), locale('unnamed_foal'), foalParent.outfit or 0,
                inherit(parentA.speed, parentB.speed, 1, statMax, v),
                inherit(parentA.accel, parentB.accel, 1, statMax, v),
                inherit(parentA.handling, parentB.handling, 0, 100, v * 5),
                inherit(parentA.maxhealth, parentB.maxhealth, 1, statMax, v)
            })
        end)

        if not ok or not insertId or insertId == 0 then
            print(('[rsg-stables] ERROR: collectFoal insert failed for citizenid %s: %s'):format(
                Player.PlayerData.citizenid, tostring(insertId)
            ))
            MySQL.update.await('UPDATE rsg_stables_breeding SET collected = 0 WHERE id = ?', { breedingId }) -- give the job back
            return false, locale('foal_collect_error')
        end

        return true
    end)
end)


-- ===================== HORSE INVENTORY =====================
-- Opens the rsg-inventory stash for the player's active (checked-out) horse.
RegisterNetEvent('rsg-stables:server:openHorseInventory', function(horseId, horseNetId)
    local src = source
    if not Config.HorseInventory or not Config.HorseInventory.enabled then return end
    horseId = toId(horseId)
    if not horseId then return end

    -- the player must actually be standing next to the horse entity (stops remote stash access)
    local horseEntity = tonumber(horseNetId) and NetworkGetEntityFromNetworkId(tonumber(horseNetId)) or 0
    local ped = GetPlayerPed(src)
    if not horseEntity or horseEntity == 0 or not DoesEntityExist(horseEntity) or ped == 0 then return end
    if #(GetEntityCoords(ped) - GetEntityCoords(horseEntity)) > (Config.HorseInventory.distance or 2.5) + 2.0 then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local row = MySQL.single.await('SELECT id, name FROM rsg_stables_horses WHERE id = ? AND citizenid = ? AND active = 1 LIMIT 1', {
        horseId, Player.PlayerData.citizenid
    })
    if not row then return end

    exports['rsg-inventory']:OpenInventory(src, 'horse_' .. row.id, {
        label = row.name or locale('your_horse'),
        maxweight = Config.HorseInventory.maxweight,
        slots = Config.HorseInventory.slots,
    })
end)


-- ===================== NATURAL DEATH (old age) =====================
CreateThread(function()
    while true do
        local cfg = Config.HorseAging
        Wait((cfg and cfg.checkInterval) or 600000)
        if cfg and cfg.enabled and (cfg.lifespanDays or 0) > 0 then
            local rows = MySQL.query.await('SELECT id, citizenid, name, active FROM rsg_stables_horses WHERE alive = 1 AND DATEDIFF(NOW(), created_at) >= ?', { cfg.lifespanDays }) or {}
            for _, r in ipairs(rows) do
                withLock('citizen:' .. r.citizenid, function()
                    MySQL.update.await('UPDATE rsg_stables_horses SET alive = 0, died_of_age = 1, insured = 0, active = 0, pos_x = NULL, pos_y = NULL, pos_z = NULL, pos_h = NULL WHERE id = ? AND alive = 1', { r.id })
                    -- cancel any breeding this horse was part of
                    MySQL.update.await('UPDATE rsg_stables_breeding SET collected = 1 WHERE (parent_a = ? OR parent_b = ?) AND collected = 0 AND ready_at > ?', { r.id, r.id, os.time() * 1000 })
                    if isTrue(r.active) then endSession(r.citizenid) end
                    local Player = RSGCore.Functions.GetPlayerByCitizenId(r.citizenid)
                    if Player then
                        TriggerClientEvent('rsg-stables:client:horseDiedOfAge', Player.PlayerData.source, r.id, r.name)
                    end
                end)
            end
        end
    end
end)
