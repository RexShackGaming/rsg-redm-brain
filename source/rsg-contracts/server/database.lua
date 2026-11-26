-- Same schema as install.sql
local Tables = {
[[
CREATE TABLE IF NOT EXISTS `rsg_contracts` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `type` VARCHAR(10) NOT NULL,
    `status` VARCHAR(12) NOT NULL,
    `buyer_cid` VARCHAR(50) NOT NULL,
    `buyer_name` VARCHAR(100) NOT NULL,
    `worker_cid` VARCHAR(50) NOT NULL,
    `worker_name` VARCHAR(100) NOT NULL,
    `title` VARCHAR(255) NOT NULL,
    `details` TEXT NOT NULL,
    `item` VARCHAR(80) DEFAULT NULL,
    `quantity` INT NOT NULL DEFAULT 0,
    `pay_cents` INT NOT NULL,
    `deposit_cents` INT NOT NULL DEFAULT 0,
    `hours` INT NOT NULL,
    `due_at` BIGINT NOT NULL,
    `cancel_by` VARCHAR(50) DEFAULT NULL,
    `outcome` VARCHAR(30) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]],
[[
CREATE TABLE IF NOT EXISTS `rsg_contract_claims` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `contract_id` INT NOT NULL,
    `cents` INT NOT NULL DEFAULT 0,
    `item` VARCHAR(80) DEFAULT NULL,
    `amount` INT NOT NULL DEFAULT 0,
    `info` LONGTEXT DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]]
}

function EnsureDatabase()
    for _, query in ipairs(Tables) do
        local ok, err = pcall(function() MySQL.query.await(query) end)
        if not ok then
            print(('^1[rsg-contracts] database setup failed: %s^7'):format(tostring(err)))
            return false
        end
    end
    print('^2[rsg-contracts] database tables ready^7')
    return true
end
