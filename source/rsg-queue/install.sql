-- rsg-queue: only needed when Config.AutoDatabase = false
CREATE TABLE IF NOT EXISTS `rsg_queue_vip` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(80) NOT NULL,
    `name` VARCHAR(100) DEFAULT NULL,
    `tier` VARCHAR(30) NOT NULL,
    `expires_at` DATETIME DEFAULT NULL,
    `added_by` VARCHAR(100) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_queue_rewards` (
    `license` VARCHAR(80) NOT NULL,
    `last_claim` DATETIME NOT NULL,
    PRIMARY KEY (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
