-- rsg-mining manual install
-- The script creates these tables automatically on start; run this only if you
-- prefer to set the database up by hand (or your DB user lacks CREATE rights).

CREATE TABLE IF NOT EXISTS `rsg_mining` (
    `mine`      VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) NULL DEFAULT NULL,
    `expires`   INT NOT NULL DEFAULT 0,
    `wages`     INT NOT NULL DEFAULT 0,
    `supplies`  LONGTEXT NULL,
    `storage`   LONGTEXT NULL,
    PRIMARY KEY (`mine`)
);

CREATE TABLE IF NOT EXISTS `rsg_mining_workers` (
    `id`      INT NOT NULL AUTO_INCREMENT,
    `mine`    VARCHAR(50) NOT NULL,
    `name`    VARCHAR(100) NOT NULL,
    `skill`   FLOAT NOT NULL DEFAULT 1,
    `food`    INT NOT NULL DEFAULT 100,
    `water`   INT NOT NULL DEFAULT 100,
    `pickaxe` INT NOT NULL DEFAULT 0,
    `status`  VARCHAR(50) NOT NULL DEFAULT 'idle',
    PRIMARY KEY (`id`)
);

-- Upgrading an install from before payroll existed? Run this once
-- (skip it if the `wages` column is already there):
-- ALTER TABLE `rsg_mining` ADD COLUMN `wages` INT NOT NULL DEFAULT 0;
