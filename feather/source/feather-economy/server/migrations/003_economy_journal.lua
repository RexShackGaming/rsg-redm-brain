EconomyMigrationDefinitions = EconomyMigrationDefinitions or {}

EconomyMigrationDefinitions[#EconomyMigrationDefinitions + 1] = {
    id = '003_economy_journal',
    statements = {
        [[
            CREATE TABLE IF NOT EXISTS `economy_transactions` (
              `transaction_id` CHAR(36) NOT NULL,
              `operation_type` VARCHAR(24) NOT NULL,
              `status` VARCHAR(16) NOT NULL,
              `currency_code` VARCHAR(32) NOT NULL,
              `reason_code` VARCHAR(64) NOT NULL,
              `reference_type` VARCHAR(48) NULL,
              `reference_id` VARCHAR(128) NULL,
              `source_resource` VARCHAR(64) NOT NULL,
              `actor_account_id` CHAR(36) NULL,
              `actor_character_id` CHAR(36) NULL,
              `correlation_id` VARCHAR(128) NULL,
              `idempotency_key` VARCHAR(128) NOT NULL,
              `request_fingerprint` VARCHAR(512) NOT NULL,
              `result_json` LONGTEXT NULL,
              `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              `posted_at` TIMESTAMP NULL,
              PRIMARY KEY (`transaction_id`),
              UNIQUE KEY `uq_economy_transaction_request`
                (`source_resource`,`operation_type`,`idempotency_key`),
              KEY `idx_economy_transaction_reference` (`reference_type`,`reference_id`),
              CONSTRAINT `fk_economy_transaction_currency`
                FOREIGN KEY (`currency_code`) REFERENCES `economy_currencies` (`currency_code`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `economy_entries` (
              `entry_id` CHAR(36) NOT NULL,
              `transaction_id` CHAR(36) NOT NULL,
              `account_id` CHAR(36) NOT NULL,
              `amount` BIGINT NOT NULL,
              `resulting_balance` BIGINT NOT NULL,
              `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (`entry_id`),
              KEY `idx_economy_entries_transaction` (`transaction_id`),
              KEY `idx_economy_entries_account` (`account_id`,`created_at`),
              CONSTRAINT `fk_economy_entry_transaction`
                FOREIGN KEY (`transaction_id`) REFERENCES `economy_transactions` (`transaction_id`),
              CONSTRAINT `fk_economy_entry_account`
                FOREIGN KEY (`account_id`) REFERENCES `economy_accounts` (`account_id`),
              CONSTRAINT `chk_economy_entry_nonzero` CHECK (`amount` <> 0)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `economy_outbox` (
              `event_id` CHAR(36) NOT NULL,
              `event_type` VARCHAR(96) NOT NULL,
              `aggregate_id` CHAR(36) NOT NULL,
              `payload_json` LONGTEXT NOT NULL,
              `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
              `attempts` INT UNSIGNED NOT NULL DEFAULT 0,
              `available_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              `published_at` TIMESTAMP NULL,
              PRIMARY KEY (`event_id`),
              KEY `idx_economy_outbox_delivery` (`status`,`available_at`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]
    }
}
