-- rsg-reputation: manual install (only needed when Config.AutoDatabase = false)

CREATE TABLE IF NOT EXISTS `rsg_reputation` (
    `citizenid` VARCHAR(50) NOT NULL,
    `honor` INT NOT NULL DEFAULT 0,
    `decayed` INT UNSIGNED NOT NULL DEFAULT 0,
    `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_reputation_standing` (
    `citizenid` VARCHAR(50) NOT NULL,
    `region` VARCHAR(50) NOT NULL,
    `standing` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`, `region`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
