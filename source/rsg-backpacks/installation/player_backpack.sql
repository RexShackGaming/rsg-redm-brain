CREATE TABLE IF NOT EXISTS `player_backpack` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `serial` VARCHAR(32) NOT NULL,
    `citizenid` VARCHAR(50) DEFAULT NULL,
    `owner` VARCHAR(50) DEFAULT NULL,
    `backpackitem` VARCHAR(50) NOT NULL,
    `model` VARCHAR(100) DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `serial` (`serial`),
    KEY `owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
