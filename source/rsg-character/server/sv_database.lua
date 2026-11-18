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
          KEY `citizenid` (`citizenid`)
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
          KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
}

function RSG.EnsureDatabase()
    for i = 1, #tables do
        local ok, err = pcall(MySQL.query.await, tables[i])
        if not ok then
            print(('^1[rsg-character] database setup failed: %s^7'):format(tostring(err)))
            return false
        end
    end
    print('^2[rsg-character] database tables ready^7')
    return true
end
