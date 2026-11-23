-- rsg-economy: database setup, in-memory state, loading, saving, ledger
RSGEcon = RSGEcon or {}
local TAG = '[rsg-economy]'

-- shared helpers (used by every server file)
function RSGEcon.finite(v) return type(v) == 'number' and v == v and v > -math.huge and v < math.huge end
function RSGEcon.round2(v) return math.floor(v * 100 + 0.5) / 100 end
RSGEcon.MaxBalance = 999999999999.0 -- largest value a DECIMAL(14,2) balance can hold

------------------------------------------
-- schema (keep identical to install.sql)
------------------------------------------
local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `rsg_economy_treasury` (
        `region` VARCHAR(50) NOT NULL,
        `balance` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
        PRIMARY KEY (`region`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_economy_tax` (
        `region` VARCHAR(50) NOT NULL,
        `category` VARCHAR(50) NOT NULL,
        `rate` DECIMAL(6,4) NOT NULL DEFAULT 0.0000,
        PRIMARY KEY (`region`, `category`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_economy_ledger` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `region` VARCHAR(50) NOT NULL,
        `amount` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
        `balance_after` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
        `kind` VARCHAR(20) NOT NULL,
        `reason` VARCHAR(120) NOT NULL DEFAULT '',
        `actor` VARCHAR(80) NOT NULL DEFAULT '',
        `created` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        KEY `idx_region_created` (`region`, `created`),
        KEY `idx_created` (`created`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_economy_market` (
        `item` VARCHAR(50) NOT NULL,
        `region` VARCHAR(50) NOT NULL,
        `pressure` DOUBLE NOT NULL DEFAULT 0,
        `updated` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`item`, `region`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_economy_project` (
        `region` VARCHAR(50) NOT NULL,
        `project` VARCHAR(50) NOT NULL,
        `expires` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`region`, `project`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_economy_meta` (
        `k` VARCHAR(50) NOT NULL,
        `v` VARCHAR(100) NOT NULL,
        PRIMARY KEY (`k`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_economy_region` (
        `id` VARCHAR(50) NOT NULL,
        `label` VARCHAR(60) NOT NULL,
        `ord` INT NOT NULL DEFAULT 99,
        `x` DOUBLE NOT NULL DEFAULT 0,
        `y` DOUBLE NOT NULL DEFAULT 0,
        `z` DOUBLE NOT NULL DEFAULT 0,
        `law_job` VARCHAR(50) NULL,
        `officials` TEXT NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_economy_mayor` (
        `region` VARCHAR(50) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(100) NOT NULL,
        `since` INT UNSIGNED NOT NULL,
        `term_end` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`region`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_economy_election` (
        `region` VARCHAR(50) NOT NULL,
        `phase` VARCHAR(12) NOT NULL,
        `phase_end` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`region`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_economy_candidate` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `region` VARCHAR(50) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(100) NOT NULL,
        `platform` VARCHAR(200) NOT NULL DEFAULT '',
        `registered` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uq_region_citizen` (`region`, `citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_economy_vote` (
        `region` VARCHAR(50) NOT NULL,
        `license` VARCHAR(80) NOT NULL,
        `voter` VARCHAR(50) NOT NULL,
        `candidate` INT UNSIGNED NOT NULL,
        `voted` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`region`, `license`),
        KEY `idx_candidate` (`candidate`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local function ensureDatabase()
    local ok, err = pcall(function()
        for i = 1, #SCHEMA do
            MySQL.query.await(SCHEMA[i])
        end
        -- upgrade: tables made by older versions lack the index used to prune the ledger
        local has = MySQL.scalar.await("SELECT COUNT(1) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rsg_economy_ledger' AND INDEX_NAME = 'idx_created'")
        if (tonumber(has) or 0) == 0 then
            MySQL.query.await('ALTER TABLE `rsg_economy_ledger` ADD KEY `idx_created` (`created`)')
        end
    end)
    if not ok then
        print(('%s ^1could not create database tables: %s^7'):format(TAG, tostring(err)))
        return false
    end
    print(('%s ^2database tables ready^7'):format(TAG))
    return true
end

RSGEcon.Ready = false

function RSGEcon.WaitReady()
    local waited = 0
    while not RSGEcon.Ready do
        if waited >= 15000 then return false end
        Wait(100)
        waited = waited + 100
    end
    return true
end

------------------------------------------
-- in-memory state
--   Treasury[region] = balance
--   Taxes[region][category] = rate          (only rates changed from the default are stored)
--   Market[region][item] = { pressure, updated }
--   Projects[region][id] = expires          (0 = permanent)
------------------------------------------
RSGEcon.Treasury = {}
RSGEcon.Taxes = {}
RSGEcon.Market = {}
RSGEcon.Projects = {}
RSGEcon.Mayors = {}      -- Mayors[region] = { citizenid, name, since, term_end }
RSGEcon.Elections = {}   -- Elections[region] = { phase = 'candidacy' | 'voting', phase_end }; no entry = no election running
RSGEcon.Meta = {}        -- small key/value store (last interest day, last report day, election retry times)

-- keys of rows that changed since the last save
local dirty = { treasury = {}, tax = {}, market = {}, project = {} }

function RSGEcon.MarkTreasury(region) dirty.treasury[region] = true end
function RSGEcon.MarkTax(region, cat) dirty.tax[region .. '|' .. cat] = { region, cat } end
function RSGEcon.MarkMarket(region, item) dirty.market[region .. '|' .. item] = { region, item } end
function RSGEcon.MarkProject(region, id) dirty.project[region .. '|' .. id] = { region, id } end

------------------------------------------
-- ledger
------------------------------------------
local function clip(s, n)
    s = tostring(s or '')
    if #s > n then s = s:sub(1, n) end
    return s
end

function RSGEcon.Ledger(region, amount, balanceAfter, kind, reason, actor, awaitIt)
    local params = { region, amount, balanceAfter, clip(kind, 20), clip(reason, 120), clip(actor, 80), os.time() }
    local q = 'INSERT INTO rsg_economy_ledger (region, amount, balance_after, kind, reason, actor, created) VALUES (?, ?, ?, ?, ?, ?, ?)'
    local ok, err = pcall(function()
        if awaitIt then MySQL.insert.await(q, params) else MySQL.insert(q, params) end
    end)
    if not ok then print(('%s ^1ledger write failed: %s^7'):format(TAG, tostring(err))) end
    return ok
end

------------------------------------------
-- loading
------------------------------------------
local function loadAll()
    local ok, err = pcall(function()
        for _, r in ipairs(MySQL.query.await('SELECT region, balance FROM rsg_economy_treasury') or {}) do
            RSGEcon.Treasury[r.region] = tonumber(r.balance) or 0
        end
        for _, r in ipairs(MySQL.query.await('SELECT region, category, rate FROM rsg_economy_tax') or {}) do
            RSGEcon.Taxes[r.region] = RSGEcon.Taxes[r.region] or {}
            RSGEcon.Taxes[r.region][r.category] = tonumber(r.rate) or 0
        end
        for _, r in ipairs(MySQL.query.await('SELECT item, region, pressure, updated FROM rsg_economy_market') or {}) do
            RSGEcon.Market[r.region] = RSGEcon.Market[r.region] or {}
            RSGEcon.Market[r.region][r.item] = { pressure = tonumber(r.pressure) or 0, updated = tonumber(r.updated) or os.time() }
        end
        for _, r in ipairs(MySQL.query.await('SELECT region, project, expires FROM rsg_economy_project') or {}) do
            RSGEcon.Projects[r.region] = RSGEcon.Projects[r.region] or {}
            RSGEcon.Projects[r.region][r.project] = tonumber(r.expires) or 0
        end
        for _, r in ipairs(MySQL.query.await('SELECT k, v FROM rsg_economy_meta') or {}) do
            RSGEcon.Meta[r.k] = r.v
        end
        for _, r in ipairs(MySQL.query.await('SELECT region, citizenid, name, since, term_end FROM rsg_economy_mayor') or {}) do
            RSGEcon.Mayors[r.region] = { citizenid = r.citizenid, name = r.name, since = tonumber(r.since) or 0, term_end = tonumber(r.term_end) or 0 }
        end
        for _, r in ipairs(MySQL.query.await('SELECT region, phase, phase_end FROM rsg_economy_election') or {}) do
            RSGEcon.Elections[r.region] = { phase = r.phase, phase_end = tonumber(r.phase_end) or 0 }
        end
        -- towns added or changed in the admin panel (applied over Config.Regions)
        for _, r in ipairs(MySQL.query.await('SELECT id, label, ord, x, y, z, law_job, officials FROM rsg_economy_region') or {}) do
            RSGEcon.ApplyRegionRow(r)
        end
    end)
    if not ok then
        print(('%s ^1could not load saved data: %s^7'):format(TAG, tostring(err)))
        return false
    end
    return true
end

------------------------------------------
-- saving
------------------------------------------
local Q_TREASURY = 'INSERT INTO rsg_economy_treasury (region, balance) VALUES (?, ?) ON DUPLICATE KEY UPDATE balance = VALUES(balance)'
local Q_TAX = 'INSERT INTO rsg_economy_tax (region, category, rate) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE rate = VALUES(rate)'
local Q_MARKET = 'INSERT INTO rsg_economy_market (item, region, pressure, updated) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE pressure = VALUES(pressure), updated = VALUES(updated)'
local Q_MARKET_DEL = 'DELETE FROM rsg_economy_market WHERE item = ? AND region = ?'
local Q_PROJECT = 'INSERT INTO rsg_economy_project (region, project, expires) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE expires = VALUES(expires)'
local Q_PROJECT_DEL = 'DELETE FROM rsg_economy_project WHERE region = ? AND project = ?'

-- puts a failed row back in the queue
local function remark(group, key)
    if group == 'treasury' then dirty.treasury[key] = true
    else dirty[group][key[1] .. '|' .. key[2]] = key end
end

-- writes the changed rows in transactions of up to 100 queries (runs from the save thread and on stop)
function RSGEcon.Flush()
    if not RSGEcon.Ready then return end

    -- snapshot first: awaiting below yields, and new changes may arrive meanwhile
    local queries, keys = {}, {}
    local function add(group, key, query, values)
        queries[#queries + 1] = { query = query, values = values }
        keys[#keys + 1] = { group, key }
    end
    for region in pairs(dirty.treasury) do
        add('treasury', region, Q_TREASURY, { region, RSGEcon.Treasury[region] or 0 })
    end
    for _, k in pairs(dirty.tax) do
        local rate = RSGEcon.Taxes[k[1]] and RSGEcon.Taxes[k[1]][k[2]]
        if rate ~= nil then add('tax', k, Q_TAX, { k[1], k[2], rate }) end
    end
    for _, k in pairs(dirty.market) do
        local m = RSGEcon.Market[k[1]] and RSGEcon.Market[k[1]][k[2]]
        if m then add('market', k, Q_MARKET, { k[2], k[1], m.pressure, m.updated })
        else add('market', k, Q_MARKET_DEL, { k[2], k[1] }) end
    end
    for _, k in pairs(dirty.project) do
        local e = RSGEcon.Projects[k[1]] and RSGEcon.Projects[k[1]][k[2]]
        if e ~= nil then add('project', k, Q_PROJECT, { k[1], k[2], e })
        else add('project', k, Q_PROJECT_DEL, { k[1], k[2] }) end
    end
    dirty = { treasury = {}, tax = {}, market = {}, project = {} }

    for first = 1, #queries, 100 do
        local last = math.min(first + 99, #queries)
        local chunk = {}
        for i = first, last do chunk[#chunk + 1] = queries[i] end
        local ok, res = pcall(MySQL.transaction.await, chunk)
        if not ok or not res then
            print(('%s ^1save failed (%s): %s^7'):format(TAG, keys[first][1], tostring(ok and 'transaction rolled back' or res)))
            for i = first, last do remark(keys[i][1], keys[i][2]) end -- keep for the next save
        end
    end
end

-- saves one treasury and waits for it (used before paying money out)
function RSGEcon.SaveTreasuryNow(region)
    dirty.treasury[region] = nil
    local ok, err = pcall(function() MySQL.insert.await(Q_TREASURY, { region, RSGEcon.Treasury[region] or 0 }) end)
    if not ok then
        dirty.treasury[region] = true
        print(('%s ^1treasury save failed: %s^7'):format(TAG, tostring(err)))
    end
    return ok
end

function RSGEcon.SaveProjectNow(region, id)
    dirty.project[region .. '|' .. id] = nil
    local e = RSGEcon.Projects[region] and RSGEcon.Projects[region][id]
    local ok = pcall(function()
        if e ~= nil then MySQL.insert.await(Q_PROJECT, { region, id, e }) else MySQL.insert.await(Q_PROJECT_DEL, { region, id }) end
    end)
    if not ok then dirty.project[region .. '|' .. id] = { region, id } end
    return ok
end

-- small key/value store; awaitIt = true waits for the write (use it when a crash between write and action matters)
function RSGEcon.SetMeta(key, value, awaitIt)
    value = tostring(value)
    RSGEcon.Meta[key] = value
    local q = 'INSERT INTO rsg_economy_meta (k, v) VALUES (?, ?) ON DUPLICATE KEY UPDATE v = VALUES(v)'
    local ok = pcall(function()
        if awaitIt then MySQL.insert.await(q, { key, value }) else MySQL.insert(q, { key, value }) end
    end)
    return ok
end

CreateThread(function()
    while true do
        Wait(math.max(10, tonumber(Config.SaveInterval) or 30) * 1000)
        RSGEcon.Flush()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    RSGEcon.Flush()
end)

------------------------------------------
-- pruning (old ledger entries, expired projects)
------------------------------------------
function RSGEcon.Prune()
    local now = os.time()
    local keep = math.max(2, tonumber(Config.Treasury.Ledger.KeepDays) or 30) * 86400 -- never below 2 days: the daily withdrawal limit reads the ledger
    pcall(function()
        MySQL.query.await('DELETE FROM rsg_economy_ledger WHERE created < ?', { now - keep })
    end)
    for region, list in pairs(RSGEcon.Projects) do
        for id, expires in pairs(list) do
            if expires ~= 0 and expires < now then
                list[id] = nil
                RSGEcon.MarkProject(region, id)
            end
        end
    end
end

------------------------------------------
-- startup
------------------------------------------
CreateThread(function()
    Wait(1000) -- let every server script finish loading first
    if Config.AutoDatabase and not ensureDatabase() then return end
    if not loadAll() then return end
    RSGEcon.Ready = true
    RSGEcon.Prune()
    TriggerEvent('rsg-economy:server:ready')
    while true do
        Wait(6 * 60 * 60 * 1000)
        RSGEcon.Prune()
    end
end)
