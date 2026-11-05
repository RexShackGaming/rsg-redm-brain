AssetMigrations = {}

-- Applied migrations are checksummed. Never edit one; add a new migration instead.
local definitions = {
    {
        id = '001_asset_records',
        statements = {
            -- The managing resource plus its provenance is unique, so one purchase,
            -- capture or legacy row can never register two assets.
            [[CREATE TABLE IF NOT EXISTS `feather_asset_records` (
                `asset_id` CHAR(36) NOT NULL,
                `asset_type` VARCHAR(32) NOT NULL,
                `model_key` VARCHAR(100) NOT NULL,
                `status` VARCHAR(16) NOT NULL DEFAULT 'active',
                `manager_resource` VARCHAR(100) NOT NULL,
                `provenance_type` VARCHAR(48) NOT NULL,
                `provenance_id` VARCHAR(128) NOT NULL,
                `metadata_version` INT UNSIGNED NOT NULL DEFAULT 1,
                `metadata_json` LONGTEXT NULL,
                `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                `retired_at` TIMESTAMP NULL,
                PRIMARY KEY (`asset_id`),
                UNIQUE KEY `uq_asset_provenance` (`manager_resource`,`provenance_type`,`provenance_id`),
                KEY `idx_asset_type` (`asset_type`,`status`),
                CONSTRAINT `chk_asset_status` CHECK (`status` IN ('active','held','missing','retired'))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    },
    {
        id = '002_asset_interests',
        statements = {
            -- active_slot is set while the interest is active and NULL once ended, so
            -- the unique key allows exactly one active interest of each type per asset
            -- (one owner) without blocking ownership history.
            [[CREATE TABLE IF NOT EXISTS `feather_asset_interests` (
                `interest_id` CHAR(36) NOT NULL,
                `asset_id` CHAR(36) NOT NULL,
                `holder_type` VARCHAR(32) NOT NULL,
                `holder_id` CHAR(36) NOT NULL,
                `interest_type` VARCHAR(16) NOT NULL,
                `status` VARCHAR(16) NOT NULL DEFAULT 'active',
                `active_slot` VARCHAR(64) NULL,
                `valid_from` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `valid_until` TIMESTAMP NULL,
                `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
                PRIMARY KEY (`interest_id`),
                UNIQUE KEY `uq_asset_interest_active` (`active_slot`),
                KEY `idx_asset_interest_holder` (`holder_type`,`holder_id`,`interest_type`,`status`),
                KEY `idx_asset_interest_asset` (`asset_id`,`interest_type`,`status`),
                CONSTRAINT `fk_asset_interest_asset` FOREIGN KEY (`asset_id`)
                    REFERENCES `feather_asset_records` (`asset_id`),
                CONSTRAINT `chk_asset_interest_status` CHECK (`status` IN ('active','ended'))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    },
    {
        id = '003_asset_receipts_events_outbox',
        statements = {
            [[CREATE TABLE IF NOT EXISTS `feather_asset_receipts` (
                `source_resource` VARCHAR(100) NOT NULL,
                `request_id` VARCHAR(128) NOT NULL,
                `operation` VARCHAR(48) NOT NULL,
                `request_fingerprint` LONGTEXT NOT NULL,
                `result_json` LONGTEXT NULL,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`source_resource`,`request_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
            [[CREATE TABLE IF NOT EXISTS `feather_asset_events` (
                `event_id` CHAR(36) NOT NULL,
                `event_type` VARCHAR(64) NOT NULL,
                `asset_id` CHAR(36) NOT NULL,
                `asset_type` VARCHAR(32) NOT NULL,
                `holder_type` VARCHAR(32) NULL,
                `holder_id` CHAR(36) NULL,
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
                UNIQUE KEY `uq_asset_event_request` (`source_resource`,`request_id`,`event_type`),
                KEY `idx_asset_event_asset` (`asset_id`,`created_at`),
                KEY `idx_asset_event_holder` (`holder_type`,`holder_id`,`created_at`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]],
            [[CREATE TABLE IF NOT EXISTS `feather_asset_outbox` (
                `event_id` CHAR(36) NOT NULL,
                `event_type` VARCHAR(100) NOT NULL,
                `payload_json` LONGTEXT NOT NULL,
                `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
                `attempts` BIGINT UNSIGNED NOT NULL DEFAULT 0,
                `available_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `published_at` TIMESTAMP NULL,
                PRIMARY KEY (`event_id`),
                KEY `idx_asset_outbox_pending` (`status`,`available_at`),
                CONSTRAINT `fk_asset_outbox_event` FOREIGN KEY (`event_id`)
                    REFERENCES `feather_asset_events` (`event_id`),
                CONSTRAINT `chk_asset_outbox_status` CHECK (`status` IN ('pending','published'))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]]
        }
    },
    {
        id = '004_asset_event_references',
        statements = {
            -- Links an audit fact to the consumer record behind it (for example
            -- stables_order + order UUID), so a workflow can be traced across domains.
            [[ALTER TABLE `feather_asset_events`
                ADD COLUMN IF NOT EXISTS `reference_type` VARCHAR(48) NULL AFTER `reason_code`,
                ADD COLUMN IF NOT EXISTS `reference_id` VARCHAR(128) NULL AFTER `reference_type`,
                ADD KEY IF NOT EXISTS `idx_asset_event_reference` (`reference_type`,`reference_id`)]]
        }
    },
    {
        id = '005_asset_delegation_epoch',
        statements = {
            -- Target-owned generation for delegated use (feather-access). It rises
            -- in the same commit as an owner change or retirement and never on a
            -- status or metadata change, so the general revision cannot stand in
            -- for it. Existing assets start at 1; no grants exist before this.
            [[ALTER TABLE `feather_asset_records`
                ADD COLUMN IF NOT EXISTS `delegation_epoch` BIGINT UNSIGNED NOT NULL DEFAULT 1 AFTER `revision`]]
        }
    }
}
AssetMigrations.Count = #definitions

local function Hash(value)
    local hash = 2166136261
    for index = 1, #value do
        hash = ((hash ~ value:byte(index)) * 16777619) & 0xffffffff
    end
    return ('fnv1a32:%08x'):format(hash)
end

function AssetMigrations.Run()
    DB.exec([[
        CREATE TABLE IF NOT EXISTS `feather_asset_schema_migrations` (
            `id` VARCHAR(100) NOT NULL,
            `checksum` VARCHAR(64) NOT NULL,
            `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]])
    local count = 0
    for _, migration in ipairs(definitions) do
        local checksum = Hash(table.concat(migration.statements, '\n-- next statement --\n'))
        local applied = DB.one('SELECT `checksum` FROM `feather_asset_schema_migrations` WHERE `id`=?', migration.id)
        if applied and applied.checksum ~= checksum then
            return Assets.Err('migration_checksum_mismatch', 'An applied assets migration changed.', {
                migrationId = migration.id
            })
        end
        if not applied then
            for _, statement in ipairs(migration.statements) do
                DB.exec(statement)
            end
            DB.insert('INSERT INTO `feather_asset_schema_migrations` (`id`,`checksum`) VALUES (?,?)',
                migration.id, checksum)
            count = count + 1
        end
    end
    return Assets.Ok({ total = #definitions, applied = count })
end
