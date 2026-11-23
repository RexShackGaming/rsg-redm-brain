-- Upgrading from an older version? The columns are added automatically while Config.AutoDatabase = true.
-- For a manual upgrade run these lines once (skip the ones your table already has):
--   ALTER TABLE `rsg_doorlocks` ADD COLUMN `lockpick` VARCHAR(16) NULL DEFAULT NULL;
--   ALTER TABLE `rsg_doorlocks` ADD COLUMN `region` VARCHAR(32) NULL DEFAULT NULL;
--   ALTER TABLE `rsg_doorlocks` ADD COLUMN `key_item` VARCHAR(64) NULL DEFAULT NULL;
--   ALTER TABLE `rsg_doorlocks` ADD COLUMN `gangs` LONGTEXT NULL;
--   ALTER TABLE `rsg_doorlocks` ADD COLUMN `group_name` VARCHAR(32) NULL DEFAULT NULL;
--   ALTER TABLE `rsg_doorlocks` ADD COLUMN `open_from` TINYINT NULL DEFAULT NULL;
--   ALTER TABLE `rsg_doorlocks` ADD COLUMN `open_to` TINYINT NULL DEFAULT NULL;
CREATE TABLE IF NOT EXISTS `rsg_doorlocks` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(64) NOT NULL,
    `doors` LONGTEXT NOT NULL,
    `text_coords` LONGTEXT NOT NULL,
    `jobs` LONGTEXT NOT NULL,
    `distance` FLOAT NOT NULL DEFAULT 1.25,
    `locked` TINYINT(1) NOT NULL DEFAULT 1,
    `lockpick` VARCHAR(16) NULL DEFAULT NULL,
    `region` VARCHAR(32) NULL DEFAULT NULL,
    `key_item` VARCHAR(64) NULL DEFAULT NULL,
    `gangs` LONGTEXT NULL,
    `group_name` VARCHAR(32) NULL DEFAULT NULL,
    `open_from` TINYINT NULL DEFAULT NULL,
    `open_to` TINYINT NULL DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
