OrganizationMigrations = {}
local definitions = {
    { id = '001_organization_types', statements = {
        [[CREATE TABLE IF NOT EXISTS `feather_organization_types` (
            `organization_type_id` CHAR(36) NOT NULL,
            `type_key` VARCHAR(48) NOT NULL,
            `label` VARCHAR(100) NOT NULL,
            `owner_resource` VARCHAR(100) NOT NULL,
            `status` VARCHAR(16) NOT NULL DEFAULT 'active',
            `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`organization_type_id`), UNIQUE KEY `uq_organization_type_key` (`type_key`),
            CONSTRAINT `chk_organization_type_status` CHECK (`status` IN ('active','retired'))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
    } },
    { id = '002_organization_identity', statements = {
        [[CREATE TABLE IF NOT EXISTS `feather_organizations` (
            `organization_id` CHAR(36) NOT NULL,
            `organization_type_id` CHAR(36) NOT NULL,
            `organization_key` VARCHAR(64) NOT NULL,
            `legal_name` VARCHAR(160) NOT NULL, `display_name` VARCHAR(100) NOT NULL,
            `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
            `created_by_resource` VARCHAR(100) NOT NULL,
            `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`organization_id`), UNIQUE KEY `uq_organization_key` (`organization_key`),
            CONSTRAINT `fk_organization_type` FOREIGN KEY (`organization_type_id`)
                REFERENCES `feather_organization_types` (`organization_type_id`),
            CONSTRAINT `chk_organization_status` CHECK (`status` IN ('pending','active','suspended','dissolving','dissolved'))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
        [[CREATE TABLE IF NOT EXISTS `feather_organization_creation_receipts` (
            `source_resource` VARCHAR(100) NOT NULL, `request_id` VARCHAR(128) NOT NULL,
            `request_fingerprint` LONGTEXT NOT NULL, `result_json` LONGTEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`source_resource`,`request_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
        [[CREATE TABLE IF NOT EXISTS `feather_organization_events` (
            `event_id` CHAR(36) NOT NULL, `organization_id` CHAR(36) NOT NULL,
            `event_type` VARCHAR(64) NOT NULL, `source_resource` VARCHAR(100) NOT NULL,
            `request_id` VARCHAR(128) NOT NULL, `reason_code` VARCHAR(64) NOT NULL,
            `revision` BIGINT UNSIGNED NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`event_id`), UNIQUE KEY `uq_organization_creation_event` (`source_resource`,`request_id`),
            CONSTRAINT `fk_organization_event` FOREIGN KEY (`organization_id`)
                REFERENCES `feather_organizations` (`organization_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
    } },
    { id = '003_organization_lifecycle', statements = {
        [[CREATE TABLE IF NOT EXISTS `feather_organization_lifecycle_receipts` (
            `source_resource` VARCHAR(100) NOT NULL, `request_id` VARCHAR(128) NOT NULL,
            `request_fingerprint` LONGTEXT NOT NULL, `result_json` LONGTEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`source_resource`,`request_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
    } },
    { id = '004_organization_identity_updates', statements = {
        [[CREATE TABLE IF NOT EXISTS `feather_organization_identity_receipts` (
            `source_resource` VARCHAR(100) NOT NULL, `request_id` VARCHAR(128) NOT NULL,
            `request_fingerprint` LONGTEXT NOT NULL, `result_json` LONGTEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`source_resource`,`request_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
    } },
    { id = '005_organization_hierarchy', statements = {
        [[CREATE TABLE IF NOT EXISTS `feather_organization_hierarchy_guard` (
            `id` TINYINT NOT NULL, PRIMARY KEY (`id`)
        ) ENGINE=InnoDB]],
        [[INSERT IGNORE INTO `feather_organization_hierarchy_guard` (`id`) VALUES (1)]],
        [[CREATE TABLE IF NOT EXISTS `feather_organization_parents` (
            `organization_id` CHAR(36) NOT NULL, `parent_organization_id` CHAR(36) NOT NULL,
            PRIMARY KEY (`organization_id`), KEY `idx_organization_parent` (`parent_organization_id`),
            CONSTRAINT `fk_organization_child` FOREIGN KEY (`organization_id`) REFERENCES `feather_organizations` (`organization_id`),
            CONSTRAINT `fk_organization_parent` FOREIGN KEY (`parent_organization_id`) REFERENCES `feather_organizations` (`organization_id`),
            CONSTRAINT `chk_organization_parent_self` CHECK (`organization_id` <> `parent_organization_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
        [[CREATE TABLE IF NOT EXISTS `feather_organization_hierarchy_receipts` (
            `source_resource` VARCHAR(100) NOT NULL, `request_id` VARCHAR(128) NOT NULL,
            `request_fingerprint` LONGTEXT NOT NULL, `result_json` LONGTEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`source_resource`,`request_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
    } },
    { id = '006_organization_outbox', statements = {
        [[CREATE TABLE IF NOT EXISTS `feather_organization_outbox` (
            `event_id` CHAR(36) NOT NULL, `event_type` VARCHAR(100) NOT NULL,
            `payload_json` LONGTEXT NOT NULL, `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
            `attempts` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            `available_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `published_at` TIMESTAMP NULL,
            PRIMARY KEY (`event_id`), KEY `idx_organization_outbox_pending` (`status`,`available_at`),
            CONSTRAINT `fk_organization_outbox_event` FOREIGN KEY (`event_id`) REFERENCES `feather_organization_events` (`event_id`),
            CONSTRAINT `chk_organization_outbox_status` CHECK (`status` IN ('pending','published'))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
    } },
    { id = '007_organization_interests', statements = {
        [[CREATE TABLE IF NOT EXISTS `feather_organization_interests` (
            `interest_id` CHAR(36) NOT NULL, `organization_id` CHAR(36) NOT NULL,
            `interest_type` VARCHAR(48) NOT NULL, `holder_type` VARCHAR(24) NOT NULL,
            `holder_id` CHAR(36) NOT NULL, `status` VARCHAR(16) NOT NULL,
            `revision` BIGINT UNSIGNED NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`interest_id`), UNIQUE KEY `uq_organization_interest` (`organization_id`,`interest_type`,`holder_type`,`holder_id`),
            CONSTRAINT `fk_interest_organization` FOREIGN KEY (`organization_id`) REFERENCES `feather_organizations` (`organization_id`),
            CONSTRAINT `chk_interest_status` CHECK (`status` IN ('active','revoked'))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
        [[CREATE TABLE IF NOT EXISTS `feather_organization_interest_receipts` (
            `source_resource` VARCHAR(100) NOT NULL, `request_id` VARCHAR(128) NOT NULL,
            `request_fingerprint` LONGTEXT NOT NULL, `result_json` LONGTEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`source_resource`,`request_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
    } }
}
local function Hash(value)
    local hash = 2166136261
    for index = 1, #value do hash = ((hash ~ value:byte(index)) * 16777619) & 0xffffffff end
    return ('fnv1a32:%08x'):format(hash)
end
function OrganizationMigrations.Run()
    DB.exec([[CREATE TABLE IF NOT EXISTS `feather_organization_schema_migrations` (
        `id` VARCHAR(100) NOT NULL, `checksum` VARCHAR(64) NOT NULL,
        `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]])
    local count = 0
    for _, migration in ipairs(definitions) do
        local checksum = Hash(table.concat(migration.statements, '\n-- next statement --\n'))
        local applied = DB.one('SELECT `checksum` FROM `feather_organization_schema_migrations` WHERE `id`=?', migration.id)
        if applied and applied.checksum ~= checksum then
            return Organizations.Err('migration_checksum_mismatch', 'An applied organization migration changed.', { migrationId = migration.id })
        end
        if not applied then
            for _, statement in ipairs(migration.statements) do DB.exec(statement) end
            DB.insert('INSERT INTO `feather_organization_schema_migrations` (`id`,`checksum`) VALUES (?,?)', migration.id, checksum)
            count = count + 1
        end
    end
    return Organizations.Ok({ total = #definitions, applied = count })
end
