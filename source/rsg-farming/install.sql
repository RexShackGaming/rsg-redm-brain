-- rsg-farming manual install (only needed when Config.AutoDatabase = false)
-- Keep in sync with the schema in server/utils.lua

CREATE TABLE IF NOT EXISTS `rsg_farming_plants` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `crop` VARCHAR(50) NOT NULL,
    `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL, `h` FLOAT NOT NULL DEFAULT 0,
    `growth` FLOAT NOT NULL DEFAULT 0,
    `water` FLOAT NOT NULL DEFAULT 0,
    `fertilizer` FLOAT NOT NULL DEFAULT 0,
    `health` FLOAT NOT NULL DEFAULT 100,
    `dead` TINYINT(1) NOT NULL DEFAULT 0,
    `dead_time` INT(11) NOT NULL DEFAULT 0,
    `planted_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
