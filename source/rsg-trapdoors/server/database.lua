-- Automatic database installer / migrator for rsg-trapdoors (server only)
--
-- Schema changes are listed as numbered migrations. Each one runs once and the
-- applied version is stored in `rsg_trapdoors_schema`, so updating the script
-- upgrades existing databases automatically. Never edit a released migration;
-- add a new one to the end of the list instead.

TrapdoorDB = {}

local PREFIX = '^5[rsg-trapdoors]^7 '

local migrations = {
    [1] = {
        description = 'create rsg_trapdoors table',
        queries = {
            [[
            CREATE TABLE IF NOT EXISTS `rsg_trapdoors` (
                `door_id`    VARCHAR(64) NOT NULL,
                `passcode`   CHAR(4)     NOT NULL,
                `owner`      VARCHAR(50) NOT NULL,
                `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`door_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            ]],
        },
    },
    -- [2] = { description = '...', queries = { 'ALTER TABLE `rsg_trapdoors` ADD COLUMN ...' } },
}

local function tableExists(name)
    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name })
    return (tonumber(count) or 0) > 0
end

local function currentVersion()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rsg_trapdoors_schema` (
            `id`      TINYINT UNSIGNED NOT NULL DEFAULT 1,
            `version` INT UNSIGNED     NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    local v = MySQL.scalar.await('SELECT version FROM rsg_trapdoors_schema WHERE id = 1')
    if v == nil then
        -- table existed before migrations were tracked (older version of the script)
        local start = tableExists('rsg_trapdoors') and 1 or 0
        MySQL.insert.await('INSERT INTO rsg_trapdoors_schema (id, version) VALUES (1, ?)', { start })
        return start
    end
    return tonumber(v) or 0
end

--- Builds / upgrades the schema. Returns true when the database is usable.
function TrapdoorDB.Install()
    if not DatabaseConfig.AutoInstall then
        if tableExists('rsg_trapdoors') then return true end
        print(PREFIX .. '^1table `rsg_trapdoors` is missing. Import rsg_trapdoors.sql or set DatabaseConfig.AutoInstall = true^7')
        return false
    end

    local ok, err = pcall(function()
        local version = currentVersion()
        local latest = #migrations

        if version >= latest then
            print(PREFIX .. ('^2database up to date (schema v%d)^7'):format(version))
            return
        end

        for v = version + 1, latest do
            local m = migrations[v]
            for _, query in ipairs(m.queries) do
                MySQL.query.await(query)
            end
            MySQL.update.await('UPDATE rsg_trapdoors_schema SET version = ? WHERE id = 1', { v })
            print(PREFIX .. ('^2applied migration %d: %s^7'):format(v, m.description))
        end
        print(PREFIX .. ('^2database installed (schema v%d)^7'):format(latest))
    end)

    if not ok then
        print(PREFIX .. '^1database install failed: ' .. tostring(err) .. '^7')
        print(PREFIX .. '^1passcode features are disabled until this is fixed.^7')
        return false
    end
    return true
end
