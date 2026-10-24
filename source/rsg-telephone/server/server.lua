local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Phones     = {}  -- [id] = { id, number, label, model, coords, heading, room, listed, job }
local Calls      = {}  -- [callId] = { caller, answerer, fromPhone, toPhone, state, started, deposit, spent, payer, paidUntil }
local PlayerCall = {}  -- [src] = callId
local PhoneCall  = {}  -- [phoneId] = callId
local Cooldown   = {}
local Stored     = {}  -- [id] = picked-up player phones (number stays reserved)
local PendingPlace = {} -- [src] = { slot, storedId, t } issued when the telephone item is used
local nextCallId = 0

----------------------------------------------------------------
-- helpers
----------------------------------------------------------------
local function notify(src, msg, nType)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('title'), description = msg, type = nType or 'inform' })
end

-- same check as the /addphone command, so the callback can't be reached by anyone the command rejects
local function isAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.AdminPermission)
end

local function isFinite(n) return n and n == n and n ~= math.huge and n ~= -math.huge end

local function nearPhone(src, phone, dist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not phone then return false end
    return #(GetEntityCoords(ped) - phone.coords) <= (dist or Config.MaxCallDistance)
end

local function nearestPhone(src, maxDist)
    local pos = GetEntityCoords(GetPlayerPed(src))
    local best, bestDist
    for _, p in pairs(Phones) do
        local d = #(pos - p.coords)
        if d < (maxDist or 3.0) and (not bestDist or d < bestDist) then best, bestDist = p, d end
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
    local min = 10 ^ (Config.NumberLength - 1)
    local max = (10 ^ Config.NumberLength) - 1
    for _ = 1, 500 do
        local n = tostring(math.random(min, max))
        if not numberTaken(n) then return n end
    end
end

local function publicPhone(p)
    return { id = p.id, number = p.number, label = p.label, model = p.model,
             x = p.coords.x, y = p.coords.y, z = p.coords.z, heading = p.heading, room = p.room or 0, job = p.job, owner = p.owner, listed = p.listed }
end

-- job restriction: '' / nil = anyone. Matches the player's job type (e.g. medic, leo) or job name.
local function cleanJob(job)
    job = type(job) == 'string' and job:lower():gsub('[^%w_]', ''):sub(1, 64) or ''
    return job ~= '' and job or nil
end

local function canUsePhone(src, phone)
    if not phone.job then return true end
    local Player = RSGCore.Functions.GetPlayer(src)
    local job = Player and Player.PlayerData.job
    if not job then return false end
    return (job.type and job.type:lower() == phone.job) or (job.name and job.name:lower() == phone.job) or false
end

local function phoneList()
    local list = {}
    for _, p in pairs(Phones) do list[#list + 1] = publicPhone(p) end
    return list
end

----------------------------------------------------------------
-- payphone money (all amounts handled in whole cents)
----------------------------------------------------------------
local PP = Config.Payphone
local function cents(d) return math.floor((tonumber(d) or 0) * 100 + 0.5) end
local function dollars(c) return ('%.2f'):format(c / 100) end
local COST = cents(PP.CostPerMinute)

local function isPayphone(phone)
    return PP.Enabled and COST > 0 and phone and not phone.job and (not phone.owner or Config.Item.Payphone)
end

-- refund to an online player, or straight into the database if they've already left
local function refund(src, citizenid, amount)
    if amount <= 0 then return end
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
        MySQL.update(('UPDATE players SET money = JSON_SET(money, "$.%s", ROUND(COALESCE(JSON_EXTRACT(money, "$.%s"), 0) + ?, 2)) WHERE citizenid = ?')
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
-- load
----------------------------------------------------------------
CreateThread(function()
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
        if tonumber(n) == 0 then MySQL.query.await(('ALTER TABLE rsg_telephones ADD COLUMN `%s` %s'):format(name, def)) end
    end
    ensureColumn('room', 'BIGINT NOT NULL DEFAULT 0')
    ensureColumn('job', 'VARCHAR(64) DEFAULT NULL')
    ensureColumn('owner', 'VARCHAR(64) DEFAULT NULL')
    ensureColumn('stored', 'TINYINT(1) NOT NULL DEFAULT 0')

    local rows = MySQL.query.await('SELECT * FROM rsg_telephones') or {}
    local loaded = 0
    for _, r in ipairs(rows) do
        local x, y, z = tonumber(r.x), tonumber(r.y), tonumber(r.z)
        if r.id and r.number and r.model and x and y and z then
            local p = {
                id = r.id, number = tostring(r.number), label = r.label or locale('default_label'), model = r.model,
                coords = vector3(x, y, z), heading = (tonumber(r.heading) or 0.0) + 0.0,
                room = tonumber(r.room) or 0, listed = r.listed == 1 or r.listed == true, job = cleanJob(r.job),
                owner = r.owner,
            }
            if r.stored == 1 or r.stored == true then Stored[r.id] = p else Phones[r.id] = p end
            loaded = loaded + 1
        else
            print(('[rsg-telephone] ^3skipped invalid row id %s^7'):format(tostring(r.id)))
        end
    end
    print(('[rsg-telephone] loaded %d telephones'):format(loaded))
    TriggerClientEvent('rsg-telephone:client:syncPhones', -1, phoneList())
end)

lib.callback.register('rsg-telephone:server:getPhones', function()
    local ringing = {}
    for phoneId, callId in pairs(PhoneCall) do
        local c = Calls[callId]
        if c and c.state == 'ringing' and c.toPhone == phoneId then ringing[#ringing + 1] = phoneId end
    end
    return phoneList(), ringing
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

lib.callback.register('rsg-telephone:server:getDirectory', function(src)
    local admin = isAdmin(src)
    return { entries = buildDirectory(admin), admin = admin }
end)

lib.callback.register('rsg-telephone:server:setListed', function(src, id, listed)
    if not isAdmin(src) then return false, locale('no_permission') end
    local p = Phones[tonumber(id)]
    if not p or type(listed) ~= 'boolean' then return false end
    MySQL.update.await('UPDATE rsg_telephones SET listed = ? WHERE id = ?', { listed and 1 or 0, p.id })
    p.listed = listed
    return true, buildDirectory(true)
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
    for _, p in pairs(Phones) do if p.owner == cid then n = n + 1 end end
    return n
end

-- the item must still be in the slot it was used from (and still carry the same stored phone)
local function pendingItem(src)
    local pend = PendingPlace[src]
    if not pend or os.time() - pend.t > 300 then PendingPlace[src] = nil return end
    local it = exports['rsg-inventory']:GetItemBySlot(src, pend.slot)
    if not it or it.name ~= Config.Item.Name then return end
    local storedId = it.info and tonumber(it.info.phone_id) or nil
    if pend.storedId ~= storedId then return end
    return pend
end

local placeItem -- forward declaration (item placement path)

lib.callback.register('rsg-telephone:server:createPhone', function(src, data)
    if type(data) ~= 'table' then return false end
    if data.item == true then return placeItem(src, data) end
    if not isAdmin(src) then return false, locale('no_permission') end
    if not validModel[data.model] then return false end
    local x, y, z, h = tonumber(data.x), tonumber(data.y), tonumber(data.z), tonumber(data.heading)
    if not (isFinite(x) and isFinite(y) and isFinite(z) and isFinite(h)) then return false end
    local coords = vector3(x, y, z)
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > 30.0 then return false, locale('not_near') end

    local number = data.number and tostring(data.number):gsub('%s', '') or ''
    if number == '' then
        number = generateNumber()
        if not number then return false end
    elseif not number:match('^%d%d+$') or #number > 16 then
        return false, locale('number_invalid')
    elseif numberTaken(number) then
        return false, locale('number_taken')
    end

    local label = tostring(data.label or ''):sub(1, 64)
    if label == '' then label = locale('default_label') end
    local listed = data.listed and 1 or 0
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local cid = Player.PlayerData.citizenid

    local room = math.tointeger(tonumber(data.room) or 0) or 0
    local job = cleanJob(data.job)
    local id = MySQL.insert.await(
        'INSERT INTO rsg_telephones (number, label, model, x, y, z, heading, listed, created_by, room, job) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { number, label, data.model, x, y, z, h, listed, cid, room, job })
    if not id then return false end

    Phones[id] = { id = id, number = number, label = label, model = data.model, coords = coords, heading = h % 360.0, room = room, listed = listed == 1, job = job }
    TriggerClientEvent('rsg-telephone:client:addPhone', -1, publicPhone(Phones[id]))
    return true, number
end)

local function removePhone(id)
    local p = Phones[id]
    if not p then return false end
    if PhoneCall[id] then endCall(PhoneCall[id]) end
    MySQL.query.await('DELETE FROM rsg_telephones WHERE id = ?', { id })
    Phones[id] = nil
    TriggerClientEvent('rsg-telephone:client:removePhone', -1, id)
    return p
end

----------------------------------------------------------------
-- player-owned telephones (usable item)
----------------------------------------------------------------
local function ownerOf(src, p)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and p and p.owner and p.owner == Player.PlayerData.citizenid and Player or nil
end

if Config.Item.Enabled then
    RSGCore.Functions.CreateUseableItem(Config.Item.Name, function(source, item)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player or not item or not item.slot then return end
        if PlayerCall[src] then return notify(src, locale('already_in_call'), 'error') end
        local pend = PendingPlace[src]
        if pend and os.time() - pend.t <= 300 then return end -- already placing one

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

function placeItem(src, data)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Config.Item.Enabled then return false end
    local pend = pendingItem(src)
    if not pend then PendingPlace[src] = nil return false, locale('item_missing') end

    local x, y, z, h = tonumber(data.x), tonumber(data.y), tonumber(data.z), tonumber(data.heading)
    if not (isFinite(x) and isFinite(y) and isFinite(z) and isFinite(h)) then return false end
    local coords = vector3(x, y, z)
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > 10.0 then return false, locale('not_near') end
    local room = math.tointeger(tonumber(data.room) or 0) or 0
    local cid = Player.PlayerData.citizenid
    local stored = pend.storedId and Stored[pend.storedId]
    if ownedCount(cid) >= Config.Item.MaxPerPlayer then -- re-check: limit may have been hit since the item was used
        PendingPlace[src] = nil
        return false, locale('item_max', Config.Item.MaxPerPlayer)
    end

    -- take the item first; if anything after fails it is given back
    if not exports['rsg-inventory']:RemoveItem(src, Config.Item.Name, 1, pend.slot, 'telephone-placed') then
        return false, locale('item_missing')
    end
    PendingPlace[src] = nil

    local p
    if stored then
        -- re-placing a picked-up phone: keeps its number, label, prop and listing
        local ok = MySQL.update.await('UPDATE rsg_telephones SET x = ?, y = ?, z = ?, heading = ?, room = ?, owner = ?, stored = 0 WHERE id = ?',
            { x, y, z, h, room, cid, stored.id })
        if not ok or ok == 0 then
            exports['rsg-inventory']:AddItem(src, Config.Item.Name, 1, { phone_id = stored.id, number = stored.number, label = stored.label }, nil, 'telephone-refund')
            return false
        end
        Stored[stored.id] = nil
        p = stored
        p.coords, p.heading, p.room, p.owner = coords, h % 360.0, room, cid
    else
        if not validModel[data.model] then
            exports['rsg-inventory']:AddItem(src, Config.Item.Name, 1, nil, nil, 'telephone-refund')
            return false
        end
        local label = tostring(data.label or ''):sub(1, 64)
        if label:gsub('%s', '') == '' then label = locale('default_label') end
        local number = generateNumber()
        local id = number and MySQL.insert.await(
            'INSERT INTO rsg_telephones (number, label, model, x, y, z, heading, listed, created_by, room, owner) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { number, label, data.model, x, y, z, h, data.listed and 1 or 0, cid, room, cid })
        if not id then
            exports['rsg-inventory']:AddItem(src, Config.Item.Name, 1, nil, nil, 'telephone-refund')
            return false
        end
        p = { id = id, number = number, label = label, model = data.model, coords = coords, heading = h % 360.0,
              room = room, listed = data.listed == true, owner = cid }
    end

    Phones[p.id] = p
    TriggerClientEvent('rsg-telephone:client:addPhone', -1, publicPhone(p))
    return true, p.number
end

-- owner picks the phone up: it leaves the world, its settings stay in the DB, the item comes back
lib.callback.register('rsg-telephone:server:pickupPhone', function(src, id)
    local p = Phones[tonumber(id)]
    local Player = ownerOf(src, p)
    if not Player then return false, locale('not_owner') end
    if not nearPhone(src, p) then return false, locale('not_near') end
    if PhoneCall[p.id] then return false, locale('phone_busy') end
    if not exports['rsg-inventory']:CanAddItem(src, Config.Item.Name, 1) then return false, locale('item_full') end

    MySQL.update.await('UPDATE rsg_telephones SET stored = 1 WHERE id = ?', { p.id })
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
        return false, locale('item_full')
    end
    return true
end)

-- owner settings (label + directory listing)
lib.callback.register('rsg-telephone:server:ownerUpdate', function(src, id, data)
    local p = Phones[tonumber(id)]
    if not ownerOf(src, p) then return false, locale('not_owner') end
    if not nearPhone(src, p) or type(data) ~= 'table' then return false, locale('not_near') end
    local label = tostring(data.label or ''):sub(1, 64)
    if label:gsub('%s', '') == '' then return false, locale('form_label_required') end
    local listed = data.listed == true
    MySQL.update.await('UPDATE rsg_telephones SET label = ?, listed = ? WHERE id = ?', { label, listed and 1 or 0, p.id })
    p.label, p.listed = label, listed
    TriggerClientEvent('rsg-telephone:client:updatePhone', -1, publicPhone(p))
    return true
end)

----------------------------------------------------------------
-- admin panel (/phoneadmin) - every callback re-checks permission
----------------------------------------------------------------
local function adminRow(p)
    local callId = PhoneCall[p.id]
    local c = callId and Calls[callId]
    local status = 'idle'
    if c then status = (c.state == 'ringing' and c.toPhone == p.id) and 'ringing' or 'call' end
    return { id = p.id, number = p.number, label = p.label, model = p.model, job = p.job or '', listed = p.listed,
             payphone = isPayphone(p) and true or false, status = status, owned = p.owner ~= nil,
             x = p.coords.x, y = p.coords.y, z = p.coords.z }
end

local function adminList()
    local rows, calls = {}, 0
    for _, p in pairs(Phones) do rows[#rows + 1] = adminRow(p) end
    -- picked-up player phones: listed so admins can free up their numbers
    for _, p in pairs(Stored) do
        local r = adminRow(p); r.status = 'stored'; rows[#rows + 1] = r
    end
    for _ in pairs(Calls) do calls = calls + 1 end
    table.sort(rows, function(a, b) return a.label:lower() < b.label:lower() end)
    return { phones = rows, calls = calls, models = Config.Models }
end

lib.callback.register('rsg-telephone:server:adminList', function(src)
    if not isAdmin(src) then return false end
    return adminList()
end)

lib.callback.register('rsg-telephone:server:adminUpdate', function(src, id, data)
    if not isAdmin(src) then return false, locale('no_permission') end
    local p = Phones[tonumber(id)]
    if not p or type(data) ~= 'table' then return false end

    local label = tostring(data.label or ''):sub(1, 64)
    if label:gsub('%s', '') == '' then return false, locale('form_label_required') end
    local number = (tostring(data.number or ''):gsub('%D', ''))
    if not number:match('^%d%d+$') or #number > 16 then return false, locale('number_invalid') end
    if numberTaken(number, p.id) then return false, locale('number_taken') end
    if not validModel[data.model] then return false end
    local job, listed = cleanJob(data.job), data.listed == true

    -- a changed number would strand a live call, so end it first
    if number ~= p.number and PhoneCall[p.id] then endCall(PhoneCall[p.id]) end

    MySQL.update.await('UPDATE rsg_telephones SET label = ?, number = ?, model = ?, job = ?, listed = ? WHERE id = ?',
        { label, number, data.model, job, listed and 1 or 0, p.id })
    p.label, p.number, p.model, p.job, p.listed = label, number, data.model, job, listed
    TriggerClientEvent('rsg-telephone:client:updatePhone', -1, publicPhone(p))
    return true, adminList()
end)

lib.callback.register('rsg-telephone:server:adminDelete', function(src, id)
    if not isAdmin(src) then return false, locale('no_permission') end
    id = tonumber(id)
    if Stored[id] then
        MySQL.query.await('DELETE FROM rsg_telephones WHERE id = ?', { id })
        Stored[id] = nil
        return true, adminList()
    end
    if not removePhone(id) then return false end
    return true, adminList()
end)

lib.callback.register('rsg-telephone:server:adminEndCall', function(src, id)
    if not isAdmin(src) then return false, locale('no_permission') end
    local callId = PhoneCall[tonumber(id)]
    if not callId then return false end
    endCall(callId, 'admin_ended')
    return true, adminList()
end)

RSGCore.Commands.Add('phoneadmin', locale('cmd_phoneadmin'), {}, false, function(source)
    TriggerClientEvent('rsg-telephone:client:openAdmin', source)
end, Config.AdminPermission)

RSGCore.Commands.Add('addphone', locale('cmd_addphone'), {}, false, function(source)
    TriggerClientEvent('rsg-telephone:client:startPlacement', source)
end, Config.AdminPermission)

RSGCore.Commands.Add('removephone', locale('cmd_removephone'), {}, false, function(source)
    local near = nearestPhone(source)
    if not near then return notify(source, locale('no_phone_near'), 'error') end
    local p = removePhone(near.id)
    if p then notify(source, locale('removed', p.number), 'success') end
end, Config.AdminPermission)

RSGCore.Commands.Add('phonejob', locale('cmd_phonejob'), {
    { name = 'job', help = locale('cmd_phonejob_arg') },
}, false, function(source, args)
    local p = nearestPhone(source)
    if not p then return notify(source, locale('no_phone_near'), 'error') end
    local job = cleanJob(args[1])
    MySQL.update.await('UPDATE rsg_telephones SET job = ? WHERE id = ?', { job, p.id })
    p.job = job
    TriggerClientEvent('rsg-telephone:client:updatePhone', -1, publicPhone(p))
    notify(source, job and locale('job_set', p.number, job) or locale('job_cleared', p.number), 'success')
end, Config.AdminPermission)

RSGCore.Commands.Add('phoneinfo', locale('cmd_phoneinfo'), {}, false, function(source)
    local p = nearestPhone(source)
    if not p then return notify(source, locale('no_phone_near'), 'error') end
    local info = locale('phone_info', p.id, p.number, p.label)
    if p.job then info = info .. ' · ' .. locale('job_only', p.job)
    elseif isPayphone(p) then info = info .. ' · ' .. locale('payphone') end
    notify(source, info, 'inform')
end, Config.AdminPermission)

----------------------------------------------------------------
-- calling
----------------------------------------------------------------
lib.callback.register('rsg-telephone:server:startCall', function(src, phoneId, number, deposit)
    phoneId = tonumber(phoneId)
    number = type(number) == 'string' and number:gsub('%D', '') or ''
    local from = Phones[phoneId]
    if not from or number == '' or #number > 16 then return false end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end

    local now = os.time()
    if Cooldown[src] and now - Cooldown[src] < Config.CallCooldown then return false, locale('cooldown') end
    Cooldown[src] = now

    if not nearPhone(src, from) then return false, locale('not_near') end
    if not canUsePhone(src, from) then return false, locale('job_restricted') end
    if PlayerCall[src] then return false, locale('already_in_call') end
    if PhoneCall[phoneId] then return false, locale('phone_busy') end

    local to = phoneByNumber(number)
    if not to then return false, locale('no_such_number') end
    if to.id == from.id then return false, locale('own_number') end
    if PhoneCall[to.id] then return false, locale('line_busy') end

    -- payphone: take the inserted coins only after every other check has passed
    local paid
    if isPayphone(from) then
        paid = cents(deposit)
        if paid < COST then return false, locale('pay_need', dollars(COST)) end
        if paid > cents(PP.MaxDeposit) then return false end
        if cents(Player.Functions.GetMoney(PP.MoneyType)) < paid then return false, locale('pay_no_money') end
        if not Player.Functions.RemoveMoney(PP.MoneyType, paid / 100, 'payphone-deposit') then return false, locale('pay_no_money') end
    end

    nextCallId = nextCallId + 1
    local callId = nextCallId
    Calls[callId] = { id = callId, caller = src, fromPhone = from.id, toPhone = to.id, state = 'ringing', started = now,
        deposit = paid, spent = 0, payer = paid and Player.PlayerData.citizenid or nil }
    PlayerCall[src] = callId
    PhoneCall[from.id] = callId
    PhoneCall[to.id] = callId

    TriggerClientEvent('rsg-telephone:client:setRinging', -1, to.id, true)

    SetTimeout(Config.RingTimeout * 1000, function()
        local c = Calls[callId]
        if c and c.state == 'ringing' then endCall(callId, 'no_answer') end
    end)

    return true, { label = to.label, number = to.number }
end)

lib.callback.register('rsg-telephone:server:answer', function(src, phoneId)
    phoneId = tonumber(phoneId)
    local phone = Phones[phoneId]
    local callId = PhoneCall[phoneId]
    local call = callId and Calls[callId]
    if not phone or not call or call.state ~= 'ringing' or call.toPhone ~= phoneId then return false end
    if not RSGCore.Functions.GetPlayer(src) then return false end
    if PlayerCall[src] then return false, locale('already_in_call') end
    if not nearPhone(src, phone) then return false, locale('not_near') end

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
    return true, { label = from and from.label or '?', number = from and from.number or '?' }
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
        for callId, c in pairs(Calls) do
            local drop = false
            if not nearPhone(c.caller, Phones[c.fromPhone], Config.MaxCallDistance + 1.0) then drop = true end
            if c.answerer and not nearPhone(c.answerer, Phones[c.toPhone], Config.MaxCallDistance + 1.0) then drop = true end
            if c.state == 'active' and Config.MaxCallLength > 0 and now - c.started > Config.MaxCallLength then drop = true end
            if drop then
                endCall(callId)
            elseif c.deposit and c.state == 'active' then
                local left = c.deposit - c.spent
                if now >= c.paidUntil then
                    if left >= COST then
                        c.spent = c.spent + COST
                        c.paidUntil = c.paidUntil + 60
                        c.warned = false
                        sendCredit(c)
                    else
                        endCall(callId, 'pay_out')
                    end
                elseif left < COST and not c.warned and c.paidUntil - now <= PP.WarnSeconds then
                    c.warned = true
                    notify(c.caller, locale('pay_low', c.paidUntil - now), 'warning')
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
