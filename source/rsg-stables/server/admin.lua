-- rsg-stables: admin panel (server)
-- /horseadmin opens the NUI (client/admin.lua, html/admin.js). Every callback below re-checks the admin permission,
-- validates all input against Config and the database, and logs what was done. Helpers come from StablesAPI (server.lua).
local RSGCore = exports['rsg-core']:GetCoreObject()

local A = Config.Admin
if not (A and A.enabled) then return end
local API = StablesAPI

local isTrue, toId, withLock = API.isTrue, API.toId, API.withLock

local function registerCallback(name, fn)
    RSGCore.Functions.CreateCallback(name, function(source, cb, ...) cb(fn(source, ...)) end)
end

local function isAdmin(src)
    return src and src > 0 and RSGCore.Functions.HasPermission(src, A.permission or 'admin') == true
end

-- ===================== HELPERS =====================
local function decodeCharName(raw)
    local ci = raw
    if type(raw) == 'string' then
        local ok, parsed = pcall(json.decode, raw)
        ci = ok and parsed or nil
    end
    if type(ci) ~= 'table' then return nil end
    local name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or nil
end

local function cleanText(v, max)
    if type(v) ~= 'string' then return '' end
    v = v:gsub('%c', ''):gsub('^%s+', ''):gsub('%s+$', '')
    return v:sub(1, max or 50)
end

local function playerExists(citizenid)
    if type(citizenid) ~= 'string' or citizenid == '' or #citizenid > 50 then return false end
    return MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ? LIMIT 1', { citizenid }) ~= nil
end

local function playerName(citizenid)
    local P = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if P then return decodeCharName(P.PlayerData.charinfo) or citizenid, P.PlayerData.source end
    local raw = MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
    return decodeCharName(raw) or citizenid, nil
end

local function logAdmin(src, message)
    local P = RSGCore.Functions.GetPlayer(src)
    local who = P and ('%s [%s]'):format(GetPlayerName(src) or src, P.PlayerData.citizenid) or tostring(src)
    print(('[rsg-stables] ADMIN %s: %s'):format(who, message))
    TriggerEvent('rsg-log:server:CreateLog', 'rsgstables', 'Horse Admin', 'orange', ('%s: %s'):format(who, message))
end

local function notifyOwner(citizenid, key, ...)
    local P = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if P then
        TriggerClientEvent('RSGCore:Client:Notify', P.PlayerData.source, { description = locale(key, ...), type = 'inform', duration = 8000 })
    end
end

local function loadHorse(horseId)
    return MySQL.single.await('SELECT *, ' .. API.AGE_SQL .. ' FROM rsg_stables_horses WHERE id = ?', { horseId })
end

local function mapHorse(row)
    local now = os.time() * 1000
    return {
        id = row.id, name = row.name, breed = row.breed_label, model = tostring(row.model),
        gender = row.gender, stable = row.stable,
        alive = isTrue(row.alive), insured = isTrue(row.insured), active = isTrue(row.active),
        born = isTrue(row.born), diedOfAge = isTrue(row.died_of_age),
        health = math.floor((tonumber(row.health) or 0) + 0.5), stamina = math.floor((tonumber(row.stamina) or 0) + 0.5),
        hunger = math.floor((tonumber(row.hunger) or 0) + 0.5), thirst = math.floor((tonumber(row.thirst) or 0) + 0.5),
        bonding = math.floor((tonumber(row.bonding) or 0) + 0.5),
        speed = tonumber(row.speed) or 0, accel = tonumber(row.accel) or 0,
        handling = tonumber(row.handling) or 0, maxhealth = tonumber(row.maxhealth) or 0,
        ageDays = tonumber(row.age_days) or 0, stage = API.horseStage(row.age_days),
        breedCooldown = (tonumber(row.breed_cooldown) or 0) > now,
    }
end

local function cancelBreedingJobs(horseId)
    MySQL.update.await('UPDATE rsg_stables_breeding SET collected = 1 WHERE (parent_a = ? OR parent_b = ?) AND collected = 0', { horseId, horseId })
end

-- takes a horse that is out back to its stable (also when its owner is offline or the horse was left out)
local function forceStore(row)
    local hunger, thirst, bonding = row.hunger, row.thirst, row.bonding
    local session = API.activeSessions[row.citizenid]
    if session and session.horseId == row.id then
        API.applyDecay(session)
        hunger, thirst, bonding = session.hunger, session.thirst, session.bonding
    end
    MySQL.update.await('UPDATE rsg_stables_horses SET active = 0, pos_x = NULL, pos_y = NULL, pos_z = NULL, pos_h = NULL, hunger = ?, thirst = ?, bonding = ? WHERE id = ?',
        { hunger, thirst, bonding, row.id })
    if session and session.horseId == row.id then API.endSession(row.citizenid) end
    local P = RSGCore.Functions.GetPlayerByCitizenId(row.citizenid)
    if P then TriggerClientEvent('rsg-stables:client:adminStoreHorse', P.PlayerData.source) end
end

-- ===================== SEARCH =====================
registerCallback('rsg-stables:server:admin:search', function(source, query)
    if not isAdmin(source) then return nil, locale('adm_err_perm') end
    query = cleanText(query, 40)
    local needle = query:lower()
    local results, seen, ids = {}, {}, {}

    local function add(citizenid, name, online)
        if seen[citizenid] or #results >= 30 then return end
        seen[citizenid] = true
        ids[#ids + 1] = citizenid
        results[#results + 1] = { citizenid = citizenid, name = name or citizenid, online = online or false, horses = 0 }
    end

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local P = src and RSGCore.Functions.GetPlayer(src)
        if P then
            local name = decodeCharName(P.PlayerData.charinfo) or P.PlayerData.citizenid
            local cid = P.PlayerData.citizenid
            if needle == '' or name:lower():find(needle, 1, true) or cid:lower():find(needle, 1, true) or tostring(src) == needle then
                add(cid, name, src)
            end
        end
    end

    if needle ~= '' then
        local like = '%' .. query:gsub('[%%_\\]', '\\%0') .. '%'
        local rows = MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE citizenid LIKE ? OR charinfo LIKE ? LIMIT 30', { like, like }) or {}
        for _, r in ipairs(rows) do
            local name = decodeCharName(r.charinfo) or r.citizenid
            if r.citizenid:lower():find(needle, 1, true) or name:lower():find(needle, 1, true) then
                add(r.citizenid, name, false)
            end
        end
    end

    if #ids > 0 then
        local counts = MySQL.query.await('SELECT citizenid, COUNT(*) AS c FROM rsg_stables_horses WHERE citizenid IN (?) GROUP BY citizenid', { ids }) or {}
        local byId = {}
        for _, c in ipairs(counts) do byId[c.citizenid] = c.c end
        for _, r in ipairs(results) do r.horses = byId[r.citizenid] or 0 end
    end
    return true, results
end)

-- ===================== OPTIONS (stables + breeds for the forms) =====================
registerCallback('rsg-stables:server:admin:getOptions', function(source)
    if not isAdmin(source) then return nil, locale('adm_err_perm') end
    local stables, breeds = {}, {}
    for _, s in ipairs(Config.Stables) do stables[#stables + 1] = { value = s.name, label = s.label } end
    for _, b in ipairs(Config.Breeds) do
        breeds[#breeds + 1] = { value = tostring(math.floor(tonumber(b.model) or 0) & 0xFFFFFFFF), label = b.label }
    end
    local aging = Config.HorseAging or {}
    return true, { stables = stables, breeds = breeds, statMax = Config.BreedStatMax or 10, lifespanDays = aging.enabled and aging.lifespanDays or nil }
end)

-- ===================== A PLAYER'S HORSES =====================
registerCallback('rsg-stables:server:admin:getHorses', function(source, citizenid)
    if not isAdmin(source) then return nil, locale('adm_err_perm') end
    if not playerExists(citizenid) then return nil, locale('adm_err_player') end
    local rows = MySQL.query.await('SELECT *, ' .. API.AGE_SQL .. ' FROM rsg_stables_horses WHERE citizenid = ? ORDER BY active DESC, alive DESC, id', { citizenid }) or {}
    local horses = {}
    for _, r in ipairs(rows) do horses[#horses + 1] = mapHorse(r) end
    local name, online = playerName(citizenid)
    return true, { player = { citizenid = citizenid, name = name, online = online or false }, horses = horses }
end)

-- ===================== EDIT =====================
local FIELD_RANGES = { health = { 0, 100 }, stamina = { 0, 100 }, hunger = { 0, 100 }, thirst = { 0, 100 }, bonding = { 0, 100 }, handling = { 0, 100 } }

registerCallback('rsg-stables:server:admin:updateHorse', function(source, horseId, changes)
    if not isAdmin(source) then return false, locale('adm_err_perm') end
    horseId = toId(horseId)
    if not horseId or type(changes) ~= 'table' then return false, locale('adm_err_invalid') end
    local row = loadHorse(horseId)
    if not row then return false, locale('adm_err_horse') end

    return withLock('citizen:' .. row.citizenid, function()
        row = loadHorse(horseId)
        if not row then return false, locale('adm_err_horse') end
        if isTrue(row.active) then return false, locale('adm_err_out') end

        local sets, params, log = {}, {}, {}
        local function set(sql, value, label) sets[#sets + 1] = sql; params[#params + 1] = value; log[#log + 1] = ('%s=%s'):format(label, tostring(value)) end

        if changes.name ~= nil then
            local name = API.sanitizeName(changes.name)
            if not name then return false, locale('adm_err_invalid') end
            set('name = ?', name:sub(1, 40), 'name')
        end
        if changes.gender ~= nil then
            if changes.gender ~= 'male' and changes.gender ~= 'female' then return false, locale('adm_err_invalid') end
            set('gender = ?', changes.gender, 'gender')
        end
        if changes.stable ~= nil then
            if not API.getStableConfig(changes.stable) then return false, locale('adm_err_stable') end
            set('stable = ?', changes.stable, 'stable')
        end
        if changes.insured ~= nil then set('insured = ?', changes.insured and 1 or 0, 'insured') end
        if changes.born ~= nil then set('born = ?', changes.born and 1 or 0, 'born') end

        for key, range in pairs(FIELD_RANGES) do
            if changes[key] ~= nil then
                local v = tonumber(changes[key])
                if not v or v ~= v or v < range[1] or v > range[2] then return false, locale('adm_err_invalid') end
                set(key .. ' = ?', math.floor(v), key)
            end
        end
        for _, key in ipairs({ 'speed', 'accel', 'maxhealth' }) do
            if changes[key] ~= nil then
                local v = tonumber(changes[key])
                if not v or v ~= v or v < 1 or v > (Config.BreedStatMax or 10) then return false, locale('adm_err_invalid') end
                set(key .. ' = ?', math.floor(v), key)
            end
        end

        local newAge
        if changes.ageDays ~= nil then
            newAge = tonumber(changes.ageDays)
            if not newAge or newAge ~= newAge or newAge < 0 or newAge > 3650 then return false, locale('adm_err_invalid') end
            newAge = math.floor(newAge)
            local aging = Config.HorseAging
            if aging and aging.enabled and isTrue(row.alive) and (aging.lifespanDays or 0) > 0 and newAge >= aging.lifespanDays then
                return false, locale('adm_err_age', aging.lifespanDays)
            end
            set('created_at = DATE_SUB(NOW(), INTERVAL ? DAY)', newAge, 'ageDays')
        end

        if #sets == 0 then return false, locale('adm_err_invalid') end
        params[#params + 1] = horseId
        MySQL.update.await('UPDATE rsg_stables_horses SET ' .. table.concat(sets, ', ') .. ' WHERE id = ?', params)
        logAdmin(source, ('edited horse %d (%s) of %s: %s'):format(horseId, row.name, row.citizenid, table.concat(log, ', ')))
        return true, locale('adm_ok_saved')
    end)
end)

-- ===================== ACTIONS =====================
local ACTIONS = {}

ACTIONS.forceStore = function(src, row)
    if not isTrue(row.active) then return false, locale('adm_err_not_out') end
    forceStore(row)
    notifyOwner(row.citizenid, 'adm_n_stored', row.name)
    return true, locale('adm_ok_done')
end

ACTIONS.revive = function(src, row)
    if isTrue(row.alive) then return false, locale('adm_err_alive') end
    local aging = Config.HorseAging or {}
    if isTrue(row.died_of_age) then
        -- a horse that died of old age would be killed again by the next lifespan check: make it Old with time left
        local age = (aging.enabled and aging.oldFromDays) or 0
        MySQL.update.await('UPDATE rsg_stables_horses SET alive = 1, died_of_age = 0, health = 100, stamina = 100, hunger = 100, thirst = 100, created_at = DATE_SUB(NOW(), INTERVAL ? DAY) WHERE id = ?', { age, row.id })
    else
        MySQL.update.await('UPDATE rsg_stables_horses SET alive = 1, health = 100, stamina = 100, hunger = 100, thirst = 100 WHERE id = ?', { row.id })
    end
    notifyOwner(row.citizenid, 'adm_n_revived', row.name)
    return true, locale('adm_ok_done')
end

ACTIONS.resetShoes = function(src, row)
    MySQL.update.await('UPDATE rsg_stables_horses SET shoe_wear = 0 WHERE id = ?', { row.id })
    return true, locale('adm_ok_done')
end

ACTIONS.resetCoat = function(src, row)
    MySQL.update.await('UPDATE rsg_stables_horses SET coat = NULL WHERE id = ?', { row.id })
    return true, locale('adm_ok_done')
end

ACTIONS.resetTack = function(src, row)
    MySQL.update.await('UPDATE rsg_stables_horses SET tack = ? WHERE id = ?', { API.newHorseTack(), row.id })
    return true, locale('adm_ok_done')
end

ACTIONS.resetTraining = function(src, row)
    MySQL.update.await('UPDATE rsg_stables_horses SET training = NULL WHERE id = ?', { row.id })
    return true, locale('adm_ok_done')
end

ACTIONS.clearCooldown = function(src, row)
    MySQL.update.await('UPDATE rsg_stables_horses SET breed_cooldown = 0 WHERE id = ?', { row.id })
    return true, locale('adm_ok_done')
end

ACTIONS.openSaddlebags = function(src, row)
    exports['rsg-inventory']:OpenInventory(src, 'horse_' .. row.id, {
        label = row.name or locale('your_horse'),
        maxweight = Config.HorseInventory.maxweight,
        slots = Config.HorseInventory.slots,
    })
    return true, locale('adm_ok_done')
end

ACTIONS.delete = function(src, row)
    if isTrue(row.active) then forceStore(row) end
    cancelBreedingJobs(row.id)
    MySQL.update.await('DELETE FROM rsg_stables_horses WHERE id = ?', { row.id })
    API.deleteSaddlebags(row.id)
    notifyOwner(row.citizenid, 'adm_n_deleted', row.name)
    return true, locale('adm_ok_deleted')
end

-- actions that don't need the horse to be in the stable
local WORKS_WHILE_OUT = { forceStore = true, openSaddlebags = true, delete = true }

registerCallback('rsg-stables:server:admin:action', function(source, horseId, action)
    if not isAdmin(source) then return false, locale('adm_err_perm') end
    horseId = toId(horseId)
    local handler = type(action) == 'string' and ACTIONS[action]
    if not horseId or not handler then return false, locale('adm_err_invalid') end
    local row = loadHorse(horseId)
    if not row then return false, locale('adm_err_horse') end

    return withLock('citizen:' .. row.citizenid, function()
        row = loadHorse(horseId)
        if not row then return false, locale('adm_err_horse') end
        if isTrue(row.active) and not WORKS_WHILE_OUT[action] then return false, locale('adm_err_out') end
        local ok, msg = handler(source, row)
        if ok then logAdmin(source, ('%s on horse %d (%s) of %s'):format(action, row.id, row.name, row.citizenid)) end
        return ok, msg
    end)
end)

-- ===================== GIVE =====================
registerCallback('rsg-stables:server:admin:giveHorse', function(source, citizenid, model, name, gender, stable, ageDays, foal)
    if not isAdmin(source) then return false, locale('adm_err_perm') end
    if not playerExists(citizenid) then return false, locale('adm_err_player') end
    local breed = API.getBreedConfig(tonumber(model))
    if not breed then return false, locale('adm_err_breed') end
    if not API.getStableConfig(stable) then return false, locale('adm_err_stable') end
    if gender ~= 'male' and gender ~= 'female' then gender = API.randomGender() end
    local age = math.floor(tonumber(ageDays) or 0)
    if age < 0 or age > 3650 then return false, locale('adm_err_invalid') end
    local aging = Config.HorseAging
    if aging and aging.enabled and (aging.lifespanDays or 0) > 0 and age >= aging.lifespanDays then
        return false, locale('adm_err_age', aging.lifespanDays)
    end
    local safeName = (API.sanitizeName(name) or locale('unnamed_horse')):sub(1, 40)

    return withLock('citizen:' .. citizenid, function()
        local ok, id = pcall(MySQL.insert.await, [[
            INSERT INTO rsg_stables_horses
                (citizenid, stable, model, breed_label, gender, name, outfit, tack, health, stamina, speed, accel, handling, maxhealth, alive, insured, active, born, created_at)
            VALUES (?, ?, ?, ?, ?, ?, 0, ?, 100, 100, ?, ?, ?, ?, 1, 0, 0, ?, DATE_SUB(NOW(), INTERVAL ? DAY))
        ]], {
            citizenid, stable, breed.model, breed.label, gender, safeName, API.newHorseTack(),
            breed.speed, breed.acceleration, API.breedHandlingValue(breed), breed.health, foal and 1 or 0, age,
        })
        if not ok or not id or id == 0 then return false, locale('generic_error') end
        logAdmin(source, ('gave %s (%s, %s) id %d to %s at %s'):format(safeName, breed.label, gender, id, citizenid, stable))
        notifyOwner(citizenid, 'adm_n_given', safeName)
        return true, locale('adm_ok_given')
    end)
end)

-- ===================== TRANSFER =====================
registerCallback('rsg-stables:server:admin:transferHorse', function(source, horseId, targetCitizenid)
    if not isAdmin(source) then return false, locale('adm_err_perm') end
    horseId = toId(horseId)
    if not horseId then return false, locale('adm_err_invalid') end
    targetCitizenid = cleanText(targetCitizenid, 50)
    if not playerExists(targetCitizenid) then return false, locale('adm_err_target') end
    local row = loadHorse(horseId)
    if not row then return false, locale('adm_err_horse') end
    if row.citizenid == targetCitizenid then return false, locale('adm_err_same') end

    -- lock both owners in a fixed order so two admins can't deadlock each other
    local first, second = row.citizenid, targetCitizenid
    if first > second then first, second = second, first end
    return withLock('citizen:' .. first, function()
        return withLock('citizen:' .. second, function()
            row = loadHorse(horseId)
            if not row then return false, locale('adm_err_horse') end
            if isTrue(row.active) then return false, locale('adm_err_out') end
            local oldOwner = row.citizenid
            MySQL.update.await('UPDATE rsg_stables_horses SET citizenid = ? WHERE id = ?', { targetCitizenid, horseId })
            cancelBreedingJobs(horseId)
            logAdmin(source, ('transferred horse %d (%s) from %s to %s'):format(horseId, row.name, oldOwner, targetCitizenid))
            notifyOwner(oldOwner, 'adm_n_transferred_away', row.name)
            notifyOwner(targetCitizenid, 'adm_n_transferred_to', row.name)
            return true, locale('adm_ok_transferred')
        end)
    end)
end)

-- ===================== COMMAND =====================
RSGCore.Commands.Add(A.command or 'horseadmin', locale('adm_cmd_help'), {}, false, function(source)
    if isAdmin(source) then TriggerClientEvent('rsg-stables:client:openAdmin', source) end
end, A.permission or 'admin')
