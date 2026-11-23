-- Optional: the resource creates this table itself on first start.
CREATE TABLE IF NOT EXISTS `rsg_chat_channels` (
  `id` VARCHAR(32) NOT NULL,
  `data` LONGTEXT NOT NULL,
  `sort` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
);

-- Optional: created automatically too (chat mutes and chat logs).
CREATE TABLE IF NOT EXISTS `rsg_chat_mutes` (
  `citizenid` VARCHAR(50) NOT NULL,
  `expires` BIGINT NOT NULL DEFAULT 0,
  `reason` VARCHAR(200) NOT NULL DEFAULT '',
  `muted_by` VARCHAR(100) NOT NULL DEFAULT '',
  PRIMARY KEY (`citizenid`)
) DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rsg_chat_logs` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `channel` VARCHAR(32) NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL DEFAULT '',
  `name` VARCHAR(100) NOT NULL DEFAULT '',
  `player_id` INT NOT NULL DEFAULT 0,
  `message` VARCHAR(768) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_created` (`created`),
  KEY `idx_citizenid` (`citizenid`)
) DEFAULT CHARSET=utf8mb4;
