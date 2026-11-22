-- rsg-character: manual install (only needed when RSG.AutoDatabase = false in shared/config.lua)
-- Keep in sync with server/sv_database.lua.

CREATE TABLE IF NOT EXISTS `playerskins` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(255) NOT NULL,
  `skin` LONGTEXT NOT NULL,
  `clothes` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_playerskins_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `playeroutfit` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(255) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `clothes` LONGTEXT NOT NULL,
  `is_default` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `citizen_default` (`citizenid`, `is_default`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `playerslots` (
  `license` VARCHAR(255) NOT NULL,
  `extra_slots` INT(11) NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `rsg_character_names` (
  `citizenid` VARCHAR(50) NOT NULL,
  `firstname` VARCHAR(64) NOT NULL,
  `lastname` VARCHAR(64) NOT NULL,
  PRIMARY KEY (`citizenid`),
  KEY `fullname` (`firstname`, `lastname`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `rsg_character_deleted` (
  `citizenid` VARCHAR(50) NOT NULL,
  `license` VARCHAR(255) NOT NULL,
  `original_cid` INT(11) NOT NULL,
  `deleted_at` INT(11) NOT NULL,
  `purge_at` INT(11) NOT NULL,
  PRIMARY KEY (`citizenid`),
  KEY `license` (`license`),
  KEY `purge_at` (`purge_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Upgrading from rsg-character 3.3.x by hand? Run these once (after removing duplicate playerskins rows):
--   ALTER TABLE `playerskins` ADD UNIQUE KEY `uq_playerskins_citizenid` (`citizenid`);
--   ALTER TABLE `playeroutfit` ADD KEY `citizen_default` (`citizenid`, `is_default`);
--   INSERT INTO rsg_character_names (citizenid, firstname, lastname)
--     SELECT citizenid, JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))
--     FROM players WHERE charinfo IS NOT NULL;
