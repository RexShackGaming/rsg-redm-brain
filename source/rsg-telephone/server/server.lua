local RSGCore = exports['rsg-core']:GetCoreObject()

local Phones      = {} -- [id] = { id, number, label, model, coords, heading, room, listed, job, owner }
local Calls       = {} -- [callId] = { caller, answerer, fromPhone, toPhone, state, started, deposit, spent, payer, paidUntil }
local PlayerCall  = {} -- [src] = callId
local PhoneCall   = {} -- [phoneId] = callId
local Cooldown    = {} -- [src] = os.time of last dial attempt
local Stored      = {} -- [id] = picked-up player phones (number stays reserved)
local PendingPlace = {} -- [src] = { slot, storedId, t } issued when the telephone item is used
local nextCallId  = 0

----------------------------------------------------------------
-- helpers
----------------------------------------------------------------
local function notify(src, msg, nType)
    if not src or src == 0 or not msg then return end
    RSGCore.Functions.Notify(src, { title = locale('title'), description = msg, type = nType or 'inform' })
end

-- same check as the commands, so a callback can't be reached by anyone the command rejects
local function isAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.AdminPermission)
end

local function isFinite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function nearPhone(src, phone, dist)
    if not phone or not phone.coords then return false end
    local pos = playerCoords(src)
    if not pos then return false end
    return #(pos - phone.coords) <= (dist or Config.MaxCallDistance)
end

local function nearestPhone(src, maxDist)
    local pos = playerCoords(src)
    if not pos then return end
    local best, bestDist
    for _, p in pairs(Phones) do
        local d = #(pos - p.coords)
        if d <= (maxDist or 3.0) and (not bestDist or d < bestDist) then
            best, bestDist = p, d
        end
    end
    return best
end

local function phoneByNumber(number)
    for _, p in pairs(Phones) do
        if p.number == number then return p end
    end
end

-- includes picked-up phones so nobody can take a stored phone's number
local function numberTaken(number, exceptId)
    local p = phoneByNumber(number)
    if p and p.id ~= exceptId then return true end
    for id, s in pairs(Stored) do
        if s.number == number and id ~= exceptId then return true end
    end
    return false
end

local function generateNumber()
    local length = Config.NumberLength
    for _ = 1, 500 do
        local digits = { tostring(math.random(1, 9)) }
        for i = 2, length do digits[i] = tostring(math.random(0, 9)) end
        local number = table.concat(digits)
        if not numberTaken(number) then return number end
    end
end

local function cleanLabel(value)
    local label = type(value) == 'string' and value:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '') or ''
    if label == '' then return nil end
    return label:sub(1, 64)
end

-- job restriction: '' / nil = anyone. Matches a job name or a job type (e.g. medic, leo).
local function cleanJob(job)
    job = type(job) == 'string' and job:lower():gsub('[^%w_]', ''):sub(1, 64) or ''
    return job ~= '' and job or nil
end

-- Every job the character holds, plus each job definition's type (rsg-core multijob)
local function jobKeys(citizenid)
    local keys, seen = {}, {}
    local function add(key)
        if type(key) ~= 'string' then return end
        key = key:lower()
        if key ~= '' and not seen[key] then
            seen[key] = true
            keys[#keys + 1] = key
        end
    end

    local jobs = RSGCore.Functions.GetPlayerJobs(citizenid) or {}
    for _, entry in ipairs(jobs) do
        local name = entry.job or entry.name
        add(name)
        if name then
            local def = RSGCore.Functions.GetJobDefinition(name)
            if def and def.type then add(def.type) end
        end
    end

    local Player = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    local primary = Player and Player.PlayerData.job
    if primary then
        add(primary.name)
        add(primary.type)
    end
    return keys
end

local function canUsePhone(src, phone)
    if not phone.job then return true end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    for _, key in ipairs(jobKeys(Player.PlayerData.citizenid)) do
        if key == phone.job then return true end
    end
    return false
end

local function publicPhone(p)
    return {
        id = p.id, number = p.number, label = p.label, model = p.model,
        x = p.coords.x, y = p.coords.y, z = p.coords.z,
        heading = p.heading, room = p.room or 0,
        job = p.job, owner = p.owner, listed = p.listed,
    }
end

local function phoneList()
    local list = {}
    for _, p in pairs(Phones) do list[#list + 1] = publicPhone(p) end
    return list
end

local function ownerOf(src, p)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and p and p.owner and p.owner == Player.PlayerData.citizenid and Player or nil
end

----------------------------------------------------------------
-- payphone money (all amounts handled in whole cents)
----------------------------------------------------------------
local PP = Config.Payphone
local function cents(d)
    local n = tonumber(d)
    if not isFinite(n) then return nil end
    return math.floor(n * 100 + 0.5)
end
local function dollars(c) return ('%.2f'):format(c / 100) end
local COST = cents(PP.CostPerMinute) or 0
local MAX_DEPOSIT = cents(PP.MaxDeposit) or 0

local function isPayphone(phone)
    return PP.Enabled and COST > 0 and phone and not phone.job and (not phone.owner or Config.Item.Payphone)
end

-- refund to an online player, or straight into the database if they've already left
local function refund(src, citizenid, amount)
    if amount <= 0 or not citizenid then return end
    local Player = src and RSGCore.Functions.GetPlayer(src)
    if not (Player and Player.PlayerData.citizenid == citizenid) then
        -- same character may be online under a new source (reconnect); never write the DB while they're loaded
        Player = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
        src = Player and Player.PlayerData.source
    end
    if Player then
        Player.Functions.AddMoney(PP.MoneyType, amount / 100, 'payphone-refund')
        notify(src, locale('pay_refund', dollars(amount)), 'success')
    else
        MySQL.update(('UPDATE players SET money = JSON_SET(money, "$.%s", ROUND(COALESCE(JSON_EXTRACT(COALESCE(money, JSON_OBJECT()), "$.%s"), 0) + ?, 2)) WHERE citizenid = ?')
            :format(PP.MoneyType, PP.MoneyType), { amount / 100, citizenid })
    end
end

local function sendCredit(call)
    TriggerClientEvent('rsg-telephone:client:credit', call.caller, call.deposit - call.spent, COST)
end

----------------------------------------------------------------
-- call lifecycle
----------------------------------------------------------------
local function endCall(callId, reasonKey)
    local call = Calls[callId]
    if not call then return end
    Calls[callId] = nil

    if call.deposit then refund(call.caller, call.payer, call.deposit - call.spent) end

    local msg = locale(reasonKey or 'call_ended')
    for _, src in ipairs({ call.caller, call.answerer }) do
        if src then
            PlayerCall[src] = nil
            TriggerClientEvent('rsg-telephone:client:callEnded', src, msg)
            if reasonKey then notify(src, msg, 'inform') end -- plain hang-ups are already shown on the phone
        end
    end
    PhoneCall[call.fromPhone] = nil
    PhoneCall[call.toPhone] = nil
    TriggerClientEvent('rsg-telephone:client:setRinging', -1, call.toPhone, false)
end

----------------------------------------------------------------
-- database / load
----------------------------------------------------------------
CreateThread(function()
    if Config.AutoDatabase then
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `rsg_telephones` (
                `id` INT NOT NULL AUTO_INCREMENT,
                `number` VARCHAR(16) NOT NULL,
                `label` VARCHAR(64) NOT NULL DEFAULT 'Telephone',
                `model` VARCHAR(64) NOT NULL,
                `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
                `heading` DOUBLE NOT NULL DEFAULT 0,
                `listed` TINYINT(1) NOT NULL DEFAULT 1,
                `room` BIGINT NOT NULL DEFAULT 0,
                `job` VARCHAR(64) DEFAULT NULL,
                `owner` VARCHAR(64) DEFAULT NULL,
                `stored` TINYINT(1) NOT NULL DEFAULT 0,
                `created_by` VARCHAR(64) DEFAULT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`), UNIQUE KEY `number` (`number`)
            )
        ]])

        -- upgrade older tables (information_schema check: MySQL has no "ADD COLUMN IF NOT EXISTS", only MariaDB does)
        local function ensureColumn(name, def)
            local n = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rsg_telephones' AND COLUMN_NAME = ?]], { name })
            if tonumber(n) == 0 then
                MySQL.query.await(('ALTER TABLE rsg_telephones ADD COLUMN `%s` %s'):format(name, def))
            end
        end
        ensureColumn('room', 'BIGINT NOT NULL DEFAULT 0')
        ensureColumn('job', 'VARCHAR(64) DEFAULT NULL')
        ensureColumn('owner', 'VARCHAR(64) DEFAULT NULL')
        ensureColumn('stored', 'TINYINT(1) NOT NULL DEFAULT 0')
        ensureColumn('created_by', 'VARCHAR(64) DEFAULT NULL')
        ensureColumn('created_at', 'TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP')
    end

    local rows = MySQL.query.await('SELECT * FROM rsg_telephones')
    if not rows then
        return print(('[rsg-telephone] ^1%s^7'):format(locale('db_error')))
    end

    local loaded = 0
    for _, r in ipairs(rows) do
        local x, y, z = tonumber(r.x), tonumber(r.y), tonumber(r.z)
        if r.id and r.number and r.model and isFinite(x) and isFinite(y) and isFinite(z) then
            local p = {
                id = r.id, number = tostring(r.number), label = cleanLabel(r.label) or locale('default_label'), model = r.model,
                coords = vector3(x, y, z), heading = (tonumber(r.heading) or 0.0) % 360.0,
                room = math.tointeger(tonumber(r.room) or 0) or 0,
                listed = tonumber(r.listed) == 1, job = cleanJob(r.job),
                owner = r.owner,
            }
            if tonumber(r.stored) == 1 then Stored[r.id] = p else Phones[r.id] = p end
            loaded = loaded + 1
        else
            print(('[rsg-telephone] ^3skipped invalid row id %s^7'):format(tostring(r.id)))
        end
    end
    print(('[rsg-telephone] loaded %d telephones'):format(loaded))
    TriggerClientEvent('rsg-telephone:client:syncPhones', -1, phoneList())
end)

----------------------------------------------------------------
-- phone callbacks
----------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-telephone:server:getPhones', function(_, cb)
    local ringing = {}
    for phoneId, callId in pairs(PhoneCall) do
        local call = Calls[callId]
        if call and call.state == 'ringing' and call.toPhone == phoneId then ringing[#ringing + 1] = phoneId end
    end
    cb(phoneList(), ringing)
end)

RSGCore.Functions.CreateCallback('rsg-telephone:server:myJobs', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    cb(jobKeys(Player.PlayerData.citizenid))
end)

-- players get listed phones; admins also get hidden ones so they can toggle them
local function buildDirectory(admin)
    local dir = {}
    for _, p in pairs(Phones) do
        if p.listed or admin then
            dir[#dir + 1] = { id = p.id, label = p.label, number = p.number, listed = p.listed }
        end
    end
    table.sort(dir, function(a, b) return a.label:lower() < b.label:lower() end)
    return dir
end

RSGCore.Functions.CreateCallback('rsg-telephone:server:getDirectory', function(src, cb)
    local admin = isAdmin(src)
    cb({ entries = buildDirectory(admin), admin = admin })
end)

RSGCore.Functions.CreateCallback('rsg-telephone:server:setListed', function(src, cb, id, listed)
    if not isAdmin(src) then return cb(false, locale('no_permission')) end
    local p = Phones[tonumber(id)]
    if not p or type(listed) ~= 'boolean' then return cb(false) end
    local updated = MySQL.update.await('UPDATE rsg_telephones SET listed = ? WHERE id = ?', { listed and 1 or 0, p.id })
    if updated == nil or updated == 0 then return cb(false, locale('db_error')) end
    p.listed = listed
    cb(true, buildDirectory(true))
end)

----------------------------------------------------------------
-- admin: create / remove
----------------------------------------------------------------
local validModel = {}
for _, m in ipairs(Config.Models) do validModel[m.value] = true end

-- only placed phones count: a picked-up phone's item can be sold, lost or dropped,
-- and must not block its old owner from ever placing another phone
local function ownedCount(cid)
    local n = 0
    for _, p in pairs(Phones) do
        if p.owner == cid then n = n + 1 end
    end
    return n
end

-- the item must still be in the slot it was used from (and still carry the same stored phone)
local function pendingItem(src)
    local pend = PendingPlace[src]
    if not pend or os.time() - pend.t > 300 then
        PendingPlace[src] = nil
        return
    end
    local item = exports['rsg-inventory']:GetItemBySlot(src, pend.slot)
    if not item or item.name ~= Config.Item.Name then return end
    local storedId = item.info and tonumber(item.info.phone_id) or nil
    if pend.storedId ~= storedId then return end
    return pend
end

-- Validate a placement result from the client with rsg-gizmo. Returns coords, rotation, room or nil.
local function validatePlacement(src, data, maxDistance)
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if not (isFinite(x) and isFinite(y) and isFinite(z)) then return end
    local coords = vector3(x, y, z)
    local ok = exports['rsg-gizmo']:IsPlacementValid(src, coords, maxDistance or Config.PlaceDistance)
    if not ok then return end

    local rotInput = data.rotation
    if type(rotInput) ~= 'vector3' then
        rotInput = vector3(0.0, 0.0, tonumber(data.heading) or 0.0)
    end
    local rotation = exports['rsg-gizmo']:SanitiseRotation(rotInput)
    local room = math.tointeger(tonumber(data.room) or 0) or 0
    return coords, rotation, room
end

local function createAdminPhone(src, data)
    if not isAdmin(src) then return false, locale('no_permission') end
    if not validModel[data.model] then return false end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end

    local coords, rotation, room = validatePlacement(src, data, Config.PlaceDistance)
    if not coords then return false, locale('not_near') end

    local number = tostring(data.number or ''):gsub('%D', '')
    if number == '' then
        number = generateNumber()
        if not number then return false, locale('db_error') end
    elseif not number:match('^%d%d+$') or #number > 16 then
        return false, locale('number_invalid')
    elseif numberTaken(number) then
        return false, locale('number_taken')
    end

    local label = cleanLabel(data.label) or locale('default_label')
    local job = cleanJob(data.job)
    local listed = data.listed == true
    local cid = Player.PlayerData.citizenid

    local id = MySQL.insert.await(
        'INSERT INTO rsg_telephones (number, label, model, x, y, z, heading, listed, created_by, room, job) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { number, label, data.model, coords.x, coords.y, coords.z, rotation.z, listed and 1 or 0, cid, room, job })
    if not id then return false, locale('db_error') end

    local p = {
        id = id, number = number, label = label, model = data.model, coords = coords,
        heading = rotation.z, room = room, listed = listed, job = job,
    }
    Phones[id] = p
    TriggerClientEvent('rsg-telephone:client:addPhone', -1, publicPhone(p))
    return true, number
end

local function removePhone(id)
    local p = Phones[id]
    if not p then return false, locale('db_error') end
    -- delete first: a failed delete must leave the live phone (and its call) untouched
    local deleted = MySQL.query.await('DELETE FROM rsg_telephones WHERE id = ?', { id })
    if deleted == nil then return false, locale('db_error') end
    local callId = PhoneCall[id]
    if callId then endCall(callId) end
    Phones[id] = nil
    TriggerClientEvent('rsg-telephone:client:removePhone', -1, id)
    return p
end

----------------------------------------------------------------
-- player-owned telephones (usable item)
----------------------------------------------------------------
if Config.Item.Enabled then
    RSGCore.Functions.CreateUseableItem(Config.Item.Name, function(source, item)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player or not item or not item.slot then return end
        if PlayerCall[src] then return notify(src, locale('already_in_call'), 'error') end

        local pending = PendingPlace[src]
        if pending and os.time() - pending.t <= 300 then return end -- already placing one

        local storedId = item.info and tonumber(item.info.phone_id) or nil
        local stored = storedId and Stored[storedId] or nil
        if storedId and not stored then storedId = nil end -- stale item: treat as a new phone
        if ownedCount(Player.PlayerData.citizenid) >= Config.Item.MaxPerPlayer then
            return notify(src, locale('item_max', Config.Item.MaxPerPlayer), 'error')
        end

        PendingPlace[src] = { slot = item.slot, storedId = storedId, t = os.time() }
        TriggerClientEvent('rsg-telephone:client:startPlacement', src, {
            item = true,
            preset = stored and { label = stored.label, model = stored.model, number = stored.number } or nil,
        })
    end)
end

RegisterNetEvent('rsg-telephone:server:cancelPlace', function()
    PendingPlace[source] = nil
end)

local function placeItem(src, data)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Config.Item.Enabled then return false end
    local pending = pendingItem(src)
    if not pending then
        PendingPlace[src] = nil
        return false, locale('item_missing')
    end

    local coords, rotation, room = validatePlacement(src, data, Config.PlaceDistance)
    if not coords then
        PendingPlace[src] = nil
        return false, locale('not_near')
    end

    local cid = Player.PlayerData.citizenid
    local stored = pending.storedId and Stored[pending.storedId]
    if ownedCount(cid) >= Config.Item.MaxPerPlayer then -- re-check: limit may have been hit since the item was used
        PendingPlace[src] = nil
        return false, locale('item_max', Config.Item.MaxPerPlayer)
    end
    if not stored and not validModel[data.model] then
        PendingPlace[src] = nil
        return false
    end

    -- take the item first; if anything after fails it is given back
    local removed = exports['rsg-inventory']:RemoveItem(src, Config.Item.Name, 1, pending.slot, 'telephone-placed')
    if not removed then return false, locale('item_missing') end
    PendingPlace[src] = nil

    local p
    if stored then
        -- re-placing a picked-up phone: keeps its number, label, prop and listing
        local updated = MySQL.update.await(
            'UPDATE rsg_telephones SET x = ?, y = ?, z = ?, heading = ?, room = ?, owner = ?, stored = 0 WHERE id = ?',
            { coords.x, coords.y, coords.z, rotation.z, room, cid, stored.id })
        if updated == nil or updated == 0 then
            exports['rsg-inventory']:AddItem(src, Config.Item.Name, 1,
                { phone_id = stored.id, number = stored.number, label = stored.label }, nil, 'telephone-refund')
            return false, locale('db_error')
        end
        Stored[stored.id] = nil
        p = stored
        p.coords, p.heading, p.room, p.owner = coords, rotation.z, room, cid
    else
        local label = cleanLabel(data.label) or locale('default_label')
        local number = generateNumber()
        if not number then
            exports['rsg-inventory']:AddItem(src, Config.Item.Name, 1, nil, nil, 'telephone-refund')
            return false, locale('db_error')
        end
        local id = MySQL.insert.await(
            'INSERT INTO rsg_telephones (number, label, model, x, y, z, heading, listed, created_by, room, owner) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { number, label, data.model, coords.x, coords.y, coords.z, rotation.z, data.listed == true and 1 or 0, cid, room, cid })
        if not id then
            exports['rsg-inventory']:AddItem(src, Config.Item.Name, 1, nil, nil, 'telephone-refund')
            return false, locale('db_error')
        end
        p = {
            id = id, number = number, label = label, model = data.model, coords = coords,
            heading = rotation.z, room = room, listed = data.listed == true, owner = cid,
        }
    end

    Phones[p.id] = p
    TriggerClientEvent('rsg-telephone:client:addPhone', -1, publicPhone(p))
    return true, p.number
end

RSGCore.Functions.CreateCallback('rsg-telephone:server:createPhone', function(src, cb, data)
    if type(data) ~= 'table' then return cb(false) end
    if data.item == true then
        local ok, res = placeItem(src, data)
        return cb(ok, res)
    end
    local ok, res = createAdminPhone(src, data)
    cb(ok, res)
end)

-- owner picks the phone up: it leaves the world, its settings stay in the DB, the item comes back
RSGCore.Functions.CreateCallback('rsg-telephone:server:pickupPhone', function(src, cb, id)
    local p = Phones[tonumber(id)]
    local Player = ownerOf(src, p)
    if not Player then return cb(false, locale('not_owner')) end
    if not nearPhone(src, p, Config.MaxCallDistance + 1.0) then return cb(false, locale('not_near')) end
    if PhoneCall[p.id] then return cb(false, locale('phone_busy')) end
    if not exports['rsg-inventory']:CanAddItem(src, Config.Item.Name, 1) then return cb(false, locale('item_full')) end

    local updated = MySQL.update.await('UPDATE rsg_telephones SET stored = 1 WHERE id = ?', { p.id })
    if updated == nil or updated == 0 then return cb(false, locale('db_error')) end

    -- the phone may have been removed or a call may have started while the DB updated
    if Phones[p.id] ~= p then return cb(false, locale('db_error')) end
    if PhoneCall[p.id] then
        MySQL.update.await('UPDATE rsg_telephones SET stored = 0 WHERE id = ?', { p.id })
        return cb(false, locale('phone_busy'))
    end

    Phones[p.id] = nil
    Stored[p.id] = p
    TriggerClientEvent('rsg-telephone:client:removePhone', -1, p.id)

    local ok = exports['rsg-inventory']:AddItem(src, Config.Item.Name, 1,
        { phone_id = p.id, number = p.number, label = p.label }, nil, 'telephone-pickup')
    if not ok then -- put it back exactly as it was
        MySQL.update.await('UPDATE rsg_telephones SET stored = 0 WHERE id = ?', { p.id })
        Stored[p.id] = nil
        Phones[p.id] = p
        TriggerClientEvent('rsg-telephone:client:addPhone', -1, publicPhone(p))
        return cb(false, locale('item_full'))
    end
    cb(true)
end)

-- owner settings (label + directory listing)
RSGCore.Functions.CreateCallback('rsg-telephone:server:ownerUpdate', function(src, cb, id, data)
    local p = Phones[tonumber(id)]
    if not ownerOf(src, p) then return cb(false, locale('not_owner')) end
    if not nearPhone(src, p, Config.MaxCallDistance + 1.0) or type(data) ~= 'table' then
        return cb(false, locale('not_near'))
    end
    local label = cleanLabel(data.label)
    if not label then return cb(false, locale('form_label_required')) end
    local listed = data.listed == true

    local updated = MySQL.update.await('UPDATE rsg_telephones SET label = ?, listed = ? WHERE id = ?', { label, listed and 1 or 0, p.id })
    if updated == nil or updated == 0 then return cb(false, locale('db_error')) end
    p.label, p.listed = label, listed
    TriggerClientEvent('rsg-telephone:client:updatePhone', -1, publicPhone(p))
    cb(true)
end)

----------------------------------------------------------------
-- admin panel (/phoneadmin) - every callback re-checks permission
----------------------------------------------------------------
local function adminRow(p)
    local callId = PhoneCall[p.id]
    local call = callId and Calls[callId]
    local status = 'idle'
    if call then status = (call.state == 'ringing' and call.toPhone == p.id) and 'ringing' or 'call' end
    return {
        id = p.id, number = p.number, label = p.label, model = p.model, job = p.job or '', listed = p.listed,
        payphone = isPayphone(p) and true or false, status = status, owned = p.owner ~= nil,
        x = p.coords.x, y = p.coords.y, z = p.coords.z,
    }
end

local function adminList()
    local rows, calls = {}, 0
    for _, p in pairs(Phones) do rows[#rows + 1] = adminRow(p) end
    -- picked-up player phones: listed so admins can free up their numbers
    for _, p in pairs(Stored) do
        local r = adminRow(p)
        r.status = 'stored'
        rows[#rows + 1] = r
    end
    for _ in pairs(Calls) do calls = calls + 1 end
    table.sort(rows, function(a, b) return a.label:lower() < b.label:lower() end)
    return { phones = rows, calls = calls, models = Config.Models }
end

RSGCore.Functions.CreateCallback('rsg-telephone:server:adminList', function(src, cb)
    if not isAdmin(src) then return cb(false) end
    cb(adminList())
end)

RSGCore.Functions.CreateCallback('rsg-telephone:server:adminUpdate', function(src, cb, id, data)
    if not isAdmin(src) then return cb(false, locale('no_permission')) end
    local p = Phones[tonumber(id)]
    if not p or type(data) ~= 'table' then return cb(false) end

    local label = cleanLabel(data.label)
    if not label then return cb(false, locale('form_label_required')) end
    local number = tostring(data.number or ''):gsub('%D', '')
    if not number:match('^%d%d+$') or #number > 16 then return cb(false, locale('number_invalid')) end
    if numberTaken(number, p.id) then return cb(false, locale('number_taken')) end
    if not validModel[data.model] then return cb(false) end
    local job, listed = cleanJob(data.job), data.listed == true

    -- a changed number would strand a live call, so end it first
    if number ~= p.number and PhoneCall[p.id] then endCall(PhoneCall[p.id]) end

    local updated = MySQL.update.await(
        'UPDATE rsg_telephones SET label = ?, number = ?, model = ?, job = ?, listed = ? WHERE id = ?',
        { label, number, data.model, job, listed and 1 or 0, p.id })
    if updated == nil or updated == 0 then return cb(false, locale('db_error')) end

    p.label, p.number, p.model, p.job, p.listed = label, number, data.model, job, listed
    TriggerClientEvent('rsg-telephone:client:updatePhone', -1, publicPhone(p))
    cb(true, adminList())
end)

RSGCore.Functions.CreateCallback('rsg-telephone:server:adminDelete', function(src, cb, id)
    if not isAdmin(src) then return cb(false, locale('no_permission')) end
    id = tonumber(id)
    if Stored[id] then
        local deleted = MySQL.query.await('DELETE FROM rsg_telephones WHERE id = ?', { id })
        if deleted == nil then return cb(false, locale('db_error')) end
        Stored[id] = nil
        return cb(true, adminList())
    end
    if not removePhone(id) then return cb(false, locale('db_error')) end
    cb(true, adminList())
end)

RSGCore.Functions.CreateCallback('rsg-telephone:server:adminEndCall', function(src, cb, id)
    if not isAdmin(src) then return cb(false, locale('no_permission')) end
    local callId = PhoneCall[tonumber(id)]
    if not callId then return cb(false) end
    endCall(callId, 'admin_ended')
    cb(true, adminList())
end)

----------------------------------------------------------------
-- commands
----------------------------------------------------------------
RSGCore.Commands.Add('phoneadmin', locale('cmd_phoneadmin'), {}, false, function(source)
    if source == 0 then return end
    TriggerClientEvent('rsg-telephone:client:openAdmin', source)
end, Config.AdminPermission)

RSGCore.Commands.Add('addphone', locale('cmd_addphone'), {}, false, function(source)
    if source == 0 then return end
    TriggerClientEvent('rsg-telephone:client:startPlacement', source)
end, Config.AdminPermission)

RSGCore.Commands.Add('removephone', locale('cmd_removephone'), {}, false, function(source)
    if source == 0 then return end
    local near = nearestPhone(source, Config.UseDistance + 1.0)
    if not near then return notify(source, locale('no_phone_near'), 'error') end
    local p, err = removePhone(near.id)
    if p then notify(source, locale('removed', p.number), 'success')
    else notify(source, err or locale('db_error'), 'error') end
end, Config.AdminPermission)

RSGCore.Commands.Add('phonejob', locale('cmd_phonejob'), {
    { name = 'job', help = locale('cmd_phonejob_arg') },
}, false, function(source, args)
    if source == 0 then return end
    local p = nearestPhone(source, Config.UseDistance + 1.0)
    if not p then return notify(source, locale('no_phone_near'), 'error') end
    local job = cleanJob(args[1])
    local updated = MySQL.update.await('UPDATE rsg_telephones SET job = ? WHERE id = ?', { job, p.id })
    if updated == nil then return notify(source, locale('db_error'), 'error') end
    p.job = job
    TriggerClientEvent('rsg-telephone:client:updatePhone', -1, publicPhone(p))
    notify(source, job and locale('job_set', p.number, job) or locale('job_cleared', p.number), 'success')
end, Config.AdminPermission)

RSGCore.Commands.Add('phoneinfo', locale('cmd_phoneinfo'), {}, false, function(source)
    if source == 0 then return end
    local p = nearestPhone(source, Config.UseDistance + 1.0)
    if not p then return notify(source, locale('no_phone_near'), 'error') end
    local info = locale('phone_info', p.id, p.number, p.label)
    if p.job then
        info = info .. ' · ' .. locale('job_only', p.job)
    elseif isPayphone(p) then
        info = info .. ' · ' .. locale('payphone')
    end
    notify(source, info, 'inform')
end, Config.AdminPermission)

----------------------------------------------------------------
-- calling
----------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-telephone:server:startCall', function(src, cb, phoneId, number, deposit)
    phoneId = tonumber(phoneId)
    number = type(number) == 'string' and number:gsub('%D', '') or ''
    local from = Phones[phoneId]
    if not from or #number < 2 or #number > 16 then return cb(false, locale('no_such_number')) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end

    local now = os.time()
    if Cooldown[src] and now - Cooldown[src] < Config.CallCooldown then return cb(false, locale('cooldown')) end
    Cooldown[src] = now

    if not nearPhone(src, from) then return cb(false, locale('not_near')) end
    if not canUsePhone(src, from) then return cb(false, locale('job_restricted')) end
    if PlayerCall[src] then return cb(false, locale('already_in_call')) end
    if PhoneCall[phoneId] then return cb(false, locale('phone_busy')) end

    local to = phoneByNumber(number)
    if not to then return cb(false, locale('no_such_number')) end
    if to.id == from.id then return cb(false, locale('own_number')) end
    if PhoneCall[to.id] then return cb(false, locale('line_busy')) end

    -- payphone: take the inserted coins only after every other check has passed
    local paid
    if isPayphone(from) then
        local depositCents = cents(deposit)
        if not depositCents then return cb(false, locale('number_invalid')) end
        if depositCents < COST then return cb(false, locale('pay_need', dollars(COST))) end
        if depositCents > MAX_DEPOSIT then return cb(false, locale('pay_too_much', dollars(MAX_DEPOSIT))) end
        local balance = cents(Player.Functions.GetMoney(PP.MoneyType))
        if not balance or balance < depositCents then return cb(false, locale('pay_no_money')) end
        if not Player.Functions.RemoveMoney(PP.MoneyType, depositCents / 100, 'payphone-deposit') then
            return cb(false, locale('pay_no_money'))
        end
        paid = depositCents
    end

    nextCallId = nextCallId + 1
    local callId = nextCallId
    Calls[callId] = {
        id = callId, caller = src, fromPhone = from.id, toPhone = to.id, state = 'ringing', started = now,
        deposit = paid, spent = 0, payer = paid and Player.PlayerData.citizenid or nil,
    }
    PlayerCall[src] = callId
    PhoneCall[from.id] = callId
    PhoneCall[to.id] = callId

    TriggerClientEvent('rsg-telephone:client:setRinging', -1, to.id, true)

    SetTimeout(Config.RingTimeout * 1000, function()
        local call = Calls[callId]
        if call and call.state == 'ringing' then endCall(callId, 'no_answer') end
    end)

    cb(true, { label = to.label, number = to.number })
end)

RSGCore.Functions.CreateCallback('rsg-telephone:server:answer', function(src, cb, phoneId)
    phoneId = tonumber(phoneId)
    local phone = Phones[phoneId]
    local callId = PhoneCall[phoneId]
    local call = callId and Calls[callId]
    if not phone or not call or call.state ~= 'ringing' or call.toPhone ~= phoneId then return cb(false) end
    if call.caller == src then return cb(false, locale('already_in_call')) end
    if not RSGCore.Functions.GetPlayer(src) then return cb(false) end
    if PlayerCall[src] then return cb(false, locale('already_in_call')) end
    if not nearPhone(src, phone) then return cb(false, locale('not_near')) end

    call.state = 'active'
    call.answerer = src
    call.started = os.time()
    PlayerCall[src] = callId

    TriggerClientEvent('rsg-telephone:client:setRinging', -1, phoneId, false)

    -- open the private line: each client whispers to the other
    TriggerClientEvent('rsg-telephone:client:startVoice', call.caller, src)
    TriggerClientEvent('rsg-telephone:client:startVoice', src, call.caller)

    if call.deposit then -- first minute is charged on answer
        call.spent = COST
        call.paidUntil = call.started + 60
        sendCredit(call)
    end

    local from = Phones[call.fromPhone]
    TriggerClientEvent('rsg-telephone:client:callConnected', call.caller, { label = phone.label, number = phone.number })
    notify(call.caller, locale('call_connected'), 'success')
    notify(src, locale('call_connected'), 'success')
    cb(true, { label = from and from.label or '?', number = from and from.number or '?' })
end)

RegisterNetEvent('rsg-telephone:server:hangUp', function()
    local src = source
    local callId = PlayerCall[src]
    if callId then endCall(callId) end
end)

-- watchdog: distance, max length and payphone billing
CreateThread(function()
    while true do
        Wait(2000)
        local now = os.time()
        for callId, call in pairs(Calls) do
            local drop = false
            if not nearPhone(call.caller, Phones[call.fromPhone], Config.MaxCallDistance + 1.0) then drop = true end
            if call.answerer and not nearPhone(call.answerer, Phones[call.toPhone], Config.MaxCallDistance + 1.0) then drop = true end
            if call.state == 'active' and Config.MaxCallLength > 0 and now - call.started > Config.MaxCallLength then drop = true end

            if drop then
                endCall(callId)
            elseif call.deposit and call.state == 'active' then
                local left = call.deposit - call.spent
                if now >= call.paidUntil then
                    if left >= COST then
                        call.spent = call.spent + COST
                        call.paidUntil = call.paidUntil + 60
                        call.warned = false
                        sendCredit(call)
                    else
                        endCall(callId, 'pay_out')
                    end
                elseif left < COST and not call.warned and call.paidUntil - now <= PP.WarnSeconds then
                    call.warned = true
                    notify(call.caller, locale('pay_low', call.paidUntil - now), 'warning')
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Cooldown[src] = nil
    PendingPlace[src] = nil
    if PlayerCall[src] then endCall(PlayerCall[src]) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for callId in pairs(Calls) do endCall(callId) end
end)
