-- only needed when Config.AutoDatabase = false
CREATE TABLE IF NOT EXISTS `rsg_guarma_players` (
    `citizenid` VARCHAR(50) NOT NULL,
    `trade_day` VARCHAR(10) NOT NULL DEFAULT '',
    `bought` TEXT NULL,
    `rescue_at` BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
