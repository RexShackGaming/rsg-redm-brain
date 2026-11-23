-- rsg-canteen: tables are created automatically on start (Config.AutoDatabase = true).
-- Import this file only if you set Config.AutoDatabase = false.

CREATE TABLE IF NOT EXISTS `rsg_canteen_pumps` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
    `model` VARCHAR(64) NOT NULL DEFAULT '',
    `added_by` VARCHAR(50) NOT NULL DEFAULT '',
    `added_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
