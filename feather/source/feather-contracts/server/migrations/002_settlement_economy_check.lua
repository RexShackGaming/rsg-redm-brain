ContractsMigrationDefinitions = ContractsMigrationDefinitions or {}

-- Result of checking a committed settlement against Economy's journal
-- (GetTransaction): 'verified', 'mismatch' or 'missing'. NULL until checked.
ContractsMigrationDefinitions[#ContractsMigrationDefinitions + 1] = {
    id = '002_settlement_economy_check',
    statements = {
        [[
            ALTER TABLE `contract_settlements`
              ADD COLUMN IF NOT EXISTS `economy_check` VARCHAR(16) NULL,
              ADD COLUMN IF NOT EXISTS `economy_checked_at` TIMESTAMP NULL,
              ADD KEY IF NOT EXISTS `idx_contract_settlements_economy_check` (`status`,`economy_check`)
        ]]
    }
}
