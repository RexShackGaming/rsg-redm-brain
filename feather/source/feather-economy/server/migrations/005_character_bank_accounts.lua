EconomyMigrationDefinitions = EconomyMigrationDefinitions or {}

-- Character bank accounts. A character may hold several bank accounts in one
-- currency (for example one per branch), so account identity gains an
-- `account_ref`: empty for wallets, treasuries and system accounts, and a
-- caller-chosen stable reference for bank accounts. Uniqueness is per
-- (owner, type, currency, ref); existing rows keep ref '' and stay unique.
EconomyMigrationDefinitions[#EconomyMigrationDefinitions + 1] = {
    id = '005_character_bank_accounts',
    statements = {
        [[ALTER TABLE `economy_accounts`
            ADD COLUMN `account_ref` VARCHAR(64) NOT NULL DEFAULT '' AFTER `account_type`,
            DROP INDEX `uq_economy_owner_account`,
            ADD UNIQUE KEY `uq_economy_owner_account`
                (`owner_type`,`owner_id`,`account_type`,`currency_code`,`account_ref`),
            DROP CONSTRAINT `chk_economy_account_type`,
            DROP CONSTRAINT `chk_economy_account_owner_type`,
            ADD CONSTRAINT `chk_economy_account_type`
                CHECK (`account_type` IN ('wallet','bank','system_source','system_sink','treasury')),
            ADD CONSTRAINT `chk_economy_account_owner_type`
                CHECK ((`owner_type`='character' AND `account_type` IN ('wallet','bank'))
                    OR (`owner_type`='system' AND `account_type` IN ('system_source','system_sink'))
                    OR (`owner_type`='organization' AND `account_type`='treasury')),
            ADD CONSTRAINT `chk_economy_account_ref`
                CHECK ((`account_type`='bank' AND `account_ref`<>'')
                    OR (`account_type`<>'bank' AND `account_ref`=''))]]
    }
}
