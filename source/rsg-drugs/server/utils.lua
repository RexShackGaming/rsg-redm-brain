-- Shared server helpers (loaded first): rsg-core callback wrapper and the one-time database build.
local RSGCore = exports['rsg-core']:GetCoreObject()

-- rsg-core callback wrapper: handlers return their result(s) instead of calling cb
function DrugsCallback(name, fn)
    RSGCore.Functions.CreateCallback(name, function(src, cb, ...) cb(fn(src, ...)) end)
end

-- Builds every table this resource needs (identical to installation/install.sql). Safe to call from several
-- places: it only runs once. Returns true when the tables are ready (or when Config.AutoDatabase is false).
local dbReady
function DrugsEnsureDatabase()
    if dbReady ~= nil then return dbReady end
    if Config.AutoDatabase == false then dbReady = true return true end
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `rsg_drugs_labs` (
                `citizenid` VARCHAR(50) NOT NULL,
                `data` LONGTEXT NOT NULL,
                PRIMARY KEY (`citizenid`)
            )
        ]])
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `rsg_drugs_state` (
                `key` VARCHAR(50) NOT NULL,
                `value` LONGTEXT NOT NULL,
                PRIMARY KEY (`key`)
            )
        ]])
    end)
    if not ok then
        print(('^1[rsg-drugs] Could not create the database tables: %s^7'):format(tostring(err)))
        print('^1[rsg-drugs] Set Config.AutoDatabase = false and import installation/install.sql manually.^7')
        dbReady = false
        return false
    end
    print('^2[rsg-drugs] database tables ready^7')
    dbReady = true
    return true
end

---------------------------------------------------------------------
-- Potency helpers (Config.Quality). Potency is 0-100 and lives on items as info.potency.
---------------------------------------------------------------------
local function clamp100(v) return math.max(0, math.min(100, v)) end

-- price multiplier for a potency (1.0 when quality is switched off)
function DrugsPotencyMult(p)
    local Q = Config.Quality
    if not Q.Enabled then return 1.0 end
    p = clamp100(tonumber(p) or Q.Default)
    return Q.PriceMin + (Q.PriceMax - Q.PriceMin) * p / 100
end

-- the info table to put on an item (nil when quality is off); rounded so stacks still merge
function DrugsPotencyInfo(p)
    local Q = Config.Quality
    if not Q.Enabled then return nil end
    local step = math.max(1, Q.Step or 5)
    return { potency = clamp100(math.floor((tonumber(p) or Q.Default) / step + 0.5) * step) }
end

-- potency of an inventory item (items without one count as Config.Quality.Default)
function DrugsItemPotency(item)
    local p = item and type(item.info) == 'table' and tonumber(item.info.potency)
    return p or Config.Quality.Default
end
