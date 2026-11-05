PropertyMigrations = {}

-- Applied migrations are checksummed. Never edit one; add a new migration instead.
local definitions = {
    {
        id = '001_property_records',
        statements = {
            -- property_key is the stable, namespaced identity a consumer registers
            -- (bcc-housing:house0); property_id is the UUID every reference uses.
            [[CREATE TABLE IF NOT EXISTS `feather_properties` (
                `property_id` CHAR(36) NOT NULL,
                `property_key` VARCHAR(128) NOT NULL,
                `property_type` VARCHAR(32) NOT NULL,
                `label` VARCHAR(100) NOT NULL,
                `status` VARCHAR(16) NOT NULL DEFAULT 'active',
                `manager_resource` VARCHAR(100) NOT NULL,
                `max_owners` SMALLINT UNSIGNED NOT NULL,
                `max_tenants` SMALLINT UNSIGNED NOT NULL,
                `metadata_version` INT UNSIGNED NOT NULL DEFAULT 1,
                `metadata_json` LONGTEXT NULL,
                `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                `retired_at` TIMESTAMP NULL,
                PRIMARY KEY (`property_id`),
                UNIQUE KEY `uq_property_key` (`property_key`),
                KEY `idx_property_type` (`property_type`,`status`),
                KEY `idx_property_manager` (`manager_resource`,`status`),
                CONSTRAINT `chk_property_status` CHECK (`status` IN ('active','suspended','retired'))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    },
    {
        id = '002_property_interests',
        statements = {
            -- active_slot is set while the interest is active and NULL once ended, so
            -- one holder has at most one active interest of each type per property
            -- while history is kept. Owner and tenant caps are enforced under the
            -- property row lock. valid_until bounds a tenancy; ended_at records when
            -- the interest actually ended.
            [[CREATE TABLE IF NOT EXISTS `feather_property_interests` (
                `interest_id` CHAR(36) NOT NULL,
                `property_id` CHAR(36) NOT NULL,
                `holder_type` VARCHAR(32) NOT NULL,
                `holder_id` CHAR(36) NOT NULL,
                `interest_type` VARCHAR(16) NOT NULL,
                `status` VARCHAR(16) NOT NULL DEFAULT 'active',
                `active_slot` VARCHAR(128) NULL,
                `valid_from` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `valid_until` TIMESTAMP NULL,
                `ended_at` TIMESTAMP NULL,
                `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
                PRIMARY KEY (`interest_id`),
                UNIQUE KEY `uq_property_interest_active` (`active_slot`),
                KEY `idx_property_interest_holder` (`holder_type`,`holder_id`,`interest_type`,`status`),
                KEY `idx_property_interest_property` (`property_id`,`interest_type`,`status`),
                KEY `idx_property_interest_expiry` (`status`,`valid_until`),
                CONSTRAINT `fk_property_interest_property` FOREIGN KEY (`property_id`)
                    REFERENCES `feather_properties` (`property_id`),
                CONSTRAINT `chk_property_interest_status` CHECK (`status` IN ('active','ended')),
                CONSTRAINT `chk_property_interest_type` CHECK (`interest_type` IN ('owner','tenant'))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    },
    {
        id = '003_property_receipts_events_outbox',
        statements = {
            [[CREATE TABLE IF NOT EXISTS `feather_property_receipts` (
                `source_resource` VARCHAR(100) NOT NULL,
                `request_id` VARCHAR(128) NOT NULL,
                `operation` VARCHAR(48) NOT NULL,
                `request_fingerprint` LONGTEXT NOT NULL,
                `result_json` LONGTEXT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`source_resource`,`request_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
            [[CREATE TABLE IF NOT EXISTS `feather_property_events` (
                `event_id` CHAR(36) NOT NULL,
                `event_type` VARCHAR(64) NOT NULL,
                `property_id` CHAR(36) NOT NULL,
                `property_type` VARCHAR(32) NOT NULL,
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
                KEY `idx_property_event_request` (`source_resource`,`request_id`),
                KEY `idx_property_event_property` (`property_id`,`created_at`),
                KEY `idx_property_event_holder` (`holder_type`,`holder_id`,`created_at`),
                KEY `idx_property_event_reference` (`reference_type`,`reference_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
            [[CREATE TABLE IF NOT EXISTS `feather_property_outbox` (
                `event_id` CHAR(36) NOT NULL,
                `event_type` VARCHAR(100) NOT NULL,
                `payload_json` LONGTEXT NOT NULL,
                `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
                `attempts` BIGINT UNSIGNED NOT NULL DEFAULT 0,
                `available_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `published_at` TIMESTAMP NULL,
                PRIMARY KEY (`event_id`),
                KEY `idx_property_outbox_pending` (`status`,`available_at`),
                CONSTRAINT `fk_property_outbox_event` FOREIGN KEY (`event_id`)
                    REFERENCES `feather_property_events` (`event_id`),
                CONSTRAINT `chk_property_outbox_status` CHECK (`status` IN ('pending','published'))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    },
    {
        id = '004_property_links',
        statements = {
            -- Things attached to a property (storage containers, doors). The unique
            -- (link_type, external_id) makes one external thing belong to at most one
            -- property; a link is removed, never edited, so it carries no revision of
            -- its own (the property revision covers it).
            [[CREATE TABLE IF NOT EXISTS `feather_property_links` (
                `link_id` CHAR(36) NOT NULL,
                `property_id` CHAR(36) NOT NULL,
                `link_type` VARCHAR(32) NOT NULL,
                `external_id` VARCHAR(128) NOT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`link_id`),
                UNIQUE KEY `uq_property_link_external` (`link_type`,`external_id`),
                KEY `idx_property_link_property` (`property_id`,`link_type`),
                CONSTRAINT `fk_property_link_property` FOREIGN KEY (`property_id`)
                    REFERENCES `feather_properties` (`property_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    }
}
definitions[#definitions + 1] = {
    id = '005_property_delegation_epoch',
    statements = {[[ALTER TABLE `feather_properties`
        ADD COLUMN IF NOT EXISTS `delegation_epoch` BIGINT UNSIGNED NOT NULL DEFAULT 1 AFTER `revision`]]}
}
PropertyMigrations.Count = #definitions

local function Hash(value)
    local hash = 2166136261
    for index = 1, #value do
        hash = ((hash ~ value:byte(index)) * 16777619) & 0xffffffff
    end
    return ('fnv1a32:%08x'):format(hash)
end

function PropertyMigrations.Run()
    DB.exec([[
        CREATE TABLE IF NOT EXISTS `feather_property_schema_migrations` (
            `id` VARCHAR(100) NOT NULL,
            `checksum` VARCHAR(64) NOT NULL,
            `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]])
    local count = 0
    for _, migration in ipairs(definitions) do
        local checksum = Hash(table.concat(migration.statements, '\n-- next statement --\n'))
        local applied = DB.one('SELECT `checksum` FROM `feather_property_schema_migrations` WHERE `id`=?', migration.id)
        if applied and applied.checksum ~= checksum then
            return Property.Err('migration_checksum_mismatch', 'An applied property migration changed.', {
                migrationId = migration.id
            })
        end
        if not applied then
            for _, statement in ipairs(migration.statements) do
                DB.exec(statement)
            end
            DB.insert('INSERT INTO `feather_property_schema_migrations` (`id`,`checksum`) VALUES (?,?)',
                migration.id, checksum)
            count = count + 1
        end
    end
    return Property.Ok({ total = #definitions, applied = count })
end
