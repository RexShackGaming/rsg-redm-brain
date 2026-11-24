-- rsg-fishmonger: only needed when Config.AutoDatabase = false
CREATE TABLE IF NOT EXISTS `rsg_fishmonger_stock` (
  `location` VARCHAR(50) NOT NULL,
  `day` VARCHAR(10) NOT NULL,
  `sold` INT NOT NULL DEFAULT 0,
  `updated` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`location`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_fishmonger_orders` (
  `citizenid` VARCHAR(50) NOT NULL,
  `location` VARCHAR(50) NOT NULL,
  `slot` TINYINT NOT NULL,
  `day` VARCHAR(10) NOT NULL,
  PRIMARY KEY (`citizenid`, `location`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- upgrading a manual 3.2.x install: ALTER TABLE `rsg_fishmonger_stock` ADD COLUMN `updated` INT NOT NULL DEFAULT 0;
