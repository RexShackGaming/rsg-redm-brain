local RSGCore = exports['rsg-core']:GetCoreObject()

-- rsg-core callbacks answer via cb(...); keep handlers returning values
local function registerCallback(name, handler)
    RSGCore.Functions.CreateCallback(name, function(source, cb, ...)
        cb(handler(source, ...))
    end)
end

---------------------------------------------
-- state / lookups
---------------------------------------------
local RentedHouses = {} -- [houseid] = { owner = fullname, citizenid = citizenid, label = custom name, home = bool }
local DoorStates   = {} -- [doorid (string)] = 1 locked / 0 unlocked
local Cooldowns    = {}

-- decorating: props the tenant may place (from Config.DecorProps)
local DecorByKey, DecorList = {}, {}
for _, def in ipairs(Config.DecorProps or {}) do
    DecorByKey[def.key] = def
    DecorList[#DecorList + 1] = { key = def.key, label = def.label, price = def.price or 0 }
end

-- key lengths a tenant may pick (hours, 0 = until removed)
local GUEST_DURATION_SET = {}
for _, h in ipairs(Config.GuestDurations or { 0 }) do GUEST_DURATION_SET[h] = true end

local HousesById, DoorsById = {}, {}
for _, house in ipairs(Config.Houses) do HousesById[house.houseid] = house end
for _, door in ipairs(Config.HouseDoors) do DoorsById[tostring(door.doorid)] = door end

-- extra columns: due date as text, is it overdue, can the tenant pay now (max 1 month ahead)
local HOUSE_SELECT = [[
    SELECT *, DATE_FORMAT(rent_due, '%d/%m/%Y %H:%i') AS due_text,
           (rent_due < NOW()) AS overdue,
           (rent_due < DATE_ADD(NOW(), INTERVAL 1 MONTH)) AS can_pay,
           TIMESTAMPDIFF(HOUR, NOW(), rent_due) AS hours_left
    FROM rsg_housing
]]

---------------------------------------------
-- helpers
---------------------------------------------
-- oxmysql returns TINYINT(1) columns as booleans, other flags as 0/1
local function isTrue(value)
    return value == true or value == 1
end

local function notify(src, title, description, nType)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = title,
        description = description,
        type = nType or 'inform',
        duration = 6000
    })
end

-- per-player, per-action rate limit ([src][key] = last time)
local function onCooldown(src, ms, key)
    local now = GetGameTimer()
    local timers = Cooldowns[src]
    if not timers then timers = {}; Cooldowns[src] = timers end
    key = key or 'action'
    if timers[key] and now - timers[key] < (ms or 1000) then return true end
    timers[key] = now
    return false
end

local function isNear(src, coords, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - vector3(coords.x, coords.y, coords.z)) <= maxDist
end

local function getStashId(houseid)
    return 'house_' .. houseid
end

local function getHouse(houseid)
    if type(houseid) ~= 'string' or not HousesById[houseid] then return nil end
    return MySQL.single.await(HOUSE_SELECT .. ' WHERE houseid = ?', { houseid })
end

-- the house the player rents, by id (so tenants with several houses act on the right one)
local function getTenantHouse(citizenid, houseid)
    if type(houseid) ~= 'string' or not HousesById[houseid] then return nil end
    return MySQL.single.await(HOUSE_SELECT .. ' WHERE houseid = ? AND citizenid = ? AND rented = 1', { houseid, citizenid })
end

-- per-guest permissions (tenants always have every permission)
local GUEST_PERMS = { 'doors', 'storage', 'wardrobe', 'mailbox' }
local GUEST_PERM_SET = {}
for _, perm in ipairs(GUEST_PERMS) do GUEST_PERM_SET[perm] = true end
local PERM_COLUMNS = 'perm_doors, perm_storage, perm_wardrobe, perm_mailbox'

local function permsFromRow(row)
    local perms = {}
    for _, perm in ipairs(GUEST_PERMS) do perms[perm] = isTrue(row['perm_' .. perm]) end
    return perms
end

-- the player's key to a house (guest flag + permissions), or nil
local function getKey(citizenid, houseid)
    return MySQL.single.await('SELECT guest, ' .. PERM_COLUMNS .. ' FROM rsg_housekeys WHERE citizenid = ? AND houseid = ? AND (expires IS NULL OR expires > NOW()) LIMIT 1', { citizenid, houseid })
end

-- returns 'tenant', 'guest' or nil
local function getAccess(citizenid, houseid)
    local key = getKey(citizenid, houseid)
    if not key then return nil end
    return isTrue(key.guest) and 'guest' or 'tenant'
end

-- true if the player is the tenant, or a guest the tenant has allowed to use this part of the house
local function hasPermission(citizenid, houseid, perm)
    if not GUEST_PERM_SET[perm] then return false end
    local key = getKey(citizenid, houseid)
    if not key then return false end
    if not isTrue(key.guest) then return true end
    return isTrue(key['perm_' .. perm])
end

-- what every client may see (no citizen ids) + the houses that belong to one player
local function publicHouses()
    local list = {}
    for houseid, info in pairs(RentedHouses) do
        list[houseid] = { owner = info.owner, label = info.label, home = info.home }
    end
    return list
end

local function housesOf(citizenid)
    local mine = {}
    for houseid, info in pairs(RentedHouses) do
        if info.citizenid == citizenid then mine[houseid] = true end
    end
    return mine
end

local function syncRentedHouses()
    local list = publicHouses()
    for src, Player in pairs(RSGCore.Functions.GetRSGPlayers()) do
        TriggerClientEvent('rsg-housing:client:SyncOwnedHouses', src, list, housesOf(Player.PlayerData.citizenid))
    end
end

-- rsg-economy (optional): returns true when the payment was deposited into a town treasury
local function payTreasury(houseid, amount, reason)
    if not Config.Economy.Enabled or amount <= 0 or GetResourceState('rsg-economy') ~= 'started' then return false end
    local h = HousesById[houseid]
    local c = h and h.menucoords
    if not c then return false end
    local region = exports['rsg-economy']:GetRegionAt(vector3(c.x, c.y, c.z))
    if not region then return false end
    return exports['rsg-economy']:DepositTreasury(region, amount, reason, 'rsg-housing') ~= nil
end

local function payGovernor(region, amount, houseid, reason)
    if payTreasury(houseid, amount, reason or 'rent') and Config.Economy.ReplaceGovernor then return end
    local job = Config.GovernorJobs[region]
    local enabled = Config.EnableGovernor
    if enabled == nil then enabled = Config.EnableGovenor end
    if enabled and job and amount > 0 then
        local ok = pcall(function() exports['rsg-bossmenu']:AddMoney(job, amount) end)
        if not ok then print('^1[rsg-housing] could not pay the governor account (is rsg-bossmenu started?)^7') end
    end
end

local function telegramsAvailable()
    return GetResourceState(Config.TelegramResource) == 'started'
end

-- delivers into rsg-telegram's inbox table and pings the player if they're online
local function sendTelegram(citizenid, recipient, subject, message)
    if not telegramsAvailable() then return end
    local sender = locale('telegram_sender')
    MySQL.insert('INSERT INTO rsg_telegrams (citizenid, recipient_name, sender_citizenid, sender_name, subject, message) VALUES (?, ?, ?, ?, ?, ?)', {
        citizenid, recipient, 'LETTINGS', sender, subject, message
    })
    local target = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if target then
        TriggerClientEvent('rsg-telegram:client:newTelegram', target.PlayerData.source, sender)
    end
end

local function notifyIfOnline(citizenid, title, description, nType)
    local target = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if target then notify(target.PlayerData.source, title, description, nType) end
end

-- unrented houses stay unlocked for viewings, rented houses lock
local function setHouseDoors(houseid, state)
    for doorid, door in pairs(DoorsById) do
        if door.houseid == houseid then
            DoorStates[doorid] = state
            TriggerClientEvent('rsg-housing:client:SetDoorState', -1, doorid, state)
        end
    end
end

-- empties a stash in rsg-inventory memory and the database
local function stashPurge(stashId)
    pcall(function() exports['rsg-inventory']:ClearInventory(stashId) end)
    pcall(function() exports['rsg-inventory']:ClearStash(stashId) end)
    pcall(function() exports['rsg-inventory']:DeleteInventory(stashId) end)
    MySQL.update.await('DELETE FROM inventories WHERE identifier = ?', { stashId })
end

local function purgeStorage(houseid)
    stashPurge(getStashId(houseid))
end

local function retrievalId(houseid, citizenid)
    return ('houseret_%s_%s'):format(citizenid, houseid)
end

-- moves the house stash into a per-tenant retrieval stash they can open for Config.RetrievalDays
local function moveToRetrieval(houseid, citizenid)
    local days = tonumber(Config.RetrievalDays) or 0
    if days <= 0 or not citizenid or citizenid == '0' then return false end

    local ok, inv = pcall(function() return exports['rsg-inventory']:GetInventory(getStashId(houseid)) end)
    local list = {}
    if ok and type(inv) == 'table' and type(inv.items) == 'table' then
        for slot, it in pairs(inv.items) do
            if type(it) == 'table' and it.name then
                list[#list + 1] = { name = it.name, amount = it.amount, info = it.info or {}, slot = tonumber(it.slot) or tonumber(slot) }
            end
        end
    end
    if #list == 0 then return false end

    local retId = retrievalId(houseid, citizenid)
    stashPurge(retId)
    MySQL.insert.await('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)', { retId, json.encode(list) })
    MySQL.insert.await('INSERT INTO rsg_housing_retrieval (houseid, citizenid, expires) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? DAY)) ON DUPLICATE KEY UPDATE expires = VALUES(expires)', { houseid, citizenid, days })
    return true
end

-- highest slot used in the house stash (so a smaller storage never hides items)
local function storageUsedSlots(houseid)
    local stashId = getStashId(houseid)
    local highest = 0
    local ok, inv = pcall(function() return exports['rsg-inventory']:GetInventory(stashId) end)
    if ok and type(inv) == 'table' and type(inv.items) == 'table' then
        for key, item in pairs(inv.items) do
            local slot = type(item) == 'table' and tonumber(item.slot) or tonumber(key)
            if slot and slot > highest then highest = slot end
        end
        return highest
    end
    -- rsg-inventory not answering: read what was last saved
    local raw = MySQL.scalar.await('SELECT items FROM inventories WHERE identifier = ?', { stashId })
    local items = raw and json.decode(raw)
    if type(items) == 'table' then
        for key, item in pairs(items) do
            local slot = type(item) == 'table' and tonumber(item.slot) or tonumber(key)
            if slot and slot > highest then highest = slot end
        end
    end
    return highest
end

local function getStorageTier(level)
    level = math.tointeger(tonumber(level)) or 1
    return Config.StorageTiers[level] and level or 1, Config.StorageTiers[level] or Config.StorageTiers[1]
end

-- purge: true deletes the storage, false keeps it for the old tenant (Config.RetrievalDays), nil uses Config.PurgeStorageOnLeave
-- reason is passed to the tenancyEnded hook: 'left' | 'evicted' | 'admin' | 'api'
-- returns true when belongings were kept for retrieval
local function endTenancy(houseid, purge, ownerCid, reason)
    MySQL.update.await("UPDATE rsg_housing SET citizenid = '0', fullname = '0', rented = 0, rent_due = NULL, reminder_sent = 0, custom_name = NULL, storage_tier = 1 WHERE houseid = ?", { houseid })
    MySQL.update.await('DELETE FROM rsg_housekeys WHERE houseid = ?', { houseid })
    MySQL.update.await('DELETE FROM rsg_housing_props WHERE houseid = ?', { houseid })
    TriggerClientEvent('rsg-housing:client:propsCleared', -1, houseid)

    if purge == nil then purge = Config.PurgeStorageOnLeave end
    local moved = false
    if not purge then moved = moveToRetrieval(houseid, ownerCid) end
    purgeStorage(houseid) -- the next tenant always starts with an empty house

    RentedHouses[houseid] = nil
    setHouseDoors(houseid, 0)
    TriggerEvent('rsg-housing:server:tenancyEnded', houseid, ownerCid, reason or 'left')
    return moved
end

-- guest list with character names (two queries, so table collations never have to match)
local function getGuests(houseid)
    local guests = MySQL.query.await('SELECT citizenid, ' .. PERM_COLUMNS .. ", DATE_FORMAT(expires, '%d/%m/%Y %H:%i') AS expires_text FROM rsg_housekeys WHERE houseid = ? AND guest = 1 AND (expires IS NULL OR expires > NOW())", { houseid }) or {}
    if #guests == 0 then return guests end
    for i = 1, #guests do
        guests[i].perms = permsFromRow(guests[i])
        for _, perm in ipairs(GUEST_PERMS) do guests[i]['perm_' .. perm] = nil end
    end

    local cids = {}
    for i = 1, #guests do cids[i] = guests[i].citizenid end

    local names = {}
    local players = MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE citizenid IN (?)', { cids }) or {}
    for _, row in ipairs(players) do
        local info = type(row.charinfo) == 'string' and json.decode(row.charinfo) or row.charinfo
        if info and info.firstname then
            names[row.citizenid] = info.firstname .. ' ' .. (info.lastname or '')
        end
    end

    for i = 1, #guests do guests[i].name = names[guests[i].citizenid] end
    return guests
end

-- opens the house stash for a player (no permission check: callers decide who may)
local function openStash(src, houseid)
    local level = MySQL.scalar.await('SELECT storage_tier FROM rsg_housing WHERE houseid = ?', { houseid })
    local _, tier = getStorageTier(level)
    exports['rsg-inventory']:OpenInventory(src, getStashId(houseid), {
        label     = locale('storage_label', HousesById[houseid].name),
        maxweight = tier.weight,
        slots     = tier.slots
    })
end

-- gives a key (guest = 1); hours > 0 makes it expire. perms = { doors, storage, wardrobe, mailbox } booleans
local function giveKey(houseid, citizenid, hours, perms)
    hours = math.max(0, math.tointeger(tonumber(hours)) or 0)
    perms = perms or Config.GuestDefaultPermissions or {}
    -- an expired key for the same person would block the insert below
    MySQL.update.await('DELETE FROM rsg_housekeys WHERE houseid = ? AND citizenid = ? AND expires IS NOT NULL AND expires <= NOW()', { houseid, citizenid })
    local values = {}
    for i, perm in ipairs(GUEST_PERMS) do values[i] = perms[perm] == false and 0 or 1 end
    MySQL.insert.await('INSERT INTO rsg_housekeys (citizenid, houseid, guest, ' .. PERM_COLUMNS .. ', expires) VALUES (?, ?, 1, ?, ?, ?, ?, IF(? > 0, DATE_ADD(NOW(), INTERVAL ? HOUR), NULL))', {
        citizenid, houseid, values[1], values[2], values[3], values[4], hours, hours
    })
    TriggerEvent('rsg-housing:server:guestAdded', houseid, citizenid, hours)
end

local function revokeKey(houseid, citizenid)
    local removed = MySQL.update.await('DELETE FROM rsg_housekeys WHERE houseid = ? AND citizenid = ? AND guest = 1', { houseid, citizenid })
    if removed > 0 then
        TriggerEvent('rsg-housing:server:guestRemoved', houseid, citizenid)
        return true
    end
    return false
end

-- ends the current tenancy with the lettings-office message; returns the tenant row (or nil) and whether belongings were kept
local function evictHouse(houseid, purge, reason)
    local row = MySQL.single.await('SELECT citizenid, fullname FROM rsg_housing WHERE houseid = ? AND rented = 1', { houseid })
    if not row then return nil end
    local name = HousesById[houseid] and HousesById[houseid].name or houseid
    local moved = endTenancy(houseid, purge == true, row.citizenid, reason)
    syncRentedHouses()
    local msg = locale('admin_eviction_message', name)
    if moved then msg = msg .. ' ' .. locale('retrieval_hint', Config.RetrievalDays) end
    sendTelegram(row.citizenid, row.fullname, locale('eviction_subject'), msg)
    notifyIfOnline(row.citizenid, locale('rent_title'), msg, 'error')
    return row, moved
end

-- result sent back to the NUI (shown as a toast)
local function reply(ok, msg, nType)
    return { ok = ok, msg = msg, type = nType or (ok and 'success' or 'error') }
end

AddEventHandler('playerDropped', function()
    Cooldowns[source] = nil
end)

---------------------------------------------
-- startup: cache rented houses, lock all doors
---------------------------------------------
-- creates the tables from installation/rsg-housing.sql the first time the resource starts
local function columnExists(tbl, col)
    return (MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?', { tbl, col }) or 0) > 0
end

local function tableExists(tbl)
    return (MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', { tbl }) or 0) > 0
end

local function addColumn(tbl, col, definition)
    if not columnExists(tbl, col) then
        MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tbl, col, definition))
    end
end

local function addIndex(tbl, name, columns)
    local found = MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = ? AND index_name = ?', { tbl, name }) or 0
    if found == 0 then
        MySQL.query.await(('ALTER TABLE `%s` ADD INDEX `%s` (%s)'):format(tbl, name, columns))
    end
end

local function ensureDatabase()
    if not Config.AutoDatabase then return true end

    local ok, err = pcall(function()
        local firstInstall = not tableExists('rsg_housing')
        local sql = LoadResourceFile(GetCurrentResourceName(), 'installation/rsg-housing.sql')
        assert(sql, 'installation/rsg-housing.sql not found')
        sql = sql:gsub('%-%-[^\n]*', '')
        for statement in sql:gmatch('[^;]+') do
            if statement:match('^%s*CREATE') or (firstInstall and statement:match('^%s*INSERT')) then
                MySQL.query.await(statement)
            end
        end

        -- columns from newer versions (MySQL and MariaDB safe, never destructive)
        addColumn('rsg_housing', 'custom_name', 'varchar(30) DEFAULT NULL')
        addColumn('rsg_housing', 'storage_tier', 'tinyint(4) NOT NULL DEFAULT 1')
        for _, perm in ipairs(GUEST_PERMS) do
            addColumn('rsg_housekeys', 'perm_' .. perm, 'tinyint(1) NOT NULL DEFAULT 1')
        end
        addColumn('rsg_housekeys', 'expires', 'datetime DEFAULT NULL')
        addIndex('rsg_housekeys', 'idx_house_citizen', '`houseid`, `citizenid`')
        -- house ids longer than 7 characters (house100+)
        MySQL.query.await('ALTER TABLE rsg_housing MODIFY `houseid` varchar(20) NOT NULL')
        MySQL.query.await("ALTER TABLE rsg_housekeys MODIFY `houseid` varchar(20) NOT NULL DEFAULT '0'")

        -- houses added to Config.Houses get a database row (needs region = '...' in the house entry)
        for _, house in ipairs(Config.Houses) do
            if house.region then
                MySQL.insert.await('INSERT IGNORE INTO rsg_housing (region, houseid, rent) VALUES (?, ?, ?)', { house.region, house.houseid, house.rent or 50 })
            end
        end
    end)

    if not ok then
        print(('^1[rsg-housing] database setup failed: %s^7'):format(tostring(err)))
        return false
    end
    print('^2[rsg-housing] database tables ready^7')
    return true
end

CreateThread(function()
    if not ensureDatabase() then return end
    local houses = MySQL.query.await('SELECT houseid, fullname, citizenid, custom_name FROM rsg_housing WHERE rented = 1') or {}
    for _, house in ipairs(houses) do
        RentedHouses[house.houseid] = { owner = house.fullname, citizenid = house.citizenid, label = house.custom_name }
    end

    for doorid, door in pairs(DoorsById) do
        DoorStates[doorid] = RentedHouses[door.houseid] and 1 or 0
    end

    for _, house in ipairs(Config.Houses) do
        if not MySQL.scalar.await('SELECT 1 FROM rsg_housing WHERE houseid = ?', { house.houseid }) then
            print(('^3[rsg-housing] %s has no row in rsg_housing and cannot be rented (add region = \'...\' to its config entry or insert the row)^7'):format(house.houseid))
        end
    end

    print(('[rsg-housing] loaded %s rented houses'):format(#houses))
    syncRentedHouses()
    TriggerClientEvent('rsg-housing:client:SyncDoors', -1, DoorStates)
end)

---------------------------------------------
-- callbacks
---------------------------------------------
registerCallback('rsg-housing:server:getState', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    return publicHouses(), DoorStates, Player and housesOf(Player.PlayerData.citizenid) or {}
end)

-- everything the house menu needs in one call
registerCallback('rsg-housing:server:getHouseStatus', function(source, houseid)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return nil end
    local house = getHouse(houseid)
    if not house then return nil end

    local status = { rented = isTrue(house.rented), rent = house.rent, grace = Config.GracePeriodDays }
    if status.rented then
        local key = getKey(Player.PlayerData.citizenid, houseid)
        status.access = key and (isTrue(key.guest) and 'guest' or 'tenant') or nil
        if status.access == 'tenant' then
            status.due     = house.due_text
            status.overdue = isTrue(house.overdue)
            status.canPay  = isTrue(house.can_pay)
            status.hoursLeft = house.hours_left
            status.customName = house.custom_name
            status.home = RentedHouses[houseid] and RentedHouses[houseid].home == true or false
            status.guests    = getGuests(houseid)
            status.durations = Config.GuestDurations
            if Config.Decorating and #DecorList > 0 then
                status.decor = {
                    items = DecorList,
                    max   = Config.MaxPropsPerHouse,
                    count = MySQL.scalar.await('SELECT COUNT(*) FROM rsg_housing_props WHERE houseid = ?', { houseid }) or 0
                }
            end
        end
        if status.access == 'guest' then
            status.perms = permsFromRow(key)
        end
        if status.access then
            status.storageTier = (getStorageTier(house.storage_tier))
        end
        if status.access and telegramsAvailable() and (status.access == 'tenant' or status.perms.mailbox) then
            status.unread = MySQL.scalar.await('SELECT COUNT(*) FROM rsg_telegrams WHERE citizenid = ? AND is_read = 0', { Player.PlayerData.citizenid }) or 0
        end
    end
    return status
end)


---------------------------------------------
-- rent a house (first month paid up front)
---------------------------------------------
registerCallback('rsg-housing:server:rentHouse', function(src, houseid)
    if onCooldown(src, 2000) then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return reply(false) end

    local house = getHouse(houseid)
    if not house or isTrue(house.rented) then
        return reply(false, locale('house_unavailable'), 'error')
    end
    if not isNear(src, HousesById[houseid].menucoords, Config.InteractDistance) then
        return reply(false, locale('too_far'), 'error')
    end

    local citizenid = Player.PlayerData.citizenid
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM rsg_housing WHERE citizenid = ? AND rented = 1', { citizenid })
    if (count or 0) >= Config.MaxHousesPerPlayer then
        return reply(false, locale('already_renting'), 'error')
    end

    local rent = math.max(0, house.rent)
    if Player.Functions.GetMoney('cash') < rent then
        return reply(false, locale('not_enough_cash'), 'error')
    end
    if rent > 0 and not Player.Functions.RemoveMoney('cash', rent, 'house-rent') then return reply(false) end

    local charinfo = Player.PlayerData.charinfo
    local fullname = charinfo.firstname .. ' ' .. charinfo.lastname

    -- conditional update stops two players renting the same house at once
    local updated = MySQL.update.await([[
        UPDATE rsg_housing SET citizenid = ?, fullname = ?, rented = 1, reminder_sent = 0, custom_name = NULL,
               rent_due = DATE_ADD(NOW(), INTERVAL 1 MONTH)
        WHERE houseid = ? AND rented = 0
    ]], { citizenid, fullname, houseid })
    if updated == 0 then
        if rent > 0 then Player.Functions.AddMoney('cash', rent, 'house-rent-refund') end
        return reply(false, locale('house_unavailable'), 'error')
    end

    MySQL.update.await('DELETE FROM rsg_housekeys WHERE houseid = ?', { houseid })
    MySQL.insert.await('INSERT INTO rsg_housekeys (citizenid, houseid, guest) VALUES (?, ?, 0)', { citizenid, houseid })
    payGovernor(house.region, rent, houseid, 'rent')

    RentedHouses[houseid] = { owner = fullname, citizenid = citizenid }
    syncRentedHouses()
    setHouseDoors(houseid, 1)
    TriggerEvent('rsg-housing:server:houseRented', houseid, citizenid, rent)

    local due = MySQL.scalar.await("SELECT DATE_FORMAT(rent_due, '%d/%m/%Y') FROM rsg_housing WHERE houseid = ?", { houseid })
    return reply(true, locale('house_rented', HousesById[houseid].name, rent, due), 'success')
end)

---------------------------------------------
-- pay rent (adds 1 calendar month to the due date, max 1 month ahead)
---------------------------------------------
registerCallback('rsg-housing:server:payRent', function(src, houseid)
    if onCooldown(src, 2000) then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return reply(false) end

    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house then return reply(false, locale('not_tenant'), 'error') end
    if not isTrue(house.can_pay) then
        return reply(false, locale('rent_paid_ahead', house.due_text), 'inform')
    end
    if not isNear(src, HousesById[house.houseid].menucoords, Config.InteractDistance) then
        return reply(false, locale('too_far'), 'error')
    end

    local rent = math.max(0, house.rent)
    if Player.Functions.GetMoney('cash') < rent then
        return reply(false, locale('not_enough_cash'), 'error')
    end
    if rent > 0 and not Player.Functions.RemoveMoney('cash', rent, 'house-rent') then return reply(false) end

    local updated = MySQL.update.await([[
        UPDATE rsg_housing SET rent_due = DATE_ADD(rent_due, INTERVAL 1 MONTH), reminder_sent = 0
        WHERE houseid = ? AND citizenid = ? AND rented = 1 AND rent_due < DATE_ADD(NOW(), INTERVAL 1 MONTH)
    ]], { house.houseid, Player.PlayerData.citizenid })
    if updated == 0 then
        if rent > 0 then Player.Functions.AddMoney('cash', rent, 'house-rent-refund') end
        return reply(false)
    end

    payGovernor(house.region, rent, house.houseid, 'rent')
    TriggerEvent('rsg-housing:server:rentPaid', house.houseid, Player.PlayerData.citizenid, rent)
    local due = MySQL.scalar.await("SELECT DATE_FORMAT(rent_due, '%d/%m/%Y') FROM rsg_housing WHERE houseid = ?", { house.houseid })
    return reply(true, locale('rent_paid', rent, due), 'success')
end)

---------------------------------------------
-- 'at home' toggle (tenant only, kept in memory)
---------------------------------------------
registerCallback('rsg-housing:server:setHome', function(src, houseid, on)
    if onCooldown(src, 1500) then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return reply(false) end

    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house or not RentedHouses[house.houseid] then return reply(false, locale('not_tenant'), 'error') end

    on = on == true
    if on and not isNear(src, HousesById[house.houseid].menucoords, Config.InteractDistance) then
        return reply(false, locale('too_far'), 'error')
    end

    RentedHouses[house.houseid].home = on or nil
    syncRentedHouses()
    return reply(true, on and locale('home_on') or locale('home_off'), on and 'success' or 'inform')
end)

-- clears 'at home' when the tenant logs off or walks away from the house
CreateThread(function()
    while true do
        Wait(math.max(5, Config.HomeCheckInterval) * 1000)
        local changed = false
        for houseid, info in pairs(RentedHouses) do
            if info.home then
                local target = RSGCore.Functions.GetPlayerByCitizenId(info.citizenid)
                local away = not target
                if target and Config.HomeAutoAwayDistance > 0 then
                    away = not isNear(target.PlayerData.source, HousesById[houseid].menucoords, Config.HomeAutoAwayDistance)
                end
                if away then
                    info.home = nil
                    changed = true
                    if target then
                        notify(target.PlayerData.source, locale('rent_title'), locale('home_auto_off'), 'inform')
                    end
                end
            end
        end
        if changed then syncRentedHouses() end
    end
end)

---------------------------------------------
-- storage upgrade (tenant pays the difference between tiers, cash)
---------------------------------------------
registerCallback('rsg-housing:server:upgradeStorage', function(src, houseid, level)
    if onCooldown(src, 2000) then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return reply(false) end

    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house then return reply(false, locale('not_tenant'), 'error') end
    if not isNear(src, HousesById[house.houseid].menucoords, Config.InteractDistance) then
        return reply(false, locale('too_far'), 'error')
    end

    level = math.tointeger(tonumber(level))
    local current, currentTier = getStorageTier(house.storage_tier)
    local target = level and Config.StorageTiers[level]
    if not target or level <= current then
        return reply(false, locale('storage_upgrade_invalid'), 'error')
    end

    local cost = math.max(0, target.price - currentTier.price)
    if Player.Functions.GetMoney('cash') < cost then
        return reply(false, locale('not_enough_cash'), 'error')
    end
    if cost > 0 and not Player.Functions.RemoveMoney('cash', cost, 'house-storage-upgrade') then return reply(false) end

    local updated = MySQL.update.await('UPDATE rsg_housing SET storage_tier = ? WHERE houseid = ? AND citizenid = ? AND storage_tier = ?', {
        level, house.houseid, Player.PlayerData.citizenid, current
    })
    if updated == 0 then
        if cost > 0 then Player.Functions.AddMoney('cash', cost, 'house-storage-upgrade-refund') end
        return reply(false)
    end

    payGovernor(house.region, cost, house.houseid, 'storage upgrade')
    return reply(true, locale('storage_upgraded', locale('storage_tier_' .. target.key), cost), 'success')
end)

---------------------------------------------
-- rename house (tenant only, empty name resets to the default)
---------------------------------------------
local function cleanHouseName(value)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('~', ''):gsub('[%c<>]', ''):gsub('%s+', ' ')
    value = value:match('^%s*(.-)%s*$')
    return value
end

registerCallback('rsg-housing:server:renameHouse', function(src, houseid, value)
    if onCooldown(src, 2000) then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return reply(false) end

    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house then return reply(false, locale('not_tenant'), 'error') end

    local name = cleanHouseName(value)
    if not name then return reply(false) end
    if name ~= '' and (#name < Config.HouseNameMin or #name > Config.HouseNameMax) then
        return reply(false, locale('rename_invalid', Config.HouseNameMin, Config.HouseNameMax), 'error')
    end

    local label = name ~= '' and name or nil
    MySQL.update.await('UPDATE rsg_housing SET custom_name = ? WHERE houseid = ? AND citizenid = ?', { label, house.houseid, Player.PlayerData.citizenid })

    if RentedHouses[house.houseid] then RentedHouses[house.houseid].label = label end
    syncRentedHouses()

    if label then
        return reply(true, locale('rename_done', label), 'success')
    end
    return reply(true, locale('rename_reset', HousesById[house.houseid].name), 'success')
end)

---------------------------------------------
-- end tenancy (no refund)
---------------------------------------------
registerCallback('rsg-housing:server:endTenancy', function(src, houseid)
    if onCooldown(src, 2000) then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return reply(false) end

    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house then return reply(false, locale('not_tenant'), 'error') end
    if not isNear(src, HousesById[house.houseid].menucoords, Config.InteractDistance) then
        return reply(false, locale('too_far'), 'error')
    end

    -- optional refund of the unused part of the paid month
    local refund = 0
    local percent = tonumber(Config.EndTenancyRefundPercent) or 0
    local hoursLeft = tonumber(house.hours_left) or 0
    if percent > 0 and hoursLeft > 0 then
        refund = math.floor(math.max(0, house.rent) * math.min(hoursLeft / 720, 1) * math.min(percent, 100) / 100)
    end

    local moved = endTenancy(house.houseid, nil, Player.PlayerData.citizenid)
    syncRentedHouses()
    if refund > 0 then
        Player.Functions.AddMoney('cash', refund, 'house-rent-refund')
    end

    local name = HousesById[house.houseid].name
    local msg = refund > 0 and locale('tenancy_ended_refund', name, refund) or locale('tenancy_ended', name)
    if moved then msg = msg .. ' ' .. locale('retrieval_hint', Config.RetrievalDays) end
    return reply(true, msg, 'success')
end)

---------------------------------------------
-- guests
---------------------------------------------
registerCallback('rsg-housing:server:addGuest', function(src, houseid, targetCid, hours)
    if onCooldown(src) then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(targetCid) ~= 'string' then return reply(false) end

    targetCid = targetCid:upper():gsub('%s+', '')
    if targetCid == '' or #targetCid > 50 then
        return reply(false, locale('guest_not_found'), 'error')
    end
    if targetCid == Player.PlayerData.citizenid then
        return reply(false, locale('guest_self'), 'error')
    end

    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house then return reply(false, locale('not_tenant'), 'error') end

    hours = math.tointeger(tonumber(hours)) or 0
    if not GUEST_DURATION_SET[hours] then hours = 0 end

    local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { targetCid })
    if not row then
        return reply(false, locale('guest_not_found'), 'error')
    end
    local info = type(row.charinfo) == 'string' and json.decode(row.charinfo) or row.charinfo
    local guestName = info and info.firstname and (info.firstname .. ' ' .. (info.lastname or '')) or targetCid

    if getAccess(targetCid, house.houseid) then
        return reply(false, locale('guest_exists', guestName), 'error')
    end
    local guestCount = MySQL.scalar.await('SELECT COUNT(*) FROM rsg_housekeys WHERE houseid = ? AND guest = 1 AND (expires IS NULL OR expires > NOW())', { house.houseid }) or 0
    if guestCount >= Config.MaxGuests then
        return reply(false, locale('guest_limit', Config.MaxGuests), 'error')
    end

    giveKey(house.houseid, targetCid, hours)
    notifyIfOnline(targetCid, locale('rent_title'), locale('key_received', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname, HousesById[house.houseid].name), 'success')

    if hours > 0 then
        local untilText = MySQL.scalar.await("SELECT DATE_FORMAT(expires, '%d/%m/%Y %H:%i') FROM rsg_housekeys WHERE houseid = ? AND citizenid = ?", { house.houseid, targetCid })
        return reply(true, locale('guest_added_temp', guestName, untilText), 'success')
    end
    return reply(true, locale('guest_added', guestName), 'success')
end)

-- tenant turns one guest permission on or off
registerCallback('rsg-housing:server:setGuestPermission', function(src, houseid, targetCid, perm, allowed)
    if onCooldown(src, 400, 'perm') then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(targetCid) ~= 'string' or #targetCid > 50 or not GUEST_PERM_SET[perm] then return reply(false) end

    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house then return reply(false, locale('not_tenant'), 'error') end

    -- column name comes from the fixed GUEST_PERMS list, never from the client string directly
    local updated = MySQL.update.await(('UPDATE rsg_housekeys SET perm_%s = ? WHERE houseid = ? AND citizenid = ? AND guest = 1'):format(perm), {
        allowed == true and 1 or 0, house.houseid, targetCid
    })
    if updated == 0 then return reply(false) end
    return reply(true, locale(allowed == true and 'guest_perm_on' or 'guest_perm_off', locale('perm_' .. perm)), allowed == true and 'success' or 'inform')
end)

-- search characters by name (or exact citizen id) for the add-guest box
registerCallback('rsg-housing:server:searchPlayers', function(src, houseid, query)
    if onCooldown(src, 300, 'search') then return nil end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(query) ~= 'string' then return {} end

    query = query:gsub('[%c<>~]', ''):match('^%s*(.-)%s*$'):sub(1, 40)
    if #query < Config.GuestSearchMin then return {} end

    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house then return {} end

    -- skip the tenant and anyone who already has a key to this house
    local skip = { [Player.PlayerData.citizenid] = true }
    local keys = MySQL.query.await('SELECT citizenid FROM rsg_housekeys WHERE houseid = ?', { house.houseid }) or {}
    for _, key in ipairs(keys) do skip[key.citizenid] = true end

    local results = {}
    local scope = Config.GuestSearchScope or 'nearby'

    -- 'nearby' / 'online': only characters that are logged in (and close by), no database scan
    if scope ~= 'all' then
        local lowered, upper = query:lower(), query:upper()
        for psrc, target in pairs(RSGCore.Functions.GetRSGPlayers()) do
            local cid = target.PlayerData.citizenid
            if #results < Config.GuestSearchResults and not skip[cid] then
                local ci = target.PlayerData.charinfo or {}
                local name = (ci.firstname or '') .. ' ' .. (ci.lastname or '')
                if name:lower():find(lowered, 1, true) or cid == upper then
                    if scope ~= 'nearby' or isNear(src, GetEntityCoords(GetPlayerPed(psrc)), Config.GuestSearchDistance) then
                        results[#results + 1] = { citizenid = cid, name = name }
                    end
                end
            end
        end
        return results
    end

    local like = '%' .. query:gsub('[%%_\\]', '\\%0') .. '%'
    local rows = MySQL.query.await([[
        SELECT citizenid, charinfo FROM players
        WHERE citizenid = ?
           OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ?
           OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?
           OR CONCAT(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))) LIKE ?
        LIMIT ?
    ]], { query:upper(), like, like, like, Config.GuestSearchResults + 5 }) or {}

    for _, row in ipairs(rows) do
        if not skip[row.citizenid] and #results < Config.GuestSearchResults then
            local info = type(row.charinfo) == 'string' and json.decode(row.charinfo) or row.charinfo
            if info and info.firstname then
                results[#results + 1] = { citizenid = row.citizenid, name = info.firstname .. ' ' .. (info.lastname or '') }
            end
        end
    end
    return results
end)

registerCallback('rsg-housing:server:removeGuest', function(src, houseid, targetCid)
    if onCooldown(src) then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(targetCid) ~= 'string' then return reply(false) end

    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house then return reply(false, locale('not_tenant'), 'error') end

    local guestName = targetCid
    local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { targetCid })
    local info = row and (type(row.charinfo) == 'string' and json.decode(row.charinfo) or row.charinfo)
    if info and info.firstname then guestName = info.firstname .. ' ' .. (info.lastname or '') end

    if revokeKey(house.houseid, targetCid) then
        notifyIfOnline(targetCid, locale('rent_title'), locale('key_removed', HousesById[house.houseid].name), 'inform')
        return reply(true, locale('guest_removed', guestName), 'success')
    end
    return reply(false)
end)

---------------------------------------------
-- wardrobe: saved outfits from rsg-character (playeroutfit table)
---------------------------------------------
registerCallback('rsg-housing:server:outfits', function(src, houseid, action, id)
    local Player = RSGCore.Functions.GetPlayer(src)
    local house = HousesById[houseid]
    if not Player or not house then return { available = false } end
    if not hasPermission(Player.PlayerData.citizenid, houseid, 'wardrobe') then return { available = false, denied = true } end
    if not isNear(src, house.menucoords, Config.InteractDistance) then return { available = false } end

    local citizenid = Player.PlayerData.citizenid
    id = math.tointeger(tonumber(id))

    if action == 'wear' and id then
        if onCooldown(src, 1500, 'outfit') then return nil end
        local clothes = MySQL.scalar.await('SELECT clothes FROM playeroutfit WHERE id = ? AND citizenid = ?', { id, citizenid })
        if not clothes then return { available = true, error = locale('outfit_not_found') } end
        -- same as rsg-character: the worn outfit becomes the saved skin clothes
        MySQL.update.await('UPDATE playerskins SET clothes = ? WHERE citizenid = ?', { clothes, citizenid })
        return { available = true, wear = json.decode(clothes) }
    end

    local rows = MySQL.query.await('SELECT * FROM playeroutfit WHERE citizenid = ? ORDER BY id', { citizenid }) or {}
    local outfits = {}
    for _, row in ipairs(rows) do
        outfits[#outfits + 1] = { id = row.id, name = row.name, default = isTrue(row.is_default) }
    end
    table.sort(outfits, function(x, y)
        if x.default ~= y.default then return x.default end
        return x.id < y.id
    end)
    return { available = true, outfits = outfits }
end)

---------------------------------------------
-- mailbox: read / delete your rsg-telegram inbox from the house (sending stays at the post office)
---------------------------------------------
local function canUseMailbox(src, houseid)
    local Player = RSGCore.Functions.GetPlayer(src)
    local house = HousesById[houseid]
    if not Player or not house or not telegramsAvailable() then return nil end
    if not hasPermission(Player.PlayerData.citizenid, houseid, 'mailbox') then return nil end
    if not isNear(src, house.menucoords, Config.InteractDistance) then return nil end
    return Player.PlayerData.citizenid
end

registerCallback('rsg-housing:server:mailbox', function(src, houseid, action, id)
    local citizenid = canUseMailbox(src, houseid)
    if not citizenid then return { available = false } end

    id = math.tointeger(tonumber(id))
    if action == 'read' and id then
        if onCooldown(src, 250, 'mail') then return nil end
        MySQL.update.await('UPDATE rsg_telegrams SET is_read = 1 WHERE id = ? AND citizenid = ?', { id, citizenid })
    elseif action == 'delete' and id then
        if onCooldown(src, 500, 'mail') then return nil end
        MySQL.update.await('DELETE FROM rsg_telegrams WHERE id = ? AND citizenid = ?', { id, citizenid })
    end

    local mail = MySQL.query.await([[
        SELECT id, sender_name, subject, message, is_read, UNIX_TIMESTAMP(sent_at) AS sent_at
        FROM rsg_telegrams WHERE citizenid = ? ORDER BY sent_at DESC, id DESC LIMIT ?
    ]], { citizenid, Config.MailboxMax }) or {}
    for i = 1, #mail do mail[i].is_read = isTrue(mail[i].is_read) end
    return { available = true, mail = mail }
end)

---------------------------------------------
-- storage
---------------------------------------------
RegisterNetEvent('rsg-housing:server:openStorage', function(houseid)
    local src = source
    if onCooldown(src, 1000, 'storage') then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local house = HousesById[houseid]
    if not house then return end

    if not hasPermission(Player.PlayerData.citizenid, houseid, 'storage') then
        return notify(src, locale('storage_title'), locale('no_permission'), 'error')
    end
    if not isNear(src, house.menucoords, Config.InteractDistance) then
        return notify(src, locale('storage_title'), locale('too_far'), 'error')
    end

    openStash(src, houseid)
end)

---------------------------------------------
-- doors (state kept in memory: rented houses lock on restart, vacant houses stay open)
---------------------------------------------
registerCallback('rsg-housing:server:toggleDoor', function(source, doorid)
    local src = source
    doorid = tostring(doorid)
    local door = DoorsById[doorid]
    if not door or onCooldown(src, 1500) then return false end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    if not isNear(src, door.doorcoords, 3.0) then return false end

    if not RentedHouses[door.houseid] then
        notify(src, door.name, locale('door_viewing'), 'inform')
        return false
    end

    if not hasPermission(Player.PlayerData.citizenid, door.houseid, 'doors') then
        local tenant = RentedHouses[door.houseid]
        if Config.AllowKnock and tenant and not onCooldown(src, (Config.KnockCooldown or 20) * 1000, 'knock') then
            notify(src, door.name, locale('door_knock'), 'inform')
            local label = tenant.label or (HousesById[door.houseid] and HousesById[door.houseid].name) or door.houseid
            notifyIfOnline(tenant.citizenid, label, locale('knock_notice', label), 'inform')
        else
            notify(src, door.name, locale('no_access'), 'error')
        end
        return false
    end

    local newState = DoorStates[doorid] == 1 and 0 or 1
    DoorStates[doorid] = newState
    TriggerClientEvent('rsg-housing:client:SetDoorState', -1, doorid, newState)
    return true
end)

---------------------------------------------
-- login reminder: rent due soon or overdue
---------------------------------------------
RegisterNetEvent('rsg-housing:server:loginCheck', function()
    local src = source
    if not Config.LoginRentReminder or onCooldown(src, 60000, 'login') then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local rows = MySQL.query.await([[
        SELECT houseid, DATE_FORMAT(rent_due, '%d/%m/%Y') AS due_text, (rent_due < NOW()) AS overdue
        FROM rsg_housing
        WHERE citizenid = ? AND rented = 1 AND rent_due < DATE_ADD(NOW(), INTERVAL ? DAY)
    ]], { Player.PlayerData.citizenid, Config.ReminderDays }) or {}

    for _, row in ipairs(rows) do
        local cfg = HousesById[row.houseid]
        local name = cfg and cfg.name or row.houseid
        if isTrue(row.overdue) then
            notify(src, locale('rent_title'), locale('login_overdue', name, row.due_text, Config.GracePeriodDays), 'error')
        else
            notify(src, locale('rent_title'), locale('login_due', name, row.due_text), 'warning')
        end
    end
end)

---------------------------------------------
-- belongings kept after a tenancy ended (/housebelongings at the old house)
---------------------------------------------
RSGCore.Commands.Add('housebelongings', locale('retrieval_help'), {}, false, function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or onCooldown(src, 2000, 'belongings') then return end

    local rows = MySQL.query.await('SELECT houseid FROM rsg_housing_retrieval WHERE citizenid = ? AND expires > NOW()', { Player.PlayerData.citizenid }) or {}
    if #rows == 0 then
        return notify(src, locale('storage_title'), locale('retrieval_none'), 'error')
    end

    local biggest = Config.StorageTiers[#Config.StorageTiers]
    for _, row in ipairs(rows) do
        local cfg = HousesById[row.houseid]
        if cfg and isNear(src, cfg.menucoords, Config.InteractDistance + 10.0) then
            exports['rsg-inventory']:OpenInventory(src, retrievalId(row.houseid, Player.PlayerData.citizenid), {
                label = locale('retrieval_label', cfg.name), maxweight = biggest.weight, slots = biggest.slots
            })
            return
        end
    end
    notify(src, locale('storage_title'), locale('retrieval_far'), 'error')
end)

---------------------------------------------
-- decorating: furniture placed with rsg-gizmo, saved per house
---------------------------------------------
local function propPayload(row)
    local def = DecorByKey[row.model_key]
    if not def then return nil end
    return {
        id = row.id, key = row.model_key, model = def.model,
        coords = { x = row.x, y = row.y, z = row.z },
        rot = { x = row.rx, y = row.ry, z = row.rz }
    }
end

local function toVec(v)
    local t = type(v)
    if t ~= 'table' and t ~= 'vector3' then return nil end
    local x, y, z = tonumber(v.x), tonumber(v.y), tonumber(v.z)
    if not x or not y or not z then return nil end
    for _, n in ipairs({ x, y, z }) do
        if n ~= n or n > 100000 or n < -100000 then return nil end
    end
    return vector3(x, y, z)
end

-- validates a client placement (position near the house, gizmo checks) and returns pos, rot or nil, errorMessage
local function checkPlacement(src, houseid, coords, rot)
    local pos = toVec(coords)
    if not pos then return nil, locale('prop_invalid') end
    if #(pos - HousesById[houseid].menucoords) > Config.PropPlaceRadius then return nil, locale('prop_invalid') end

    local ok, valid = pcall(function() return exports['rsg-gizmo']:IsPlacementValid(src, pos, 5.0) end)
    if ok and not valid then return nil, locale('prop_invalid') end

    local okRot, clean = pcall(function() return exports['rsg-gizmo']:SanitiseRotation(rot) end)
    local r = (okRot and toVec(clean)) or toVec(rot) or vector3(0.0, 0.0, 0.0)
    return pos, r
end

registerCallback('rsg-housing:server:getProps', function(src, houseid)
    if onCooldown(src, 500, 'getprops') then return nil end
    local Player = RSGCore.Functions.GetPlayer(src)
    local house = type(houseid) == 'string' and HousesById[houseid]
    if not Player or not house or not Config.Decorating then return {} end
    if not isNear(src, house.menucoords, Config.PropStreamDistance + 100.0) then return {} end

    local rows = MySQL.query.await('SELECT id, model_key, x, y, z, rx, ry, rz FROM rsg_housing_props WHERE houseid = ?', { houseid }) or {}
    local list = {}
    for _, row in ipairs(rows) do
        local payload = propPayload(row)
        if payload then list[#list + 1] = payload end
    end
    return list
end)

registerCallback('rsg-housing:server:prePlaceProp', function(src, houseid, key)
    if onCooldown(src, 500, 'preprop') then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Config.Decorating then return reply(false) end
    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house then return reply(false, locale('not_tenant'), 'error') end
    local def = type(key) == 'string' and DecorByKey[key]
    if not def then return reply(false, locale('prop_invalid'), 'error') end
    if not isNear(src, HousesById[houseid].menucoords, Config.PropPlaceRadius) then return reply(false, locale('too_far'), 'error') end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM rsg_housing_props WHERE houseid = ?', { houseid }) or 0
    if count >= Config.MaxPropsPerHouse then return reply(false, locale('prop_limit', Config.MaxPropsPerHouse), 'error') end
    if Player.Functions.GetMoney('cash') < (def.price or 0) then return reply(false, locale('not_enough_cash'), 'error') end
    return reply(true)
end)

registerCallback('rsg-housing:server:placeProp', function(src, houseid, key, coords, rot)
    if onCooldown(src, 1000, 'prop') then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Config.Decorating then return reply(false) end
    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house then return reply(false, locale('not_tenant'), 'error') end
    local def = type(key) == 'string' and DecorByKey[key]
    if not def then return reply(false, locale('prop_invalid'), 'error') end

    local pos, r = checkPlacement(src, houseid, coords, rot)
    if not pos then return reply(false, r, 'error') end

    local price = math.max(0, def.price or 0)
    if Player.Functions.GetMoney('cash') < price then return reply(false, locale('not_enough_cash'), 'error') end
    if price > 0 and not Player.Functions.RemoveMoney('cash', price, 'house-decor') then return reply(false) end

    -- the count check is part of the insert, so two quick placements can't pass the limit
    local id = MySQL.insert.await([[
        INSERT INTO rsg_housing_props (houseid, model_key, x, y, z, rx, ry, rz)
        SELECT ?, ?, ?, ?, ?, ?, ?, ? FROM DUAL
        WHERE (SELECT COUNT(*) FROM rsg_housing_props WHERE houseid = ?) < ?
    ]], { houseid, key, pos.x, pos.y, pos.z, r.x, r.y, r.z, houseid, Config.MaxPropsPerHouse })
    if not id or id == 0 then
        if price > 0 then Player.Functions.AddMoney('cash', price, 'house-decor-refund') end
        return reply(false, locale('prop_limit', Config.MaxPropsPerHouse), 'error')
    end

    TriggerClientEvent('rsg-housing:client:propAdded', -1, houseid, {
        id = id, key = key, model = def.model,
        coords = { x = pos.x, y = pos.y, z = pos.z }, rot = { x = r.x, y = r.y, z = r.z }
    })
    return reply(true, locale('prop_placed', def.label, price), 'success')
end)

registerCallback('rsg-housing:server:moveProp', function(src, houseid, id, coords, rot)
    if onCooldown(src, 800, 'prop') then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Config.Decorating then return reply(false) end
    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house then return reply(false, locale('not_tenant'), 'error') end
    id = math.tointeger(tonumber(id))
    if not id then return reply(false) end

    local pos, r = checkPlacement(src, houseid, coords, rot)
    if not pos then return reply(false, r, 'error') end

    local updated = MySQL.update.await('UPDATE rsg_housing_props SET x = ?, y = ?, z = ?, rx = ?, ry = ?, rz = ? WHERE id = ? AND houseid = ?',
        { pos.x, pos.y, pos.z, r.x, r.y, r.z, id, houseid })
    if updated == 0 then return reply(false) end

    TriggerClientEvent('rsg-housing:client:propMoved', -1, houseid, id, { x = pos.x, y = pos.y, z = pos.z }, { x = r.x, y = r.y, z = r.z })
    return reply(true, locale('prop_moved'), 'success')
end)

registerCallback('rsg-housing:server:removeProp', function(src, houseid, id)
    if onCooldown(src, 800, 'prop') then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Config.Decorating then return reply(false) end
    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house then return reply(false, locale('not_tenant'), 'error') end
    id = math.tointeger(tonumber(id))
    if not id then return reply(false) end

    local key = MySQL.scalar.await('SELECT model_key FROM rsg_housing_props WHERE id = ? AND houseid = ?', { id, houseid })
    if not key then return reply(false) end
    if MySQL.update.await('DELETE FROM rsg_housing_props WHERE id = ? AND houseid = ?', { id, houseid }) == 0 then return reply(false) end

    local def = DecorByKey[key]
    local refund = def and math.floor((def.price or 0) * math.min(Config.PropRefundPercent or 0, 100) / 100) or 0
    if refund > 0 then Player.Functions.AddMoney('cash', refund, 'house-decor-refund') end

    TriggerClientEvent('rsg-housing:client:propRemoved', -1, houseid, id)
    return reply(true, locale('prop_removed', def and def.label or key, refund), 'success')
end)

---------------------------------------------
-- admin panel (/houseadmin)
---------------------------------------------
local function isAdmin(src)
    return src and src > 0 and RSGCore.Functions.HasPermission(src, Config.AdminPermission) == true
end

local function adminLog(src, message)
    local name = GetPlayerName(src) or ('id ' .. tostring(src))
    TriggerEvent('rsg-log:server:CreateLog', 'rsghousing', locale('log_admin_title'), 'orange', ('%s: %s'):format(name, message))
    if Config.Debug then print(('[rsg-housing] admin %s: %s'):format(name, message)) end
end

local ADMIN_SELECT = [[
    SELECT houseid, region, citizenid, fullname, rented, rent, custom_name, storage_tier,
           DATE_FORMAT(rent_due, '%Y-%m-%d %H:%i') AS due_text,
           (rent_due < NOW()) AS overdue,
           TIMESTAMPDIFF(HOUR, NOW(), rent_due) AS hours_left
    FROM rsg_housing
]]

local function adminRow(row, guestCount)
    local cfg = HousesById[row.houseid]
    local rented = isTrue(row.rented)
    local info = RentedHouses[row.houseid]
    local locked = false
    for doorid, door in pairs(DoorsById) do
        if door.houseid == row.houseid and DoorStates[doorid] == 1 then locked = true break end
    end
    return {
        houseid     = row.houseid,
        name        = cfg and cfg.name or row.houseid,
        customName  = row.custom_name,
        region      = row.region,
        rent        = row.rent,
        rented      = rented,
        tenant      = rented and row.fullname or nil,
        citizenid   = rented and row.citizenid or nil,
        due         = rented and row.due_text or nil,
        overdue     = rented and isTrue(row.overdue) or false,
        hoursLeft   = rented and row.hours_left or nil,
        storageTier = (getStorageTier(row.storage_tier)),
        guests      = guestCount or 0,
        home        = info and info.home == true or false,
        locked      = locked,
        inConfig    = cfg ~= nil,
    }
end

local function adminList()
    local rows = MySQL.query.await(ADMIN_SELECT .. ' ORDER BY id') or {}
    local counts = {}
    for _, c in ipairs(MySQL.query.await('SELECT houseid, COUNT(*) AS n FROM rsg_housekeys WHERE guest = 1 GROUP BY houseid') or {}) do
        counts[c.houseid] = c.n
    end
    local list = {}
    for i = 1, #rows do list[i] = adminRow(rows[i], counts[rows[i].houseid]) end
    return list
end

local function adminHouse(houseid)
    local row = MySQL.single.await(ADMIN_SELECT .. ' WHERE houseid = ?', { houseid })
    if not row then return nil end
    local guests = getGuests(houseid)
    local house = adminRow(row, #guests)
    house.guestList = guests
    return house
end

local function adminReply(ok, msg, houseid)
    return { ok = ok, msg = msg, type = ok and 'success' or 'error', house = houseid and adminHouse(houseid) or nil }
end

local AdminActions = {}

AdminActions.setRent = function(src, houseid, data)
    local rent = math.tointeger(tonumber(data.rent))
    if not rent or rent < 0 or rent > Config.MaxRent then return adminReply(false, locale('invalid_amount')) end
    MySQL.update.await('UPDATE rsg_housing SET rent = ? WHERE houseid = ?', { rent, houseid })
    adminLog(src, ('set rent of %s to $%s'):format(houseid, rent))
    return adminReply(true, locale('admin_rent_set', houseid, rent), houseid)
end

AdminActions.shiftDue = function(src, houseid, data)
    local months = math.tointeger(tonumber(data.months))
    if not months or months == 0 or math.abs(months) > 12 then return adminReply(false, locale('invalid_amount')) end
    local updated = MySQL.update.await('UPDATE rsg_housing SET rent_due = DATE_ADD(rent_due, INTERVAL ? MONTH), reminder_sent = 0 WHERE houseid = ? AND rented = 1', { months, houseid })
    if updated == 0 then return adminReply(false, locale('admin_not_rented')) end
    adminLog(src, ('moved rent due of %s by %s month(s)'):format(houseid, months))
    return adminReply(true, locale('admin_due_moved', houseid), houseid)
end

AdminActions.setDue = function(src, houseid, data)
    local date = type(data.date) == 'string' and data.date:match('^(%d%d%d%d%-%d%d%-%d%d)$')
    if not date then return adminReply(false, locale('admin_bad_date')) end
    -- a date in the past would get the tenant evicted on the next rent check
    if date < os.date('%Y-%m-%d') then return adminReply(false, locale('admin_past_date')) end
    local updated = MySQL.update.await("UPDATE rsg_housing SET rent_due = CONCAT(?, ' ', TIME(COALESCE(rent_due, NOW()))), reminder_sent = 0 WHERE houseid = ? AND rented = 1", { date, houseid })
    if updated == 0 then return adminReply(false, locale('admin_not_rented')) end
    adminLog(src, ('set rent due of %s to %s'):format(houseid, date))
    return adminReply(true, locale('admin_due_moved', houseid), houseid)
end

AdminActions.setStorage = function(src, houseid, data)
    local level = math.tointeger(tonumber(data.level))
    if not level or not Config.StorageTiers[level] then return adminReply(false, locale('storage_upgrade_invalid')) end
    if storageUsedSlots(houseid) > Config.StorageTiers[level].slots then
        return adminReply(false, locale('admin_storage_too_full'))
    end
    MySQL.update.await('UPDATE rsg_housing SET storage_tier = ? WHERE houseid = ?', { level, houseid })
    adminLog(src, ('set storage of %s to tier %s'):format(houseid, level))
    return adminReply(true, locale('admin_storage_set', houseid, locale('storage_tier_' .. Config.StorageTiers[level].key)), houseid)
end

AdminActions.resetName = function(src, houseid)
    MySQL.update.await('UPDATE rsg_housing SET custom_name = NULL WHERE houseid = ?', { houseid })
    if RentedHouses[houseid] then RentedHouses[houseid].label = nil end
    syncRentedHouses()
    adminLog(src, ('reset the name of %s'):format(houseid))
    return adminReply(true, locale('admin_name_reset', houseid), houseid)
end

AdminActions.removeGuest = function(src, houseid, data)
    if type(data.citizenid) ~= 'string' then return adminReply(false) end
    if not revokeKey(houseid, data.citizenid) then return adminReply(false) end
    adminLog(src, ('removed guest %s from %s'):format(data.citizenid, houseid))
    return adminReply(true, locale('admin_guest_removed', data.citizenid), houseid)
end

AdminActions.doors = function(src, houseid, data)
    local state = data.locked == true and 1 or 0
    setHouseDoors(houseid, state)
    adminLog(src, ('%s the doors of %s'):format(state == 1 and 'locked' or 'unlocked', houseid))
    return adminReply(true, locale(state == 1 and 'admin_doors_locked' or 'admin_doors_unlocked', houseid), houseid)
end

AdminActions.evict = function(src, houseid, data)
    local row, moved = evictHouse(houseid, data.purge == true, 'admin')
    if not row then return adminReply(false, locale('admin_not_rented')) end
    adminLog(src, ('evicted %s (%s) from %s%s'):format(row.fullname, row.citizenid, houseid, data.purge == true and ', storage deleted' or (moved and ', belongings kept' or '')))
    return adminReply(true, locale('admin_evicted', row.fullname, houseid), houseid)
end

AdminActions.teleport = function(src, houseid)
    local cfg = HousesById[houseid]
    if not cfg then return adminReply(false, locale('admin_no_config')) end
    adminLog(src, ('teleported to %s'):format(houseid))
    return { ok = true, teleport = cfg.menucoords }
end

AdminActions.storage = function(src, houseid)
    local cfg = HousesById[houseid]
    if not cfg then return adminReply(false, locale('admin_no_config')) end
    adminLog(src, ('opened the storage of %s'):format(houseid))
    openStash(src, houseid)
    return { ok = true, closed = true }
end

registerCallback('rsg-housing:server:admin', function(src, action, houseid, data)
    if not isAdmin(src) then return { ok = false, denied = true } end
    if action == 'list' then return { ok = true, houses = adminList() } end

    if type(houseid) ~= 'string' or #houseid > 20 then return adminReply(false) end
    if action == 'house' then
        local house = adminHouse(houseid)
        return { ok = house ~= nil, house = house }
    end

    local handler = AdminActions[action]
    if not handler then return adminReply(false) end
    if onCooldown(src, 500, 'admin') then return { ok = false } end
    if not MySQL.scalar.await('SELECT 1 FROM rsg_housing WHERE houseid = ?', { houseid }) then return adminReply(false) end
    return handler(src, houseid, type(data) == 'table' and data or {})
end)

RSGCore.Commands.Add('houseadmin', locale('admin_command_help'), {}, false, function(source)
    if not isAdmin(source) then return end
    TriggerClientEvent('rsg-housing:client:openAdmin', source)
end, Config.AdminPermission)

---------------------------------------------
-- rent check: reminders and evictions
---------------------------------------------
RSGCore.Functions.CreateCron(Config.RentCheckCronJob, function()
    -- reminders (sent once per rent period)
    local dueSoon = MySQL.query.await([[
        SELECT houseid, citizenid, fullname, DATE_FORMAT(rent_due, '%d/%m/%Y') AS due_text
        FROM rsg_housing
        WHERE rented = 1 AND reminder_sent = 0 AND rent_due < DATE_ADD(NOW(), INTERVAL ? DAY)
    ]], { Config.ReminderDays }) or {}

    for _, row in ipairs(dueSoon) do
        local name = HousesById[row.houseid] and HousesById[row.houseid].name or row.houseid
        sendTelegram(row.citizenid, row.fullname, locale('reminder_subject'), locale('reminder_message', name, row.due_text, Config.GracePeriodDays))
        notifyIfOnline(row.citizenid, locale('rent_title'), locale('reminder_message', name, row.due_text, Config.GracePeriodDays), 'warning')
        MySQL.update('UPDATE rsg_housing SET reminder_sent = 1 WHERE houseid = ?', { row.houseid })
    end

    -- evictions (past the due date + grace period)
    local overdue = MySQL.query.await([[
        SELECT houseid, citizenid, fullname FROM rsg_housing
        WHERE rented = 1 AND rent_due < DATE_SUB(NOW(), INTERVAL ? DAY)
    ]], { Config.GracePeriodDays }) or {}

    for _, row in ipairs(overdue) do
        local name = HousesById[row.houseid] and HousesById[row.houseid].name or row.houseid
        local moved = endTenancy(row.houseid, false, row.citizenid, 'evicted')
        local evictMsg = locale('eviction_message', name)
        if moved then evictMsg = evictMsg .. ' ' .. locale('retrieval_hint', Config.RetrievalDays) end
        sendTelegram(row.citizenid, row.fullname, locale('eviction_subject'), evictMsg)
        notifyIfOnline(row.citizenid, locale('rent_title'), evictMsg, 'error')
        TriggerEvent('rsg-log:server:CreateLog', 'rsghousing', locale('log_eviction_title'), 'red', locale('log_eviction', row.fullname, row.houseid))
    end

    if #overdue > 0 then syncRentedHouses() end

    -- time-limited guest keys and belongings that were not collected in time
    MySQL.update('DELETE FROM rsg_housekeys WHERE expires IS NOT NULL AND expires <= NOW()')
    for _, old in ipairs(MySQL.query.await('SELECT id, houseid, citizenid FROM rsg_housing_retrieval WHERE expires <= NOW()') or {}) do
        stashPurge(retrievalId(old.houseid, old.citizenid))
        MySQL.update.await('DELETE FROM rsg_housing_retrieval WHERE id = ?', { old.id })
    end
    if Config.Debug then
        print(('[rsg-housing] rent check: %s reminders, %s evictions'):format(#dueSoon, #overdue))
    end
end)

---------------------------------------------
-- public API (see DOCS.md): exports + hook events
-- Hook events are server-side only (AddEventHandler), clients cannot trigger them:
--   rsg-housing:server:houseRented   (houseid, citizenid, rent)
--   rsg-housing:server:rentPaid      (houseid, citizenid, rent)
--   rsg-housing:server:tenancyEnded  (houseid, citizenid, reason)   reason: left | evicted | admin | api
--   rsg-housing:server:guestAdded    (houseid, citizenid, hours)    hours 0 = until removed
--   rsg-housing:server:guestRemoved  (houseid, citizenid)
---------------------------------------------
local function validHouse(houseid)
    return type(houseid) == 'string' and HousesById[houseid] ~= nil
end

local function publicHouse(row)
    local cfg = HousesById[row.houseid]
    local rented = isTrue(row.rented)
    local live = RentedHouses[row.houseid]
    return {
        houseid     = row.houseid,
        name        = cfg and cfg.name or row.houseid,
        customName  = row.custom_name,
        region      = row.region,
        rent        = row.rent,
        rented      = rented,
        citizenid   = rented and row.citizenid or nil,
        tenant      = rented and row.fullname or nil,
        due         = rented and row.due_text or nil,
        overdue     = rented and isTrue(row.overdue) or false,
        storageTier = (getStorageTier(row.storage_tier)),
        home        = live and live.home == true or false,
        coords      = cfg and cfg.menucoords or nil,
    }
end

exports('GetHouse', function(houseid)
    local row = getHouse(houseid)
    return row and publicHouse(row) or nil
end)

exports('GetHouses', function()
    local list = {}
    for _, row in ipairs(MySQL.query.await(HOUSE_SELECT .. ' ORDER BY id') or {}) do
        if HousesById[row.houseid] then list[#list + 1] = publicHouse(row) end
    end
    return list
end)

exports('IsHouseRented', function(houseid)
    return validHouse(houseid) and RentedHouses[houseid] ~= nil
end)

-- returns citizenid, full name (or nil)
exports('GetTenant', function(houseid)
    local info = validHouse(houseid) and RentedHouses[houseid]
    if not info then return nil end
    return info.citizenid, info.owner
end)

-- house ids the character rents
exports('GetPlayerHouses', function(citizenid)
    local list = {}
    if type(citizenid) ~= 'string' then return list end
    for houseid, info in pairs(RentedHouses) do
        if info.citizenid == citizenid then list[#list + 1] = houseid end
    end
    table.sort(list)
    return list
end)

-- 'tenant' | 'guest' | nil
exports('GetHouseAccess', function(citizenid, houseid)
    if type(citizenid) ~= 'string' or not validHouse(houseid) then return nil end
    return getAccess(citizenid, houseid)
end)

-- perm: 'doors' | 'storage' | 'wardrobe' | 'mailbox' (nil = any access at all)
exports('HasHouseAccess', function(citizenid, houseid, perm)
    if type(citizenid) ~= 'string' or not validHouse(houseid) then return false end
    if perm == nil then return getAccess(citizenid, houseid) ~= nil end
    return hasPermission(citizenid, houseid, perm)
end)

-- closest house menu spot within radius (default Config.InteractDistance): houseid, distance
exports('GetHouseAt', function(coords, radius)
    if not coords or not coords.x then return nil end
    local pos = vector3(coords.x, coords.y, coords.z)
    radius = tonumber(radius) or Config.InteractDistance
    local best, bestDist
    for _, house in ipairs(Config.Houses) do
        local dist = #(pos - house.menucoords)
        if dist <= radius and (not bestDist or dist < bestDist) then best, bestDist = house.houseid, dist end
    end
    return best, bestDist
end)

exports('GetHouseByDoor', function(doorid)
    local door = DoorsById[tostring(doorid)]
    return door and door.houseid or nil
end)

-- true locked | false unlocked | nil unknown door
exports('GetDoorState', function(doorid)
    local state = DoorStates[tostring(doorid)]
    if state == nil then return nil end
    return state == 1
end)

exports('SetHouseDoors', function(houseid, locked)
    if not validHouse(houseid) then return false end
    setHouseDoors(houseid, locked and 1 or 0)
    return true
end)

-- { { citizenid, name, perms = { doors, storage, wardrobe, mailbox }, expires_text } }
exports('GetHouseGuests', function(houseid)
    if not validHouse(houseid) then return {} end
    return getGuests(houseid)
end)

-- opts: { hours = 0 (0 = until removed), perms = { doors = true, ... } }  ->  ok, reason
-- reasons: invalid_house | not_rented | invalid_player | is_tenant | exists | limit
exports('AddGuest', function(houseid, citizenid, opts)
    if not validHouse(houseid) then return false, 'invalid_house' end
    local tenant = RentedHouses[houseid]
    if not tenant then return false, 'not_rented' end
    if type(citizenid) ~= 'string' or citizenid == '' or #citizenid > 50 then return false, 'invalid_player' end
    citizenid = citizenid:upper()
    if citizenid == tenant.citizenid then return false, 'is_tenant' end
    if not MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ?', { citizenid }) then return false, 'invalid_player' end
    if getAccess(citizenid, houseid) then return false, 'exists' end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM rsg_housekeys WHERE houseid = ? AND guest = 1 AND (expires IS NULL OR expires > NOW())', { houseid }) or 0
    if count >= Config.MaxGuests then return false, 'limit' end

    opts = type(opts) == 'table' and opts or {}
    giveKey(houseid, citizenid, opts.hours, opts.perms)
    return true
end)

exports('RemoveGuest', function(houseid, citizenid)
    if not validHouse(houseid) or type(citizenid) ~= 'string' then return false end
    return revokeKey(houseid, citizenid)
end)

-- 0 .. Config.MaxRent
exports('SetHouseRent', function(houseid, rent)
    rent = math.tointeger(tonumber(rent))
    if not validHouse(houseid) or not rent or rent < 0 or rent > Config.MaxRent then return false end
    MySQL.update.await('UPDATE rsg_housing SET rent = ? WHERE houseid = ?', { rent, houseid })
    return true
end)

-- opts: { purge = false } purge = true deletes the storage instead of keeping it for retrieval
exports('EvictTenant', function(houseid, opts)
    if not validHouse(houseid) then return false end
    opts = type(opts) == 'table' and opts or {}
    return evictHouse(houseid, opts.purge == true, 'api') ~= nil
end)

-- no permission check: the calling script decides who may open it
exports('OpenHouseStorage', function(src, houseid)
    if not validHouse(houseid) or not GetPlayerName(src) then return false end
    openStash(src, houseid)
    return true
end)

exports('GetHouseProps', function(houseid)
    local list = {}
    if not validHouse(houseid) then return list end
    for _, row in ipairs(MySQL.query.await('SELECT id, model_key, x, y, z, rx, ry, rz FROM rsg_housing_props WHERE houseid = ?', { houseid }) or {}) do
        local payload = propPayload(row)
        if payload then list[#list + 1] = payload end
    end
    return list
end)
