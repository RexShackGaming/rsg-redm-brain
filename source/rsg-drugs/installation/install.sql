CREATE TABLE IF NOT EXISTS `rsg_drugs_labs` (
  `citizenid` VARCHAR(50) NOT NULL,
  `data` LONGTEXT NOT NULL,
  PRIMARY KEY (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `rsg_drugs_state` (
  `key` VARCHAR(50) NOT NULL,
  `value` LONGTEXT NOT NULL,
  PRIMARY KEY (`key`)
);
