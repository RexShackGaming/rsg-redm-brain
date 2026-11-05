EconomyMigrationDefinitions = EconomyMigrationDefinitions or {}

-- Posting order for account history. Timestamps have one-second precision, so
-- entries posted in the same second had no order of their own. The sequence is
-- assigned on insert; balance rows are locked while posting, so one account's
-- entries are numbered in the order they were posted. Existing rows are
-- numbered in entry_id order, which matches posting order within a second.
EconomyMigrationDefinitions[#EconomyMigrationDefinitions + 1] = {
    id = '007_entry_sequence',
    statements = {
        [[ALTER TABLE `economy_entries`
            ADD COLUMN `entry_sequence` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT AFTER `entry_id`,
            ADD UNIQUE KEY `uq_economy_entries_sequence` (`entry_sequence`),
            ADD KEY `idx_economy_entries_account_sequence` (`account_id`,`entry_sequence`)]]
    }
}
