-- rsg-radio: private (passcode) channels
-- Created automatically on start when Config.AutoDatabase = true. Import this file only for a manual install.
CREATE TABLE IF NOT EXISTS `rsg_radio_private` (
  `freq` VARCHAR(16) NOT NULL,
  `owner` VARCHAR(50) NOT NULL,
  `name` VARCHAR(32) NOT NULL DEFAULT '',
  `code` VARCHAR(32) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_used` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`freq`),
  KEY `owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
