-- rsg-crafting: only needed when Config.AutoDatabase = false (the tables are otherwise created on start)

CREATE TABLE IF NOT EXISTS `rsg_crafting_recipes` (
    `citizenid`  VARCHAR(50) NOT NULL,
    `recipe`     VARCHAR(64) NOT NULL,
    `learned_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `recipe`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_crafting_stations` (
    `id`   INT          NOT NULL AUTO_INCREMENT,
    `type` VARCHAR(32)  NOT NULL,
    `x`    DOUBLE       NOT NULL,
    `y`    DOUBLE       NOT NULL,
    `z`    DOUBLE       NOT NULL,
    `rx`   DOUBLE       NOT NULL DEFAULT 0,
    `ry`   DOUBLE       NOT NULL DEFAULT 0,
    `rz`   DOUBLE       NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
