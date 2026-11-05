AuthorityMigrations = {}
local definitions = {
    {
        id = '001_capability_registry',
        statements = {
            [[CREATE TABLE IF NOT EXISTS `feather_authority_capabilities` (
                `capability_id` CHAR(36) NOT NULL,
                `capability_key` VARCHAR(100) NOT NULL,
                `description` VARCHAR(255) NOT NULL,
                `risk_class` VARCHAR(16) NOT NULL,
                `owner_resource` VARCHAR(100) NOT NULL,
                `status` VARCHAR(16) NOT NULL DEFAULT 'active',
                `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `retired_at` TIMESTAMP NULL,
                PRIMARY KEY (`capability_id`),
                UNIQUE KEY `uq_authority_capability_key` (`capability_key`),
                CONSTRAINT `chk_authority_capability_risk`
                    CHECK (`risk_class` IN ('low','moderate','high','critical')),
                CONSTRAINT `chk_authority_capability_status`
                    CHECK (`status` IN ('active','retired'))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    },
    {
        id = '002_role_identity',
        statements = {
            [[CREATE TABLE IF NOT EXISTS `feather_authority_roles` (
                `role_id` CHAR(36) NOT NULL,
                `role_key` VARCHAR(100) NOT NULL,
                `label` VARCHAR(100) NOT NULL,
                `role_class` VARCHAR(16) NOT NULL,
                `owner_resource` VARCHAR(100) NOT NULL,
                `status` VARCHAR(16) NOT NULL DEFAULT 'active',
                `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `retired_at` TIMESTAMP NULL,
                PRIMARY KEY (`role_id`),
                UNIQUE KEY `uq_authority_role_key` (`role_key`),
                CONSTRAINT `chk_authority_role_class` CHECK (`role_class` IN ('staff','rp')),
                CONSTRAINT `chk_authority_role_status` CHECK (`status` IN ('active','retired'))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
            [[CREATE TABLE IF NOT EXISTS `feather_authority_role_creation_receipts` (
                `source_resource` VARCHAR(100) NOT NULL,
                `request_id` VARCHAR(128) NOT NULL,
                `request_fingerprint` LONGTEXT NOT NULL,
                `result_json` LONGTEXT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`source_resource`,`request_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
            [[CREATE TABLE IF NOT EXISTS `feather_authority_role_events` (
                `event_id` CHAR(36) NOT NULL,
                `role_id` CHAR(36) NOT NULL,
                `event_type` VARCHAR(64) NOT NULL,
                `source_resource` VARCHAR(100) NOT NULL,
                `request_id` VARCHAR(128) NOT NULL,
                `reason_code` VARCHAR(64) NOT NULL,
                `revision` BIGINT UNSIGNED NOT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`event_id`),
                UNIQUE KEY `uq_authority_role_event_request` (`source_resource`,`request_id`),
                CONSTRAINT `fk_authority_role_event` FOREIGN KEY (`role_id`)
                    REFERENCES `feather_authority_roles` (`role_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    },
    {
        id = '003_role_grants',
        statements = {
            [[CREATE TABLE IF NOT EXISTS `feather_authority_role_grants` (
                `grant_id` CHAR(36) NOT NULL,
                `role_id` CHAR(36) NOT NULL,
                `capability_id` CHAR(36) NOT NULL,
                `effect` VARCHAR(8) NOT NULL DEFAULT 'allow',
                `scope_type` VARCHAR(24) NOT NULL,
                `status` VARCHAR(16) NOT NULL DEFAULT 'active',
                `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `revoked_at` TIMESTAMP NULL,
                PRIMARY KEY (`grant_id`),
                UNIQUE KEY `uq_authority_role_grant` (`role_id`,`capability_id`,`scope_type`),
                CONSTRAINT `fk_authority_grant_role` FOREIGN KEY (`role_id`)
                    REFERENCES `feather_authority_roles` (`role_id`),
                CONSTRAINT `fk_authority_grant_capability` FOREIGN KEY (`capability_id`)
                    REFERENCES `feather_authority_capabilities` (`capability_id`),
                CONSTRAINT `chk_authority_grant_effect` CHECK (`effect`='allow'),
                CONSTRAINT `chk_authority_grant_scope` CHECK (`scope_type` IN ('server','organization')),
                CONSTRAINT `chk_authority_grant_status` CHECK (`status` IN ('active','revoked'))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
            [[CREATE TABLE IF NOT EXISTS `feather_authority_role_grant_receipts` (
                `source_resource` VARCHAR(100) NOT NULL,
                `request_id` VARCHAR(128) NOT NULL,
                `request_fingerprint` LONGTEXT NOT NULL,
                `result_json` LONGTEXT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`source_resource`,`request_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    },
    {
        id = '004_assignments',
        statements = {
            [[CREATE TABLE IF NOT EXISTS `feather_authority_assignments` (
                `assignment_id` CHAR(36) NOT NULL,
                `subject_type` VARCHAR(32) NOT NULL,
                `subject_id` CHAR(36) NOT NULL,
                `role_id` CHAR(36) NOT NULL,
                `issuer_type` VARCHAR(32) NOT NULL,
                `issuer_id` VARCHAR(100) NOT NULL,
                `scope_type` VARCHAR(24) NOT NULL,
                `valid_from` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `valid_until` TIMESTAMP NULL,
                `status` VARCHAR(16) NOT NULL DEFAULT 'active',
                `reason` VARCHAR(255) NOT NULL,
                `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `revoked_at` TIMESTAMP NULL,
                PRIMARY KEY (`assignment_id`),
                KEY `idx_authority_subject_assignments` (`subject_type`,`subject_id`,`status`),
                CONSTRAINT `fk_authority_assignment_role` FOREIGN KEY (`role_id`)
                    REFERENCES `feather_authority_roles` (`role_id`),
                CONSTRAINT `chk_authority_assignment_subject`
                    CHECK (`subject_type` IN ('account','character')),
                CONSTRAINT `chk_authority_assignment_issuer` CHECK (`issuer_type`='service_principal'),
                CONSTRAINT `chk_authority_assignment_scope` CHECK (`scope_type`='server'),
                CONSTRAINT `chk_authority_assignment_status`
                    CHECK (`status` IN ('active','suspended','revoked'))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
            [[CREATE TABLE IF NOT EXISTS `feather_authority_assignment_receipts` (
                `source_resource` VARCHAR(100) NOT NULL,
                `request_id` VARCHAR(128) NOT NULL,
                `request_fingerprint` LONGTEXT NOT NULL,
                `result_json` LONGTEXT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`source_resource`,`request_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    },
    {
        id = '005_assignment_events',
        statements = {
            [[CREATE TABLE IF NOT EXISTS `feather_authority_assignment_events` (
                `event_id` CHAR(36) NOT NULL,
                `assignment_id` CHAR(36) NOT NULL,
                `event_type` VARCHAR(64) NOT NULL,
                `source_resource` VARCHAR(100) NOT NULL,
                `request_id` VARCHAR(128) NOT NULL,
                `reason_code` VARCHAR(64) NOT NULL,
                `revision` BIGINT UNSIGNED NOT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`event_id`),
                UNIQUE KEY `uq_authority_assignment_event_request` (`source_resource`,`request_id`),
                CONSTRAINT `fk_authority_assignment_event` FOREIGN KEY (`assignment_id`)
                    REFERENCES `feather_authority_assignments` (`assignment_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    },
    {
        id = '006_policy_version',
        statements = {
            [[CREATE TABLE IF NOT EXISTS `feather_authority_policy_state` (
                `id` TINYINT UNSIGNED NOT NULL,
                `policy_version` BIGINT UNSIGNED NOT NULL DEFAULT 1,
                `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                CONSTRAINT `chk_authority_policy_state` CHECK (`id`=1)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
            [[INSERT IGNORE INTO `feather_authority_policy_state` (`id`,`policy_version`) VALUES (1,1)]]
        }
    },
    {
        id = '007_assignment_lifecycle',
        statements = {
            [[CREATE TABLE IF NOT EXISTS `feather_authority_assignment_lifecycle_receipts` (
                `source_resource` VARCHAR(100) NOT NULL,
                `request_id` VARCHAR(128) NOT NULL,
                `request_fingerprint` LONGTEXT NOT NULL,
                `result_json` LONGTEXT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`source_resource`,`request_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    },
    {
        id = '008_capability_registration',
        statements = {
            [[CREATE TABLE IF NOT EXISTS `feather_authority_capability_registration_receipts` (
                `source_resource` VARCHAR(100) NOT NULL,
                `request_id` VARCHAR(128) NOT NULL,
                `request_fingerprint` LONGTEXT NOT NULL,
                `result_json` LONGTEXT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`source_resource`,`request_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
            [[CREATE TABLE IF NOT EXISTS `feather_authority_capability_events` (
                `event_id` CHAR(36) NOT NULL,
                `capability_id` CHAR(36) NOT NULL,
                `event_type` VARCHAR(64) NOT NULL,
                `source_resource` VARCHAR(100) NOT NULL,
                `request_id` VARCHAR(128) NOT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`event_id`),
                UNIQUE KEY `uq_authority_capability_event_request`
                    (`capability_id`,`source_resource`,`request_id`),
                CONSTRAINT `fk_authority_capability_event` FOREIGN KEY (`capability_id`)
                    REFERENCES `feather_authority_capabilities` (`capability_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    },
    {
        id = '009_assignment_replacement',
        statements = {
            [[CREATE TABLE IF NOT EXISTS `feather_authority_assignment_replacement_receipts` (
                `source_resource` VARCHAR(100) NOT NULL,
                `request_id` VARCHAR(80) NOT NULL,
                `request_fingerprint` LONGTEXT NOT NULL,
                `result_json` LONGTEXT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`source_resource`,`request_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    }
}

local function Hash(value)
    local hash = 2166136261
    for index = 1, #value do hash = ((hash ~ value:byte(index)) * 16777619) & 0xffffffff end
    return ('fnv1a32:%08x'):format(hash)
end

function AuthorityMigrations.Run()
    DB.exec([[CREATE TABLE IF NOT EXISTS `feather_authority_schema_migrations` (
        `id` VARCHAR(100) NOT NULL,
        `checksum` VARCHAR(64) NOT NULL,
        `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]])
    local count = 0
    for _, migration in ipairs(definitions) do
        local checksum = Hash(table.concat(migration.statements, '\n-- next statement --\n'))
        local applied = DB.one(
            'SELECT `checksum` FROM `feather_authority_schema_migrations` WHERE `id`=?', migration.id)
        if applied and applied.checksum ~= checksum then
            return Authority.Err('migration_checksum_mismatch', 'An applied Authority migration changed.', {
                migrationId = migration.id
            })
        end
        if not applied then
            for _, statement in ipairs(migration.statements) do DB.raw(statement) end
            DB.insert(
                'INSERT INTO `feather_authority_schema_migrations` (`id`,`checksum`) VALUES (?,?)',
                migration.id, checksum)
            count = count + 1
        end
    end
    return Authority.Ok({ total = #definitions, applied = count })
end
