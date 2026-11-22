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
    `featured` TINYINT(1) NOT NULL DEFAULT 0,
    `hidden` TINYINT(1) NOT NULL DEFAULT 0,
    `edited_at` INT DEFAULT NULL,
    `pin_x` DOUBLE DEFAULT NULL,
    `pin_y` DOUBLE DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_expires` (`expires_at`),
    KEY `idx_town` (`town`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_noticeboard_reports` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `notice_id` INT NOT NULL,
    `reporter` VARCHAR(64) NOT NULL,
    `reason` VARCHAR(16) NOT NULL,
    `created_at` INT NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_notice_reporter` (`notice_id`, `reporter`),
    KEY `idx_reporter` (`reporter`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_noticeboard_reminders` (
    `notice_id` INT NOT NULL,
    `citizenid` VARCHAR(64) NOT NULL,
    PRIMARY KEY (`notice_id`, `citizenid`),
    KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_noticeboard_bans` (
    `citizenid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(128) NOT NULL DEFAULT '',
    `reason` VARCHAR(64) NOT NULL DEFAULT '',
    `banned_by` VARCHAR(64) DEFAULT NULL,
    `created_at` INT NOT NULL,
    `expires_at` INT NOT NULL,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
