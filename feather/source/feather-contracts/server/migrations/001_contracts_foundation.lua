ContractsMigrationDefinitions = ContractsMigrationDefinitions or {}

ContractsMigrationDefinitions[#ContractsMigrationDefinitions + 1] = {
    id = '001_contracts_foundation',
    statements = {
        [[
            CREATE TABLE IF NOT EXISTS `contract_obligation_types` (
              `type_key` VARCHAR(48) NOT NULL,
              `owner_resource` VARCHAR(64) NOT NULL,
              `definition_json` LONGTEXT NOT NULL,
              `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
              `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
              PRIMARY KEY (`type_key`),
              KEY `idx_contract_types_owner` (`owner_resource`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `contract_obligations` (
              `obligation_id` CHAR(36) NOT NULL,
              `obligation_type` VARCHAR(48) NOT NULL,
              `issuer_resource` VARCHAR(64) NOT NULL,
              `issuer_type` VARCHAR(16) NOT NULL,
              `issuer_id` CHAR(36) NULL,
              `debtor_type` VARCHAR(16) NOT NULL,
              `debtor_id` CHAR(36) NOT NULL,
              `creditor_type` VARCHAR(16) NOT NULL,
              `creditor_id` CHAR(36) NULL,
              `creditor_account_id` CHAR(36) NULL,
              `amount` BIGINT NOT NULL,
              `currency` VARCHAR(32) NOT NULL,
              `status` VARCHAR(16) NOT NULL DEFAULT 'draft',
              `requires_acceptance` TINYINT(1) NOT NULL,
              `debtor_may_settle` TINYINT(1) NOT NULL,
              `issuer_may_settle` TINYINT(1) NOT NULL,
              `debtor_may_dispute` TINYINT(1) NOT NULL,
              `due_in_seconds` INT UNSIGNED NOT NULL,
              `default_after_seconds` INT UNSIGNED NULL,
              `due_at` TIMESTAMP NULL,
              `reference_type` VARCHAR(48) NULL,
              `reference_id` VARCHAR(128) NULL,
              `memo` VARCHAR(255) NULL,
              `settlement_state` VARCHAR(16) NOT NULL DEFAULT 'none',
              `settlement_transaction_id` CHAR(36) NULL,
              `dispute_return_status` VARCHAR(16) NULL,
              `revision` BIGINT UNSIGNED NOT NULL DEFAULT 1,
              `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              `issued_at` TIMESTAMP NULL,
              `accepted_at` TIMESTAMP NULL,
              `settled_at` TIMESTAMP NULL,
              `cancelled_at` TIMESTAMP NULL,
              `disputed_at` TIMESTAMP NULL,
              `defaulted_at` TIMESTAMP NULL,
              `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
              PRIMARY KEY (`obligation_id`),
              KEY `idx_contract_obligations_debtor` (`debtor_type`,`debtor_id`,`status`),
              KEY `idx_contract_obligations_creditor` (`creditor_type`,`creditor_id`,`status`),
              KEY `idx_contract_obligations_type` (`obligation_type`,`status`),
              KEY `idx_contract_obligations_due` (`status`,`due_at`),
              KEY `idx_contract_obligations_reference` (`issuer_resource`,`reference_type`,`reference_id`),
              CONSTRAINT `fk_contract_obligation_type`
                FOREIGN KEY (`obligation_type`) REFERENCES `contract_obligation_types` (`type_key`),
              CONSTRAINT `chk_contract_obligation_amount` CHECK (`amount` > 0),
              CONSTRAINT `chk_contract_obligation_status` CHECK (`status` IN
                ('draft','issued','accepted','due','settled','cancelled','disputed','defaulted')),
              CONSTRAINT `chk_contract_obligation_issuer` CHECK (`issuer_type` IN ('character','organization','system')),
              CONSTRAINT `chk_contract_obligation_debtor` CHECK (`debtor_type` IN ('character')),
              CONSTRAINT `chk_contract_obligation_creditor` CHECK (`creditor_type` IN ('character','organization','system')),
              CONSTRAINT `chk_contract_obligation_settlement` CHECK (`settlement_state` IN ('none','pending')),
              CONSTRAINT `chk_contract_obligation_settled` CHECK
                (`status` <> 'settled' OR `settlement_transaction_id` IS NOT NULL)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `contract_actions` (
              `action_id` CHAR(36) NOT NULL,
              `obligation_id` CHAR(36) NOT NULL,
              `action_type` VARCHAR(32) NOT NULL,
              `from_status` VARCHAR(16) NULL,
              `to_status` VARCHAR(16) NULL,
              `revision` BIGINT UNSIGNED NOT NULL,
              `source_resource` VARCHAR(64) NOT NULL,
              `actor_account_id` CHAR(36) NULL,
              `actor_character_id` CHAR(36) NULL,
              `reason_code` VARCHAR(64) NOT NULL,
              `correlation_id` VARCHAR(128) NULL,
              `request_id` VARCHAR(160) NULL,
              `economy_transaction_id` CHAR(36) NULL,
              `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (`action_id`),
              KEY `idx_contract_actions_obligation` (`obligation_id`,`created_at`),
              CONSTRAINT `fk_contract_action_obligation`
                FOREIGN KEY (`obligation_id`) REFERENCES `contract_obligations` (`obligation_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `contract_receipts` (
              `source_resource` VARCHAR(64) NOT NULL,
              `operation` VARCHAR(32) NOT NULL,
              `request_id` VARCHAR(160) NOT NULL,
              `request_fingerprint` TEXT NOT NULL,
              `result_json` LONGTEXT NULL,
              `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (`source_resource`,`operation`,`request_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `contract_settlements` (
              `settlement_id` CHAR(36) NOT NULL,
              `obligation_id` CHAR(36) NOT NULL,
              `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
              `initiated_by` VARCHAR(16) NOT NULL,
              `channel` VARCHAR(16) NOT NULL DEFAULT 'server',
              `payer_account_id` CHAR(36) NOT NULL,
              `payee_account_id` CHAR(36) NOT NULL,
              `amount` BIGINT NOT NULL,
              `currency` VARCHAR(32) NOT NULL,
              `economy_idempotency_key` VARCHAR(128) NOT NULL,
              `economy_transaction_id` CHAR(36) NULL,
              `source_resource` VARCHAR(64) NOT NULL,
              `actor_account_id` CHAR(36) NULL,
              `actor_character_id` CHAR(36) NULL,
              `correlation_id` VARCHAR(128) NULL,
              `request_id` VARCHAR(160) NULL,
              `attempts` INT UNSIGNED NOT NULL DEFAULT 0,
              `last_error_code` VARCHAR(64) NULL,
              `next_attempt_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
              `completed_at` TIMESTAMP NULL,
              -- 1 while pending/committed, NULL once failed. With the unique key below an
              -- obligation can hold at most one active settlement. (MariaDB refuses a
              -- generated column that returns a CHAR value, so this is a flag.)
              `active_slot` TINYINT UNSIGNED AS
                (CASE WHEN `status` IN ('pending','committed') THEN 1 ELSE NULL END) STORED,
              PRIMARY KEY (`settlement_id`),
              UNIQUE KEY `uq_contract_settlement_economy_key` (`economy_idempotency_key`),
              UNIQUE KEY `uq_contract_settlement_active` (`obligation_id`,`active_slot`),
              KEY `idx_contract_settlements_obligation` (`obligation_id`),
              KEY `idx_contract_settlements_retry` (`status`,`next_attempt_at`),
              CONSTRAINT `fk_contract_settlement_obligation`
                FOREIGN KEY (`obligation_id`) REFERENCES `contract_obligations` (`obligation_id`),
              CONSTRAINT `chk_contract_settlement_status` CHECK (`status` IN ('pending','committed','failed')),
              CONSTRAINT `chk_contract_settlement_initiator` CHECK (`initiated_by` IN ('debtor','issuer')),
              CONSTRAINT `chk_contract_settlement_channel` CHECK (`channel` IN ('server','client')),
              CONSTRAINT `chk_contract_settlement_amount` CHECK (`amount` > 0),
              CONSTRAINT `chk_contract_settlement_committed` CHECK
                (`status` <> 'committed' OR `economy_transaction_id` IS NOT NULL)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `contract_outbox` (
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
              KEY `idx_contract_outbox_delivery` (`status`,`available_at`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]
    }
}
