-- rsg-weather database schema (also created automatically when Config.AutoDatabase = true)

CREATE TABLE IF NOT EXISTS `rsg_weather_state` (
  `key` VARCHAR(50) NOT NULL PRIMARY KEY,
  `value` VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
