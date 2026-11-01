CREATE TABLE IF NOT EXISTS `player_goldrockers` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) DEFAULT NULL,
    `owner` varchar(50) DEFAULT NULL,
    `properties` text NOT NULL,
    `propid` int(11) NOT NULL,
    `proptype` varchar(50) DEFAULT NULL,
    `licensed` tinyint(1) NOT NULL DEFAULT 0,
    `claimname` varchar(100) DEFAULT NULL,
    `paydirt` int(3) NOT NULL DEFAULT 0,
    `water` int(3) NOT NULL DEFAULT 0,
    `quality` int(3) NOT NULL DEFAULT 100,
    PRIMARY KEY (`id`),
    UNIQUE KEY `propid` (`propid`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- upgrading an existing install? run these once instead:
-- ALTER TABLE `player_goldrockers` ADD UNIQUE KEY `propid` (`propid`);
-- ALTER TABLE `player_goldrockers` ADD KEY `citizenid` (`citizenid`);
