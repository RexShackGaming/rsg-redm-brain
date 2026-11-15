CREATE TABLE IF NOT EXISTS `townhall_locations` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `label` VARCHAR(60) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `h` DOUBLE NOT NULL DEFAULT 0,
    `created_by` VARCHAR(50) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `townhall_managers` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NULL,
    `job` VARCHAR(50) NOT NULL DEFAULT '*',
    `added_by` VARCHAR(50) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_manager` (`citizenid`, `job`)
);

CREATE TABLE IF NOT EXISTS `townhall_postings` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `job` VARCHAR(50) NOT NULL,
    `grade` VARCHAR(10) NOT NULL,
    `title` VARCHAR(100) NOT NULL,
    `description` TEXT NOT NULL,
    `requirements` TEXT NOT NULL,
    `questions` LONGTEXT NULL,
    `slots` INT NOT NULL DEFAULT 1,
    `filled_count` INT NOT NULL DEFAULT 0,
    `expires_at` TIMESTAMP NULL DEFAULT NULL,
    `location_id` INT NOT NULL DEFAULT 0,
    `req_items` TEXT NULL,
    `req_job` VARCHAR(50) NOT NULL DEFAULT '',
    `req_job_grade` INT NOT NULL DEFAULT 0,
    `status` VARCHAR(16) NOT NULL DEFAULT 'open',
    `posted_by` VARCHAR(50) NOT NULL,
    `posted_by_name` VARCHAR(100) NULL,
    `filled_by` VARCHAR(50) NULL,
    `filled_by_name` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `closed_at` TIMESTAMP NULL DEFAULT NULL,
    `warned` TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_status` (`status`),
    KEY `idx_job` (`job`)
);

CREATE TABLE IF NOT EXISTS `townhall_applications` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `posting_id` INT NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `applicant_name` VARCHAR(100) NULL,
    `answers` LONGTEXT NOT NULL,
    `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
    `interview_note` TEXT NULL,
    `feedback` TEXT NULL,
    `granted` TINYINT(1) NOT NULL DEFAULT 1,
    `reviewed_by` VARCHAR(50) NULL,
    `reviewed_by_name` VARCHAR(100) NULL,
    `reviewed_at` TIMESTAMP NULL DEFAULT NULL,
    `seen` TINYINT(1) NOT NULL DEFAULT 1,
    `notified` TINYINT(1) NOT NULL DEFAULT 1,
    `fee` INT NOT NULL DEFAULT 0,
    `refund` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_posting` (`posting_id`),
    KEY `idx_citizen` (`citizenid`),
    KEY `idx_status` (`status`)
);

CREATE TABLE IF NOT EXISTS `townhall_resignations` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `job` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_citizen_job` (`citizenid`, `job`)
);

CREATE TABLE IF NOT EXISTS `townhall_messages` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `application_id` INT NOT NULL,
    `sender_cid` VARCHAR(50) NOT NULL,
    `sender_name` VARCHAR(100) NULL,
    `from_reviewer` TINYINT(1) NOT NULL DEFAULT 0,
    `body` TEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_application` (`application_id`)
);

CREATE TABLE IF NOT EXISTS `townhall_templates` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(60) NOT NULL,
    `data` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_citizen` (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `townhall_blacklist` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NULL,
    `job` VARCHAR(50) NOT NULL DEFAULT '*',
    `reason` TEXT NULL,
    `added_by` VARCHAR(50) NULL,
    `added_by_name` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_block` (`citizenid`, `job`)
);
