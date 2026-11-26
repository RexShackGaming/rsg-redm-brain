-- rsg-npcdialog: only needed when Config.AutoDatabase = false
CREATE TABLE IF NOT EXISTS `rsg_npcdialog_npcs` (
  `id` VARCHAR(50) NOT NULL,
  `data` LONGTEXT NOT NULL,
  `updated_by` VARCHAR(50) DEFAULT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
CREATE TABLE IF NOT EXISTS `rsg_npcdialog_progress` (
  `citizenid` VARCHAR(50) NOT NULL,
  `kind` VARCHAR(8) NOT NULL,
  `name` VARCHAR(160) NOT NULL,
  `value` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`, `kind`, `name`)
);
CREATE TABLE IF NOT EXISTS `rsg_npcdialog_quests` (
  `id` VARCHAR(50) NOT NULL,
  `data` LONGTEXT NOT NULL,
  `updated_by` VARCHAR(50) DEFAULT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
CREATE TABLE IF NOT EXISTS `rsg_npcdialog_quest_progress` (
  `citizenid` VARCHAR(50) NOT NULL,
  `quest_id` VARCHAR(50) NOT NULL,
  `data` TEXT NOT NULL,
  PRIMARY KEY (`citizenid`, `quest_id`)
);
