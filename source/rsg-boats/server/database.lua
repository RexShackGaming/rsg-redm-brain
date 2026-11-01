---------------------------------------------------------------------
-- auto database install
-- builds the rsg-boats tables on resource start (safe to run every start)
---------------------------------------------------------------------
local Schema = {
    [[CREATE TABLE IF NOT EXISTS `rsg_boats_models` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `model` VARCHAR(64) NOT NULL,
        `label` VARCHAR(64) NOT NULL,
        `description` VARCHAR(255) NOT NULL DEFAULT '',
        `price` INT NOT NULL DEFAULT 0,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `slots` INT NOT NULL DEFAULT 10,
        `weight` INT NOT NULL DEFAULT 50000,
        PRIMARY KEY (`id`),
        UNIQUE KEY `model` (`model`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `rsg_boats_owned` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `model` VARCHAR(64) NOT NULL,
        `label` VARCHAR(64) NOT NULL,
        `purchased` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `yard` INT NULL DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `rsg_boats_yards` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `name` VARCHAR(64) NOT NULL,
        `coords` VARCHAR(255) NOT NULL,
        `spawn` VARCHAR(255) NULL DEFAULT NULL,
        `dock` VARCHAR(255) NULL DEFAULT NULL,
        `models` TEXT NULL DEFAULT NULL,
        PRIMARY KEY (`id`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `rsg_boats_settings` (
        `k` VARCHAR(64) NOT NULL,
        `v` LONGTEXT NOT NULL,
        PRIMARY KEY (`k`)
    )]],
}

-- columns added after first release: { table, column, definition }
local Columns = {
    { 'rsg_boats_models', 'description', "VARCHAR(255) NOT NULL DEFAULT ''" },
    { 'rsg_boats_models', 'enabled', 'TINYINT(1) NOT NULL DEFAULT 1' },
    { 'rsg_boats_models', 'slots', 'INT NOT NULL DEFAULT 10' },
    { 'rsg_boats_models', 'weight', 'INT NOT NULL DEFAULT 50000' },
    { 'rsg_boats_owned', 'purchased', 'TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP' },
    { 'rsg_boats_owned', 'yard', 'INT NULL DEFAULT NULL' },    -- yard the boat is stored at (NULL = any yard)
    { 'rsg_boats_yards', 'models', 'TEXT NULL DEFAULT NULL' }, -- JSON list of boat models allowed at the yard (NULL = all)
}

local function columnExists(tbl, col)
    local n = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?]], { tbl, col })
    return (tonumber(n) or 0) > 0
end

local function tableExists(tbl)
    local n = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]], { tbl })
    return (tonumber(n) or 0) > 0
end

function InstallDatabase()
    if not Config.AutoInstallDB then return true end
    local ok, err = pcall(function()
        local fresh = not tableExists('rsg_boats_models')

        for _, sql in ipairs(Schema) do MySQL.query.await(sql) end

        for _, c in ipairs(Columns) do
            if not columnExists(c[1], c[2]) then
                MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(c[1], c[2], c[3]))
                print(('^3[rsg-boats]^7 added missing column %s.%s'):format(c[1], c[2]))
            end
        end

        -- seed default boats only on first install (so admin deletions stick)
        if fresh then
            for _, b in ipairs(Config.DefaultBoats or {}) do
                MySQL.insert.await([[INSERT IGNORE INTO rsg_boats_models (model, label, description, price, enabled, slots, weight)
                    VALUES (?, ?, ?, ?, 1, ?, ?)]], { b.model, b.label, b.description or '', b.price or 0,
                    b.slots or Config.Storage.defaultSlots, b.weight or Config.Storage.defaultWeight })
            end
            print('^2[rsg-boats]^7 database tables created')
        else
            print('^2[rsg-boats]^7 database tables verified')
        end
    end)
    if not ok then
        print(('^1[rsg-boats]^7 database install failed: %s'):format(err))
        return false
    end
    return true
end
