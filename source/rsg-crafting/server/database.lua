---------------------------------------------
-- database: tables are built on start (Config.AutoDatabase); install.sql is kept in sync for manual installs
---------------------------------------------
CraftingServer = CraftingServer or {}
CraftingServer.ready = false

local readyCallbacks = {}

-- run fn once the database is ready (immediately if it already is)
function CraftingServer.OnReady(fn)
    if CraftingServer.ready then return fn() end
    readyCallbacks[#readyCallbacks + 1] = fn
end

local TABLES = {
    [[CREATE TABLE IF NOT EXISTS `rsg_crafting_recipes` (
        `citizenid`  VARCHAR(50) NOT NULL,
        `recipe`     VARCHAR(64) NOT NULL,
        `learned_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`, `recipe`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_crafting_stations` (
        `id`   INT          NOT NULL AUTO_INCREMENT,
        `type` VARCHAR(32)  NOT NULL,
        `x`    DOUBLE       NOT NULL,
        `y`    DOUBLE       NOT NULL,
        `z`    DOUBLE       NOT NULL,
        `rx`   DOUBLE       NOT NULL DEFAULT 0,
        `ry`   DOUBLE       NOT NULL DEFAULT 0,
        `rz`   DOUBLE       NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local function ensureDatabase()
    local ok, err = pcall(function()
        for _, sql in ipairs(TABLES) do MySQL.query.await(sql) end
    end)
    if not ok then
        print(('^1[rsg-crafting] could not create the database tables: %s^7'):format(tostring(err)))
        return false
    end
    print('^2[rsg-crafting] database tables ready^7')
    return true
end

CreateThread(function()
    if Config.AutoDatabase and not ensureDatabase() then return end
    CraftingServer.ready = true
    for _, fn in ipairs(readyCallbacks) do fn() end
    readyCallbacks = {}
end)
