Access.Migrations = {}
Access.MigrationStatus = { total = 4, applied = 0, verified = false }

local definitions = {
    { id = '001_access_receipts', statements = {
        [[CREATE TABLE IF NOT EXISTS `feather_access_receipts` (
            `source_resource` VARCHAR(100) NOT NULL,
            `request_id` VARCHAR(128) NOT NULL,
            `operation` VARCHAR(64) NOT NULL,
            `request_fingerprint` LONGTEXT NOT NULL,
            `result_json` LONGTEXT NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`source_resource`,`request_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
    } },
    { id = '002_access_grants', statements = {
        [[CREATE TABLE IF NOT EXISTS `feather_access_grants` (
            `grant_id` CHAR(36) NOT NULL, `target_type` VARCHAR(64) NOT NULL,
            `target_id` CHAR(36) NOT NULL, `target_epoch` BIGINT UNSIGNED NOT NULL,
            `grantee_type` VARCHAR(16) NOT NULL, `grantee_id` CHAR(36) NOT NULL,
            `capability` VARCHAR(64) NOT NULL, `roles_json` TEXT NOT NULL,
            `valid_from` BIGINT UNSIGNED NOT NULL, `valid_until` BIGINT UNSIGNED NOT NULL,
            `status` VARCHAR(16) NOT NULL, `revision` BIGINT UNSIGNED NOT NULL,
            `source_resource` VARCHAR(100) NOT NULL, `provenance_type` VARCHAR(64) NOT NULL,
            `provenance_id` CHAR(36) NOT NULL, `actor_json` TEXT NOT NULL,
            PRIMARY KEY (`grant_id`),
            KEY `ix_access_target` (`target_type`,`target_id`,`grant_id`),
            KEY `ix_access_grantee` (`grantee_type`,`grantee_id`,`grant_id`),
            KEY `ix_access_check` (`target_type`,`target_id`,`capability`,`status`,`grantee_type`,`grantee_id`),
            CONSTRAINT `chk_access_validity` CHECK (`valid_until` > `valid_from`),
            CONSTRAINT `chk_access_status` CHECK (`status` IN ('active','revoked')),
            CONSTRAINT `chk_access_grantee` CHECK (`grantee_type` IN ('character','organization'))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
        [[CREATE TABLE IF NOT EXISTS `feather_access_events` (
            `event_id` CHAR(36) NOT NULL, `grant_id` CHAR(36) NOT NULL,
            `event_type` VARCHAR(64) NOT NULL, `payload_json` LONGTEXT NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`event_id`), KEY `ix_access_event_grant` (`grant_id`),
            CONSTRAINT `fk_access_event_grant` FOREIGN KEY (`grant_id`) REFERENCES `feather_access_grants` (`grant_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
        [[CREATE TABLE IF NOT EXISTS `feather_access_outbox` (
            `event_id` CHAR(36) NOT NULL, `event_type` VARCHAR(64) NOT NULL,
            `payload_json` LONGTEXT NOT NULL, `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`event_id`), KEY `ix_access_pending` (`status`,`event_id`),
            CONSTRAINT `fk_access_outbox_event` FOREIGN KEY (`event_id`) REFERENCES `feather_access_events` (`event_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
    } },
    { id = '003_access_audit_delivery', statements = {
        [[ALTER TABLE `feather_access_outbox`
            ADD COLUMN IF NOT EXISTS `audit_payload` LONGTEXT NULL,
            ADD COLUMN IF NOT EXISTS `audit_canonical` LONGTEXT NULL,
            ADD COLUMN IF NOT EXISTS `attempt_count` INT UNSIGNED NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `available_at` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `lease_owner` CHAR(36) NULL,
            ADD COLUMN IF NOT EXISTS `lease_until` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            ADD COLUMN IF NOT EXISTS `audit_event_id` CHAR(36) NULL,
            ADD COLUMN IF NOT EXISTS `last_result` VARCHAR(64) NULL,
            ADD COLUMN IF NOT EXISTS `delivered_at` TIMESTAMP NULL]],
        [[CREATE INDEX IF NOT EXISTS `ix_access_audit_queue`
            ON `feather_access_outbox` (`status`,`available_at`,`lease_until`,`event_id`)]],
    } },
}

local function Checksum(statements)
    local input, hash = table.concat(statements, '\n-- next statement --\n'), 2166136261
    for index = 1, #input do hash = ((hash ~ input:byte(index)) * 16777619) & 0xffffffff end
    return ('fnv1a32:%08x'):format(hash)
end

definitions[#definitions + 1] = {id='004_access_preservation_manifests', statements={[[
    CREATE TABLE IF NOT EXISTS `feather_access_preservation_manifests` (
        `manifest_id` CHAR(36) NOT NULL PRIMARY KEY, `target_type` VARCHAR(64) NOT NULL,
        `target_id` CHAR(36) NOT NULL, `source_epoch` BIGINT UNSIGNED NOT NULL,
        `candidates_json` LONGTEXT NOT NULL, `actor_json` LONGTEXT NOT NULL,
        `status` VARCHAR(16) NOT NULL DEFAULT 'prepared',
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]}}

function Access.Migrations.Run()
    DB.exec([[CREATE TABLE IF NOT EXISTS `feather_access_schema_migrations` (
        `id` VARCHAR(100) NOT NULL, `checksum` VARCHAR(64) NOT NULL,
        `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]])
    local known, appliedCount = {}, 0
    for _, migration in ipairs(definitions) do known[migration.id] = true end
    for _, row in ipairs(DB.query('SELECT `id` FROM `feather_access_schema_migrations`')) do
        if not known[row.id] then
            return Access.Err('migration_unknown', 'Database contains a newer or unknown Access migration.',
                { migrationId = row.id })
        end
    end
    for _, migration in ipairs(definitions) do
        local checksum = Checksum(migration.statements)
        local applied = DB.one('SELECT `checksum` FROM `feather_access_schema_migrations` WHERE `id`=?', migration.id)
        if applied and applied.checksum ~= checksum then
            return Access.Err('migration_checksum_mismatch', 'An applied Access migration changed.',
                { migrationId = migration.id })
        end
        if not applied then
            -- MariaDB DDL autocommits. Statements must be restart-safe; record only after all succeed.
            for _, statement in ipairs(migration.statements) do DB.exec(statement) end
            DB.insert('INSERT INTO `feather_access_schema_migrations` (`id`,`checksum`) VALUES (?,?)',
                migration.id, checksum)
            appliedCount = appliedCount + 1
        end
    end
    Access.MigrationStatus = { total = #definitions, applied = appliedCount, verified = true }
    return Access.Ok(Access.Copy(Access.MigrationStatus))
end
