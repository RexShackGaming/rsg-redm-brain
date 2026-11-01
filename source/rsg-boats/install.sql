CREATE TABLE IF NOT EXISTS `rsg_boats_models` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `model` VARCHAR(64) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `description` VARCHAR(255) NOT NULL DEFAULT '',
  `price` INT NOT NULL DEFAULT 0,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `slots` INT NOT NULL DEFAULT 10,
  `weight` INT NOT NULL DEFAULT 50000,
  PRIMARY KEY (`id`),
  UNIQUE KEY `model` (`model`)
);

CREATE TABLE IF NOT EXISTS `rsg_boats_owned` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `model` VARCHAR(64) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `purchased` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `yard` INT NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `rsg_boats_yards` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(64) NOT NULL,
  `coords` VARCHAR(255) NOT NULL,
  `spawn` VARCHAR(255) NULL DEFAULT NULL,
  `dock` VARCHAR(255) NULL DEFAULT NULL,
  `models` TEXT NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `rsg_boats_settings` (
  `k` VARCHAR(64) NOT NULL,
  `v` LONGTEXT NOT NULL,
  PRIMARY KEY (`k`)
);

-- model: femga/rdr3_discoveries vehicles/vehicles_list.lua (0x9FD6BA58 "rowboat")
INSERT IGNORE INTO `rsg_boats_models` (`model`, `label`, `description`, `price`, `enabled`, `slots`, `weight`)
VALUES ('rowboat', 'Rowboat', 'A sturdy wooden rowboat for rivers and bayous.', 75, 1, 10, 50000);
