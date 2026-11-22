-- Upgrading from an older version? The columns are added automatically while Config.AutoDatabase = true.
-- For a manual upgrade run these two lines once:
--   ALTER TABLE `rsg_doorlocks` ADD COLUMN `lockpick` VARCHAR(16) NULL DEFAULT NULL;
--   ALTER TABLE `rsg_doorlocks` ADD COLUMN `region` VARCHAR(32) NULL DEFAULT NULL;
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
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
