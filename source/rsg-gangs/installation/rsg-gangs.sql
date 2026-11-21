-- rsg-gangs database schema.
-- The resource creates these tables automatically on start (Config.AutoDatabase = true).
-- Import this file only if you set Config.AutoDatabase = false. Keep it identical to server/main.lua.

CREATE TABLE IF NOT EXISTS `rsg_gangs` (
  `name` varchar(50) NOT NULL,
  `label` varchar(50) NOT NULL,
  `color` varchar(10) NOT NULL DEFAULT '#e63946',
  `bank` int(11) NOT NULL DEFAULT 0,
  `owner` varchar(50) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `wagon_x` float DEFAULT NULL,
  `wagon_y` float DEFAULT NULL,
  `wagon_z` float DEFAULT NULL,
  `wagon_heading` float DEFAULT NULL,
  `stash_tier` varchar(20) NOT NULL DEFAULT 'small',
  `stash_id` varchar(36) DEFAULT NULL,
  `upkeep_due` int(11) DEFAULT NULL,
  `upkeep_missed` int(11) NOT NULL DEFAULT 0,
  `tag` varchar(8) DEFAULT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_gang_members` (
  `citizenid` varchar(50) NOT NULL,
  `gang_name` varchar(50) NOT NULL,
  `rank` varchar(50) NOT NULL DEFAULT 'recruit',
  `name` varchar(100) DEFAULT NULL,
  `joined_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`),
  KEY `gang_name` (`gang_name`),
  CONSTRAINT `fk_gang_member_gang` FOREIGN KEY (`gang_name`) REFERENCES `rsg_gangs` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_gang_equipment` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gang_name` varchar(50) NOT NULL,
  `item_id` varchar(50) NOT NULL,
  `x` float NOT NULL,
  `y` float NOT NULL,
  `z` float NOT NULL,
  `heading` float NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `gang_item` (`gang_name`, `item_id`),
  CONSTRAINT `fk_gang_equipment_gang` FOREIGN KEY (`gang_name`) REFERENCES `rsg_gangs` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Upgrading from 2.0.x (only needed when importing manually): add the stored member name column.
-- ALTER TABLE `rsg_gang_members` ADD COLUMN `name` varchar(100) DEFAULT NULL AFTER `rank`;

CREATE TABLE IF NOT EXISTS `rsg_gang_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gang_name` varchar(50) NOT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `actor` varchar(100) DEFAULT NULL,
  `action` varchar(40) NOT NULL,
  `detail` varchar(200) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `gang_id` (`gang_name`, `id`),
  CONSTRAINT `fk_gang_log_gang` FOREIGN KEY (`gang_name`) REFERENCES `rsg_gangs` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_gang_territories` (
  `territory_id` varchar(50) NOT NULL,
  `gang_name` varchar(50) NOT NULL,
  `claimed_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`territory_id`),
  KEY `gang_name` (`gang_name`),
  CONSTRAINT `fk_gang_territory_gang` FOREIGN KEY (`gang_name`) REFERENCES `rsg_gangs` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_gang_bounties` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gang_name` varchar(50) NOT NULL,
  `reward` int(11) NOT NULL,
  `target_type` varchar(10) NOT NULL DEFAULT 'player',
  `target_id` varchar(50) DEFAULT NULL,
  `target_name` varchar(100) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `gang_name` (`gang_name`),
  CONSTRAINT `fk_gang_bounty_gang` FOREIGN KEY (`gang_name`) REFERENCES `rsg_gangs` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_gang_rivals` (
  `gang_name` varchar(50) NOT NULL,
  `rival_name` varchar(50) NOT NULL,
  `kills` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`gang_name`, `rival_name`),
  CONSTRAINT `fk_gang_rival_gang` FOREIGN KEY (`gang_name`) REFERENCES `rsg_gangs` (`name`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_gang_rival_other` FOREIGN KEY (`rival_name`) REFERENCES `rsg_gangs` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_gang_state` (
  `key` varchar(50) NOT NULL,
  `value` varchar(100) NOT NULL,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
