LicenseMigrations = {}

-- Applied migrations are checksummed. Never edit one; add a new migration instead.
local definitions = {
    {
        id = '001_license_definitions',
        statements = {
            -- One row per license kind (hunting, weapons, ...), owned by the
            -- resource that registered it. Durations are seconds; NULL = no limit.
            [[CREATE TABLE IF NOT EXISTS `feather_license_definitions` (
                `license_key` VARCHAR(48) NOT NULL,
                `label` VARCHAR(100) NOT NULL,
                `owner_resource` VARCHAR(100) NOT NULL,
                `holder_types` VARCHAR(255) NOT NULL,
                `default_duration_seconds` INT UNSIGNED NULL,
                `max_duration_seconds` INT UNSIGNED NULL,
                `renewable` TINYINT(1) NOT NULL DEFAULT 1,
                `status` VARCHAR(16) NOT NULL DEFAULT 'active',
                `scope_version` INT UNSIGNED NOT NULL DEFAULT 1,
                `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`license_key`),
                KEY `idx_license_definition_owner` (`owner_resource`,`status`),
                CONSTRAINT `chk_license_definition_status` CHECK (`status` IN ('active','retired'))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    },
    {
        id = '002_licenses',
        statements = {
            -- current_slot is set while a license is active or suspended and NULL
            -- once revoked, so the unique key allows one current license per
            -- holder and kind without blocking history. expires_at_ms is Unix
            -- milliseconds (NULL = never expires): validity is computed against
            -- the database clock at every read and never waits for the sweep.
            [[CREATE TABLE IF NOT EXISTS `feather_licenses` (
                `license_id` CHAR(36) NOT NULL,
                `license_key` VARCHAR(48) NOT NULL,
                `holder_type` VARCHAR(32) NOT NULL,
                `holder_id` CHAR(36) NOT NULL,
                `status` VARCHAR(16) NOT NULL DEFAULT 'active',
                `current_slot` VARCHAR(128) NULL,
                `issuer_type` VARCHAR(16) NOT NULL,
                `issuer_id` CHAR(36) NULL,
                `issuer_resource` VARCHAR(100) NOT NULL,
                `scope_version` INT UNSIGNED NOT NULL DEFAULT 1,
                `scope_json` LONGTEXT NULL,
                `issued_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `expires_at_ms` BIGINT UNSIGNED NULL,
                `renewed_at` TIMESTAMP NULL,
                `suspended_at` TIMESTAMP NULL,
                `revoked_at` TIMESTAMP NULL,
                `expiry_notified_at` TIMESTAMP NULL,
                `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
                PRIMARY KEY (`license_id`),
                UNIQUE KEY `uq_license_current` (`current_slot`),
                KEY `idx_license_holder` (`holder_type`,`holder_id`,`status`),
                KEY `idx_license_key` (`license_key`,`status`),
                KEY `idx_license_expiry` (`expiry_notified_at`,`expires_at_ms`),
                CONSTRAINT `fk_license_definition` FOREIGN KEY (`license_key`)
                    REFERENCES `feather_license_definitions` (`license_key`),
                CONSTRAINT `chk_license_status` CHECK (`status` IN ('active','suspended','revoked')),
                CONSTRAINT `chk_license_issuer` CHECK (`issuer_type` IN ('system','character','organization')),
                CONSTRAINT `chk_license_slot` CHECK ((`status` = 'revoked') = (`current_slot` IS NULL))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    },
    {
        id = '003_license_receipts_events_outbox',
        statements = {
            [[CREATE TABLE IF NOT EXISTS `feather_license_receipts` (
                `source_resource` VARCHAR(100) NOT NULL,
                `request_id` VARCHAR(128) NOT NULL,
                `operation` VARCHAR(48) NOT NULL,
                `request_fingerprint` LONGTEXT NOT NULL,
                `result_json` LONGTEXT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`source_resource`,`request_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
            -- aggregate_id is a license UUID or a definition key.
            [[CREATE TABLE IF NOT EXISTS `feather_license_events` (
                `event_id` CHAR(36) NOT NULL,
                `event_type` VARCHAR(64) NOT NULL,
                `aggregate_type` VARCHAR(16) NOT NULL,
                `aggregate_id` VARCHAR(48) NOT NULL,
                `license_key` VARCHAR(48) NOT NULL,
                `holder_type` VARCHAR(32) NULL,
                `holder_id` CHAR(36) NULL,
                `source_resource` VARCHAR(100) NOT NULL,
                `request_id` VARCHAR(128) NOT NULL,
                `reason_code` VARCHAR(64) NOT NULL,
                `reference_type` VARCHAR(48) NULL,
                `reference_id` VARCHAR(128) NULL,
                `revision` BIGINT UNSIGNED NOT NULL,
                `actor_account_id` CHAR(36) NULL,
                `actor_character_id` CHAR(36) NULL,
                `correlation_id` VARCHAR(128) NULL,
                `details_json` LONGTEXT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`event_id`),
                UNIQUE KEY `uq_license_event_request` (`source_resource`,`request_id`,`event_type`),
                KEY `idx_license_event_aggregate` (`aggregate_type`,`aggregate_id`,`created_at`),
                KEY `idx_license_event_holder` (`holder_type`,`holder_id`,`created_at`),
                KEY `idx_license_event_reference` (`reference_type`,`reference_id`),
                CONSTRAINT `chk_license_event_aggregate` CHECK (`aggregate_type` IN ('definition','license'))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
            [[CREATE TABLE IF NOT EXISTS `feather_license_outbox` (
                `event_id` CHAR(36) NOT NULL,
                `event_type` VARCHAR(100) NOT NULL,
                `payload_json` LONGTEXT NOT NULL,
                `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
                `attempts` BIGINT UNSIGNED NOT NULL DEFAULT 0,
                `available_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `published_at` TIMESTAMP NULL,
                PRIMARY KEY (`event_id`),
                KEY `idx_license_outbox_pending` (`status`,`available_at`),
                CONSTRAINT `fk_license_outbox_event` FOREIGN KEY (`event_id`)
                    REFERENCES `feather_license_events` (`event_id`),
                CONSTRAINT `chk_license_outbox_status` CHECK (`status` IN ('pending','published'))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    }
}
LicenseMigrations.Count = #definitions

local function Hash(value)
    local hash = 2166136261
    for index = 1, #value do
        hash = ((hash ~ value:byte(index)) * 16777619) & 0xffffffff
    end
    return ('fnv1a32:%08x'):format(hash)
end

function LicenseMigrations.Run()
    DB.exec([[
        CREATE TABLE IF NOT EXISTS `feather_license_schema_migrations` (
            `id` VARCHAR(100) NOT NULL,
            `checksum` VARCHAR(64) NOT NULL,
            `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]])
    local count = 0
    for _, migration in ipairs(definitions) do
        local checksum = Hash(table.concat(migration.statements, '\n-- next statement --\n'))
        local applied = DB.one('SELECT `checksum` FROM `feather_license_schema_migrations` WHERE `id`=?', migration.id)
        if applied and applied.checksum ~= checksum then
            return Licenses.Err('migration_checksum_mismatch', 'An applied licenses migration changed.', {
                migrationId = migration.id
            })
        end
        if not applied then
            for _, statement in ipairs(migration.statements) do
                DB.exec(statement)
            end
            DB.insert('INSERT INTO `feather_license_schema_migrations` (`id`,`checksum`) VALUES (?,?)',
                migration.id, checksum)
            count = count + 1
        end
    end
    return Licenses.Ok({ total = #definitions, applied = count })
end
