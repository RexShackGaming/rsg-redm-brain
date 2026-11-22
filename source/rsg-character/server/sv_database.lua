RSGCore = RSGCore or exports['rsg-core']:GetCoreObject()

-- Builds the tables this resource needs. Identical to install.sql (keep the two in sync).
-- Set RSG.AutoDatabase = false in shared/config.lua to import install.sql manually instead.
local tables = {
    [[
        CREATE TABLE IF NOT EXISTS `playerskins` (
          `id` INT(11) NOT NULL AUTO_INCREMENT,
          `citizenid` VARCHAR(255) NOT NULL,
          `skin` LONGTEXT NOT NULL,
          `clothes` LONGTEXT NOT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uq_playerskins_citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `playeroutfit` (
          `id` INT(11) NOT NULL AUTO_INCREMENT,
          `citizenid` VARCHAR(255) NOT NULL,
          `name` VARCHAR(255) NOT NULL,
          `clothes` LONGTEXT NOT NULL,
          `is_default` TINYINT(1) NOT NULL DEFAULT 0,
          PRIMARY KEY (`id`),
          KEY `citizen_default` (`citizenid`, `is_default`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `playerslots` (
          `license` VARCHAR(255) NOT NULL,
          `extra_slots` INT(11) NOT NULL DEFAULT 0,
          `updated_at` TIMESTAMP NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
          PRIMARY KEY (`license`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `rsg_character_names` (
          `citizenid` VARCHAR(50) NOT NULL,
          `firstname` VARCHAR(64) NOT NULL,
          `lastname` VARCHAR(64) NOT NULL,
          PRIMARY KEY (`citizenid`),
          KEY `fullname` (`firstname`, `lastname`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `rsg_character_deleted` (
          `citizenid` VARCHAR(50) NOT NULL,
          `license` VARCHAR(255) NOT NULL,
          `original_cid` INT(11) NOT NULL,
          `deleted_at` INT(11) NOT NULL,
          `purge_at` INT(11) NOT NULL,
          PRIMARY KEY (`citizenid`),
          KEY `license` (`license`),
          KEY `purge_at` (`purge_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    ]],
}

local function IndexExists(tableName, indexName)
    local found = MySQL.scalar.await(
        'SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ? LIMIT 1',
        { tableName, indexName })
    return found ~= nil
end

-- Upgrades tables created by older versions. Never drops data except the older duplicate
-- playerskins rows (only the newest row per character was ever read), and only when RSG.DedupeSkins is on.
local function Migrate()
    local hasUnique = MySQL.scalar.await(
        'SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ? AND NON_UNIQUE = 0 AND SEQ_IN_INDEX = 1 LIMIT 1',
        { 'playerskins', 'citizenid' }) ~= nil
    if not hasUnique then
        local dup = MySQL.scalar.await('SELECT citizenid FROM playerskins GROUP BY citizenid HAVING COUNT(*) > 1 LIMIT 1')
        if dup and RSG.DedupeSkins ~= false then
            local removed = MySQL.update.await('DELETE s1 FROM playerskins s1 INNER JOIN playerskins s2 ON s1.citizenid = s2.citizenid AND s1.id < s2.id')
            print(('^3[rsg-character] removed %s older duplicate playerskins rows (the newest row per character is kept)^7'):format(tostring(removed)))
            dup = MySQL.scalar.await('SELECT citizenid FROM playerskins GROUP BY citizenid HAVING COUNT(*) > 1 LIMIT 1')
        end
        if dup then
            print('^3[rsg-character] playerskins still has duplicate rows, unique key not added (set RSG.DedupeSkins = true to clean them)^7')
        else
            local ok, err = pcall(MySQL.query.await, 'ALTER TABLE playerskins ADD UNIQUE KEY `uq_playerskins_citizenid` (`citizenid`)')
            if not ok then print(('^1[rsg-character] could not add the playerskins unique key: %s^7'):format(tostring(err))) end
        end
    end

    pcall(MySQL.query.await, 'ALTER TABLE playeroutfit ADD COLUMN IF NOT EXISTS is_default TINYINT(1) NOT NULL DEFAULT 0')
    if not IndexExists('playeroutfit', 'citizen_default') then
        pcall(MySQL.query.await, 'ALTER TABLE playeroutfit ADD KEY `citizen_default` (`citizenid`, `is_default`)')
    end

    -- characters that exist in `players` but not in the names table yet (older characters, or made by other resources)
    local ok, err = pcall(MySQL.query.await, [[
        INSERT INTO rsg_character_names (citizenid, firstname, lastname)
        SELECT p.citizenid,
               JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')),
               JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
        FROM players p
        WHERE p.charinfo IS NOT NULL
          AND JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) IS NOT NULL
          AND JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM rsg_character_names n WHERE n.citizenid = p.citizenid)
    ]])
    if not ok then print(('^3[rsg-character] names table backfill skipped: %s^7'):format(tostring(err))) end
end

function RSG.EnsureDatabase()
    for i = 1, #tables do
        local ok, err = pcall(MySQL.query.await, tables[i])
        if not ok then
            print(('^1[rsg-character] database setup failed: %s^7'):format(tostring(err)))
            return false
        end
    end
    local ok, err = pcall(Migrate)
    if not ok then print(('^1[rsg-character] database upgrade failed: %s^7'):format(tostring(err))) end
    print('^2[rsg-character] database tables ready^7')
    return true
end
