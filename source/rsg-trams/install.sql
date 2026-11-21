-- rsg-trams: only needed when Config.AutoDatabase = false
CREATE TABLE IF NOT EXISTS `rsg_trams_state` (
  `key` VARCHAR(60) NOT NULL,
  `value` VARCHAR(10) NOT NULL,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
