ContractsMigrationDefinitions = ContractsMigrationDefinitions or {}

-- An organization may be the debtor (it pays from its treasury).
ContractsMigrationDefinitions[#ContractsMigrationDefinitions + 1] = {
    id = '003_organization_debtors',
    statements = {
        [[
            ALTER TABLE `contract_obligations`
              DROP CONSTRAINT IF EXISTS `chk_contract_obligation_debtor`,
              ADD CONSTRAINT `chk_contract_obligation_debtor` CHECK (`debtor_type` IN ('character','organization'))
        ]]
    }
}
