-- Only needed if DatabaseConfig.AutoInstall = false in server/sv_config.lua.
-- With AutoInstall on (default) the resource builds and upgrades its tables itself.
CREATE TABLE IF NOT EXISTS `rsg_trapdoors` (
    `door_id`    VARCHAR(64) NOT NULL,
    `passcode`   CHAR(4)     NOT NULL,
    `owner`      VARCHAR(50) NOT NULL,
    `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`door_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
