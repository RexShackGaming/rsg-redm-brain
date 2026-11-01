CREATE TABLE IF NOT EXISTS `rsg_noticeboard_boards` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `label` VARCHAR(64) NOT NULL DEFAULT 'Notice Board',
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `heading` DOUBLE NOT NULL DEFAULT 0,
    `created_by` VARCHAR(64) DEFAULT NULL,
    `created_at` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_noticeboard_notices` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(64) NOT NULL,
    `author` VARCHAR(128) NOT NULL,
    `title` VARCHAR(128) NOT NULL,
    `body` TEXT NOT NULL,
    `image` VARCHAR(512) DEFAULT NULL,
    `category` VARCHAR(32) NOT NULL,
    `town` VARCHAR(32) DEFAULT NULL,
    `duration` VARCHAR(16) NOT NULL,
    `created_at` INT NOT NULL,
    `expires_at` INT NOT NULL,
    `warned` TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_expires` (`expires_at`),
    KEY `idx_town` (`town`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
