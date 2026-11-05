-- Versioned schema installed by server startup through feather-mysql.
-- UTC seconds avoid session/monotonic clock reset on reconnect or restart.
MedicalSchema = {
    version = 1,
    statements = {
        [[CREATE TABLE IF NOT EXISTS fm_condition (
            character_id VARCHAR(64) NOT NULL PRIMARY KEY,
            life_state ENUM('alive','incapacitated','dead') NOT NULL,
            active_episode_id CHAR(36) NULL,
            opened_at BIGINT UNSIGNED NULL,
            bleed_out_at BIGINT UNSIGNED NULL,
            doctor_available_at BIGINT UNSIGNED NULL,
            revision BIGINT UNSIGNED NOT NULL DEFAULT 0,
            updated_at BIGINT UNSIGNED NOT NULL,
            INDEX fm_bleed_out (life_state, bleed_out_at)
        ) ENGINE=InnoDB]],
        [[CREATE TABLE IF NOT EXISTS fm_episodes (
            episode_id CHAR(36) NOT NULL PRIMARY KEY,
            character_id VARCHAR(64) NOT NULL,
            state ENUM('incapacitated','dead','closed') NOT NULL,
            provenance ENUM('client_observation','server_action') NOT NULL,
            opened_at BIGINT UNSIGNED NOT NULL,
            closed_at BIGINT UNSIGNED NULL,
            revision BIGINT UNSIGNED NOT NULL DEFAULT 0,
            INDEX fm_character_episodes (character_id, opened_at)
        ) ENGINE=InnoDB]],
        [[CREATE TABLE IF NOT EXISTS fm_recovery_operations (
            operation_id CHAR(36) NOT NULL PRIMARY KEY,
            episode_id CHAR(36) NOT NULL,
            character_id VARCHAR(64) NOT NULL,
            recovery_kind ENUM('staff','doctor') NOT NULL,
            status ENUM('pending','completed','cancelled') NOT NULL,
            destination_snapshot LONGTEXT NULL,
            requested_by VARCHAR(64) NOT NULL,
            created_at BIGINT UNSIGNED NOT NULL,
            completed_at BIGINT UNSIGNED NULL,
            revision BIGINT UNSIGNED NOT NULL DEFAULT 0,
            UNIQUE KEY fm_episode_recovery (episode_id)
        ) ENGINE=InnoDB]],
        [[CREATE TABLE IF NOT EXISTS fm_transition_outbox (
            event_id CHAR(36) NOT NULL PRIMARY KEY,
            character_id VARCHAR(64) NOT NULL,
            episode_id CHAR(36) NULL,
            revision BIGINT UNSIGNED NOT NULL,
            payload LONGTEXT NOT NULL,
            created_at BIGINT UNSIGNED NOT NULL,
            published_at BIGINT UNSIGNED NULL,
            UNIQUE KEY fm_transition_revision (character_id, revision),
            INDEX fm_pending_events (published_at, created_at)
        ) ENGINE=InnoDB]]
    }
}
return MedicalSchema
