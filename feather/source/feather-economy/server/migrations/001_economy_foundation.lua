EconomyMigrationDefinitions = EconomyMigrationDefinitions or {}

EconomyMigrationDefinitions[#EconomyMigrationDefinitions + 1] = {
    id = '001_economy_foundation',
    statements = {
        [[
            CREATE TABLE IF NOT EXISTS `economy_currencies` (
              `currency_code` VARCHAR(32) NOT NULL,
              `label` VARCHAR(64) NOT NULL,
              `precision` TINYINT UNSIGNED NOT NULL,
              `enabled` TINYINT(1) NOT NULL DEFAULT 1,
              `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
              `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
              PRIMARY KEY (`currency_code`),
              CONSTRAINT `chk_economy_currency_precision` CHECK (`precision` <= 6)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]
    }
}
