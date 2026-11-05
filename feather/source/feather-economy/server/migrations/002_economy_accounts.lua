EconomyMigrationDefinitions = EconomyMigrationDefinitions or {}

EconomyMigrationDefinitions[#EconomyMigrationDefinitions + 1] = {
    id = '002_economy_accounts',
    statements = {
        [[
            CREATE TABLE IF NOT EXISTS `economy_accounts` (
              `account_id` CHAR(36) NOT NULL,
              `owner_type` VARCHAR(16) NOT NULL,
              `owner_id` CHAR(36) NOT NULL,
              `account_type` VARCHAR(24) NOT NULL,
              `currency_code` VARCHAR(32) NOT NULL,
              `status` VARCHAR(16) NOT NULL DEFAULT 'open',
              `label` VARCHAR(96) NULL,
              `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
              `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              `closed_at` TIMESTAMP NULL,
              PRIMARY KEY (`account_id`),
              UNIQUE KEY `uq_economy_owner_account`
                (`owner_type`,`owner_id`,`account_type`,`currency_code`),
              KEY `idx_economy_accounts_owner` (`owner_type`,`owner_id`,`status`),
              CONSTRAINT `fk_economy_account_currency`
                FOREIGN KEY (`currency_code`) REFERENCES `economy_currencies` (`currency_code`),
              CONSTRAINT `chk_economy_account_owner`
                CHECK (`owner_type` IN ('character','system')),
              CONSTRAINT `chk_economy_account_type`
                CHECK (`account_type` IN ('wallet','system_source','system_sink')),
              CONSTRAINT `chk_economy_account_status`
                CHECK (`status` IN ('open','closed'))
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `economy_balances` (
              `account_id` CHAR(36) NOT NULL,
              `posted_amount` BIGINT NOT NULL DEFAULT 0,
              `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
              `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
              PRIMARY KEY (`account_id`),
              CONSTRAINT `fk_economy_balance_account`
                FOREIGN KEY (`account_id`) REFERENCES `economy_accounts` (`account_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]
    }
}
