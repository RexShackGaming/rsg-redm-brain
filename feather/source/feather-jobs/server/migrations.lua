JobMigrations = {}
local definitions = {
    { id = '001_job_definitions', statements = {
        [[CREATE TABLE IF NOT EXISTS `feather_job_definitions` (
            `job_id` CHAR(36) NOT NULL,
            `job_key` VARCHAR(48) NOT NULL,
            `label` VARCHAR(100) NOT NULL,
            `owner_resource` VARCHAR(100) NOT NULL,
            `status` VARCHAR(16) NOT NULL DEFAULT 'active',
            `metadata_version` INT UNSIGNED NOT NULL DEFAULT 1,
            `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`job_id`), UNIQUE KEY `uq_job_key` (`job_key`),
            KEY `idx_job_owner` (`owner_resource`),
            CONSTRAINT `chk_job_status` CHECK (`status` IN ('active','retired'))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
        [[CREATE TABLE IF NOT EXISTS `feather_job_grades` (
            `grade_id` CHAR(36) NOT NULL,
            `job_id` CHAR(36) NOT NULL,
            `grade_key` VARCHAR(48) NOT NULL,
            `label` VARCHAR(100) NOT NULL,
            `ordinal` SMALLINT UNSIGNED NOT NULL,
            `status` VARCHAR(16) NOT NULL DEFAULT 'active',
            `metadata_version` INT UNSIGNED NOT NULL DEFAULT 1,
            `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`grade_id`),
            UNIQUE KEY `uq_job_grade_key` (`job_id`,`grade_key`),
            UNIQUE KEY `uq_job_grade_ordinal` (`job_id`,`ordinal`),
            CONSTRAINT `fk_job_grade_job` FOREIGN KEY (`job_id`) REFERENCES `feather_job_definitions` (`job_id`),
            CONSTRAINT `chk_job_grade_status` CHECK (`status` IN ('active','retired'))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
    } },
    { id = '002_job_assignments', statements = {
        -- open_slot is set while active and NULL once ended, so the unique key allows
        -- one open assignment per character/job/employer without blocking history.
        [[CREATE TABLE IF NOT EXISTS `feather_job_assignments` (
            `assignment_id` CHAR(36) NOT NULL,
            `character_id` CHAR(36) NOT NULL,
            `job_id` CHAR(36) NOT NULL,
            `grade_id` CHAR(36) NOT NULL,
            `employer_type` VARCHAR(32) NULL,
            `employer_id` CHAR(36) NULL,
            `status` VARCHAR(16) NOT NULL DEFAULT 'active',
            `duty_state` VARCHAR(16) NOT NULL DEFAULT 'off_duty',
            `owner_resource` VARCHAR(100) NOT NULL,
            `provenance_type` VARCHAR(48) NOT NULL,
            `provenance_id` VARCHAR(128) NOT NULL,
            `open_slot` VARCHAR(160) NULL,
            `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
            `assigned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `ended_at` TIMESTAMP NULL,
            PRIMARY KEY (`assignment_id`),
            UNIQUE KEY `uq_job_assignment_open` (`open_slot`),
            KEY `idx_job_assignment_character` (`character_id`,`status`),
            KEY `idx_job_assignment_employer` (`employer_type`,`employer_id`,`status`),
            KEY `idx_job_assignment_provenance` (`owner_resource`,`provenance_type`,`provenance_id`),
            CONSTRAINT `fk_job_assignment_job` FOREIGN KEY (`job_id`) REFERENCES `feather_job_definitions` (`job_id`),
            CONSTRAINT `fk_job_assignment_grade` FOREIGN KEY (`grade_id`) REFERENCES `feather_job_grades` (`grade_id`),
            CONSTRAINT `chk_job_assignment_status` CHECK (`status` IN ('active','ended')),
            CONSTRAINT `chk_job_assignment_duty` CHECK (`duty_state` IN ('off_duty','on_duty','suspended')),
            CONSTRAINT `chk_job_assignment_employer` CHECK ((`employer_type` IS NULL) = (`employer_id` IS NULL))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
        [[CREATE TABLE IF NOT EXISTS `feather_job_character_state` (
            `character_id` CHAR(36) NOT NULL,
            `active_assignment_id` CHAR(36) NULL,
            `revision` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (`character_id`),
            CONSTRAINT `fk_job_character_active` FOREIGN KEY (`active_assignment_id`)
                REFERENCES `feather_job_assignments` (`assignment_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
    } },
    { id = '003_job_receipts_events_outbox', statements = {
        [[CREATE TABLE IF NOT EXISTS `feather_job_receipts` (
            `source_resource` VARCHAR(100) NOT NULL, `request_id` VARCHAR(128) NOT NULL,
            `operation` VARCHAR(48) NOT NULL,
            `request_fingerprint` LONGTEXT NOT NULL, `result_json` LONGTEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`source_resource`,`request_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
        [[CREATE TABLE IF NOT EXISTS `feather_job_events` (
            `event_id` CHAR(36) NOT NULL,
            `event_type` VARCHAR(64) NOT NULL,
            `aggregate_type` VARCHAR(16) NOT NULL,
            `aggregate_id` CHAR(36) NOT NULL,
            `job_id` CHAR(36) NULL,
            `character_id` CHAR(36) NULL,
            `source_resource` VARCHAR(100) NOT NULL,
            `request_id` VARCHAR(128) NOT NULL,
            `reason_code` VARCHAR(64) NOT NULL,
            `revision` BIGINT UNSIGNED NOT NULL,
            `actor_account_id` CHAR(36) NULL,
            `actor_character_id` CHAR(36) NULL,
            `correlation_id` VARCHAR(128) NULL,
            `details_json` LONGTEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`event_id`),
            UNIQUE KEY `uq_job_event_request` (`source_resource`,`request_id`,`event_type`),
            KEY `idx_job_event_aggregate` (`aggregate_type`,`aggregate_id`,`created_at`),
            KEY `idx_job_event_character` (`character_id`,`created_at`),
            CONSTRAINT `chk_job_event_aggregate` CHECK (`aggregate_type` IN ('definition','grade','assignment','character'))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
        [[CREATE TABLE IF NOT EXISTS `feather_job_outbox` (
            `event_id` CHAR(36) NOT NULL, `event_type` VARCHAR(100) NOT NULL,
            `payload_json` LONGTEXT NOT NULL, `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
            `attempts` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            `available_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `published_at` TIMESTAMP NULL,
            PRIMARY KEY (`event_id`), KEY `idx_job_outbox_pending` (`status`,`available_at`),
            CONSTRAINT `fk_job_outbox_event` FOREIGN KEY (`event_id`) REFERENCES `feather_job_events` (`event_id`),
            CONSTRAINT `chk_job_outbox_status` CHECK (`status` IN ('pending','published'))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
    } },
    { id = '004_job_event_references', statements = {
        -- Links an audit fact to the consumer record behind it (for example
        -- society_membership + membership ID), so a workflow can be traced across domains.
        [[ALTER TABLE `feather_job_events`
            ADD COLUMN IF NOT EXISTS `reference_type` VARCHAR(48) NULL AFTER `reason_code`,
            ADD COLUMN IF NOT EXISTS `reference_id` VARCHAR(128) NULL AFTER `reference_type`,
            ADD KEY IF NOT EXISTS `idx_job_event_reference` (`reference_type`,`reference_id`)]]
    } }
}
JobMigrations.Count = #definitions

local function Hash(value)
    local hash = 2166136261
    for index = 1, #value do hash = ((hash ~ value:byte(index)) * 16777619) & 0xffffffff end
    return ('fnv1a32:%08x'):format(hash)
end

function JobMigrations.Run()
    DB.exec([[CREATE TABLE IF NOT EXISTS `feather_job_schema_migrations` (
        `id` VARCHAR(100) NOT NULL, `checksum` VARCHAR(64) NOT NULL,
        `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]])
    local count = 0
    for _, migration in ipairs(definitions) do
        local checksum = Hash(table.concat(migration.statements, '\n-- next statement --\n'))
        local applied = DB.one('SELECT `checksum` FROM `feather_job_schema_migrations` WHERE `id`=?', migration.id)
        if applied and applied.checksum ~= checksum then
            return Jobs.Err('migration_checksum_mismatch', 'An applied jobs migration changed.', {
                migrationId = migration.id
            })
        end
        if not applied then
            for _, statement in ipairs(migration.statements) do DB.exec(statement) end
            DB.insert('INSERT INTO `feather_job_schema_migrations` (`id`,`checksum`) VALUES (?,?)',
                migration.id, checksum)
            count = count + 1
        end
    end
    return Jobs.Ok({ total = #definitions, applied = count })
end
