CREATE TABLE IF NOT EXISTS `rsg_deliveries_stats` (
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NOT NULL DEFAULT '',
    `completed` INT UNSIGNED NOT NULL DEFAULT 0,
    `distance` DOUBLE NOT NULL DEFAULT 0,
    `earned` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `streak` INT UNSIGNED NOT NULL DEFAULT 0,
    `best_streak` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_delivery` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`),
    INDEX `idx_completed` (`completed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
