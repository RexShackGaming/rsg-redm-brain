local RSGCore = exports['rsg-core']:GetCoreObject()

-- pending[src] = { item, ammoType, amount, readyAt, expires } -- set by the server only
local pending = {}

-- whitelist of valid db columns, built from config (never trust client column names)
local validColumns = {}
for ammoType, data in pairs(Config.AmmoTypes) do
    validColumns[ammoType:lower()] = data.maxAmmo
end

------------------------------------------
-- auto database setup (backup: installation/rsg-ammo.sql)
------------------------------------------
local dbReady = false

CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `player_ammo` (
                `id` INT(11) NOT NULL AUTO_INCREMENT,
                `citizenid` VARCHAR(255) NOT NULL,
                PRIMARY KEY (`id`) USING BTREE,
                UNIQUE INDEX `citizenid` (`citizenid`) USING BTREE
            ) ENGINE=InnoDB
        ]])

        -- add a column for any ammo type in config that the table doesn't have yet
        local existing = {}
        local rows = MySQL.query.await([[
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'player_ammo'
        ]]) or {}
        for _, row in ipairs(rows) do
            existing[row.COLUMN_NAME:lower()] = true
        end

        local added = 0
        for column in pairs(validColumns) do
            if not existing[column] then
                MySQL.query.await(('ALTER TABLE `player_ammo` ADD COLUMN `%s` INT(11) NOT NULL DEFAULT 0'):format(column))
                added = added + 1
            end
        end
        if added > 0 then
            print(('^2[rsg-ammo] added %d ammo column(s) to player_ammo^7'):format(added))
        end
    end)

    if not ok then
        print(('^1[rsg-ammo] database setup failed, import installation/rsg-ammo.sql manually: %s^7'):format(err))
    end
    dbReady = true
end)

------------------------------------------
-- claim ammo (after progress bar / instantly for arrows)
------------------------------------------
local function claimAmmo(src)
    local claim = pending[src]
    pending[src] = nil
    local now = GetGameTimer()
    if not claim or now > claim.expires or now < claim.readyAt then return end -- expired or progress bar skipped

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if not Player.Functions.RemoveItem(claim.item, 1, nil, 'rsg-ammo:open') then return end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[claim.item], 'remove', 1)
    TriggerClientEvent('rsg-ammo:client:AddAmmo', src, claim.ammoType, claim.amount)
end

------------------------------------------
-- useable ammo items (boxes + arrows)
------------------------------------------
local function registerAmmoItem(itemName, ammoType, useProgress)
    local ammoData = Config.AmmoTypes[ammoType]
    if not ammoData then
        print(('^3[rsg-ammo] item %s maps to unknown ammo type %s, skipped^7'):format(itemName, ammoType))
        return
    end

    RSGCore.Functions.CreateUseableItem(itemName, function(source, item)
        local src = source
        if pending[src] and pending[src].expires > GetGameTimer() then return end
        if not RSGCore.Functions.GetPlayer(src) then return end

        local amount = ammoData.refill
        if not lib.callback.await('rsg-ammo:client:CanAddAmmo', src, ammoType, amount) then return end

        -- the server decides what the client may claim; the client only confirms
        local openTime = useProgress and Config.OpenAmmoBoxTime or 0
        local now = GetGameTimer()
        pending[src] = {
            item = item.name,
            ammoType = ammoType,
            amount = amount,
            readyAt = now + openTime - 500,
            expires = now + openTime + 10000,
        }

        if useProgress then
            TriggerClientEvent('rsg-ammo:client:openAmmoBox', src, item.name)
        else
            claimAmmo(src)
        end
    end)
end

for itemName, ammoType in pairs(Config.BoxAmmo) do
    registerAmmoItem(itemName, ammoType, true)
end

for itemName, ammoType in pairs(Config.ArrowAmmo) do
    registerAmmoItem(itemName, ammoType, false)
end

RegisterNetEvent('rsg-ammo:server:openAmmoBox', function()
    claimAmmo(source)
end)

RegisterNetEvent('rsg-ammo:server:cancelOpen', function()
    pending[source] = nil
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)

------------------------------------------
-- load saved ammo
------------------------------------------
lib.callback.register('rsg-ammo:server:initializeDb', function(source)
    while not dbReady do Wait(100) end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return nil end
    local citizenid = Player.PlayerData.citizenid

    local row = MySQL.single.await('SELECT * FROM player_ammo WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row then
        MySQL.insert.await('INSERT IGNORE INTO player_ammo (citizenid) VALUES (?)', { citizenid })
        row = MySQL.single.await('SELECT * FROM player_ammo WHERE citizenid = ? LIMIT 1', { citizenid })
    end
    return row
end)

------------------------------------------
-- save ammo
------------------------------------------
RegisterNetEvent('rsg-ammo:server:updateDb', function(update)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not dbReady or not Player or type(update) ~= 'table' then return end

    local setClauses, params = {}, {}
    for column, value in pairs(update) do
        local maxAmmo = validColumns[column]
        value = tonumber(value)
        if maxAmmo and value then
            setClauses[#setClauses + 1] = ('`%s` = ?'):format(column)
            params[#params + 1] = math.max(0, math.min(math.floor(value), maxAmmo))
        end
    end
    if #setClauses == 0 then return end

    params[#params + 1] = Player.PlayerData.citizenid
    MySQL.update(('UPDATE player_ammo SET %s WHERE citizenid = ?'):format(table.concat(setClauses, ', ')), params)
end)
