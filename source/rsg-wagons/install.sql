-- rsg-wagons: only needed if Config.AutoDatabase = false
CREATE TABLE IF NOT EXISTS `player_wagons` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `model` VARCHAR(50) NOT NULL,
  `name` VARCHAR(40) NOT NULL,
  `wagon_condition` INT(11) NOT NULL DEFAULT 100,
  `store` VARCHAR(50) NOT NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 0,
  `livery` INT(11) NOT NULL DEFAULT -1,
  `tint` INT(11) NOT NULL DEFAULT -1,
  `propset` VARCHAR(64) NULL DEFAULT NULL,
  `lantern` VARCHAR(64) NULL DEFAULT NULL,
  `cargo` LONGTEXT NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Upgrading an existing install? Add the livery column:
-- ALTER TABLE `player_wagons` ADD COLUMN `livery` INT(11) NOT NULL DEFAULT -1;
-- ALTER TABLE `player_wagons` ADD COLUMN `tint` INT(11) NOT NULL DEFAULT -1;
-- ALTER TABLE `player_wagons` ADD COLUMN `propset` VARCHAR(64) NULL DEFAULT NULL, ADD COLUMN `lantern` VARCHAR(64) NULL DEFAULT NULL;
-- ALTER TABLE `player_wagons` ADD COLUMN `cargo` LONGTEXT NULL DEFAULT NULL;
