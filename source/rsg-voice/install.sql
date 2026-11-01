CREATE TABLE IF NOT EXISTS `rsg_voice_mutes` (
    `license`    VARCHAR(64)  NOT NULL,
    `reason`     VARCHAR(255) DEFAULT NULL,
    `muted_by`   VARCHAR(100) DEFAULT NULL,
    `expires_at` INT UNSIGNED DEFAULT NULL, -- unix time, NULL = permanent
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`license`)
);
