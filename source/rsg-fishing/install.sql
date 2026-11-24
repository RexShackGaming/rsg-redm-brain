-- rsg-fishing: angler's journal and server records
-- Created automatically on start when Config.AutoDatabase = true. Import this file only for a manual install.

CREATE TABLE IF NOT EXISTS `rsg_fishing_journal` (
  `citizenid` VARCHAR(50) NOT NULL,
  `species` VARCHAR(60) NOT NULL,
  `name` VARCHAR(100) NOT NULL DEFAULT '',
  `caught` INT NOT NULL DEFAULT 0,
  `best_weight` DECIMAL(8,2) NOT NULL DEFAULT 0,
  `first_caught` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_caught` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`, `species`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_fishing_records` (
  `species` VARCHAR(60) NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NOT NULL DEFAULT '',
  `weight` DECIMAL(8,2) NOT NULL DEFAULT 0,
  `caught_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`species`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
