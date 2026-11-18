CREATE TABLE IF NOT EXISTS `rsg_factories` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(64) NOT NULL,
  `ped_model` VARCHAR(64) NOT NULL,
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `h` DOUBLE NOT NULL DEFAULT 0,
  `recipes` LONGTEXT NOT NULL,
  `created_by` VARCHAR(50) DEFAULT NULL,
  `owner` VARCHAR(50) DEFAULT NULL,
  `owner_name` VARCHAR(64) DEFAULT NULL,
  `price` INT NOT NULL DEFAULT 5000,
  `fuel` INT NOT NULL DEFAULT 0,
  `water` INT NOT NULL DEFAULT 0,
  `bank` INT NOT NULL DEFAULT 0,
  `settings` LONGTEXT DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_factory_queue` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `factory_id` INT NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `outputs` LONGTEXT NOT NULL,
  `finish_at` BIGINT NOT NULL,
  `stages` LONGTEXT DEFAULT NULL,
  `notified` TINYINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_factory_citizen` (`factory_id`, `citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
