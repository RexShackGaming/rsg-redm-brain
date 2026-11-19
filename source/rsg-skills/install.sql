-- rsg-skills: skills, XP and weekly leaderboard tables
-- Created automatically on start when Config.AutoDatabase = true. Import this file only if you set it to false.

CREATE TABLE IF NOT EXISTS `rsg_skills` (
    `citizenid` VARCHAR(50) NOT NULL,
    `skill` VARCHAR(50) NOT NULL,
    `xp` INT UNSIGNED NOT NULL DEFAULT 0,
    `name` VARCHAR(100) NOT NULL DEFAULT '',
    `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `skill`),
    KEY `skill_xp` (`skill`, `xp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_skills_weekly` (
    `citizenid` VARCHAR(50) NOT NULL,
    `skill` VARCHAR(50) NOT NULL,
    `week` INT NOT NULL,
    `xp` INT UNSIGNED NOT NULL DEFAULT 0,
    `name` VARCHAR(100) NOT NULL DEFAULT '',
    PRIMARY KEY (`citizenid`, `skill`, `week`),
    KEY `week_skill_xp` (`week`, `skill`, `xp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
