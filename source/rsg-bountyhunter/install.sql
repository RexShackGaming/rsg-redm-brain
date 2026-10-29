CREATE TABLE IF NOT EXISTS `rsg_bountyhunter` (
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NOT NULL DEFAULT '',
    `completed` INT NOT NULL DEFAULT 0,
    `alive` INT NOT NULL DEFAULT 0,
    `dead` INT NOT NULL DEFAULT 0,
    `earned` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
