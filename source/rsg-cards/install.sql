-- rsg-cards
-- Only needed when Config.AutoDatabase = false (tables are created automatically otherwise).

-- Upgrading from the old tilp-hdrp-collectablecards? Keep your boxes by running this first:
-- RENAME TABLE `hdrp_boxes` TO `rsg_cards_boxes`;

CREATE TABLE IF NOT EXISTS `rsg_cards_boxes` (
    `serial`  VARCHAR(20) NOT NULL,
    `creator` VARCHAR(50) NOT NULL,
    `owner`   VARCHAR(50) NOT NULL,
    PRIMARY KEY (`serial`),
    INDEX `idx_creator` (`creator`),
    INDEX `idx_owner` (`owner`)
);

CREATE TABLE IF NOT EXISTS `rsg_cards_collection` (
    `citizenid`   VARCHAR(50) NOT NULL,
    `card`        VARCHAR(50) NOT NULL,
    `obtained_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `card`)
);

CREATE TABLE IF NOT EXISTS `rsg_cards_pickups` (
    `citizenid` VARCHAR(50) NOT NULL,
    `card`      VARCHAR(50) NOT NULL,
    `picked_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`citizenid`, `card`)
);
