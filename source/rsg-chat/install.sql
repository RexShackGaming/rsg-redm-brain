-- Optional: the resource creates this table itself on first start.
CREATE TABLE IF NOT EXISTS `rsg_chat_channels` (
  `id` VARCHAR(32) NOT NULL,
  `data` LONGTEXT NOT NULL,
  `sort` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
);
