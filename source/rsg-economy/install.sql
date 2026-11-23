-- rsg-economy: manual install (only needed when Config.AutoDatabase = false)

CREATE TABLE IF NOT EXISTS `rsg_economy_treasury` (
    `region` VARCHAR(50) NOT NULL,
    `balance` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (`region`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_economy_tax` (
    `region` VARCHAR(50) NOT NULL,
    `category` VARCHAR(50) NOT NULL,
    `rate` DECIMAL(6,4) NOT NULL DEFAULT 0.0000,
    PRIMARY KEY (`region`, `category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_economy_ledger` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `region` VARCHAR(50) NOT NULL,
    `amount` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `balance_after` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `kind` VARCHAR(20) NOT NULL,
    `reason` VARCHAR(120) NOT NULL DEFAULT '',
    `actor` VARCHAR(80) NOT NULL DEFAULT '',
    `created` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_region_created` (`region`, `created`),
    KEY `idx_created` (`created`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_economy_market` (
    `item` VARCHAR(50) NOT NULL,
    `region` VARCHAR(50) NOT NULL,
    `pressure` DOUBLE NOT NULL DEFAULT 0,
    `updated` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`item`, `region`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_economy_project` (
    `region` VARCHAR(50) NOT NULL,
    `project` VARCHAR(50) NOT NULL,
    `expires` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`region`, `project`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_economy_meta` (
    `k` VARCHAR(50) NOT NULL,
    `v` VARCHAR(100) NOT NULL,
    PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_economy_region` (
    `id` VARCHAR(50) NOT NULL,
    `label` VARCHAR(60) NOT NULL,
    `ord` INT NOT NULL DEFAULT 99,
    `x` DOUBLE NOT NULL DEFAULT 0,
    `y` DOUBLE NOT NULL DEFAULT 0,
    `z` DOUBLE NOT NULL DEFAULT 0,
    `law_job` VARCHAR(50) NULL,
    `officials` TEXT NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_economy_mayor` (
    `region` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `since` INT UNSIGNED NOT NULL,
    `term_end` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`region`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_economy_election` (
    `region` VARCHAR(50) NOT NULL,
    `phase` VARCHAR(12) NOT NULL,
    `phase_end` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`region`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_economy_candidate` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `region` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `platform` VARCHAR(200) NOT NULL DEFAULT '',
    `registered` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_region_citizen` (`region`, `citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_economy_vote` (
    `region` VARCHAR(50) NOT NULL,
    `license` VARCHAR(80) NOT NULL,
    `voter` VARCHAR(50) NOT NULL,
    `candidate` INT UNSIGNED NOT NULL,
    `voted` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`region`, `license`),
    KEY `idx_candidate` (`candidate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
