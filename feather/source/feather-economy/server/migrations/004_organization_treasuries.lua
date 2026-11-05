EconomyMigrationDefinitions = EconomyMigrationDefinitions or {}

EconomyMigrationDefinitions[#EconomyMigrationDefinitions + 1] = {
    id = '004_organization_treasuries',
    statements = {
        [[ALTER TABLE `economy_accounts`
            DROP CONSTRAINT `chk_economy_account_owner`,
            DROP CONSTRAINT `chk_economy_account_type`,
            ADD CONSTRAINT `chk_economy_account_owner`
                CHECK (`owner_type` IN ('character','system','organization')),
            ADD CONSTRAINT `chk_economy_account_type`
                CHECK (`account_type` IN ('wallet','system_source','system_sink','treasury')),
            ADD CONSTRAINT `chk_economy_account_owner_type`
                CHECK ((`owner_type`='character' AND `account_type`='wallet')
                    OR (`owner_type`='system' AND `account_type` IN ('system_source','system_sink'))
                    OR (`owner_type`='organization' AND `account_type`='treasury'))]]
    }
}
