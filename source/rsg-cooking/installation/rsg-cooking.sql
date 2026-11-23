-- optional: the resource creates this table automatically on start
CREATE TABLE IF NOT EXISTS `rsg_cooking_stations` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `world` TINYINT(1) NOT NULL DEFAULT 0,
    `stype` VARCHAR(20) NOT NULL DEFAULT 'campfire',
    `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
    `heading` FLOAT NOT NULL DEFAULT 0,
    `recipe` VARCHAR(50) DEFAULT NULL,
    `hopper` LONGTEXT DEFAULT NULL,
    `output` INT NOT NULL DEFAULT 0,
    `fuel` INT NOT NULL DEFAULT 0,
    `batch_left` INT DEFAULT NULL,
    `last_tick` INT DEFAULT NULL,
    `last_used` INT DEFAULT NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_citizenid` (`citizenid`)
);

-- upgrading from 3.4.x or older by hand (AutoDatabase = false)? run this once:
-- ALTER TABLE `rsg_cooking_stations` ADD COLUMN `last_used` INT DEFAULT NULL;
-- UPDATE `rsg_cooking_stations` SET `last_used` = UNIX_TIMESTAMP() WHERE `last_used` IS NULL;

-- the old campfire table from v3 is no longer used and can be dropped:
-- DROP TABLE IF EXISTS `rsg_cooking_campfires`;
