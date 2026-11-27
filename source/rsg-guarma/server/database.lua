-------------------------------------
-- shared server namespace and per-character data (cargo limits, rescue cooldown)
-------------------------------------
Guarma = {}

local ready = false
local cache = {} -- [citizenid] = { day, bought = { [item] = n }, rescueAt }

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `rsg_guarma_players` (
    `citizenid` VARCHAR(50) NOT NULL,
    `trade_day` VARCHAR(10) NOT NULL DEFAULT '',
    `bought` TEXT NULL,
    `rescue_at` BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]]

MySQL.ready(function()
    if Config.AutoDatabase then
        local ok, err = pcall(MySQL.query.await, SCHEMA)
        if not ok then
            return print(('^1[rsg-guarma] could not create the database table: %s^7'):format(err))
        end
        print('^2[rsg-guarma] database tables ready^7')
    end
    ready = true
end)

-- yields on first load; returns nil if the data can't be read (cargo and rescue are then refused)
function Guarma.GetRecord(citizenid)
    if not ready then return nil end
    if not cache[citizenid] then
        local ok, row = pcall(MySQL.single.await,
            'SELECT trade_day, bought, rescue_at FROM rsg_guarma_players WHERE citizenid = ?', { citizenid })
        if not ok then
            print(('^1[rsg-guarma] database read failed: %s^7'):format(row))
            return nil
        end
        -- another request may have loaded it while this one waited
        cache[citizenid] = cache[citizenid] or {
            day = row and row.trade_day or '',
            bought = row and row.bought and json.decode(row.bought) or {},
            rescueAt = row and tonumber(row.rescue_at) or 0,
        }
    end

    local record = cache[citizenid]
    local today = os.date('!%Y-%m-%d')
    if record.day ~= today then
        record.day, record.bought = today, {}
    end
    return record
end

function Guarma.SaveRecord(citizenid)
    local record = cache[citizenid]
    if not record then return end
    MySQL.prepare('INSERT INTO rsg_guarma_players (citizenid, trade_day, bought, rescue_at) VALUES (?, ?, ?, ?) '
        .. 'ON DUPLICATE KEY UPDATE trade_day = VALUES(trade_day), bought = VALUES(bought), rescue_at = VALUES(rescue_at)',
        { citizenid, record.day, json.encode(record.bought), record.rescueAt })
end
