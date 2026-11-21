-- rsg-fishmonger: only needed when Config.AutoDatabase = false
CREATE TABLE IF NOT EXISTS `rsg_fishmonger_stock` (
  `location` VARCHAR(50) NOT NULL,
  `day` VARCHAR(10) NOT NULL,
  `sold` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`location`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
