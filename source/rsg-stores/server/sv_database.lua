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
              `store_kind` varchar(10) NOT NULL DEFAULT 'npc',
              `owner_citizenid` varchar(50) DEFAULT NULL,
              `owner_name` varchar(100) DEFAULT NULL,
              `balance` decimal(12,2) NOT NULL DEFAULT 0.00,
              `prop_model` varchar(100) DEFAULT NULL,
              `upkeep_owed` decimal(10,2) NOT NULL DEFAULT 0.00,
              `upkeep_next` int(11) DEFAULT NULL,
              `packed_at` int(11) DEFAULT NULL,
              PRIMARY KEY (`id`),
              KEY `idx_shop_name` (`shop_name`),
              KEY `idx_owner` (`owner_citizenid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        ]],
        columns = {
            name       = 'varchar(100) DEFAULT NULL',
            shop_name  = 'varchar(100) DEFAULT NULL',
            shop_label = 'varchar(100) DEFAULT NULL',
            shop_type  = "varchar(10) NOT NULL DEFAULT 'both'",
            store_kind      = "varchar(10) NOT NULL DEFAULT 'npc'", -- 'npc' = NPC shopkeeper, 'player' = player-owned store
            owner_citizenid = 'varchar(50) DEFAULT NULL',
            owner_name      = 'varchar(100) DEFAULT NULL',
            balance         = 'decimal(12,2) NOT NULL DEFAULT 0.00',      -- player-owned store till
            prop_model      = 'varchar(100) DEFAULT NULL',                -- sign prop for stores opened with a shop sign item
            upkeep_owed     = 'decimal(10,2) NOT NULL DEFAULT 0.00',      -- unpaid sign store upkeep
            upkeep_next     = 'int(11) DEFAULT NULL',                     -- unix time the next upkeep is due
            packed_at       = 'int(11) DEFAULT NULL',                     -- set while a sign store is picked up (moving)
        },
        indexes = { idx_shop_name = '`shop_name`', idx_owner = '`owner_citizenid`' },
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
        -- Owner-facing sales ledger for player-owned stores.
        name = 'rsg_shops_ledger',
        create = [[
            CREATE TABLE IF NOT EXISTS `rsg_shops_ledger` (
              `id` int(11) NOT NULL AUTO_INCREMENT,
              `npc_id` int(11) NOT NULL,
              `ts` int(11) NOT NULL,
              `kind` varchar(16) NOT NULL,
              `item` varchar(100) DEFAULT NULL,
              `qty` int(11) NOT NULL DEFAULT 0,
              `amount` decimal(12,2) NOT NULL DEFAULT 0.00,
              `who` varchar(100) DEFAULT NULL,
              PRIMARY KEY (`id`),
              KEY `idx_ledger_npc` (`npc_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        ]],
        columns = {},
        indexes = {},
    },
    {
        -- Staff hired by store owners, with their permissions.
        name = 'rsg_shops_staff',
        create = [[
            CREATE TABLE IF NOT EXISTS `rsg_shops_staff` (
              `id` int(11) NOT NULL AUTO_INCREMENT,
              `npc_id` int(11) NOT NULL,
              `citizenid` varchar(50) NOT NULL,
              `name` varchar(100) DEFAULT NULL,
              `staff_rank` varchar(32) NOT NULL DEFAULT 'custom',
              `perms` varchar(255) NOT NULL DEFAULT '',
              `withdrawn` decimal(12,2) NOT NULL DEFAULT 0.00,
              `withdraw_day` int(11) NOT NULL DEFAULT 0,
              `hired_at` int(11) NOT NULL DEFAULT 0,
              PRIMARY KEY (`id`),
              UNIQUE KEY `uq_store_staff` (`npc_id`, `citizenid`),
              KEY `idx_staff_cid` (`citizenid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        ]],
        columns = {
            withdrawn    = 'decimal(12,2) NOT NULL DEFAULT 0.00',
            withdraw_day = 'int(11) NOT NULL DEFAULT 0',
        },
        indexes = {},
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
