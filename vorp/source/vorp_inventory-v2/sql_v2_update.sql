
CREATE TABLE `item_rarity` (
    `id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
    `description` VARCHAR(255) NOT NULL DEFAULT '' COMMENT 'Description of item rarity' COLLATE 'utf8mb4_general_ci',
    PRIMARY KEY (`id`) USING BTREE,
    UNIQUE INDEX `uk_item_rarity_name` (`name`) USING BTREE
)
COLLATE='utf8mb4_general_ci'
ENGINE=InnoDB;


INSERT INTO `item_rarity` (`id`, `name`, `description`) VALUES
(1, 'Common', 'Common item'),
(2, 'Uncommon', 'Uncommon item'),
(3, 'Rare', 'Rare item'),
(4, 'Epic', 'Epic item'),
(5, 'Legendary', 'Legendary item');


ALTER TABLE `items`
    ADD COLUMN `durability` INT NULL DEFAULT NULL COMMENT 'Optional default/max durability',
    ADD COLUMN `instructions` LONGTEXT NULL DEFAULT NULL COMMENT 'you can add a item instruction like where to find it how to use it' COLLATE 'armscii8_general_ci',
    ADD COLUMN `rarityId` INT(10) UNSIGNED NOT NULL DEFAULT '1' COMMENT 'Item Rarity ID for filtering' AFTER `groupId`,
    ADD INDEX `FK_items_item_rarity` (`rarityId`) USING BTREE,
    ADD CONSTRAINT `FK_items_item_rarity` FOREIGN KEY (`rarityId`) REFERENCES `item_rarity` (`id`)
    ON UPDATE NO ACTION ON DELETE NO ACTION;


ALTER TABLE `items_crafted`
    ADD COLUMN `durability` INT NULL DEFAULT NULL;


ALTER TABLE `loadout`
    CHANGE COLUMN `dirtlevel` `dirt` DECIMAL(20,6) NULL DEFAULT '0.000000',
    CHANGE COLUMN `mudlevel` `soot` DECIMAL(20,6) NULL DEFAULT '0.000000',
    CHANGE COLUMN `conditionlevel` `degradation` DECIMAL(20,6) NULL DEFAULT '0.000000',
    CHANGE COLUMN `rustlevel` `damage` DECIMAL(20,6) NULL DEFAULT '0.000000',
    ADD INDEX `identifier` (`identifier`) USING BTREE;