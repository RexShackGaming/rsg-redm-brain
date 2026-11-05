FeatherAuditMigrations = {}

local migrations = {
    {
        id = '001_audit_foundation',
        checksum = 'audit-foundation-v1-20260902',
        up = function()
            DB.exec([[CREATE TABLE IF NOT EXISTS feather_audit_events (
                audit_event_id CHAR(36) NOT NULL,
                source_resource VARCHAR(128) NOT NULL,
                source_instance VARCHAR(128) NOT NULL,
                producer_event_id VARCHAR(128) NOT NULL,
                event_type VARCHAR(128) NOT NULL,
                event_version INT UNSIGNED NOT NULL,
                contract_version INT UNSIGNED NOT NULL,
                occurred_at DATETIME(3) NOT NULL,
                ingested_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
                invoking_resource VARCHAR(128) NULL,
                correlation_id VARCHAR(128) NULL,
                causation_id VARCHAR(128) NULL,
                actor_type VARCHAR(128) NOT NULL,
                actor_id VARCHAR(128) NOT NULL,
                actor_account_id VARCHAR(128) NULL,
                actor_character_id VARCHAR(128) NULL,
                actor_resource VARCHAR(128) NULL,
                actor_display_name VARCHAR(128) NULL,
                result VARCHAR(32) NOT NULL,
                reason_code VARCHAR(128) NOT NULL,
                summary VARCHAR(256) NOT NULL,
                context_json LONGTEXT NOT NULL,
                canonical_payload MEDIUMTEXT NOT NULL,
                sensitivity_class VARCHAR(32) NOT NULL,
                retention_class VARCHAR(32) NOT NULL,
                integrity_hash CHAR(64) NOT NULL,
                redaction_state VARCHAR(32) NOT NULL DEFAULT 'active',
                PRIMARY KEY (audit_event_id),
                UNIQUE KEY uq_fae_producer_event (source_resource, source_instance, producer_event_id),
                KEY idx_fae_occurred (occurred_at, audit_event_id),
                KEY idx_fae_ingested (ingested_at, audit_event_id),
                KEY idx_fae_type_time (event_type, occurred_at),
                KEY idx_fae_actor_time (actor_type, actor_id, occurred_at),
                KEY idx_fae_correlation (correlation_id, occurred_at),
                KEY idx_fae_source_time (source_resource, occurred_at),
                KEY idx_fae_class_time (sensitivity_class, retention_class, occurred_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])

            DB.exec([[CREATE TABLE IF NOT EXISTS feather_audit_targets (
                audit_event_id CHAR(36) NOT NULL,
                ordinal SMALLINT UNSIGNED NOT NULL,
                target_type VARCHAR(128) NOT NULL,
                target_id VARCHAR(128) NOT NULL,
                target_role VARCHAR(128) NOT NULL,
                target_resource VARCHAR(128) NULL,
                target_display_name VARCHAR(128) NULL,
                PRIMARY KEY (audit_event_id, ordinal),
                KEY idx_fat_target_time (target_type, target_id, audit_event_id),
                CONSTRAINT fk_fat_event FOREIGN KEY (audit_event_id)
                    REFERENCES feather_audit_events (audit_event_id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])

            DB.exec([[CREATE TABLE IF NOT EXISTS feather_audit_references (
                audit_event_id CHAR(36) NOT NULL,
                ordinal SMALLINT UNSIGNED NOT NULL,
                reference_resource VARCHAR(128) NOT NULL,
                reference_type VARCHAR(128) NOT NULL,
                reference_id VARCHAR(128) NOT NULL,
                PRIMARY KEY (audit_event_id, ordinal),
                KEY idx_far_reference (reference_resource, reference_type, reference_id, audit_event_id),
                CONSTRAINT fk_far_event FOREIGN KEY (audit_event_id)
                    REFERENCES feather_audit_events (audit_event_id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])

            DB.exec([[CREATE TABLE IF NOT EXISTS feather_audit_quarantine (
                quarantine_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                fingerprint CHAR(64) NOT NULL,
                source_resource VARCHAR(128) NOT NULL,
                source_instance VARCHAR(128) NULL,
                producer_event_id VARCHAR(128) NULL,
                event_type VARCHAR(128) NULL,
                rejection_code VARCHAR(128) NOT NULL,
                rejection_path VARCHAR(256) NULL,
                first_seen_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
                last_seen_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
                occurrence_count BIGINT UNSIGNED NOT NULL DEFAULT 1,
                state VARCHAR(32) NOT NULL DEFAULT 'open',
                PRIMARY KEY (quarantine_id),
                UNIQUE KEY uq_faq_fingerprint (fingerprint),
                KEY idx_faq_state_time (state, last_seen_at),
                KEY idx_faq_source_time (source_resource, last_seen_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])

            DB.exec([[CREATE TABLE IF NOT EXISTS feather_audit_access_events (
                access_event_id CHAR(36) NOT NULL,
                requester_type VARCHAR(128) NOT NULL,
                requester_id VARCHAR(128) NOT NULL,
                operation VARCHAR(128) NOT NULL,
                query_fingerprint CHAR(64) NULL,
                sensitivity_reached VARCHAR(32) NOT NULL,
                reason_code VARCHAR(128) NOT NULL,
                result VARCHAR(32) NOT NULL,
                occurred_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
                PRIMARY KEY (access_event_id),
                KEY idx_faae_requester_time (requester_type, requester_id, occurred_at),
                KEY idx_faae_operation_time (operation, occurred_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
        end
    }
}

function FeatherAuditMigrations.Run()
    DB.exec([[CREATE TABLE IF NOT EXISTS feather_audit_schema_migrations (
        id VARCHAR(100) NOT NULL,
        checksum VARCHAR(64) NOT NULL,
        applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])

    local applied = {}
    for _, row in ipairs(DB.query(
        'SELECT id, checksum FROM feather_audit_schema_migrations') or {}) do
        applied[row.id] = row.checksum
    end

    for _, migration in ipairs(migrations) do
        if applied[migration.id] and applied[migration.id] ~= migration.checksum then
            return false, ('migration_checksum_mismatch:%s'):format(migration.id)
        end
        if not applied[migration.id] then
            local ok, problem = pcall(function()
                migration.up()
                DB.insert(
                    'INSERT INTO feather_audit_schema_migrations (id, checksum) VALUES (?, ?)',
                    migration.id, migration.checksum)
            end)
            if not ok then return false, ('migration_failed:%s:%s'):format(migration.id, tostring(problem)) end
        end
    end

    return true, #migrations
end
