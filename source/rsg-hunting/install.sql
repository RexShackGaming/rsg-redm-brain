-- rsg-hunting: weekly leaderboard + weekly rewards
CREATE TABLE IF NOT EXISTS `hunting_weekly` (
    `citizenid` VARCHAR(50) NOT NULL,
    `week` INT NOT NULL,
    `name` VARCHAR(100) NOT NULL DEFAULT '',
    `xp` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`, `week`),
    KEY `week_xp` (`week`, `xp`)
);

CREATE TABLE IF NOT EXISTS `hunting_weekly_rewards` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `week` INT NOT NULL,
    `rank` INT NOT NULL,
    `cash` DECIMAL(10,2) NOT NULL DEFAULT 0,
    `claimed` TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `cid_week` (`citizenid`, `week`)
);
