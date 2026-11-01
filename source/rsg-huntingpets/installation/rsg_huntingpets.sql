-- rsg-huntingpets Database Setup (OPTIONAL / REFERENCE ONLY)
-- As of this version, server/database.lua creates these tables
-- automatically the first time the resource starts (CREATE TABLE IF NOT
-- EXISTS), so running this file by hand is no longer required.
--
-- Keep this around only for manual setups (e.g. shared hosting where the
-- resource's database user isn't allowed to CREATE TABLE) or to inspect the
-- schema. WARNING: this file DROPs the tables before recreating them --
-- do not run it against a database that already has player pet data you
-- want to keep.

DROP TABLE IF EXISTS `player_dogs`;
DROP TABLE IF EXISTS `player_birds`;

CREATE TABLE `player_dogs` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(50) NOT NULL,
    `charid` INT(11) NOT NULL,
    `model` VARCHAR(255) NOT NULL,
    `preset` INT(11) NOT NULL DEFAULT '0',
    `xp` INT(11) NOT NULL DEFAULT '0',
    `price` INT(11) NOT NULL DEFAULT '0',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `player_birds` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(50) NOT NULL,
    `charid` INT(11) NOT NULL,
    `model` VARCHAR(255) NOT NULL,
    `preset` INT(11) NOT NULL DEFAULT '0',
    `xp` INT(11) NOT NULL DEFAULT '0',
    `price` INT(11) NOT NULL DEFAULT '0',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS `player_selected_pets`;

CREATE TABLE `player_selected_pets` (
    `identifier` VARCHAR(50) NOT NULL,
    `charid` INT(11) NOT NULL,
    `selected_dog` INT(11) DEFAULT NULL,
    `selected_bird` INT(11) DEFAULT NULL,
    UNIQUE KEY `uc_player` (`identifier`, `charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
