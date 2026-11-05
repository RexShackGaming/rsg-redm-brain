EconomyMigrationDefinitions = EconomyMigrationDefinitions or {}

-- Operated treasuries. An organization treasury is bound, once and permanently,
-- to the one resource that may move it (EnsureOperatedTreasury). Other
-- treasuries (shops, governments) can never be moved through operated reasons.
EconomyMigrationDefinitions[#EconomyMigrationDefinitions + 1] = {
    id = '006_treasury_operators',
    statements = {
        [[CREATE TABLE IF NOT EXISTS `economy_treasury_operators` (
            `organization_id` CHAR(36) NOT NULL,
            `operator_resource` VARCHAR(100) NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`organization_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]
    }
}
