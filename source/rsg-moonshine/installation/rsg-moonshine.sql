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
    `quality` INT NOT NULL DEFAULT 0,
    `op_level` INT NOT NULL DEFAULT 1,
    `trusted` LONGTEXT DEFAULT NULL,
    `label` VARCHAR(100) DEFAULT NULL,
    `kind` VARCHAR(10) NOT NULL DEFAULT 'still',
    `wash` INT NOT NULL DEFAULT 0,
    `ferment_left` INT DEFAULT NULL,
    `heat` VARCHAR(10) NOT NULL DEFAULT 'medium',
    `proof` INT NOT NULL DEFAULT 0,
    `reran` TINYINT NOT NULL DEFAULT 0,
    `rerun_left` INT DEFAULT NULL,
    `rerun_vol` INT NOT NULL DEFAULT 0,
    `cask` TINYINT NOT NULL DEFAULT 0,
    `cask_recipe` VARCHAR(50) DEFAULT NULL,
    `cask_vol` INT NOT NULL DEFAULT 0,
    `cask_q` INT NOT NULL DEFAULT 0,
    `cask_proof` INT NOT NULL DEFAULT 0,
    `cask_start` INT DEFAULT NULL,
    `wear` INT NOT NULL DEFAULT 0,
    `water` INT NOT NULL DEFAULT 0,
    `dry` INT NOT NULL DEFAULT 0,
    `material` VARCHAR(10) NOT NULL DEFAULT 'copper',
    `mash_q` INT DEFAULT NULL,
    `ferment_q` INT DEFAULT NULL,
    `wash_q` INT DEFAULT NULL,
    `batch_q` INT DEFAULT NULL,
    PRIMARY KEY (`id`)
);

-- upgrading an existing table on MySQL 8 (MariaDB is upgraded automatically):
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `hopper` LONGTEXT DEFAULT NULL;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `output` INT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `fuel` INT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `batch_left` INT DEFAULT NULL;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `last_tick` INT DEFAULT NULL;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `quality` INT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `op_level` INT NOT NULL DEFAULT 1;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `trusted` LONGTEXT DEFAULT NULL;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `label` VARCHAR(100) DEFAULT NULL;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `kind` VARCHAR(10) NOT NULL DEFAULT 'still';
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `wash` INT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `ferment_left` INT DEFAULT NULL;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `heat` VARCHAR(10) NOT NULL DEFAULT 'medium';
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `proof` INT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `reran` TINYINT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `rerun_left` INT DEFAULT NULL;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `rerun_vol` INT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `cask` TINYINT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `cask_recipe` VARCHAR(50) DEFAULT NULL;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `cask_vol` INT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `cask_q` INT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `cask_proof` INT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `cask_start` INT DEFAULT NULL;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `wear` INT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `water` INT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `dry` INT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `material` VARCHAR(10) NOT NULL DEFAULT 'copper';
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `mash_q` INT DEFAULT NULL;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `ferment_q` INT DEFAULT NULL;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `wash_q` INT DEFAULT NULL;
-- ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `batch_q` INT DEFAULT NULL;
