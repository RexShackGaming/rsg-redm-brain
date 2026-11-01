-- optional: the resource also creates/upgrades this table automatically on start
CREATE TABLE IF NOT EXISTS `rsg_moonshine_stills` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
    `heading` FLOAT NOT NULL DEFAULT 0,
    `recipe` VARCHAR(50) DEFAULT NULL,
    `hopper` LONGTEXT DEFAULT NULL,
    `output` INT NOT NULL DEFAULT 0,
    `fuel` INT NOT NULL DEFAULT 0,
    `batch_left` INT DEFAULT NULL,
    `last_tick` INT DEFAULT NULL,
    PRIMARY KEY (`id`)
);

-- upgrading an existing table on MySQL 8 (MariaDB is upgraded automatically):
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `hopper` LONGTEXT DEFAULT NULL;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `output` INT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `fuel` INT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `batch_left` INT DEFAULT NULL;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `last_tick` INT DEFAULT NULL;
