local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

---------------------------------------------
-- state / lookups
---------------------------------------------
local RentedHouses = {} -- [houseid] = { owner = fullname, citizenid = citizenid, label = custom name, home = bool }
local DoorStates   = {} -- [doorid (string)] = 1 locked / 0 unlocked
local Cooldowns    = {}

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
    TriggerClientEvent('ox_lib:notify', src, {
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
    return MySQL.single.await('SELECT guest, ' .. PERM_COLUMNS .. ' FROM rsg_housekeys WHERE citizenid = ? AND houseid = ? LIMIT 1', { citizenid, houseid })
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

local function payGovernor(region, amount)
    local job = Config.GovernorJobs[region]
    if Config.EnableGovenor and job and amount > 0 then
        exports['rsg-bossmenu']:AddMoney(job, amount)
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

-- wipes the house stash in rsg-inventory memory and the database
local function purgeStorage(houseid)
    local stashId = getStashId(houseid)
    pcall(function()
        exports['rsg-inventory']:ClearStash(stashId)
        exports['rsg-inventory']:DeleteInventory(stashId)
    end)
    MySQL.update.await('DELETE FROM inventories WHERE identifier = ?', { stashId })
end

-- highest slot used in the house stash (so a smaller storage never hides items)
local function storageUsedSlots(houseid)
    local raw = MySQL.scalar.await('SELECT items FROM inventories WHERE identifier = ?', { getStashId(houseid) })
    local items = raw and json.decode(raw)
    local highest = 0
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

-- purge: true/false forces deleting the storage or keeping it, nil uses Config.PurgeStorageOnLeave
local function endTenancy(houseid, purge)
    MySQL.update.await("UPDATE rsg_housing SET citizenid = '0', fullname = '0', rented = 0, rent_due = NULL, reminder_sent = 0, custom_name = NULL, storage_tier = 1 WHERE houseid = ?", { houseid })
    MySQL.update.await('DELETE FROM rsg_housekeys WHERE houseid = ?', { houseid })
    if purge == nil then purge = Config.PurgeStorageOnLeave end
    if purge then
        purgeStorage(houseid)
    end
    RentedHouses[houseid] = nil
    setHouseDoors(houseid, 0)
end

-- guest list with character names (two queries, so table collations never have to match)
local function getGuests(houseid)
    local guests = MySQL.query.await('SELECT citizenid, ' .. PERM_COLUMNS .. ' FROM rsg_housekeys WHERE houseid = ? AND guest = 1', { houseid }) or {}
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
local function ensureDatabase()
    local exists = MySQL.scalar.await("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'rsg_housing'")
    if exists and exists > 0 then
        -- add columns from newer versions to an existing table
        MySQL.query.await('ALTER TABLE rsg_housing ADD COLUMN IF NOT EXISTS `custom_name` varchar(30) DEFAULT NULL')
        MySQL.query.await('ALTER TABLE rsg_housing ADD COLUMN IF NOT EXISTS `storage_tier` tinyint(4) NOT NULL DEFAULT 1')
        for _, perm in ipairs(GUEST_PERMS) do
            MySQL.query.await(('ALTER TABLE rsg_housekeys ADD COLUMN IF NOT EXISTS `perm_%s` tinyint(1) NOT NULL DEFAULT 1'):format(perm))
        end
        return true
    end

    local sql = LoadResourceFile(GetCurrentResourceName(), 'installation/rsg-housing.sql')
    if not sql then
        print('^1[rsg-housing] rsg_housing table missing and installation/rsg-housing.sql not found^7')
        return false
    end

    sql = sql:gsub('%-%-[^\n]*', '')
    for statement in sql:gmatch('[^;]+') do
        if statement:match('%S') then
            MySQL.query.await(statement)
        end
    end
    print('^2[rsg-housing] database tables created^7')
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

    print(('[rsg-housing] loaded %s rented houses'):format(#houses))
    syncRentedHouses()
    TriggerClientEvent('rsg-housing:client:SyncDoors', -1, DoorStates)
end)

---------------------------------------------
-- callbacks
---------------------------------------------
lib.callback.register('rsg-housing:server:getState', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    return publicHouses(), DoorStates, Player and housesOf(Player.PlayerData.citizenid) or {}
end)

-- everything the house menu needs in one call
lib.callback.register('rsg-housing:server:getHouseStatus', function(source, houseid)
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
lib.callback.register('rsg-housing:server:rentHouse', function(src, houseid)
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
    if count >= Config.MaxHousesPerPlayer then
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
    payGovernor(house.region, rent)

    RentedHouses[houseid] = { owner = fullname, citizenid = citizenid }
    syncRentedHouses()
    setHouseDoors(houseid, 1)

    local due = MySQL.scalar.await("SELECT DATE_FORMAT(rent_due, '%d/%m/%Y') FROM rsg_housing WHERE houseid = ?", { houseid })
    return reply(true, locale('house_rented', HousesById[houseid].name, rent, due), 'success')
end)

---------------------------------------------
-- pay rent (adds 1 calendar month to the due date, max 1 month ahead)
---------------------------------------------
lib.callback.register('rsg-housing:server:payRent', function(src, houseid)
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

    payGovernor(house.region, rent)
    local due = MySQL.scalar.await("SELECT DATE_FORMAT(rent_due, '%d/%m/%Y') FROM rsg_housing WHERE houseid = ?", { house.houseid })
    return reply(true, locale('rent_paid', rent, due), 'success')
end)

---------------------------------------------
-- 'at home' toggle (tenant only, kept in memory)
---------------------------------------------
lib.callback.register('rsg-housing:server:setHome', function(src, houseid, on)
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
lib.callback.register('rsg-housing:server:upgradeStorage', function(src, houseid, level)
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

    payGovernor(house.region, cost)
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

lib.callback.register('rsg-housing:server:renameHouse', function(src, houseid, value)
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
lib.callback.register('rsg-housing:server:endTenancy', function(src, houseid)
    if onCooldown(src, 2000) then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return reply(false) end

    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house then return reply(false, locale('not_tenant'), 'error') end

    endTenancy(house.houseid)
    syncRentedHouses()
    return reply(true, locale('tenancy_ended', HousesById[house.houseid].name), 'success')
end)

---------------------------------------------
-- guests
---------------------------------------------
lib.callback.register('rsg-housing:server:addGuest', function(src, houseid, targetCid)
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

    local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { targetCid })
    if not row then
        return reply(false, locale('guest_not_found'), 'error')
    end
    local info = type(row.charinfo) == 'string' and json.decode(row.charinfo) or row.charinfo
    local guestName = info and info.firstname and (info.firstname .. ' ' .. (info.lastname or '')) or targetCid

    if getAccess(targetCid, house.houseid) then
        return reply(false, locale('guest_exists', guestName), 'error')
    end

    local defaults = Config.GuestDefaultPermissions or {}
    local values = {}
    for i, perm in ipairs(GUEST_PERMS) do values[i] = defaults[perm] == false and 0 or 1 end
    MySQL.insert.await('INSERT INTO rsg_housekeys (citizenid, houseid, guest, ' .. PERM_COLUMNS .. ') VALUES (?, ?, 1, ?, ?, ?, ?)', {
        targetCid, house.houseid, values[1], values[2], values[3], values[4]
    })
    return reply(true, locale('guest_added', guestName), 'success')
end)

-- tenant turns one guest permission on or off
lib.callback.register('rsg-housing:server:setGuestPermission', function(src, houseid, targetCid, perm, allowed)
    if onCooldown(src, 400, 'perm') then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(targetCid) ~= 'string' or not GUEST_PERM_SET[perm] then return reply(false) end

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
lib.callback.register('rsg-housing:server:searchPlayers', function(src, houseid, query)
    if onCooldown(src, 300, 'search') then return nil end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(query) ~= 'string' then return {} end

    query = query:gsub('[%c<>~]', ''):match('^%s*(.-)%s*$'):sub(1, 40)
    if #query < Config.GuestSearchMin then return {} end

    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house then return {} end

    local like = '%' .. query:gsub('[%%_\\]', '\\%0') .. '%'
    local rows = MySQL.query.await([[
        SELECT citizenid, charinfo FROM players
        WHERE citizenid = ?
           OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ?
           OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?
           OR CONCAT(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))) LIKE ?
        LIMIT ?
    ]], { query:upper(), like, like, like, Config.GuestSearchResults + 5 }) or {}

    -- skip the tenant and anyone who already has a key to this house
    local skip = { [Player.PlayerData.citizenid] = true }
    local keys = MySQL.query.await('SELECT citizenid FROM rsg_housekeys WHERE houseid = ?', { house.houseid }) or {}
    for _, key in ipairs(keys) do skip[key.citizenid] = true end

    local results = {}
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

lib.callback.register('rsg-housing:server:removeGuest', function(src, houseid, targetCid)
    if onCooldown(src) then return reply(false) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(targetCid) ~= 'string' then return reply(false) end

    local house = getTenantHouse(Player.PlayerData.citizenid, houseid)
    if not house then return reply(false, locale('not_tenant'), 'error') end

    local guestName = targetCid
    local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { targetCid })
    local info = row and (type(row.charinfo) == 'string' and json.decode(row.charinfo) or row.charinfo)
    if info and info.firstname then guestName = info.firstname .. ' ' .. (info.lastname or '') end

    local removed = MySQL.update.await('DELETE FROM rsg_housekeys WHERE houseid = ? AND citizenid = ? AND guest = 1', { house.houseid, targetCid })
    if removed > 0 then
        return reply(true, locale('guest_removed', guestName), 'success')
    end
    return reply(false)
end)

---------------------------------------------
-- wardrobe: saved outfits from rsg-character (playeroutfit table)
---------------------------------------------
lib.callback.register('rsg-housing:server:outfits', function(src, houseid, action, id)
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

lib.callback.register('rsg-housing:server:mailbox', function(src, houseid, action, id)
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

    local level = MySQL.scalar.await('SELECT storage_tier FROM rsg_housing WHERE houseid = ?', { houseid })
    local _, tier = getStorageTier(level)
    exports['rsg-inventory']:OpenInventory(src, getStashId(houseid), {
        label     = locale('storage_label', house.name),
        maxweight = tier.weight,
        slots     = tier.slots
    })
end)

---------------------------------------------
-- doors (state kept in memory: rented houses lock on restart, vacant houses stay open)
---------------------------------------------
lib.callback.register('rsg-housing:server:toggleDoor', function(source, doorid)
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
        notify(src, door.name, locale('no_access'), 'error')
        return false
    end

    local newState = DoorStates[doorid] == 1 and 0 or 1
    DoorStates[doorid] = newState
    TriggerClientEvent('rsg-housing:client:SetDoorState', -1, doorid, newState)
    return true
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
    local removed = MySQL.update.await('DELETE FROM rsg_housekeys WHERE houseid = ? AND citizenid = ? AND guest = 1', { houseid, data.citizenid })
    if removed == 0 then return adminReply(false) end
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
    local row = MySQL.single.await('SELECT citizenid, fullname FROM rsg_housing WHERE houseid = ? AND rented = 1', { houseid })
    if not row then return adminReply(false, locale('admin_not_rented')) end
    local name = HousesById[houseid] and HousesById[houseid].name or houseid
    endTenancy(houseid, data.purge == true)
    syncRentedHouses()
    sendTelegram(row.citizenid, row.fullname, locale('eviction_subject'), locale('admin_eviction_message', name))
    notifyIfOnline(row.citizenid, locale('rent_title'), locale('admin_eviction_message', name), 'error')
    adminLog(src, ('evicted %s (%s) from %s%s'):format(row.fullname, row.citizenid, houseid, data.purge == true and ', storage deleted' or ''))
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
    local level = MySQL.scalar.await('SELECT storage_tier FROM rsg_housing WHERE houseid = ?', { houseid })
    local _, tier = getStorageTier(level)
    adminLog(src, ('opened the storage of %s'):format(houseid))
    exports['rsg-inventory']:OpenInventory(src, getStashId(houseid), {
        label = locale('storage_label', cfg.name), maxweight = tier.weight, slots = tier.slots
    })
    return { ok = true, closed = true }
end

lib.callback.register('rsg-housing:server:admin', function(src, action, houseid, data)
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
lib.cron.new(Config.RentCheckCronJob, function()
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
        endTenancy(row.houseid, true)
        sendTelegram(row.citizenid, row.fullname, locale('eviction_subject'), locale('eviction_message', name))
        notifyIfOnline(row.citizenid, locale('rent_title'), locale('eviction_message', name), 'error')
        TriggerEvent('rsg-log:server:CreateLog', 'rsghousing', locale('log_eviction_title'), 'red', locale('log_eviction', row.fullname, row.houseid))
    end

    if #overdue > 0 then syncRentedHouses() end
    if Config.Debug then
        print(('[rsg-housing] rent check: %s reminders, %s evictions'):format(#dueSoon, #overdue))
    end
end)
