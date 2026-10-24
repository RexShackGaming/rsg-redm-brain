---------------------------------------------
-- DATABASE: builds / upgrades `player_backpack` automatically on resource start
-- (Config.AutoCreateTable). Safe to run every start: only missing parts are added.
---------------------------------------------
BP = BP or {}
BP.DatabaseReady = false

local TABLE = 'player_backpack'

local CREATE_SQL = [[
    CREATE TABLE IF NOT EXISTS `player_backpack` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `serial` VARCHAR(32) NOT NULL,
        `citizenid` VARCHAR(50) DEFAULT NULL,
        `owner` VARCHAR(50) DEFAULT NULL,
        `backpackitem` VARCHAR(50) NOT NULL,
        `model` VARCHAR(100) DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `serial` (`serial`),
        KEY `owner` (`owner`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

-- columns added to older tables (e.g. imported from hdrp-backpack)
local COLUMNS = {
    { name = 'citizenid',    sql = 'ADD COLUMN `citizenid` VARCHAR(50) DEFAULT NULL' },
    { name = 'owner',        sql = 'ADD COLUMN `owner` VARCHAR(50) DEFAULT NULL' },
    { name = 'backpackitem', sql = "ADD COLUMN `backpackitem` VARCHAR(50) NOT NULL DEFAULT ''" },
    { name = 'model',        sql = 'ADD COLUMN `model` VARCHAR(100) DEFAULT NULL' },
}

local INDEXES = {
    { name = 'serial',     sql = 'ADD UNIQUE KEY `serial` (`serial`)' },
    { name = 'owner',      sql = 'ADD KEY `owner` (`owner`)' },
}

local function Log(msg, ...)
    print(('^2[rsg-backpacks]^0 ' .. msg):format(...))
end

local function Exists(query, name)
    return MySQL.scalar.await(query, { TABLE, name }) ~= nil
end

local function BuildDatabase()
    local tableExisted = MySQL.scalar.await(
        'SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { TABLE }) ~= nil

    MySQL.query.await(CREATE_SQL)
    if not tableExisted then
        Log('created table `%s`', TABLE)
        return
    end

    for _, col in ipairs(COLUMNS) do
        if not Exists('SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?', col.name) then
            MySQL.query.await(('ALTER TABLE `%s` %s'):format(TABLE, col.sql))
            Log('added column `%s`', col.name)
        end
    end

    for _, idx in ipairs(INDEXES) do
        if not Exists('SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?', idx.name) then
            local ok, err = pcall(MySQL.query.await, ('ALTER TABLE `%s` %s'):format(TABLE, idx.sql))
            if ok then
                Log('added index `%s`', idx.name)
            else
                -- e.g. duplicate serials in legacy data block the unique key
                print(('^1[rsg-backpacks] could not add index `%s`: %s^0'):format(idx.name, tostring(err)))
            end
        end
    end
end

MySQL.ready(function()
    if Config.AutoCreateTable then
        local ok, err = pcall(BuildDatabase)
        if not ok then
            print(('^1[rsg-backpacks] database setup failed: %s^0'):format(tostring(err)))
            print('^1[rsg-backpacks] import installation/player_backpack.sql manually^0')
        end
    end
    BP.DatabaseReady = true
end)
