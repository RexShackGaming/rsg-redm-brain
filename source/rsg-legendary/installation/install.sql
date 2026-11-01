-- Optional: rsg-legendary creates (and upgrades) these tables automatically on start.
CREATE TABLE IF NOT EXISTS `rsg_legendary_cooldowns` (
    `citizenid` VARCHAR(50) NOT NULL,
    `animal` VARCHAR(50) NOT NULL,
    `last_hunt` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `notified` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`citizenid`, `animal`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rsg_legendary_trophies` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `animal` VARCHAR(50) NOT NULL,
    `seconds` INT NOT NULL,
    `quality` VARCHAR(20) NOT NULL DEFAULT 'good',
    `killed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_animal` (`animal`),
    INDEX `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rsg_legendary_hunts` (
    `citizenid` VARCHAR(50) NOT NULL,
    `data` LONGTEXT NOT NULL,
    `expires` INT NOT NULL,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
