-- =====================================================
-- RSG-LUMBER - DATABASE SCHEMA
-- =====================================================
-- This table is created automatically on resource start
-- (server/main.lua). This file is provided for reference /
-- manual installation only.
-- =====================================================

CREATE TABLE IF NOT EXISTS `rsg_lumberjack_trees` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64) NOT NULL,
    `owner_citizenid` VARCHAR(50) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `heading` FLOAT NOT NULL DEFAULT 0,
    `model` VARCHAR(64) NOT NULL DEFAULT 'p_tree_birch_01_sapling',
    `stage` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `state` ENUM('planted','growing','ready','chopped') NOT NULL DEFAULT 'planted',
    `watered` TINYINT(1) NOT NULL DEFAULT 0,
    `fertilized` TINYINT(1) NOT NULL DEFAULT 0,
    `planted_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `next_stage_at` DATETIME NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_owner` (`owner_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
