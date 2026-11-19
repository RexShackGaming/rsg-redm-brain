-- rsg-smelting database schema (also created automatically when Config.AutoDatabase = true)

CREATE TABLE IF NOT EXISTS `rsg_smelting_state` (
  `id` TINYINT UNSIGNED NOT NULL PRIMARY KEY,
  `data` LONGTEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
