CREATE TABLE IF NOT EXISTS `rsg_legendary_cooldowns` (
    `citizenid` VARCHAR(50) NOT NULL,
    `animal` VARCHAR(50) NOT NULL,
    `last_hunt` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `animal`)
);
