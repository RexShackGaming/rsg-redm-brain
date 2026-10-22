-- ============================================
-- AUTO DATABASE INSTALLER / MIGRATOR
-- Creates missing tables, adds missing columns and indexes on older installs.
-- Safe to run on every start: every step checks first and never drops data.
-- Toggle with Config.AutoInstallDatabase in shared/config.lua.
-- ============================================
Database = {}

local SCHEMA = {
    {
        name = 'rsg_shops_npcs',
        create = [[
            CREATE TABLE IF NOT EXISTS `rsg_shops_npcs` (
              `id` int(11) NOT NULL AUTO_INCREMENT,
              `name` varchar(100) DEFAULT NULL,
              `model` varchar(100) NOT NULL,
              `x` double NOT NULL,
              `y` double NOT NULL,
              `z` double NOT NULL,
              `h` double NOT NULL,
              `shop_name` varchar(100) DEFAULT NULL,
              `shop_label` varchar(100) DEFAULT NULL,
              `shop_type` varchar(10) NOT NULL DEFAULT 'both',
              PRIMARY KEY (`id`),
              KEY `idx_shop_name` (`shop_name`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        ]],
        columns = {
            name       = 'varchar(100) DEFAULT NULL',
            shop_name  = 'varchar(100) DEFAULT NULL',
            shop_label = 'varchar(100) DEFAULT NULL',
            shop_type  = "varchar(10) NOT NULL DEFAULT 'both'",
        },
        indexes = { idx_shop_name = '`shop_name`' },
    },
    {
        name = 'rsg_shops_items',
        create = [[
            CREATE TABLE IF NOT EXISTS `rsg_shops_items` (
              `id` int(11) NOT NULL AUTO_INCREMENT,
              `npc_id` int(11) NOT NULL,
              `item_name` varchar(100) NOT NULL,
              `label` varchar(100) DEFAULT NULL,
              `price` decimal(10,2) NOT NULL DEFAULT 0.00,
              `stock` int(11) DEFAULT NULL,
              PRIMARY KEY (`id`),
              KEY `idx_npc_id` (`npc_id`),
              KEY `idx_item_name` (`item_name`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        ]],
        columns = {
            label = 'varchar(100) DEFAULT NULL',
            price = 'decimal(10,2) NOT NULL DEFAULT 0.00',
            stock = 'int(11) DEFAULT NULL',
        },
        indexes = { idx_npc_id = '`npc_id`', idx_item_name = '`item_name`' },
    },
    {
        name = 'rsg_shops_blips',
        create = [[
            CREATE TABLE IF NOT EXISTS `rsg_shops_blips` (
              `id` int(11) NOT NULL AUTO_INCREMENT,
              `name` varchar(100) NOT NULL,
              `sprite` bigint(20) NOT NULL,
              `color` varchar(64) DEFAULT NULL,
              `x` double NOT NULL,
              `y` double NOT NULL,
              `z` double NOT NULL,
              `associated_npc_id` int(11) DEFAULT NULL,
              PRIMARY KEY (`id`),
              KEY `idx_assoc_npc` (`associated_npc_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        ]],
        columns = {
            color             = 'varchar(64) DEFAULT NULL',
            associated_npc_id = 'int(11) DEFAULT NULL',
        },
        indexes = { idx_assoc_npc = '`associated_npc_id`' },
    },
    {
        -- Admin-managed dropdown options (NPC models / blip sprites). Seeded from Config on first install.
        name = 'rsg_shops_presets',
        create = [[
            CREATE TABLE IF NOT EXISTS `rsg_shops_presets` (
              `id` int(11) NOT NULL AUTO_INCREMENT,
              `kind` varchar(10) NOT NULL,
              `label` varchar(100) NOT NULL,
              `value` varchar(100) NOT NULL,
              PRIMARY KEY (`id`),
              UNIQUE KEY `uq_kind_value` (`kind`, `value`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        ]],
        columns = {},
        indexes = {},
    },
}

local function tableExists(name)
    return (MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name }) or 0) > 0
end

local function existingColumns(name)
    local set = {}
    for _, r in ipairs(MySQL.query.await(
        'SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name }) or {}) do
        set[r.COLUMN_NAME] = true
    end
    return set
end

local function existingIndexes(name)
    local set = {}
    for _, r in ipairs(MySQL.query.await(
        'SELECT DISTINCT INDEX_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name }) or {}) do
        set[r.INDEX_NAME] = true
    end
    return set
end

-- Returns number of changes made. Errors propagate so BootDatabase can retry.
function Database.Install()
    local changes = 0
    for _, t in ipairs(SCHEMA) do
        if not tableExists(t.name) then
            MySQL.query.await(t.create)
            changes = changes + 1
            print(('[rsg-stores] ' .. locale('sv_db_table_created')):format(t.name))
        else
            local cols = existingColumns(t.name)
            for col, def in pairs(t.columns) do
                if not cols[col] then
                    MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(t.name, col, def))
                    changes = changes + 1
                    print(('[rsg-stores] ' .. locale('sv_db_column_added')):format(t.name, col))
                end
            end
            local idx = existingIndexes(t.name)
            for name, cols_ in pairs(t.indexes) do
                if not idx[name] then
                    MySQL.query.await(('ALTER TABLE `%s` ADD INDEX `%s` (%s)'):format(t.name, name, cols_))
                    changes = changes + 1
                end
            end
        end
    end
    if changes == 0 then
        print('[rsg-stores] ' .. locale('sv_db_uptodate'))
    else
        print(('[rsg-stores] ' .. locale('sv_db_installed')):format(changes))
    end
    return changes
end
