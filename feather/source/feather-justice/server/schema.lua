-- Justice schema (master plan: Domain design, Persistence and privacy).
-- Plan tables and columns; extensions are commented. Times are UTC epoch
-- milliseconds in BIGINT columns (no session time-zone conversion).
-- Migrations are ordered, checksummed and ledgered after completion. MariaDB DDL
-- commits implicitly: every statement is rerunnable and never wrapped in a transaction.
local engine = ' ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
local migrations = {
    { id = '001_definitions', ddl = {
        [[CREATE TABLE IF NOT EXISTS justice_jurisdictions (
            jurisdiction_id CHAR(36) NOT NULL PRIMARY KEY,
            jurisdiction_key VARCHAR(128) NOT NULL,
            label VARCHAR(100) NOT NULL,
            jurisdiction_type VARCHAR(32) NOT NULL,
            status VARCHAR(16) NOT NULL,
            parent_jurisdiction_id CHAR(36) NULL,
            owner_resource VARCHAR(64) NOT NULL,
            revision BIGINT UNSIGNED NOT NULL,
            created_at BIGINT UNSIGNED NOT NULL,
            retired_at BIGINT UNSIGNED NULL,
            UNIQUE KEY uq_justice_jurisdiction_key (jurisdiction_key),
            KEY idx_justice_jurisdiction_owner (owner_resource, jurisdiction_id),
            CONSTRAINT fk_justice_jurisdiction_parent FOREIGN KEY (parent_jurisdiction_id)
                REFERENCES justice_jurisdictions (jurisdiction_id)
        )]] .. engine,
        -- Extensions: description, metadata_json (recommended fine/custody ranges), created_at.
        [[CREATE TABLE IF NOT EXISTS justice_statutes (
            statute_id CHAR(36) NOT NULL PRIMARY KEY,
            jurisdiction_id CHAR(36) NOT NULL,
            statute_key VARCHAR(160) NOT NULL,
            title VARCHAR(180) NOT NULL,
            description TEXT NULL,
            category VARCHAR(32) NOT NULL,
            severity_class VARCHAR(16) NOT NULL,
            status VARCHAR(16) NOT NULL,
            definition_version INT UNSIGNED NOT NULL,
            effective_from BIGINT UNSIGNED NULL,
            effective_until BIGINT UNSIGNED NULL,
            metadata_json TEXT NULL,
            owner_resource VARCHAR(64) NOT NULL,
            revision BIGINT UNSIGNED NOT NULL,
            created_at BIGINT UNSIGNED NOT NULL,
            UNIQUE KEY uq_justice_statute_key (statute_key),
            KEY idx_justice_statute_jurisdiction (jurisdiction_id, statute_id),
            CONSTRAINT fk_justice_statute_jurisdiction FOREIGN KEY (jurisdiction_id)
                REFERENCES justice_jurisdictions (jurisdiction_id)
        )]] .. engine } },
    { id = '002_cases', ddl = {
        -- Extensions: sealed_from_status (restored on unseal), expunged_at.
        [[CREATE TABLE IF NOT EXISTS justice_cases (
            case_id CHAR(36) NOT NULL PRIMARY KEY,
            jurisdiction_id CHAR(36) NOT NULL,
            case_type VARCHAR(32) NOT NULL,
            status VARCHAR(24) NOT NULL,
            title VARCHAR(180) NOT NULL,
            summary TEXT NOT NULL,
            opened_by_character_id CHAR(36) NOT NULL,
            opened_by_resource VARCHAR(64) NOT NULL,
            opened_at BIGINT UNSIGNED NOT NULL,
            closed_at BIGINT UNSIGNED NULL,
            sealed_at BIGINT UNSIGNED NULL,
            sealed_from_status VARCHAR(24) NULL,
            expunged_at BIGINT UNSIGNED NULL,
            revision BIGINT UNSIGNED NOT NULL,
            KEY idx_justice_case_scope (opened_by_resource, jurisdiction_id, case_id),
            KEY idx_justice_case_opener (opened_by_character_id),
            CONSTRAINT fk_justice_case_jurisdiction FOREIGN KEY (jurisdiction_id)
                REFERENCES justice_jurisdictions (jurisdiction_id)
        )]] .. engine,
        -- Extensions: added/removed actor; active_key enforces one active slot per role.
        [[CREATE TABLE IF NOT EXISTS justice_case_parties (
            party_id CHAR(36) NOT NULL PRIMARY KEY,
            case_id CHAR(36) NOT NULL,
            party_type VARCHAR(16) NOT NULL,
            party_id_reference CHAR(36) NOT NULL,
            party_role VARCHAR(32) NOT NULL,
            status VARCHAR(16) NOT NULL,
            added_at BIGINT UNSIGNED NOT NULL,
            removed_at BIGINT UNSIGNED NULL,
            added_by_character_id CHAR(36) NOT NULL,
            removed_by_character_id CHAR(36) NULL,
            revision BIGINT UNSIGNED NOT NULL,
            active_key VARCHAR(160) AS (IF(status = 'active',
                CONCAT(RTRIM(case_id), ':', party_type, ':', RTRIM(party_id_reference), ':', party_role), NULL)) STORED,
            UNIQUE KEY uq_justice_party_active (active_key),
            KEY idx_justice_party_case (case_id, party_type, party_id_reference, status),
            KEY idx_justice_party_reference (party_type, party_id_reference, status),
            CONSTRAINT fk_justice_party_case FOREIGN KEY (case_id) REFERENCES justice_cases (case_id)
        )]] .. engine } },
    { id = '003_charges_warrants', ddl = {
        -- Extensions: proposer, disposer, amendment links, convicting/acquitting ruling.
        [[CREATE TABLE IF NOT EXISTS justice_charges (
            charge_id CHAR(36) NOT NULL PRIMARY KEY,
            case_id CHAR(36) NOT NULL,
            defendant_character_id CHAR(36) NOT NULL,
            statute_id CHAR(36) NOT NULL,
            statute_snapshot_json TEXT NOT NULL,
            count INT UNSIGNED NOT NULL,
            status VARCHAR(16) NOT NULL,
            proposed_by_character_id CHAR(36) NOT NULL,
            proposed_at BIGINT UNSIGNED NOT NULL,
            filed_by_character_id CHAR(36) NULL,
            filed_at BIGINT UNSIGNED NULL,
            disposition VARCHAR(16) NULL,
            disposed_by_character_id CHAR(36) NULL,
            disposed_at BIGINT UNSIGNED NULL,
            amends_charge_id CHAR(36) NULL,
            amended_by_charge_id CHAR(36) NULL,
            ruling_id CHAR(36) NULL,
            revision BIGINT UNSIGNED NOT NULL,
            KEY idx_justice_charge_case (case_id, charge_id),
            KEY idx_justice_charge_defendant (defendant_character_id, charge_id),
            CONSTRAINT fk_justice_charge_case FOREIGN KEY (case_id) REFERENCES justice_cases (case_id),
            CONSTRAINT fk_justice_charge_statute FOREIGN KEY (statute_id) REFERENCES justice_statutes (statute_id)
        )]] .. engine,
        -- Extensions: creator, lifetime, quash time and the closing actor.
        [[CREATE TABLE IF NOT EXISTS justice_warrants (
            warrant_id CHAR(36) NOT NULL PRIMARY KEY,
            jurisdiction_id CHAR(36) NOT NULL,
            case_id CHAR(36) NOT NULL,
            subject_character_id CHAR(36) NOT NULL,
            warrant_type VARCHAR(16) NOT NULL,
            status VARCHAR(16) NOT NULL,
            basis_summary TEXT NOT NULL,
            valid_for_seconds INT UNSIGNED NOT NULL,
            created_by_character_id CHAR(36) NOT NULL,
            created_at BIGINT UNSIGNED NOT NULL,
            issued_by_character_id CHAR(36) NULL,
            issued_at BIGINT UNSIGNED NULL,
            expires_at BIGINT UNSIGNED NULL,
            served_at BIGINT UNSIGNED NULL,
            recalled_at BIGINT UNSIGNED NULL,
            quashed_at BIGINT UNSIGNED NULL,
            closed_by_character_id CHAR(36) NULL,
            revision BIGINT UNSIGNED NOT NULL,
            KEY idx_justice_warrant_case (case_id, warrant_id),
            KEY idx_justice_warrant_active (jurisdiction_id, status, warrant_id),
            KEY idx_justice_warrant_subject (subject_character_id, status, expires_at),
            KEY idx_justice_warrant_expiry (status, expires_at),
            CONSTRAINT fk_justice_warrant_case FOREIGN KEY (case_id) REFERENCES justice_cases (case_id)
        )]] .. engine } },
    { id = '004_citations_custody', ddl = {
        -- Extensions: frozen financial terms and basis; a warning citation has no amount.
        [[CREATE TABLE IF NOT EXISTS justice_citations (
            citation_id CHAR(36) NOT NULL PRIMARY KEY,
            jurisdiction_id CHAR(36) NOT NULL,
            case_id CHAR(36) NOT NULL,
            subject_character_id CHAR(36) NOT NULL,
            statute_id CHAR(36) NOT NULL,
            status VARCHAR(16) NOT NULL,
            issued_by_character_id CHAR(36) NOT NULL,
            issued_at BIGINT UNSIGNED NOT NULL,
            due_at BIGINT UNSIGNED NULL,
            contracts_obligation_id CHAR(36) NULL,
            amount BIGINT UNSIGNED NULL,
            currency VARCHAR(32) NULL,
            type_key VARCHAR(48) NULL,
            due_in_seconds INT UNSIGNED NULL,
            basis_summary TEXT NOT NULL,
            revision BIGINT UNSIGNED NOT NULL,
            KEY idx_justice_citation_case (case_id, citation_id),
            KEY idx_justice_citation_subject (subject_character_id, citation_id),
            CONSTRAINT fk_justice_citation_case FOREIGN KEY (case_id) REFERENCES justice_cases (case_id),
            CONSTRAINT fk_justice_citation_statute FOREIGN KEY (statute_id) REFERENCES justice_statutes (statute_id)
        )]] .. engine,
        -- Extensions: authority revision, facility, booking/release actors;
        -- active_subject enforces one unreleased custody record per character.
        [[CREATE TABLE IF NOT EXISTS justice_custody_records (
            custody_id CHAR(36) NOT NULL PRIMARY KEY,
            jurisdiction_id CHAR(36) NOT NULL,
            case_id CHAR(36) NOT NULL,
            subject_character_id CHAR(36) NOT NULL,
            authority_type VARCHAR(16) NOT NULL,
            authority_id VARCHAR(64) NOT NULL,
            authority_revision BIGINT UNSIGNED NULL,
            status VARCHAR(16) NOT NULL,
            arresting_character_id CHAR(36) NOT NULL,
            started_at BIGINT UNSIGNED NOT NULL,
            booked_at BIGINT UNSIGNED NULL,
            booked_by_character_id CHAR(36) NULL,
            facility_key VARCHAR(64) NULL,
            released_at BIGINT UNSIGNED NULL,
            released_by_character_id CHAR(36) NULL,
            release_reason VARCHAR(64) NULL,
            revision BIGINT UNSIGNED NOT NULL,
            active_subject VARCHAR(36) AS (IF(status <> 'released', RTRIM(subject_character_id), NULL)) STORED,
            UNIQUE KEY uq_justice_custody_active (active_subject),
            KEY idx_justice_custody_case (case_id, custody_id),
            KEY idx_justice_custody_subject (subject_character_id, custody_id),
            CONSTRAINT fk_justice_custody_case FOREIGN KEY (case_id) REFERENCES justice_cases (case_id)
        )]] .. engine } },
    { id = '005_rulings_sentences', ddl = {
        -- Extensions: subject (per-defendant verdicts) and findings_json.
        [[CREATE TABLE IF NOT EXISTS justice_rulings (
            ruling_id CHAR(36) NOT NULL PRIMARY KEY,
            case_id CHAR(36) NOT NULL,
            ruling_type VARCHAR(16) NOT NULL,
            outcome VARCHAR(64) NOT NULL,
            issued_by_character_id CHAR(36) NOT NULL,
            issued_at BIGINT UNSIGNED NOT NULL,
            summary TEXT NOT NULL,
            subject_character_id CHAR(36) NULL,
            findings_json TEXT NULL,
            revision BIGINT UNSIGNED NOT NULL,
            KEY idx_justice_ruling_case (case_id, ruling_id),
            CONSTRAINT fk_justice_ruling_case FOREIGN KEY (case_id) REFERENCES justice_cases (case_id)
        )]] .. engine,
        -- Extensions: ruling, jurisdiction, lifecycle actors/times, completion outcome,
        -- executing-domain reference, frozen financial terms; active_custodial enforces
        -- one active or suspended custodial sentence per character.
        [[CREATE TABLE IF NOT EXISTS justice_sentences (
            sentence_id CHAR(36) NOT NULL PRIMARY KEY,
            case_id CHAR(36) NOT NULL,
            defendant_character_id CHAR(36) NOT NULL,
            sentence_type VARCHAR(24) NOT NULL,
            status VARCHAR(16) NOT NULL,
            terms_json TEXT NOT NULL,
            starts_at BIGINT UNSIGNED NULL,
            ends_at BIGINT UNSIGNED NULL,
            contracts_obligation_id CHAR(36) NULL,
            ruling_id CHAR(36) NOT NULL,
            jurisdiction_id CHAR(36) NOT NULL,
            created_by_character_id CHAR(36) NOT NULL,
            created_at BIGINT UNSIGNED NOT NULL,
            activated_by_character_id CHAR(36) NULL,
            activated_at BIGINT UNSIGNED NULL,
            remaining_ms BIGINT UNSIGNED NULL,
            completed_by_character_id CHAR(36) NULL,
            completed_at BIGINT UNSIGNED NULL,
            outcome VARCHAR(16) NULL,
            effect_reference VARCHAR(128) NULL,
            financial_outcome VARCHAR(16) NULL,
            currency VARCHAR(32) NULL,
            type_key VARCHAR(48) NULL,
            revision BIGINT UNSIGNED NOT NULL,
            active_custodial VARCHAR(36) AS (IF(sentence_type = 'custodial' AND status IN ('active', 'suspended'),
                RTRIM(defendant_character_id), NULL)) STORED,
            UNIQUE KEY uq_justice_sentence_custodial (active_custodial),
            KEY idx_justice_sentence_case (case_id, sentence_id),
            KEY idx_justice_sentence_active (jurisdiction_id, status, sentence_id),
            KEY idx_justice_sentence_defendant (defendant_character_id, status),
            KEY idx_justice_sentence_term (status, ends_at),
            CONSTRAINT fk_justice_sentence_case FOREIGN KEY (case_id) REFERENCES justice_cases (case_id),
            CONSTRAINT fk_justice_sentence_ruling FOREIGN KEY (ruling_id) REFERENCES justice_rulings (ruling_id)
        )]] .. engine } },
    { id = '006_evidence', ddl = {
        -- Extensions: status (active/removed/missing), disposition, subject, description,
        -- Inventory item name; active_key enforces one active link per case and reference.
        [[CREATE TABLE IF NOT EXISTS justice_evidence_links (
            evidence_link_id CHAR(36) NOT NULL PRIMARY KEY,
            case_id CHAR(36) NOT NULL,
            evidence_type VARCHAR(24) NOT NULL,
            evidence_id VARCHAR(64) NOT NULL,
            relationship VARCHAR(16) NOT NULL,
            linked_by_character_id CHAR(36) NOT NULL,
            linked_at BIGINT UNSIGNED NOT NULL,
            removed_at BIGINT UNSIGNED NULL,
            removed_by_character_id CHAR(36) NULL,
            status VARCHAR(16) NOT NULL,
            disposition VARCHAR(16) NULL,
            subject_character_id CHAR(36) NULL,
            description TEXT NULL,
            item_name VARCHAR(64) NULL,
            revision BIGINT UNSIGNED NOT NULL,
            active_key VARCHAR(160) AS (IF(status = 'active', CONCAT(RTRIM(case_id), ':', evidence_type, ':', evidence_id), NULL)) STORED,
            UNIQUE KEY uq_justice_evidence_active (active_key),
            KEY idx_justice_evidence_case (case_id, evidence_link_id),
            KEY idx_justice_evidence_reference (evidence_type, evidence_id, status),
            CONSTRAINT fk_justice_evidence_case FOREIGN KEY (case_id) REFERENCES justice_cases (case_id)
        )]] .. engine } },
    { id = '007_operations', ddl = {
        [[CREATE TABLE IF NOT EXISTS justice_receipts (
            source_resource VARCHAR(64) NOT NULL,
            request_id VARCHAR(128) NOT NULL,
            fingerprint CHAR(64) NOT NULL,
            actor_character_id CHAR(36) NULL,
            record_kind VARCHAR(24) NULL,
            record_id CHAR(36) NULL,
            result_json MEDIUMTEXT NULL,
            PRIMARY KEY (source_resource, request_id),
            KEY idx_justice_receipt_record (record_id)
        )]] .. engine,
        [[CREATE TABLE IF NOT EXISTS justice_audit_events (
            event_id CHAR(36) NOT NULL PRIMARY KEY,
            record_kind VARCHAR(24) NOT NULL,
            record_id CHAR(36) NOT NULL,
            fact VARCHAR(80) NOT NULL,
            source_resource VARCHAR(64) NOT NULL,
            actor_character_id CHAR(36) NULL,
            reason_code VARCHAR(64) NOT NULL,
            correlation_id VARCHAR(128) NULL,
            revision BIGINT UNSIGNED NOT NULL,
            created_at BIGINT UNSIGNED NOT NULL,
            KEY idx_justice_audit_record (record_id, revision)
        )]] .. engine,
        [[CREATE TABLE IF NOT EXISTS justice_outbox (
            event_id CHAR(36) NOT NULL PRIMARY KEY,
            record_id CHAR(36) NOT NULL,
            fact VARCHAR(80) NOT NULL,
            revision BIGINT UNSIGNED NOT NULL,
            payload_json TEXT NOT NULL,
            delivered TINYINT NOT NULL DEFAULT 0,
            created_at BIGINT UNSIGNED NOT NULL,
            KEY idx_justice_outbox_pending (delivered, created_at, event_id),
            KEY idx_justice_outbox_order (record_id, delivered, revision)
        )]] .. engine,
        -- Master plan, Query rules: search by character UUID is privileged and audited.
        [[CREATE TABLE IF NOT EXISTS justice_access_audit (
            access_id CHAR(36) NOT NULL PRIMARY KEY,
            source_resource VARCHAR(64) NOT NULL,
            actor_character_id CHAR(36) NULL,
            action VARCHAR(64) NOT NULL,
            subject_character_id CHAR(36) NOT NULL,
            created_at BIGINT UNSIGNED NOT NULL,
            KEY idx_justice_access_subject (subject_character_id, created_at)
        )]] .. engine,
        -- Durable cross-domain workflow state (Contracts issue/cancel/settlement watch).
        [[CREATE TABLE IF NOT EXISTS justice_workflows (
            record_id CHAR(36) NOT NULL PRIMARY KEY,
            record_kind VARCHAR(24) NOT NULL,
            next_attempt_at BIGINT UNSIGNED NOT NULL,
            attempts BIGINT UNSIGNED NOT NULL DEFAULT 0,
            last_code VARCHAR(64) NULL,
            KEY idx_justice_workflow_due (next_attempt_at, record_id)
        )]] .. engine } }
}

-- Tables of the pre-0.3.0 development layout, dropped once only if they hold no records.
local retired = { 'feather_justice_participants', 'feather_justice_case_links', 'feather_justice_citation_workflows',
    'feather_justice_active_custody', 'feather_justice_case_visibility', 'feather_justice_evidence_index',
    'feather_justice_financial_workflows', 'feather_justice_active_custodial', 'feather_justice_receipts',
    'feather_justice_events', 'feather_justice_outbox', 'feather_justice_records', 'feather_justice_schema_migrations' }
local function RetireDevelopmentSchema()
    local present = DB.value([[SELECT COUNT(*) FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'feather_justice_records']])
    if tonumber(present) == 0 then return end
    if tonumber(DB.value('SELECT COUNT(*) FROM feather_justice_records')) ~= 0 then
        error('development_schema_has_records: export or remove feather_justice_records before upgrading to 0.3.0')
    end
    for _, name in ipairs(retired) do DB.exec('DROP TABLE IF EXISTS ' .. name) end
end

local inspecting
local function Apply(migration, ledger)
    local checksum = Justice.Sha256(table.concat(migration.ddl, '\n'))
    if inspecting then
        inspecting[#inspecting + 1] = { id = migration.id, checksum = checksum }
        return
    end
    local existing = ledger[migration.id]
    if existing then
        if existing ~= checksum then error('migration_checksum_mismatch:' .. migration.id) end
        return
    end
    for _, statement in ipairs(migration.ddl) do DB.exec(statement) end
    DB.exec('INSERT INTO justice_schema_migrations (migration_id, checksum) VALUES (?, ?)', migration.id, checksum)
end
function Justice.Migrate()
    RetireDevelopmentSchema()
    DB.exec([[CREATE TABLE IF NOT EXISTS justice_schema_migrations (
        migration_id VARCHAR(64) NOT NULL PRIMARY KEY,
        checksum CHAR(64) NOT NULL,
        applied_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    )]] .. engine)
    local ledger = {}
    for _, row in ipairs(DB.query('SELECT migration_id, checksum FROM justice_schema_migrations')) do
        ledger[row.migration_id] = row.checksum
    end
    for _, migration in ipairs(migrations) do Apply(migration, ledger) end
end
-- Read-only: what the ledger must contain for this version (JusticeMigrationSmokeTest).
function Justice.ExpectedMigrations()
    inspecting = {}
    for _, migration in ipairs(migrations) do Apply(migration, {}) end
    local result = inspecting
    inspecting = nil
    return result
end
function Justice.MigrationLedger()
    local ok, rows = pcall(DB.query, 'SELECT migration_id, checksum FROM justice_schema_migrations')
    if not ok then return nil end
    local ledger = {}
    for _, row in ipairs(rows) do ledger[row.migration_id] = row.checksum end
    return ledger
end
function Justice.SchemaTables()
    local ok, rows = pcall(DB.query, [[SELECT TABLE_NAME FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE 'justice\_%']])
    local present = {}
    if ok then for _, row in ipairs(rows) do present[row.TABLE_NAME] = true end end
    return present
end
Justice.Tables = { 'justice_jurisdictions', 'justice_statutes', 'justice_cases', 'justice_case_parties',
    'justice_charges', 'justice_warrants', 'justice_citations', 'justice_custody_records', 'justice_rulings',
    'justice_sentences', 'justice_evidence_links', 'justice_receipts', 'justice_audit_events', 'justice_outbox',
    'justice_access_audit', 'justice_workflows', 'justice_schema_migrations' }
