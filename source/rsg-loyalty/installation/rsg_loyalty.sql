CREATE TABLE IF NOT EXISTS `rsg_loyalty` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `charname` VARCHAR(50) NOT NULL,
  `loyalty_points` INT NOT NULL DEFAULT 0,
  `lifetime_points` INT NOT NULL DEFAULT 0,
  `daily_streak` INT NOT NULL DEFAULT 0,
  `last_daily` DATE NULL,
  `last_update` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `citizenid` (`citizenid`),
  KEY `loyalty_points_idx` (`loyalty_points`),
  KEY `lifetime_points_idx` (`lifetime_points`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_loyalty_history` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `amount` INT NOT NULL,
  `reason` VARCHAR(32) NOT NULL,
  `detail` VARCHAR(100) NULL,
  `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `citizen_idx` (`citizenid`, `id`),
  KEY `created_idx` (`created`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_loyalty_redemptions` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `reward_id` VARCHAR(64) NOT NULL,
  `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `reward_idx` (`reward_id`, `created`),
  KEY `citizen_reward_idx` (`citizenid`, `reward_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Upgrading a manual install from 3.0.x? Run these two statements once (skip if the columns already exist):
-- ALTER TABLE `rsg_loyalty` ADD COLUMN `daily_streak` INT NOT NULL DEFAULT 0;
-- ALTER TABLE `rsg_loyalty` ADD COLUMN `last_daily` DATE NULL;
