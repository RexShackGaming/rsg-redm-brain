-- rsg-society database schema.
-- The resource creates these tables automatically on start (Config.AutoDatabase = true) by running this very file.
-- Import it by hand only if you set Config.AutoDatabase = false.
-- Every statement ends with a semicolon at the end of a line; do not put semicolons inside strings.
-- Money columns hold cents (whole numbers), so $12.50 is stored as 1250.

CREATE TABLE IF NOT EXISTS `rsg_societies` (
  `name` varchar(50) NOT NULL,
  `type` enum('job','gang') NOT NULL DEFAULT 'job',
  `label` varchar(80) NOT NULL,
  `color` varchar(10) DEFAULT NULL,
  `tag` varchar(8) DEFAULT NULL,
  `owner` varchar(50) DEFAULT NULL,
  `balance_cents` bigint(20) NOT NULL DEFAULT 0,
  `payroll` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`name`),
  KEY `type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_society_ranks` (
  `society` varchar(50) NOT NULL,
  `level` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `payment_cents` bigint(20) NOT NULL DEFAULT 0,
  `is_boss` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`society`, `level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_society_perms` (
  `society` varchar(50) NOT NULL,
  `level` int(11) NOT NULL,
  `perms` text NOT NULL,
  PRIMARY KEY (`society`, `level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_society_members` (
  `citizenid` varchar(50) NOT NULL,
  `society` varchar(50) NOT NULL,
  `level` int(11) NOT NULL DEFAULT 0,
  `name` varchar(100) DEFAULT NULL,
  `joined_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`),
  KEY `society` (`society`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_society_ledger` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `society` varchar(50) NOT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `actor` varchar(100) DEFAULT NULL,
  `kind` varchar(20) NOT NULL,
  `amount_cents` bigint(20) NOT NULL,
  `balance_cents` bigint(20) NOT NULL,
  `note` varchar(200) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `society_id` (`society`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_society_audit` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `society` varchar(50) NOT NULL,
  `actor_cid` varchar(50) DEFAULT NULL,
  `actor_name` varchar(100) DEFAULT NULL,
  `action` varchar(40) NOT NULL,
  `target_cid` varchar(50) DEFAULT NULL,
  `target_name` varchar(100) DEFAULT NULL,
  `detail` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `society_id` (`society`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_society_fines` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `society` varchar(50) NOT NULL,
  `citizenid` varchar(50) NOT NULL,
  `target_name` varchar(100) DEFAULT NULL,
  `issuer_cid` varchar(50) DEFAULT NULL,
  `issuer_name` varchar(100) DEFAULT NULL,
  `amount_cents` bigint(20) NOT NULL,
  `paid_cents` bigint(20) NOT NULL DEFAULT 0,
  `reason` varchar(200) DEFAULT NULL,
  `status` enum('unpaid','paid','void') NOT NULL DEFAULT 'unpaid',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `paid_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizen_status` (`citizenid`, `status`),
  KEY `society_id` (`society`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_society_locations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `society` varchar(50) NOT NULL,
  `label` varchar(80) DEFAULT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `heading` double NOT NULL DEFAULT 0,
  `created_by` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `society` (`society`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_society_meta` (
  `k` varchar(60) NOT NULL,
  `v` varchar(255) NOT NULL,
  PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
