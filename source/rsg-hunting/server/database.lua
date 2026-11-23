------------------------------------------
-- tables for the journal and contracts (the weekly tables are made in xp.lua)
-- built automatically on start; set Config.AutoDatabase = false and import install.sql to do it by hand
------------------------------------------
HuntingDB = { ready = false }

-- keep in sync with install.sql
local TABLES = {
    [[CREATE TABLE IF NOT EXISTS `hunting_journal` (
        `citizenid` VARCHAR(50) NOT NULL,
        `model` BIGINT NOT NULL,
        `skinned` INT NOT NULL DEFAULT 0,
        `perfect` INT NOT NULL DEFAULT 0,
        `sold` INT NOT NULL DEFAULT 0,
        `best_sale` DECIMAL(10,2) NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`, `model`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `hunting_contracts` (
        `citizenid` VARCHAR(50) NOT NULL,
        `model` BIGINT NOT NULL DEFAULT 0,
        `need` INT NOT NULL DEFAULT 1,
        `got` INT NOT NULL DEFAULT 0,
        `quality` VARCHAR(10) NOT NULL DEFAULT '',
        `reward` DECIMAL(10,2) NOT NULL DEFAULT 0,
        `xp` INT NOT NULL DEFAULT 0,
        `expires` INT NOT NULL DEFAULT 0,
        `status` VARCHAR(10) NOT NULL DEFAULT 'active',
        `claimed_at` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`)
    )]],
}

CreateThread(function()
    if Config.AutoDatabase == false then HuntingDB.ready = true return end
    local ok, err = pcall(function()
        for _, query in ipairs(TABLES) do MySQL.query.await(query) end
    end)
    if ok then
        HuntingDB.ready = true
        print('[rsg-hunting] ^2database tables ready^7')
    else
        print(('[rsg-hunting] ^1could not create the journal/contract tables, those features are off: %s^7'):format(tostring(err)))
    end
end)
