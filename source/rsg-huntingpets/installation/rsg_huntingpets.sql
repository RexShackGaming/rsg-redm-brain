-- rsg-huntingpets database schema
-- The tables are created automatically on start while Config.AutoDatabase = true.
-- Import this file only for a manual install (Config.AutoDatabase = false), for example when
-- the resource's database user is not allowed to CREATE TABLE.
-- Safe to run more than once: it never drops or alters existing pet data.

CREATE TABLE IF NOT EXISTS `player_dogs` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(50) NOT NULL,
    `charid` INT(11) NOT NULL,
    `model` VARCHAR(255) NOT NULL,
    `preset` INT(11) NOT NULL DEFAULT '0',
    `xp` INT(11) NOT NULL DEFAULT '0',
    `price` INT(11) NOT NULL DEFAULT '0',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `player_birds` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(50) NOT NULL,
    `charid` INT(11) NOT NULL,
    `model` VARCHAR(255) NOT NULL,
    `preset` INT(11) NOT NULL DEFAULT '0',
    `xp` INT(11) NOT NULL DEFAULT '0',
    `price` INT(11) NOT NULL DEFAULT '0',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `player_selected_pets` (
    `identifier` VARCHAR(50) NOT NULL,
    `charid` INT(11) NOT NULL,
    `selected_dog` INT(11) DEFAULT NULL,
    `selected_bird` INT(11) DEFAULT NULL,
    UNIQUE KEY `uc_player` (`identifier`, `charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
